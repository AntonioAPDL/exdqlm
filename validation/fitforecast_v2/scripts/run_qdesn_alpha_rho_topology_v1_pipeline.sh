#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
WORKERS="${2:-16}"
RUN_ID="${3:-qdesn_alpha_rho_topology_v1_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MAX_LOAD="${MAX_LOAD:-42}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-180}"
MIN_DISK_GB="${MIN_DISK_GB:-300}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"

cd "$REPO_ROOT"
STAGE_STUB="qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_topology_v1"
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
  awk -v load="$load1" -v memory="$memory_kb" -v disk="$disk_kb" 'BEGIN {printf "%.2f %.1f %.1f", load, memory/1048576, disk/1048576}'
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
      record_status "RESOURCE_GATE_PASS" "load=${load};memory_gb=${memory};disk_gb=${disk}"
      return 0
    fi
    record_status "RESOURCE_GATE_WAIT" "load=${load};memory_gb=${memory};disk_gb=${disk}"
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

GIT_SHORT="$(git rev-parse --short HEAD)"
STAMP="$(date +%Y%m%d_%H%M%S)"
MECHANISM_PREP_TAG="qdesn-arv1-mechanism-prepare-${STAMP}__git-${GIT_SHORT}"
MECHANISM_SMOKE_TAG="qdesn-arv1-mechanism-smoke-${STAMP}__git-${GIT_SHORT}"
MECHANISM_RUN_TAG="qdesn-arv1-mechanism-full-${STAMP}__git-${GIT_SHORT}"
BROAD_SMOKE_TAG="qdesn-arv1-broad-smoke-${STAMP}__git-${GIT_SHORT}"
BROAD_RUN_TAG="qdesn-arv1-broad-full-${STAMP}__git-${GIT_SHORT}"

cat > "$STATE_ROOT/run_tags.env" <<EOF
RUN_ID=$RUN_ID
MECHANISM_PREP_TAG=$MECHANISM_PREP_TAG
MECHANISM_SMOKE_TAG=$MECHANISM_SMOKE_TAG
MECHANISM_RUN_TAG=$MECHANISM_RUN_TAG
BROAD_SMOKE_TAG=$BROAD_SMOKE_TAG
BROAD_RUN_TAG=$BROAD_RUN_TAG
GIT_COMMIT=$(git rev-parse HEAD)
WORKERS=$WORKERS
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

CURRENT_STAGE="mechanism_prepare"
run_logged "$STATE_ROOT/mechanism_prepare.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_mechanism_defaults.yaml" \
  --grid "${CONFIG_STUB}_mechanism_grid.csv" \
  --batch full --prepare-only --run-tag "$MECHANISM_PREP_TAG"

CURRENT_STAGE="mechanism_smoke"
run_logged "$STATE_ROOT/mechanism_smoke.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_mechanism_defaults.yaml" \
  --grid "${CONFIG_STUB}_mechanism_grid.csv" \
  --batch smoke --run-tag "$MECHANISM_SMOKE_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_mechanism/${MECHANISM_SMOKE_TAG}" \
  "$STATE_ROOT/mechanism_smoke_binary_payload_audit.tsv"

CURRENT_STAGE="mechanism_resource_gate"
wait_for_resources
CURRENT_STAGE="mechanism_full"
run_logged "$STATE_ROOT/mechanism_full.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_mechanism_defaults.yaml" \
  --grid "${CONFIG_STUB}_mechanism_grid.csv" \
  --batch full --run-tag "$MECHANISM_RUN_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_mechanism/${MECHANISM_RUN_TAG}" \
  "$STATE_ROOT/mechanism_full_binary_payload_audit.tsv"

CURRENT_STAGE="mechanism_audit"
MECHANISM_AUDIT_ROOT="$STATE_ROOT/mechanism_audit"
run_logged "$STATE_ROOT/mechanism_audit.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_alpha_rho_topology_v1.R \
  --phase mechanism --run-tag "$MECHANISM_RUN_TAG" --output-root "$MECHANISM_AUDIT_ROOT"
MECHANISM_DECISION="$($R_SCRIPT -e 'x <- jsonlite::read_json(commandArgs(TRUE)[1]); cat(x$decision)' "$MECHANISM_AUDIT_ROOT/mechanism_gate.json")"
record_status "GATE_DECISION" "$MECHANISM_DECISION"

if [[ "$MECHANISM_DECISION" != "GO_BROAD" ]]; then
  CURRENT_STAGE="pipeline_stopped_by_gate"
  record_status "COMPLETED" "mechanism_decision=${MECHANISM_DECISION};broad_not_launched"
  exit 0
fi

CURRENT_STAGE="broad_prepare"
run_logged "$STATE_ROOT/broad_prepare.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_broad_defaults.yaml" \
  --grid "${CONFIG_STUB}_broad_grid.csv" \
  --batch full --prepare-only --run-tag "${BROAD_RUN_TAG}-prepare"

CURRENT_STAGE="broad_smoke"
run_logged "$STATE_ROOT/broad_smoke.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_broad_defaults.yaml" \
  --grid "${CONFIG_STUB}_broad_grid.csv" \
  --batch smoke --run-tag "$BROAD_SMOKE_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_broad/${BROAD_SMOKE_TAG}" \
  "$STATE_ROOT/broad_smoke_binary_payload_audit.tsv"

CURRENT_STAGE="broad_resource_gate"
wait_for_resources
CURRENT_STAGE="broad_full"
run_logged "$STATE_ROOT/broad_full.log" \
  "${COMMON[@]}" \
  --defaults "${CONFIG_STUB}_broad_defaults.yaml" \
  --grid "${CONFIG_STUB}_broad_grid.csv" \
  --batch full --run-tag "$BROAD_RUN_TAG"
check_storage_light \
  "results/qdesn_mcmc_validation/${STAGE_STUB}_broad/${BROAD_RUN_TAG}" \
  "$STATE_ROOT/broad_full_binary_payload_audit.tsv"

CURRENT_STAGE="broad_audit"
run_logged "$STATE_ROOT/broad_audit.log" \
  "$R_SCRIPT" validation/fitforecast_v2/scripts/audit_qdesn_alpha_rho_topology_v1.R \
  --phase broad --run-tag "$BROAD_RUN_TAG" \
  --baseline-metrics "$MECHANISM_AUDIT_ROOT/mechanism_metrics.csv" \
  --output-root "$STATE_ROOT/broad_audit"

CURRENT_STAGE="pipeline_complete"
record_status "COMPLETED" "mechanism_and_broad_audits_finished;full_budget_confirmation_not_launched"
write_heartbeat
