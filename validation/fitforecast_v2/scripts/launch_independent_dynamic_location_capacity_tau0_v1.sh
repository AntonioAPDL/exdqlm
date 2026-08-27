#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(git rev-parse --show-toplevel)}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="independent_dynamic_location_capacity_tau0_v1_${STAMP}"
RUN_TAG="independent-dynamic-location-capacity-tau0-v1-${STAMP}__git-$(git -C "$REPO" rev-parse --short HEAD)"
SESSION="ffv2_independent_dynamic_location_capacity_tau0_v1_${STAMP}"
mkdir -p "$REPO/reports/shared_fitforecast_v2_orchestration"
tmux new-session -d -s "$SESSION" \
  "cd '$REPO' && WORKERS='${WORKERS:-20}' bash validation/fitforecast_v2/scripts/run_independent_dynamic_location_capacity_tau0_v1_pipeline.sh '$REPO' '$RUN_ID' '$RUN_TAG' > 'reports/shared_fitforecast_v2_orchestration/${RUN_ID}.stdout.log' 2>&1"
printf 'SESSION=%s\nRUN_ID=%s\nRUN_TAG=%s\n' "$SESSION" "$RUN_ID" "$RUN_TAG"
