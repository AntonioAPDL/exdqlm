# Q-DESN 500-Observation MCMC RHS Repair v1c Status-Agnostic Closeout

- Promotion id: `qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725`
- Generated: `2026-07-25 19:30:24.543859`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Validation commit: `79931ca0eb2c15dfe8afdf35f15a7af3fe35344e`
- Run tag: `qdesn-tt500-mcmc-rhsrepair-v1c-full-20260724-194917__git-79931ca`
- Campaign stamp: `20260724-195157__git-79931ca`
- Source registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

## Policy

This closeout follows the requested status-agnostic diagnostic policy: signoff is not used as a hard exclusion for metric-promotion evidence. The signoff grade and reason are retained in every output table, and diagnostic failures are not hidden.

Two promotion concepts are recorded:

1. Metric promotions: v1c best same-variant rows that improve at least one registered metric relative to the previous same family/tau/model variant best.
2. Status-agnostic current-best rows: winners after appending v1c candidates and selecting by the registered objective.

## Summary

- v1c roots: `110`
- v1c successful roots: `110`
- v1c signoff mix: PASS `0`, WARN `57`, FAIL `53`
- Same-variant cells checked: `10`
- Metric promotions: `5`
- Objective promotions: `3`
- All-primary metric promotions: `0`
- New same-variant winners from v1c: `3`
- New global cell winners from v1c: `0`
- Targeted follow-up rows prepared: `15`
- Heavy/binary artifacts retained: `0`

## Status-Agnostic Metric Promotions

| family | tau | model_variant | candidate_id_v1c | signoff_grade_v1c | promotion_class | objective_delta | fit_rmse_delta | forecast_mae_delta | forecast_check_delta |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gausmix | 0.050 | qdesn_exal_rhs_ns | mcrv1c_gm005x_a_current_anchor | FAIL | status_agnostic_objective_improved | -0.107 | 0.017 | -0.069 | -0.002 |
| gausmix | 0.250 | qdesn_exal_rhs_ns | mcrv1c_gm025x_a_current_anchor | FAIL | status_agnostic_metric_only_improved | 0.020 | 0.057 | -0.059 | -0.008 |
| laplace | 0.500 | qdesn_al_rhs_ns | mcrv1c_lp050a_b_d1_mem12_tau1e4_confirm | WARN | status_agnostic_objective_improved | -0.228 | 0.452 | -0.679 | -0.122 |
| laplace | 0.500 | qdesn_exal_rhs_ns | mcrv1c_lp050x_b_d1_mem12_tau1e4_confirm | WARN | status_agnostic_objective_improved | -0.793 | 0.423 | -1.143 | -0.189 |
| normal | 0.500 | qdesn_al_rhs_ns | mcrv1c_nm050a_a_current_anchor | WARN | status_agnostic_metric_only_improved | 0.188 | 0.492 | -0.367 | -0.062 |

## Targeted Follow-Up Prepared

| priority | family | tau | model_variant | signoff_grade | largest_blocker | objective_gap_vs_cell_winner | proposed_followup_family | proposed_first_step | launch_status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | normal | 0.050 | qdesn_al_rhs_ns | WARN | forecast_mae | 5.940 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 2 | gausmix | 0.250 | qdesn_exal_rhs_ns | FAIL | forecast_mae | 2.975 | mcmc_mixing_confirmation_for_metric_winner | rerun_current_metric_winner_with_multiseed_longer_chain_before_new_structure | not_launched_prepared_only |
| 3 | normal | 0.500 | qdesn_al_rhs_ns | WARN | forecast_mae | 2.559 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 4 | normal | 0.500 | qdesn_exal_rhs_ns | WARN | forecast_mae | 2.146 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 5 | laplace | 0.050 | qdesn_al_rhs_ns | WARN | forecast_mae | 2.024 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 6 | laplace | 0.500 | qdesn_exal_rhs_ns | WARN | forecast_mae | 0.812 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 7 | laplace | 0.500 | qdesn_al_rhs_ns | WARN | forecast_mae | 0.750 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 8 | gausmix | 0.500 | qdesn_exal_rhs_ns | WARN | forecast_mae | 0.703 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 9 | laplace | 0.250 | qdesn_al_rhs_ns | PASS | fit_rmse | 0.645 | fit_rmse_oriented_compact_rhs_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 10 | gausmix | 0.050 | qdesn_exal_rhs_ns | FAIL | fit_rmse | 0.241 | mcmc_mixing_confirmation_for_metric_winner | rerun_current_metric_winner_with_multiseed_longer_chain_before_new_structure | not_launched_prepared_only |
| 11 | gausmix | 0.500 | qdesn_al_rhs_ns | WARN | forecast_mae | 0.209 | forecast_mae_oriented_memory_rho_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 12 | normal | 0.250 | qdesn_al_rhs_ns | PASS | fit_rmse | 0.154 | fit_rmse_oriented_compact_rhs_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 13 | gausmix | 0.050 | qdesn_al_rhs_ns | PASS | fit_rmse | 0.140 | fit_rmse_oriented_compact_rhs_screen | small_case_specific_vb_or_short_mcmc_screen_around_current_best | not_launched_prepared_only |
| 14 | gausmix | 0.250 | qdesn_al_rhs_ns | FAIL | fit_rmse | 0.000 | mcmc_mixing_confirmation_for_metric_winner | rerun_current_metric_winner_with_multiseed_longer_chain_before_new_structure | not_launched_prepared_only |
| 15 | normal | 0.250 | qdesn_exal_rhs_ns | FAIL | fit_rmse | 0.000 | mcmc_mixing_confirmation_for_metric_winner | rerun_current_metric_winner_with_multiseed_longer_chain_before_new_structure | not_launched_prepared_only |

## Files

- Standardized v1c candidates: `qdesn_tt500_mcmc_rhsrepair_v1c_standardized_candidates_20260725.csv`
- v1c vs previous comparison: `qdesn_tt500_mcmc_rhsrepair_v1c_vs_previous_status_agnostic_20260725.csv`
- Status-agnostic metric promotions: `qdesn_tt500_mcmc_rhsrepair_v1c_metric_promotions_status_agnostic_20260725.csv`
- Status-agnostic objective promotions: `qdesn_tt500_mcmc_rhsrepair_v1c_objective_promotions_status_agnostic_20260725.csv`
- Status-agnostic all candidates: `qdesn_dqlm_500obs_mcmc_status_agnostic_all_candidates_20260725.csv`
- Same-variant current-best winners: `qdesn_dqlm_500obs_mcmc_status_agnostic_same_variant_winners_20260725.csv`
- Global cell winners: `qdesn_dqlm_500obs_mcmc_status_agnostic_cell_winners_20260725.csv`
- Article-table snapshot: `qdesn_dqlm_500obs_mcmc_status_agnostic_article_table_snapshot_20260725.csv`
- Targeted follow-up plan: `qdesn_tt500_mcmc_rhsrepair_v1c_targeted_followup_plan_20260725.csv`
- Storage audit: `qdesn_tt500_mcmc_rhsrepair_v1c_storage_audit_20260725.csv`
- Manifest: `qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_manifest_20260725.json`
