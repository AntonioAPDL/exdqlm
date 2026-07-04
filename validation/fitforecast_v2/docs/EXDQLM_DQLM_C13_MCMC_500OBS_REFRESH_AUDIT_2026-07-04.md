# exDQLM/DQLM c13 MCMC 500-Observation Refresh Audit

Date: 2026-07-04

## Scope

This audit checks the current-best c13 exDQLM/DQLM MCMC refresh lane for the 500-observation rolling-origin simulation comparison. It is not an Article-facing promotion unless the complete 18-cell by 30-lead grid is done/PASS and then materialized by the promotion script.

## Inputs

- validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- validation branch: `validation/shared-fitforecast-v2-1.0.0`
- validation HEAD at audit generation: `49a4caa5b62d32216e75945e8adfbfa8e83c63cc`
- validation HEAD subject: `Record c13 MCMC gate audit`
- manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v2/manifests/row_manifest.csv`
- shared interface: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v2/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- run root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v2`

## Evidence Counts

- done/PASS c13 MCMC cells: `18/18`
- done/PASS c13 MCMC lead rows: `540/540`
- missing cells: `0`
- audit issues: `0`

## Status Counts

| Status | Rows |
| --- | ---: |
| done | 18 |

## Telemetry States

| State | Rows |
| --- | ---: |
| completed | 18 |

## Done/PASS Cell Summary

| Family | Tau | Model | Fit RMSE | Forecast MAE | Forecast check | Leads | Scored targets |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| gausmix | 0.05 | dqlm | 2.623 | 3.003 | 1.505 | 30 | 1000 |
| gausmix | 0.05 | exdqlm | 2.554 | 23.912 | 5.857 | 30 | 1000 |
| gausmix | 0.25 | dqlm | 4.740 | 2.487 | 4.540 | 30 | 1000 |
| gausmix | 0.25 | exdqlm | 1.381 | 8.941 | 5.649 | 30 | 1000 |
| gausmix | 0.50 | dqlm | 2.226 | 1.932 | 5.556 | 30 | 1000 |
| gausmix | 0.50 | exdqlm | 2.408 | 2.207 | 5.607 | 30 | 1000 |
| laplace | 0.05 | dqlm | 3.663 | 9.791 | 1.968 | 30 | 1000 |
| laplace | 0.05 | exdqlm | 5.677 | 22.440 | 5.154 | 30 | 1000 |
| laplace | 0.25 | dqlm | 2.850 | 3.520 | 4.548 | 30 | 1000 |
| laplace | 0.25 | exdqlm | 1.710 | 6.811 | 5.106 | 30 | 1000 |
| laplace | 0.50 | dqlm | 1.774 | 1.337 | 5.082 | 30 | 1000 |
| laplace | 0.50 | exdqlm | 1.774 | 2.013 | 5.206 | 30 | 1000 |
| normal | 0.05 | dqlm | 3.036 | 3.829 | 1.103 | 30 | 1000 |
| normal | 0.05 | exdqlm | 1.935 | 16.226 | 4.313 | 30 | 1000 |
| normal | 0.25 | dqlm | 3.811 | 2.209 | 3.328 | 30 | 1000 |
| normal | 0.25 | exdqlm | 2.344 | 6.634 | 4.132 | 30 | 1000 |
| normal | 0.50 | dqlm | 2.590 | 1.161 | 4.029 | 30 | 1000 |
| normal | 0.50 | exdqlm | 2.808 | 1.637 | 4.109 | 30 | 1000 |

## Issues

- none

## Storage

- forbidden payloads: `0`

## Regeneration

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_c13_mcmc_500obs_refresh.R --manifest '/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v2/manifests/row_manifest.csv' 
```
