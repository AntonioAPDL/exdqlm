# Q-DESN 500-Observation MCMC Per-Case RHS v2 Prelaunch

- generated_at: `2026-07-25 20:23:30.720814`
- stage_file: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2`
- current per-case cells: `18`
- target MCMC atomic specs: `90`
- candidate cell-likelihoods: `18`
- source materialization manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_materialization_manifest.json`

## Intent

This is a per-case calibration handoff, not a global-specification search. Each family, quantile, and likelihood target receives its own slate of historical VB-derived candidates, and MCMC is the confirmation layer.

## Current Per-Case Disposition

| family | tau | likelihood_target | current_best_candidate_id | current_signoff_grade | current_forecast_mae_ratio_to_best_dqlm | current_fit_rmse_ratio_to_best_dqlm | action | n_mcmc_candidate_specs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gausmix | 0.05 | al | mcvbc_004_al | PASS | 0.856250922320605 | 1.19534704215487 | freeze_or_light_confirm | 5 |
| gausmix | 0.05 | exal | mcrv1c_gm005x_a_current_anchor | FAIL | 0.734957421531134 | 1.38276017786263 | tier_a_diagnostic_risk_confirmation | 5 |
| gausmix | 0.25 | al | mcvbc_018_al | FAIL | 0.576434052500252 | 0.412395635422813 | tier_a_diagnostic_risk_confirmation | 5 |
| gausmix | 0.25 | exal | mcvbc_022_exal | FAIL | 1.6097586967203 | 0.408908687492358 | tier_a_diagnostic_risk_confirmation | 5 |
| gausmix | 0.5 | al | tt500alrhs_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001 | WARN | 1.6259324099693 | 0.552263703110662 | tier_b_forecast_repair_confirmation | 5 |
| gausmix | 0.5 | exal | tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3 | WARN | 1.77173444516092 | 0.621811145570153 | tier_b_forecast_repair_confirmation | 5 |
| laplace | 0.05 | al | mcvbc_030_al | WARN | 0.480417492725004 | 1.45313858121741 | tier_b_fit_balance_confirmation | 5 |
| laplace | 0.05 | exal | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | WARN | 0.21888029006266 | 1.82123331381041 | tier_b_fit_balance_confirmation | 5 |
| laplace | 0.25 | al | mcvbc_041_al | PASS | 0.43627979282463 | 0.796408094019095 | freeze_or_light_confirm | 5 |
| laplace | 0.25 | exal | mcvbc_046_exal | WARN | 0.385021576696979 | 0.632080909693404 | freeze_or_light_confirm | 5 |
| laplace | 0.5 | al | mcrv1c_lp050a_b_d1_mem12_tau1e4_confirm | WARN | 1.55936348341747 | 0.940339038680624 | tier_b_forecast_repair_confirmation | 5 |
| laplace | 0.5 | exal | mcrv1c_lp050x_b_d1_mem12_tau1e4_confirm | WARN | 1.57332883497326 | 0.950223335378536 | tier_b_forecast_repair_confirmation | 5 |
| normal | 0.05 | al | mcvbc_015_al | WARN | 1.95305779354387 | 1.18990859127639 | tier_b_forecast_repair_confirmation | 5 |
| normal | 0.05 | exal | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | WARN | 0.692520221532784 | 0.918496045104187 | freeze_or_light_confirm | 5 |
| normal | 0.25 | al | mcvbc_060_al | PASS | 1.22793223725266 | 0.587433098313346 | freeze_or_light_confirm | 5 |
| normal | 0.25 | exal | mcvbc_063_exal | FAIL | 1.4099271454922 | 0.468890269246774 | tier_a_diagnostic_risk_confirmation | 5 |
| normal | 0.5 | al | tt500alrhs_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001 | WARN | 3.26393482748433 | 0.7613683742386 | tier_b_forecast_repair_confirmation | 5 |
| normal | 0.5 | exal | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | WARN | 2.99165600871974 | 0.744142501588073 | tier_b_forecast_repair_confirmation | 5 |

## Candidate Source Mix

| candidate_source | Freq |
| --- | --- |
| case_targeted_v51_vb | 46 |
| historical_all_primary_vb | 36 |
| qvbm1_mechanism_first_vb | 8 |

## Launch Gate

- Full MCMC confirmation uses `init_from_vb = TRUE`, `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`, `progress_every = 50`.
- Outputs stay storage-light: no retained routine draws, forecast objects, or failure `.rds` payloads.
- Article-facing promotion is blocked until the full run completes and a strict closeout chooses per-case winners.

- candidate inventory: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_candidate_inventory_20260725.csv`
- current per-case ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_current_percase_ledger_20260725.csv`
- prelaunch plan: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_plan_20260725.csv`
- summary: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_summary_20260725.csv`
- file manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_percase_rhs_v2_prelaunch_20260725/file_manifest.csv`
