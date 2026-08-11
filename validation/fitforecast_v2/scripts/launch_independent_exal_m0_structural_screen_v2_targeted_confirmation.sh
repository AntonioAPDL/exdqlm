#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${2:-independent_exal_m0_structural_v2_targeted_confirmation_${STAMP}}"
RUN_TAG="${3:-ind-exal-m0-struct-v2-target-confirm-${STAMP}__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
SESSION="${SESSION:-ffv2_ind_exal_m0_struct_v2_confirm_${STAMP}}"
WORKERS="${WORKERS:-6}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
PIPELINE="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_targeted_confirmation.sh"
mkdir -p "$STATE_ROOT"
cd "$REPO_ROOT"
tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec env TARGETED_CONFIRMATION_APPROVED=true WORKERS='$WORKERS' bash '$PIPELINE' '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STATE_ROOT/pipeline.stdout.log' 2>&1"
sleep 2
tmux has-session -t "$SESSION" 2>/dev/null || {
  echo "Launch exited during startup; inspect $STATE_ROOT/pipeline.stdout.log" >&2; exit 3;
}
printf 'SESSION=%s\nRUN_ID=%s\nRUN_TAG=%s\nWORKERS=%s\nCOMMIT=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$(git rev-parse HEAD)" > "$STATE_ROOT/launch.env"
printf 'session=%s\nrun_id=%s\nrun_tag=%s\njobs=6\nworkers=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS"
