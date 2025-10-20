#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SESSION="${SESSION:-exdqlm-msel}"
STAGE="${STAGE:-coarse}"
GRID="${GRID:-micro}"
LIMIT_SPECS="${LIMIT_SPECS:-}"
SEEDS="${SEEDS:-42,101}"
DATA="${DATA:-}"
WORKERS="${WORKERS:-}"          # NEW: forward if provided
PARALLEL="${PARALLEL:-TRUE}"     # allow override
GRID_SEED="${GRID_SEED:-}"       # optional
PLOT="${PLOT:-}"                 # optional
KEEP="${KEEP:-}"                 # optional
PROGRESS_EVERY="${PROGRESS_EVERY:-}"  # optional
WEIGHT_LEADS="${WEIGHT_LEADS:-inverse_h}"   # optional override
SPLIT="${SPLIT:-0.80,0.15,0.05}"            # optional override

# Build the actual run command (all envs we want to pass into run_qdesn_msel.sh)
RUN_CMD="cd \"$ROOT\" && STAGE='$STAGE' GRID='$GRID' SEEDS='$SEEDS' PARALLEL='$PARALLEL'"
[[ -n "$WORKERS" ]]        && RUN_CMD+=" WORKERS='$WORKERS'"
[[ -n "$LIMIT_SPECS" ]]    && RUN_CMD+=" LIMIT_SPECS='$LIMIT_SPECS'"
[[ -n "$DATA" ]]           && RUN_CMD+=" DATA='$DATA'"
[[ -n "$GRID_SEED" ]]      && RUN_CMD+=" GRID_SEED='$GRID_SEED'"
[[ -n "$PLOT" ]]           && RUN_CMD+=" PLOT='$PLOT'"
[[ -n "$KEEP" ]]           && RUN_CMD+=" KEEP='$KEEP'"
[[ -n "$PROGRESS_EVERY" ]] && RUN_CMD+=" PROGRESS_EVERY='$PROGRESS_EVERY'"
RUN_CMD+=" bin/run_qdesn_msel.sh"

# If tmux is not available, run in foreground
if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found; running directly in this shell:"
  echo "$RUN_CMD"
  bash -lc "$RUN_CMD"
  exit $?
fi

# Create or reuse session and run in a window
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-window -t "$SESSION" -n "msel_${STAGE}" "bash -lc \"$RUN_CMD\""
else
  tmux new-session -d -s "$SESSION" -n "msel_${STAGE}" "bash -lc \"$RUN_CMD\""
fi

echo "Launched in tmux session: $SESSION (window: msel_${STAGE})"
echo "Cmd: $RUN_CMD"
echo "Attach: tmux attach -t $SESSION"
echo "Latest log (once created):"
echo "  tail -f \"\$(ls -t \"$ROOT\"/logs/run_${STAGE}_*.log 2>/dev/null | head -n1)\""
