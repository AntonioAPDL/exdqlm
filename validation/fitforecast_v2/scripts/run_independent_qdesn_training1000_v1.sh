#!/usr/bin/env bash
set -euo pipefail
repo=$(realpath "$1")
run=$(realpath "$2")
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
cli=${IQT12_CLI:-"$repo/validation/fitforecast_v2/scripts/independent_qdesn_training1000_v1.R"}
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
export LC_ALL=C
exec 9>"$run/scheduler.lock"
flock -n 9 || { printf 'Another IND scheduler owns this run.\n' >&2; exit 1; }
mkdir -p "$run/logs" "$run/receipts"
cpus=$($rscript "$cli" resources "$repo")
IFS=, read -r -a cores <<< "$cpus"
printf '%s\n' "$cpus" > "$run/allocated_cpus.txt"
printf 'RUNNING\t%s\t%s workers\n' "$(date -u +%FT%TZ)" "${#cores[@]}" > "$run/scheduler.status"
declare -A jobs=() configs=() starts=() assigned=()
spent=0
cpu_budget=${IQT12_CPU_BUDGET_SECONDS:-4320000}
if [[ -f "$run/receipts/exits.tsv" ]]; then
  spent=$(awk '{sum += $3} END {printf "%.0f", sum}' "$run/receipts/exits.tsv")
fi
hold=""
read -r -a stages <<< "${IQT12_STAGES:-cost diagnosis size_pilot normal1 normal2 normal3 quantile_A quantile_B bridge final_vb final_warm final_mcmc}"
for stage in "${stages[@]}"; do
  plan="$run/plans/$stage.csv"
  [[ -f "$plan" ]] || { hold="missing_frozen_stage_$stage"; break; }
  pending="$run/receipts/pending_$stage.tsv"
  if ! "$rscript" "$cli" pending "$repo" "$run" "$stage" > "$pending"; then
    hold="unresolved_status_$stage"; break
  fi
  mapfile -t queue < "$pending"
  index=0
  epoch=$(date +%s)
  printf 'RUNNING\t%s\tstage=%s\tworkers=%s\n' "$(date -u +%FT%TZ)" "$stage" "${#cores[@]}" > "$run/scheduler.status"
  while (( index < ${#queue[@]} || ${#jobs[@]} > 0 )); do
    now=$(date +%s)
    [[ ! -f "$run/STOP_NEW_SCHEDULING" ]] || hold="requested_stop_new_scheduling"
    running_time=0
    for pid in "${!jobs[@]}"; do
      if ! kill -0 "$pid" 2>/dev/null; then
        code=0
        wait "$pid" || code=$?
        if ! "$rscript" "$cli" exit "$repo" "${configs[$pid]}" "$code" >> "$run/logs/scheduler.log" 2>&1; then
          hold="worker_failed_${jobs[$pid]}"
        fi
        spent=$((spent + now - starts[$pid]))
        printf '%s\t%s\t%s\t%s\n' "${jobs[$pid]}" "$code" "$((now - starts[$pid]))" "${assigned[$pid]}" >> "$run/receipts/exits.tsv"
        unset 'jobs[$pid]' 'configs[$pid]' 'starts[$pid]' 'assigned[$pid]'
      else
        running_time=$((running_time + now - starts[$pid]))
        child=$(pgrep -P "$pid" | head -n 1 || true)
        if [[ -n "$child" ]]; then
          rss=$(ps -o rss= -p "$child" | tr -d ' ' || true)
          if [[ ${rss:-0} -gt 12582912 ]]; then hold="worker_RSS_review_required"; fi
        fi
      fi
    done
    size=$(du -sk "$run" | awk '{print $1}')
    free=$(df -Pk "$run" | awk 'NR==2 {print $4}')
    (( size <= 41943040 && free >= 20971520 )) || hold="disk_budget_review_required"
    (( spent + running_time < cpu_budget )) || hold="worker_hour_budget_review_required"
    (( now - epoch < 172800 )) || hold="48h_stage_wall_budget_review_required"
    if [[ -n "$hold" ]]; then
      printf 'DRAINING\t%s\t%s\n' "$(date -u +%FT%TZ)" "$hold" > "$run/scheduler.status"
      if (( ${#jobs[@]} == 0 )); then break; fi
      sleep 5
      continue
    fi
    for cpu in "${cores[@]}"; do
      (( index < ${#queue[@]} )) || break
      busy=false
      for pid in "${!assigned[@]}"; do
        if [[ ${assigned[$pid]} == "$cpu" ]]; then busy=true; break; fi
      done
      [[ "$busy" == false ]] || continue
      available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
      (( available >= 37748736 )) || break
      IFS=$'\t' read -r id config seconds <<< "${queue[$index]}"
      timeout --signal=TERM --kill-after=120 "$seconds" taskset -c "$cpu" \
        "$rscript" "$cli" worker "$repo" "$config" > "$run/logs/$id.log" 2>&1 &
      pid=$!
      jobs[$pid]=$id; configs[$pid]=$config; starts[$pid]=$(date +%s); assigned[$pid]=$cpu
      index=$((index + 1))
    done
    sleep 5
  done
  [[ -z "$hold" ]] || break
  if [[ ${IQT12_STOP_AFTER_STAGE:-} == "$stage" ]]; then
    printf 'WORKER_SMOKE_COMPLETE\t%s\tstage=%s\n' "$(date -u +%FT%TZ)" "$stage" > "$run/scheduler.status"
    exit 0
  fi
  if ! "$rscript" "$cli" advance "$repo" "$run" "$stage" >> "$run/logs/scheduler.log" 2>&1; then
    hold="stage_gate_$stage"; break
  fi
  if [[ -f "$run/early_complete.json" ]]; then break; fi
done
if [[ -n "$hold" ]]; then
  printf 'PAUSED_REVIEW_REQUIRED\t%s\t%s\n' "$(date -u +%FT%TZ)" "$hold" > "$run/scheduler.status"
  exit 1
fi
printf 'COMPLETE_REVIEW_REQUIRED\t%s\n' "$(date -u +%FT%TZ)" > "$run/scheduler.status"
