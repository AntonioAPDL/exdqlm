#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
prepare_script="$out_dir/LOCAL_dynamic_row15_wave8_prepare_20260405.R"
evaluate_script="$out_dir/LOCAL_dynamic_row15_wave8_evaluate_20260405.R"
matrix_launcher="$out_dir/LOCAL_dynamic_matrix_launch_20260326.sh"
matrix_csv="$out_dir/LOCAL_dynamic_row15_wave8_matrix_20260405.csv"

mode="launch"
max_parallel="2"
dry_run="0"

for arg in "$@"; do
  case "$arg" in
    --mode=*) mode="${arg#*=}" ;;
    --max-parallel=*) max_parallel="${arg#*=}" ;;
    --dry-run) dry_run="1" ;;
    *) ;;
  esac
done

if [[ ! -f "$prepare_script" || ! -f "$evaluate_script" || ! -f "$matrix_launcher" ]]; then
  echo "required script missing" >&2
  exit 2
fi

if [[ "$mode" == "prepare" ]]; then
  Rscript "$prepare_script"
  exit 0
fi

Rscript "$prepare_script" >/dev/null

if [[ "$mode" == "evaluate" ]]; then
  Rscript "$evaluate_script"
  exit 0
fi

cmd=(bash "$matrix_launcher"
  --matrix-csv="$matrix_csv"
  --variant-prefix=row15wave8
  --max-parallel="$max_parallel"
  --default-watchdog-mode=log_only
)
if [[ "$dry_run" == "1" ]]; then
  cmd+=(--dry-run)
fi

"${cmd[@]}"
Rscript "$evaluate_script"
