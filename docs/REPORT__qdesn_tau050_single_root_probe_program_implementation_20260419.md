# QDESN Tau050 Single-Root Probe Program Implementation

Date: 2026-04-19

## Summary

This report records the implementation of Phase 0 and Phase 1 from the
crash-recovery program in:

- [crash-recovery program plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_crash_recovery_program_20260419.md)

The goal of this step was to turn the single-root probe into a fully
reproducible launch surface before any live compute:

1. tighten the theta-freeze spec by explicitly restoring VB tau freeze
2. materialize canonical single-root and comparator grids
3. generate dedicated probe defaults files for the first-pass structural arms
4. extend the launch and healthcheck wrappers
5. add focused tests
6. validate the probe phases with `prepare-only`

No broad failed-run relaunch was started in this step.

## Files Changed

### Core defaults and wrappers

- [thetafreeze defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml)
- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

### New materializer

- [single-root probe materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R)

### Generated probe defaults

- [tau-only defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_tau_only_defaults.yaml)
- [theta-plus-tau defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_defaults.yaml)
- [s-plus-tau defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_stau_defaults.yaml)
- [theta-plus-tau rescue defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_theta_tau_rescue_defaults.yaml)

### Generated probe grids

- [primary EXAL rhs_ns probe grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_primary_exal_rhsns_grid.csv)
- [EXAL ridge comparator grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_comparator_exal_ridge_grid.csv)
- [AL rhs_ns comparator grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_comparator_al_rhsns_grid.csv)
- [AL ridge comparator grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_comparator_al_ridge_grid.csv)
- [EXAL triad grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_triad_exal_grid.csv)
- [AL triad grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_triad_al_grid.csv)

### Tests

- [thetafreeze config test](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config.R)
- [single-root probe config test](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-single-root-probe-config.R)

## What Was Implemented

### 1. Theta-freeze spec cleanup

The dedicated theta-freeze defaults now explicitly restate the VB tau-freeze
policy for the probe program:

- direct VB `rhs` tau freeze: `50`
- direct VB `rhs` warmup freeze: `50`
- direct VB `min_tau_updates`: `2`
- direct VB `force_tau_after_warmup`: `true`
- mirrored `rhs_ns` VB prior override
- mirrored MCMC VB warm-start `rhs` block

This closes the ambiguity identified in the recovery-program plan and makes the
theta-plus-tau story explicit on both the VB and MCMC sides.

### 2. Canonical probe surfaces

The materializer now freezes a small but scalable experiment surface:

- one primary hard probe root:
  - `mcmc_exal`
  - `laplace`
  - `tau = 0.50`
  - `fit_size = 5000`
  - `rhs_ns`
- direct comparators for:
  - EXAL `ridge`
  - AL `rhs_ns`
  - AL `ridge`
- two triad grids for later promotion if the primary probe separates cleanly

### 3. First-pass structural arms

The generated defaults isolate the following arms:

1. `tau only`
2. `theta + tau`
3. `s + tau`
4. `theta + tau + bounded latent-v rescue`

Only the first three are intended for the first live wave. The rescue arm is
materialized and validated so it can be promoted quickly if the structural
comparison is inconclusive.

### 4. Wrapper support

The main launch and healthcheck wrappers now support:

- `single_root_probe_exal_tau_only`
- `single_root_probe_exal_theta_tau`
- `single_root_probe_exal_stau`
- `single_root_probe_exal_theta_tau_rescue`

Each probe phase is pinned to:

- the generated single-root EXAL rhs_ns grid
- the corresponding generated defaults file
- `mcmc`
- `exal`
- `1` worker

## Validation

### Focused tests

The following focused battery passed:

```bash
Rscript -e 'testthat::test_local(filter = "exal-inference-config|exal-mcmc|qdesn-sigmagam-warmup-validation-export|qdesn-dynamic-failure-repair|qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config|qdesn-dynamic-tau050-single-root-probe-config", reporter = "summary")'
```

### Prepare-only validation

The following probe phases were validated with `prepare-only`:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_tau_only --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_theta_tau --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_stau --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_theta_tau_rescue --prepare-only
```

Prepare-only run tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_tau_only-20260419-173736__git-109ff76`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_theta_tau-20260419-173749__git-109ff76`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_stau-20260419-173800__git-109ff76`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_theta_tau_rescue-20260419-173816__git-109ff76`

## Recommended Next Step

The next operational step is:

1. commit and push this implementation surface
2. relaunch the same probe phases from the clean implementation SHA
3. start only the first three structural arms:
   - `tau only`
   - `theta + tau`
   - `s + tau`
4. keep the rescue arm ready but unlaunched unless the first three fail to
   separate clearly

That preserves scientific attribution while keeping the compute footprint small.
