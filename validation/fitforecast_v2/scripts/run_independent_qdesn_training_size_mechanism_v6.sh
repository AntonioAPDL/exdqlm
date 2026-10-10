#!/usr/bin/env bash
set -euo pipefail

repo=$(realpath "$1")
run=$(realpath "$2")
workers=${3:-30}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
cli="$repo/validation/fitforecast_v2/scripts/independent_qdesn_training_size_mechanism_v6.R"
control="$run/control"
mkdir -p "$control"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1
export LC_ALL=C

exec 9>"$run/scheduler.lock"
flock -n 9 || { printf 'Another v6 scheduler owns this run.\n' >&2; exit 1; }

declare -A job_id=()
declare -A job_config=()
declare -A job_start=()
declare -A job_cpu=()
hold=""
stage="startup"
finished=false

write_status() {
  printf '%s\n' "$(date +%s)" > "$control/heartbeat.epoch"
  printf '%s\t%s\tstage=%s\t%s\n' "$1" "$(date -u +%FT%TZ)" "$stage" "$2" \
    > "$control/scheduler.status.tmp.$$"
  mv "$control/scheduler.status.tmp.$$" "$control/scheduler.status"
  cp "$control/scheduler.status" "$run/scheduler.status"
}

collect() {
  local pid=$1
  local code=0
  wait "$pid" || code=$?
  local elapsed=$(( $(date +%s) - job_start[$pid] ))
  if ! "$rscript" "$cli" exit "$repo" "${job_config[$pid]}" "$code" "$elapsed" \
      >> "$control/scheduler.log" 2>&1; then
    hold="worker_failed_${job_id[$pid]}"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "${job_id[$pid]}" "$code" "$elapsed" \
    "${job_cpu[$pid]}" "$(date -u +%FT%TZ)" >> "$control/exits.tsv"
  unset 'job_id[$pid]' 'job_config[$pid]' 'job_start[$pid]' 'job_cpu[$pid]'
}

drain() {
  local code=$?
  trap - EXIT INT TERM
  if [[ "$finished" == true && ${#job_id[@]} == 0 ]]; then return; fi
  set +e
  hold=${hold:-"unexpected_scheduler_exit_$code"}
  write_status DRAINING "$hold"
  for pid in "${!job_id[@]}"; do collect "$pid"; done
  write_status PAUSED_REVIEW_REQUIRED "$hold"
  exit 1
}
trap drain EXIT
trap 'hold=signal_INT; exit 130' INT
trap 'hold=signal_TERM; exit 143' TERM

printf '%s\n' "$$" > "$control/scheduler.pid"
cpus=$("$rscript" "$cli" resources "$repo" "$workers")
IFS=, read -r -a cores <<< "$cpus"
(( ${#cores[@]} == workers )) || { printf 'Physical-core allocation failed.\n' >&2; exit 1; }
printf '%s\n' "$cpus" > "$control/allocated_cpus.txt"

for stage in smoke representation quantile validation rolling mcmc; do
  [[ -f "$run/closeout.json" ]] && break
  [[ -f "$run/plans/$stage.csv" ]] || { hold="missing_plan_$stage"; break; }
  pending="$control/pending_$stage.tsv"
  "$rscript" "$cli" pending "$repo" "$run" "$stage" > "$pending"
  mapfile -t queue < "$pending"
  index=0
  while (( index < ${#queue[@]} || ${#job_id[@]} > 0 )); do
    [[ ! -f "$run/STOP_NEW_SCHEDULING" ]] || hold="requested_stop_new_scheduling"
    for pid in "${!job_id[@]}"; do
      kill -0 "$pid" 2>/dev/null || collect "$pid"
    done
    if [[ -n "$hold" ]]; then
      write_status DRAINING "$hold"
      (( ${#job_id[@]} == 0 )) && break
      sleep 3
      continue
    fi
    write_status RUNNING "workers=${#job_id[@]};maximum=${#cores[@]};queued=$(( ${#queue[@]} - index ))"
    for cpu in "${cores[@]}"; do
      (( index < ${#queue[@]} )) || break
      busy=false
      for pid in "${!job_cpu[@]}"; do
        [[ ${job_cpu[$pid]} == "$cpu" ]] && busy=true
      done
      [[ "$busy" == false ]] || continue
      available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
      (( available >= 67108864 )) || break
      IFS=$'\t' read -r id config seconds <<< "${queue[$index]}"
      timeout --signal=TERM --kill-after=180 "$seconds" taskset -c "$cpu" \
        "$rscript" "$cli" worker "$repo" "$config" \
        > "$control/worker_$id.log" 2>&1 &
      pid=$!
      job_id[$pid]=$id
      job_config[$pid]=$config
      job_start[$pid]=$(date +%s)
      job_cpu[$pid]=$cpu
      index=$((index + 1))
    done
    sleep 3
  done
  [[ -z "$hold" ]] || break
  "$rscript" "$cli" advance "$repo" "$run" "$stage" \
    >> "$control/scheduler.log" 2>&1
done

if [[ -n "$hold" ]]; then
  write_status PAUSED_REVIEW_REQUIRED "$hold"
else
  write_status COMPLETE_REVIEW_REQUIRED all_gated_stages_complete
fi
finished=true
[[ -z "$hold" ]]
