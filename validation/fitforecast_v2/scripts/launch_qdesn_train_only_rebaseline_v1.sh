#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
WORKERS="${2:-20}"
RUN_ID="${3:-qdesn_trainonly_rebaseline_v1_$(date +%Y%m%d_%H%M%S)}"
SESSION="${4:-ffv2_qdesn_trainonly_rebaseline_v1_$(date +%Y%m%d_%H%M%S)}"

if [[ "${FULL_TRAINONLY_REBASELINE_APPROVED:-0}" != "1" ]]; then
  printf 'Set FULL_TRAINONLY_REBASELINE_APPROVED=1 to launch the full rebaseline.\n' >&2
  exit 2
fi
cd "$REPO_ROOT"
if [[ -n "$(git status --porcelain)" ]]; then
  printf 'The full rebaseline requires a clean committed worktree.\n' >&2
  git status --short >&2
  exit 2
fi
if tmux has-session -t "$SESSION" 2>/dev/null; then
  printf 'tmux session already exists: %s\n' "$SESSION" >&2
  exit 2
fi

STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
COMMAND="cd $(printf '%q' "$REPO_ROOT") && FULL_TRAINONLY_REBASELINE_APPROVED=1 validation/fitforecast_v2/scripts/run_qdesn_train_only_rebaseline_v1_pipeline.sh $(printf '%q' "$REPO_ROOT") $(printf '%q' "$WORKERS") $(printf '%q' "$RUN_ID") > $(printf '%q' "$STATE_ROOT/pipeline.stdout.log") 2>&1"
printf '%s\n' "$COMMAND" > "$STATE_ROOT/launch_command.txt"
tmux new-session -d -s "$SESSION" "$COMMAND"
printf 'session=%s\nrun_id=%s\nstate_root=%s\n' "$SESSION" "$RUN_ID" "$STATE_ROOT"
