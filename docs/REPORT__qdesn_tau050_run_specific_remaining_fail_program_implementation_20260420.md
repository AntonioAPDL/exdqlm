# QDESN Tau050 Run-Specific Remaining-Fail Program Implementation

Date: 2026-04-20

## Summary

This report records the implementation of the run-specific remaining-fail
program defined in:

- [run-specific program plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_run_specific_remaining_fail_program_20260420.md)

The goal is to relaunch the remaining `15` hard failures with specs chosen by
failure mechanism instead of applying one global warmup profile to the whole
surface.

## Implemented Surfaces

### Frozen run-specific mapping

- [run-specific cluster map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_run_specific_cluster_map.csv)

### Materializer

- [run-specific materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_run_specific_remaining_fail_grids.R)

This script now writes:

- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_grid.csv`
- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_grid.csv`
- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_grid.csv`
- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_defaults.yaml`
- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_defaults.yaml`
- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_defaults.yaml`
- `qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v2_defaults.yaml`

### Wrapper phases

Launch wrapper:

- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

Healthcheck wrapper:

- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

New phases:

- `remaining_hard_fail_latent_v_al`
- `remaining_hard_fail_latent_v_exal`
- `remaining_hard_fail_exal_ridge_precision_v1`
- `remaining_hard_fail_exal_ridge_precision_v2`

### Regression coverage

- [run-specific config test](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-run-specific-remaining-fail-config.R)

## Implemented Spec Families

### `tau_theta_rescue_v1`

Applied through:

- `remaining_hard_fail_latent_v_al`
- `remaining_hard_fail_latent_v_exal`

Key properties:

- VB tau freeze `50`
- MCMC tau freeze `500`
- theta freeze `50`, sparse to `500`
- bounded latent-`v` rescue enabled
- latent-`s` freeze off
- conditioning off

### `tau_theta_precision_exal_v1`

Applied through:

- `remaining_hard_fail_exal_ridge_precision_v1`

Key additions on top of `tau_theta_rescue_v1`:

- `conditioning.mode = "qr_whiten"`
- `conditioning.gram_ridge = 1e-6`
- `conditioning.scale_metric = "sd"`
- `conditioning.scale_floor = 1e-8`

### `tau_theta_precision_exal_v2`

Prepared but intended only as a fallback:

- `remaining_hard_fail_exal_ridge_precision_v2`

Key additions on top of `v1`:

- `conditioning.gram_ridge = 1e-4`
- `slice.core_update_mode = "gamma_sigma_gamma"`

## Materialized Counts

The run-specific materializer reproduces the intended split:

| Phase surface | Roots |
|---|---:|
| latent-`v` AL cluster | 7 |
| latent-`v` EXAL cluster | 5 |
| EXAL ridge precision cluster | 3 |

## Verification

Focused validation passed with:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-run-specific-remaining-fail-config|qdesn-dynamic-tau050-single-root-probe-config|qdesn-static-crossstudy-collector|exal-inference-config|exal-mcmc|qdesn-dynamic-failure-repair|qdesn-sigmagam-warmup-validation-export", reporter = "summary")'
```

## Next Step

Run clean-SHA `prepare-only` for:

1. `remaining_hard_fail_latent_v_al`
2. `remaining_hard_fail_latent_v_exal`
3. `remaining_hard_fail_exal_ridge_precision_v1`

Then launch the live run-specific relaunch wave.
