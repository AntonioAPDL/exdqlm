#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SCENARIO="${EXDQLM_DYNAMIC_DLM_SCENARIO:-dlm_constV_smallW}"
TAUS="${EXDQLM_QSPEC_TAUS:-0.05 0.50 0.95}"
SIM_T="${EXDQLM_DYNAMIC_SIM_T:-5000}"
FIT_TT="${EXDQLM_DYNAMIC_FIT_TT:-5000}"
VB_NSAMP="${EXDQLM_VB_NSAMP:-1000}"
VB_MAX_ITER="${EXDQLM_VB_MAX_ITER:-300}"
MCMC_BURN="${EXDQLM_MCMC_BURN:-2000}"
MCMC_N="${EXDQLM_MCMC_N:-1000}"
CORES="${EXDQLM_PIPELINE_CORES:-3}"
BASE_OUT="${EXDQLM_DYNAMIC_DLM_OUT_BASE:-results/sim_suite_dlm_qspec/series}"
RUN_BASE="${EXDQLM_DYNAMIC_RUN_BASE:-results/function_testing_dynamic_qspec}"

for TAU in $TAUS; do
  TAU_TAG=$(printf '%.2f' "$TAU" | tr '.' 'p')
  echo "[$(date '+%F %T')] dynamic-dlm qspec scenario=$SCENARIO tau=$TAU"
  EXDQLM_TARGET_TAU="$TAU" \
  EXDQLM_SIM_T="$SIM_T" \
  EXDQLM_DYNAMIC_FIT_TT="$FIT_TT" \
  EXDQLM_DYNAMIC_DLM_SCENARIO="$SCENARIO" \
  EXDQLM_DYNAMIC_DLM_OUT_ROOT="$BASE_OUT/$SCENARIO/tau_${TAU_TAG}" \
  Rscript tools/merge_reports/20260308_generate_dynamic_dlm_quantile_specific.R

  SIM_PATH="$BASE_OUT/$SCENARIO/tau_${TAU_TAG}/fit_input_tt${FIT_TT}/sim_output.rds"
  RUN_ROOT="$RUN_BASE/${SCENARIO}_tau_${TAU_TAG}_tt${FIT_TT}_vbns${VB_NSAMP}_burn${MCMC_BURN}_n${MCMC_N}"

  EXDQLM_DYNAMIC_SIM_PATH="$SIM_PATH" \
  EXDQLM_DYNAMIC_PIPELINE_TAU="$TAU" \
  EXDQLM_PIPELINE_TT="$FIT_TT" \
  EXDQLM_VB_NSAMP="$VB_NSAMP" \
  EXDQLM_VB_MAX_ITER="$VB_MAX_ITER" \
  EXDQLM_MCMC_BURN="$MCMC_BURN" \
  EXDQLM_MCMC_N="$MCMC_N" \
  EXDQLM_PIPELINE_CORES="$CORES" \
  EXDQLM_DYNAMIC_OUT_ROOT="$RUN_ROOT" \
  Rscript tools/merge_reports/20260305_vb_then_mcmc_pipeline.R

  EXDQLM_DYNAMIC_RUN_ROOT="$RUN_ROOT" \
  Rscript tools/merge_reports/20260305_postprocess_from_existing_fits.R
  echo "[$(date '+%F %T')] dynamic-dlm qspec scenario=$SCENARIO tau=$TAU done"
done
