#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
STAGE="${4:?STAGE is required: tier_a_replication or tier_a_sealed}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"

case "$STAGE" in
  tier_a_replication)
    EXPECTED_JOBS=20
    NEXT_DETAIL="sealed plan materialized;not launched"
    ;;
  tier_a_sealed)
    EXPECTED_JOBS=60
    NEXT_DETAIL="confirmation manifest materialized;explicit approval required"
    ;;
  *) echo "Unsupported stage: $STAGE" >&2; exit 2 ;;
esac

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/qdesn-postm0-legacy-recheck-v1-1.0.0"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
ADAPTIVE_ROOT="$STATE_ROOT/adaptive"
PLAN="$ADAPTIVE_ROOT/${STAGE}_plan.csv"
WORKER="validation/fitforecast_v2/scripts/run_qdesn_postm0_legacy_recheck_v1_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_postm0_legacy_recheck_v1.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_qdesn_postm0_legacy_recheck_v1.R"
ADVANCE="validation/fitforecast_v2/scripts/advance_qdesn_postm0_legacy_recheck_v1.R"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_postm0_legacy_recheck_v1.lock"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
mkdir -p "$ADAPTIVE_ROOT"
if [[ ! -s "$STATUS_CSV" ]]; then
  printf 'timestamp,stage,status,detail\n' > "$STATUS_CSV"
fi
if [[ ! -s "$HEARTBEAT_CSV" ]]; then
  printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' \
    > "$HEARTBEAT_CSV"
fi
export QDESN_PLRV1_MATERIALIZATION_ROOT="$MATERIALIZATION_ROOT"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another post-M0 legacy recheck holds the lock." >&2; exit 2; }
record_status() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" \
    >> "$STATUS_CSV"
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
  local values
  values="$(resource_values)"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$STAGE" "${values// /,}" \
    >> "$HEARTBEAT_CSV"
}
heartbeat_loop() {
  while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done
}
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"; read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" \
      -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" -v i="$idle" -v w="$WORKERS" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md) && (i >= w))}'; then
      return 0
    fi
    record_status "${STAGE}_resource_gate" WAIT \
      "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
    sleep "$POLL_SECONDS"
  done
}
select_idle_cpus() {
  local count
  count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$count" '
    {cpu=$1+0; used[cpu]+=$2+0}
    END {for (i=0; i<n; i++) printf "%d %.6f\n", i, used[i]+0}
  ' | sort -k2,2n -k1,1n | awk -v workers="$WORKERS" \
    -v limit="$MAX_IDLE_CPU_PERCENT" \
    '$2 <= limit && selected < workers {print $1; selected++}' | paste -sd, -
}

[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || {
  echo "Launch refused outside $EXPECTED_BRANCH" >&2; exit 3;
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "Launch requires a clean worktree." >&2; exit 3;
}
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || {
  echo "Launch requires an upstream." >&2; exit 3;
}
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || {
  echo "Launch requires synchronized HEAD." >&2; exit 3;
}
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 20 ]] || {
  echo "WORKERS must be between 1 and 20." >&2; exit 3;
}
[[ -f "$PLAN" ]] || { echo "Missing stage plan: $PLAN" >&2; exit 3; }
JOBS="$($R_SCRIPT -e 'cat(nrow(read.csv(commandArgs(TRUE)[1])))' "$PLAN")"
[[ "$JOBS" -eq "$EXPECTED_JOBS" ]] || {
  echo "Expected $EXPECTED_JOBS jobs, found $JOBS." >&2; exit 3;
}

heartbeat_loop &
HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

printf '%s\n' "$STAGE" > "$CURRENT_STAGE"
record_status "${STAGE}_preflight" PASS \
  "jobs=${JOBS};same_run_tag_resumes_completed_jobs;article_v6_frozen"
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
[[ "$CPU_COUNT" -eq "$WORKERS" ]] || {
  echo "Expected $WORKERS idle CPUs, found $CPU_COUNT." >&2; exit 3;
}
CONFIG_LIST="$STATE_ROOT/${STAGE}_configs.txt"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1]); writeLines(x$config_path)' \
  "$PLAN" > "$CONFIG_LIST"
record_status "$STAGE" STARTED \
  "jobs=${JOBS};workers=${WORKERS};threads_per_worker=1;cpus=${CPU_SET}"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$WORKERS" \
  "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
  < "$CONFIG_LIST" > "$STATE_ROOT/${STAGE}_workers.log" 2>&1
RC="$?"
set -e
"$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
  --plan "$PLAN" --output "$STATE_ROOT/${STAGE}_health.csv" \
  > "$STATE_ROOT/${STAGE}_health.log" 2>&1 || true
[[ "$RC" -eq 0 ]] || {
  record_status "$STAGE" FAILED "worker_exit=${RC};resume_same_run_tag"; exit "$RC";
}
if ! "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --stage "$STAGE" \
  --plan "$PLAN" --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/${STAGE}_verification.json"; then
  record_status "${STAGE}_verification" FAILED \
    "completed_jobs_preserved;repair_closeout_then_resume_same_run_tag"
  exit 4
fi
record_status "${STAGE}_verification" PASS \
  "jobs=${JOBS};runtime_and_recovery_contracts_pass"
if ! "$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from "$STAGE" \
  --run-tag "$RUN_TAG" --materialization-root "$MATERIALIZATION_ROOT" \
  --output-root "$ADAPTIVE_ROOT" > "$STATE_ROOT/advance_after_${STAGE}.log" 2>&1; then
  record_status "${STAGE}_advance" FAILED \
    "completed_jobs_preserved;inspect_advance_log;resume_same_run_tag"
  exit 5
fi
record_status "${STAGE}_advance" PASS "$NEXT_DETAIL"
record_status "$STAGE" COMPLETED "$NEXT_DETAIL"
printf 'Post-M0 legacy recheck stage complete: %s (%s)\n' "$STAGE" "$RUN_TAG"
