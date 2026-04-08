# PLAN: QDESN Dynamic Effective-W300 Failed-Root Relaunch

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Relaunch only the failed roots from the completed effective-w300 posterior-draw rerun after fixing
the implementation / numerical failure path.

Source run:

- `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`

Repair target:

- `6` failed roots
- all on the effective `5000` surface
- all expected to rerun under the same effective-w300 / posterior-draw study contract

## 2) Root-Cause Summary

Primary inner failure:

- `mcmc_al` crashed in `exal_mcmc_fit()` during latent-`v` GIG sampling with:
  - `exal_mcmc_fit::latent_v returned 1 invalid draws ... value=NA`

Secondary outer failure:

- failed fits did not always write `fit_summary_row.csv`
- root aggregation later surfaced the downstream symptom:
  - `arguments imply differing number of rows: 1, 0`

Important interpretation:

- these are implementation / numerical failures
- they are not merely weak-signoff or poor-mixing cases

## 3) Repair Strategy

Code-level repair:

- stabilize the C++ GIG sampler numerics
- retry invalid GIG draws in the R wrappers instead of hard-failing immediately
- always write `fit_summary_row.csv` on failed fits so downstream aggregation remains auditable
- allow auditable subset-grid reruns in the dynamic validation runner

Validation strategy:

1. unit-level regression checks for:
   - GIG retry repair
   - failed-fit summary-row writing
2. direct reproduction of exact previously failed `mcmc_al` requests
3. prepare-only validation of the failed-root-only relaunch subset

## 4) Failed-Root Relaunch Scope

Exact relaunch scope:

- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__laplace__tau_0p05__lasttt_5000__qdesn_ridge`
- `root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_ridge`

Relaunch contract:

- same defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`
- same canonical grid source:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.csv`
- subset execution:
  - auditable subset grid written at relaunch time
  - `--allow-grid-subset`
- same worker policy:
  - `6` workers
- no design retuning in this repair pass

## 5) Reproducibility Assets

Repair / relaunch code:

- `R/utils.R`
- `src/sampling_utils.cpp`
- `R/qdesn_static_exdqlm_crossstudy.R`
- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_failed_root_relaunch.R`

Regression tests:

- `tests/testthat/test-qdesn-dynamic-failure-repair.R`

## 6) Execution Sequence

1. commit the repair and docs on the integration branch
2. run the failed-root relaunch driver from committed state
3. let the targeted rerun complete
4. reconcile recovered roots back into the authoritative effective-w300 state
5. regenerate the comparison outputs from the repaired state
