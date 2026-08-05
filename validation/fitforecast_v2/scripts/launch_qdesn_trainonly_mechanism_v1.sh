#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/qdesn-trainonly-mechanism-v1-1.0.0"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing launch from a dirty worktree." >&2
  exit 2
fi
if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Refusing launch from an unexpected branch." >&2
  exit 2
fi
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$UPSTREAM" ]]; then
  echo "Refusing launch before the campaign branch has an upstream." >&2
  exit 2
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count "${UPSTREAM}...HEAD")
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Refusing launch unless the branch is exactly pushed (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 2
fi
if tmux list-sessions -F '#S' 2>/dev/null | grep -q '^ffv2_qdesn_tmv1_'; then
  echo "Refusing duplicate launch while another qdesn_tmv1 session exists." >&2
  exit 2
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="qdesn_trainonly_mechanism_v1_${STAMP}"
SESSION="ffv2_qdesn_tmv1_${STAMP}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
LOG_PATH="$STATE_ROOT/pipeline.stdout.log"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && bash validation/fitforecast_v2/scripts/run_qdesn_trainonly_mechanism_v1_pipeline.sh '$REPO_ROOT' '$RUN_ID' > '$LOG_PATH' 2>&1"

cat <<EOF
session=$SESSION
run_id=$RUN_ID
worktree=$REPO_ROOT
branch=$(git branch --show-current)
commit=$(git rev-parse HEAD)
upstream=$UPSTREAM
total_workers=16
cpu_policy=raw:0-6,c12:7-9,c123:10-12,sr:13-15
log=$REPO_ROOT/$LOG_PATH
state_root=$REPO_ROOT/$STATE_ROOT
EOF
