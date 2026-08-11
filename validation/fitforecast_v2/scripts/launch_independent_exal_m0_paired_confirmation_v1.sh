#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
MODE="${2:?MODE must be smoke or confirmation}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${3:-independent_exal_m0_paired_confirmation_v1_${MODE}_${STAMP}}"
RUN_TAG="${4:-ind-exal-m0-paired-confirm-v1-${MODE}-${STAMP}__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
SESSION="${SESSION:-ffv2_ind_exal_m0_paired_confirm_v1_${MODE}_${STAMP}}"
PIPELINE="validation/fitforecast_v2/scripts/run_independent_exal_m0_paired_confirmation_v1.sh"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"

case "$MODE" in
  smoke)
    WORKERS="${WORKERS:-2}"
    APPROVAL=""
    ;;
  confirmation)
    WORKERS="${WORKERS:-6}"
    [[ "${PAIRED_CONFIRMATION_APPROVED:-false}" == "true" ]] || {
      echo "PAIRED_CONFIRMATION_APPROVED=true is required." >&2
      exit 3
    }
    APPROVAL="PAIRED_CONFIRMATION_APPROVED=true"
    ;;
  *)
    echo "MODE must be smoke or confirmation." >&2
    exit 3
    ;;
esac

mkdir -p "$STATE_ROOT"
cd "$REPO_ROOT"
tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec env $APPROVAL WORKERS='$WORKERS' bash '$PIPELINE' '$REPO_ROOT' '$MODE' '$RUN_ID' '$RUN_TAG' > '$STATE_ROOT/pipeline.stdout.log' 2>&1"
sleep 2
tmux has-session -t "$SESSION" 2>/dev/null || {
  echo "Launch exited during startup; inspect $STATE_ROOT/pipeline.stdout.log" >&2
  exit 3
}
printf 'SESSION=%s\nMODE=%s\nRUN_ID=%s\nRUN_TAG=%s\nWORKERS=%s\nCOMMIT=%s\n' \
  "$SESSION" "$MODE" "$RUN_ID" "$RUN_TAG" "$WORKERS" \
  "$(git rev-parse HEAD)" > "$STATE_ROOT/launch.env"
printf 'session=%s\nmode=%s\nrun_id=%s\nrun_tag=%s\njobs=%s\nworkers=%s\n' \
  "$SESSION" "$MODE" "$RUN_ID" "$RUN_TAG" \
  "$([[ "$MODE" == "smoke" ]] && printf 2 || printf 6)" "$WORKERS"
