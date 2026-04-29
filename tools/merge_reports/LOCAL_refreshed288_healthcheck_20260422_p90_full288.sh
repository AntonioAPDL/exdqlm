#!/usr/bin/env bash
set -euo pipefail

run_tag="${REFRESHED288_RUN_TAG:-20260422_p90_full288_baseline_v1}"
manifest_kind="full"
session=""

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
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

run_tag="${run_tag//[^A-Za-z0-9_-]/_}"
export REFRESHED288_RUN_TAG="$run_tag"
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

if [[ ! -f "$manifest_path" ]]; then
  echo "manifest not found: $manifest_path" >&2
  exit 1
fi

tmux_state="NOT_RUNNING"
if tmux has-session -t "$session" 2>/dev/null; then
  tmux_state="RUNNING"
fi

runner_count="$( { pgrep -af 'LOCAL_refreshed288_run_row_20260422_p90_full288.R' 2>/dev/null || true; } | wc -l | tr -d ' ' )"
echo "tmux_session=$tmux_state runner_processes=$runner_count session=$session run_tag=$run_tag manifest_kind=$manifest_kind"

(cd "$repo_root" && Rscript "$evaluate_script" --manifest="$manifest_path" --status_out="$status_path" --phase_out="$phase_path" --method_out="$method_path")
(cd "$repo_root" && Rscript "$report_script" --manifest="$manifest_path" --status="$status_path" --phase="$phase_path" --method="$method_path")

echo "status_path=$status_path"
echo "phase_path=$phase_path"
echo "method_path=$method_path"
