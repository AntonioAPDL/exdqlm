# Q-DESN 500-Observation VB Mechanism-First Closeout

- generated_at: `2026-07-14 04:52:12.872611`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- head: `8c6eda99d9ec3c4b22a855fddf30075eee26d2e6`
- article_summary_read_only: `/data/jaguir26/local/src/Article-Q-DESN---Version-2/tables/qdesn_validation_tt500_final_summary.csv`
- qvbm1_fit_roots: `192 / 192`
- qvbm1_forecast_lead_rows: `5760 / 5760`
- all_complete: `TRUE`
- storage_light_pass: `TRUE`
- mcmc_promote_after_review_cells: `0`

## Decision

The screen is complete and storage-light, but it remains diagnostic/candidate-selection evidence. No cell clears the conservative MCMC handoff gate against both the current Q-DESN RHS same-likelihood baseline and the best exDQLM/DQLM VB baseline on all four primary metrics.

## Audit And Diagnosis

- The run is operationally closed: every configured bundle has 32 successful fits and 960 rolling-origin lead rows.
- The corrected decomposition tags are storage-light: no `.rds`, `.rda`, `.RData`, or `__design.rds` payloads were found for valid or quarantined tags.
- The useful signal is structural but not sufficient for promotion: qvbm1 winners split between `c12` and `c123`, with no wins from `sr`, `srp`, or `srx` under the joint within-screen score.
- The main scientific blocker is not completion. It is dominance: every per-cell winner fails at least one primary ratio against the current Article v2 Q-DESN RHS same-likelihood table or the best exDQLM/DQLM VB rows.
- The repeated pattern is fit-RMSE or forecast relief at the cost of check-loss and/or external-baseline forecast ratios. That makes immediate MCMC spending inefficient.

## Bundle Win Counts

| bundle | n_cell_wins |
|---|---|
| c12 | 4 |
| c123 | 4 |

## Health Summary

| bundle | tag | fit_roots | expected_fit_roots | forecast_lead_rows | expected_forecast_lead_rows | n_success | n_pass | fit_roots_remaining | forecast_lead_rows_remaining | pct_done | train_qtrue_rmse | train_pinball_tau | forecast_qtrue_mae_lead_mean | forecast_pinball_mean_lead_mean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| raw | m1rawf_07132035_90defed | 32 | 32 | 960 | 960 | 32 | 32 | 0 | 0 | 100 | 3.1906 | 1.5667 | 4.9906 | 1.9162 |
| c12 | m1c12f_07132209_8c6eda9 | 32 | 32 | 960 | 960 | 32 | 32 | 0 | 0 | 100 | 3.1906 | 1.5668 | 4.9586 | 1.9199 |
| c123 | m1c123f_07132209_8c6eda9 | 32 | 32 | 960 | 960 | 32 | 32 | 0 | 0 | 100 | 3.3466 | 1.5534 | 4.2175 | 1.8176 |
| sr | m1srf_07132209_8c6eda9 | 32 | 32 | 960 | 960 | 32 | 32 | 0 | 0 | 100 | 3.1906 | 1.5669 | 4.8986 | 1.9256 |
| srp | m1srpf_07132209_8c6eda9 | 32 | 32 | 960 | 960 | 32 | 32 | 0 | 0 | 100 | 3.1906 | 1.5669 | 4.8986 | 1.9256 |
| srx | m1srxf_07132209_8c6eda9 | 32 | 32 | 960 | 960 | 32 | 32 | 0 | 0 | 100 | 3.1906 | 1.5669 | 4.8986 | 1.9256 |

## Per-Cell qvbm1 Winners

| family | tau | likelihood_family | bundle | screening_profile_id | train_qtrue_rmse | train_pinball_tau | forecast_qtrue_mae_lead_mean | forecast_pinball_mean_lead_mean | joint_worst_ratio |
|---|---|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | c123 | m1c123_c08_p04 | 3.5280 | 1.4080 | 3.8884 | 1.5908 | 1.0976 |
| gausmix | 0.05 | exal | c123 | m1c123_c03_p04 | 4.4904 | 1.4672 | 4.1762 | 1.5995 | 1.0340 |
| laplace | 0.05 | al | c12 | m1c12_c07_p01 | 6.7167 | 1.6734 | 4.6136 | 1.9326 | 1.0529 |
| laplace | 0.05 | exal | c123 | m1c123_c01_p03 | 8.2226 | 1.7644 | 4.9512 | 1.9226 | 1.0280 |
| normal | 0.05 | al | c123 | m1c123_c04_p04 | 2.8814 | 1.0518 | 4.8321 | 1.1378 | 1.0387 |
| normal | 0.05 | exal | c12 | m1c12_c02_p04 | 3.1055 | 1.0743 | 2.7495 | 1.0872 | 1.0028 |
| normal | 0.50 | al | c12 | m1c12_c05_p04 | 1.1905 | 3.9796 | 1.8418 | 4.0575 | 1.1705 |
| normal | 0.50 | exal | c12 | m1c12_c06_p04 | 1.1966 | 3.9800 | 1.8423 | 4.0582 | 1.1545 |

