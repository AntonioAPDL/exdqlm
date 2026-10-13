#!/usr/bin/env bash
set -euo pipefail
repo=$(realpath "$1")
run=$(realpath "$2")
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
cli="$repo/validation/fitforecast_v2/scripts/independent_qdesn_rolling_readout_v4.R"
control="$run/control"
mkdir -p "$control"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1 LC_ALL=C
exec 9>"$run/scheduler.lock"
flock -n 9 || { printf 'Another rolling-readout scheduler owns this run.\n' >&2; exit 1; }
declare -A jobs=() configs=() starts=() assigned=()
hold=""; stage="startup"; final=false
status() {
  printf '%s\n' "$(date +%s)" > "$control/heartbeat.epoch"
  printf '%s\t%s\tstage=%s\t%s\n' "$1" "$(date -u +%FT%TZ)" "$stage" "$2" \
    > "$control/scheduler.status.tmp.$$"
  mv "$control/scheduler.status.tmp.$$" "$control/scheduler.status"
  cp "$control/scheduler.status" "$run/scheduler.status"
}
collect() {
  local pid=$1 code=0
  wait "$pid" || code=$?
  if ! "$rscript" "$cli" exit "$repo" "${configs[$pid]}" "$code" \
      >> "$control/scheduler.log" 2>&1; then
    hold="worker_failed_${jobs[$pid]}"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "${jobs[$pid]}" "$code" \
    "$(( $(date +%s) - starts[$pid] ))" "${assigned[$pid]}" "$(date -u +%FT%TZ)" \
    >> "$control/exits.tsv"
  unset 'jobs[$pid]' 'configs[$pid]' 'starts[$pid]' 'assigned[$pid]'
}
drain() {
  local code=$?
  trap - EXIT INT TERM
  if [[ "$final" == true && ${#jobs[@]} == 0 ]]; then return; fi
  set +e
  hold=${hold:-"unexpected_scheduler_exit_$code"}
  status DRAINING "$hold"
  for pid in "${!jobs[@]}"; do collect "$pid"; done
  status PAUSED_REVIEW_REQUIRED "$hold"
  exit 1
}
trap drain EXIT
trap 'hold=signal_INT; exit 130' INT
trap 'hold=signal_TERM; exit 143' TERM
printf '%s\n' "$$" > "$control/scheduler.pid"
cpus=$("$rscript" "$cli" resources "$repo")
IFS=, read -r -a cores <<< "$cpus"
(( ${#cores[@]} >= 1 && ${#cores[@]} <= 15 )) || exit 1
printf '%s\n' "$cpus" > "$control/allocated_cpus.txt"
stages=(screen validation confirmation)
[[ ! -f "$run/manifests/screen_imports.csv" ]] || stages=(validation confirmation)
for stage in "${stages[@]}"; do
  [[ -f "$run/closeout.json" ]] && break
  [[ -f "$run/plans/$stage.csv" ]] || { hold="missing_plan_$stage"; break; }
  pending="$control/pending_$stage.tsv"
  "$rscript" "$cli" pending "$repo" "$run" "$stage" > "$pending"
  mapfile -t queue < "$pending"
  index=0
  while (( index < ${#queue[@]} || ${#jobs[@]} > 0 )); do
    [[ ! -f "$run/STOP_NEW_SCHEDULING" ]] || hold="requested_stop_new_scheduling"
    for pid in "${!jobs[@]}"; do kill -0 "$pid" 2>/dev/null || collect "$pid"; done
    if [[ -n "$hold" ]]; then
      status DRAINING "$hold"
      (( ${#jobs[@]} == 0 )) && break
      sleep 5; continue
    fi
    status RUNNING "workers=${#jobs[@]};maximum=${#cores[@]};queued=$(( ${#queue[@]} - index ))"
    for cpu in "${cores[@]}"; do
      (( index < ${#queue[@]} )) || break
      busy=false
      for pid in "${!assigned[@]}"; do [[ ${assigned[$pid]} == "$cpu" ]] && busy=true; done
      [[ "$busy" == false ]] || continue
      available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
      (( available >= 33554432 )) || break
      IFS=$'\t' read -r id config seconds <<< "${queue[$index]}"
      timeout --signal=TERM --kill-after=120 "$seconds" taskset -c "$cpu" \
        "$rscript" "$cli" worker "$repo" "$config" \
        > "$control/worker_$id.log" 2>&1 &
      pid=$!; jobs[$pid]=$id; configs[$pid]=$config
      starts[$pid]=$(date +%s); assigned[$pid]=$cpu; index=$((index + 1))
    done
    sleep 5
  done
  [[ -z "$hold" ]] || break
  "$rscript" "$cli" advance "$repo" "$run" "$stage" \
    >> "$control/scheduler.log" 2>&1
done
if [[ -n "$hold" ]]; then
  status PAUSED_REVIEW_REQUIRED "$hold"
else
  status COMPLETE_REVIEW_REQUIRED "all_gated_stages_complete"
fi
final=true
[[ -z "$hold" ]]
