# Q-DESN qvbm2 VB Blocker-Aware Closeout

- generated_at: `2026-07-14 21:04:42.599588`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- head: `33f8a873c9fb87db68f3f867da64ec78bcecb54e`
- orchestrator_manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/orch/qvbm2p3_full_07142049__git-33f8a87/manifest/mechanism_first_orchestrator_manifest.json`
- article_summary_read_only: `/data/jaguir26/local/src/Article-Q-DESN---Version-2/tables/qdesn_validation_tt500_final_summary.csv`
- planned_roots: `16`
- success_roots: `16`
- failed_roots: `0`
- remaining_roots: `0`
- forecast_lead_rows_successes: `480`
- storage_light_pass: `TRUE`
- known_invalid_p03_failure_only: `FALSE`
- mcmc_promote_after_review_cells: `0`

## Decision

The screen is operationally complete and storage-light. Promotion still requires the ratio gate below.

## Health

| bundle_code | planned_roots | SUCCESS | FAIL | remaining_roots | pct_terminal | pct_success | success_fit_metric_rows | forecast_lead_rows |
|---|---|---|---|---|---|---|---|---|
| c12 | 8 | 8 | 0 | 0 | 100 | 100 | 8 | 240 |
| c123 | 8 | 8 | 0 | 0 | 100 | 100 | 8 | 240 |

## Profile Status

| profile_suffix | SUCCESS |
|---|---|
| p03 | 16 |

## Invalid/Failure Ledger

Rows below are refusal rows. They are evidence of a failed exploratory surface, not valid model results.

| empty |
|---|
| no rows |

## Best Successful Candidates

| family | tau | likelihood_family | bundle_code | screening_profile_id | profile_role | train_qtrue_rmse | train_pinball_tau | forecast_qtrue_mae_lead_mean | forecast_pinball_mean_lead_mean | screen_joint_worst |
|---|---|---|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | c123 | m2p3c123_c01_p03 | check_guard_strong_shrink_safe_floor | 3.6716 | 1.4070 | 3.8170 | 1.5890 | 1.0848 |
| gausmix | 0.05 | exal | c123 | m2p3c123_c02_p03 | check_guard_strong_shrink_safe_floor | 4.5786 | 1.4647 | 4.2720 | 1.6049 | 1.0042 |
| laplace | 0.05 | al | c12 | m2p3c12_c03_p03 | check_guard_strong_shrink_safe_floor | 6.4485 | 1.6694 | 4.8935 | 1.9404 | 1.0049 |
| laplace | 0.05 | exal | c123 | m2p3c123_c04_p03 | check_guard_strong_shrink_safe_floor | 8.0017 | 1.7721 | 7.7359 | 2.0322 | 1.0000 |
| normal | 0.05 | al | c123 | m2p3c123_c05_p03 | check_guard_strong_shrink_safe_floor | 2.9038 | 1.0541 | 4.7081 | 1.1335 | 1.0241 |
| normal | 0.05 | exal | c12 | m2p3c12_c06_p03 | check_guard_strong_shrink_safe_floor | 3.1739 | 1.0773 | 3.0219 | 1.0934 | 1.0016 |
| normal | 0.50 | al | c12 | m2p3c12_c07_p03 | check_guard_strong_shrink_safe_floor | 1.5364 | 3.9620 | 2.2636 | 4.1020 | 1.0175 |
| normal | 0.50 | exal | c12 | m2p3c12_c08_p03 | check_guard_strong_shrink_safe_floor | 1.4785 | 3.9622 | 2.2115 | 4.0962 | 1.0569 |

## Baseline Ratios

| family_screen | tau_screen | likelihood_family | screening_profile_id | ratio_vs_qvbm1_fit_rmse | ratio_vs_qvbm1_fit_check | ratio_vs_qvbm1_fcst_mae | ratio_vs_qvbm1_fcst_check | ratio_vs_exdqlm_fit_rmse | ratio_vs_exdqlm_fit_check | ratio_vs_exdqlm_fcst_mae | ratio_vs_exdqlm_fcst_check | beats_qvbm1_all4 | beats_exdqlm_all4 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | m2p3c123_c01_p03 | 1.041 | 0.999 | 0.982 | 0.999 | 1.348 | 1.028 | 0.738 | 0.987 | FALSE | FALSE |
| gausmix | 0.05 | exal | m2p3c123_c02_p03 | 1.020 | 0.998 | 1.023 | 1.003 | 1.680 | 1.070 | 0.826 | 0.997 | FALSE | FALSE |
| laplace | 0.05 | al | m2p3c12_c03_p03 | 0.960 | 0.998 | 1.061 | 1.004 | 1.405 | 1.026 | 1.343 | 1.039 | FALSE | FALSE |
| laplace | 0.05 | exal | m2p3c123_c04_p03 | 0.973 | 1.004 | 1.562 | 1.057 | 1.743 | 1.089 | 2.123 | 1.088 | FALSE | FALSE |
| normal | 0.05 | al | m2p3c123_c05_p03 | 1.008 | 1.002 | 0.974 | 0.996 | 1.223 | 1.046 | 3.259 | 1.052 | FALSE | FALSE |
| normal | 0.05 | exal | m2p3c12_c06_p03 | 1.022 | 1.003 | 1.099 | 1.006 | 1.337 | 1.069 | 2.092 | 1.015 | FALSE | FALSE |
| normal | 0.50 | al | m2p3c12_c07_p03 | 1.291 | 0.996 | 1.229 | 1.011 | 0.799 | 1.025 | 2.040 | 1.020 | FALSE | FALSE |
| normal | 0.50 | exal | m2p3c12_c08_p03 | 1.236 | 0.996 | 1.200 | 1.009 | 0.769 | 1.025 | 1.994 | 1.019 | FALSE | FALSE |

## Storage Audit

| scope | files_scanned | forbidden_payloads | forbidden_bytes | status | forbidden_paths |
|---|---|---|---|---|---|
| run_roots_and_orchestrator | 577 | 0 | 0 | PASS |  |

## Next Safe Step

Run the p03 safe-floor repair as a separate non-authoritative screen. It should retain the p03 structural design but replace `rhs_tau0 = 3e-05` with the stable lower bound `rhs_tau0 = 1e-04`, using new root IDs and new run tags so the original refused qvbm2 p03 roots remain untouched.

## Output Paths

- health: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_health.csv`
- profile_status: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_profile_status.csv`
- failure_ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_invalid_failure_ledger.csv`
- fit_forecast: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_fit_forecast_summary.csv`
- ranked: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_ranked_candidates.csv`
- cell_winners: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_cell_winners.csv`
- ratio_breakdown: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_ratio_breakdown.csv`
- storage_audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_storage_audit.csv`
