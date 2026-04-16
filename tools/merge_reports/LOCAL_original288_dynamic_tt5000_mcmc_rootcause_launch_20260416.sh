#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MANIFEST="tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_manifest_20260416.csv"
RUN_ROOT="tools/merge_reports/full288_original288_dynamic_tt5000_mcmc_rootcause_20260416"
LOG_DIR="$RUN_ROOT/logs"
mkdir -p "$LOG_DIR"

Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_prepare_20260416.R

awk -F, 'NR>1 {print $1}' "$MANIFEST" > "$RUN_ROOT/row_ids.txt"

xargs -a "$RUN_ROOT/row_ids.txt" -P 1 -I{} bash -lc '
  id="$1"
  root="$2"
  manifest="$3"
  log_dir="$4"
  cd "$root"
  log="$log_dir/rootcause_row_${id}.log"
  Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_run_case_20260416.R \
    --manifest="$manifest" \
    --row_id="$id" \
    --force=1 > "$log" 2>&1
' _ {} "$ROOT" "$MANIFEST" "$LOG_DIR"

Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_summarize_20260416.R
