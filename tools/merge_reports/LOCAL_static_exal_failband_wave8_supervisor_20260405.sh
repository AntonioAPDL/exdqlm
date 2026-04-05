#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave8_launch_20260405.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave8_evaluate_20260405.R"

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

echo "=== static failband wave8 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage stability1_warn87: confirming the row-87 slice anchor ---"
bash "$launch_script" --stage=stability1_warn87 --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave8 evaluation after stability1_warn87 ---"
Rscript "$evaluate_script"
echo "--- stage core12_seedinit: closing rows 135, 174, and 269 with exact replays plus vb-init probes ---"
bash "$launch_script" --stage=core12_seedinit --parallel-jobs="$parallel_jobs"
echo "--- final wave8 evaluation ---"
Rscript "$evaluate_script"
