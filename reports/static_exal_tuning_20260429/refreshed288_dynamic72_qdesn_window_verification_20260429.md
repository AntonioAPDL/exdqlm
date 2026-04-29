# Dynamic 72 Q-DESN Window Verification

- Timestamp: `2026-04-29 19:29:57 EDT`
- Run tag: `20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin`
- Branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- Git SHA: `65ecd871d619`
- Scenario: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- Validation registry: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260422_dynamic_p90_steepertrend_v1.csv`
- Q-DESN staged source root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_main_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

## Contract

- The 0.4.0 validation relaunch uses only canonical `fit_input_lastTT500` and `fit_input_lastTT5000` windows.
- Q-DESN uses staged source windows of length `813` and `5313`; only their final `500` or `5000` rows are effective after washout.
- DQLM/exDQLM must not receive the Q-DESN washout prefix as extra fitting data.
- The quantile truth convention is `q_true = mu`, represented in these CSVs as `q_target = mu`.

## Result

| status | n |
| --- | --- |
| pass | 18 |

## Pass Counts By Fit Size

| fit_size | rows | total | pct_pass |
| --- | --- | --- | --- |
| 500 | 9 | 9 | 100 |
| 5000 | 9 | 9 | 100 |

## Pass Counts By Family

| family | rows | total | pct_pass |
| --- | --- | --- | --- |
| gausmix | 6 | 6 | 100 |
| laplace | 6 | 6 | 100 |
| normal | 6 | 6 | 100 |

## Numeric Tolerances

- Max allowed absolute numeric difference: `1e-10`
- Observed max numeric absolute difference: `0`
- Observed max canonical `abs(q_target - mu)`: `0`
- Observed max Q-DESN-tail `abs(q_target - mu)`: `0`

## Detailed CSV

- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260429/refreshed288_dynamic72_qdesn_window_verification_20260429.csv`
