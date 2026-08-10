#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
RECOVERY_NAME="${4:-adaptive_recovery_selector_v2}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-16}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
ORIGINAL_COMPLETED_ROOTS=282

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
PRIOR_ADAPTIVE_ROOT="$STATE_ROOT/adaptive"
ADAPTIVE_ROOT="$STATE_ROOT/$RECOVERY_NAME"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
WORKER="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_independent_exal_m0_structural_screen_v2.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_structural_screen_v2.R"
ADVANCE="validation/fitforecast_v2/scripts/advance_independent_exal_m0_structural_screen_v2.R"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/independent_exal_m0_structural_screen_v2.lock"
ATTEMPT_ID="$(date +%Y%m%d_%H%M%S)"

if [[ ! -d "$STATE_ROOT" || ! -d "$MATERIALIZATION_ROOT" || ! -d "$PRIOR_ADAPTIVE_ROOT" ]]; then
  echo "Recovery requires the existing run, materialization, and original adaptive roots." >&2
  exit 2
fi
if [[ ! -f "$STATUS_CSV" || ! -f "$PRIOR_ADAPTIVE_ROOT/wave2_plan.csv" ]]; then
  echo "Recovery evidence is incomplete: stage status or Wave-2 plan is missing." >&2
  exit 2
fi

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
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf 'recovery_initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "${values// /,}" >> "$HEARTBEAT_CSV"
}
heartbeat_loop() { while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done; }
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"; read -r load memory disk idle <<< "$values"; write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" \
      -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" -v i="$idle" -v w="$WORKERS" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md) && (i >= w))}'; then
      record_status recovery_resource_gate PASS \
        "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return 0
    fi
    record_status recovery_resource_gate WAIT \
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
run_stage() {
  local stage="$1"
  local plan="$ADAPTIVE_ROOT/${stage}_plan.csv"
  local list="$STATE_ROOT/${stage}_configs_recovery_${ATTEMPT_ID}.txt"
  local log="$STATE_ROOT/${stage}_workers_recovery_${ATTEMPT_ID}.log"
  local parallelism="$WORKERS" rc jobs
  "$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); writeLines(x$config_path)' \
    "$plan" > "$list"
  jobs="$(wc -l < "$list")"
  if [[ "$jobs" -lt "$parallelism" ]]; then parallelism="$jobs"; fi
  record_status "$stage" RECOVERY_STARTED \
    "jobs=${jobs};parallelism=${parallelism};threads_per_job=1;attempt=${ATTEMPT_ID}"
  set +e
  taskset -c "$CPU_SET" xargs -r -n 1 -P "$parallelism" \
    "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
    < "$list" > "$log" 2>&1
  rc="$?"
  set -e
  printf '%s\n' "$rc" > "$STATE_ROOT/${stage}_worker_exit_code_recovery_${ATTEMPT_ID}.txt"
  "$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --plan "$plan" \
    --output "$STATE_ROOT/${stage}_health_recovery_${ATTEMPT_ID}.csv" \
    > "$STATE_ROOT/${stage}_health_recovery_${ATTEMPT_ID}.log" 2>&1 || true
  if [[ "$rc" -ne 0 ]]; then
    record_status "$stage" RECOVERY_FAILED \
      "worker_exit=${rc};same-tag retry skips config-identical successful jobs"
    return "$rc"
  fi
  "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
    --materialization-root "$MATERIALIZATION_ROOT" --stage "$stage" --plan "$plan" \
    --run-tag "$RUN_TAG" --output "$STATE_ROOT/${stage}_verification_recovery_${ATTEMPT_ID}.json" \
    > "$STATE_ROOT/${stage}_verification_recovery_${ATTEMPT_ID}.log" 2>&1
  record_status "$stage" RECOVERY_COMPLETED "jobs=${jobs};finite_storage_light=all"
}
advance_after() {
  local stage="$1"
  local log="$STATE_ROOT/advance_after_${stage}_recovery_${ATTEMPT_ID}.log"
  record_status "advance_${stage}" RECOVERY_STARTED \
    "selector_recovery=${RECOVERY_NAME};prior_adaptive_preserved"
  "$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from "$stage" --run-tag "$RUN_TAG" \
    --materialization-root "$MATERIALIZATION_ROOT" \
    --prior-adaptive-root "$PRIOR_ADAPTIVE_ROOT" --output-root "$ADAPTIVE_ROOT" \
    > "$log" 2>&1
  record_status "advance_${stage}" RECOVERY_COMPLETED \
    "next-stage manifest generated;article unchanged"
}

if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Recovery refused outside $EXPECTED_BRANCH" >&2; exit 3
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Recovery requires a clean worktree." >&2; git status --short >&2; exit 3
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Recovery requires an upstream." >&2; exit 3
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Recovery requires synchronized HEAD (behind=$BEHIND ahead=$AHEAD)." >&2; exit 3
fi
if [[ "$WORKERS" -lt 1 || "$WORKERS" -gt 20 ]]; then
  echo "WORKERS must be between 1 and 20." >&2; exit 3
fi
if [[ "$(cat "$STATE_ROOT/run_tag.txt")" != "$RUN_TAG" ]]; then
  echo "RUN_TAG does not match the frozen run evidence." >&2; exit 3
fi

mkdir -p "$ADAPTIVE_ROOT"
if [[ ! -f "$HEARTBEAT_CSV" ]]; then
  printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' > "$HEARTBEAT_CSV"
