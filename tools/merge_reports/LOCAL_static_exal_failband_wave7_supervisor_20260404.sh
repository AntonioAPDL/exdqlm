#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave7_launch_20260404.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave7_evaluate_20260404.R"

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

echo "=== static failband wave7 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage stability3_v3: confirming promoted non-FAIL local map rows ---"
bash "$launch_script" --stage=stability3_v3 --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave7 evaluation after stability3_v3 ---"
Rscript "$evaluate_script"
echo "--- stage core17_triplet: closing the remaining static fail triplet ---"
bash "$launch_script" --stage=core17_triplet --parallel-jobs="$parallel_jobs"
echo "--- final wave7 evaluation ---"
Rscript "$evaluate_script"
