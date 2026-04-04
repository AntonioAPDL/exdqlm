#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave4_evaluate_20260404.R"
session="static-exal-failband-wave4-20260404"
interval="120"
max_checks="360"

for arg in "$@"; do
  case "$arg" in
    --session=*) session="${arg#*=}" ;;
    --interval=*) interval="${arg#*=}" ;;
    --max-checks=*) max_checks="${arg#*=}" ;;
    *) ;;
  esac
done

latest_row_log_heartbeat() {
  local latest_line
  latest_line="$(find "$out_dir" -maxdepth 1 -type f -name 'LOCAL_static_exal_failband_wave4_*_row*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 || true)"
  if [[ -z "$latest_line" ]]; then
    echo "NA|NA"
    return 0
  fi
  local latest_epoch latest_path now_epoch age_sec
  latest_epoch="${latest_line%% *}"
  latest_path="${latest_line#* }"
  now_epoch="$(date +%s)"
  age_sec=$(( now_epoch - ${latest_epoch%.*} ))
  echo "${age_sec}|${latest_path}"
}

prev_done="NA"
stagnant=0
check=0

while true; do
  check=$((check + 1))
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "=== static failband wave4 monitor ${ts} (check ${check}) ==="

  session_state="NOT_RUNNING"
  if tmux has-session -t "$session" 2>/dev/null; then
    session_state="RUNNING"
  fi
  runner_count="$( { pgrep -af 'LOCAL_static_exal_case_runner_20260323.R.*failband4_' 2>/dev/null || true; } | wc -l | tr -d ' ' )"
  if [[ -z "$runner_count" ]]; then
    runner_count="0"
  fi
  heartbeat="$(latest_row_log_heartbeat)"
  latest_row_log_age_sec="${heartbeat%%|*}"
  latest_row_log_path="${heartbeat#*|}"

  echo "tmux_session=${session_state} runner_processes=${runner_count} latest_row_log_age_sec=${latest_row_log_age_sec} latest_row_log_path=${latest_row_log_path}"

  if output="$(Rscript "$evaluate_script" 2>&1)"; then
    echo "$output" | sed -n '/^SUMMARY /,/^UNRESOLVED_DETAIL$/p' | sed '$d'
  else
    echo "$output"
    echo "Notice: evaluator is not ready yet; continuing monitor."
    echo ""
    if [[ "$check" -ge "$max_checks" ]]; then
      echo "Max checks reached; exiting monitor."
      exit 0
    fi
    sleep "$interval"
    continue
  fi

  summary_line="$(echo "$output" | awk '/^SUMMARY /{print; exit}')"
  done_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^done=/){sub("done=","",$i); print $i; exit}}}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"

  if [[ -n "$done_now" && "$done_now" == "$prev_done" ]]; then
    stagnant=$((stagnant + 1))
  else
    stagnant=0
  fi
  prev_done="$done_now"

  if [[ -n "$missing_now" && "$missing_now" == "0" && "$session_state" != "RUNNING" && "${runner_count:-0}" == "0" ]]; then
    echo "All failband wave4 rows completed. Exiting monitor."
    exit 0
  fi

  if [[ "$session_state" != "RUNNING" && "${runner_count:-0}" == "0" ]]; then
    echo "Warning: no active tmux session or runner processes detected while rows remain."
  fi

  if [[ "$stagnant" -ge 3 ]]; then
    if [[ "${runner_count:-0}" == "0" ]]; then
      echo "Warning: no progress detected for 3 consecutive checks and no runner processes are active."
    elif [[ "$latest_row_log_age_sec" == "NA" ]]; then
      echo "Warning: no progress detected for 3 consecutive checks and no row-log heartbeat is available."
    elif [[ "$latest_row_log_age_sec" -gt $(( interval * 2 )) ]]; then
      echo "Warning: no progress detected for 3 consecutive checks and row logs have been quiet for ${latest_row_log_age_sec}s."
    else
      echo "Notice: summary counts are unchanged, but recent row-log heartbeats suggest jobs are still alive."
    fi
  fi

  echo ""
  if [[ "$check" -ge "$max_checks" ]]; then
    echo "Max checks reached; exiting monitor."
    exit 0
  fi
  sleep "$interval"
done
