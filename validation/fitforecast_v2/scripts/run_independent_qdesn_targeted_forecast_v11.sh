#!/usr/bin/env bash
set -euo pipefail
repo=${REPO_ROOT:?}
run=${RUN_ROOT:?}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
mkdir -p "$run/logs"
exec 9> "$run/.launcher.lock"
flock -n 9 || { printf 'Another IND launcher owns this attempt.\n' >&2; exit 73; }
[[ ! -e "$run/launcher_exit_codes.csv" ]] || { printf 'Use a fresh immutable attempt.\n' >&2; exit 74; }
declare -A active_slots=() active_ids=()
declare -a cpus=() rows=()
started=0; completed=0; failed=0; terminal_state=FAILED_PREFLIGHT
write_status() {
  printf 'status=%s\ntimestamp=%s\nlauncher_pid=%s\nstarted=%s\nfinished=%s\nstage=%s\n' \
    "$1" "$(date -u --iso-8601=seconds)" "$$" "$started" "$completed" "${stage:-preflight}" > "$run/.pipeline.status.tmp"
  mv "$run/.pipeline.status.tmp" "$run/pipeline.status"
}
reap() {
  local pid=$1 rc=0 slot
  wait "$pid" || rc=$?
  slot=${active_slots[$pid]}
  printf '%s,%s,%s,%s\n' "${active_ids[$pid]}" "$pid" "${cpus[$slot]}" "$rc" >> "$run/launcher_exit_codes.csv"
  unset "active_slots[$pid]" "active_ids[$pid]"
  completed=$((completed+1))
  if (( rc )); then failed=1; fi
}
on_exit() {
  local rc=$? pid
  trap - EXIT INT TERM
  set +e
  if [[ $terminal_state != COMPLETE ]]; then
    write_status DRAINING_AFTER_FAILURE
    for pid in "${!active_slots[@]}"; do reap "$pid"; done
    write_status "$terminal_state"
    if (( rc == 0 )); then rc=1; fi
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'terminal_state=INTERRUPTED_DRAINED; exit 130' INT TERM
IFS=',' read -r -a cpus <<< "${CPU_LIST:-25,26,27,28,29,30}"
[[ ${#cpus[@]} == 6 ]]
[[ $(printf '%s\n' "${cpus[@]}" | sort -u | wc -l) == 6 ]]
for cpu in "${cpus[@]}"; do [[ "$cpu" =~ ^[0-9]+$ ]]; done
[[ -x "$rscript" ]]
cd "$repo"
script="$repo/validation/fitforecast_v2/scripts/independent_qdesn_targeted_forecast_v11.R"
printf 'job_id,pid,cpu,exit_code\n' > "$run/launcher_exit_codes.csv"
terminal_state=FAILED_RESOURCE_PREFLIGHT
write_status WAITING_FOR_IDLE_CORES
resource_wait_start=$SECONDS
while ! "$rscript" --vanilla "$repo/validation/fitforecast_v2/scripts/resource_independent_qdesn_mcmc_bridge_v9.R" \
  "${CPU_LIST:-25,26,27,28,29,30}" "$run/resource_start.json" "$repo"; do
  if (( SECONDS-resource_wait_start >= 3600 )); then exit 1; fi
  sleep 30
done
for stage in cost initializers discovery pilot confirmation; do
  terminal_state=FAILED_MANIFEST_OR_PLAN
  "$rscript" --vanilla "$script" "$repo" dispatch "$run" "$stage" > "$run/.launcher_jobs.tmp"
  mapfile -t rows < "$run/.launcher_jobs.tmp"
  next=0; expected=${#rows[@]}
  terminal_state=FAILED_WORKER
  while (( next < expected || ${#active_slots[@]} > 0 )); do
    # Reap all exited peers before starting a replacement.
    for pid in "${!active_slots[@]}"; do
      if ! kill -0 "$pid" 2>/dev/null; then reap "$pid"; fi
    done
    for ((slot=0;slot<6 && next<expected && failed==0;slot++)); do
      busy=0
      for pid in "${!active_slots[@]}"; do
        if [[ ${active_slots[$pid]} == "$slot" ]]; then busy=1; break; fi
      done
      if (( busy )); then continue; fi
      item=${rows[$next]};id=${item%%$'\t'*};config=${item#*$'\t'}
      taskset -c "${cpus[$slot]}" timeout --signal=TERM --kill-after=60s 43200s \
        "$rscript" --vanilla "$script" "$repo" worker "$config" 9>&- > "$run/logs/$id.log" 2>&1 &
      pid=$!;active_slots[$pid]=$slot;active_ids[$pid]=$id
      next=$((next+1));started=$((started+1))
    done
    if (( failed )); then write_status DRAINING_AFTER_WORKER_FAILURE; else write_status RUNNING; fi
    if (( ${#active_slots[@]} == 0 )); then break; fi
    sleep 1
  done
  if (( failed || next != expected )); then exit 1; fi
  terminal_state=FAILED_STAGE_GATE
  write_status ADVANCING
  "$rscript" --vanilla "$script" "$repo" advance "$run" "$stage"
done
terminal_state=FAILED_CLOSEOUT
write_status CLOSING
"$rscript" --vanilla "$script" "$repo" closeout "$run"
write_status COMPLETE
terminal_state=COMPLETE