fi
set_stage recovery_preflight
heartbeat_loop & HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

record_status recovery_preflight STARTED \
  "append-only recovery;expected_completed_roots=${ORIGINAL_COMPLETED_ROOTS};attempt=${ATTEMPT_ID}"
for stage in smoke calibration wave1; do
  "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
    --materialization-root "$MATERIALIZATION_ROOT" --stage "$stage" \
    --plan "$MATERIALIZATION_ROOT/${stage}_plan.csv" --run-tag "$RUN_TAG" \
    --output "$STATE_ROOT/${stage}_recovery_preflight_${ATTEMPT_ID}.json" \
    > "$STATE_ROOT/${stage}_recovery_preflight_${ATTEMPT_ID}.log" 2>&1
done
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --stage wave2 \
  --plan "$PRIOR_ADAPTIVE_ROOT/wave2_plan.csv" --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/wave2_recovery_preflight_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/wave2_recovery_preflight_${ATTEMPT_ID}.log" 2>&1
"$R_SCRIPT" -e 'paths <- commandArgs(TRUE); x <- lapply(paths, jsonlite::read_json, simplifyVector=TRUE); expected <- vapply(x, function(z) as.integer(z$runtime_summary$expected), integer(1)); success <- vapply(x, function(z) as.integer(z$runtime_summary$success), integer(1)); stopifnot(sum(expected)==282L, identical(expected, success), all(vapply(x, function(z) identical(z$decision, "PASS"), logical(1))))' \
  "$STATE_ROOT/smoke_recovery_preflight_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/calibration_recovery_preflight_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/wave1_recovery_preflight_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/wave2_recovery_preflight_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/prior_282_root_gate_${ATTEMPT_ID}.log" 2>&1
record_status recovery_preflight COMPLETED \
  "282 prior roots reverified;no prior fit rerun permitted"

set_stage recovery_tests
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0")' \
  > "$STATE_ROOT/recovery_package_load_${ATTEMPT_ID}.log" 2>&1
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-independent-exal-m0-structural-screen-v2.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)' \
  > "$STATE_ROOT/recovery_focused_tests_${ATTEMPT_ID}.log" 2>&1
record_status recovery_tests COMPLETED "profile-null;repeat-resolution;launcher contracts pass"

{
  printf 'RUN_ID=%s\nRUN_TAG=%s\nRECOVERY_NAME=%s\n' "$RUN_ID" "$RUN_TAG" "$RECOVERY_NAME"
  printf 'ORIGINAL_LAUNCH_COMMIT=%s\n' "$(cat "$STATE_ROOT/launch_commit.txt")"
  printf 'RECOVERY_COMMIT=%s\nRECOVERY_ATTEMPT=%s\n' "$(git rev-parse HEAD)" "$ATTEMPT_ID"
  printf 'ORIGINAL_COMPLETED_ROOTS=%s\nWORKERS=%s\nTHREADS_PER_WORKER=1\n' \
    "$ORIGINAL_COMPLETED_ROOTS" "$WORKERS"
  printf 'PRIOR_ADAPTIVE_ROOT=%s\nRECOVERY_ADAPTIVE_ROOT=%s\n' \
    "$PRIOR_ADAPTIVE_ROOT" "$ADAPTIVE_ROOT"
  printf 'WAVE3=72\nSEALED=76\nFULL_CONFIRMATION_LAUNCH_APPROVED=FALSE\n'
} > "$STATE_ROOT/recovery_manifest_${ATTEMPT_ID}.env"

set_stage advance_wave2_recovery
advance_after wave2
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); stopifnot(nrow(x)==55L, all(x$superseded_stage=="wave1"), all(x$retained_stage=="wave2"))' \
  "$ADAPTIVE_ROOT/wave1_wave2_repeat_resolution.csv" \
  > "$STATE_ROOT/wave2_repeat_resolution_gate_${ATTEMPT_ID}.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --stage wave3 \
  --plan "$ADAPTIVE_ROOT/wave3_plan.csv" \
  --output "$STATE_ROOT/wave3_plan_verification_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/wave3_plan_verification_${ATTEMPT_ID}.log" 2>&1
record_status wave3_plan PASS "72 jobs;55 repeated dev09 rows resolved latest-stage-first"

set_stage recovery_resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  record_status recovery_cpu_selection FAILED \
    "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"
  exit 3
fi
record_status recovery_cpu_selection COMPLETED \
  "workers=${WORKERS};threads=1;cpus=${CPU_SET}"

set_stage wave3
run_stage wave3
advance_after wave3
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --stage sealed \
  --plan "$ADAPTIVE_ROOT/sealed_plan.csv" \
  --output "$STATE_ROOT/sealed_plan_verification_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/sealed_plan_verification_${ATTEMPT_ID}.log" 2>&1

set_stage sealed
run_stage sealed
advance_after sealed
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); stopifnot(nrow(x)==21L, all(!x$launch_approved))' \
  "$ADAPTIVE_ROOT/canonical_confirmation_plan.csv" \
  > "$STATE_ROOT/confirmation_block_gate_${ATTEMPT_ID}.log" 2>&1

set_stage complete
write_heartbeat
record_status complete RECOVERY_COMPLETED \
  "430 automated roots closed;confirmation manifest only;article unchanged"
cat "Structural screen v2 recovery complete: $RUN_TAG\n"
