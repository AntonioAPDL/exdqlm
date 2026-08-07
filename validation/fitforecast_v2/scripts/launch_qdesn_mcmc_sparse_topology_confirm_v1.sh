#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-qdesn_mcmc_sparse_topology_confirm_v1_$(date +%Y%m%d_%H%M%S)}"
SESSION="${3:-ffv2_qdesn_sparse_topology_confirm_v1_$(date +%Y%m%d_%H%M%S)}"
cd "$REPO_ROOT"

EXPECTED_BRANCH="validation/qdesn-mcmc-sparse-topology-confirm-v1-1.0.0"
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
read -r behind ahead < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$behind" -ne 0 || "$ahead" -ne 0 ]]; then
  echo "Launch refused: upstream mismatch (behind=$behind ahead=$ahead)." >&2
  exit 2
fi
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session already exists: $SESSION" >&2
  exit 2
fi

STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STDOUT_LOG="$STATE_ROOT/pipeline.stdout.log"
PIPELINE="validation/fitforecast_v2/scripts/run_qdesn_mcmc_sparse_topology_confirm_v1_pipeline.sh"
printf '%s\n' "$SESSION" > "$STATE_ROOT/tmux_session.txt"
printf '%s\n' "$RUN_ID" > "$STATE_ROOT/run_id.txt"
printf '%s\n' "$(git rev-parse HEAD)" > "$STATE_ROOT/launch_commit.txt"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec bash '$PIPELINE' '$REPO_ROOT' '$RUN_ID' > '$STDOUT_LOG' 2>&1"
sleep 2
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Pipeline session exited during startup; inspect $STDOUT_LOG" >&2
  exit 3
fi
printf 'session=%s\nrun_id=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$STATE_ROOT" "$STDOUT_LOG"
