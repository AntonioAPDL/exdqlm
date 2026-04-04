#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave1_launch_20260403.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave1_evaluate_20260403.R"

max_passes="4"
parallel_jobs="6"
sleep_sec="20"

for arg in "$@"; do
  case "$arg" in
    --max-passes=*) max_passes="${arg#*=}" ;;
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --sleep-sec=*) sleep_sec="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$launch_script" || ! -f "$evaluate_script" ]]; then
  echo "required script missing" >&2
  exit 2
fi

prev_missing=""

for ((pass=1; pass<=max_passes; pass++)); do
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "=== static failband wave1 supervisor pass ${pass}/${max_passes} at ${ts} ==="
  launch_output="$(bash "$launch_script" --parallel-jobs="$parallel_jobs")"
  echo "$launch_output"

  summary_line="$(echo "$launch_output" | awk '/^SUMMARY /{print; exit}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"
  done_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^done=/){sub("done=","",$i); print $i; exit}}}')"

  echo "pass=${pass} done=${done_now:-NA} missing=${missing_now:-NA}"

  if [[ -n "$missing_now" && "$missing_now" == "0" ]]; then
    echo "All failband wave1 rows completed."
    exit 0
  fi

  if [[ -n "$missing_now" && -n "$prev_missing" && "$missing_now" == "$prev_missing" ]]; then
    echo "No missing-row reduction on pass ${pass}; stopping supervisor."
    Rscript "$evaluate_script"
    exit 0
  fi

  prev_missing="$missing_now"
  sleep "$sleep_sec"
done

echo "Reached max passes; final evaluation follows."
Rscript "$evaluate_script"
