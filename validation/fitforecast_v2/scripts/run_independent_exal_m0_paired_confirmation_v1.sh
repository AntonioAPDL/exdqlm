#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
MODE="${2:?MODE must be smoke or confirmation}"
RUN_ID="${3:?RUN_ID is required}"
RUN_TAG="${4:?RUN_TAG is required}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
RESULT_STAGE="qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
STALE_SECONDS="${STALE_SECONDS:-1800}"
POLL_SECONDS="${POLL_SECONDS:-300}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"

case "$MODE" in
  smoke)
    DEFAULT_WORKERS=2
    EXPECTED_JOBS=2
    PLAN_NAME="smoke_plan.csv"
    ;;
  confirmation)
    DEFAULT_WORKERS=6
    EXPECTED_JOBS=6
    PLAN_NAME="confirmation_plan.csv"
    [[ "${PAIRED_CONFIRMATION_APPROVED:-false}" == "true" ]] || {
      echo "PAIRED_CONFIRMATION_APPROVED=true is required." >&2
      exit 3
    }
    ;;
  *)
    echo "MODE must be smoke or confirmation." >&2
    exit 3
    ;;
esac
WORKERS="${WORKERS:-$DEFAULT_WORKERS}"
[[ "$WORKERS" =~ ^[0-9]+$ ]] && [[ "$WORKERS" -ge 1 ]] &&
  [[ "$WORKERS" -le "$EXPECTED_JOBS" ]] || {
    echo "WORKERS must be between 1 and $EXPECTED_JOBS for $MODE." >&2
    exit 3
  }

STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
MATERIALIZE="validation/fitforecast_v2/scripts/materialize_independent_exal_m0_paired_confirmation_v1.R"
VERIFY="validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_confirmation_v1.R"
WORKER="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R"
CLOSEOUT="validation/fitforecast_v2/scripts/closeout_independent_exal_m0_paired_confirmation_v1.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_structural_screen_v2.R"
LOCK_FILE="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_confirmation_v1_${MODE}.lock"

cd "$REPO_ROOT"
[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || {
  echo "Wrong validation branch." >&2
  exit 3
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "A clean worktree is required." >&2
  exit 3
}
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || {
  echo "A synchronized upstream HEAD is required." >&2
  exit 3
}
[[ -x "$R_SCRIPT" ]] || { echo "R 4.6.0 Rscript is unavailable." >&2; exit 3; }

mkdir -p "$STATE_ROOT"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another $MODE confirmation pipeline is active." >&2; exit 3; }
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1

STATUS="$STATE_ROOT/stage_status.csv"
CURRENT="$STATE_ROOT/current_stage.txt"
HEARTBEAT="$STATE_ROOT/heartbeat.csv"
printf 'timestamp,stage,status,detail\n' > "$STATUS"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' > "$HEARTBEAT"
record() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS"
}
stage() {
  CURRENT_STAGE="$1"
  printf '%s\n' "$CURRENT_STAGE" > "$CURRENT"
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
  local values current_stage
  values="$(resource_values)"
  current_stage="$(cat "$CURRENT" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$current_stage" \
    "${values// /,}" >> "$HEARTBEAT"
  if [[ -f "$MATERIALIZATION_ROOT/$PLAN_NAME" ]]; then
    "$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
      --plan "$MATERIALIZATION_ROOT/$PLAN_NAME" --stale-seconds "$STALE_SECONDS" \
      --output "$STATE_ROOT/latest_health.csv" \
      > "$STATE_ROOT/latest_health.log" 2>&1 || true
  fi
}
heartbeat_loop() {
  while true; do
    write_heartbeat
    sleep "$HEARTBEAT_SECONDS"
  done
}
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"
    read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v i="$idle" \
      -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      -v w="$WORKERS" \
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
  ' | sort -k2,2n -k1,1n | awk -v workers="$WORKERS" \
    -v limit="$MAX_IDLE_CPU_PERCENT" \
    '$2 <= limit && selected < workers {print $1; selected++}' | paste -sd, -
}

