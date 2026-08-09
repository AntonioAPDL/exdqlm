#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${2:-independent_exal_m0_relaunch_v1_${STAMP}}"
SESSION="${3:-ffv2_independent_exal_m0_v1_${STAMP}}"
RUN_TAG="${4:-ind-exal-m0-v1-${STAMP}__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
cd "$REPO_ROOT"

EXPECTED_BRANCH="validation/independent-exal-m0-relaunch-v1-1.0.0"
if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Launch refused outside $EXPECTED_BRANCH" >&2
  exit 2
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Launch refused from a dirty worktree." >&2
  git status --short >&2
  exit 2
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Launch refused without an upstream." >&2
  exit 2
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch refused: upstream mismatch (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 2
fi
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session already exists: $SESSION" >&2
  exit 2
fi

STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STDOUT_LOG="$STATE_ROOT/pipeline.stdout.log"
PIPELINE="validation/fitforecast_v2/scripts/run_independent_exal_m0_relaunch_v1_pipeline.sh"
printf '%s\n' "$SESSION" > "$STATE_ROOT/tmux_session.txt"
printf '%s\n' "$RUN_ID" > "$STATE_ROOT/run_id.txt"
printf '%s\n' "$RUN_TAG" > "$STATE_ROOT/run_tag.txt"
printf '%s\n' "$(git rev-parse HEAD)" > "$STATE_ROOT/launch_commit.txt"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec bash '$PIPELINE' '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STDOUT_LOG' 2>&1"
sleep 2
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Pipeline exited during startup; inspect $STDOUT_LOG" >&2
  exit 3
fi
printf 'session=%s\nrun_id=%s\nrun_tag=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$STATE_ROOT" "$STDOUT_LOG"
