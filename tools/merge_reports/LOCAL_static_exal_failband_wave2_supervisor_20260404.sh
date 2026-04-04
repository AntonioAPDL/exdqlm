#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave2_launch_20260404.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave2_evaluate_20260404.R"
select_script="$out_dir/LOCAL_static_exal_failband_wave2_select_20260404.R"

parallel_jobs="6"
sleep_sec="20"
sentinel_top_n="5"
final_top_n="2"

for arg in "$@"; do
  case "$arg" in
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --sleep-sec=*) sleep_sec="${arg#*=}" ;;
    --sentinel-top-n=*) sentinel_top_n="${arg#*=}" ;;
    --final-top-n=*) final_top_n="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$launch_script" || ! -f "$evaluate_script" || ! -f "$select_script" ]]; then
  echo "required script missing" >&2
  exit 2
fi

echo "=== static failband wave2 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

echo "--- stage sentinel12: launching all candidates ---"
bash "$launch_script" --stage=sentinel12 --parallel-jobs="$parallel_jobs"
sleep "$sleep_sec"

sentinel_candidates="$(Rscript "$select_script" --stage=sentinel12 --top-n="$sentinel_top_n" | paste -sd, -)"
if [[ -z "$sentinel_candidates" ]]; then
  echo "No stage-2 candidates selected from sentinel12." >&2
  exit 1
fi
echo "stage_expand20_candidates=${sentinel_candidates}"

echo "--- stage expand20: launching top candidates ---"
bash "$launch_script" --stage=expand20 --candidate="$sentinel_candidates" --parallel-jobs="$parallel_jobs"
sleep "$sleep_sec"

final_candidates="$(Rscript "$select_script" --stage=expand20 --candidate="$sentinel_candidates" --top-n="$final_top_n" | paste -sd, -)"
if [[ -z "$final_candidates" ]]; then
  echo "No full30 candidates selected from expand20." >&2
  exit 1
fi
echo "stage_full30_candidates=${final_candidates}"

echo "--- stage full30: launching finalists ---"
bash "$launch_script" --stage=full30 --candidate="$final_candidates" --parallel-jobs="$parallel_jobs"

echo "--- final wave2 evaluation ---"
Rscript "$evaluate_script"
