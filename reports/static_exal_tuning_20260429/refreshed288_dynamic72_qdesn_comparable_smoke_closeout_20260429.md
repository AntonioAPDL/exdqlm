# Dynamic 72 Q-DESN-Comparable Relaunch Smoke Closeout

## Executive Outcome

The dynamic-only Q-DESN-comparable relaunch setup was implemented and verified, but the full 72-case launch was not started.

Reason: the required dynamic smoke gate did not pass. VB smoke completed cleanly, but MCMC smoke surfaced one completed sampler-health `FAIL` and the six TT5000 MCMC rows were manually stopped after excessive runtime once the smoke gate had already failed.

## Run Identity

- Requested run tag: `20260429_p90_dynamic72_qdesn_comparable_v1`
- Prepared run root: `tools/merge_reports/full288_refreshed288_20260429_p90_dynamic72_qdesn_comparable_v1`
- Variant tag: `p90_dynamic72_qdesn_comparable_v1`
- Dynamic dataset: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`
- Dynamic smoke manifest: `tools/merge_reports/LOCAL_refreshed288_smoke_manifest_20260429_p90_dynamic72_qdesn_comparable_v1.csv`
- Dynamic full manifest: `tools/merge_reports/LOCAL_refreshed288_full_manifest_20260429_p90_dynamic72_qdesn_comparable_v1.csv`

## Preflight

| Check | Result |
| --- | --- |
| Branch fetched and worktree checked | Pass before launch setup |
| Package load | Pass |
| Focused relaunch contract tests | Pass |
| Lightweight retention tests | Pass |
| Dynamic canonical source tests | Pass |
| Dynamic registry | 18 dynamic rows, 0 missing inputs |
| Q-DESN effective-tail verification | 18/18 pass, max numeric difference 0 |

Window verification report:

- `reports/static_exal_tuning_20260429/refreshed288_dynamic72_qdesn_window_verification_20260429.md`
- `reports/static_exal_tuning_20260429/refreshed288_dynamic72_qdesn_window_verification_20260429.csv`

## Smoke Result

Only dynamic phases were launched. Static smoke rows remain intentionally `not_started`.

| Phase | Attempted | Done | Stopped | PASS | WARN | FAIL | Outcome |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| dynamic VB | 12 | 12 | 0 | 12 | 0 | 0 | Pass |
| dynamic MCMC | 12 | 6 | 6 | 3 | 2 | 7 | Blocked |
| dynamic total | 24 | 18 | 6 | 15 | 2 | 7 | Blocked |

The six stopped rows are counted as `failed_runtime` with error:

`manual_stop_after_smoke_gate_failure_and_long_tt5000_mcmc_runtime`

This is a manual operational stop, not an R exception or numerical crash.

## MCMC Diagnostics

Completed MCMC rows:

| Row | Family | Fit Size | Model | Gate | Runtime Sec | Main Issue |
| ---: | --- | ---: | --- | --- | ---: | --- |
| 18 | gausmix | 500 | dqlm | PASS | 1441.217 | none |
| 20 | gausmix | 500 | exdqlm | WARN | 1659.027 | sigma/gamma ESS warning |
| 42 | laplace | 500 | dqlm | PASS | 1442.165 | none |
| 44 | laplace | 500 | exdqlm | FAIL | 1646.909 | sigma/gamma ESS failure |
| 66 | normal | 500 | dqlm | PASS | 1432.882 | none |
| 68 | normal | 500 | exdqlm | WARN | 1642.987 | gamma warning |

Key health-gate details:

| Row | ess_sigma_per1k | ess_gamma_per1k | acf1_sigma | acf1_gamma | gate_sigma | gate_gamma |
| ---: | ---: | ---: | ---: | ---: | --- | --- |
| 20 | 6.4867 | 5.6465 | 0.9772 | 0.9888 | WARN | WARN |
| 44 | 4.4471 | 3.6439 | 0.9849 | 0.9927 | FAIL | FAIL |
| 68 | 10.7814 | 9.9297 | 0.9606 | 0.9803 | PASS | WARN |

Stopped TT5000 MCMC rows:

| Row | Family | Fit Size | Model | Elapsed Sec At Stop |
| ---: | --- | ---: | --- | ---: |
| 22 | gausmix | 5000 | dqlm | 7918.536 |
| 24 | gausmix | 5000 | exdqlm | 7918.809 |
| 46 | laplace | 5000 | dqlm | 7917.989 |
| 48 | laplace | 5000 | exdqlm | 7918.858 |
| 70 | normal | 5000 | dqlm | 5886.454 |
| 72 | normal | 5000 | exdqlm | 5858.551 |

## Numerical Failure Statement

No completed smoke row had an R runtime error, missing metric output, or `metric_error`.

The blocking issue is sampler health and throughput:

- `row 44` completed but failed the sigma/gamma ESS health gate.
- `rows 22, 24, 46, 48, 70, 72` were manually stopped after the smoke gate had already failed and TT5000 MCMC runtime was excessive.
- No full 72-case relaunch was started.

## Resource And Retention Check

| Resource | Result |
| --- | --- |
| Run root size after smoke stop | ~16 MB |
| Full fit binaries retained | 0 |
| Draw binaries retained | 0 |
| VB-init binaries retained | 0 |
| Disk free on `/home` after stop | ~785 GB |
| RAM available after stop | ~489 GiB |

The compact/resource-efficient retention policy worked as intended. The blocker is MCMC compute/sampler health, not storage growth.

## Recommendation

Do not launch the full 72 dynamic grid from this baseline smoke result.

Recommended next pass:

- Create an explicit MCMC repair overlay for dynamic TT5000 and exDQLM TT500 rows.
- Keep VB baseline unchanged because dynamic VB smoke passed 12/12.
- Treat row 44 as the first concrete repair target.
- Re-smoke MCMC with a smaller, targeted repair set before full launch.
- Consider separating dynamic VB full launch from MCMC full launch so successful VB rows are not blocked by MCMC tuning.
