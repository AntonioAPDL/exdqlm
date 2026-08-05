#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_trainonly_mechanism_v1_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MAX_LOAD="${MAX_LOAD:-50}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-96}"
MIN_DISK_GB="${MIN_DISK_GB:-250}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"

cd "$REPO_ROOT"
STAGE="qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
CONFIG_STUB="config/validation/${STAGE}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE_FILE="$STATE_ROOT/current_stage.txt"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_trainonly_mechanism_v1.lock"
printf 'timestamp,stage,bundle,status,detail\n' > "$STATUS_CSV"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "$HEARTBEAT_CSV"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another train-only mechanism v1 pipeline holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() {
  printf '%s\n' "$1" > "$CURRENT_STAGE_FILE"
}

record_status() {
  local stage="$1"
  local bundle="$2"
  local status="$3"
  local detail="$4"
  printf '%s,%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "$bundle" "$status" "${detail//,/;}" >> "$STATUS_CSV"
}

resource_values() {
  local load1 memory_kb disk_kb
  load1="$(awk '{print $1}' /proc/loadavg)"
  memory_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  disk_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
  awk -v ld="$load1" -v memory="$memory_kb" -v disk="$disk_kb" 'BEGIN {printf "%.2f %.1f %.1f", ld, memory/1048576, disk/1048576}'
}

write_heartbeat() {
  local values stage
  values="$(resource_values)"
  stage="$(cat "$CURRENT_STAGE_FILE" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "${values// /,}" >> "$HEARTBEAT_CSV"
}

heartbeat_loop() {
  while true; do
    write_heartbeat
    sleep "$HEARTBEAT_SECONDS"
  done
}

set_stage "initializing"
heartbeat_loop &
HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_resources() {
  while true; do
    local values load memory disk
    values="$(resource_values)"
    read -r load memory disk <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" 'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md))}'; then
      record_status "resource_gate" "all" "PASS" "load=${load};memory_gb=${memory};disk_gb=${disk}"
      return 0
    fi
    record_status "resource_gate" "all" "WAIT" "load=${load};memory_gb=${memory};disk_gb=${disk}"
    sleep "$POLL_SECONDS"
  done
}

check_storage_light() {
  local path="$1"
  local evidence="$2"
  if [[ ! -d "$path" ]]; then
    printf 'run_root_missing\n' > "$evidence"
    return 1
  fi
  find "$path" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) -printf '%s\t%p\n' | sort -nr > "$evidence"
  [[ ! -s "$evidence" ]]
}

GIT_SHA="$(git rev-parse HEAD)"
GIT_SHORT="$(git rev-parse --short HEAD)"
STAMP="$(date +%Y%m%d_%H%M%S)"
for bundle in raw c12 c123 sr; do
  key="$(printf '%s' "$bundle" | tr '[:lower:]' '[:upper:]')_RUN_TAG"
  value="qdesn-tmv1-${bundle}-full-${STAMP}__git-${GIT_SHORT}"
  printf -v "$key" '%s' "$value"
  export "$key"
done
cat > "$STATE_ROOT/run_tags.env" <<EOF
RUN_ID=$RUN_ID
RAW_RUN_TAG=$RAW_RUN_TAG
C12_RUN_TAG=$C12_RUN_TAG
C123_RUN_TAG=$C123_RUN_TAG
SR_RUN_TAG=$SR_RUN_TAG
GIT_COMMIT=$GIT_SHA
WORKTREE=$REPO_ROOT
TOTAL_WORKERS=16
CPU_POLICY=raw:0-6;c12:7-9;c123:10-12;sr:13-15
EOF

set_stage "contract_verify"
record_status "contract_verify" "all" "STARTED" "90-spec checked-in contract"
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_trainonly_mechanism_v1.R \
  --output "$STATE_ROOT/contract_verification.json" > "$STATE_ROOT/contract_verification.log" 2>&1
record_status "contract_verify" "all" "COMPLETED" "contract_verification.json"

COMMON=(
  "$R_SCRIPT" scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R
  --allow-grid-subset
  --methods mcmc
  --priors rhs_ns
  --no-plots
  --stream-child-stdout
  --fit-timeout-seconds 21600
  --fit-timeout-kill-after-seconds 60
)

