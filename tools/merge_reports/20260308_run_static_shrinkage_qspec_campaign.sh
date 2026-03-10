#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TAUS="${EXDQLM_QSPEC_TAUS:-0.05 0.50 0.95}"
PRIORS="${EXDQLM_QSPEC_PRIORS:-ridge rhs}"
BASE_OUT="${EXDQLM_STATIC_SHRINK_OUT_ROOT:-results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian_qspec}"
TARGET_N="${EXDQLM_STATIC_SHRINK_TARGET_N:-5000}"
VB_NSAMP="${EXDQLM_STATIC_VB_NSAMP:-1000}"
VB_MAX_ITER="${EXDQLM_STATIC_VB_MAX_ITER:-300}"
MCMC_BURN="${EXDQLM_STATIC_MCMC_BURN:-2000}"
MCMC_N="${EXDQLM_STATIC_MCMC_N:-1000}"
CORES="${EXDQLM_STATIC_PIPELINE_CORES:-3}"

for TAU in $TAUS; do
  TAU_TAG=$(printf '%.2f' "$TAU" | tr '.' 'p')
  echo "[$(date '+%F %T')] static-shrink qspec tau=$TAU"
  EXDQLM_TARGET_TAU="$TAU" \
  EXDQLM_STATIC_SHRINK_OUT_ROOT="$BASE_OUT" \
  EXDQLM_STATIC_SHRINK_TARGET_N="$TARGET_N" \
  Rscript tools/merge_reports/20260308_generate_static_homoskedastic_shrinkage_gaussian.R
  SIM_PATH="$BASE_OUT/tau_${TAU_TAG}/fit_input_subsample_tt${TARGET_N}_xmain_sorted/sim_output.rds"

  for PRIOR in $PRIORS; do
    RUN_ROOT="$BASE_OUT/tau_${TAU_TAG}/run_${PRIOR}_tt${TARGET_N}_vbns${VB_NSAMP}_burn${MCMC_BURN}_n${MCMC_N}"
    EXDQLM_STATIC_SIM_PATH="$SIM_PATH" \
    EXDQLM_STATIC_PIPELINE_TAU="$TAU" \
    EXDQLM_STATIC_PIPELINE_TT="$TARGET_N" \
    EXDQLM_STATIC_PIPELINE_CORES="$CORES" \
    EXDQLM_STATIC_VB_NSAMP="$VB_NSAMP" \
    EXDQLM_STATIC_VB_MAX_ITER="$VB_MAX_ITER" \
    EXDQLM_STATIC_MCMC_BURN="$MCMC_BURN" \
    EXDQLM_STATIC_MCMC_N="$MCMC_N" \
    EXDQLM_STATIC_BETA_PRIOR="$PRIOR" \
    EXDQLM_STATIC_OUT_ROOT="$RUN_ROOT" \
    Rscript tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R

    EXDQLM_STATIC_RUN_ROOT="$RUN_ROOT" \
    Rscript tools/merge_reports/20260305_static_postprocess_from_existing_fits.R

    EXDQLM_STATIC_RUN_ROOT="$RUN_ROOT" \
    Rscript tools/merge_reports/20260305_static_vb_mcmc_report.R
  done
  echo "[$(date '+%F %T')] static-shrink qspec tau=$TAU done"
done
