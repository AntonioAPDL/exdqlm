# QDESN Tau050 Failed-MCMC Theta-Freeze Relaunch Plan

Date: 2026-04-19

## Purpose

This plan defines the next crash-only relaunch lane for the original 23 hard
numerical MCMC failures from the April 16, 2026 `tau050_refreshed_main`
campaign. The goal is to test a `theta`-plus-`tau` stabilization strategy while
keeping the relaunch auditable against the original source campaign.

## Relaunch Surface

Canonical failed-only grids:

- [failed MCMC AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv)
- [failed MCMC EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv)

Dedicated relaunch defaults:

- [thetafreeze defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_thetafreeze_defaults.yaml)

Wrapper phases:

- `failed_mcmc_al_thetafreeze`
- `failed_mcmc_exal_thetafreeze`

## Strategy

Keep:

- strong VB warm start
- VB tau freeze
- MCMC tau freeze burn-in `500`
- GIG input floor `1e-10`

Change:

- disable direct latent-`v` freeze scheduling
- disable direct latent-`s` freeze scheduling
- enable a new MCMC theta scheduler on the `beta` update:
  - `freeze_burnin_iters = 50`
  - `sparse_update_every = 10`
  - `sparse_update_until_iter = 500`
  - `force_first_postwarmup_update = true`

Rationale:

- the remaining unresolved crash family still concentrates in the latent-`v`
  GIG draw
- recent evidence suggested that pure latent-state freezing was only partially
  helpful
- this lane isolates whether a more conservative early `beta` schedule reduces
  destabilizing feedback into the latent-`v` path

## Audit And Reproducibility Rules

1. Use the original 23-crash manifests only.
2. Keep the source campaign seed contract aligned with the April 16 run:
   `base_seed = 41000`.
3. Always materialize failed-only grids through:
   [failed-MCMC materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R)
4. Keep the theta-freeze relaunch in its own campaign root and report root.
5. Preserve preflight manifests before any live compute.

## Test And Launch Order

1. Focused regression battery
2. `prepare-only` for `failed_mcmc_al_thetafreeze`
3. `prepare-only` for `failed_mcmc_exal_thetafreeze`
4. Small canary if desired
5. Full AL + EXAL failed-only relaunch

## Verified Commands

Focused tests:

```bash
Rscript -e 'testthat::test_local(filter = "exal-inference-config|exal-mcmc|qdesn-sigmagam-warmup-validation-export|qdesn-dynamic-failure-repair|qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config", reporter = "summary")'
```

Prepare-only:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al_thetafreeze \
  --prepare-only \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_thetafreeze-prepare-20260419-verify__git-9285a9a

Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal_thetafreeze \
  --prepare-only \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_thetafreeze-prepare-20260419-verify__git-9285a9a
```

## Launch Guidance

Do not mutate the canonical refreshed-main defaults for this lane.

When launching live compute:

- prefer sequential AL then EXAL startup
- keep worker count at `2` per lane
- run healthchecks from the dedicated theta-freeze phase names
- archive the exact run tags in a follow-up launch report
