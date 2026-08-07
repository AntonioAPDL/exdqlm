#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_mcmc_dynamic_alpha_confirm_v1_$(date +%Y%m%d_%H%M%S)}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MAX_LOAD="${MAX_LOAD:-40}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-96}"
MIN_DISK_GB="${MIN_DISK_GB:-250}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
WORKERS=20

cd "$REPO_ROOT"
STAGE="qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_alpha_confirm_v1"
CONFIG_STUB="config/validation/${STAGE}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE_FILE="$STATE_ROOT/current_stage.txt"
LOCK_FILE="reports/shared_fitforecast_v2_orchestration/qdesn_mcmc_dynamic_alpha_confirm_v1.lock"
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
  echo "Another dynamic-alpha confirmation v1 pipeline holds $LOCK_FILE" >&2
  exit 2
fi

set_stage() {
  printf '%s\n' "$1" > "$CURRENT_STAGE_FILE"
}

record_status() {
  local stage="$1"
  local status="$2"
  local detail="$3"
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "$status" "${detail//,/;}" >> "$STATUS_CSV"
}

resource_values() {
  local load1 memory_kb disk_kb
  load1="$(awk '{print $1}' /proc/loadavg)"
  memory_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  disk_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
  awk -v load="$load1" -v memory="$memory_kb" -v disk="$disk_kb" \
    'BEGIN {printf "%.2f %.1f %.1f", load, memory/1048576, disk/1048576}'
}

