#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-6}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
POLL_SECONDS="${POLL_SECONDS:-300}"
[[ "${QDESN_LTCV1_CONFIRMATION_APPROVED:-false}" == "true" ]] || { echo "Explicit confirmation approval is required." >&2; exit 3; }
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 6 ]] || { echo "WORKERS must be 1..6" >&2; exit 3; }
cd "$REPO_ROOT"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
OUT="$STATE_ROOT/confirmation"
STATUS="$STATE_ROOT/stage_status.csv"
CURRENT="$STATE_ROOT/current_stage.txt"
WORKER="validation/fitforecast_v2/scripts/run_qdesn_lower_tail_cellwise_mcmc_v1_chain.R"
MAT="validation/fitforecast_v2/scripts/materialize_qdesn_lower_tail_cellwise_mcmc_v1_confirmation.R"
VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_lower_tail_cellwise_mcmc_v1_confirmation.R"
CLOSE="validation/fitforecast_v2/scripts/closeout_qdesn_lower_tail_cellwise_mcmc_v1_confirmation.R"
LOCK="reports/shared_fitforecast_v2_orchestration/qdesn_lower_tail_cellwise_mcmc_v1_confirmation.lock"
record(){ printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS"; }
stage(){ printf '%s\n' "$1" > "$CURRENT"; }
resource_values(){
  local load memory disk count idle
  load="$(awk '{print $1}' /proc/loadavg)"
  memory="$(awk '/MemAvailable:/ {print $2/1048576}' /proc/meminfo)"
  disk="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4/1048576}')"
  count="$(getconf _NPROCESSORS_ONLN)"
  idle="$(ps -eLo psr=,pcpu= | awk -v n="$count" -v lim="$MAX_IDLE_CPU_PERCENT" '{u[$1+0]+=$2} END{for(i=0;i<n;i++)if((u[i]+0)<=lim)c++;print c+0}')"
  printf '%.2f %.1f %.1f %d\n' "$load" "$memory" "$disk" "$idle"
}
select_cpus(){
  local count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= | awk -v n="$count" '{u[$1+0]+=$2} END{for(i=0;i<n;i++)printf "%d %.6f\n",i,u[i]+0}' |
    sort -k2,2n -k1,1n | awk -v n="$WORKERS" -v lim="$MAX_IDLE_CPU_PERCENT" '$2<=lim&&c<n{print $1;c++}' | paste -sd, -
}
wait_for_resources(){
  while true; do
    local values load memory disk idle
    values="$(resource_values)"; read -r load memory disk idle <<< "$values"
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v i="$idle" -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" -v w="$WORKERS" 'BEGIN{exit !((l<=ml)&&(m>=mm)&&(d>=md)&&(i>=w))}'; then
      record tier_a_confirmation_resource_gate PASS "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return
    fi
    record tier_a_confirmation_resource_gate WAIT "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle};workers=${WORKERS}"
    sleep "$POLL_SECONDS"
  done
}
exec 9>"$LOCK"; flock -n 9 || { echo "Confirmation already active." >&2; exit 3; }
[[ "$(git branch --show-current)" == "validation/qdesn-lower-tail-cellwise-mcmc-v1-1.0.0" ]] || { echo "Wrong branch" >&2; exit 3; }
[[ -z "$(git status --porcelain)" ]] || { echo "Clean worktree required" >&2; exit 3; }
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || { echo "Synchronized branch required" >&2; exit 3; }
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
stage tier_a_confirmation_preflight; record tier_a_confirmation_preflight STARTED "approved;canonical source;sealed handoff;storage"
"$R_SCRIPT" "$MAT" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" --output-root "$OUT" > "$STATE_ROOT/confirmation_materialize.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" --run-tag "$RUN_TAG" --output "$STATE_ROOT/confirmation_preflight_verification.json" > "$STATE_ROOT/confirmation_preflight_verification.log" 2>&1
record tier_a_confirmation_preflight COMPLETED "6 chains;canonical article source;M0;5000+20000"
PLAN="$OUT/confirmation_plan.csv"; LIST="$STATE_ROOT/confirmation_configs.txt"
"$R_SCRIPT" -e 'x<-read.csv(commandArgs(TRUE)[1],check.names=FALSE);writeLines(x$config_path)' "$PLAN" > "$LIST"
stage tier_a_confirmation_resource_gate; wait_for_resources
CPU_SET="${CPU_SET:-$(select_cpus)}"
[[ "$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)" -eq "$WORKERS" ]] || { record tier_a_confirmation_cpu_selection FAILED "cpus=${CPU_SET}"; exit 3; }
record tier_a_confirmation_cpu_selection COMPLETED "workers=${WORKERS};threads=1;cpus=${CPU_SET}"
stage tier_a_confirmation; record tier_a_confirmation STARTED "jobs=6;parallelism=${WORKERS};one_thread_each;resumable"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$WORKERS" "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config < "$LIST" > "$STATE_ROOT/confirmation_workers.log" 2>&1
RC="$?"; set -e; printf '%s\n' "$RC" > "$STATE_ROOT/confirmation_worker_exit_code.txt"
[[ "$RC" -eq 0 ]] || { record tier_a_confirmation FAILED "worker_exit=${RC};resume_same_run_tag"; exit "$RC"; }
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" --run-tag "$RUN_TAG" --runtime true --output "$STATE_ROOT/confirmation_verification.json" > "$STATE_ROOT/confirmation_verification.log" 2>&1
record tier_a_confirmation COMPLETED "6/6 finite;storage-light;config-matched"
stage tier_a_confirmation_closeout
"$R_SCRIPT" "$CLOSE" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" --run-tag "$RUN_TAG" > "$STATE_ROOT/confirmation_closeout.log" 2>&1
record tier_a_confirmation_closeout COMPLETED "promotion ledger materialized;article unchanged"
stage confirmation_complete; record confirmation_complete COMPLETED "manual promotion review required;article v6 unchanged"
printf 'Lower-tail canonical confirmation complete: %s\n' "$RUN_TAG"
