#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_mcmc_highalpha_cellwise_v1_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MAX_LOAD="${MAX_LOAD:-40}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-96}"
MIN_DISK_GB="${MIN_DISK_GB:-250}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
WORKERS=20

cd "$REPO_ROOT"
STAGE="qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1"
CONFIG_STUB="config/validation/${STAGE}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE_FILE="$STATE_ROOT/current_stage.txt"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_mcmc_highalpha_cellwise_v1.lock"
printf 'timestamp,stage,status,detail\n' > "$STATUS_CSV"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "$HEARTBEAT_CSV"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another high-alpha cellwise v1 pipeline holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() {
  printf '%s\n' "$1" > "$CURRENT_STAGE_FILE"
}

record_status() {
  local stage="$1"
  local status="$2"
  local detail="$3"
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "$status" "${detail//,/;}" >> "$STATUS_CSV"
}

resource_values() {
  local load1 memory_kb disk_kb
  load1="$(awk '{print $1}' /proc/loadavg)"
  memory_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  disk_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
  awk -v ld="$load1" -v memory="$memory_kb" -v disk="$disk_kb" \
    'BEGIN {printf "%.2f %.1f %.1f", ld, memory/1048576, disk/1048576}'
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
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md))}'; then
      record_status "resource_gate" "PASS" "load=${load};memory_gb=${memory};disk_gb=${disk}"
      return 0
    fi
    record_status "resource_gate" "WAIT" "load=${load};memory_gb=${memory};disk_gb=${disk}"
    sleep "$POLL_SECONDS"
  done
}

select_idle_cpus() {
  local count
  # GNU nproc honors OMP_NUM_THREADS; use the online host count after thread caps are set.
  count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$count" '
    {cpu=$1+0; used[cpu]+=$2+0}
    END {for (i=0; i<n; i++) printf "%d %.6f\n", i, used[i]+0}
  ' | sort -k2,2n -k1,1n | awk -v workers="$WORKERS" 'NR <= workers {print $1}' | paste -sd, -
}

storage_audit() {
  local root="$1"
  local output="$2"
  if [[ ! -d "$root" ]]; then
    printf 'run_root_missing\n' > "$output"
    return 1
  fi
  find "$root" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) -printf '%s\t%p\n' | sort -nr > "$output"
  [[ ! -s "$output" ]]
}

