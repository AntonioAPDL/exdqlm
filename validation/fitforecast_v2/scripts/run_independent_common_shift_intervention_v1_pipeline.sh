#!/usr/bin/env bash
set -euo pipefail
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1 IMI_V1_LAUNCH_APPROVED=true
if [[ $# -ne 3 ]]; then
  printf 'usage: %s REPO_ROOT STATE_ROOT WORKERS\n' "$0" >&2
  exit 2
fi
repo_root=$1; state_root=$2; workers=$3
Rscript "$repo_root/validation/fitforecast_v2/scripts/verify_independent_common_shift_intervention_v1_plan.R" --state-root "$state_root"
Rscript "$repo_root/validation/fitforecast_v2/scripts/orchestrate_independent_metric_intervals_v1.R" --repo-root "$repo_root" --state-root "$state_root" --workers "$workers" --approved true
Rscript "$repo_root/validation/fitforecast_v2/scripts/closeout_independent_common_shift_intervention_v1.R" --state-root "$state_root"
