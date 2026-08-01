#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
WORKERS="${2:-8}"
RUN_ID="${3:-qdesn_alpha_rho_cellwise_v2_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
NCORES="$(nproc)"
MAX_LOAD="${MAX_LOAD:-$((NCORES - WORKERS - 4))}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-180}"
MIN_DISK_GB="${MIN_DISK_GB:-300}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"

cd "$REPO_ROOT"
STAGE_STUB="qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
CONFIG_STUB="config/validation/${STAGE_STUB}"
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
  awk -v ld="$load1" -v memory="$memory_kb" -v disk="$disk_kb" 'BEGIN {printf "%.2f %.1f %.1f", ld, memory/1048576, disk/1048576}'
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

cleanup() {
  stop_heartbeat
}
trap cleanup EXIT INT TERM

wait_for_resources() {
  while true; do
    local values load memory disk
    values="$(resource_values)"
    read -r load memory disk <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" 'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md))}'; then
      record_status "RESOURCE_GATE_PASS" "load=${load};max_load=${MAX_LOAD};memory_gb=${memory};disk_gb=${disk};workers=${WORKERS}"
      return 0
    fi
    record_status "RESOURCE_GATE_WAIT" "load=${load};max_load=${MAX_LOAD};memory_gb=${memory};disk_gb=${disk};workers=${WORKERS}"
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
  find "$run_root" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) -printf '%s\t%p\n' | sort -nr > "$evidence_path"
  if [[ -s "$evidence_path" ]]; then
    record_status "STORAGE_POLICY_FAIL" "unexpected_binary_payloads=${evidence_path}"
    return 1
  fi
  record_status "STORAGE_POLICY_PASS" "no_binary_payloads_under=${run_root}"
}

if [[ "${PIPELINE_SELF_TEST:-0}" == "1" ]]; then
  CURRENT_STAGE="orchestration_self_test"
  VALUES="$(resource_values)"
  write_heartbeat
  record_status "COMPLETED" "resource_values=${VALUES// /;}"
  printf 'PIPELINE_SELF_TEST_OK %s max_load=%s workers=%s\n' "$VALUES" "$MAX_LOAD" "$WORKERS"
  exit 0
fi

GIT_SHORT="$(git rev-parse --short HEAD)"
STAMP="$(date +%Y%m%d_%H%M%S)"
COARSE_PREP_TAG="qdesn-arv2-coarse-prepare-${STAMP}__git-${GIT_SHORT}"
COARSE_SMOKE_TAG="qdesn-arv2-coarse-smoke-${STAMP}__git-${GIT_SHORT}"
COARSE_RUN_TAG="qdesn-arv2-coarse-full-${STAMP}__git-${GIT_SHORT}"
REFINEMENT_SMOKE_TAG="qdesn-arv2-refinement-smoke-${STAMP}__git-${GIT_SHORT}"
REFINEMENT_RUN_TAG="qdesn-arv2-refinement-full-${STAMP}__git-${GIT_SHORT}"

cat > "$STATE_ROOT/run_tags.env" <<EOF
RUN_ID=$RUN_ID
COARSE_PREP_TAG=$COARSE_PREP_TAG
COARSE_SMOKE_TAG=$COARSE_SMOKE_TAG
COARSE_RUN_TAG=$COARSE_RUN_TAG
REFINEMENT_SMOKE_TAG=$REFINEMENT_SMOKE_TAG
REFINEMENT_RUN_TAG=$REFINEMENT_RUN_TAG
GIT_COMMIT=$(git rev-parse HEAD)
WORKERS=$WORKERS
MAX_LOAD=$MAX_LOAD
EOF

COMMON=(
  "$R_SCRIPT" scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R
  --allow-grid-subset
  --methods mcmc
  --priors rhs_ns
  --workers "$WORKERS"
  --no-plots
  --stream-child-stdout
  --fit-timeout-seconds 7200
  --fit-timeout-kill-after-seconds 60
)

CURRENT_STAGE="coarse_prepare"
run_logged "$STATE_ROOT/coarse_prepare.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_coarse_defaults.yaml" \
  --grid "${CONFIG_STUB}_coarse_grid.csv" \
  --batch full --prepare-only --run-tag "$COARSE_PREP_TAG"

CURRENT_STAGE="coarse_smoke"
run_logged "$STATE_ROOT/coarse_smoke.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_coarse_defaults.yaml" \
  --grid "${CONFIG_STUB}_coarse_grid.csv" \
  --batch smoke --run-tag "$COARSE_SMOKE_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_coarse/${COARSE_SMOKE_TAG}" \
  "$STATE_ROOT/coarse_smoke_binary_payload_audit.tsv"