for bundle in raw c12 c123 sr; do
  set_stage "${bundle}_prepare"
  record_status "prepare" "$bundle" "STARTED" "prepare-only"
  "${COMMON[@]}" --workers 1 \
    --defaults "${CONFIG_STUB}_${bundle}_defaults.yaml" \
    --grid "${CONFIG_STUB}_${bundle}_grid.csv" \
    --batch full --prepare-only \
    --run-tag "qdesn-tmv1-${bundle}-prepare-${STAMP}__git-${GIT_SHORT}" \
    > "$STATE_ROOT/${bundle}_prepare.log" 2>&1
  record_status "prepare" "$bundle" "COMPLETED" "no compute"

  set_stage "${bundle}_smoke"
  record_status "smoke" "$bundle" "STARTED" "one root; four burn plus four retained"
  smoke_tag="qdesn-tmv1-${bundle}-smoke-${STAMP}__git-${GIT_SHORT}"
  "${COMMON[@]}" --workers 1 \
    --defaults "${CONFIG_STUB}_${bundle}_defaults.yaml" \
    --grid "${CONFIG_STUB}_${bundle}_grid.csv" \
    --batch smoke --run-tag "$smoke_tag" \
    > "$STATE_ROOT/${bundle}_smoke.log" 2>&1
  smoke_root="results/qdesn_mcmc_validation/${STAGE}_${bundle}/${smoke_tag}"
  if ! check_storage_light "$smoke_root" "$STATE_ROOT/${bundle}_smoke_binary_payload_audit.tsv"; then
    record_status "smoke" "$bundle" "FAILED" "binary payload or missing root"
    exit 3
  fi
  record_status "smoke" "$bundle" "COMPLETED" "storage-light smoke passed"
done

set_stage "resource_gate"
wait_for_resources

declare -A CPUS WORKERS TAGS PIDS
CPUS[raw]="0-6"; WORKERS[raw]="7"; TAGS[raw]="$RAW_RUN_TAG"
CPUS[c12]="7-9"; WORKERS[c12]="3"; TAGS[c12]="$C12_RUN_TAG"
CPUS[c123]="10-12"; WORKERS[c123]="3"; TAGS[c123]="$C123_RUN_TAG"
CPUS[sr]="13-15"; WORKERS[sr]="3"; TAGS[sr]="$SR_RUN_TAG"

run_full_bundle() {
  local bundle="$1"
  record_status "full" "$bundle" "STARTED" "workers=${WORKERS[$bundle]};cpus=${CPUS[$bundle]};run_tag=${TAGS[$bundle]}"
  set +e
  taskset -c "${CPUS[$bundle]}" "${COMMON[@]}" --workers "${WORKERS[$bundle]}" \
    --defaults "${CONFIG_STUB}_${bundle}_defaults.yaml" \
    --grid "${CONFIG_STUB}_${bundle}_grid.csv" \
    --batch full --run-tag "${TAGS[$bundle]}" \
    > "$STATE_ROOT/${bundle}_full.log" 2>&1
  local rc="$?"
  set -e
  printf '%s\n' "$rc" > "$STATE_ROOT/${bundle}_exit_code.txt"
  if [[ "$rc" -eq 0 ]]; then
    record_status "full" "$bundle" "COMPLETED" "exit_code=0"
  else
    record_status "full" "$bundle" "FAILED" "exit_code=${rc}"
  fi
  return "$rc"
}

set_stage "full_parallel"
for bundle in raw c12 c123 sr; do
  run_full_bundle "$bundle" &
  PIDS[$bundle]="$!"
done

ANY_FAILED=0
set +e
for bundle in raw c12 c123 sr; do
  wait "${PIDS[$bundle]}"
  rc="$?"
  if [[ "$rc" -ne 0 ]]; then ANY_FAILED=1; fi
done
set -e

set_stage "storage_audit"
for bundle in raw c12 c123 sr; do
  run_root="results/qdesn_mcmc_validation/${STAGE}_${bundle}/${TAGS[$bundle]}"
  if check_storage_light "$run_root" "$STATE_ROOT/${bundle}_full_binary_payload_audit.tsv"; then
    record_status "storage_audit" "$bundle" "PASS" "no binary payloads"
  else
    record_status "storage_audit" "$bundle" "FAILED" "unexpected binary payload or missing run root"
    ANY_FAILED=1
  fi
done

set_stage "closeout"
set +e
"$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_trainonly_mechanism_v1.R \
  --state-root "$STATE_ROOT" --output-root "$STATE_ROOT/closeout" \
  > "$STATE_ROOT/closeout.log" 2>&1
AUDIT_RC="$?"
set -e
if [[ "$AUDIT_RC" -eq 0 ]]; then
  record_status "closeout" "all" "COMPLETED" "mechanism_gate.json"
else
  record_status "closeout" "all" "FAILED" "exit_code=${AUDIT_RC}"
  ANY_FAILED=1
fi

set_stage "pipeline_complete"
write_heartbeat
if [[ "$ANY_FAILED" -eq 0 ]]; then
  record_status "pipeline_complete" "all" "COMPLETED" "90-spec discovery closed; confirmation not launched"
  exit 0
fi
record_status "pipeline_complete" "all" "COMPLETED_WITH_FAILURES" "inspect per-bundle logs and closeout"
exit 1
