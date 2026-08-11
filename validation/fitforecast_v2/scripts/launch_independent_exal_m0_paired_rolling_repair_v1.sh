#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MODE="smoke"
WORKERS="2"
RUN_TAG=""
MATERIALIZATION_ROOT="${MATERIALIZATION_ROOT:-$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_rolling_repair_v1_materialization}"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
MAX_LOAD="${MAX_LOAD:-48}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-100}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
STALE_SECONDS="${STALE_SECONDS:-1800}"
LOCK_FILE="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_rolling_repair_v1.lock"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --workers) WORKERS="$2"; shift 2 ;;
    --run-tag) RUN_TAG="$2"; shift 2 ;;
    --materialization-root) MATERIALIZATION_ROOT="$2"; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" != "smoke" && "$MODE" != "calibration" ]]; then
  printf '%s\n' '--mode must be smoke or calibration' >&2
  exit 2
fi
if ! [[ "$WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' '--workers must be a positive integer' >&2
  exit 2
fi
if [[ "$MODE" == "calibration" ]]; then
  if [[ "${QDESN_PAIRED_REPAIR_APPROVAL:-}" != "YES" ]]; then
    printf '%s\n' 'Calibration is gated. Set QDESN_PAIRED_REPAIR_APPROVAL=YES only after explicit approval.' >&2
    exit 3
  fi
  if (( WORKERS > 20 )); then
    printf '%s\n' 'Calibration workers may not exceed the predeclared 20-core cap.' >&2
    exit 3
  fi
fi

if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  printf 'Wrong branch: expected %s, found %s\n' \
    "$EXPECTED_BRANCH" "$(git branch --show-current)" >&2
  exit 3
fi
if [[ -n "$(git status --porcelain)" ]]; then
  printf '%s\n' 'A clean worktree is required for a reproducible launch.' >&2
  exit 3
fi
if ! git rev-parse '@{upstream}' >/dev/null 2>&1; then
  printf '%s\n' 'The launch branch must have an upstream.' >&2
  exit 3
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  printf 'The launch commit must be synchronized (behind=%s ahead=%s).\n' \
    "$BEHIND" "$AHEAD" >&2
  exit 3
fi

PLAN_NAME="${MODE}_plan.csv"
PLAN_PATH="$MATERIALIZATION_ROOT/$PLAN_NAME"
if [[ ! -f "$PLAN_PATH" ]]; then
  printf 'Missing plan: %s\n' "$PLAN_PATH" >&2
  exit 4
fi
if [[ -z "$RUN_TAG" ]]; then
  RUN_TAG="ind-exal-m0-paired-rolling-repair-v1-${MODE}-$(date +%Y%m%d_%H%M%S)"
fi

STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_TAG"
mkdir -p "$STATE_ROOT/logs"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  printf '%s\n' 'Another paired rolling-repair campaign currently holds the lock.' >&2
  exit 3
fi
printf '%s\n' "$RUN_TAG" > "$STATE_ROOT/run_tag.txt"
printf '%s\n' "$MODE" > "$STATE_ROOT/mode.txt"
printf '%s\n' "$WORKERS" > "$STATE_ROOT/workers.txt"
git rev-parse HEAD > "$STATE_ROOT/launch_commit.txt"

STATUS_PATH="$STATE_ROOT/stage_status.csv"
CURRENT_STAGE_PATH="$STATE_ROOT/current_stage.txt"
HEARTBEAT_PATH="$STATE_ROOT/heartbeat.csv"
printf 'timestamp,stage,status,detail\n' > "$STATUS_PATH"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' \
  > "$HEARTBEAT_PATH"

record_status() {
  local stage="$1" status="$2" detail="$3"
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "$status" \
    "${detail//,/;}" >> "$STATUS_PATH"
}
set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE_PATH"; }
resource_values() {
  local load1 memory_kb disk_kb cpu_count idle_cpus
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
  stage="$(cat "$CURRENT_STAGE_PATH" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" \
    "${values// /,}" >> "$HEARTBEAT_PATH"
  if [[ -f "$PLAN_PATH" ]]; then
    "$R_SCRIPT" \
      validation/fitforecast_v2/scripts/healthcheck_independent_exal_m0_paired_rolling_repair_v1.R \
      --mode "$MODE" --run-tag "$RUN_TAG" \
      --materialization-root "$MATERIALIZATION_ROOT" \
      --stale-seconds "$STALE_SECONDS" \
      --output "$STATE_ROOT/healthcheck.csv" \
      > "$STATE_ROOT/healthcheck.log" 2>&1 || true
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
  ' | sort -k2,2n -k1,1n | awk -v workers="$WORKERS" \
    -v limit="$MAX_IDLE_CPU_PERCENT" \
    '$2 <= limit && selected < workers {print $1; selected++}' | paste -sd, -
}

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1
set_stage prelaunch_verification
heartbeat_loop &
HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_rolling_repair_v1.R \
  --materialization-root "$MATERIALIZATION_ROOT" \
  --plan "$PLAN_NAME" \
  --output "$STATE_ROOT/prelaunch_verification.json" \
  > "$STATE_ROOT/prelaunch_verification.log" 2>&1
record_status prelaunch_verification COMPLETED \
  "plan=${PLAN_NAME};workers=${WORKERS};method=M0_v_collapsed_support_logit"

CONFIG_LIST="$STATE_ROOT/config_paths.txt"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], stringsAsFactors = FALSE); cat(x$config_path, sep = "\n")' \
  "$PLAN_PATH" > "$CONFIG_LIST"

