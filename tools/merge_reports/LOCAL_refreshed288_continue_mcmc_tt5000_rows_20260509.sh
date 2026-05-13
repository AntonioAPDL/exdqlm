#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

export R_LIBS_USER="${R_LIBS_USER:-/data/jaguir26/R/local_libs}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

manifest="tools/merge_reports/LOCAL_refreshed288_full_manifest_20260507_p90_dynamic72_qdesn_comparable_fresh_v1.csv"
runner="tools/merge_reports/LOCAL_refreshed288_run_row_20260422_p90_full288.R"

for row_id in 8 14 16 22 24 30 32 38 40 54 56 62 64 70 72; do
  printf '[stage-mcmc-tt5000] starting row_id=%s at %s\n' "$row_id" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  Rscript "$runner" --manifest="$manifest" --row_id="$row_id"
  printf '[stage-mcmc-tt5000] finished row_id=%s at %s\n' "$row_id" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
done
