# Q-DESN 500-Observation MCMC RHS Repair v1b Closeout and v1c Plan

Status: v1b closed out as diagnostic evidence; v1c prepared but not launched.

## Evidence Roots

- Validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Closeout commit at generation time: `9a365dc68f8515ca08d1ba53b7058400c402415d`
- v1b run tag: `qdesn-tt500-mcmc-rhsrepair-v1b-full-20260723__git-9a365dc`
- v1b results root: `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b/qdesn-tt500-mcmc-rhsrepair-v1b-full-20260723__git-9a365dc/20260723-211348__git-9a365dc`
- v1b report root: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b/qdesn-tt500-mcmc-rhsrepair-v1b-full-20260723__git-9a365dc/20260723-211348__git-9a365dc`
- Closeout bundle: `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_rhsrepair_v1b_closeout_20260724`

## Diagnosis

The v1b campaign completed operationally. There are no active v1b workers and no
roots left waiting to finish. The scientific closeout is mixed:

- 130/130 planned roots reached a terminal state.
- 110 roots succeeded.
- 20 roots failed and are marked non-promotable.
- 50 roots are clean comparison rows under the current PASS/WARN plus
  `comparison_eligible == TRUE` rule.
- 80 roots are non-promotable because they either failed or tripped strict MCMC
  diagnostics, primarily high autocorrelation.
- The run retained no `.rds`, `.rda`, or `.RData` payloads under the full v1b
  results root.

The campaign is therefore useful for calibration and for a small diagnostic
candidate update, but it is not a wholesale replacement for the current
article-facing 500-observation MCMC comparison table.

## Promotion Decision

Selection follows the current Q-DESN/DQLM MCMC convention:

1. keep only clean rows with `comparison_eligible == TRUE` and PASS/WARN
   signoff;
2. compare against the July 23 current-best Q-DESN row for the same
   family, quantile, and model variant;
3. use `fit RMSE + H1000 RMSE + H1000 check loss` as the primary objective;
4. separately mark rows that improve H1000 forecast MAE but not the full
   objective.

The closeout records four diagnostic current-best candidates:

- Objective-supported improvements:
  - Laplace, tau 0.50, Q-DESN AL RHS: `mcrv1b_lp050a_b_d1_mem12`
  - Laplace, tau 0.50, exQ-DESN exAL RHS: `mcrv1b_lp050x_b_d1_mem12`
- Forecast-MAE-only improvements:
  - Normal, tau 0.50, Q-DESN AL RHS: `mcrv1b_nm050a_a_current_anchor`
  - Normal, tau 0.50, exQ-DESN exAL RHS: `mcrv1b_nm050x_a_current_anchor`

These rows are diagnostic candidates only. They should not update article tables
until the current-best MCMC materializer is intentionally refreshed and the
reference-gap decision is made.

## Non-Promotable Evidence

The failed roots and diagnostic-failed roots are explicitly retained:

- Failed roots: `qdesn_tt500_mcmc_rhsrepair_v1b_failed_roots_20260724.csv`
- All non-promotable rows: `qdesn_tt500_mcmc_rhsrepair_v1b_nonpromotable_roots_20260724.csv`

This protects the campaign from accidental cherry-picking. No row with failed
root status, failed fit status, `signoff_grade == FAIL`, or
`comparison_eligible != TRUE` is eligible for clean promotion.

## v1c Prelaunch Plan

The prepared v1c plan is:

`qdesn_tt500_mcmc_rhsrepair_v1c_prelaunch_screen_plan_20260724.csv`

It contains 10 family/quantile/model targets, grouped as follows:

- No clean v1b candidate:
  - Gausmix tau 0.25 exQ-DESN RHS
  - Normal tau 0.25 exQ-DESN RHS
- v1b candidate exists but needs reference-gap review:
  - Laplace tau 0.50 Q-DESN RHS
  - Laplace tau 0.50 exQ-DESN RHS
  - Normal tau 0.50 Q-DESN RHS
  - Normal tau 0.50 exQ-DESN RHS
- v1b did not improve the current best:
  - Gausmix tau 0.05 exQ-DESN RHS
  - Gausmix tau 0.50 Q-DESN RHS
  - Gausmix tau 0.50 exQ-DESN RHS
  - Normal tau 0.05 Q-DESN RHS

Recommended v1c rule: first run a small multichain smoke/preflight on the
stability-first cells, with a `rhs_tau0` floor of at least `1e-4` for the
previous no-clean cells. Do not relaunch the exact failed low-tau/small-diagnostic
surface without first confirming that chain diagnostics are produced and captured.

## Reproducibility Commands

Regenerate the v1b closeout:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript validation/fitforecast_v2/scripts/materialize_qdesn_tt500_mcmc_rhsrepair_v1b_closeout.R
```

Run the closeout regression test:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript -e 'testthat::test_file("validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-rhsrepair-v1b-closeout.R")'
```

## Prepared, Not Launched

No v1c launch was started by this closeout. The next launch should be a separate
explicit decision after reviewing the prepared plan and choosing whether to
prioritize stability repair, structural breakout, or reference-gap confirmation.
