#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave10_launch_20260405.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave10_evaluate_20260405.R"

parallel_jobs="4"

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

echo "=== static failband wave10 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage anchor4_confirm: exact and slightly longer confirmations in the surviving row-87 anchor band ---"
bash "$launch_script" --stage=anchor4_confirm --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave10 evaluation after anchor4_confirm ---"
Rscript "$evaluate_script"
echo "--- stage micro4_expand: narrow row-87 micro-band expansion around the two only surviving anchor families ---"
bash "$launch_script" --stage=micro4_expand --parallel-jobs="$parallel_jobs"
echo "--- final wave10 evaluation ---"
Rscript "$evaluate_script"
