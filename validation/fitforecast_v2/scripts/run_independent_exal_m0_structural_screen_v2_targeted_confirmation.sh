#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-6}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
SCREEN_ID="independent_exal_m0_structural_screen_v2_capacity_repair_20260810_040208"
SCREEN_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$SCREEN_ID/adaptive_recovery_selector_v3"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
RESULT_ROOT="$REPO_ROOT/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2/$RUN_TAG"
MATERIALIZE="validation/fitforecast_v2/scripts/materialize_independent_exal_m0_structural_screen_v2_targeted_confirmation.R"
VERIFY="validation/fitforecast_v2/scripts/verify_independent_exal_m0_structural_screen_v2_targeted_confirmation.R"
WORKER="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R"
CLOSEOUT="validation/fitforecast_v2/scripts/closeout_independent_exal_m0_structural_screen_v2_targeted_confirmation.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_structural_screen_v2.R"
LOCK_FILE="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_structural_v2_targeted_confirmation.lock"

cd "$REPO_ROOT"
[[ "${TARGETED_CONFIRMATION_APPROVED:-false}" == "true" ]] || {
  echo "TARGETED_CONFIRMATION_APPROVED=true is required." >&2; exit 3;
}
[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || { echo "Wrong branch" >&2; exit 3; }
[[ -z "$(git status --porcelain)" ]] || { echo "A clean worktree is required" >&2; exit 3; }
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || { echo "Synchronized HEAD is required" >&2; exit 3; }
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 6 ]] || { echo "WORKERS must be 1..6" >&2; exit 3; }

mkdir -p "$STATE_ROOT"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another targeted confirmation is active" >&2; exit 3; }
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
STATUS="$STATE_ROOT/stage_status.csv"; CURRENT="$STATE_ROOT/current_stage.txt"
HEARTBEAT="$STATE_ROOT/heartbeat.csv"
printf 'timestamp,stage,status,detail\n' > "$STATUS"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' > "$HEARTBEAT"
record() { printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS"; }
stage() { printf '%s\n' "$1" > "$CURRENT"; }
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
  local values current_stage
  values="$(resource_values)"
  current_stage="$(cat "$CURRENT" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$current_stage" \
    "${values// /,}" >> "$HEARTBEAT"
  if [[ -f "$MATERIALIZATION_ROOT/targeted_confirmation_plan.csv" ]]; then
    "$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
      --plan "$MATERIALIZATION_ROOT/targeted_confirmation_plan.csv" \
      --stale-seconds 1800 --output "$STATE_ROOT/latest_health.csv" \
      > "$STATE_ROOT/latest_health.log" 2>&1 || true
  fi
}
heartbeat_loop() { while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done; }
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"; read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v i="$idle" \
      -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" -v w="$WORKERS" \
      'BEGIN {exit !((l<=ml)&&(m>=mm)&&(d>=md)&&(i>=w))}'; then
      record resource_gate PASS \
        "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return 0
    fi
    record resource_gate WAIT \
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

stage initializing
heartbeat_loop & HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

stage materialize
"$R_SCRIPT" "$MATERIALIZE" --repo-root "$REPO_ROOT" --screen-root "$SCREEN_ROOT" \
  --output-root "$MATERIALIZATION_ROOT" > "$STATE_ROOT/materialize.log" 2>&1
record materialize COMPLETED "2 cells;3 chains each;canonical article source"

stage tests
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); stopifnot(as.character(packageVersion("exdqlm"))=="1.0.0"); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-independent-exal-m0-structural-screen-v2.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)' \
  > "$STATE_ROOT/focused_tests.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
  --output "$STATE_ROOT/static_verification.json" > "$STATE_ROOT/static_verification.log" 2>&1
record tests COMPLETED "package;M0;source;window;budget;storage contracts pass"

stage resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
[[ "$CPU_COUNT" -eq "$WORKERS" ]] || {
  record cpu_selection FAILED "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"
  echo "Expected $WORKERS idle CPUs; found $CPU_COUNT in '$CPU_SET'." >&2; exit 4;
}
record cpu_selection PASS "workers=${WORKERS};threads=1;cpus=${CPU_SET}"
printf 'RUN_ID=%s\nRUN_TAG=%s\nGIT_COMMIT=%s\nCPU_SET=%s\n' \
  "$RUN_ID" "$RUN_TAG" "$(git rev-parse HEAD)" "$CPU_SET" > "$STATE_ROOT/run.env"

stage confirmation
PLAN="$MATERIALIZATION_ROOT/targeted_confirmation_plan.csv"
"$R_SCRIPT" -e 'x<-read.csv(commandArgs(TRUE)[1],check.names=FALSE);stopifnot(nrow(x)==6L);writeLines(x$config_path)' \
  "$PLAN" > "$STATE_ROOT/configs.txt"
record confirmation STARTED "6 full-budget chains;parallelism=${WORKERS};threads=1"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$WORKERS" "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" \
  --run-tag "$RUN_TAG" --config < "$STATE_ROOT/configs.txt" > "$STATE_ROOT/workers.log" 2>&1
RC="$?"
set -e
printf '%s\n' "$RC" > "$STATE_ROOT/worker_exit_code.txt"
if [[ "$RC" -ne 0 ]]; then
  record confirmation FAILED "worker_exit=${RC};same-tag resume skips matching successes"; exit "$RC"
fi
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
  --run-tag "$RUN_TAG" --output "$STATE_ROOT/runtime_verification.json" \
  > "$STATE_ROOT/runtime_verification.log" 2>&1
record confirmation COMPLETED "6/6 finite storage-light chains"

stage closeout
"$R_SCRIPT" "$CLOSEOUT" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
  --run-tag "$RUN_TAG" --output-root "$STATE_ROOT/closeout" > "$STATE_ROOT/closeout.log" 2>&1
record closeout COMPLETED "chain and cell summaries written;article unchanged"
stage complete
write_heartbeat
record complete COMPLETED "manual metric-promotion review required"
printf 'Targeted confirmation complete: %s\n' "$RUN_TAG"
