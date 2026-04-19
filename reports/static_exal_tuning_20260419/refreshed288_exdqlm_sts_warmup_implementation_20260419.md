# Refreshed288 exDQLM `s_t` Warmup Implementation

This note records the method change introduced before the `20260419_numcrash_stsfreeze_v1` numerical-crash relaunch.

## Why this was added

The failed exDQLM dynamic MCMC rows were no longer best interpreted as pure downstream `chi` failures. The stronger-init diagnostic rerun showed that several rows were already arriving at MCMC with a broken LDVB initializer and were now failing earlier at:

- `vb_init_validation_fail: theta_nonfinite; post_pred_nonfinite; sfe_nonfinite`

The deeper investigation pointed to the exDQLM state-side path:

- `s_t` moments collapse first,
- then `ex.f / ex.q`,
- then the smoothed state / forecast-error path.

So the next relaunch needed an upstream exDQLM LDVB stabilization lever, not just more MCMC warmup.

## What changed

The dynamic LDVB path in [R/exdqlmLDVB.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/R/exdqlmLDVB.R) now supports an explicit `s_t` warmup/freeze scheduler through:

- `exdqlm.dynamic.ldvb.sts`

Supported control fields:

- `freeze_warmup_iters`
- `force_after_warmup`
- `min_postwarmup_updates`

Current relaunch policy:

| Surface | Setting |
|---|---|
| exDQLM direct VB | `s_t` warmup `50` |
| exDQLM MCMC VB init | `s_t` warmup `50` |
| post-warmup guard | require at least `5` post-warmup `s_t` updates |

Warmup semantics:

1. During warmup, the `s_t` block is held at the previous iterate.
2. The first post-warmup update is forced.
3. Convergence is not allowed to declare success until the required post-warmup `s_t` updates have actually happened.

## Diagnostics added

The LDVB fit now records `s_t` warmup state in:

- `fit$misc$sts`
- `fit$misc$sts_frozen_trace`
- `fit$misc$sts_update_reason_trace`
- `fit$misc$sts_forced_postwarmup_trace`
- `fit$misc$sts_update_performed_trace`
- `fit$misc$sts_update_count_trace`

and in:

- `fit$diagnostics$convergence$sts_min_updates_ok`
- `fit$diagnostics$ld_block$sts`
- `fit$diagnostics$state_path$trace`

This keeps the warmup contract visible both in the fit object and in the row-level rerun evidence.

## Relaunch integration

The numerical-crash relaunch tooling now wires this through:

- [LOCAL_refreshed288_helpers_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R)
- [LOCAL_refreshed288_prepare_numerical_failures_20260419.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_prepare_numerical_failures_20260419.R)
- [LOCAL_refreshed288_launch_numerical_failures_20260419.sh](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_launch_numerical_failures_20260419.sh)

The frozen relaunch scope remains:

- the `20` numerical/runtime crash rows from [LOCAL_refreshed288_numerical_runtime_failure_manifest_20260419.csv](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_numerical_runtime_failure_manifest_20260419.csv)

The `27` static MCMC gate/mixing failures remain excluded from this relaunch.
