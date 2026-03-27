# TRACK: QDESN rhs vs rhs_ns Median Validation (Toy Static Study)

Date: 2026-03-27  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static simulation/validation only (no benchmark pipeline)

## 1) Objective

Run a focused, reproducible `tau=0.5` toy validation comparison where `rhs` and `rhs_ns` are first-class options for both VB and MCMC in the same qdesn validation workflow, with:

1. forecast performance,
2. toy signal-recovery performance,
3. runtime,
4. health/signoff/collapse diagnostics.

## 2) Run Identity And Artifacts

- Campaign run tag: `20260327-104735__git-2acd278`
- Results root:
  - `results/qdesn_mcmc_validation/rhs_vs_rhs_ns_median/20260327-104735__git-2acd278`
- Reports root:
  - `reports/qdesn_mcmc_validation/rhs_vs_rhs_ns_median/20260327-104735__git-2acd278`
- Comparison summary:
  - `reports/qdesn_mcmc_validation/rhs_vs_rhs_ns_median/20260327-104735__git-2acd278/rhs_vs_rhsns_median_summary.md`
- Key comparison tables:
  - `.../tables/rhs_vs_rhsns_forecast_metrics.csv`
  - `.../tables/rhs_vs_rhsns_signal_recovery.csv`
  - `.../tables/rhs_vs_rhsns_runtime_health.csv`
  - `.../tables/rhs_vs_rhsns_method_deltas.csv`
  - `.../tables/rhs_vs_rhsns_baseline_refs.csv`

## 3) Experimental Setup

- Dataset/scenario: `toy_sine_small` (existing small toy scenario)
- Quantile: `tau = 0.5`
- Seed: `123`
- Reservoir profile: `tiny_d1_n8`
- Priors compared: `rhs`, `rhs_ns`
- Methods compared: `vb`, `mcmc`
- Non-DLM contract preserved:
  - `readout.input_mode = raw_y_lags`
  - `decomposition.enabled = false`
- Collapse guardrails active for both priors, including rhs-family diagnostics/signoff path.

## 4) Main Outcomes

### 4.1 Forecast/Signal Quality (qhat metrics)

- VB:
  - `rhs` slightly better than `rhs_ns` on this single toy root (`qhat_rmse`: `0.056` vs `0.058`).
- MCMC:
  - `rhs` slightly better than `rhs_ns` on this single toy root (`qhat_rmse`: `0.051` vs `0.053`).
- Signal correlations were very close and high for all fits (`~0.995` to `~0.996`).

Note:
- `CRPS` and synthesis `S` are `NA` by design in this run because this is a single-quantile (`p_vec` length 1) setup; synthesis scoring is disabled in that mode.

### 4.2 Runtime

- VB runtime ratio (`rhs_ns / rhs`): `0.772` (rhs_ns faster).
- MCMC runtime ratio (`rhs_ns / rhs`): `0.242` (rhs_ns much faster).

### 4.3 Health And Collapse

- All 4 method fits finished with `status=SUCCESS`.
- `rhs_diag_available=TRUE` for all 4 fits (critical gap fixed).
- No collapse flags for any fit:
  - `rhs_collapse_flag=FALSE`
  - `rhs_collapse_flag_bound=FALSE`
  - `rhs_collapse_flag_shrink=FALSE`
- `unhealthy=FALSE` for all fits.

### 4.4 Signoff

- VB:
  - `rhs`: `WARN` (`vb_converged_false`)
  - `rhs_ns`: `PASS` (`vb_converged; stable_tail`)
- MCMC:
  - `rhs`: `FAIL` (`geweke_drift`)
  - `rhs_ns`: `FAIL` (`geweke_drift`)

Interpretation:
- The rhs_ns diagnostics-missing blocker is resolved.
- Remaining MCMC signoff issue is chain drift/mixing quality, not collapse nor missing diagnostics.

## 5) Decision Status

Current status: **integration-ready for rhs/rhs_ns switching in static validation pipeline**, with **MCMC tuning still required for signoff-grade stability** in this toy median profile.

Immediate recommendation:

1. Keep this run as the frozen integration evidence baseline for rhs vs rhs_ns.
2. Use this as the launch point for next MCMC tuning wave (same toy root, same seed, same contract), now that diagnostics parity and collapse guardrails are in place for rhs_ns.
