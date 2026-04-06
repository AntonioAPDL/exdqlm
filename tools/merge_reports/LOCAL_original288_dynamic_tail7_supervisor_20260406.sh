#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"

launch_script="$out_dir/LOCAL_original288_dynamic_tail7_launch_20260406.sh"
evaluate_script="$out_dir/LOCAL_original288_dynamic_tail7_evaluate_20260406.R"
select_script="$out_dir/LOCAL_original288_dynamic_tail7_select_20260406.R"
tag="original288_dynamic_tail7_20260406"

max_band="5"
max_long="3"

for arg in "$@"; do
  case "$arg" in
    --max-band=*) max_band="${arg#*=}" ;;
    --max-long=*) max_long="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$launch_script" || ! -f "$evaluate_script" || ! -f "$select_script" ]]; then
  echo "required script missing" >&2
  exit 2
fi

echo "=== original288 dynamic tail7 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

if ! bash "$launch_script" --max-band="$max_band" --max-long="$max_long"; then
  rc=$?
  echo "--- launch returned rc=$rc; latest evaluator snapshot follows ---"
  Rscript "$evaluate_script" || true
  exit "$rc"
fi

echo "--- final evaluator snapshot ---"
Rscript "$evaluate_script"
echo "--- selection preview ---"
Rscript "$select_script"

runner_count="$( { pgrep -af "LOCAL_full288_case_runner_20260327.R.*--tag=${tag}" 2>/dev/null || true; } | wc -l | tr -d ' ' )"
if [[ "${runner_count:-0}" != "0" ]]; then
  echo "tail7 supervisor finished launch, but runner_count=$runner_count remains active" >&2
  exit 1
fi

echo "original288 dynamic tail7 supervisor completed cleanly."
