#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-3}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
[[ "${QDESN_PLRV1_FORECAST_CONFIRMATION_APPROVED:-false}" == "true" ]] || {
  echo "Explicit forecast-first confirmation approval is required." >&2; exit 3;
}
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 3 ]] || {
  echo "WORKERS must be 1..3" >&2; exit 3;
}
cd "$REPO_ROOT"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
OUT="$STATE_ROOT/forecast_first_confirmation"
STATUS="$STATE_ROOT/stage_status.csv"
HEARTBEAT="$STATE_ROOT/heartbeat.csv"
CURRENT="$STATE_ROOT/current_stage.txt"
WORKER="validation/fitforecast_v2/scripts/run_qdesn_postm0_legacy_recheck_v1_chain.R"
MAT="validation/fitforecast_v2/scripts/materialize_qdesn_postm0_legacy_recheck_v1_confirmation.R"
VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_postm0_legacy_recheck_v1_confirmation.R"
CLOSE="validation/fitforecast_v2/scripts/closeout_qdesn_postm0_legacy_recheck_v1_confirmation.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_qdesn_postm0_legacy_recheck_v1.R"
LOCK="reports/shared_fitforecast_v2_orchestration/qdesn_postm0_legacy_recheck_v1_confirmation.lock"
record(){ printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS"; }
stage(){ printf '%s\n' "$1" > "$CURRENT"; }
resource_values(){
  local load memory disk count idle
  load="$(awk '{print $1}' /proc/loadavg)"
  memory="$(awk '/MemAvailable:/ {print $2/1048576}' /proc/meminfo)"
  disk="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4/1048576}')"
  count="$(getconf _NPROCESSORS_ONLN)"
  idle="$(ps -eLo psr=,pcpu= | awk -v n="$count" -v lim="$MAX_IDLE_CPU_PERCENT" \
    '{u[$1+0]+=$2} END{for(i=0;i<n;i++)if((u[i]+0)<=lim)c++;print c+0}')"
  printf '%.2f %.1f %.1f %d\n' "$load" "$memory" "$disk" "$idle"
}
write_heartbeat(){
  local values
  values="$(resource_values)"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" \
    "$(cat "$CURRENT" 2>/dev/null || printf initializing)" "${values// /,}" >> "$HEARTBEAT"
}
heartbeat_loop(){ while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done; }
wait_for_resources(){
  while true; do
    local values load memory disk idle
    values="$(resource_values)"; read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v i="$idle" \
      -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      -v w="$WORKERS" 'BEGIN{exit !((l<=ml)&&(m>=mm)&&(d>=md)&&(i>=w))}'; then
      record forecast_first_confirmation_resource_gate PASS \
        "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return
    fi
    record forecast_first_confirmation_resource_gate WAIT \
      "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle};workers=${WORKERS}"
    sleep "$POLL_SECONDS"
  done
}
select_cpus(){
  local count
  count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= | awk -v n="$count" \
    '{u[$1+0]+=$2} END{for(i=0;i<n;i++)printf "%d %.6f\n",i,u[i]+0}' |
    sort -k2,2n -k1,1n | awk -v n="$WORKERS" -v lim="$MAX_IDLE_CPU_PERCENT" \
    '$2<=lim&&c<n{print $1;c++}' | paste -sd, -
}
exec 9>"$LOCK"
flock -n 9 || { echo "Forecast-first confirmation already active." >&2; exit 3; }
[[ "$(git branch --show-current)" == \
  "validation/qdesn-postm0-legacy-recheck-v1-1.0.0" ]] || {
  echo "Wrong branch" >&2; exit 3;
}
[[ -z "$(git status --porcelain)" ]] || { echo "Clean worktree required" >&2; exit 3; }
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || {
  echo "Synchronized branch required" >&2; exit 3;
}
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
heartbeat_loop & HEARTBEAT_PID="$!"
cleanup(){
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM
stage forecast_first_confirmation_preflight
record forecast_first_confirmation_preflight STARTED \
  "approved;canonical source;exact M0;forecast MAE primary;diagnostics descriptive"
"$R_SCRIPT" "$MAT" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --output-root "$OUT" > "$STATE_ROOT/forecast_first_confirmation_materialize.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --run-tag "$RUN_TAG" --output "$STATE_ROOT/forecast_first_confirmation_preflight_verification.json" \
  > "$STATE_ROOT/forecast_first_confirmation_preflight_verification.log" 2>&1
record forecast_first_confirmation_preflight COMPLETED \
  "3 chains;canonical source;5000+20000;strict mean forecast MAE rule"
PLAN="$OUT/confirmation_plan.csv"
LIST="$STATE_ROOT/forecast_first_confirmation_configs.txt"
"$R_SCRIPT" -e 'x<-read.csv(commandArgs(TRUE)[1],check.names=FALSE);writeLines(x$config_path)' \
  "$PLAN" > "$LIST"
JOBS="$(wc -l < "$LIST")"
[[ "$JOBS" -eq 3 ]] || { echo "Expected three confirmation jobs." >&2; exit 3; }
stage forecast_first_confirmation_resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_cpus)}"
[[ "$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)" -eq "$WORKERS" ]] || {
  record forecast_first_confirmation_cpu_selection FAILED "cpus=${CPU_SET}"; exit 3;
}
record forecast_first_confirmation_cpu_selection COMPLETED \
  "workers=${WORKERS};threads=1;cpus=${CPU_SET}"
stage forecast_first_confirmation
record forecast_first_confirmation STARTED \
  "jobs=3;parallelism=${WORKERS};one_thread_each;resumable"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$WORKERS" \
  "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
  < "$LIST" > "$STATE_ROOT/forecast_first_confirmation_workers.log" 2>&1
RC="$?"; set -e
printf '%s\n' "$RC" > "$STATE_ROOT/forecast_first_confirmation_worker_exit_code.txt"
"$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
  --plan "$PLAN" --output "$STATE_ROOT/forecast_first_confirmation_health.csv" \
  > "$STATE_ROOT/forecast_first_confirmation_health.log" 2>&1 || true
[[ "$RC" -eq 0 ]] || {
  record forecast_first_confirmation FAILED "worker_exit=${RC};resume_same_run_tag"; exit "$RC";
}
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --run-tag "$RUN_TAG" --runtime true \
  --output "$STATE_ROOT/forecast_first_confirmation_verification.json" \
  > "$STATE_ROOT/forecast_first_confirmation_verification.log" 2>&1
record forecast_first_confirmation COMPLETED \
  "3/3 finite;storage-light;diagnostics recorded but not gated"
stage forecast_first_confirmation_closeout
"$R_SCRIPT" "$CLOSE" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --run-tag "$RUN_TAG" > "$STATE_ROOT/forecast_first_confirmation_closeout.log" 2>&1
record forecast_first_confirmation_closeout COMPLETED \
  "forecast-first promotion ledger materialized;article unchanged"
stage confirmation_complete
record confirmation_complete COMPLETED \
  "metric-specific promotion decision ready;article update remains manual"
printf 'Post-M0 forecast-first confirmation complete: %s\n' "$RUN_TAG"
