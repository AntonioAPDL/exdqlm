#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_forecast_gap_adaptive_mcmc_v1_20260818_214229}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
RUN_ENV="$STATE_ROOT/run_tags.env"
[[ -s "$RUN_ENV" ]] || { echo "Missing run metadata: $RUN_ENV" >&2; exit 3; }
RUN_TAG="${3:-$(awk -F= '$1 == "RUN_TAG" {sub(/^[^=]*=/, ""); print; exit}' "$RUN_ENV")}"
STAMP="$(date +%Y%m%d_%H%M%S)"
SESSION="${SESSION:-ffv2_forecast_gap_adaptive_v1_confirmation_${STAMP}}"
WORKERS="${WORKERS:-20}"
PIPELINE="validation/fitforecast_v2/scripts/resume_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.sh"
STDOUT_LOG="$STATE_ROOT/confirmation_resume_${STAMP}.stdout.log"

[[ "${QDESN_FGAV1_CONFIRMATION_RESUME_APPROVED:-false}" == "true" ]] || {
  echo "Explicit confirmation-resume approval is required." >&2
  exit 3
}
cd "$REPO_ROOT"
[[ "$(git branch --show-current)" == \
  "validation/qdesn-forecast-gap-adaptive-mcmc-v1-1.0.0" ]] || {
  echo "Wrong branch." >&2
  exit 3
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "Launch requires a clean worktree." >&2
  exit 3
}
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || {
  echo "Launch requires synchronized HEAD." >&2
  exit 3
}

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec env QDESN_FGAV1_CONFIRMATION_RESUME_APPROVED=true WORKERS='$WORKERS' bash '$PIPELINE' '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STDOUT_LOG' 2>&1"
sleep 3
tmux has-session -t "$SESSION" 2>/dev/null || {
  echo "Confirmation recovery exited during startup; inspect $STDOUT_LOG" >&2
  exit 3
}
printf '%s\n' "$SESSION" > "$STATE_ROOT/confirmation_resume_tmux_session_${STAMP}.txt"
printf 'SESSION=%s\nRUN_ID=%s\nRUN_TAG=%s\nWORKERS=%s\nRECOVERY_COMMIT=%s\nSTDOUT_LOG=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$(git rev-parse HEAD)" "$STDOUT_LOG" \
  > "$STATE_ROOT/confirmation_resume_launch_${STAMP}.env"
printf 'session=%s\nrun_id=%s\nrun_tag=%s\nworkers=%s\nremaining_jobs=24\nstdout=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$STDOUT_LOG"
