# Refreshed288 Dynamic P90 Steepertrend Dataset Sync Verification

- qdesn source root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- local validation root: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- verification rows: `27`
- all rows pass: `TRUE`
- root rows pass: `9 / 9`
- slice rows pass: `18 / 18`

## Verification summary by level
| level | n_rows | n_pass |
|---|---|---|
| root | 9 | 9 |
| slice | 18 | 18 |

## Verification detail
| level | family | tau | fit_size | n_obs_local | n_obs_ref | series_wide_match | sim_match | meta_contract_match | validation_contract_match | source_index_match | q_true_equals_mu_local | all_pass |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| root | gausmix | 0.05 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | gausmix | 0.25 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | gausmix | 0.50 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | laplace | 0.05 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | laplace | 0.25 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | laplace | 0.50 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | normal | 0.05 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | normal | 0.25 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| root | normal | 0.50 | NA | 7000 | 7000 | TRUE | TRUE | TRUE | TRUE | NA | TRUE | TRUE |
| slice | gausmix | 0.05 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | gausmix | 0.05 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | gausmix | 0.25 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | gausmix | 0.25 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | gausmix | 0.50 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | gausmix | 0.50 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | laplace | 0.05 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | laplace | 0.05 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | laplace | 0.25 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | laplace | 0.25 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | laplace | 0.50 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | laplace | 0.50 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | normal | 0.05 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | normal | 0.05 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | normal | 0.25 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | normal | 0.25 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | normal | 0.50 | 500 | 500 | 500 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
| slice | normal | 0.50 | 5000 | 5000 | 5000 | TRUE | TRUE | NA | NA | TRUE | TRUE | TRUE |
