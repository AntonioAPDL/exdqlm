#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_syncedbase_residual_repair_20260407"
MANIFEST="$OUT_DIR/LOCAL_original288_syncedbase_residual_manifest_20260407.csv"

while true; do
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  eval_out="$(Rscript "$OUT_DIR/LOCAL_original288_syncedbase_residual_repair_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG" 2>/dev/null || true)"
  summary_line="$(printf '%s\n' "$eval_out" | rg '^SUMMARY ' || true)"
  active_runners="$( (pgrep -af "LOCAL_full288_case_runner_20260327.R.*--tag=$TAG" || true) | wc -l | tr -d ' ' )"
  echo "[$ts] active_runners=$active_runners ${summary_line:-SUMMARY unavailable}"
  if [[ "$summary_line" == *"missing=0"* ]] && [[ "$active_runners" == "0" ]]; then
    break
  fi
  sleep 60
done
