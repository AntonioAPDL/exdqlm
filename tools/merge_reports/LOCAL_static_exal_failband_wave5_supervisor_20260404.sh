#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave5_launch_20260404.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave5_evaluate_20260404.R"

parallel_jobs="6"

for arg in "$@"; do
  case "$arg" in
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$launch_script" || ! -f "$evaluate_script" ]]; then
  echo "required script missing" >&2
  exit 2
fi

echo "=== static failband wave5 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage confirm9: confirming selected local repair map ---"
bash "$launch_script" --stage=confirm9 --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave5 evaluation after confirm9 ---"
Rscript "$evaluate_script"
echo "--- stage probe2: probing stubborn WARN-only rows ---"
bash "$launch_script" --stage=probe2 --parallel-jobs="2"
echo "--- final wave5 evaluation ---"
Rscript "$evaluate_script"
