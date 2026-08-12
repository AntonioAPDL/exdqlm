#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/qdesn-lower-tail-cellwise-mcmc-v1-1.0.0"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
ADAPTIVE_ROOT="$STATE_ROOT/adaptive"
PLAN="$ADAPTIVE_ROOT/tier_a_replication_plan.csv"
WORKER="validation/fitforecast_v2/scripts/run_qdesn_lower_tail_cellwise_mcmc_v1_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_lower_tail_cellwise_mcmc_v1.R"
VERIFY_HANDOFF="validation/fitforecast_v2/scripts/verify_qdesn_lower_tail_cellwise_mcmc_v1_replication_handoff.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_qdesn_lower_tail_cellwise_mcmc_v1.R"
ADVANCE="validation/fitforecast_v2/scripts/advance_qdesn_lower_tail_cellwise_mcmc_v1.R"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_lower_tail_cellwise_mcmc_v1.lock"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
mkdir -p "$STATE_ROOT" "$ADAPTIVE_ROOT"
export QDESN_LTCV1_MATERIALIZATION_ROOT="$MATERIALIZATION_ROOT"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another lower-tail cellwise pipeline holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE"; }
record_status() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS_CSV"
}
resource_values() {
  local load1 memory_kb disk_kb idle_cpus cpu_count
  load1="$(awk '{print $1}' /proc/loadavg)"
  memory_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  disk_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
  cpu_count="$(getconf _NPROCESSORS_ONLN)"
  idle_cpus="$(ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$cpu_count" \
    -v limit="$MAX_IDLE_CPU_PERCENT" '
      {cpu=$1+0; used[cpu]+=$2+0}
      END {idle=0; for (i=0; i<n; i++) if ((used[i]+0) <= limit) idle++; print idle}
    ')"
  awk -v l="$load1" -v m="$memory_kb" -v d="$disk_kb" -v i="$idle_cpus" \
    'BEGIN {printf "%.2f %.1f %.1f %d", l, m/1048576, d/1048576, i}'
}
write_heartbeat() {
  local values stage
  values="$(resource_values)"
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "${values// /,}" >> "$HEARTBEAT_CSV"
}
heartbeat_loop() { while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done; }
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"; read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" \
      -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" -v i="$idle" -v w="$WORKERS" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md) && (i >= w))}'; then
      record_status replication_resource_gate PASS \
        "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return 0
    fi
    record_status replication_resource_gate WAIT \
      "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle};workers=${WORKERS}"
    sleep "$POLL_SECONDS"
  done
}
select_idle_cpus() {
  local count
  count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$count" '
    {cpu=$1+0; used[cpu]+=$2+0}
    END {for (i=0; i<n; i++) printf "%d %.6f\n", i, used[i]+0}
  ' | sort -k2,2n -k1,1n | awk -v workers="$WORKERS" -v limit="$MAX_IDLE_CPU_PERCENT" \
    '$2 <= limit && selected < workers {print $1; selected++}' | paste -sd, -
}
cleanup() {
  if [[ -n "${HEARTBEAT_PID:-}" ]] && kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
on_error() {
  local rc="$?" stage
  trap - ERR
  set +e
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf 'unknown')"
  record_status "$stage" FAILED "replication_pipeline_exit=${rc};inspect_stage_specific_logs"
  exit "$rc"
}
trap cleanup EXIT INT TERM
trap on_error ERR

[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || {
  echo "Launch refused outside $EXPECTED_BRANCH" >&2; exit 3;
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "Launch requires a clean worktree." >&2; git status --short >&2; exit 3;
}
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || {
  echo "Launch requires an upstream." >&2; exit 3;
}
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || {
  echo "Launch requires synchronized HEAD (behind=$BEHIND ahead=$AHEAD)." >&2; exit 3;
}
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 20 ]] || {
  echo "WORKERS must be between 1 and 20." >&2; exit 3;
}
[[ -f "$PLAN" ]] || { echo "Missing replication plan: $PLAN" >&2; exit 3; }

set_stage tier_a_replication_preflight
record_status tier_a_replication_preflight STARTED "discovery_gate;plan;source;seed;hash contracts"
"$R_SCRIPT" "$VERIFY_HANDOFF" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --output "$STATE_ROOT/tier_a_replication_handoff_verification.json" \
  > "$STATE_ROOT/tier_a_replication_handoff_verification.log" 2>&1
record_status tier_a_replication_preflight COMPLETED "24 roots;dev11;r02;storage-light"

heartbeat_loop & HEARTBEAT_PID="$!"
set_stage tier_a_replication_resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
[[ "$CPU_COUNT" -eq "$WORKERS" ]] || {
  record_status replication_cpu_selection FAILED \
    "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"; exit 3;
}
record_status replication_cpu_selection COMPLETED \
  "workers=${WORKERS};threads=1;cpus=${CPU_SET}"

set_stage tier_a_replication
CONFIG_LIST="$STATE_ROOT/tier_a_replication_configs.txt"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); writeLines(x$config_path)' \
  "$PLAN" > "$CONFIG_LIST"
JOBS="$(wc -l < "$CONFIG_LIST")"; PARALLELISM="$WORKERS"
[[ "$JOBS" -lt "$PARALLELISM" ]] && PARALLELISM="$JOBS"
record_status tier_a_replication STARTED \
  "jobs=${JOBS};parallelism=${PARALLELISM};threads_per_job=1;same_run_tag_resumes_completed_jobs"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$PARALLELISM" \
  "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
  < "$CONFIG_LIST" > "$STATE_ROOT/tier_a_replication_workers.log" 2>&1
RC="$?"
set -e
printf '%s\n' "$RC" > "$STATE_ROOT/tier_a_replication_worker_exit_code.txt"
"$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
  --plan "$PLAN" --output "$STATE_ROOT/tier_a_replication_health.csv" \
  > "$STATE_ROOT/tier_a_replication_health.log" 2>&1 || true
[[ "$RC" -eq 0 ]] || {
  record_status tier_a_replication FAILED \
    "worker_exit=${RC};same_run_tag_resumes_completed_jobs"; exit "$RC";
}
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --stage tier_a_replication \
  --plan "$PLAN" --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/tier_a_replication_verification.json" \
  > "$STATE_ROOT/tier_a_replication_verification.log" 2>&1
record_status tier_a_replication COMPLETED "jobs=${JOBS};finite_storage_light=all"

set_stage tier_a_replication_closeout
"$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from tier_a_replication \
  --run-tag "$RUN_TAG" --materialization-root "$MATERIALIZATION_ROOT" \
  --output-root "$ADAPTIVE_ROOT" \
  > "$STATE_ROOT/advance_after_tier_a_replication.log" 2>&1
record_status tier_a_replication_closeout COMPLETED \
  "paired rankings complete;72-job sealed plan materialized;not launched"
set_stage replication_complete
write_heartbeat
record_status replication_complete COMPLETED \
  "Tier-A replication closed;sealed evaluation waits for review;article v6 unchanged"
printf 'Lower-tail cellwise MCMC v1 replication complete: %s\n' "$RUN_TAG"