write_heartbeat() {
  local values stage
  values="$(resource_values)"
  stage="$(cat "$CURRENT_STAGE_FILE" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "${values// /,}" >> "$HEARTBEAT_CSV"
}

heartbeat_loop() {
  while true; do
    write_heartbeat
    sleep "$HEARTBEAT_SECONDS"
  done
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

storage_audit() {
  local root="$1"
  local output="$2"
  if [[ ! -d "$root" ]]; then
    printf 'run_root_missing\n' > "$output"
    return 1
  fi
  find "$root" -type f \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) \
    -printf '%s\t%p\n' | sort -nr > "$output"
  [[ ! -s "$output" ]]
}

BRANCH="$(git branch --show-current)"
EXPECTED_BRANCH="validation/qdesn-mcmc-dynamic-alpha-confirm-v1-1.0.0"
if [[ "$BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "Wrong branch: $BRANCH" >&2
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
  echo "Launch requires HEAD to match its upstream (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 3
fi

GIT_SHA="$(git rev-parse HEAD)"
GIT_SHORT="$(git rev-parse --short HEAD)"
STAMP="$(date +%Y%m%d_%H%M%S)"
CONFIRMATION_RUN_TAG="qdesn-dacf1-full-${STAMP}__git-${GIT_SHORT}"
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
if [[ "$CPU_COUNT" -ne "$WORKERS" ]]; then
  echo "Expected 20 selected CPUs; found $CPU_COUNT in '$CPU_SET'." >&2
  exit 3
fi
{
  printf 'RUN_ID=%s\n' "$RUN_ID"
  printf 'CONFIRMATION_RUN_TAG=%s\n' "$CONFIRMATION_RUN_TAG"
  printf 'GIT_COMMIT=%s\n' "$GIT_SHA"
  printf 'WORKTREE=%s\n' "$REPO_ROOT"
  printf 'TOTAL_SPECS=30\n'
  printf 'TOTAL_WORKERS=%s\n' "$WORKERS"
  printf 'THREADS_PER_FIT=1\n'
  printf 'CPU_SET=%s\n' "$CPU_SET"
  printf 'ARTICLE_UPDATE_AUTOMATIC=FALSE\n'
} > "$STATE_ROOT/run_tags.env"

COMMON=(
  "$R_SCRIPT" scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R
  --allow-grid-subset
  --methods mcmc
  --priors rhs_ns
  --no-plots
  --stream-child-stdout
  --fit-timeout-seconds 604800
  --fit-timeout-kill-after-seconds 60
)

set_stage "contract_materialize"
record_status "contract_materialize" "STARTED" "regenerate frozen campaign contract"
"$R_SCRIPT" validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_dynamic_alpha_confirm_v1.R \
  --workers "$WORKERS" > "$STATE_ROOT/contract_materialization.log" 2>&1
if [[ -n "$(git status --porcelain)" ]]; then
  record_status "contract_materialize" "FAILED" "materialization changed tracked files"
  git status --short > "$STATE_ROOT/post_materialization_git_status.txt"
  exit 4
fi
record_status "contract_materialize" "COMPLETED" "30-spec contract regenerated without drift"

set_stage "contract_verify"
record_status "contract_verify" "STARTED" "branch=${BRANCH};commit=${GIT_SHA}"
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_mcmc_dynamic_alpha_confirm_v1.R \
  --output "$STATE_ROOT/contract_verification.json" \
  > "$STATE_ROOT/contract_verification.log" 2>&1
record_status "contract_verify" "COMPLETED" "source;seed;budget;storage;parallel contracts pass"

set_stage "prepare_only"
PREPARE_TAG="qdesn-dacf1-prepare-${STAMP}__git-${GIT_SHORT}"
record_status "prepare_only" "STARTED" "$PREPARE_TAG"
"${COMMON[@]}" --workers 1 \
  --defaults "${CONFIG_STUB}_defaults.yaml" \
  --grid "${CONFIG_STUB}_grid.csv" \
  --batch full --prepare-only --run-tag "$PREPARE_TAG" \
  > "$STATE_ROOT/prepare_only.log" 2>&1
find "results/qdesn_mcmc_validation/${STAGE}" -path "*${PREPARE_TAG}*" -type f \
  \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) -print \
  > "$STATE_ROOT/prepare_only_binary_payload_audit.txt" 2>/dev/null || true
if [[ -s "$STATE_ROOT/prepare_only_binary_payload_audit.txt" ]]; then
  record_status "prepare_only" "FAILED" "forbidden model binary payload"
  exit 4
fi
record_status "prepare_only" "COMPLETED" "manifest-only; no model binary payload"

set_stage "smoke"
SMOKE_TAG="qdesn-dacf1-smoke-${STAMP}__git-${GIT_SHORT}"
record_status "smoke" "STARTED" "$SMOKE_TAG"
set +e
"${COMMON[@]}" --workers 2 \
  --defaults "${CONFIG_STUB}_smoke_defaults.yaml" \
  --grid "${CONFIG_STUB}_smoke_grid.csv" \
  --batch full --run-tag "$SMOKE_TAG" \
  > "$STATE_ROOT/smoke.log" 2>&1
SMOKE_RUNNER_RC="$?"
set -e
printf '%s\n' "$SMOKE_RUNNER_RC" > "$STATE_ROOT/smoke_runner_exit_code.txt"
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_qdesn_mcmc_dynamic_alpha_confirm_v1_smoke.R \
  --run-tag "$SMOKE_TAG" --output-root "$STATE_ROOT/smoke_audit" \
  > "$STATE_ROOT/smoke_audit.log" 2>&1
record_status "smoke" "COMPLETED" "2/2 finite contract-valid fits;runner_exit=${SMOKE_RUNNER_RC}"

set_stage "resource_gate"
wait_for_resources
record_status "cpu_selection" "COMPLETED" "workers=20;threads_per_fit=1;cpus=${CPU_SET}"

set_stage "full_confirmation"
record_status "full_confirmation" "STARTED" "run_tag=${CONFIRMATION_RUN_TAG};specs=30;workers=20"
set +e
taskset -c "$CPU_SET" "${COMMON[@]}" --workers "$WORKERS" \
  --defaults "${CONFIG_STUB}_defaults.yaml" \
  --grid "${CONFIG_STUB}_grid.csv" \
  --batch full --run-tag "$CONFIRMATION_RUN_TAG" \
  > "$STATE_ROOT/full_confirmation.log" 2>&1
RUNNER_RC="$?"
set -e
printf '%s\n' "$RUNNER_RC" > "$STATE_ROOT/full_runner_exit_code.txt"
if [[ "$RUNNER_RC" -eq 0 ]]; then
  record_status "full_confirmation" "COMPLETED" "runner_exit=0"
else
  record_status "full_confirmation" "COMPLETED_WITH_FAILURES" "runner_exit=${RUNNER_RC};retain finite outputs"
fi

set_stage "storage_audit"
FULL_ROOT="results/qdesn_mcmc_validation/${STAGE}/${CONFIRMATION_RUN_TAG}"
STORAGE_OK=1
if storage_audit "$FULL_ROOT" "$STATE_ROOT/full_binary_payload_audit.tsv"; then
  record_status "storage_audit" "PASS" "no retained model .rds/.rda/.RData payloads"
else
  record_status "storage_audit" "FAILED" "missing run root or retained model binary payload"
  STORAGE_OK=0
fi

set_stage "closeout"
set +e
"$R_SCRIPT" validation/fitforecast_v2/scripts/closeout_qdesn_mcmc_dynamic_alpha_confirm_v1.R \
  --run-tag "$CONFIRMATION_RUN_TAG" --runner-exit-code "$RUNNER_RC" \
  --output-root "$STATE_ROOT/closeout" > "$STATE_ROOT/closeout.log" 2>&1
CLOSEOUT_RC="$?"
set -e
if [[ "$CLOSEOUT_RC" -eq 0 ]]; then
  record_status "closeout" "COMPLETED" "status-agnostic metric envelope written;article untouched"
else
  record_status "closeout" "FAILED" "exit_code=${CLOSEOUT_RC};resume only invalid or missing roots"
fi

set_stage "pipeline_complete"
write_heartbeat
if [[ "$STORAGE_OK" -eq 1 && "$CLOSEOUT_RC" -eq 0 ]]; then
  record_status "pipeline_complete" "COMPLETED" "confirmation closed;manual article review remains"
  exit 0
fi
record_status "pipeline_complete" "COMPLETED_WITH_REVIEW" "inspect storage and closeout evidence"
exit 1