## Baseline Comparison Ratios

Ratios below 1 are better than the referenced current table row. The current-table comparison is read-only and does not make this qvbm1 screen article-facing.

| family | tau | qdesn_likelihood | qvbm1_bundle | qvbm1_profile | ratio_vs_current_qdesn_rhsns_same_likelihood_fit_rmse | ratio_vs_current_qdesn_rhsns_same_likelihood_fit_check | ratio_vs_current_qdesn_rhsns_same_likelihood_fcst_mae | ratio_vs_current_qdesn_rhsns_same_likelihood_fcst_check | ratio_vs_best_exdqlm_dqlm_vb_fit_rmse | ratio_vs_best_exdqlm_dqlm_vb_fit_check | ratio_vs_best_exdqlm_dqlm_vb_fcst_mae | ratio_vs_best_exdqlm_dqlm_vb_fcst_check | mcmc_handoff_status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | c123 | m1c123_c08_p04 | 0.521 | 1.107 | 1.106 | 1.012 | 1.295 | 1.029 | 0.752 | 0.988 | HOLD_DIAGNOSTIC_ONLY |
| gausmix | 0.05 | exal | c123 | m1c123_c03_p04 | 0.777 | 1.047 | 1.297 | 1.021 | 1.648 | 1.072 | 0.808 | 0.993 | HOLD_DIAGNOSTIC_ONLY |
| laplace | 0.05 | al | c12 | m1c12_c07_p01 | 0.914 | 1.017 | 1.192 | 1.012 | 1.463 | 1.029 | 1.266 | 1.035 | HOLD_DIAGNOSTIC_ONLY |
| laplace | 0.05 | exal | c123 | m1c123_c01_p03 | 0.985 | 1.002 | 1.630 | 1.023 | 1.791 | 1.085 | 1.359 | 1.029 | HOLD_DIAGNOSTIC_ONLY |
| normal | 0.05 | al | c123 | m1c123_c04_p04 | 0.809 | 1.043 | 2.820 | 1.070 | 1.214 | 1.044 | 3.345 | 1.056 | HOLD_DIAGNOSTIC_ONLY |
| normal | 0.05 | exal | c12 | m1c12_c02_p04 | 0.864 | 1.011 | 1.104 | 1.006 | 1.308 | 1.066 | 1.903 | 1.009 | HOLD_DIAGNOSTIC_ONLY |
| normal | 0.50 | al | c12 | m1c12_c05_p04 | 0.483 | 1.039 | 0.826 | 0.989 | 0.619 | 1.029 | 1.660 | 1.009 | HOLD_DIAGNOSTIC_ONLY |
| normal | 0.50 | exal | c12 | m1c12_c06_p04 | 0.444 | 1.029 | 0.919 | 0.995 | 0.622 | 1.029 | 1.661 | 1.009 | HOLD_DIAGNOSTIC_ONLY |

## Handoff Blockers

These rows explain why the conservative MCMC handoff gate is closed. A failed primary ratio is any ratio greater than or equal to 1.