export REPO_ROOT R_SCRIPT RUN_TAG STATE_ROOT
run_one() {
  local config="$1"
  local job_id
  job_id="$(basename "$config" .json)"
  "$R_SCRIPT" validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R \
    --repo-root "$REPO_ROOT" --config "$config" --run-tag "$RUN_TAG" \
    > "$STATE_ROOT/logs/${job_id}.log" 2>&1
}
export -f run_one

set_stage resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  record_status cpu_selection FAILED \
    "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"
  printf 'Expected %s idle CPUs; found %s in %s.\n' \
    "$WORKERS" "$CPU_COUNT" "$CPU_SET" >&2
  exit 4
fi
record_status cpu_selection PASS \
  "workers=${WORKERS};threads_per_job=1;cpus=${CPU_SET}"
printf 'RUN_TAG=%s\nMODE=%s\nGIT_COMMIT=%s\nCPU_SET=%s\nWORKERS=%s\n' \
  "$RUN_TAG" "$MODE" "$(git rev-parse HEAD)" "$CPU_SET" "$WORKERS" \
  > "$STATE_ROOT/run.env"

set_stage "$MODE"
record_status "$MODE" STARTED \
  "jobs=$(wc -l < "$CONFIG_LIST");workers=${WORKERS};threads_per_job=1"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$WORKERS" \
  bash -c 'run_one "$1"' _ < "$CONFIG_LIST"
launch_status=$?
set -e
printf '%s\n' "$launch_status" > "$STATE_ROOT/worker_exit_code.txt"
write_heartbeat

set +e
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_rolling_repair_v1.R \
  --materialization-root "$MATERIALIZATION_ROOT" \
  --plan "$PLAN_NAME" --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/runtime_verification.json" \
  > "$STATE_ROOT/runtime_verification.log" 2>&1
verify_status=$?
set -e

if (( launch_status != 0 || verify_status != 0 )); then
  record_status "$MODE" FAILED \
    "launch_status=${launch_status};verify_status=${verify_status};same_tag_resume_supported=true"
  printf 'run_tag=%s mode=%s status=FAIL launch_status=%d verify_status=%d\n' \
    "$RUN_TAG" "$MODE" "$launch_status" "$verify_status"
  exit 1
fi
record_status "$MODE" COMPLETED \
  "jobs=$(wc -l < "$CONFIG_LIST");runtime_verification=PASS"

if [[ "$MODE" == "calibration" ]]; then
  set_stage paired_closeout
  "$R_SCRIPT" validation/fitforecast_v2/scripts/closeout_independent_exal_m0_paired_rolling_repair_v1.R \
    --materialization-root "$MATERIALIZATION_ROOT" --run-tag "$RUN_TAG" \
    --output-root "$STATE_ROOT/paired_closeout" \
    > "$STATE_ROOT/paired_closeout.log" 2>&1
  record_status paired_closeout COMPLETED \
    "all paired-consistent metric gains selected;minimum_effect_threshold=0;article_unchanged"
fi
set_stage complete
write_heartbeat
record_status complete COMPLETED \
  "canonical_confirmation_not_launched;article_promotion_not_automatic"
printf 'run_tag=%s mode=%s status=PASS jobs=%s\n' \
  "$RUN_TAG" "$MODE" "$(wc -l < "$CONFIG_LIST")"
