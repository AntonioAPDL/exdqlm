#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_DIR"

SPEC="${1:-real_heavy}"
DATASETS_FILE="config/datasets_real.yaml"

if [[ ! -f "$DATASETS_FILE" ]]; then
  echo "Missing datasets file: $DATASETS_FILE"
  exit 1
fi

# Auto-read all real slugs from config/datasets_real.yaml
if command -v rg >/dev/null 2>&1; then
  mapfile -t SLUGS < <(
    rg -o "^\\s*-\\s*slug:\\s*.*" "$DATASETS_FILE" | \
      sed -E "s/^\\s*-\\s*slug:\\s*//; s/\\s+#.*$//; s/^['\\\"]//; s/['\\\"]$//"
  )
else
  mapfile -t SLUGS < <(
    grep -E "^\\s*-\\s*slug:\\s*" "$DATASETS_FILE" | \
      sed -E "s/^\\s*-\\s*slug:\\s*//; s/\\s+#.*$//; s/^['\\\"]//; s/['\\\"]$//"
  )
fi

if [[ ${#SLUGS[@]} -eq 0 ]]; then
  echo "No slugs found in $DATASETS_FILE"
  exit 1
fi

command -v tmux >/dev/null 2>&1 || { echo "tmux not found in PATH"; exit 1; }
mkdir -p tmux_logs
STAMP="$(date +%Y%m%d-%H%M%S)"

for slug in "${SLUGS[@]}"; do
  sess="real_${slug}_${SPEC}_${STAMP}"
  log="tmux_logs/${sess}.log"
  tmux new-session -d -s "$sess" \
    "echo \"[\$(date)] Starting real pipeline for slug=${slug} spec=${SPEC}\"; \
     Rscript scripts/pipeline_run.R --slug ${slug} --spec ${SPEC} 2>&1 | tee \"$log\"; \
     echo \"[\$(date)] Finished slug=${slug} spec=${SPEC}\"; \
     echo 'Press Enter to close pane...'; read _"
  echo "Started tmux session: $sess"
  echo "  Attach: tmux attach -t $sess"
  echo "  Live log: tail -f $log"
done

echo
echo "List sessions: tmux ls | grep ${SPEC}_${STAMP}"
