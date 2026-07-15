# Q-DESN qvbm2 VB Blocker-Aware Closeout

- generated_at: `2026-07-14 20:42:29.753198`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- head: `33f8a873c9fb87db68f3f867da64ec78bcecb54e`
- orchestrator_manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/orch/qvbm2_blocker_aware_20260714__git-33f8a87/manifest/mechanism_first_orchestrator_manifest.json`
- article_summary_read_only: `/data/jaguir26/local/src/Article-Q-DESN---Version-2/tables/qdesn_validation_tt500_final_summary.csv`
- planned_roots: `128`
- success_roots: `112`
- failed_roots: `16`
- remaining_roots: `0`
- forecast_lead_rows_successes: `3360`
- storage_light_pass: `TRUE`
- known_invalid_p03_failure_only: `TRUE`
- mcmc_promote_after_review_cells: `0`

## Decision

qvbm2 is operationally closed but not MCMC-promotable. The only failed roots are the p03 tiny-RHS-tau surface; they are explicitly refused and must not be consumed. Successful candidates mostly reproduce qvbm1-level evidence rather than clearing the conservative dominance gate.

## Health

| bundle_code | planned_roots | SUCCESS | FAIL | remaining_roots | pct_terminal | pct_success | success_fit_metric_rows | forecast_lead_rows |
|---|---|---|---|---|---|---|---|---|
| c12 | 64 | 56 | 8 | 0 | 100 | 87.5 | 56 | 1680 |
| c123 | 64 | 56 | 8 | 0 | 100 | 87.5 | 56 | 1680 |

## Profile Status

| profile_suffix | SUCCESS | FAIL |
|---|---|---|
| p01 | 16 | 0 |
| p02 | 16 | 0 |
| p03 | 0 | 16 |
| p04 | 16 | 0 |
| p05 | 16 | 0 |
| p06 | 16 | 0 |
| p07 | 16 | 0 |
| p08 | 16 | 0 |

## Invalid/Failure Ledger

Rows below are refusal rows. They are evidence of a failed exploratory surface, not valid model results.

| bundle_code | run_tag | screening_profile_id | profile_suffix | root_status | failure_class | consume_policy | error_signature |
|---|---|---|---|---|---|---|---|
| c12 | m2c12f_07140521_33f8a87 | m2c12_c01_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c02_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c03_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c04_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c05_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c06_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c07_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c12 | m2c12f_07140521_33f8a87 | m2c12_c08_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c01_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c02_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c03_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c04_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c05_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c06_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c07_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |
| c123 | m2c123f_07140521_33f8a87 | m2c123_c08_p03 | p03 | FAIL | invalid_rhs_tau0_tiny_surface | refuse | Error: RHS_NS hypers$tau0 must be > 0. / Execution halted |

## Best Successful Candidates

| family | tau | likelihood_family | bundle_code | screening_profile_id | profile_role | train_qtrue_rmse | train_pinball_tau | forecast_qtrue_mae_lead_mean | forecast_pinball_mean_lead_mean | screen_joint_worst |
|---|---|---|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | c123 | m2c123_c01_p01 | anchor_tail_guard | 3.5280 | 1.4080 | 3.8884 | 1.5908 | 1.0976 |
| gausmix | 0.05 | exal | c123 | m2c123_c02_p01 | anchor_tail_guard | 4.4904 | 1.4672 | 4.1762 | 1.5995 | 1.0181 |
| laplace | 0.05 | al | c12 | m2c12_c03_p04 | rmse_balanced_low_memory | 6.7163 | 1.6731 | 4.5487 | 1.9278 | 1.0529 |
| laplace | 0.05 | exal | c123 | m2c123_c04_p01 | anchor_tail_guard | 8.0210 | 1.7709 | 7.5349 | 2.0221 | 1.0111 |
| normal | 0.05 | al | c123 | m2c123_c05_p08 | period_aligned_two_layer | 2.8647 | 1.0504 | 4.8263 | 1.1374 | 1.0225 |
| normal | 0.05 | exal | c12 | m2c12_c06_p02 | check_guard_sparse | 3.1187 | 1.0747 | 2.7108 | 1.0874 | 1.0043 |
| normal | 0.50 | al | c12 | m2c12_c07_p02 | check_guard_sparse | 1.1784 | 3.9800 | 1.8000 | 4.0517 | 1.1217 |
| normal | 0.50 | exal | c12 | m2c12_c08_p02 | check_guard_sparse | 1.1847 | 3.9805 | 1.8044 | 4.0528 | 1.1247 |

## Baseline Ratios

| family_screen | tau_screen | likelihood_family | screening_profile_id | ratio_vs_qvbm1_fit_rmse | ratio_vs_qvbm1_fit_check | ratio_vs_qvbm1_fcst_mae | ratio_vs_qvbm1_fcst_check | ratio_vs_exdqlm_fit_rmse | ratio_vs_exdqlm_fit_check | ratio_vs_exdqlm_fcst_mae | ratio_vs_exdqlm_fcst_check | beats_qvbm1_all4 | beats_exdqlm_all4 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | m2c123_c01_p01 | 1.000 | 1.000 | 1.000 | 1.000 | 1.295 | 1.029 | 0.752 | 0.988 | FALSE | FALSE |
| gausmix | 0.05 | exal | m2c123_c02_p01 | 1.000 | 1.000 | 1.000 | 1.000 | 1.648 | 1.072 | 0.808 | 0.993 | FALSE | FALSE |
| laplace | 0.05 | al | m2c12_c03_p04 | 1.000 | 1.000 | 0.986 | 0.998 | 1.463 | 1.029 | 1.248 | 1.032 | TRUE | FALSE |
| laplace | 0.05 | exal | m2c123_c04_p01 | 0.975 | 1.004 | 1.522 | 1.052 | 1.747 | 1.089 | 2.068 | 1.082 | FALSE | FALSE |
| normal | 0.05 | al | m2c123_c05_p08 | 0.994 | 0.999 | 0.999 | 1.000 | 1.207 | 1.043 | 3.341 | 1.055 | TRUE | FALSE |
| normal | 0.05 | exal | m2c12_c06_p02 | 1.004 | 1.000 | 0.986 | 1.000 | 1.313 | 1.067 | 1.876 | 1.009 | FALSE | FALSE |
| normal | 0.50 | al | m2c12_c07_p02 | 0.990 | 1.000 | 0.977 | 0.999 | 0.613 | 1.029 | 1.623 | 1.007 | FALSE | FALSE |
| normal | 0.50 | exal | m2c12_c08_p02 | 0.990 | 1.000 | 0.979 | 0.999 | 0.616 | 1.030 | 1.627 | 1.008 | FALSE | FALSE |

## Storage Audit

| scope | files_scanned | forbidden_payloads | forbidden_bytes | status | forbidden_paths |
|---|---|---|---|---|---|
| run_roots_and_orchestrator | 4337 | 0 | 0 | PASS |  |

## Next Safe Step

Run the p03 safe-floor repair as a separate non-authoritative screen. It should retain the p03 structural design but replace `rhs_tau0 = 3e-05` with the stable lower bound `rhs_tau0 = 1e-04`, using new root IDs and new run tags so the original refused qvbm2 p03 roots remain untouched.

## Output Paths

- health: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_health.csv`
- profile_status: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_profile_status.csv`
- failure_ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_invalid_failure_ledger.csv`
- fit_forecast: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_fit_forecast_summary.csv`
- ranked: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_ranked_candidates.csv`
- cell_winners: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_cell_winners.csv`
- ratio_breakdown: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_ratio_breakdown.csv`
- storage_audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_storage_audit.csv`
