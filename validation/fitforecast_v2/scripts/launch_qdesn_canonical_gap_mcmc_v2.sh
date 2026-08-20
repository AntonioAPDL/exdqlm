#!/usr/bin/env bash
set -euo pipefail
REPO="${1:-$(git rev-parse --show-toplevel)}"; stamp="$(date +%Y%m%d_%H%M%S)"; run_id="qdesn_canonical_gap_mcmc_v2_$stamp"; run_tag="qdesn-canonical-gap-v2-$stamp__git-$(git -C "$REPO" rev-parse --short HEAD)"; session="ffv2_qdesn_canonical_gap_v2_$stamp"
tmux new-session -d -s "$session" "cd '$REPO' && WORKERS='${WORKERS:-20}' MIN_IDLE_CPUS='${MIN_IDLE_CPUS:-8}' bash validation/fitforecast_v2/scripts/run_qdesn_canonical_gap_mcmc_v2_pipeline.sh '$REPO' '$run_id' '$run_tag' > 'reports/shared_fitforecast_v2_orchestration/${run_id}.stdout.log' 2>&1"
printf 'SESSION=%s\nRUN_ID=%s\nRUN_TAG=%s\n' "$session" "$run_id" "$run_tag"
