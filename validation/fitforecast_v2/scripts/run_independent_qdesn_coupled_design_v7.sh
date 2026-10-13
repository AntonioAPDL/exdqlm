#!/usr/bin/env bash
set -euo pipefail
repo=${REPO_ROOT:?}
run=${RUN_ROOT:?}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
IFS=',' read -r -a cpus <<< "${CPU_LIST:?Provide six verified idle CPUs}"
[[ ${#cpus[@]} == 6 ]]
[[ $(printf '%s\n' "${cpus[@]}" | sort -u | wc -l) == 6 ]]
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
cd "$repo"
script="$repo/validation/fitforecast_v2/scripts/independent_qdesn_coupled_design_v7.R"
mkdir -p "$run/logs"
exec 9> "$run/.launcher.lock"
flock -n 9 || { printf 'Another v7 launcher owns this run.\n' >&2; exit 1; }
declare -A active_slots active_ids
write_status() { printf 'status=%s\ntimestamp=%s\n' "$1" "$(date --iso-8601=seconds)" > "$run/pipeline.status"; }
final_manifest() {
  "$rscript" --vanilla -e 'root<-commandArgs(TRUE)[1];p<-list.files(root,recursive=TRUE,full.names=TRUE);p<-p[!file.info(p)$isdir & basename(p)!="final_artifact_manifest.csv"];write.csv(data.frame(path=p,bytes=file.info(p)$size,sha256=unname(tools::sha256sum(p))),file.path(root,"final_artifact_manifest.csv"),row.names=FALSE)' "$run"
}
on_interrupt() {
  for pid in "${!active_slots[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
  for pid in "${!active_slots[@]}"; do wait "$pid" 2>/dev/null || true; done
  write_status FAILED_OR_INTERRUPTED
  final_manifest
  exit 130
}
trap on_interrupt INT TERM
trap 'write_status FAILED_OR_INTERRUPTED; final_manifest' ERR
printf 'stage,job_id,pid,cpu,exit_code\n' > "$run/launcher_exit_codes.csv"
run_stage() {
  local stage=$1 expected=$2 limit=$3 timeout_seconds=$4 next=0 failed=0 rc finished slot pid item
  local -a rows
  mapfile -t rows < <("$rscript" --vanilla -e 'p<-read.csv(commandArgs(TRUE)[1]);p<-p[p$stage==commandArgs(TRUE)[2],];cat(paste(p$job_id,p$config_path,sep="\t"),sep="\n")' "$run/plan.csv" "$stage")
  [[ ${#rows[@]} == "$expected" ]]
  active_slots=(); active_ids=()
  write_status "RUNNING_$stage"
  while (( next < expected || ${#active_slots[@]} > 0 )); do
    for ((slot=0; slot<limit && next<expected && failed==0; slot++)); do
      local busy=0
      for pid in "${!active_slots[@]}"; do
        if [[ ${active_slots[$pid]} == "$slot" ]]; then busy=1; break; fi
      done
      if (( busy )); then continue; fi
      item=${rows[$next]}
      local id=${item%%$'\t'*} config=${item#*$'\t'}
      taskset -c "${cpus[$slot]}" timeout --signal=TERM --kill-after=60s "${timeout_seconds}s" \
        "$rscript" --vanilla "$script" "$repo" worker "$config" > "$run/logs/$id.log" 2>&1 &
      pid=$!
      active_slots[$pid]=$slot; active_ids[$pid]=$id
      next=$((next+1))
    done
    if (( ${#active_slots[@]} == 0 )); then break; fi
    finished=''
    while [[ -z $finished ]]; do
      for pid in "${!active_slots[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then finished=$pid; break; fi
      done
      if [[ -z $finished ]]; then sleep 0.2; fi
    done
    rc=0
    wait "$finished" || rc=$?
    slot=${active_slots[$finished]}
    printf '%s,%s,%s,%s,%s\n' "$stage" "${active_ids[$finished]}" "$finished" "${cpus[$slot]}" "$rc" >> "$run/launcher_exit_codes.csv"
    unset 'active_slots[$finished]' 'active_ids[$finished]'
    if (( rc )); then failed=1; fi
  done
  if (( failed || next != expected )); then return 1; fi
}
run_stage engineering_cost_smoke 2 2 1800
"$rscript" --vanilla "$script" "$repo" cost-gate "$run"
run_stage design_replay 12 6 21600
"$rscript" --vanilla "$script" "$repo" audit "$run"
write_status COMPLETE
final_manifest
