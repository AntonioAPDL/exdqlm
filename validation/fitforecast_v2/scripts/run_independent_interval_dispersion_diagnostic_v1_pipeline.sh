#!/usr/bin/env bash
set -euo pipefail

export OMP_NUM_THREADS=1
export OMP_THREAD_LIMIT=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1
export IMI_V1_LAUNCH_APPROVED=true

if [[ $# -ne 3 ]]; then
  printf 'usage: %s REPO_ROOT STATE_ROOT WORKERS\n' "$0" >&2
  exit 2
fi

repo_root=$1
state_root=$2
workers=$3
harness_root="${repo_root}/validation/fitforecast_v2"
rscript_bin="${RSCRIPT_BIN:-$(command -v Rscript)}"

"${rscript_bin}" \
  "${harness_root}/scripts/verify_independent_interval_dispersion_diagnostic_v1_plan.R" \
  --state-root "${state_root}"

"${rscript_bin}" \
  "${harness_root}/scripts/orchestrate_independent_metric_intervals_v1.R" \
  --repo-root "${repo_root}" \
  --state-root "${state_root}" \
  --workers "${workers}" \
  --approved true

"${rscript_bin}" \
  "${harness_root}/scripts/closeout_independent_interval_dispersion_diagnostic_v1.R" \
  --repo-root "${repo_root}" \
  --state-root "${state_root}"
