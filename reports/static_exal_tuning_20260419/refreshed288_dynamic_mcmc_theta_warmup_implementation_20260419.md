# Refreshed288 Dynamic MCMC Theta Warmup Implementation

Date: `2026-04-19`

## Purpose

This note records the new dynamic MCMC `theta` warmup/freeze implementation that was added after the numerical-crash diagnosis in:

- [refreshed288_numcrash_root_cause_diagnosis_20260419.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260419/refreshed288_numcrash_root_cause_diagnosis_20260419.md)

The goal is to make the next numerical-crash relaunch:

- explicit,
- reproducible,
- backend-aware,
- and traceable from manifest to fit diagnostics.

## What Was Added

### Package control surface

Dynamic MCMC now accepts:

- `theta_state_controls`

Supported keys:

- `freeze_burnin_iters`
- `freeze_only_during_burn`
- `force_after_warmup`

This is implemented in:

- [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmMCMC.R)

### Behavior

During active theta warmup:

- the current `theta` state is held fixed,
- the FFBS theta draw is skipped for that iteration,
- posterior predictive draws are still defined from the held state,
- latent and sigma/gamma scheduling can continue independently.

After warmup:

- the theta update resumes,
- the first post-warmup active iteration is explicitly recorded.

## Diagnostics Added

The fit now records theta warmup in the same style as the existing warmup blocks.

### exDQLM MCMC

- `fit$mh.diagnostics$theta_state`
- `fit$mh.diagnostics$trace$theta_frozen`
- `fit$mh.diagnostics$trace$theta_update_reason`
- `fit$mh.diagnostics$trace$theta_forced_postwarmup`
- `fit$mh.diagnostics$trace$theta_update_performed`
- `fit$mh.diagnostics$trace$theta_update_count`
- `fit$diagnostics$theta_state`
- `fit$diagnostics$theta_state_trace`

### DQLM MCMC

- `fit$diagnostics$theta_state`
- `fit$diagnostics$theta_state_trace`
- per-iteration trace columns in `fit$diagnostics$trace`

## Numerical-Crash Relaunch Wiring

The refreshed numerical-crash relaunch tooling now uses:

- theta warmup for both dynamic MCMC branches
- the legacy R MCMC backend for this crash-recovery lane

This wiring lives in:

- [tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R)
- [tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R)
- [tools/merge_reports/LOCAL_refreshed288_prepare_numerical_failures_20260419.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_prepare_numerical_failures_20260419.R)
- [tools/merge_reports/LOCAL_refreshed288_launch_numerical_failures_20260419.sh](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_launch_numerical_failures_20260419.sh)

## Current Relaunch Defaults

For the next numerical-crash relaunch surface:

| Control | Value |
|---|---:|
| `theta_state.freeze_burnin_iters` | `100` |
| `theta_state.freeze_only_during_burn` | `TRUE` |
| `theta_state.force_after_warmup` | `TRUE` |
| `latent_state.freeze_burnin_iters` | `100` |
| `sigmagam.freeze_burnin_iters` | `500` |
| `dqlm_sigma.freeze_burnin_iters` | `500` |
| `mcmc_use_cpp` | `FALSE` |
| `mcmc_cpp_mode` | `"strict"` |

## Validation

Focused verification passed:

- package load
- [test-vb-mcmc-convergence-controls.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tests/testthat/test-vb-mcmc-convergence-controls.R)
- launcher shell syntax check

## Intended Next Use

The next numerical-crash relaunch should use a fresh run tag, not mutate older crash-recovery runs. The default relaunch surface is now prepared for:

- `20260419_numcrash_thetafreeze_v1`

with explicit theta warmup and explicit backend choice recorded in the generated run contract.
