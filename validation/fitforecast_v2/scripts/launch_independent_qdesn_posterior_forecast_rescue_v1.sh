#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
stamp=$(date +%Y%m%d_%H%M%S)
short=$(git -C "$repo_root" rev-parse --short=9 HEAD)
run_tag="independent_qdesn_posterior_forecast_rescue_v1_${stamp}__git-${short}"
run_root="$repo_root/validation/fitforecast_v2/local_trackers/$run_tag"
session="ind_qdesn_postfc_rescue_v1_15core"
pipeline="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_posterior_forecast_rescue_v1_pipeline.sh"

if tmux has-session -t "$session" 2>/dev/null; then
  printf 'tmux session already exists: %s\n' "$session" >&2
  exit 1
fi
mkdir -p "$run_root/orchestration"
tmux new-session -d -s "$session" \
  "cd '$repo_root' && bash '$pipeline' --run-root '$run_root' --workers 15 > '$run_root/orchestration/pipeline.log' 2>&1"
printf 'session=%s\nrun_root=%s\nlog=%s\n' \
  "$session" "$run_root" "$run_root/orchestration/pipeline.log"
