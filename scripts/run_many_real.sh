#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_DIR"

SPEC="${1:-real_heavy}"
DATASETS_FILE="config/datasets.yaml"

if [[ ! -f "$DATASETS_FILE" ]]; then
  echo "Missing datasets file: $DATASETS_FILE"
  exit 1
fi

trim_val() {
  local v="$1"
  v="${v%%#*}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  echo "$v"
}

# Auto-read all real slugs from config/datasets.yaml
SLUGS=()
current_slug=""
current_mode=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*slug:[[:space:]]*(.*)$ ]]; then
    if [[ -n "$current_slug" && "$current_mode" == "real" ]]; then
      SLUGS+=("$current_slug")
    fi
    current_slug="$(trim_val "${BASH_REMATCH[1]}")"
    current_mode=""
  elif [[ "$line" =~ ^[[:space:]]{4}mode:[[:space:]]*(.*)$ ]]; then
    current_mode="$(trim_val "${BASH_REMATCH[1]}")"
  fi
done < "$DATASETS_FILE"

if [[ -n "$current_slug" && "$current_mode" == "real" ]]; then
  SLUGS+=("$current_slug")
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
