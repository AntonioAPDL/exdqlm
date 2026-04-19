# Refreshed288 Runtime-Failure Primary Rerun Plan

Generated: `2026-04-18 19:14:57 EDT`

- run tag: `refreshed288_paperaligned_20260418_runtimefail_v1`
- variant tag: `refreshed288_0p50_ldvb_slice_runtimewarmup_v1`
- source canonical run: `20260417_canonical_v1`
- source runtime-failure rows: `20`

## Stage Counts

| phase | rows |
|---|---|
| runtime_vb_primary |  1 |
| runtime_mcmc_pilot |  3 |
| runtime_mcmc_full | 16 |

## Pilot Rows

| row_id | family | tau_label | fit_size | model | source_runtime_mode |
|---|---|---|---|---|---|
|  6 | gausmix | 0p05 | 5000 | dqlm | invalid_pre_chi |
|  8 | gausmix | 0p05 | 5000 | exdqlm | nonfinite_chi |
| 12 | gausmix | 0p25 |  500 | exdqlm | ldvb_q_t1_na |

## Direct VB Rows

| row_id | family | tau_label | fit_size | model | source_runtime_mode |
|---|---|---|---|---|---|
| 11 | gausmix | 0p25 | 500 | exdqlm | ldvb_q_t1_na |

## Full MCMC Follow-On Rows

| row_id | family | tau_label | fit_size | model | source_runtime_mode |
|---|---|---|---|---|---|
| 14 | gausmix | 0p25 | 5000 | dqlm | invalid_pre_chi |
| 16 | gausmix | 0p25 | 5000 | exdqlm | nonfinite_chi |
| 22 | gausmix | 0p50 | 5000 | dqlm | invalid_pre_chi |
| 24 | gausmix | 0p50 | 5000 | exdqlm | nonfinite_chi |
| 30 | laplace | 0p05 | 5000 | dqlm | invalid_pre_chi |
| 32 | laplace | 0p05 | 5000 | exdqlm | nonfinite_chi |
| 38 | laplace | 0p25 | 5000 | dqlm | invalid_pre_chi |
| 40 | laplace | 0p25 | 5000 | exdqlm | nonfinite_chi |
| 46 | laplace | 0p50 | 5000 | dqlm | invalid_pre_chi |
| 48 | laplace | 0p50 | 5000 | exdqlm | nonfinite_chi |
| 54 | normal | 0p05 | 5000 | dqlm | invalid_pre_chi |
| 56 | normal | 0p05 | 5000 | exdqlm | nonfinite_chi |
| 62 | normal | 0p25 | 5000 | dqlm | invalid_pre_chi |
| 64 | normal | 0p25 | 5000 | exdqlm | nonfinite_chi |
| 70 | normal | 0p50 | 5000 | dqlm | invalid_pre_chi |
| 72 | normal | 0p50 | 5000 | exdqlm | nonfinite_chi |

