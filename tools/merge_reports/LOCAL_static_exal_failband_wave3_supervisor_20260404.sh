#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave3_launch_20260404.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave3_evaluate_20260404.R"
select_script="$out_dir/LOCAL_static_exal_failband_wave3_select_20260404.R"

parallel_jobs="6"
sleep_sec="20"
final_top_n="2"

for arg in "$@"; do
  case "$arg" in
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --sleep-sec=*) sleep_sec="${arg#*=}" ;;
    --final-top-n=*) final_top_n="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$launch_script" || ! -f "$evaluate_script" || ! -f "$select_script" ]]; then
  echo "required script missing" >&2
  exit 2
fi

echo "=== static failband wave3 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

echo "--- stage residual18: launching active bridge set ---"
bash "$launch_script" --stage=residual18 --parallel-jobs="$parallel_jobs"
sleep "$sleep_sec"

final_candidates="$(Rscript "$select_script" --stage=residual18 --top-n="$final_top_n" | paste -sd, -)"
if [[ -z "$final_candidates" ]]; then
  echo "No confirm30 finalists selected from residual18." >&2
  exit 1
fi
echo "stage_confirm30_candidates=${final_candidates}"

echo "--- stage confirm30: launching finalists ---"
bash "$launch_script" --stage=confirm30 --candidate="$final_candidates" --parallel-jobs="$parallel_jobs"

echo "--- final wave3 evaluation ---"
Rscript "$evaluate_script"
