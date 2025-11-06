#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_DIR"

SPEC="${1:-real_heavy}"
# Put your real slugs here (from config/datasets_real.yaml)
SLUGS=(san_lorenzo_daily)

command -v tmux >/dev/null 2>&1 || { echo "tmux not found in PATH"; exit 1; }
mkdir -p tmux_logs
STAMP="$(date +%Y%m%d-%H%M%S)"

for slug in "${SLUGS[@]}"; do
  sess="real_${slug}_${SPEC}_${STAMP}"
  log="tmux_logs/${sess}.log"
  tmux new-session -d -s "$sess" \
    "echo \"[\$(date)] Starting real pipeline for slug=${slug} spec=${SPEC}\"; \
     Rscript scripts/pipeline_run.R --slug ${slug} --spec ${SPEC} 2>&1 | tee "$log"; \
     echo \"[\$(date)] Finished slug=${slug} spec=${SPEC}\"; \
     echo 'Press Enter to close pane...'; read _"
  echo "Started tmux session: $sess"
  echo "  Attach: tmux attach -t $sess"
  echo "  Live log: tail -f $log"
done

echo
echo "List sessions: tmux ls | grep ${SPEC}_${STAMP}"
