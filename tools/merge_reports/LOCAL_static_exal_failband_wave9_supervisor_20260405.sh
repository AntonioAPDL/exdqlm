#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave9_launch_20260405.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave9_evaluate_20260405.R"

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

echo "=== static failband wave9 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage stability7_exact: exact replays for unstable row 87 and promoted row 269 anchors ---"
bash "$launch_script" --stage=stability7_exact --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave9 evaluation after stability7_exact ---"
Rscript "$evaluate_script"
echo "--- stage closure12_exact_none: closing rows 135 and 174 via exact historical replays plus init_mode=none probes ---"
bash "$launch_script" --stage=closure12_exact_none --parallel-jobs="$parallel_jobs"
echo "--- final wave9 evaluation ---"
Rscript "$evaluate_script"