BRANCH="$(git branch --show-current)"
EXPECTED_BRANCH="validation/qdesn-mcmc-highalpha-cellwise-v1-1.0.0"
if [[ "$BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "Wrong branch: $BRANCH" >&2
  exit 3
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Launch requires a clean worktree." >&2
  git status --short >&2
  exit 3
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Launch requires a configured upstream." >&2
  exit 3
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch requires HEAD to match its upstream (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 3
fi

GIT_SHA="$(git rev-parse HEAD)"
GIT_SHORT="$(git rev-parse --short HEAD)"
STAMP="$(date +%Y%m%d_%H%M%S)"
WAVE1_RUN_TAG="qdesn-hacv1-wave1-${STAMP}__git-${GIT_SHORT}"
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  echo "Expected 20 selected CPUs; found $CPU_COUNT in '$CPU_SET'." >&2
  exit 3
fi
cat > "$STATE_ROOT/run_tags.env" <<EOF
RUN_ID=$RUN_ID
WAVE1_RUN_TAG=$WAVE1_RUN_TAG
GIT_COMMIT=$GIT_SHA
WORKTREE=$REPO_ROOT
TOTAL_WORKERS=$WORKERS
THREADS_PER_WORKER=1
CPU_SET=$CPU_SET
WAVE2_APPROVED=FALSE
FULL_CONFIRMATION_APPROVED=FALSE
EOF

COMMON=(
  "$R_SCRIPT" scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R
  --allow-grid-subset
  --methods mcmc
  --priors rhs_ns
  --no-plots
  --stream-child-stdout
  --fit-timeout-seconds 43200
  --fit-timeout-kill-after-seconds 60
)

set_stage "contract_verify"
record_status "contract_verify" "STARTED" "branch=${BRANCH};commit=${GIT_SHA}"
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_mcmc_highalpha_cellwise_v1.R \
  --output "$STATE_ROOT/contract_verification.json" > "$STATE_ROOT/contract_verification.log" 2>&1
record_status "contract_verify" "COMPLETED" "372 Wave 1 specs; Wave 2 gated"

set_stage "prepare_only"
PREPARE_TAG="qdesn-hacv1-wave1-prepare-${STAMP}__git-${GIT_SHORT}"
record_status "prepare_only" "STARTED" "$PREPARE_TAG"
"${COMMON[@]}" --workers 1 \
  --defaults "${CONFIG_STUB}_wave1_defaults.yaml" \
  --grid "${CONFIG_STUB}_wave1_grid.csv" \
  --batch full --prepare-only --run-tag "$PREPARE_TAG" \
  > "$STATE_ROOT/prepare_only.log" 2>&1
find "results/qdesn_mcmc_validation/${STAGE}_wave1" -path "*${PREPARE_TAG}*" -type f \
  \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) -print > "$STATE_ROOT/prepare_only_binary_payload_audit.txt" 2>/dev/null || true
if [[ -s "$STATE_ROOT/prepare_only_binary_payload_audit.txt" ]]; then
  record_status "prepare_only" "FAILED" "forbidden binary payload"
  exit 4
fi
record_status "prepare_only" "COMPLETED" "no inference; no binary payload"

set_stage "smoke"
SMOKE_TAG="qdesn-hacv1-wave1-smoke-${STAMP}__git-${GIT_SHORT}"
record_status "smoke" "STARTED" "$SMOKE_TAG"
"${COMMON[@]}" --workers 1 \
  --defaults "${CONFIG_STUB}_wave1_defaults.yaml" \
  --grid "${CONFIG_STUB}_wave1_grid.csv" \
  --batch smoke --run-tag "$SMOKE_TAG" \
  > "$STATE_ROOT/smoke.log" 2>&1
SMOKE_ROOT="results/qdesn_mcmc_validation/${STAGE}_wave1/${SMOKE_TAG}"
if ! storage_audit "$SMOKE_ROOT" "$STATE_ROOT/smoke_binary_payload_audit.tsv"; then
  record_status "smoke" "FAILED" "missing run root or forbidden binary payload"
  exit 4
fi
record_status "smoke" "COMPLETED" "4 burn + 4 retained; storage-light"

set_stage "resource_gate"
wait_for_resources
record_status "cpu_selection" "COMPLETED" "workers=20;threads=1;cpus=${CPU_SET}"

set_stage "wave1_full"
record_status "wave1_full" "STARTED" "run_tag=${WAVE1_RUN_TAG};workers=20;cpus=${CPU_SET}"
set +e
taskset -c "$CPU_SET" "${COMMON[@]}" --workers "$WORKERS" \
  --defaults "${CONFIG_STUB}_wave1_defaults.yaml" \
  --grid "${CONFIG_STUB}_wave1_grid.csv" \
  --batch full --run-tag "$WAVE1_RUN_TAG" \
  > "$STATE_ROOT/wave1_full.log" 2>&1
WAVE1_RC="$?"
set -e
printf '%s\n' "$WAVE1_RC" > "$STATE_ROOT/wave1_exit_code.txt"
if [[ "$WAVE1_RC" -eq 0 ]]; then
  record_status "wave1_full" "COMPLETED" "exit_code=0"
else
  record_status "wave1_full" "COMPLETED_WITH_FAILURES" "exit_code=${WAVE1_RC};audit finite outputs"
fi

set_stage "storage_audit"
WAVE1_ROOT="results/qdesn_mcmc_validation/${STAGE}_wave1/${WAVE1_RUN_TAG}"
STORAGE_OK=1
if storage_audit "$WAVE1_ROOT" "$STATE_ROOT/wave1_binary_payload_audit.tsv"; then
  record_status "storage_audit" "PASS" "no model .rds/.rda/.RData payloads"
else
  record_status "storage_audit" "FAILED" "missing run root or forbidden binary payload"
  STORAGE_OK=0
fi

set_stage "closeout"
set +e
"$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_mcmc_highalpha_cellwise_v1.R \
  --state-root "$STATE_ROOT" --output-root "$STATE_ROOT/closeout" \
  > "$STATE_ROOT/closeout.log" 2>&1
AUDIT_RC="$?"
set -e
if [[ "$AUDIT_RC" -eq 0 ]]; then
  record_status "closeout" "COMPLETED" "highalpha_wave1_gate.json"
else
  record_status "closeout" "FAILED" "exit_code=${AUDIT_RC}"
fi

set_stage "pipeline_complete"
write_heartbeat
if [[ "$WAVE1_RC" -eq 0 && "$STORAGE_OK" -eq 1 && "$AUDIT_RC" -eq 0 ]]; then
  record_status "pipeline_complete" "COMPLETED" "Wave 1 closed; Wave 2 and full confirmation remain gated"
  exit 0
fi
record_status "pipeline_complete" "COMPLETED_WITH_FAILURES" "inspect Wave 1 finite evidence; no automatic continuation"
exit 1
