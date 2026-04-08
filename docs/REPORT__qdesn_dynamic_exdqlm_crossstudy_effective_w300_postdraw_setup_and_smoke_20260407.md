# REPORT: QDESN Dynamic exdqlm Cross-Study Effective-W300 Posterior-Draw Setup And Smoke

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Executive Read

The new effective-size posterior-draw rerun contract is now implemented and smoke-validated on the
integration branch.

This is a **new study contract**, separate from the earlier zero-FAIL authoritative baseline. Its
purpose is to strengthen the academic fit-evaluation design, not to erase the earlier baseline.

Smoke result:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-20260407-231231__git-812cb58`
- campaign root status:
  - `4/4 SUCCESS`
- fit signoff mix:
  - `8 PASS`
  - `6 WARN`
  - `2 FAIL`
- root readiness:
  - `4/4` comparison-eligible-any
  - `2/4` comparison-eligible-full
- recommendation:
  - `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`

The key validation gate passed:

- the corrected source-window contract now yields the intended effective train sizes exactly:
  - effective `500` uses total `813`
  - effective `5000` uses total `5313`
- fit summaries now show:
  - `train_n_eval = 500` or `5000`
  - `holdout_n_eval = 1`
  - `train_draw_n = 1000`
  - `holdout_draw_n = 1000`

## 2) New Study Contract

### 2.1 Effective size semantics

Reported fit sizes remain:

- `500`
- `5000`

But they now mean:

- **effective post-washout train size**

Under the current pipeline contract, the required source length is:

`source_total_size = effective_fit_size + holdout_n + lag_max + washout`

Current values:

- `holdout_n = 1`
- `lag_max = 12`
- `washout = 300`

Therefore:

- effective `500`:
  - total `813`
- effective `5000`:
  - total `5313`

This contract is now enforced in the dynamic source-materialization helper so future config edits
cannot silently break the effective-size interpretation.

### 2.2 Shared inference and draw settings

MCMC:

- `n_burn = 1000`
- `n_mcmc = 2000`
- `thin = 1`

Posterior metric draws:

- `sampling.nd_draws = 1000`
- `synthesis.n_samp = 1000`

Storage policy:

- do not keep posterior draw-heavy artifacts beyond the normal pipeline objects and summary tables

## 3) Metric Design

Primary oracle quantile-recovery metrics against known `q_true`:

- `qtrue_mae`
- `qtrue_rmse`
- `qtrue_bias`
- `qtrue_corr`
- `qtrue_median_ae`
- `qtrue_p90_ae`

Primary quantile-calibration metrics against observed `y`:

- `pinball_tau`
- `coverage`
- `coverage_minus_tau`
- `coverage_error`

Primary compute metrics:

- `runtime_sec`
- `runtime_sec_per_1k_eval`
- `runtime_sec_per_1k_train_eval`

Posterior-summary outputs now include, per fit:

- posterior mean
- posterior SD
- posterior quantiles:
  - `q05`
  - `q50`
  - `q95`

Point-path reductions are retained as secondary diagnostics.

## 4) Implemented Assets

Defaults and grid:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.csv`

Core helpers:

- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- `R/qdesn_static_exdqlm_crossstudy.R`
- `R/qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R`

Wrappers:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation.R`

## 5) Validation Evidence

### 5.1 Prepare-only

Passed:

- smoke:
  - `qdesn-dynamic-exdqlm-crossstudy-smoke-20260407-231214__git-812cb58`
- full:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-231214__git-812cb58`

### 5.2 Corrected smoke execution

Smoke report root:

- `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation/qdesn-dynamic-exdqlm-crossstudy-smoke-20260407-231231__git-812cb58/20260407-231232__git-812cb58`

Primary smoke outputs:

- summary:
  - `summary/qdesn_dynamic_crossstudy_summary.md`
- fit summaries:
  - `tables/campaign_fit_summary.csv`
- root progress:
  - `tables/campaign_progress.csv`

Verified split evidence from live pipeline logs:

- effective `500`:
  - `T_use = 813`
  - `train_n = 812`
  - `rows: X_train = 500`
- effective `5000`:
  - `T_use = 5313`
  - `train_n = 5312`
  - `rows: X_train = 5000`

Verified fit-summary evidence from completed `fit_size=500` roots:

- `fit_size = 500`
- `effective_fit_size = 500`
- `source_total_size = 813`
- `source_window_label = effTT500_totalTT813`
- `train_n_eval = 500`
- `holdout_n_eval = 1`
- `train_draw_n = 1000`
- `holdout_draw_n = 1000`

## 6) Smoke Interpretation

What the smoke run proves:

- the new materialized-source contract is correct
- the new posterior-summary metric columns are being written and populated
- the deeper MCMC settings run through the smoke surface without root execution failure
- the branch is ready for the full 36-root rerun from this new committed study contract

What the smoke run does **not** prove:

- that the new broader contract will dominate the earlier zero-FAIL baseline scientifically
- that the new fail/warn profile will necessarily improve on the prior branch-local baseline

That broader scientific question belongs to the full 144-fit rerun and its downstream comparison
analysis.

## 7) Recommended Next Move

From a clean committed branch state:

1. keep this effective-size posterior-draw design as a separate branch-local rerun program
2. launch the full `36`-root / `144`-fit rerun using the new defaults
3. rebuild the main comparison pack from the new rerun outputs only after that full campaign
   completes
