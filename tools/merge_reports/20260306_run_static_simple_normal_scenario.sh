#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <scenario_root> [label]" >&2
  exit 1
fi

SCENARIO_ROOT="$1"
LABEL="${2:-simple_linear_normal}"
STAMP="$(date +%Y%m%d_%H%M%S)"
SIM_PATH="${SCENARIO_ROOT}/fit_input_subsample_tt5000_xmain_sorted/sim_output.rds"
RUN_ROOT="${SCENARIO_ROOT}/static_vb_then_mcmc_tt5000_vbns1000_burn4000_n2000_${STAMP}_${LABEL}_sub5000"
SUMMARY_PATH="${RUN_ROOT}/tables/pipeline_task_summary.csv"

if [[ ! -f "$SIM_PATH" ]]; then
  echo "missing sim path: $SIM_PATH" >&2
  exit 1
fi

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

export EXDQLM_STATIC_SIM_PATH="$SIM_PATH"
export EXDQLM_STATIC_OUT_ROOT="$RUN_ROOT"
export EXDQLM_STATIC_PIPELINE_CORES=6
export EXDQLM_STATIC_PIPELINE_TT=5000
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
export EXDQLM_STATIC_LD_INIT_COV_DIAG=1e-2,1e-2
export EXDQLM_STATIC_LD_XI_MODE=single
export EXDQLM_STATIC_LD_XI_REPLICATES=0
export EXDQLM_STATIC_LD_REUSE_DRAWS=false
export EXDQLM_STATIC_LD_ANTITHETIC=true
export EXDQLM_STATIC_LD_REUSE_SEED=20260306
export EXDQLM_STATIC_LD_DAMPING=1
export EXDQLM_STATIC_LD_XI_DAMPING=1
export EXDQLM_STATIC_LD_STEP_CAP_ETA=Inf
export EXDQLM_STATIC_LD_STEP_CAP_ELL=Inf
export EXDQLM_STATIC_LD_EIG_CAP=1
export EXDQLM_STATIC_LD_OPTIMIZER_MAXIT=2000
export EXDQLM_STATIC_MCMC_BURN=4000
export EXDQLM_STATIC_MCMC_N=2000
export EXDQLM_STATIC_MCMC_THIN=1
export EXDQLM_STATIC_MCMC_MH_PROPOSAL=rw
export EXDQLM_STATIC_MCMC_MH_ADAPT=true
export EXDQLM_STATIC_MCMC_MH_ADAPT_INTERVAL=50
export EXDQLM_STATIC_MCMC_MH_TARGET_LO=0.20
export EXDQLM_STATIC_MCMC_MH_TARGET_HI=0.45
export EXDQLM_STATIC_MCMC_MH_SCALE_MIN=0.1
export EXDQLM_STATIC_MCMC_MH_SCALE_MAX=10
export EXDQLM_STATIC_MCMC_MH_MAX_SCALE_STEP=0.35
export EXDQLM_STATIC_MCMC_MH_MIN_BURN_ADAPT=50

printf '%s | pipeline start | scenario=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LABEL" "$RUN_ROOT"
Rscript tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R

export EXDQLM_STATIC_RUN_ROOT="$RUN_ROOT"
export EXDQLM_STATIC_SUMMARY_PATH="$SUMMARY_PATH"
export EXDQLM_STATIC_TRACE_START=20
printf '%s | postprocess start | scenario=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LABEL" "$RUN_ROOT"
Rscript tools/merge_reports/20260305_static_postprocess_from_existing_fits.R

export EXDQLM_STATIC_PLOT_COVAR=x_main
printf '%s | report start | scenario=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LABEL" "$RUN_ROOT"
Rscript tools/merge_reports/20260305_static_vb_mcmc_report.R
printf '%s | complete | scenario=%s | run_root=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LABEL" "$RUN_ROOT"
