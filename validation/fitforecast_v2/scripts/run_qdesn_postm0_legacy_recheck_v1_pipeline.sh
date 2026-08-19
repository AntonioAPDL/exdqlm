#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_postm0_legacy_recheck_v1_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${3:-qdesn-postm0-legacy-recheck-v1-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/qdesn-postm0-legacy-recheck-v1-1.0.0"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
ADAPTIVE_ROOT="$STATE_ROOT/adaptive"
WORKER="validation/fitforecast_v2/scripts/run_qdesn_postm0_legacy_recheck_v1_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_postm0_legacy_recheck_v1.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_qdesn_postm0_legacy_recheck_v1.R"
ADVANCE="validation/fitforecast_v2/scripts/advance_qdesn_postm0_legacy_recheck_v1.R"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_postm0_legacy_recheck_v1.lock"
mkdir -p "$STATE_ROOT" "$MATERIALIZATION_ROOT" "$ADAPTIVE_ROOT"
export QDESN_PLRV1_MATERIALIZATION_ROOT="$MATERIALIZATION_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
if [[ ! -s "$STATUS_CSV" ]]; then
  printf 'timestamp,stage,status,detail\n' > "$STATUS_CSV"
fi
if [[ ! -s "$HEARTBEAT_CSV" ]]; then
  printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' > "$HEARTBEAT_CSV"
fi

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another post-M0 legacy-recheck pipeline holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE"; }
record_status() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS_CSV"
}
record_status pipeline RESUME_OR_START "same_run_id_and_run_tag_resume_completed_roots"
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
heartbeat_loop() {
  while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done
}
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"
    read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v ml="$MAX_LOAD" \
      -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" -v i="$idle" -v w="$WORKERS" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md) && (i >= w))}'; then
      record_status resource_gate PASS \
        "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return 0
    fi
    record_status resource_gate WAIT \
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
  local stage="$1" plan="$2" list parallelism jobs rc
  list="$STATE_ROOT/${stage}_configs.txt"
  "$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); writeLines(x$config_path)' \
    "$plan" > "$list"
  jobs="$(wc -l < "$list")"
  parallelism="$WORKERS"
  if [[ "$jobs" -lt "$parallelism" ]]; then parallelism="$jobs"; fi
  record_status "$stage" STARTED "jobs=${jobs};parallelism=${parallelism};threads_per_job=1"
  set +e
  taskset -c "$CPU_SET" xargs -r -n 1 -P "$parallelism" \
    "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
    < "$list" > "$STATE_ROOT/${stage}_workers.log" 2>&1
  rc="$?"
  set -e
  printf '%s\n' "$rc" > "$STATE_ROOT/${stage}_worker_exit_code.txt"
  "$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
    --plan "$plan" --output "$STATE_ROOT/${stage}_health.csv" \
    > "$STATE_ROOT/${stage}_health.log" 2>&1 || true
  if [[ "$rc" -ne 0 ]]; then
    record_status "$stage" FAILED "worker_exit=${rc};same_run_tag_resumes_completed_jobs"
    return "$rc"
  fi
  "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
    --materialization-root "$MATERIALIZATION_ROOT" --stage "$stage" \
    --plan "$plan" --run-tag "$RUN_TAG" \
    --output "$STATE_ROOT/${stage}_verification.json" \
    > "$STATE_ROOT/${stage}_verification.log" 2>&1
  record_status "$stage" COMPLETED "jobs=${jobs};finite_storage_light=all"
}

set_stage initializing
heartbeat_loop &
HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
on_error() {
  local rc="$?" stage
  set +e
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf 'unknown')"
  record_status "$stage" FAILED "pipeline_exit=${rc};inspect_stage_specific_logs"
  exit "$rc"
}
trap cleanup EXIT INT TERM
trap on_error ERR

