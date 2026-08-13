#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${RUN_ID:?RUN_ID from the completed sealed stage is required}"
RUN_TAG="${RUN_TAG:?RUN_TAG from the completed sealed stage is required}"
SESSION="${SESSION:-ffv2_qdesn_tbcv1_confirmation_$(date +%Y%m%d_%H%M%S)}"
LOG="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID/confirmation.stdout.log"
tmux new-session -d -s "$SESSION" "cd '$REPO_ROOT' && QDESN_TBCV1_CONFIRMATION_APPROVED=true WORKERS='${WORKERS:-6}' validation/fitforecast_v2/scripts/run_qdesn_tierb_cellwise_mcmc_v1_confirmation.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$LOG' 2>&1"
printf 'session=%s\nrun_id=%s\nrun_tag=%s\nstdout=%s\n' "$SESSION" "$RUN_ID" "$RUN_TAG" "$LOG"
