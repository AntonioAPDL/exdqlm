#!/usr/bin/env bash
set -euo pipefail
driver=$(realpath "$1")
science=$(realpath "$2")
run=$(realpath "$3")
control=$(realpath "$4")
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
helper="$driver/validation/fitforecast_v2/scripts/independent_qdesn_training1000_recovery_v1.R"
cli="$science/validation/fitforecast_v2/scripts/independent_qdesn_training1000_targeted_v2.R"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1 LC_ALL=C
exec 9>"$run/scheduler.lock"
flock -n 9 || { printf 'Another IND scheduler owns this run.\n' >&2; exit 1; }
declare -A jobs=() configs=() starts=() assigned=()
spent=0; hold=""; stage="startup"; final_written=false
status() {
  local label=$1 reason=$2 epoch
  epoch=$(date +%s)
  printf '%s\n' "$epoch" > "$control/heartbeat.epoch"
  printf '%s\t%s\tstage=%s\t%s\n' "$label" "$(date -u +%FT%TZ)" "$stage" "$reason" > "$control/scheduler.status.tmp.$$"
  mv "$control/scheduler.status.tmp.$$" "$control/scheduler.status"
  cp "$control/scheduler.status" "$run/scheduler.status"
}
collect() {
  local pid=$1 code=0 wall cost
  wait "$pid" || code=$?
  wall=$(( $(date +%s) - starts[$pid] ))
  if ! "$rscript" "$cli" exit "$science" "${configs[$pid]}" "$code" >> "$control/scheduler.log" 2>&1; then
    hold="worker_failed_${jobs[$pid]}"
  fi
  if cost=$("$rscript" "$helper" account "$driver" "$control" "${configs[$pid]}" "$code" "$wall" "${assigned[$pid]}" 2>> "$control/scheduler.log"); then
    [[ "$cost" =~ ^[0-9]+$ ]] || { hold="invalid_exit_accounting"; cost=$wall; }
  else
    hold="exit_accounting_failed_${jobs[$pid]}"; cost=$wall
  fi
  spent=$((spent + cost))
  unset 'jobs[$pid]' 'configs[$pid]' 'starts[$pid]' 'assigned[$pid]'
}
drain_on_exit() {
  local code=$?
  trap - EXIT INT TERM
  if [[ "$final_written" == true && ${#jobs[@]} == 0 ]]; then return; fi
  set +e
  hold=${hold:-"unexpected_driver_exit_$code"}
  status DRAINING "$hold"
  # Own timeout child PIDs only; never signal another lane or discard successful output.
  for pid in "${!jobs[@]}"; do collect "$pid"; status DRAINING "$hold"; done
  status PAUSED_REVIEW_REQUIRED "$hold"
  exit 1
}
trap drain_on_exit EXIT
trap 'hold="driver_signal_INT"; exit 130' INT
trap 'hold="driver_signal_TERM"; exit 143' TERM
printf '%s\n' "$$" > "$control/scheduler.pid"
if ! snapshot=$("$rscript" "$helper" context "$driver" "$control" 2>> "$control/scheduler.log"); then
  hold="recovery_context_verification_failed"; exit 1
fi
IFS=$'\t' read -r spent cpu_budget max_workers <<< "$snapshot"
[[ "$spent" =~ ^[0-9]+$ && "$cpu_budget" =~ ^[0-9]+$ && "$max_workers" == 15 ]] || exit 1
if ! cpus=$("$rscript" "$cli" resources "$science" 2>> "$control/scheduler.log"); then
  hold="unused_core_capacity_unavailable"; exit 1
fi
IFS=, read -r -a cores <<< "$cpus"
(( ${#cores[@]} > 0 && ${#cores[@]} <= max_workers )) || exit 1
for cpu in "${cores[@]}"; do [[ "$cpu" =~ ^[0-9]+$ ]] || exit 1; done
printf '%s\n' "$cpus" > "$control/allocated_cpus.txt"
for stage in bridge final_vb final_warm final_mcmc; do
  if ! epoch=$("$rscript" "$helper" stage "$driver" "$control" "$stage" 2>> "$control/scheduler.log"); then
    hold="missing_or_invalid_frozen_stage_$stage"; break
  fi
  [[ "$epoch" =~ ^[0-9]+$ ]] || { hold="invalid_stage_epoch"; break; }
  pending="$control/pending_$stage.tsv"
  if ! "$rscript" "$cli" pending "$science" "$run" "$stage" > "$pending" 2>> "$control/scheduler.log"; then
    hold="unresolved_status_$stage"; break
  fi
  mapfile -t queue < "$pending"
  index=0
  while (( index < ${#queue[@]} || ${#jobs[@]} > 0 )); do
    now=$(date +%s)
    [[ ! -f "$run/STOP_NEW_SCHEDULING" && ! -f "$control/STOP_NEW_SCHEDULING" ]] || hold="requested_stop_new_scheduling"
    running_time=0
    for pid in "${!jobs[@]}"; do
      if ! kill -0 "$pid" 2>/dev/null; then
        collect "$pid"
      else
        running_time=$((running_time + now - starts[$pid]))
        child=$(pgrep -P "$pid" | head -n 1 || true)
        if [[ -n "$child" ]]; then
          rss=$(ps -o rss= -p "$child" | tr -d ' ' || true)
          if [[ ${rss:-0} -gt 12582912 ]]; then hold="worker_RSS_review_required"; fi
        fi
      fi
    done
    if [[ -z "$hold" ]]; then
      if ! "$rscript" "$helper" telemetry "$driver" "$control" > "$control/latest_disk.tsv" 2>> "$control/scheduler.log"; then
        hold="disk_telemetry_or_budget_review_required"
      fi
      (( spent + running_time < cpu_budget )) || hold="worker_hour_budget_review_required"
      (( now - epoch < 172800 )) || hold="48h_original_stage_deadline_review_required"
    fi
    if [[ -n "$hold" ]]; then
      status DRAINING "$hold"
      if (( ${#jobs[@]} == 0 )); then break; fi
      sleep 5
      continue
    fi
    status RUNNING "recovery_workers=${#jobs[@]};maximum=${#cores[@]};accounted_seconds=$spent"
    for cpu in "${cores[@]}"; do
      (( index < ${#queue[@]} )) || break
      busy=false
      for pid in "${!assigned[@]}"; do
        if [[ ${assigned[$pid]} == "$cpu" ]]; then busy=true; break; fi
      done
      [[ "$busy" == false ]] || continue
      available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
      [[ "$available" =~ ^[0-9]+$ ]] || { hold="memory_telemetry_invalid"; break; }
      (( available >= 37748736 )) || break
      IFS=$'\t' read -r id config seconds <<< "${queue[$index]}"
      [[ "$seconds" =~ ^[0-9]+$ && "$id" =~ ^[A-Za-z0-9_]+$ && -f "$config" ]] || { hold="invalid_pending_row"; break; }
      timeout --signal=TERM --kill-after=120 "$seconds" taskset -c "$cpu" \
        "$rscript" "$cli" worker "$science" "$config" > "$control/worker_$id.log" 2>&1 &
      pid=$!
      jobs[$pid]=$id; configs[$pid]=$config; starts[$pid]=$(date +%s); assigned[$pid]=$cpu
      index=$((index + 1))
    done
    sleep 5
  done
  [[ -z "$hold" ]] || break
  if ! "$rscript" "$cli" advance "$science" "$run" "$stage" >> "$control/scheduler.log" 2>&1; then
    hold="stage_gate_$stage"; break
  fi
  if [[ -f "$run/early_complete.json" ]]; then break; fi
done
if [[ -n "$hold" ]]; then status PAUSED_REVIEW_REQUIRED "$hold"; else status COMPLETE_REVIEW_REQUIRED "source_unchanged"; fi
final_written=true
[[ -z "$hold" ]]
