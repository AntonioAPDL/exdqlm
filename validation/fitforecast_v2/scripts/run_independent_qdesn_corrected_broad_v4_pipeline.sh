#!/usr/bin/env bash
set -euo pipefail

repo_root=${REPO_ROOT:?REPO_ROOT is required}
run_root=${RUN_ROOT:?RUN_ROOT is required}
cpu_list=${CPU_LIST:?CPU_LIST is required}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
stage_runner="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_corrected_broad_v4_stage.sh"
status_path="$run_root/pipeline.status"

write_status() {
  printf 'status=%s\nstage=%s\ntimestamp=%s\n' "$1" "$2" "$(date --iso-8601=seconds)" \
    > "$status_path"
}
trap 'write_status FAILED "${current_stage:-preflight}"' ERR INT TERM

read -r load_one _ < /proc/loadavg
memory_gb=$(awk '/MemAvailable:/ {printf "%.3f", $2 / 1024 / 1024}' /proc/meminfo)
disk_gb=$(df --output=avail -BG "$run_root" | tail -1 | tr -dc '0-9')
awk -v x="$load_one" 'BEGIN {exit !(x <= 56)}'
awk -v x="$memory_gb" 'BEGIN {exit !(x >= 72)}'
(( disk_gb >= 200 ))

current_stage=operator_smoke
write_status RUNNING "$current_stage"
REPO_ROOT="$repo_root" RUN_ROOT="$run_root" STAGE="$current_stage" \
  WORKERS=6 CPU_LIST="$cpu_list" RSCRIPT="$rscript" "$stage_runner"

current_stage=development_comparator
write_status RUNNING "$current_stage"
REPO_ROOT="$repo_root" RUN_ROOT="$run_root" STAGE="$current_stage" \
  WORKERS=15 CPU_LIST="$cpu_list" RSCRIPT="$rscript" "$stage_runner"

current_stage=broad_screen
write_status RUNNING "$current_stage"
REPO_ROOT="$repo_root" RUN_ROOT="$run_root" STAGE="$current_stage" \
  WORKERS=15 CPU_LIST="$cpu_list" RSCRIPT="$rscript" "$stage_runner"

write_status COMPLETE broad_screen
