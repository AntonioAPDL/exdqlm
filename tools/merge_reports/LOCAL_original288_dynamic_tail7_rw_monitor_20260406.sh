#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
evaluate_script="$out_dir/LOCAL_original288_dynamic_tail7_rw_evaluate_20260406.R"
tag="original288_dynamic_tail7_rw_20260406"

interval="180"
max_checks="240"

for arg in "$@"; do
  case "$arg" in
    --interval=*) interval="${arg#*=}" ;;
    --max-checks=*) max_checks="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$evaluate_script" ]]; then
  echo "evaluate script missing" >&2
  exit 2
fi

echo "=== original288 dynamic tail7-rw monitor at $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

check=0
while true; do
  check=$((check + 1))
  echo "--- monitor poll ${check} at $(date '+%Y-%m-%d %H:%M:%S %Z') ---"
  output="$(Rscript "$evaluate_script" 2>&1)"
  echo "$output"
  summary_line="$(echo "$output" | awk '/^SUMMARY /{print; exit}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"
  runner_count="$( { pgrep -af "LOCAL_full288_case_runner_20260327.R.*--tag=${tag}" 2>/dev/null || true; } | wc -l | tr -d ' ' )"
  if [[ -z "$runner_count" ]]; then
    runner_count="0"
  fi
  echo "ACTIVE_RUNNERS $runner_count"
  if [[ "${missing_now:-1}" == "0" && "${runner_count}" == "0" ]]; then
    echo "original288 dynamic tail7-rw monitor detected completion."
    exit 0
  fi
  if [[ "$check" -ge "$max_checks" ]]; then
    echo "max checks reached; exiting monitor."
    exit 0
  fi
  sleep "$interval"
done
