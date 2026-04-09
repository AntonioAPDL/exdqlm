#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="static_bqrgal_aligned_20260408"
MANIFEST="$OUT_DIR/LOCAL_static_bqrgal_aligned_manifest_20260408.csv"

while true; do
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  eval_out="$(Rscript "$OUT_DIR/LOCAL_static_bqrgal_aligned_evaluate_20260408.R" --manifest="$MANIFEST" 2>/dev/null || true)"
  summary_line="$(printf '%s\n' "$eval_out" | rg '^SUMMARY ' || true)"
  active_runners="$( (pgrep -af 'LOCAL_static_bqrgal_aligned_run_row_20260408.R' || true) | wc -l | tr -d ' ' )"
  echo "[$ts] active_runners=$active_runners ${summary_line:-SUMMARY unavailable}"
  if [[ "$summary_line" == *"missing=0"* ]] && [[ "$active_runners" == "0" ]]; then
    break
  fi
  sleep 60
done
