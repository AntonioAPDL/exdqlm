#!/usr/bin/env bash
set -euo pipefail
repo=${REPO_ROOT:?}
run=${RUN_ROOT:?}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
cpu_csv=${CPU_LIST:?Provide six verified free CPUs}
IFS=',' read -r -a cpus <<< "$cpu_csv"
[[ ${#cpus[@]} == 6 ]]
[[ $(printf '%s\n' "${cpus[@]}" | sort -u | wc -l) == 6 ]]
script="$repo/validation/fitforecast_v2/scripts/independent_qdesn_coupled_tau_v6.R"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
cd "$repo"
mkdir -p "$run/logs"
exec 9> "$run/.launcher.lock"
flock -n 9 || { printf 'Another v6 launcher holds the lock.\n' >&2; exit 1; }
write_status() { printf 'status=%s\ntimestamp=%s\n' "$1" "$(date --iso-8601=seconds)" > "$run/pipeline.status"; }
pids=()
on_interrupt() {
  for pid in "${pids[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
  write_status FAILED_OR_INTERRUPTED
  exit 130
}
trap 'write_status FAILED_OR_INTERRUPTED' ERR
trap on_interrupt INT TERM
printf 'stage,slot,pid,exit_code\n' > "$run/launcher_exit_codes.csv"
run_stage() {
  local stage=$1 count=$2
  local failed=0 rc i
  mapfile -t configs < <("$rscript" --vanilla -e 'p<-read.csv(commandArgs(TRUE)[1]);p<-p[p$stage==commandArgs(TRUE)[2],];cat(p$config_path,sep="\n")' "$run/plan.csv" "$stage")
  [[ ${#configs[@]} == "$count" ]]
  pids=()
  write_status "RUNNING_$stage"
  for ((i=0; i<count; i++)); do
    taskset -c "${cpus[$i]}" timeout --signal=TERM --kill-after=60s 7200s \
      "$rscript" --vanilla "$script" "$repo" worker "${configs[$i]}" \
      > "$run/logs/${stage}_$i.log" 2>&1 &
    pids+=("$!")
  done
  for ((i=0; i<count; i++)); do
    rc=0
    wait "${pids[$i]}" || rc=$?
    printf '%s,%s,%s,%s\n' "$stage" "$i" "${pids[$i]}" "$rc" >> "$run/launcher_exit_codes.csv"
    if (( rc )); then failed=1; fi
  done
  pids=()
  if (( failed )); then write_status FAILED_OR_INTERRUPTED; return 1; fi
}
run_stage reference_replay 2
"$rscript" --vanilla "$script" "$repo" replay-gate "$run"
run_stage tau_screen 6
"$rscript" --vanilla "$script" "$repo" audit "$run"
benchmark_rc=0
if "$rscript" --vanilla -e 'z<-jsonlite::read_json(commandArgs(TRUE)[1],simplifyVector=TRUE);quit(status=if(isTRUE(z$any_forecast_mae_gain))0L else 2L)' "$run/decision.json"; then
  write_status RUNNING_WIDE_NUMERICAL_BENCHMARK
  taskset -c "${cpus[0]}" timeout --signal=TERM --kill-after=60s 1800s \
    "$rscript" --vanilla "$script" "$repo" wide-benchmark "$run" \
    > "$run/logs/wide_benchmark.log" 2>&1 &
  pids=("$!")
  wait "${pids[0]}" || benchmark_rc=$?
  pids=()
  printf '%s\n' "$benchmark_rc" > "$run/benchmark_exit_code.txt"
fi
if (( benchmark_rc )); then
  write_status COMPLETE_WITH_BENCHMARK_FAILURE
else
  write_status COMPLETE
fi
"$rscript" --vanilla -e '
  root<-commandArgs(TRUE)[1]; paths<-list.files(root,recursive=TRUE,full.names=TRUE)
  paths<-paths[!file.info(paths)$isdir & basename(paths)!="final_artifact_manifest.csv"]
  write.csv(data.frame(path=paths,bytes=file.info(paths)$size,sha256=unname(tools::sha256sum(paths))),file.path(root,"final_artifact_manifest.csv"),row.names=FALSE)
' "$run"
