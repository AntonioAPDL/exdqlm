#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${RUN_ID:-qdesn_forecast_gap_adaptive_mcmc_v1_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${RUN_TAG:-qdesn-forecast-gap-adaptive-v1-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
SESSION="${SESSION:-ffv2_forecast_gap_adaptive_v1_$(date +%Y%m%d_%H%M%S)}"
WORKERS="${WORKERS:-20}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
STDOUT_LOG="$STATE_ROOT/pipeline.stdout.log"
mkdir -p "$STATE_ROOT"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && WORKERS='$WORKERS' validation/fitforecast_v2/scripts/run_qdesn_forecast_gap_adaptive_mcmc_v1_pipeline.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STDOUT_LOG' 2>&1"

printf 'session=%s\nrun_id=%s\nrun_tag=%s\nworkers=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$STATE_ROOT" "$STDOUT_LOG"
