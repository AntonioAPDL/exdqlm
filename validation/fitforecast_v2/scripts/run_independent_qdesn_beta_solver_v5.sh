#!/usr/bin/env bash
set -euo pipefail
repo=${REPO_ROOT:?}
run=${RUN_ROOT:?}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
cpu_csv=${CPU_LIST:?Provide four verified free CPUs}
IFS=',' read -r -a cpus <<< "$cpu_csv"
[[ ${#cpus[@]} == 4 ]]
script="$repo/validation/fitforecast_v2/scripts/independent_qdesn_beta_solver_v5.R"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
cd "$repo"
mkdir -p "$run/logs"
exec 9> "$run/.launcher.lock"
flock -n 9 || { printf 'Another v5 launcher holds the lock.\n' >&2; exit 1; }
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
write_status RUNNING
mapfile -t configs < <("$rscript" --vanilla -e 'p<-read.csv(commandArgs(TRUE)[1]);stopifnot(nrow(p)==4);cat(p$config_path,sep="\n")' "$run/plan.csv")
[[ ${#configs[@]} == 4 ]]
for i in 0 1 2 3; do
  taskset -c "${cpus[$i]}" timeout --signal=TERM --kill-after=60s 7200s \
    "$rscript" --vanilla "$script" "$repo" worker "${configs[$i]}" \
    > "$run/logs/worker_$i.log" 2>&1 &
  pids+=("$!")
done
failed=0
printf 'slot,pid,exit_code\n' > "$run/launcher_exit_codes.csv"
for i in 0 1 2 3; do
  rc=0
  wait "${pids[$i]}" || rc=$?
  printf '%s,%s,%s\n' "$i" "${pids[$i]}" "$rc" >> "$run/launcher_exit_codes.csv"
  if (( rc )); then failed=1; fi
done
if (( failed )); then write_status FAILED_OR_INTERRUPTED; exit 1; fi
"$rscript" --vanilla "$script" "$repo" audit "$run"
write_status COMPLETE
# The final manifest must be written after the terminal pipeline status.
"$rscript" --vanilla -e '
  root<-commandArgs(TRUE)[1]; paths<-list.files(root,recursive=TRUE,full.names=TRUE)
  paths<-paths[!file.info(paths)$isdir & basename(paths)!="final_artifact_manifest.csv"]
  write.csv(data.frame(path=paths,bytes=file.info(paths)$size,sha256=unname(tools::sha256sum(paths))),file.path(root,"final_artifact_manifest.csv"),row.names=FALSE)
' "$run"
