#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
launch_script="$out_dir/LOCAL_dynamic_row15_wave8_launch_20260405.sh"
evaluate_script="$out_dir/LOCAL_dynamic_row15_wave8_evaluate_20260405.R"

max_parallel="2"
interval="120"
max_checks="240"

for arg in "$@"; do
  case "$arg" in
    --max-parallel=*) max_parallel="${arg#*=}" ;;
    --interval=*) interval="${arg#*=}" ;;
    --max-checks=*) max_checks="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$launch_script" || ! -f "$evaluate_script" ]]; then
  echo "required script missing" >&2
  exit 2
fi

echo "=== dynamic row15 wave8 supervisor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "--- launching dynamic row15 replay sidecar ---"
bash "$launch_script" --max-parallel="$max_parallel"

check=0
while true; do
  check=$((check + 1))
  echo "--- dynamic row15 wave8 supervisor poll ${check} at $(date '+%Y-%m-%d %H:%M:%S %Z') ---"
  output="$(Rscript "$evaluate_script" 2>&1)"
  echo "$output"
  summary_line="$(echo "$output" | awk '/^SUMMARY /{print; exit}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"
  runner_count="$( { pgrep -af 'LOCAL_dynamic_exdqlm_slice_case_runner_20260321.R.*(row15_slice_exact_20260405|row15_slice_long_20260405)' 2>/dev/null || true; } | wc -l | tr -d ' ' )"
  if [[ -z "$runner_count" ]]; then
    runner_count="0"
  fi
  if [[ "${missing_now:-1}" == "0" && "${runner_count}" == "0" ]]; then
    echo "Dynamic row15 wave8 sidecar completed."
    exit 0
  fi
  if [[ "$check" -ge "$max_checks" ]]; then
    echo "Max checks reached; exiting dynamic supervisor."
    exit 0
  fi
  sleep "$interval"
done
