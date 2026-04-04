#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave6_launch_20260404.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave6_evaluate_20260404.R"

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

echo "=== static failband wave6 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage confirm9_v2: confirming evidence-weighted local repair baseline ---"
bash "$launch_script" --stage=confirm9_v2 --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave6 evaluation after confirm9_v2 ---"
Rscript "$evaluate_script"
echo "--- stage repair13: probing core closure rows only ---"
bash "$launch_script" --stage=repair13 --parallel-jobs="$parallel_jobs"
echo "--- final wave6 evaluation ---"
Rscript "$evaluate_script"
