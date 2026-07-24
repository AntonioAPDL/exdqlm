# Q-DESN 500-Observation MCMC RHS Repair v1b Closeout

- Promotion id: `qdesn_tt500_mcmc_rhsrepair_v1b_closeout_20260724`
- Generated: `2026-07-24 19:24:26.997412`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Validation commit: `9a365dc68f8515ca08d1ba53b7058400c402415d`
- Run tag: `qdesn-tt500-mcmc-rhsrepair-v1b-full-20260723__git-9a365dc`
- Campaign stamp: `20260723-211348__git-9a365dc`

## Diagnosis

The v1b run is terminal and storage-light, but it is not a wholesale article-facing replacement. It is retained as diagnostic current-best candidate evidence.

- Roots: `130 / 130` terminal
- Successful roots: `110`
- Failed roots: `20`
- Clean comparison rows: `50`
- Non-promotable rows: `80`
- Diagnostic candidate promotions: `4`
- Objective-supported improvements: `2`
- Forecast-MAE-only improvements: `2`
- Heavy/binary artifacts retained: `0`

## Diagnostic Candidate Promotions

| family | tau | model_variant | v1b_candidate_id | promotion_class | current_objective | v1b_objective | delta_objective | current_H1000_mae | v1b_H1000_mae | delta_H1000_mae |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| laplace | 0.500 | qdesn_al_rhs_ns | mcrv1b_lp050a_b_d1_mem12 | diagnostic_current_best_candidate_objective_improves | 9.523 | 9.295 | -0.228 | 2.765 | 2.085 | -0.679 |
| laplace | 0.500 | qdesn_exal_rhs_ns | mcrv1b_lp050x_b_d1_mem12 | diagnostic_current_best_candidate_objective_improves | 10.150 | 9.539 | -0.610 | 3.248 | 2.254 | -0.993 |
| normal | 0.500 | qdesn_al_rhs_ns | mcrv1b_nm050a_a_current_anchor | diagnostic_forecast_mae_improvement_only | 10.556 | 10.744 | 0.188 | 3.791 | 3.424 | -0.367 |
| normal | 0.500 | qdesn_exal_rhs_ns | mcrv1b_nm050x_a_current_anchor | diagnostic_forecast_mae_improvement_only | 10.143 | 10.313 | 0.170 | 3.475 | 3.081 | -0.394 |

## Next Screen Prepared

The v1c prelaunch table is prepared but not launched. It prioritizes hard cells with no clean v1b row, cells where v1b did not improve the current best, and cells where v1b improved only one forecast metric but still needs a reference-gap review.

| priority | family | tau | model_variant | issue_class | proposed_design_family | proposed_tau0_floor | launch_status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | gausmix | 0.250 | qdesn_exal_rhs_ns | no_clean_v1b_candidate | stability_first_rhs_mcmc_repair | 1e-04 | not_launched_prepared_only |
| 2 | normal | 0.250 | qdesn_exal_rhs_ns | no_clean_v1b_candidate | stability_first_rhs_mcmc_repair | 1e-04 | not_launched_prepared_only |
| 3 | laplace | 0.500 | qdesn_al_rhs_ns | v1b_candidate_but_still_needs_reference_gap_review | confirm_reference_gap | 3e-05 | not_launched_prepared_only |
| 4 | laplace | 0.500 | qdesn_exal_rhs_ns | v1b_candidate_but_still_needs_reference_gap_review | confirm_reference_gap | 3e-05 | not_launched_prepared_only |
| 5 | normal | 0.500 | qdesn_al_rhs_ns | v1b_candidate_but_still_needs_reference_gap_review | confirm_reference_gap | 3e-05 | not_launched_prepared_only |
| 6 | normal | 0.500 | qdesn_exal_rhs_ns | v1b_candidate_but_still_needs_reference_gap_review | confirm_reference_gap | 3e-05 | not_launched_prepared_only |
| 7 | gausmix | 0.050 | qdesn_exal_rhs_ns | v1b_did_not_improve_current_best | structure_breakout_rhs_mcmc_repair | 3e-05 | not_launched_prepared_only |
| 8 | gausmix | 0.500 | qdesn_al_rhs_ns | v1b_did_not_improve_current_best | structure_breakout_rhs_mcmc_repair | 3e-05 | not_launched_prepared_only |
| 9 | gausmix | 0.500 | qdesn_exal_rhs_ns | v1b_did_not_improve_current_best | structure_breakout_rhs_mcmc_repair | 3e-05 | not_launched_prepared_only |
| 10 | normal | 0.050 | qdesn_al_rhs_ns | v1b_did_not_improve_current_best | structure_breakout_rhs_mcmc_repair | 3e-05 | not_launched_prepared_only |

## Files

- Fit summary: `qdesn_tt500_mcmc_rhsrepair_v1b_fit_summary_20260724.csv`
- Cell/model summary: `qdesn_tt500_mcmc_rhsrepair_v1b_cell_model_summary_20260724.csv`
- v1b vs current-best comparison: `qdesn_tt500_mcmc_rhsrepair_v1b_vs_current_best_20260724.csv`
- Diagnostic candidate promotions: `qdesn_tt500_mcmc_rhsrepair_v1b_diagnostic_candidate_promotions_20260724.csv`
- Non-promotable roots: `qdesn_tt500_mcmc_rhsrepair_v1b_nonpromotable_roots_20260724.csv`
- Failed roots: `qdesn_tt500_mcmc_rhsrepair_v1b_failed_roots_20260724.csv`
- Remaining hard cells: `qdesn_tt500_mcmc_rhsrepair_v1b_remaining_hard_cells_20260724.csv`
- v1c prelaunch screen plan: `qdesn_tt500_mcmc_rhsrepair_v1c_prelaunch_screen_plan_20260724.csv`
- Storage audit: `qdesn_tt500_mcmc_rhsrepair_v1b_storage_audit_20260724.csv`
- Manifest: `qdesn_tt500_mcmc_rhsrepair_v1b_closeout_manifest_20260724.json`
