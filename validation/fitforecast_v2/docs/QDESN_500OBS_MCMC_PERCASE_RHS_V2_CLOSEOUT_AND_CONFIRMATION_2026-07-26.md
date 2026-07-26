# Q-DESN 500-Observation MCMC Per-Case RHS v2 Closeout and Confirmation

## Decision

The per-case MCMC campaign is complete: all 90 planned atomic specifications
finished successfully. The campaign is closed as a screening experiment, but its
outputs are not copied directly into article tables. Promotion is performed
cell-by-cell against the frozen prelaunch ledger using the dedicated H=1000
rolling-origin summaries.

The closeout proposes nine replacements in the current Q-DESN ledger. Five cells
have comparison-eligible candidates that improve fit RMSE, H=1000 forecast MAE,
and H=1000 check loss relative to the frozen best-DQLM benchmark.

One additional candidate, Normal at tau=0.05 under exAL
(`mcvbc_060_exal`), improves all three metrics but is diagnostic-only because
gamma has ESS 145 and lag-one autocorrelation 0.983. It receives one targeted
four-seed confirmation. No other broad screen or full-study stage is authorized
by this document.

## Source Evidence

- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2`
- Run tag:
  `qdesn-tt500-mcmc-percase-rhs-v2-full-20260725__git-7df241c`
- Campaign stamp: `20260725-203156__git-7df241c`
- Planned/completed roots: `90/90`
- Signoff mix: PASS `17`, WARN `44`, FAIL `29`
- Comparison-eligible candidate rows: `61`
- Heavy binary payloads: `0`

The immutable evidence package is:

`validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726`

Its `source_manifest.csv`, `file_manifest.csv`, and JSON manifest provide hashes
for all inputs and generated tables.

## Ranking Contract

Each `family × tau × likelihood` cell is ranked by the maximum of:

1. fit-window quantile RMSE divided by the frozen best-DQLM fit RMSE;
2. H=1000 rolling-origin forecast MAE divided by the frozen best-DQLM forecast
   MAE;
3. H=1000 rolling-origin check loss divided by the frozen best-DQLM check loss.

Lower is better. H=1000 forecast metrics are read only from each root's
`forecast_horizon_summary.csv`. The legacy campaign-level forecast columns are
not used because the rolling-origin pipeline intentionally leaves them empty.

A candidate is comparison eligible only if:

- root and fit status are `SUCCESS`;
- finite and domain checks pass;
- MCMC signoff is `PASS` or `WARN`.

The current Q-DESN row is replaced only when:

- the eligible candidate improves the frozen minimax ratio by at least 0.5%; or
- the current row is `FAIL` and an eligible candidate is within 1% of its
  minimax value.

This separates three claims that must not be conflated:

- improvement over the current Q-DESN cell;
- all-primary dominance over DQLM;
- diagnostic suitability for article-facing comparison.

## Targeted Confirmation

Stage:

`qdesn_dynamic_fitforecast_v2_tt500_mcmc_normal005_exal_multiseed_v1`

The DESN design, data, source hashes, prior, likelihood, fit window, forecast
window, and MCMC kernel are frozen to the audited `mcvbc_060_exal` candidate.
Four independent MCMC seeds are run in parallel. The stage is deliberately one
root and one atomic fit specification.

Full budget per seed:

- burn-in: `5000`;
- retained iterations: `20000`;
- thinning: `1`;
- VB initialization: required;
- progress cadence: `50`;
- parallel seed workers: `4`.

Promotion requires:

- at least two of four seeds to receive PASS or WARN;
- the selected seed to receive PASS or WARN;
- the selected fit RMSE, H=1000 forecast MAE, and H=1000 check-loss ratios to
  remain below one;
- no unexpected retained `.rds`, `.rda`, or `.RData` payload.

## Launch Gates

Run these in order:

1. closeout and configuration tests;
2. prepare-only preflight;
3. tiny smoke using the one targeted atomic specification;
4. inspect smoke status and storage;
5. launch the four-seed full confirmation only if all gates pass;
6. materialize a final confirmation closeout before article integration.

The article gate remains closed until step 6. No article repository is modified
by this closeout.
