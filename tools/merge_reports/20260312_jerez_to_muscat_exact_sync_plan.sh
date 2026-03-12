#!/usr/bin/env bash
set -euo pipefail

SRC_HOST="jaguir26@jerez.be.ucsc.edu"
SRC_BASE="/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp"
DST_BASE="/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
PLAN_TSV="tools/merge_reports/20260312_jerez_to_muscat_exact_sync_plan.tsv"

if [[ ! -f "$PLAN_TSV" ]]; then
  echo "Missing plan TSV: $PLAN_TSV" >&2
  exit 1
fi

# Copies only exact run-root outputs listed in the plan TSV.
# Default mode copies only roots already complete on jerez.
MODE="${1:-complete_only}" # complete_only | include_running
if [[ "$MODE" != "complete_only" && "$MODE" != "include_running" ]]; then
  echo "Usage: $0 [complete_only|include_running]" >&2
  exit 1
fi
export MODE

awk -F'\t' 'NR==1{next} {
  state=$1; run_root=$4;
  if (ENVIRON["MODE"]=="complete_only" && state!="complete_on_jerez") next;
  print state"\t"run_root;
}' "$PLAN_TSV" | while IFS=$'\t' read -r state run_root; do
  src="$SRC_HOST:$SRC_BASE/$run_root/"
  dst="$DST_BASE/$run_root/"
  mkdir -p "$dst"
  echo "[sync] $state $run_root"
  rsync -a --info=progress2 "$src" "$dst"
done

echo "Sync complete for mode=$MODE"
