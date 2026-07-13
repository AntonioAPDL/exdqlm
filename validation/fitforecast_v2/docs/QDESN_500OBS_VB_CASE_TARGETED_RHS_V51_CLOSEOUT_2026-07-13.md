# Q-DESN RHS VB v5.1 Closeout

- generated_at: `2026-07-13 16:15:06.485223`
- report_root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51/qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8/20260713-002045__git-a2f11f8`
- summary_csv: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51/qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8/20260713-002045__git-a2f11f8/posthoc_v51_closeout/tables/qdesn_tt500_vb_rhs_v51_closeout_summary.csv`
- cell_feasibility_csv: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51/qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8/20260713-002045__git-a2f11f8/posthoc_v51_closeout/tables/qdesn_tt500_vb_rhs_v51_cell_feasibility_closeout.csv`
- failed_candidates_csv: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51/qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8/20260713-002045__git-a2f11f8/posthoc_v51_closeout/tables/qdesn_tt500_vb_rhs_v51_failed_candidates.csv`

## Health

| expected_roots | observed_roots | n_success | n_fail | strict_ready | success_contract_pass | ranking_contract_pass | dominance_passes | forbidden_heavy_file_count |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 520.00 | 520.00 | 517.00 | 3.0000 | TRUE | TRUE | TRUE | 0 | 0 |

## Decision

- v5.1 is mechanically closed out and strict-ready under the screening contract because failed exploratory candidates were allowed.
- v5.1 has zero all-primary dominance winners and is not MCMC-promotable.
- The failures are confined to three gausmix tau=0.05 candidate roots, yielding six failed VB fit rows across AL and exAL, all on the same tiny RHS tau0 surface; the current code path now preserves 3e-05 and explicitly rejects nonpositive tau0 before compute.
- Article-facing tables should not be updated from v5.1 as improved evidence; it is diagnostic/negative calibration evidence.

## Cell Feasibility

| family | tau | best_joint_worst_ratio | best_joint_blockers | min_forecast_mae_ratio | min_forecast_check_ratio | min_fit_rmse_ratio | min_fit_check_ratio | metricwise_blockers | feasibility_class | next_screen_recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gausmix | 0.050000 | 1.3953 | fit_rmse;fit_check | 0.73294 | 0.95258 | 1.3953 | 0.87813 | fit_rmse | metricwise_hard_infeasible_current_rhs | stop_rhs_local_retuning_change_design_family |
| gausmix | 0.25000 | 1.0535 | fit_check | 0.44389 | 0.95350 | 0.83230 | 1.0133 | fit_check | metricwise_near_infeasible_current_rhs | only_if_new_design_axis_targets_metricwise_blocker |
| gausmix | 0.50000 | 1.0361 | forecast_mae;fit_check | 0.52058 | 0.98175 | 0.58174 | 1.0180 | fit_check | metricwise_near_infeasible_current_rhs | only_if_new_design_axis_targets_metricwise_blocker |
| laplace | 0.050000 | 1.6955 | forecast_mae;forecast_check;fit_rmse;fit_check | 0.97833 | 1.0160 | 1.5718 | 0.95556 | forecast_check;fit_rmse | metricwise_hard_infeasible_current_rhs | stop_rhs_local_retuning_change_design_family |
| laplace | 0.25000 | 1.0387 | fit_check | 0.63054 | 0.98838 | 0.91650 | 1.0119 | fit_check | metricwise_near_infeasible_current_rhs | only_if_new_design_axis_targets_metricwise_blocker |
| laplace | 0.50000 | 1.0343 | fit_check | 0.60405 | 0.98767 | 0.78233 | 1.0230 | fit_check | metricwise_near_infeasible_current_rhs | only_if_new_design_axis_targets_metricwise_blocker |
| normal | 0.050000 | 1.5364 | forecast_mae;fit_rmse;fit_check | 1.4551 | 0.99460 | 1.2455 | 0.96404 | forecast_mae;fit_rmse | metricwise_hard_infeasible_current_rhs | stop_rhs_local_retuning_change_design_family |
| normal | 0.25000 | 1.0313 | fit_check | 0.86898 | 0.98101 | 0.77033 | 0.96595 | none | metricwise_feasible_joint_near | small_bridge_only |
| normal | 0.50000 | 1.4950 | forecast_mae;forecast_check;fit_check | 1.4950 | 1.0022 | 0.61806 | 0.96313 | forecast_mae;forecast_check | metricwise_hard_infeasible_current_rhs | stop_rhs_local_retuning_change_design_family |

## Better Plan

1. Freeze v5.1 as negative diagnostic evidence; do not promote any v5.1 row to MCMC.
2. Keep the new tau0 precision guards in the dynamic grid, root-spec, and static fit-request path.
3. For metricwise-feasible cells, run only small bridge screens that combine the best metric-specific profiles; do not broaden all axes at once.
4. For metricwise-infeasible cells, stop local RHS-only retuning unless the next design introduces a new axis that targets the actual blocker.
5. Require a fresh strict-audited all-primary VB dominance winner before MCMC promotion.
6. Keep storage-light policy unchanged: metrics, compact paths, manifests, logs, and status only; no routine successful R payload retention.

## Failed Candidate Rows

| root_id | family | tau | likelihood_family | screening_profile_id | profile_role | rhs_tau0 | status | signoff_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_case_gausmix_tau0p05_short_memory_rescue_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | gausmix | 0.050000 | al | tt500vb_case_gausmix_tau0p05_short_memory_rescue_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | short_memory_rescue | 0.000030000 | FAIL | status_not_success; non_finite_fit; domain_violation; short_trace |
| root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_case_gausmix_tau0p05_short_memory_rescue_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | gausmix | 0.050000 | exal | tt500vb_case_gausmix_tau0p05_short_memory_rescue_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | short_memory_rescue | 0.000030000 | FAIL | status_not_success; non_finite_fit; domain_violation; short_trace |
| root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | gausmix | 0.050000 | al | tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | structural_bridge | 0.000030000 | FAIL | status_not_success; non_finite_fit; domain_violation; short_trace |
| root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | gausmix | 0.050000 | exal | tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p00025_pin0p015_tau0p00003_s123 | structural_bridge | 0.000030000 | FAIL | status_not_success; non_finite_fit; domain_violation; short_trace |
| root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p0005_pin0p02_tau0p00003_s123 | gausmix | 0.050000 | al | tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p0005_pin0p02_tau0p00003_s123 | structural_bridge | 0.000030000 | FAIL | status_not_success; non_finite_fit; domain_violation; short_trace |
| root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p0005_pin0p02_tau0p00003_s123 | gausmix | 0.050000 | exal | tt500vb_case_gausmix_tau0p05_structural_bridge_d1_n8_a0p0005_r0p35_m1_rl0_pw0p0005_pin0p02_tau0p00003_s123 | structural_bridge | 0.000030000 | FAIL | status_not_success; non_finite_fit; domain_violation; short_trace |
