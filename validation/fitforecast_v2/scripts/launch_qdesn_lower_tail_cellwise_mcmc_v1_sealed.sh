#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${RUN_ID:-qdesn_lower_tail_cellwise_mcmc_v1_tiera_20260811_215538}"
RUN_TAG="${RUN_TAG:-qdesn-lower-tail-cellwise-mcmc-v1-tiera-20260811_215538__git-c050ccf}"
SESSION="${SESSION:-ffv2_qdesn_ltcv1_sealed_$(date +%Y%m%d_%H%M%S)}"
WORKERS="${WORKERS:-20}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
STDOUT_LOG="$STATE_ROOT/sealed.stdout.log"
mkdir -p "$STATE_ROOT"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && WORKERS='$WORKERS' validation/fitforecast_v2/scripts/run_qdesn_lower_tail_cellwise_mcmc_v1_sealed.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STDOUT_LOG' 2>&1"

printf 'session=%s\nrun_id=%s\nrun_tag=%s\nworkers=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$STATE_ROOT" "$STDOUT_LOG"
