#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-independent_exal_m0_relaunch_v1_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${3:-ind-exal-m0-v1-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MAX_LOAD="${MAX_LOAD:-50}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-100}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
WORKERS="${WORKERS:-20}"

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/independent-exal-m0-relaunch-v1-1.0.0"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
STUB="config/validation/qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1"
WORKER="validation/fitforecast_v2/scripts/run_independent_exal_m0_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_independent_exal_m0_relaunch_v1.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_relaunch_v1.R"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/independent_exal_m0_relaunch_v1.lock"
mkdir -p "$STATE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
printf 'timestamp,stage,status,detail\n' > "$STATUS_CSV"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "$HEARTBEAT_CSV"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another independent exAL M0 relaunch holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() {
  printf '%s\n' "$1" > "$CURRENT_STAGE"
}
record_status() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS_CSV"
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
  local values stage
  values="$(resource_values)"
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "${values// /,}" >> "$HEARTBEAT_CSV"
}
heartbeat_loop() {
  while true; do
    write_heartbeat
    sleep "$HEARTBEAT_SECONDS"
  done
}
wait_for_resources() {
  while true; do
    local values load memory disk
    values="$(resource_values)"
    read -r load memory disk <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" \
      -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md))}'; then
      record_status "resource_gate" "PASS" "load=${load};memory_gb=${memory};disk_gb=${disk}"
      return 0
    fi
    record_status "resource_gate" "WAIT" "load=${load};memory_gb=${memory};disk_gb=${disk}"
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
write_config_list() {
  local budget="$1"
  "$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); writeLines(x$config_path)' \
    "${STUB}_${budget}_chain_plan.csv" > "$STATE_ROOT/${budget}_configs.txt"
}
run_budget() {
  local budget="$1"
  local parallelism="$2"
  local list="$STATE_ROOT/${budget}_configs.txt"
  write_config_list "$budget"
  set +e
  taskset -c "$CPU_SET" xargs -r -n 1 -P "$parallelism" \
    "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
    < "$list" > "$STATE_ROOT/${budget}_workers.log" 2>&1
  local rc="$?"
  set -e
  printf '%s\n' "$rc" > "$STATE_ROOT/${budget}_worker_exit_code.txt"
  "$R_SCRIPT" "$HEALTH" --run-tag "$RUN_TAG" --budget "$budget" \
    --output-dir "$STATE_ROOT/${budget}_health" \
    > "$STATE_ROOT/${budget}_health.log" 2>&1 || true
  return "$rc"
}

set_stage "initializing"
heartbeat_loop &
HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

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
  echo "Launch requires a configured upstream." >&2
  exit 3
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch requires HEAD to match upstream (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 3
fi
if [[ "$WORKERS" -lt 1 || "$WORKERS" -gt 20 ]]; then
  echo "WORKERS must be between 1 and 20." >&2
  exit 3
fi

GIT_SHA="$(git rev-parse HEAD)"
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  echo "Expected $WORKERS selected CPUs; found $CPU_COUNT in '$CPU_SET'." >&2
  exit 3
fi
{
  printf 'RUN_ID=%s\n' "$RUN_ID"
  printf 'RUN_TAG=%s\n' "$RUN_TAG"
  printf 'GIT_COMMIT=%s\n' "$GIT_SHA"
  printf 'WORKTREE=%s\n' "$REPO_ROOT"
  printf 'METHOD_ID=M0_v_collapsed_support_logit\n'
  printf 'ANCHORS=15\nSMOKE_JOBS=6\nCANARY_JOBS=9\nFULL_JOBS=45\n'
  printf 'WORKERS=%s\nTHREADS_PER_WORKER=1\nCPU_SET=%s\n' "$WORKERS" "$CPU_SET"
  printf 'ARTICLE_UPDATE_AUTOMATIC=FALSE\nPROMOTION_AUTOMATIC=FALSE\n'
} > "$STATE_ROOT/run_tags.env"

set_stage "materialize"
record_status "materialize" "STARTED" "regenerate frozen 15-anchor contract"
"$R_SCRIPT" validation/fitforecast_v2/scripts/materialize_independent_exal_m0_relaunch_v1.R \
  > "$STATE_ROOT/materialize.log" 2>&1
if [[ -n "$(git status --porcelain)" ]]; then
  record_status "materialize" "FAILED" "tracked materialization drift"
  git status --short > "$STATE_ROOT/post_materialize_git_status.txt"
  exit 4
fi
record_status "materialize" "COMPLETED" "15 anchors;60 staged jobs;no drift"

set_stage "tests"
record_status "tests" "STARTED" "R-4.6.0 load and focused exact-kernel tests"
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0")' \
  > "$STATE_ROOT/package_load.log" 2>&1
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-exal-mcmc-collapsed-scale-shape.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)' \
  > "$STATE_ROOT/focused_tests.log" 2>&1
record_status "tests" "COMPLETED" "package load and collapsed-kernel tests pass"

set_stage "static_verify"
record_status "static_verify" "STARTED" "hash;source;prior;sampler;storage contracts"
"$R_SCRIPT" "$VERIFY" --budget static --output "$STATE_ROOT/static_verification.json" \
  > "$STATE_ROOT/static_verification.log" 2>&1
record_status "static_verify" "COMPLETED" "all 60 resolved configs pass"

set_stage "prepare_only"
record_status "prepare_only" "STARTED" "manifest all jobs without fitting"
"$R_SCRIPT" validation/fitforecast_v2/scripts/prepare_independent_exal_m0_relaunch_v1.R \
  --output-root "$STATE_ROOT/prepare_only" > "$STATE_ROOT/prepare_only.log" 2>&1
record_status "prepare_only" "COMPLETED" "60 jobs;0 fits;0 binary payloads"

set_stage "resource_gate"
wait_for_resources
record_status "cpu_selection" "COMPLETED" "workers=${WORKERS};threads=1;cpus=${CPU_SET}"

set_stage "smoke"
record_status "smoke" "STARTED" "6 chains;3 representative anchors;2 chains each"
if ! run_budget "smoke" 6; then
  record_status "smoke" "FAILED" "worker failure;inspect smoke_workers.log"
  exit 5
fi
if ! "$R_SCRIPT" "$VERIFY" --budget smoke --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/smoke_verification.json" > "$STATE_ROOT/smoke_verification.log" 2>&1; then
  record_status "smoke" "FAILED" "artifact verification failed;inspect smoke_verification.log"
  exit 8
fi
record_status "smoke" "COMPLETED" "6/6 finite;M0;storage contract pass"

set_stage "canary"
record_status "canary" "STARTED" "9 chains;3 anchors;3 chains each;1000 burn+3000 retained"
if ! run_budget "canary" 9; then
  record_status "canary" "FAILED" "worker failure;inspect canary_workers.log"
  exit 6
fi
if ! "$R_SCRIPT" "$VERIFY" --budget canary --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/canary_verification.json" > "$STATE_ROOT/canary_verification.log" 2>&1; then
  record_status "canary" "FAILED" "sampler or artifact gate failed;inspect canary_verification.log"
  exit 9
fi
record_status "canary" "COMPLETED" "9/9 finite;three-chain sampler gate pass"

set_stage "full"
record_status "full" "STARTED" "45 chains;15 anchors;3 chains each;20 workers"
FULL_RC=0
run_budget "full" "$WORKERS" || FULL_RC="$?"
if [[ "$FULL_RC" -ne 0 ]]; then
  record_status "full" "COMPLETED_WITH_FAILURES" "worker_exit=${FULL_RC};rerun same tag resumes only missing/failed"
  exit 7
fi
if ! "$R_SCRIPT" "$VERIFY" --budget full --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/full_verification.json" > "$STATE_ROOT/full_verification.log" 2>&1; then
  record_status "full" "FAILED" "artifact verification failed;inspect full_verification.log"
  exit 10
fi
record_status "full" "COMPLETED" "45/45 finite storage-light chains"

set_stage "closeout"
record_status "closeout" "STARTED" "pooled paths;chain diagnostics;metric comparison"
if ! "$R_SCRIPT" validation/fitforecast_v2/scripts/closeout_independent_exal_m0_relaunch_v1.R \
  --run-tag "$RUN_TAG" --output-root "$STATE_ROOT/closeout" \
  > "$STATE_ROOT/closeout.log" 2>&1; then
  record_status "closeout" "FAILED" "closeout failed;inspect closeout.log"
  exit 11
fi
record_status "closeout" "COMPLETED" "manual promotion candidates written;article untouched"

set_stage "complete"
write_heartbeat
record_status "complete" "COMPLETED" "all gates and closeout pass;manual promotion decision remains"
cat "Independent exAL M0 relaunch completed: $RUN_TAG"
