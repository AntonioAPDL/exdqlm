#!/usr/bin/env bash
set -euo pipefail

# --- Where this repo lives (resolve from this script's path) ---
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# --- Spec to use (default: heavy). You can pass another, e.g. ./scripts/run_many_heavy.sh tuned ---
SPEC="${1:-heavy}"

# --- Slugs to run (your three heavy ones) ---
SLUGS=(dlm_ar1V dlm_constV_bigW dlm_constV_smallW)

# --- Tmux + logging prep ---
command -v tmux >/dev/null 2>&1 || { echo "tmux not found in PATH"; exit 1; }
mkdir -p tmux_logs

STAMP="$(date +%Y%m%d-%H%M%S)"

for slug in "${SLUGS[@]}"; do
  sess="esn_${slug}_${SPEC}_${STAMP}"
  log="tmux_logs/${sess}.log"

  # Start detached tmux session that runs the job and tees output to a log
  tmux new-session -d -s "$sess" \
    "echo \"[\$(date)] Starting pipeline_run for slug=${slug} spec=${SPEC}\"; \
    Rscript scripts/pipeline_run.R --slug ${slug} --spec ${SPEC} 2>&1 | tee \"$log\"; \
    echo \"[\$(date)] Finished slug=${slug} spec=${SPEC}\"; \
    echo 'Press Enter to close pane...'; read _"

  echo "Started tmux session: $sess"
  echo "  Attach: tmux attach -t $sess"
  echo "  Live log: tail -f $log"
done

echo
echo "List sessions: tmux ls | grep ${SPEC}_${STAMP}"