CURRENT_STAGE="initializing"
HEARTBEAT_PID=""
cleanup() {
  if [[ -n "$HEARTBEAT_PID" ]] && kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
on_error() {
  local rc="$1" line="$2"
  record "$CURRENT_STAGE" FAILED "exit=${rc};line=${line};same_tag_resume_supported=true"
  exit "$rc"
}
trap 'on_error "$?" "$LINENO"' ERR
trap cleanup EXIT INT TERM
stage initializing
heartbeat_loop &
HEARTBEAT_PID="$!"

stage materialize
"$R_SCRIPT" "$MATERIALIZE" --repo-root "$REPO_ROOT" \
  --output-root "$MATERIALIZATION_ROOT" > "$STATE_ROOT/materialize.log" 2>&1
record materialize COMPLETED "mode=${MODE};jobs=${EXPECTED_JOBS};canonical_sources=2"

stage tests
"$R_SCRIPT" -e '
  pkgload::load_all(".", quiet = TRUE)
  stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0")
  testthat::test_file(
    "validation/fitforecast_v2/tests/testthat/test-independent-exal-m0-structural-screen-v2.R",
    reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE
  )
' > "$STATE_ROOT/focused_tests.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --plan "$PLAN_NAME" \
  --output "$STATE_ROOT/static_verification.json" \
  > "$STATE_ROOT/static_verification.log" 2>&1
record tests COMPLETED "R=4.6.0;package=1.0.0;static_contract=PASS"

stage resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
[[ "$CPU_COUNT" -eq "$WORKERS" ]] || {
  record cpu_selection FAILED "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"
  echo "Expected $WORKERS idle CPUs; found $CPU_COUNT in '$CPU_SET'." >&2
  exit 4
}
record cpu_selection PASS "workers=${WORKERS};threads_per_job=1;cpus=${CPU_SET}"
printf 'RUN_ID=%s\nRUN_TAG=%s\nMODE=%s\nGIT_COMMIT=%s\nCPU_SET=%s\nWORKERS=%s\n' \
  "$RUN_ID" "$RUN_TAG" "$MODE" "$(git rev-parse HEAD)" "$CPU_SET" "$WORKERS" \
  > "$STATE_ROOT/run.env"

stage "$MODE"
PLAN="$MATERIALIZATION_ROOT/$PLAN_NAME"
"$R_SCRIPT" -e '
  x <- read.csv(commandArgs(TRUE)[1], check.names = FALSE)
  stopifnot(nrow(x) == as.integer(commandArgs(TRUE)[2]))
  writeLines(x$config_path)
' "$PLAN" "$EXPECTED_JOBS" > "$STATE_ROOT/configs.txt"
record "$MODE" STARTED \
  "jobs=${EXPECTED_JOBS};parallelism=${WORKERS};threads_per_job=1;same_tag_resume_supported=true"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$WORKERS" \
  "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
  < "$STATE_ROOT/configs.txt" > "$STATE_ROOT/workers.log" 2>&1
RC="$?"
set -e
printf '%s\n' "$RC" > "$STATE_ROOT/worker_exit_code.txt"
if [[ "$RC" -ne 0 ]]; then
  record "$MODE" FAILED "worker_exit=${RC};same_tag_resume_supported=true"
  exit "$RC"
fi

stage runtime_verify
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --plan "$PLAN_NAME" \
  --run-tag "$RUN_TAG" --output "$STATE_ROOT/runtime_verification.json" \
  > "$STATE_ROOT/runtime_verification.log" 2>&1
record runtime_verify COMPLETED \
  "jobs=${EXPECTED_JOBS};all_metrics_finite=true;rolling=PASS;binaries=0"

if [[ "$MODE" == "confirmation" ]]; then
  stage closeout
  "$R_SCRIPT" "$CLOSEOUT" --repo-root "$REPO_ROOT" \
    --materialization-root "$MATERIALIZATION_ROOT" --run-tag "$RUN_TAG" \
    --output-root "$STATE_ROOT/closeout" > "$STATE_ROOT/closeout.log" 2>&1
  record closeout COMPLETED "six_metric_cells_reviewed;article_unchanged=true"
fi

stage storage_audit
BINARY_COUNT="$(find "$MATERIALIZATION_ROOT" \
  "$REPO_ROOT/results/qdesn_mcmc_validation/$RESULT_STAGE/$RUN_TAG" \
  -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.RData' \) \
  2>/dev/null | wc -l)"
[[ "$BINARY_COUNT" -eq 0 ]] || {
  record storage_audit FAILED "forbidden_binary_payloads=${BINARY_COUNT}"
  exit 5
}
record storage_audit PASS "forbidden_binary_payloads=0"

stage complete
write_heartbeat
record complete COMPLETED "mode=${MODE};manual_article_gate=true"
printf 'Paired confirmation %s complete: %s\n' "$MODE" "$RUN_TAG"