| family | tau | qdesn_likelihood | qvbm1_bundle | n_failed_primary_ratios | failed_primary_ratios | worst_ratio_name | worst_ratio |
|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | c123 | 5 | current_qdesn_fit_check;current_qdesn_fcst_mae;current_qdesn_fcst_check;exdqlm_dqlm_fit_rmse;exdqlm_dqlm_fit_check | exdqlm_dqlm_fit_rmse | 1.295 |
| gausmix | 0.05 | exal | c123 | 5 | current_qdesn_fit_check;current_qdesn_fcst_mae;current_qdesn_fcst_check;exdqlm_dqlm_fit_rmse;exdqlm_dqlm_fit_check | exdqlm_dqlm_fit_rmse | 1.648 |
| laplace | 0.05 | al | c12 | 7 | current_qdesn_fit_check;current_qdesn_fcst_mae;current_qdesn_fcst_check;exdqlm_dqlm_fit_rmse;exdqlm_dqlm_fit_check;exdqlm_dqlm_fcst_mae;exdqlm_dqlm_fcst_check | exdqlm_dqlm_fit_rmse | 1.463 |
| laplace | 0.05 | exal | c123 | 7 | current_qdesn_fit_check;current_qdesn_fcst_mae;current_qdesn_fcst_check;exdqlm_dqlm_fit_rmse;exdqlm_dqlm_fit_check;exdqlm_dqlm_fcst_mae;exdqlm_dqlm_fcst_check | exdqlm_dqlm_fit_rmse | 1.791 |
| normal | 0.05 | al | c123 | 7 | current_qdesn_fit_check;current_qdesn_fcst_mae;current_qdesn_fcst_check;exdqlm_dqlm_fit_rmse;exdqlm_dqlm_fit_check;exdqlm_dqlm_fcst_mae;exdqlm_dqlm_fcst_check | exdqlm_dqlm_fcst_mae | 3.345 |
| normal | 0.05 | exal | c12 | 7 | current_qdesn_fit_check;current_qdesn_fcst_mae;current_qdesn_fcst_check;exdqlm_dqlm_fit_rmse;exdqlm_dqlm_fit_check;exdqlm_dqlm_fcst_mae;exdqlm_dqlm_fcst_check | exdqlm_dqlm_fcst_mae | 1.903 |
| normal | 0.50 | al | c12 | 4 | current_qdesn_fit_check;exdqlm_dqlm_fit_check;exdqlm_dqlm_fcst_mae;exdqlm_dqlm_fcst_check | exdqlm_dqlm_fcst_mae | 1.660 |
| normal | 0.50 | exal | c12 | 4 | current_qdesn_fit_check;exdqlm_dqlm_fit_check;exdqlm_dqlm_fcst_mae;exdqlm_dqlm_fcst_check | exdqlm_dqlm_fcst_mae | 1.661 |

## Invalid Tags

The following old pre-guard-fix tags must not be consumed:

| bundle | invalid_tag | fit_summary_rows_found | report_roots_found | reason | consume_policy |
|---|---|---|---|---|---|
| c12 | m1c12f_07132035_90defed | 0 | 2 | aborted before guard fix: validation campaigns enforced readout.input_mode='raw_y_lags' and rejected dlm_decomp_lags | refuse |
| c123 | m1c123f_07132035_90defed | 0 | 2 | aborted before guard fix: validation campaigns enforced readout.input_mode='raw_y_lags' and rejected dlm_decomp_lags | refuse |
| sr | m1srf_07132035_90defed | 0 | 2 | aborted before guard fix: validation campaigns enforced readout.input_mode='raw_y_lags' and rejected dlm_decomp_lags | refuse |
| srp | m1srpf_07132035_90defed | 0 | 2 | aborted before guard fix: validation campaigns enforced readout.input_mode='raw_y_lags' and rejected dlm_decomp_lags | refuse |
| srx | m1srxf_07132035_90defed | 0 | 2 | aborted before guard fix: validation campaigns enforced readout.input_mode='raw_y_lags' and rejected dlm_decomp_lags | refuse |

## Output Paths

- health: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_health.csv`
- fit_forecast_summary: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_fit_forecast_summary.csv`
- ranked_candidates: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_ranked_candidates.csv`
- cell_winners: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_cell_winners.csv`
- bundle_win_counts: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_bundle_win_counts.csv`
- current_table_comparison: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_current_table_comparison.csv`
- ratio_blockers: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_ratio_blockers.csv`
- invalid_tag_ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_invalid_tag_ledger.csv`
- storage_audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_storage_audit.csv`

## Better Next Plan

1. Freeze this qvbm1 closeout as diagnostic evidence, not article-facing evidence.
2. Do not launch MCMC from qvbm1 winners yet; all eight handoff candidates fail at least one conservative primary gate.
3. Use `c12` and `c123` as mechanism priors for the next VB screen, because they are the only bundles that win cells.
4. Make the next screen case-specific and blocker-aware: preserve the structural input bundle that helped each cell, then target the failed ratio names in the blocker table.
5. Add an explicit check-loss guard to the selection criterion so fit/forecast relief cannot be bought by degrading check loss.
6. Leave Article-Q-DESN unchanged until a promoted validation artifact exists.
