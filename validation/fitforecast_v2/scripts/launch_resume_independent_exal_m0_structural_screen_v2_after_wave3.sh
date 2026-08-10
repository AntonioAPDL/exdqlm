#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-independent_exal_m0_structural_screen_v2_capacity_repair_20260810_040208}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
RUN_TAG="${3:-$(cat "$STATE_ROOT/run_tag.txt")}"
RECOVERY_NAME="${4:-adaptive_recovery_selector_v3}"
STAMP="$(date +%Y%m%d_%H%M%S)"
SESSION="${SESSION:-ffv2_ind_exal_m0_struct_v2_sealed_${STAMP}}"
WORKERS="${WORKERS:-16}"
PIPELINE="validation/fitforecast_v2/scripts/resume_independent_exal_m0_structural_screen_v2_after_wave3.sh"
STDOUT_LOG="$STATE_ROOT/sealed_recovery_pipeline_${STAMP}.stdout.log"

cd "$REPO_ROOT"
[[ "$(git branch --show-current)" == "validation/independent-exal-m0-structural-screen-v2-1.0.0" ]] || exit 2
[[ -z "$(git status --porcelain)" ]] || { echo "Launch requires a clean worktree" >&2; exit 2; }
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || { echo "Launch requires synchronized HEAD" >&2; exit 2; }
tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec env WORKERS='$WORKERS' bash '$PIPELINE' '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' '$RECOVERY_NAME' > '$STDOUT_LOG' 2>&1"
sleep 2
tmux has-session -t "$SESSION" 2>/dev/null || { echo "Recovery exited during startup; inspect $STDOUT_LOG" >&2; exit 3; }
printf '%s\n' "$SESSION" > "$STATE_ROOT/sealed_recovery_tmux_session_${STAMP}.txt"
printf 'SESSION=%s\nRUN_ID=%s\nRUN_TAG=%s\nRECOVERY_NAME=%s\nWORKERS=%s\nCOMMIT=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$RECOVERY_NAME" "$WORKERS" "$(git rev-parse HEAD)" \
  > "$STATE_ROOT/sealed_recovery_launch_${STAMP}.env"
printf 'session=%s\nrun_tag=%s\nremaining_jobs=76\nconfirmation_jobs_blocked=21\nstdout=%s\n' \
  "$SESSION" "$RUN_TAG" "$STDOUT_LOG"
