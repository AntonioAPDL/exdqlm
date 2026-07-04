# exDQLM/DQLM c13 MCMC 500-Observation Refresh Audit

Date: 2026-07-04

## Scope

This audit checks the current-best c13 exDQLM/DQLM MCMC refresh lane for the 500-observation rolling-origin simulation comparison. It is not an Article-facing promotion unless the complete 18-cell by 30-lead grid is done/PASS and then materialized by the promotion script.

## Inputs

- validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- validation branch: `validation/shared-fitforecast-v2-1.0.0`
- validation HEAD at audit generation: `f65f0ce15f4640658bb6a0c9b133334bb8e6b0fe`
- validation HEAD subject: `Fix c13 MCMC manifest-scoped paths`
- manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/row_manifest.csv`
- shared interface: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- run root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2`

## Evidence Counts

- done/PASS c13 MCMC cells: `6/18`
- done/PASS c13 MCMC lead rows: `180/540`
- missing cells: `12`
- audit issues: `2`

## Status Counts

| Status | Rows |
| --- | ---: |
| done | 6 |
| pending | 12 |

## Telemetry States

| State | Rows |
| --- | ---: |
| completed | 6 |
| pending | 12 |

## Done/PASS Cell Summary

| Family | Tau | Model | Fit RMSE | Forecast MAE | Forecast check | Leads | Scored targets |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| gausmix | 0.05 | dqlm | 2.540 | 3.033 | 1.505 | 30 | 1000 |
| gausmix | 0.50 | exdqlm | 2.404 | 2.208 | 5.607 | 30 | 1000 |
| laplace | 0.05 | dqlm | 3.949 | 9.900 | 1.968 | 30 | 1000 |
| laplace | 0.05 | exdqlm | 9.975 | 22.738 | 5.189 | 30 | 1000 |
| normal | 0.50 | dqlm | 2.532 | 1.155 | 4.028 | 30 | 1000 |
| normal | 0.50 | exdqlm | 2.925 | 1.641 | 4.109 | 30 | 1000 |

## Issues

- Expected 540 lead rows; observed 180.
- Expected 18 model/family/tau cells; observed 6.

## Missing Cells

| Family | Tau | Model |
| --- | ---: | --- |
| gausmix | 0.05 | exdqlm |
| gausmix | 0.25 | dqlm |
| gausmix | 0.25 | exdqlm |
| gausmix | 0.50 | dqlm |
| laplace | 0.25 | dqlm |
| laplace | 0.25 | exdqlm |
| laplace | 0.50 | dqlm |
| laplace | 0.50 | exdqlm |
| normal | 0.05 | dqlm |
| normal | 0.05 | exdqlm |
| normal | 0.25 | dqlm |
| normal | 0.25 | exdqlm |

## Storage

- forbidden payloads: `0`

## Regeneration

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_c13_mcmc_500obs_refresh.R --manifest '/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/row_manifest.csv' --allow-incomplete
```