if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Launch refused outside $EXPECTED_BRANCH" >&2
  exit 3
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Launch requires a clean worktree." >&2
  git status --short >&2
  exit 3
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Launch requires an upstream." >&2
  exit 3
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch requires synchronized HEAD (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 3
fi
if [[ "$WORKERS" -lt 1 || "$WORKERS" -gt 20 ]]; then
  echo "WORKERS must be between 1 and 20." >&2
  exit 3
fi
{
  printf 'RUN_ID=%s\nRUN_TAG=%s\nGIT_COMMIT=%s\n' \
    "$RUN_ID" "$RUN_TAG" "$(git rev-parse HEAD)"
  printf 'WORKTREE=%s\nWORKERS=%s\nTHREADS_PER_WORKER=1\n' \
    "$REPO_ROOT" "$WORKERS"
  printf 'CPU_SET=PENDING_RESOURCE_GATE\nSMOKE=2\nCALIBRATION=5\nTIER_A_DISCOVERY=90\n'
  printf 'AUTO_STOP_AFTER_TIER_A_DISCOVERY=TRUE\nARTICLE_UPDATE_AUTOMATIC=FALSE\n'
} > "$STATE_ROOT/run_tags.env"

set_stage materialize
record_status materialize STARTED \
  "v6 authority;40 exact historical candidates;pre-M0 evidence is not an M0 veto"
"$R_SCRIPT" validation/fitforecast_v2/scripts/materialize_qdesn_postm0_legacy_recheck_v1.R \
  --output-root "$MATERIALIZATION_ROOT" --use-frozen-designs \
  > "$STATE_ROOT/materialize.log" 2>&1
if [[ -n "$(git status --porcelain)" ]]; then
  record_status materialize FAILED "tracked deterministic materialization drift"
  git status --short > "$STATE_ROOT/post_materialize_git_status.txt"
  exit 4
fi
record_status materialize COMPLETED "2 smoke;5 calibration;90 discovery"

set_stage tests
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0")' \
  > "$STATE_ROOT/package_load.log" 2>&1
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-qdesn-postm0-legacy-recheck-v1.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)' \
  > "$STATE_ROOT/focused_tests.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
  --materialization-root "$MATERIALIZATION_ROOT" --stage static \
  --output "$STATE_ROOT/static_verification.json" \
  > "$STATE_ROOT/static_verification.log" 2>&1
record_status tests COMPLETED \
  "package;sampler-era;exact-M0;history;source;storage;stage contracts pass"

set_stage resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  record_status cpu_selection FAILED "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"
  exit 3
fi
sed -i "s/^CPU_SET=PENDING_RESOURCE_GATE$/CPU_SET=${CPU_SET}/" "$STATE_ROOT/run_tags.env"
record_status cpu_selection COMPLETED "workers=${WORKERS};threads=1;cpus=${CPU_SET}"

set_stage smoke
run_stage smoke "$MATERIALIZATION_ROOT/smoke_plan.csv"

set_stage calibration
run_stage calibration "$MATERIALIZATION_ROOT/calibration_plan.csv"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1]); stopifnot(nrow(x)==5L, all(x$status=="SUCCESS"), all(x$binary_count==0L), max(x$elapsed_seconds, na.rm=TRUE)<=21600)' \
  "$STATE_ROOT/calibration_verification_runtime.csv" \
  > "$STATE_ROOT/calibration_runtime_gate.log" 2>&1
record_status calibration_runtime_gate PASS "5 representative roots;maximum elapsed <= 6 hours"

set_stage tier_a_discovery
run_stage tier_a_discovery "$MATERIALIZATION_ROOT/tier_a_discovery_plan.csv"

set_stage tier_a_discovery_closeout
"$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from tier_a_discovery \
  --run-tag "$RUN_TAG" --materialization-root "$MATERIALIZATION_ROOT" \
  --output-root "$ADAPTIVE_ROOT" \
  > "$STATE_ROOT/advance_after_tier_a_discovery.log" 2>&1
record_status tier_a_discovery_closeout COMPLETED \
  "paired rankings complete;20-job replication plan materialized;not launched"

set_stage complete
write_heartbeat
record_status complete COMPLETED \
  "Tier-A discovery closed;replication waits for review;article v6 unchanged"
printf 'Post-M0 legacy recheck v1 discovery complete: %s\n' "$RUN_TAG"
