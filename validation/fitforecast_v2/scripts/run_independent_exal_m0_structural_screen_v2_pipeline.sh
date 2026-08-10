#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-independent_exal_m0_structural_screen_v2_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${3:-ind-exal-m0-struct-v2-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
CANONICAL_MATERIALIZATION_ROOT="reports/shared_fitforecast_v2_orchestration/independent_exal_m0_structural_screen_v2_materialization"
ADAPTIVE_ROOT="$STATE_ROOT/adaptive"
WORKER="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_independent_exal_m0_structural_screen_v2.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_structural_screen_v2.R"
ADVANCE="validation/fitforecast_v2/scripts/advance_independent_exal_m0_structural_screen_v2.R"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/independent_exal_m0_structural_screen_v2.lock"
mkdir -p "$STATE_ROOT" "$ADAPTIVE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
printf 'timestamp,stage,status,detail\n' > "$STATUS_CSV"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "$HEARTBEAT_CSV"

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another structural-screen v2 pipeline holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE"; }
record_status() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS_CSV"
}
resource_values() {
  local load1 memory_kb disk_kb
  load1="$(awk '{print $1}' /proc/loadavg)"
  memory_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  disk_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
  awk -v l="$load1" -v m="$memory_kb" -v d="$disk_kb" \
    'BEGIN {printf "%.2f %.1f %.1f", l, m/1048576, d/1048576}'
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
    local values load memory disk
    values="$(resource_values)"; read -r load memory disk <<< "$values"; write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" \
      -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md))}'; then
      record_status resource_gate PASS "load=${load};memory_gb=${memory};disk_gb=${disk}"
      return 0
    fi
    record_status resource_gate WAIT "load=${load};memory_gb=${memory};disk_gb=${disk}"
    sleep "$POLL_SECONDS"
  done
}
select_idle_cpus() {
  local count
  count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$count" '
    {cpu=$1+0; used[cpu]+=$2+0}
    END {for (i=0; i<n; i++) printf "%d %.6f\n", i, used[i]+0}
  ' | sort -k2,2n -k1,1n | awk -v workers="$WORKERS" 'NR <= workers {print $1}' | paste -sd, -
}
plan_for_stage() {
  local stage="$1"
  if [[ -f "$ADAPTIVE_ROOT/${stage}_plan.csv" ]]; then
    printf '%s\n' "$ADAPTIVE_ROOT/${stage}_plan.csv"
  else
    printf '%s\n' "$MATERIALIZATION_ROOT/${stage}_plan.csv"
  fi
}
run_stage() {
  local stage="$1" plan list parallelism rc
  plan="$(plan_for_stage "$stage")"
  list="$STATE_ROOT/${stage}_configs.txt"
  parallelism="$WORKERS"
  "$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); writeLines(x$config_path)' \
    "$plan" > "$list"
  local jobs; jobs="$(wc -l < "$list")"
  if [[ "$jobs" -lt "$parallelism" ]]; then parallelism="$jobs"; fi
  record_status "$stage" STARTED "jobs=${jobs};parallelism=${parallelism};threads_per_job=1"
  set +e
  taskset -c "$CPU_SET" xargs -r -n 1 -P "$parallelism" \
    "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
    < "$list" > "$STATE_ROOT/${stage}_workers.log" 2>&1
  rc="$?"
  set -e
  printf '%s\n' "$rc" > "$STATE_ROOT/${stage}_worker_exit_code.txt"
  "$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --plan "$plan" \
    --output "$STATE_ROOT/${stage}_health.csv" > "$STATE_ROOT/${stage}_health.log" 2>&1 || true
  if [[ "$rc" -ne 0 ]]; then
    record_status "$stage" FAILED "worker_exit=${rc};rerun_same_tag_resumes_successful_jobs"
    return "$rc"
  fi
  "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
    --stage "$stage" --plan "$plan" --run-tag "$RUN_TAG" \
    --output "$STATE_ROOT/${stage}_verification.json" > "$STATE_ROOT/${stage}_verification.log" 2>&1
  record_status "$stage" COMPLETED "jobs=${jobs};finite_storage_light=all"
}
advance_after() {
  local stage="$1"
  record_status "advance_${stage}" STARTED "deterministic cell-specific selector"
  "$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from "$stage" --run-tag "$RUN_TAG" \
    --materialization-root "$MATERIALIZATION_ROOT" --output-root "$ADAPTIVE_ROOT" \
    > "$STATE_ROOT/advance_after_${stage}.log" 2>&1
  record_status "advance_${stage}" COMPLETED "next-stage manifest generated;article unchanged"
}

