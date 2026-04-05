#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_static_exal_failband_wave11_launch_20260405.sh"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave11_evaluate_20260405.R"

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

echo "=== static failband wave11 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- stage anchor4_short_hist: exact short replays of the surviving lower-mid row-87 historical non-FAIL anchors ---"
bash "$launch_script" --stage=anchor4_short_hist --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave11 evaluation after anchor4_short_hist ---"
Rscript "$evaluate_script"
echo "--- stage confirm4_medium: moderate-length confirmations on the same lower-mid corridor ---"
bash "$launch_script" --stage=confirm4_medium --parallel-jobs="$parallel_jobs"
echo "--- intermediate wave11 evaluation after confirm4_medium ---"
Rscript "$evaluate_script"
echo "--- stage none3_lowermid: no-warm-start probes on the best lower-mid anchors ---"
bash "$launch_script" --stage=none3_lowermid --parallel-jobs="$parallel_jobs"
echo "--- final wave11 evaluation ---"
Rscript "$evaluate_script"
