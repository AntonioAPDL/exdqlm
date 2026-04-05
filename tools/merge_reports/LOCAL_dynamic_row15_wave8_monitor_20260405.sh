#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
evaluate_script="$out_dir/LOCAL_dynamic_row15_wave8_evaluate_20260405.R"
session="dynamic-row15-wave8-20260405"
interval="120"
max_checks="240"

for arg in "$@"; do
  case "$arg" in
    --session=*) session="${arg#*=}" ;;
    --interval=*) interval="${arg#*=}" ;;
    --max-checks=*) max_checks="${arg#*=}" ;;
    *) ;;
  esac
done

prev_done="NA"
stagnant=0
check=0

while true; do
  check=$((check + 1))
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "=== dynamic row15 wave8 monitor ${ts} (check ${check}) ==="

  session_state="NOT_RUNNING"
  if tmux has-session -t "$session" 2>/dev/null; then
    session_state="RUNNING"
  fi
  runner_count="$( { pgrep -af 'LOCAL_dynamic_exdqlm_slice_case_runner_20260321.R.*(row15_slice_exact_20260405|row15_slice_long_20260405)' 2>/dev/null || true; } | wc -l | tr -d ' ' )"
  if [[ -z "$runner_count" ]]; then
    runner_count="0"
  fi

  echo "tmux_session=${session_state} runner_processes=${runner_count}"

  output="$(Rscript "$evaluate_script" 2>&1)"
  echo "$output"
  summary_line="$(echo "$output" | awk '/^SUMMARY /{print; exit}')"
  done_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^done=/){sub("done=","",$i); print $i; exit}}}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"

  if [[ -n "$done_now" && "$done_now" == "$prev_done" ]]; then
    stagnant=$((stagnant + 1))
  else
    stagnant=0
  fi
  prev_done="$done_now"

  if [[ "${missing_now:-1}" == "0" && "$session_state" != "RUNNING" && "${runner_count}" == "0" ]]; then
    echo "Dynamic row15 wave8 rows completed. Exiting monitor."
    exit 0
  fi

  if [[ "$stagnant" -ge 3 && "${runner_count}" == "0" && "$session_state" != "RUNNING" ]]; then
    echo "Warning: no progress detected for 3 consecutive checks and no dynamic row15 processes are active."
  fi

  if [[ "$check" -ge "$max_checks" ]]; then
    echo "Max checks reached; exiting monitor."
    exit 0
  fi
  echo ""
  sleep "$interval"
done
