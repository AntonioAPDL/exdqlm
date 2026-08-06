#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"; cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/qdesn-trainonly-followup-v1-1.0.0"
[[ -z "$(git status --porcelain)" ]] || { echo "Refusing launch from a dirty worktree." >&2; exit 2; }
[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || { echo "Refusing launch from an unexpected branch." >&2; exit 2; }
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[[ -n "$UPSTREAM" ]] || { echo "Refusing launch before the campaign branch has an upstream." >&2; exit 2; }
read -r BEHIND AHEAD < <(git rev-list --left-right --count "${UPSTREAM}...HEAD")
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || { echo "Refusing launch unless exactly pushed (behind=$BEHIND ahead=$AHEAD)." >&2; exit 2; }
if tmux list-sessions -F '#S' 2>/dev/null | grep -q '^ffv2_qdesn_tfv1_'; then echo "Refusing duplicate follow-up v1 launch." >&2; exit 2; fi
STAMP="$(date +%Y%m%d_%H%M%S)"; RUN_ID="qdesn_trainonly_followup_v1_${STAMP}"; SESSION="ffv2_qdesn_tfv1_${STAMP}"
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"; mkdir -p "$STATE_ROOT"; LOG="$STATE_ROOT/pipeline.stdout.log"
tmux new-session -d -s "$SESSION" "cd '$REPO_ROOT' && bash validation/fitforecast_v2/scripts/run_qdesn_trainonly_followup_v1_pipeline.sh '$REPO_ROOT' '$RUN_ID' > '$LOG' 2>&1"
cat <<EOF
session=$SESSION
run_id=$RUN_ID
worktree=$REPO_ROOT
branch=$(git branch --show-current)
commit=$(git rev-parse HEAD)
upstream=$UPSTREAM
max_workers=28
log=$REPO_ROOT/$LOG
state_root=$REPO_ROOT/$STATE_ROOT
EOF
