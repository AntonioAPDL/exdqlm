#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${RUN_ID:-qdesn_lower_tail_cellwise_mcmc_v1_tiera_20260811_215538}"
RUN_TAG="${RUN_TAG:-qdesn-lower-tail-cellwise-mcmc-v1-tiera-20260811_215538__git-c050ccf}"
SESSION="${SESSION:-ffv2_qdesn_ltcv1_confirmation_$(date +%Y%m%d_%H%M%S)}"
LOG="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID/confirmation.stdout.log"
tmux new-session -d -s "$SESSION" "cd '$REPO_ROOT' && QDESN_LTCV1_CONFIRMATION_APPROVED=true WORKERS='${WORKERS:-6}' validation/fitforecast_v2/scripts/run_qdesn_lower_tail_cellwise_mcmc_v1_confirmation.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$LOG' 2>&1"
printf 'session=%s\nrun_id=%s\nrun_tag=%s\nstdout=%s\n' "$SESSION" "$RUN_ID" "$RUN_TAG" "$LOG"