set_stage initializing
heartbeat_loop & HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Launch refused outside $EXPECTED_BRANCH" >&2; exit 3
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Launch requires a clean worktree." >&2; git status --short >&2; exit 3
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Launch requires an upstream." >&2; exit 3
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch requires synchronized HEAD (behind=$BEHIND ahead=$AHEAD)." >&2; exit 3
fi
if [[ "$WORKERS" -lt 1 || "$WORKERS" -gt 20 ]]; then
  echo "WORKERS must be between 1 and 20." >&2; exit 3
fi
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  echo "Expected $WORKERS CPUs; found $CPU_COUNT in '$CPU_SET'." >&2; exit 3
fi
{
  printf 'RUN_ID=%s\nRUN_TAG=%s\nGIT_COMMIT=%s\n' "$RUN_ID" "$RUN_TAG" "$(git rev-parse HEAD)"
  printf 'WORKTREE=%s\nMETHOD_ID=M0_v_collapsed_support_logit\n' "$REPO_ROOT"
  printf 'WORKERS=%s\nTHREADS_PER_WORKER=1\nCPU_SET=%s\n' "$WORKERS" "$CPU_SET"
  printf 'SMOKE=2\nCALIBRATION=12\nWAVE1=103\nWAVE2=165\nWAVE3=72\nSEALED=76\n'
  printf 'FULL_CONFIRMATION_LAUNCH_APPROVED=FALSE\nARTICLE_UPDATE_AUTOMATIC=FALSE\n'
} > "$STATE_ROOT/run_tags.env"

set_stage materialize
mkdir -p "$MATERIALIZATION_ROOT"
if [[ -f "$CANONICAL_MATERIALIZATION_ROOT/virtual_candidate_universe.csv" ]]; then
  cp "$CANONICAL_MATERIALIZATION_ROOT/virtual_candidate_universe.csv" \
    "$MATERIALIZATION_ROOT/virtual_candidate_universe.csv"
  record_status materialize_cache REUSED \
    "canonical 50000-profile universe copied;content revalidated by materializer"
else
  record_status materialize_cache GENERATED "canonical universe cache absent"
fi
record_status materialize STARTED "50000 virtual profiles;frozen source cache;96 selected designs"
"$R_SCRIPT" validation/fitforecast_v2/scripts/materialize_independent_exal_m0_structural_screen_v2.R \
  --output-root "$MATERIALIZATION_ROOT" --use-frozen-designs \
  > "$STATE_ROOT/materialize.log" 2>&1
if [[ -n "$(git status --porcelain)" ]]; then
  record_status materialize FAILED "tracked deterministic materialization drift"
  git status --short > "$STATE_ROOT/post_materialize_git_status.txt"
  exit 4
fi
record_status materialize COMPLETED "2 smoke;12 calibration;103 wave1;source hashes frozen"

set_stage tests
record_status tests STARTED "R-4.6.0 package load and focused structural-screen tests"
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0")' \
  > "$STATE_ROOT/package_load.log" 2>&1
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-independent-exal-m0-structural-screen-v2.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)' \
  > "$STATE_ROOT/focused_tests.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
  --stage static --output "$STATE_ROOT/static_verification.json" > "$STATE_ROOT/static_verification.log" 2>&1
record_status tests COMPLETED "load;schema;selection;source;storage;launcher contracts pass"

set_stage resource_gate
wait_for_resources
record_status cpu_selection COMPLETED "workers=${WORKERS};threads=1;cpus=${CPU_SET}"

set_stage smoke
run_stage smoke

set_stage calibration
run_stage calibration
CAL_RUNTIME="$STATE_ROOT/calibration_verification_runtime.csv"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1]); stopifnot(nrow(x)==12L, all(x$status=="SUCCESS"), all(x$binary_count==0L), max(x$elapsed_seconds, na.rm=TRUE) <= 21600)' \
  "$CAL_RUNTIME" > "$STATE_ROOT/calibration_runtime_gate.log" 2>&1
record_status calibration_runtime_gate PASS "12 representative roots;maximum elapsed <= 6 hours"

set_stage wave1
run_stage wave1
advance_after wave1

set_stage wave2
run_stage wave2
advance_after wave2

set_stage wave3
run_stage wave3
advance_after wave3

set_stage sealed
run_stage sealed
advance_after sealed

set_stage complete
write_heartbeat
record_status complete COMPLETED "428 exploratory roots closed;confirmation manifest only;article unchanged"
cat "Structural screen v2 complete: $RUN_TAG"
