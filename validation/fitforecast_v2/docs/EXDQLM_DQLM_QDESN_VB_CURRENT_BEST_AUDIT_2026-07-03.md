# exDQLM/DQLM and Q-DESN Current-Best VB Audit

Date: 2026-07-03

## Scope

This audit selects the current best exDQLM/DQLM VB row for each model/family/tau cell from the completed c11/c12/c13 targeted screen. Selection is by lead-weighted rolling-origin forecast check loss, with forecast MAE and fit RMSE used only as tie breakers.

## Inputs

- validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- validation branch: `validation/shared-fitforecast-v2-1.0.0`
- validation HEAD at audit generation: `10ef52920b8d77de9c01d05efd0db2939c70f4e6`
- validation HEAD subject: `Plan exDQLM DQLM VB promotion and targeted screen`
- shared interface: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- Article-facing summary read-only input: `/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv`
- c13 cleanup manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/prune_c13_missing_cell_fit_handoffs_20260703.csv`
- c11/c12 cleanup manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/prune_c11_c12_challenger_fit_handoffs_20260703.csv`
- storage audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/storage/storage_audit.csv`
- reproducible CSV output: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_current_best_comparison_20260703.csv`

## Evidence Counts

- current-best done/PASS cells: `18/18`
- completed c11/c12/c13 lead rows in interface: `840`
- selected candidates: `c13_trend100_season1_df0995s099=18`
- cells where Q-DESN VB still has lower forecast check: `12/18`
- cells where Q-DESN VB still has lower forecast MAE: `13/18`
- cells eligible for narrow MCMC follow-up under this audit rule: `7/18`
- cells where MCMC is not recommended without stronger VB evidence: `6/18`
- storage audit status: `PASS`
- storage audit files/bytes: `1893` / `3470817530`
- forbidden payloads in storage audit: `0`
- fit handoff GiB pruned across c13 plus c11/c12: `2.759`

## Current-Best Comparison

| Family | Tau | Model | Winner candidate | Fit RMSE | Forecast MAE | Forecast check | Q-DESN forecast check ratio | Recommendation |
| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | --- |
| gausmix | 0.05 | dqlm | c13_trend100_season1_df0995s099 | 2.725 | 5.169 | 1.610 | 1.028 | keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger |
| gausmix | 0.05 | exdqlm | c13_trend100_season1_df0995s099 | 4.615 | 9.234 | 1.895 | 1.209 | keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger |
| gausmix | 0.25 | dqlm | c13_trend100_season1_df0995s099 | 1.958 | 4.675 | 4.795 | 1.064 | keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger |
| gausmix | 0.25 | exdqlm | c13_trend100_season1_df0995s099 | 1.834 | 3.976 | 4.711 | 1.046 | keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger |
| gausmix | 0.50 | dqlm | c13_trend100_season1_df0995s099 | 1.598 | 1.840 | 5.541 | 1.018 | promote VB current-best evidence; no broad MCMC |
| gausmix | 0.50 | exdqlm | c13_trend100_season1_df0995s099 | 1.595 | 1.859 | 5.542 | 1.018 | promote VB current-best evidence; no broad MCMC |
| laplace | 0.05 | dqlm | c13_trend100_season1_df0995s099 | 4.591 | 3.644 | 1.868 | 0.994 | eligible for narrow MCMC follow-up if a matched MCMC row is required |
| laplace | 0.05 | exdqlm | c13_trend100_season1_df0995s099 | 8.498 | 9.354 | 2.146 | 1.142 | keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger |
| laplace | 0.25 | dqlm | c13_trend100_season1_df0995s099 | 2.125 | 3.123 | 4.485 | 1.014 | keep as documented VB evidence; do not spend MCMC here without a stronger VB challenger |
| laplace | 0.25 | exdqlm | c13_trend100_season1_df0995s099 | 2.145 | 2.347 | 4.427 | 1.000 | promote VB current-best evidence; no broad MCMC |
| laplace | 0.50 | dqlm | c13_trend100_season1_df0995s099 | 1.569 | 1.285 | 5.078 | 0.964 | eligible for narrow MCMC follow-up if a matched MCMC row is required |
| laplace | 0.50 | exdqlm | c13_trend100_season1_df0995s099 | 1.571 | 1.285 | 5.077 | 0.964 | eligible for narrow MCMC follow-up if a matched MCMC row is required |
| normal | 0.05 | dqlm | c13_trend100_season1_df0995s099 | 2.374 | 1.445 | 1.078 | 0.997 | eligible for narrow MCMC follow-up if a matched MCMC row is required |
| normal | 0.05 | exdqlm | c13_trend100_season1_df0995s099 | 2.708 | 3.126 | 1.156 | 1.069 | promote VB current-best evidence; no broad MCMC |
| normal | 0.25 | dqlm | c13_trend100_season1_df0995s099 | 2.404 | 2.513 | 3.371 | 1.025 | promote VB current-best evidence; no broad MCMC |
| normal | 0.25 | exdqlm | c13_trend100_season1_df0995s099 | 2.429 | 2.022 | 3.333 | 1.014 | eligible for narrow MCMC follow-up if a matched MCMC row is required |
| normal | 0.50 | dqlm | c13_trend100_season1_df0995s099 | 1.923 | 1.109 | 4.022 | 0.986 | eligible for narrow MCMC follow-up if a matched MCMC row is required |
| normal | 0.50 | exdqlm | c13_trend100_season1_df0995s099 | 1.988 | 1.125 | 4.023 | 0.986 | eligible for narrow MCMC follow-up if a matched MCMC row is required |

## Interpretation

- The targeted c11/c12/c13 VB screen now gives complete done/PASS exDQLM/DQLM evidence for all 18 fit-size-500 model/family/tau cells.
- The current-best rows should replace any mixed or stale exDQLM/DQLM VB evidence in downstream Article-facing comparison tables when those tables are regenerated.
- Q-DESN remains competitive or dominant in many cells, so this audit still does not support broad exDQLM/DQLM MCMC as the next default action.
- Narrow exDQLM/DQLM MCMC should be considered only for the cells explicitly marked eligible after Article-facing VB promotion is stable.
- Storage-light policy is preserved: successful fit-object handoffs from the c13 and c11/c12 targeted launches were pruned after forecast summaries and lead metrics were written.

## Next Recommended Action

Use the current-best CSV as the validation-side source of truth for an Article table refresh, then decide whether a small matched MCMC follow-up is worth the compute for the eligible cells only.

## Regeneration Command

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_current_best.R
```
