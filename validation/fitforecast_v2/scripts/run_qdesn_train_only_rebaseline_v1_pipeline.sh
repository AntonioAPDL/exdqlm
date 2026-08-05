#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
WORKERS="${2:-20}"
RUN_ID="${3:-qdesn_trainonly_rebaseline_v1_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
NCORES="$(nproc)"
MAX_LOAD="${MAX_LOAD:-$((NCORES - WORKERS - 8))}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-128}"
MIN_DISK_GB="${MIN_DISK_GB:-100}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
STALE_THRESHOLD_SECONDS="${STALE_THRESHOLD_SECONDS:-1800}"
FIT_TIMEOUT_SECONDS="${FIT_TIMEOUT_SECONDS:-604800}"

if [[ "${FULL_TRAINONLY_REBASELINE_APPROVED:-0}" != "1" ]]; then
  printf 'Full rebaseline requires FULL_TRAINONLY_REBASELINE_APPROVED=1.\n' >&2
  exit 2
fi
if [[ "$WORKERS" -lt 1 || "$WORKERS" -gt 24 ]]; then
  printf 'WORKERS must be between 1 and 24.\n' >&2
  exit 2
fi
if [[ ! -x "$R_SCRIPT" ]]; then
  printf 'R 4.6.0 executable is missing: %s\n' "$R_SCRIPT" >&2
  exit 2
fi

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

cd "$REPO_ROOT"
STAGE="qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
STUB="config/validation/${STAGE}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
printf 'timestamp,stage,status,detail\n' > "$STATUS_CSV"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "$HEARTBEAT_CSV"

