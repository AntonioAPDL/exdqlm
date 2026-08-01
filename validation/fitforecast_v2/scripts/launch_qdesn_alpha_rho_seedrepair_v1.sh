#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
WORKERS="${2:-12}"
RUN_ID="${3:-qdesn_alpha_rho_seedrepair_v1_$(date +%Y%m%d_%H%M%S)}"
SESSION="ffv2_qdesn_arsr1_${RUN_ID##*_}"
PIPELINE="$REPO_ROOT/validation/fitforecast_v2/scripts/run_qdesn_alpha_rho_seedrepair_v1_pipeline.sh"
STDOUT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/${RUN_ID}/pipeline.stdout.log"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session already exists: $SESSION" >&2
  exit 1
fi

mkdir -p "$(dirname "$STDOUT")"
tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && bash '$PIPELINE' '$REPO_ROOT' '$WORKERS' '$RUN_ID' > '$STDOUT' 2>&1"

printf 'RUN_ID=%s\nSESSION=%s\nSTDOUT=%s\n' "$RUN_ID" "$SESSION" "$STDOUT"
