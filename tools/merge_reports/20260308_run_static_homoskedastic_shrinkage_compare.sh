#!/usr/bin/env bash
set -euo pipefail

SCENARIO_ROOT="${1:-results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian}"
STAMP="$(date +%Y%m%d_%H%M%S)"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

printf '%s | generator start | scenario_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$SCENARIO_ROOT" >&2
EXDQLM_STATIC_SHRINK_OUT_ROOT="$SCENARIO_ROOT" \
  Rscript tools/merge_reports/20260308_generate_static_homoskedastic_shrinkage_gaussian.R

SIM_PATH="${SCENARIO_ROOT}/fit_input_subsample_tt5000_xmain_sorted/sim_output.rds"
if [[ ! -f "$SIM_PATH" ]]; then
  echo "missing sim path: $SIM_PATH" >&2
  exit 1
fi

common_static_env() {
  export EXDQLM_STATIC_SIM_PATH="$SIM_PATH"
  export EXDQLM_STATIC_PIPELINE_TT=5000
  export EXDQLM_STATIC_PIPELINE_CORES=6
  export EXDQLM_STATIC_VB_MAX_ITER=1000
  export EXDQLM_STATIC_VB_TOL=0.0001
  export EXDQLM_STATIC_VB_TOL_SIGMA=0.0001
  export EXDQLM_STATIC_VB_TOL_GAMMA=0.0001
  export EXDQLM_STATIC_VB_TOL_ELBO=0.0001
  export EXDQLM_STATIC_VB_MIN_ITER=50
  export EXDQLM_STATIC_VB_PATIENCE=20
  export EXDQLM_STATIC_VB_ALLOW_ELBO_DROP=0.0001
  export EXDQLM_STATIC_VB_NSAMP=1000
  export EXDQLM_STATIC_LD_XI_METHOD=delta
  export EXDQLM_STATIC_LD_OPTIMIZER_METHOD=lbfgsb
  export EXDQLM_STATIC_LD_DIRECT_COMMIT=true
  export EXDQLM_STATIC_LD_SIGMA_INIT_MODE=data_scale
  export EXDQLM_STATIC_LD_ETA_LO=-12
  export EXDQLM_STATIC_LD_ETA_HI=12
  export EXDQLM_STATIC_MCMC_BURN=2000
  export EXDQLM_STATIC_MCMC_N=1000
  export EXDQLM_STATIC_MCMC_THIN=1
  export EXDQLM_STATIC_MCMC_MH_PROPOSAL=slice
  export EXDQLM_STATIC_MCMC_MH_ADAPT=true
  export EXDQLM_STATIC_MCMC_MH_ADAPT_INTERVAL=50
  export EXDQLM_STATIC_MCMC_MH_TARGET_LO=0.20
  export EXDQLM_STATIC_MCMC_MH_TARGET_HI=0.45
  export EXDQLM_STATIC_MCMC_MH_SCALE_MIN=0.1
  export EXDQLM_STATIC_MCMC_MH_SCALE_MAX=10
  export EXDQLM_STATIC_MCMC_MH_MAX_SCALE_STEP=0.35
  export EXDQLM_STATIC_MCMC_MH_MIN_BURN_ADAPT=50
  export EXDQLM_STATIC_MCMC_TRACE_DIAGNOSTICS=true
  export EXDQLM_STATIC_MCMC_TRACE_EVERY=5
}

run_one_prior() {
  local prior="$1"
  local label="$2"
  local run_root="${SCENARIO_ROOT}/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_${STAMP}_${label}"

  common_static_env
  export EXDQLM_STATIC_BETA_PRIOR="$prior"
  export EXDQLM_STATIC_OUT_ROOT="$run_root"

  printf '%s | pipeline start | prior=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$prior" "$run_root" >&2
  Rscript tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R

  export EXDQLM_STATIC_RUN_ROOT="$run_root"
  export EXDQLM_STATIC_SUMMARY_PATH="${run_root}/tables/pipeline_task_summary.csv"
  export EXDQLM_STATIC_TRACE_START=20
  export EXDQLM_STATIC_PLOT_COVAR=x_main

  printf '%s | postprocess start | prior=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$prior" "$run_root" >&2
  Rscript tools/merge_reports/20260305_static_postprocess_from_existing_fits.R

  printf '%s | report start | prior=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$prior" "$run_root" >&2
  Rscript tools/merge_reports/20260305_static_vb_mcmc_report.R

  printf '%s | complete | prior=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$prior" "$run_root" >&2
  echo "$run_root"
}

RIDGE_RUN_ROOT="$(run_one_prior ridge shrink_ridge)"
RHS_RUN_ROOT="$(run_one_prior rhs shrink_rhs)"

COMPARE_ROOT="${SCENARIO_ROOT}/shrinkage_compare_${STAMP}"
export EXDQLM_STATIC_SHRINK_SIM_PATH="$SIM_PATH"
export EXDQLM_STATIC_SHRINK_RIDGE_RUN_ROOT="$RIDGE_RUN_ROOT"
export EXDQLM_STATIC_SHRINK_RHS_RUN_ROOT="$RHS_RUN_ROOT"
export EXDQLM_STATIC_SHRINK_OUT_ROOT="$COMPARE_ROOT"

printf '%s | compare start | out_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$COMPARE_ROOT" >&2
Rscript tools/merge_reports/20260308_static_shrinkage_compare_report.R
printf '%s | compare complete | out_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$COMPARE_ROOT" >&2