CURRENT_STAGE="initializing"
HEARTBEAT_PID=""
record_status() {
  local status="$1"
  local detail="$2"
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$CURRENT_STAGE" "$status" "${detail//,/;}" >> "$STATUS_CSV"
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
  local values
  values="$(resource_values)"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$CURRENT_STAGE" "${values// /,}" >> "$HEARTBEAT_CSV"
}
heartbeat_loop() {
  while true; do
    write_heartbeat
    sleep "$HEARTBEAT_SECONDS"
  done
}
start_heartbeat() {
  heartbeat_loop &
  HEARTBEAT_PID="$!"
}
stop_heartbeat() {
  if [[ -n "$HEARTBEAT_PID" ]] && kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
  HEARTBEAT_PID=""
}
trap stop_heartbeat EXIT INT TERM

wait_for_resources() {
  while true; do
    local values load memory disk
    values="$(resource_values)"
    read -r load memory disk <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" \
      -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md))}'; then
      record_status "RESOURCE_GATE_PASS" \
        "load=${load};max_load=${MAX_LOAD};memory_gb=${memory};disk_gb=${disk};workers=${WORKERS}"
      return 0
    fi
    record_status "RESOURCE_GATE_WAIT" \
      "load=${load};max_load=${MAX_LOAD};memory_gb=${memory};disk_gb=${disk};workers=${WORKERS}"
    sleep "$POLL_SECONDS"
  done
}
run_logged() {
  local log_path="$1"
  shift
  record_status "STARTED" "log=${log_path}"
  start_heartbeat
  set +e
  "$@" 2>&1 | tee "$log_path"
  local exit_code="${PIPESTATUS[0]}"
  set -e
  stop_heartbeat
  if [[ "$exit_code" -ne 0 ]]; then
    record_status "FAILED" "exit_code=${exit_code};log=${log_path}"
    exit "$exit_code"
  fi
  record_status "COMPLETED" "log=${log_path}"
}
check_storage_light() {
  local run_root="$1"
  local evidence_path="$2"
  if [[ ! -d "$run_root" ]]; then
    printf 'run_root_missing\n' > "$evidence_path"
    return 1
  fi
  find "$run_root" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) \
    -printf '%s\t%p\n' | sort -nr > "$evidence_path"
  if [[ -s "$evidence_path" ]]; then
    record_status "STORAGE_POLICY_FAIL" "unexpected_binary_payloads=${evidence_path}"
    return 1
  fi
  record_status "STORAGE_POLICY_PASS" "no_binary_payloads_under=${run_root}"
}

if [[ "${PIPELINE_SELF_TEST:-0}" == "1" ]]; then
  CURRENT_STAGE="orchestration_self_test"
  write_heartbeat
  record_status "COMPLETED" \
    "workers=${WORKERS};max_load=${MAX_LOAD};heartbeat=${HEARTBEAT_SECONDS};stale=${STALE_THRESHOLD_SECONDS}"
  printf 'PIPELINE_SELF_TEST_OK workers=%s max_load=%s\n' "$WORKERS" "$MAX_LOAD"
  exit 0
fi

for required in \
  "${STUB}_defaults.yaml" \
  "${STUB}_grid.csv" \
  "${STUB}_target_spec_ids.csv" \
  "${STUB}_smoke_defaults.yaml" \
  "${STUB}_smoke_grid.csv" \
  "${STUB}_smoke_target_spec_ids.csv" \
  "${STUB}_materialization_manifest.json"; do
  [[ -f "$required" ]] || { printf 'Missing materialized contract: %s\n' "$required" >&2; exit 2; }
done

GIT_COMMIT="$(git rev-parse HEAD)"
GIT_SHORT="$(git rev-parse --short HEAD)"
STAMP="$(date +%Y%m%d_%H%M%S)"
PREP_TAG="qdesn-trainonly-v1-prepare-${STAMP}__git-${GIT_SHORT}"
SMOKE_TAG="qdesn-trainonly-v1-smoke-${STAMP}__git-${GIT_SHORT}"
FULL_TAG="qdesn-trainonly-v1-full-${STAMP}__git-${GIT_SHORT}"
TARGET_SPEC_IDS="$($R_SCRIPT -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); cat(paste(x$spec_id, collapse=","))' "${STUB}_target_spec_ids.csv")"
SMOKE_SPEC_IDS="$($R_SCRIPT -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); cat(paste(x$spec_id, collapse=","))' "${STUB}_smoke_target_spec_ids.csv")"

cat > "$STATE_ROOT/run_tags.env" <<EOF
RUN_ID=$RUN_ID
PREP_TAG=$PREP_TAG
SMOKE_TAG=$SMOKE_TAG
FULL_TAG=$FULL_TAG
GIT_COMMIT=$GIT_COMMIT
WORKERS=$WORKERS
MAX_LOAD=$MAX_LOAD
HEARTBEAT_SECONDS=$HEARTBEAT_SECONDS
STALE_THRESHOLD_SECONDS=$STALE_THRESHOLD_SECONDS
EOF

COMMON=(
  "$R_SCRIPT" scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R
  --allow-grid-subset
  --methods mcmc
  --likelihoods al,exal
  --priors rhs_ns
  --no-plots
  --stream-child-stdout
  --fit-timeout-seconds "$FIT_TIMEOUT_SECONDS"
  --fit-timeout-kill-after-seconds 60
)

CURRENT_STAGE="source_verification"
run_logged "$STATE_ROOT/source_verification.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_train_only_rebaseline_contract.R \
  --output "$STATE_ROOT/source_verification.json"

CURRENT_STAGE="prepare"
run_logged "$STATE_ROOT/prepare.log" \
  "${COMMON[@]}" \
  --workers "$WORKERS" \
  --defaults "${STUB}_defaults.yaml" \
  --grid "${STUB}_grid.csv" \
  --spec-ids "$TARGET_SPEC_IDS" \
  --batch full --prepare-only --run-tag "$PREP_TAG"

CURRENT_STAGE="smoke"
run_logged "$STATE_ROOT/smoke.log" \
  "${COMMON[@]}" \
  --workers 2 \
  --defaults "${STUB}_smoke_defaults.yaml" \
  --grid "${STUB}_smoke_grid.csv" \
  --spec-ids "$SMOKE_SPEC_IDS" \
  --batch full --run-tag "$SMOKE_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE}_smoke/${SMOKE_TAG}" \
  "$STATE_ROOT/smoke_binary_payload_audit.tsv"

CURRENT_STAGE="smoke_audit"
run_logged "$STATE_ROOT/smoke_audit.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_train_only_rebaseline_smoke.R \
  --run-tag "$SMOKE_TAG" --output-root "$STATE_ROOT/smoke_audit"

CURRENT_STAGE="full_resource_gate"
wait_for_resources
CURRENT_STAGE="full"
run_logged "$STATE_ROOT/full.log" \
  "${COMMON[@]}" \
  --workers "$WORKERS" \
  --defaults "${STUB}_defaults.yaml" \
  --grid "${STUB}_grid.csv" \
  --spec-ids "$TARGET_SPEC_IDS" \
  --batch full --run-tag "$FULL_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE}/${FULL_TAG}" \
  "$STATE_ROOT/full_binary_payload_audit.tsv"

CURRENT_STAGE="closeout"
run_logged "$STATE_ROOT/closeout.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/closeout_qdesn_train_only_rebaseline_v1.R \
  --run-tag "$FULL_TAG" --output-root "$STATE_ROOT/closeout"
DECISION="$($R_SCRIPT -e 'x <- jsonlite::read_json(commandArgs(TRUE)[1]); cat(x$decision)' "$STATE_ROOT/closeout/rebaseline_gate.json")"
record_status "GATE_DECISION" "$DECISION"

CURRENT_STAGE="pipeline_complete"
record_status "COMPLETED" "decision=${DECISION};article_not_automatically_updated"
write_heartbeat
