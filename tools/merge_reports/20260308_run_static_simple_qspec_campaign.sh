#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TAUS="${EXDQLM_QSPEC_TAUS:-0.05 0.25 0.95}"
BASE_OUT="${EXDQLM_SIMPLE_NORMAL_OUT_ROOT:-results/function_testing_20260306_static_simple_linear_normal_qspec}"
N_TOTAL="${EXDQLM_SIMPLE_NORMAL_N:-7000}"
TARGET_N="${EXDQLM_SIMPLE_NORMAL_TARGET_N:-5000}"
VB_NSAMP="${EXDQLM_STATIC_VB_NSAMP:-1000}"
VB_MAX_ITER="${EXDQLM_STATIC_VB_MAX_ITER:-300}"
MCMC_BURN="${EXDQLM_STATIC_MCMC_BURN:-2000}"
MCMC_N="${EXDQLM_STATIC_MCMC_N:-1000}"
CORES="${EXDQLM_STATIC_PIPELINE_CORES:-3}"

for TAU in $TAUS; do
  TAU_TAG=$(printf '%.2f' "$TAU" | tr '.' 'p')
  echo "[$(date '+%F %T')] static-simple qspec tau=$TAU"
  EXDQLM_TARGET_TAU="$TAU" \
  EXDQLM_SIMPLE_NORMAL_OUT_ROOT="$BASE_OUT" \
  EXDQLM_SIMPLE_NORMAL_N="$N_TOTAL" \
  EXDQLM_SIMPLE_NORMAL_TARGET_N="$TARGET_N" \
  Rscript tools/merge_reports/20260306_generate_static_simple_linear_normal.R

  SIM_PATH="$BASE_OUT/tau_${TAU_TAG}/fit_input_subsample_tt${TARGET_N}_xmain_sorted/sim_output.rds"
  RUN_ROOT="$BASE_OUT/tau_${TAU_TAG}/run_tt${TARGET_N}_vbns${VB_NSAMP}_burn${MCMC_BURN}_n${MCMC_N}"

  EXDQLM_STATIC_SIM_PATH="$SIM_PATH" \
  EXDQLM_STATIC_PIPELINE_TAU="$TAU" \
  EXDQLM_STATIC_PIPELINE_TT="$TARGET_N" \
  EXDQLM_STATIC_VB_NSAMP="$VB_NSAMP" \
  EXDQLM_STATIC_VB_MAX_ITER="$VB_MAX_ITER" \
  EXDQLM_STATIC_MCMC_BURN="$MCMC_BURN" \
  EXDQLM_STATIC_MCMC_N="$MCMC_N" \
  EXDQLM_STATIC_PIPELINE_CORES="$CORES" \
  EXDQLM_STATIC_OUT_ROOT="$RUN_ROOT" \
  Rscript tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R

  EXDQLM_STATIC_RUN_ROOT="$RUN_ROOT" \
  Rscript tools/merge_reports/20260305_static_postprocess_from_existing_fits.R

  EXDQLM_STATIC_RUN_ROOT="$RUN_ROOT" \
  Rscript tools/merge_reports/20260305_static_vb_mcmc_report.R
  echo "[$(date '+%F %T')] static-simple qspec tau=$TAU done"
done