CURRENT_STAGE="coarse_resource_gate"
wait_for_resources
CURRENT_STAGE="coarse_full"
run_logged "$STATE_ROOT/coarse_full.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_coarse_defaults.yaml" \
  --grid "${CONFIG_STUB}_coarse_grid.csv" \
  --batch full --run-tag "$COARSE_RUN_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_coarse/${COARSE_RUN_TAG}" \
  "$STATE_ROOT/coarse_full_binary_payload_audit.tsv"

CURRENT_STAGE="coarse_audit"
COARSE_AUDIT_ROOT="$STATE_ROOT/coarse_audit"
run_logged "$STATE_ROOT/coarse_audit.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_alpha_rho_cellwise_v2.R \
  --phase coarse --run-tag "$COARSE_RUN_TAG" --output-root "$COARSE_AUDIT_ROOT"
COARSE_DECISION="$($R_SCRIPT -e 'x <- jsonlite::read_json(commandArgs(TRUE)[1]); cat(x$decision)' "$COARSE_AUDIT_ROOT/coarse_gate.json")"
record_status "GATE_DECISION" "$COARSE_DECISION"

if [[ "$COARSE_DECISION" != "GO_REFINEMENT" ]]; then
  CURRENT_STAGE="pipeline_stopped_by_coarse_gate"
  record_status "COMPLETED" "coarse_decision=${COARSE_DECISION};refinement_not_launched"
  exit 0
fi

REFINEMENT_DEFAULTS="$COARSE_AUDIT_ROOT/refinement_defaults.yaml"
REFINEMENT_GRID="$COARSE_AUDIT_ROOT/refinement_grid.csv"
REFINEMENT_EXPECTED="$($R_SCRIPT -e 'x <- jsonlite::read_json(commandArgs(TRUE)[1]); cat(x$expected_refinement_specs)' "$COARSE_AUDIT_ROOT/coarse_gate.json")"
printf 'REFINEMENT_EXPECTED=%s\n' "$REFINEMENT_EXPECTED" >> "$STATE_ROOT/run_tags.env"

CURRENT_STAGE="refinement_prepare"
run_logged "$STATE_ROOT/refinement_prepare.log" \
  "${COMMON[@]}" \
  --defaults "$REFINEMENT_DEFAULTS" \
  --grid "$REFINEMENT_GRID" \
  --batch full --prepare-only --run-tag "${REFINEMENT_RUN_TAG}-prepare"

CURRENT_STAGE="refinement_smoke"
run_logged "$STATE_ROOT/refinement_smoke.log" \
  "${COMMON[@]}" \
  --defaults "$REFINEMENT_DEFAULTS" \
  --grid "$REFINEMENT_GRID" \
  --batch smoke --run-tag "$REFINEMENT_SMOKE_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_refinement/${REFINEMENT_SMOKE_TAG}" \
  "$STATE_ROOT/refinement_smoke_binary_payload_audit.tsv"

CURRENT_STAGE="refinement_resource_gate"
wait_for_resources
CURRENT_STAGE="refinement_full"
run_logged "$STATE_ROOT/refinement_full.log" \
  "${COMMON[@]}" \
  --defaults "$REFINEMENT_DEFAULTS" \
  --grid "$REFINEMENT_GRID" \
  --batch full --run-tag "$REFINEMENT_RUN_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_refinement/${REFINEMENT_RUN_TAG}" \
  "$STATE_ROOT/refinement_full_binary_payload_audit.tsv"

CURRENT_STAGE="refinement_audit"
run_logged "$STATE_ROOT/refinement_audit.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_alpha_rho_cellwise_v2.R \
  --phase refinement --run-tag "$REFINEMENT_RUN_TAG" \
  --coarse-audit-root "$COARSE_AUDIT_ROOT" \
  --output-root "$STATE_ROOT/refinement_audit"
REFINEMENT_DECISION="$($R_SCRIPT -e 'x <- jsonlite::read_json(commandArgs(TRUE)[1]); cat(x$decision)' "$STATE_ROOT/refinement_audit/refinement_gate.json")"
record_status "GATE_DECISION" "$REFINEMENT_DECISION"

CURRENT_STAGE="pipeline_complete"
record_status "COMPLETED" "refinement_decision=${REFINEMENT_DECISION};full_budget_confirmation_not_launched"
write_heartbeat
