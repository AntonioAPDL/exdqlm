# QDESN Tau050 Failed-MCMC Theta-Freeze And GIG-Floor Implementation

Date: 2026-04-19

## Scope

This report records the implementation of a crash-only relaunch surface for the
original 23 hard numerical MCMC failures from the April 16, 2026
`tau050_refreshed_main` source campaign. The change set has two main goals:

1. add a first-class MCMC `theta` freeze / sparse-update scheduler on the
   `beta` update in the active `exal_mcmc_fit()` path
2. harden the GIG sampling wrapper by flooring tiny positive inputs, with
   special attention to `b_vec`, at `1e-10`

The implementation was validated with focused tests plus successful
`prepare-only` runs for both failed-only theta-freeze relaunch phases.

## Main Code Changes

### Config resolution

- [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)
  - added `mcmc$theta` controls
  - added normalization for legacy aliases such as
    `freeze_theta_burnin_iters` and `freeze_beta_burnin_iters`
  - resolved `control$theta` alongside the existing `sigmagam`, `latent_v`,
    and `latent_s` controls

### MCMC implementation

- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
  - added the theta scheduler
  - gated the `beta` update with hard-freeze, sparse-update, and forced-thaw
    logic
  - exported theta traces, diagnostics, and failure payload context
  - appended theta fields to the structured latent-`v` failure payload so crash
    investigations retain the scheduler state at the failing iteration

### GIG hardening

- [R/utils.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/utils.R)
  - introduced `.exal_gig_floor()` with current floor `1e-10`
  - updated `.sample_gig_devroye_required()` so `a` and `b_vec` are floored via
    `max(..., 1e-10)` / `pmax(..., 1e-10)` rather than only replacing
    nonpositive values
  - updated `.sample_gig_devroye_pairs_required()` symmetrically

- [R/exdqlmMCMC.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exdqlmMCMC.R)
  - aligned the older dynamic MCMC GIG helper floor from `1e-12` to `1e-10`

### Validation export

- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)
  - exports theta diagnostics into method health summaries
  - appends theta scheduler fields to latent-`v` trace output
  - writes a dedicated `theta_trace.csv` when theta traces are present
  - carries theta scheduler state into failure-summary fields

### Wrapper surfaces

- [scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
  - added `failed_mcmc_al_thetafreeze`
  - added `failed_mcmc_exal_thetafreeze`
  - switched failed-only phases to the dedicated failed-MCMC subset
    materializer so auditable subset relaunches rebuild the exact crash-only
    grids

- [scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
  - added the same theta-freeze phases for monitoring

### Dedicated relaunch defaults

- [config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml)
  - dedicated crash-only relaunch lane
  - preserves the source campaign seed contract with `base_seed: 41000`
  - keeps strong tau freezing
  - disables direct latent-`v` and latent-`s` freeze schedules
  - enables the new theta scheduler

## Tests

Focused test battery:

```bash
Rscript -e 'testthat::test_local(filter = "exal-inference-config|exal-mcmc|qdesn-sigmagam-warmup-validation-export|qdesn-dynamic-failure-repair|qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config", reporter = "summary")'
```

Coverage additions include:

- [tests/testthat/test-exal-inference-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-inference-config.R)
  - theta config normalization and resolution

- [tests/testthat/test-exal-mcmc.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-mcmc.R)
  - theta freeze / sparse-update / forced-thaw scheduler behavior
  - latent-`v` failure payload assertions with theta fields

- [tests/testthat/test-qdesn-sigmagam-warmup-validation-export.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-sigmagam-warmup-validation-export.R)
  - theta health-summary and trace export

- [tests/testthat/test-qdesn-dynamic-failure-repair.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-failure-repair.R)
  - explicit assertion that tiny positive `b_vec` values are floored to
    `1e-10` before sampling

- [tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config.R)
  - theta-freeze defaults and failed-only wrapper wiring

## Prepare-Only Verification

Both failed-only theta-freeze phases completed `prepare-only` successfully from
the current branch head:

- `failed_mcmc_al_thetafreeze`
  - run tag:
    `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_thetafreeze-prepare-20260419-verify__git-9285a9a`

- `failed_mcmc_exal_thetafreeze`
  - run tag:
    `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_thetafreeze-prepare-20260419-verify__git-9285a9a`

The selected-grid preflight manifests were written under:

- [thetafreeze reports root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_validation)

## Notes

- The original prepare-only failure turned out to be a subset-audit mismatch,
  not a theta-freeze kernel bug.
- Two fixes restored subset validity:
  - aligning `base_seed` back to `41000` to match the April 16 source lane
  - using the dedicated failed-MCMC materializer for failed-only phases

No live theta-freeze relaunch was started in this implementation step. The lane
is ready for canary or full execution once launch is explicitly requested.
