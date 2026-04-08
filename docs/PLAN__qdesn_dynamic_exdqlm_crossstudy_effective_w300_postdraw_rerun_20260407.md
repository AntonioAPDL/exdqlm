# PLAN: QDESN Dynamic exdqlm Cross-Study Effective-W300 Posterior-Draw Rerun

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Run a new branch-local dynamic QDESN rerun that strengthens the validation design relative to the
already-certified zero-FAIL baseline.

This rerun is **not** a replacement for the earlier zero-FAIL authoritative baseline by default.
It is a new, reproducible study contract intended to:

- keep the same dynamic exdqlm-aligned surface;
- increase MCMC depth uniformly;
- evaluate quantile-fit metrics from posterior draws rather than only a single reduced quantile
  path;
- make the fitted/train path the primary evaluation window for simulation-based oracle validation;
- preserve reported sample sizes of `500` and `5000` as **effective post-washout train sizes**.

## 2) Main Design Decisions

### 2.1 Study surface

Keep the existing dynamic mirrored lattice:

- scenario:
  - `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- effective fit sizes:
  - `500`
  - `5000`
- priors:
  - `ridge`
  - `rhs_ns`
- inference:
  - `vb`
  - `mcmc`
- likelihoods:
  - `al`
  - `exal`

Therefore:

- roots:
  - `36`
- fit rows:
  - `144`

### 2.2 MCMC and VB sampling contract

Use a shared, deeper MCMC configuration for every MCMC fit:

- `n_burn = 1000`
- `n_mcmc = 2000`
- `thin = 1`

Use a shared posterior-metric draw layer for both VB and MCMC:

- `sampling.nd_draws = 1000`
- `synthesis.n_samp = 1000`

Important distinction:

- VB fitting still uses its own optimizer-side internal Monte Carlo controls;
- the new `1000`-draw contract is the metric-side posterior/predictive draw budget used to
  evaluate quantile-validation metrics;
- posterior draw-heavy artifacts are **not** retained on disk by default.

### 2.3 Washout and effective-size semantics

Use:

- `washout = 300`

But preserve the reported fit sizes `500` and `5000` as **effective post-washout train sizes**.

Under the current real-data pipeline contract, the true source length must account for:

- holdout length;
- lag warmup;
- reservoir washout.

The effective-size formula is therefore:

`source_total_size = effective_fit_size + holdout_n + lag_max + washout`

With the current defaults:

- `holdout_n = 1`
- `lag_max = 12`
- `washout = 300`

so the actual staged source lengths are:

- effective `500`:
  - total `813`
- effective `5000`:
  - total `5313`

These totals are now enforced by the materialization helper so future edits cannot silently break
the exact effective-size contract.

## 3) Primary Metrics

This rerun treats the fitted/train path as the primary evaluation window because the current split
uses:

- `holdout_n = 1`

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

For each posterior-draw metric family, save posterior summaries at the fit level:

- posterior mean
- posterior SD
- posterior quantiles:
  - `q05`
  - `q50`
  - `q95`

Also retain the point-path reductions as secondary diagnostics.

## 4) Reproducibility Rules

The rerun must remain reproducible and easy to revise later:

- defaults live in one branch-local YAML:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`
- the canonical grid is generated from the staged inputs, not hand-edited
- the staged source windows are regenerated from source simulation outputs
- all run entrypoints are thin wrappers around the shared dynamic validation stack
- no posterior draw tables are stored unless explicitly enabled later
- the metric summaries are produced automatically by the fit-summary layer and reused by the main
  comparison analysis

Current branch-local wrapper entrypoints:

- materialize grid:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.R`
- direct run:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation.R`
- detached launch:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation.R`

## 5) Implementation Checklist

1. extend the dynamic materialization/grid stack to distinguish:
   - reported effective fit size
   - actual staged source total size
2. enforce the effective-size contract from:
   - `holdout_n`
   - `lag_max`
   - `washout`
3. raise the shared MCMC depth to:
   - burn-in `1000`
   - kept iterations `2000`
4. raise the shared metric draw budget to:
   - `1000`
5. recompute fit-level quantile metrics from posterior draws and summarize them automatically
6. validate in:
   - prepare-only smoke
   - prepare-only full
   - corrected smoke execution
7. document the study contract and smoke evidence
8. commit and push the branch-local implementation
9. launch the full 144-fit rerun only after smoke evidence is healthy

## 6) Current Validation Gate

At the time of this plan:

- the corrected `813 / 5313` materialized-source contract is implemented
- prepare-only has passed for:
  - smoke
  - full
- the corrected smoke rerun is the gating execution check before the full detached launch

## 7) Success Criteria

The rerun setup is ready for the full 144-fit launch when all of the following are true:

1. smoke roots execute successfully on the corrected source windows
2. effective `500` roots report:
   - `train_n_eval = 500`
3. posterior metric fields are populated at the fit-summary level, including:
   - `train_qtrue_*`
   - `train_pinball_tau`
   - `train_coverage`
   - `train_coverage_minus_tau`
   - `train_coverage_error`
   - posterior SD / quantile summaries
4. branch docs and trackers point to this rerun as an explicit new study contract
5. the implementation is committed and pushed before the detached full launch
