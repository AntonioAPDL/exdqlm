#!/usr/bin/env bash
set -euo pipefail

run_tag="${REFRESHED288_RUN_TAG:-20260422_p90_full288_baseline_v1}"
manifest_kind="full"
session=""
execute="false"
refresh_status="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-tag=*)
      run_tag="${1#*=}"
      ;;
    --manifest-kind=*)
      manifest_kind="${1#*=}"
      ;;
    --session=*)
      session="${1#*=}"
      ;;
    --execute=*)
      execute="${1#*=}"
      ;;
    --refresh-status=*)
      refresh_status="${1#*=}"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

run_tag="${run_tag//[^A-Za-z0-9_-]/_}"
if [[ -z "$session" ]]; then
  session="refreshed288_${run_tag}"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
evaluate_script="$script_dir/LOCAL_refreshed288_evaluate_20260422_p90_full288.R"
report_script="$script_dir/LOCAL_refreshed288_report_20260422_p90_full288.R"
manifest_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_${manifest_kind}_manifest_${run_tag}.csv"
status_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_${manifest_kind}_manifest_status_${run_tag}.csv"
phase_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_${manifest_kind}_phase_summary_${run_tag}.csv"
method_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_${manifest_kind}_method_summary_${run_tag}.csv"

row_pattern="LOCAL_refreshed288_run_row_20260422_p90_full288.R --manifest=${manifest_path}"
launch_pattern="LOCAL_refreshed288_launch_20260422_p90_full288.sh"

session_state="missing"
if tmux has-session -t "$session" 2>/dev/null; then
  session_state="alive"
fi

mapfile -t row_pids < <(pgrep -f "$row_pattern" || true)
mapfile -t launch_pids < <(pgrep -f "$launch_pattern.*--run-tag=${run_tag}" || true)

echo "session=$session"
echo "session_state=$session_state"
echo "row_worker_count=${#row_pids[@]}"
echo "launcher_count=${#launch_pids[@]}"
echo "manifest_path=$manifest_path"

if [[ "${execute}" != "true" ]]; then
  echo "dry_run_only=true"
  exit 0
fi

if [[ "$session_state" == "alive" ]]; then
  tmux kill-session -t "$session" || true
fi

if [[ "${#launch_pids[@]}" -gt 0 ]]; then
  kill "${launch_pids[@]}" 2>/dev/null || true
fi
if [[ "${#row_pids[@]}" -gt 0 ]]; then
  kill "${row_pids[@]}" 2>/dev/null || true
fi

sleep 2

mapfile -t remaining_row_pids < <(pgrep -f "$row_pattern" || true)
if [[ "${#remaining_row_pids[@]}" -gt 0 ]]; then
  kill -9 "${remaining_row_pids[@]}" 2>/dev/null || true
fi

if [[ "${refresh_status}" == "true" && -f "$manifest_path" ]]; then
  (cd "$repo_root" && Rscript "$evaluate_script" --manifest="$manifest_path" --status_out="$status_path" --phase_out="$phase_path" --method_out="$method_path")
  (cd "$repo_root" && Rscript "$report_script" --manifest="$manifest_path" --status="$status_path" --phase="$phase_path" --method="$method_path")
fi

echo "stopped=true"
