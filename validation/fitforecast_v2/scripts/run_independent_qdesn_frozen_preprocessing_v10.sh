#!/usr/bin/env bash
set -euo pipefail
repo=${REPO_ROOT:?}
run=${RUN_ROOT:?}
legacy=${LEGACY_RUN_ROOT:?}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
mkdir -p "$run/logs"
exec 9> "$run/.launcher.lock"
flock -n 9 || { printf 'Another v10 launcher owns this run.\n' >&2; exit 73; }
[[ ! -e "$run/launcher_exit_codes.csv" ]] || {
  printf 'Use a fresh attempt directory; existing launcher evidence is immutable.\n' >&2
  exit 74
}
# Bash 4.4 nounset requires assigned arrays, even before the first child starts.
declare -A active_slots=() active_ids=()
declare -a cpus=() rows=()
next=0; failed=0; completed=0; terminal_state=FAILED_PREFLIGHT
write_status() {
  printf 'status=%s\ntimestamp=%s\nlauncher_pid=%s\nstarted=%s\nfinished=%s\n' \
    "$1" "$(date -u --iso-8601=seconds)" "$$" "$next" "$completed" > "$run/.pipeline.status.tmp"
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
write_status PREPARING_REPLAY
[[ -x "$rscript" ]]
IFS=',' read -r -a cpus <<< "${CPU_LIST:-25,26,27,28,29,30}"
[[ ${#cpus[@]} == 6 ]]
[[ $(printf '%s\n' "${cpus[@]}" | sort -u | wc -l) == 6 ]]
for cpu in "${cpus[@]}"; do [[ "$cpu" =~ ^[0-9]+$ ]]; done
cd "$repo"
script="$repo/validation/fitforecast_v2/scripts/independent_qdesn_frozen_preprocessing_v10.R"
[[ -r "$script" ]]
printf 'job_id,pid,cpu,exit_code\n' > "$run/launcher_exit_codes.csv"
terminal_state=FAILED_MANIFEST_OR_PLAN
"$rscript" --vanilla -e '
root<-commandArgs(TRUE)[1]
for(f in c("materialization_hashes.csv","source_hashes.csv")) {
  m<-read.csv(file.path(root,f));stopifnot(nrow(m)>0L,
    all(file.exists(m$path)),all(unname(tools::sha256sum(m$path))==m$sha256))
}
p<-read.csv(file.path(root,"plan.csv"),stringsAsFactors=FALSE)
stopifnot(all(c("job_id","config_path","config_sha256","status_path","result_path") %in% names(p)),
  nrow(p)==14L,!anyNA(p),!anyDuplicated(p$job_id),!anyDuplicated(p$config_path),
  !anyDuplicated(p$status_path),!anyDuplicated(p$result_path),
  all(grepl("^[A-Za-z0-9_-]+$",p$job_id)),all(file.exists(p$config_path)),
  all(unname(tools::sha256sum(p$config_path))==p$config_sha256),
  !any(file.exists(p$status_path)),!any(file.exists(p$result_path)),
  !any(grepl("[[:cntrl:]]",p$config_path)))
cat(paste(p$job_id,p$config_path,sep="\t"),sep="\n")
' "$run" > "$run/.launcher_jobs.tmp"
mapfile -t rows < "$run/.launcher_jobs.tmp"
[[ ${#rows[@]} == 14 ]]
terminal_state=FAILED_SOURCE_DEPENDENCY
write_status WAITING_FOR_V9_CORES
while true; do
  state=$(sed -n 's/^status=//p' "$legacy/pipeline.status")
  if [[ $state == COMPLETE ]]; then break; fi
  if [[ $state == FAILED* || $state == INTERRUPTED* ]]; then
    terminal_state=BLOCKED_SOURCE_CAMPAIGN
    exit 1
  fi
  sleep 30
done
"$rscript" --vanilla -e '
root<-commandArgs(TRUE)[1];z<-jsonlite::read_json(file.path(root,"closeout.json"),simplifyVector=TRUE)
stopifnot(z$status=="COMPLETE_INTERNAL_MCMC_BRIDGE",z$successful_jobs==14L,z$failures==0L)
m<-read.csv(file.path(root,"final_artifact_manifest.csv"));stopifnot(nrow(m)>0L,
  all(file.exists(m$path)),all(unname(tools::sha256sum(m$path))==m$sha256))
' "$legacy"
terminal_state=FAILED_RESOURCE_PREFLIGHT
write_status WAITING_FOR_IDLE_CORES
resource_wait_start=$SECONDS
while ! "$rscript" --vanilla "$repo/validation/fitforecast_v2/scripts/resource_independent_qdesn_mcmc_bridge_v9.R" \
  "${CPU_LIST:-25,26,27,28,29,30}" "$run/resource_replay.json" "$repo"; do
  if (( SECONDS-resource_wait_start >= 3600 )); then exit 1; fi
  sleep 30
done
terminal_state=FAILED_REPLAY
write_status RUNNING_REPLAY
expected=${#rows[@]}
while (( next < expected || ${#active_slots[@]} > 0 )); do
  # Observe every completed peer before dispatching replacements.
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
    pid=$!;active_slots[$pid]=$slot;active_ids[$pid]=$id;next=$((next+1))
  done
  if (( failed )); then write_status DRAINING_AFTER_WORKER_FAILURE; else write_status RUNNING_REPLAY; fi
  if (( ${#active_slots[@]} == 0 )); then break; fi
  sleep 1
done
if (( failed || next != expected )); then exit 1;fi
terminal_state=FAILED_CLOSEOUT
write_status CLOSING_REPLAY
"$rscript" --vanilla "$script" "$repo" closeout "$run"
terminal_state=FAILED_FINAL_MANIFEST
"$rscript" --vanilla -e '
r<-commandArgs(TRUE)[1];p<-list.files(r,recursive=TRUE,full.names=TRUE)
p<-p[!file.info(p)$isdir & !basename(p) %in% c("final_artifact_manifest.csv",
  "pipeline.status","orchestrator.stdout.log")]
write.csv(data.frame(path=p,bytes=file.info(p)$size,sha256=unname(tools::sha256sum(p))),
  file.path(r,"final_artifact_manifest.csv"),row.names=FALSE)
' "$run"
write_status COMPLETE
terminal_state=COMPLETE
