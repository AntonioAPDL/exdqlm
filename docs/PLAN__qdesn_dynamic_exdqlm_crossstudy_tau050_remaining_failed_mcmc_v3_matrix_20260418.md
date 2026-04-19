# QDESN Tau050 Remaining-Failed MCMC V3 Matrix Plan

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Objective

Run a broad but still coherent `v3` experiment matrix over the unresolved `10` MCMC failures that remained after the completed `v2` relaunch.

This matrix is intentionally broader than the first `v3` sketch. The goal is not to test one more narrow tweak. The goal is to explore a small, well-structured set of plausible rescue directions so the next interpretation step is evidence-rich rather than guess-driven.

## Source Of Truth

Use these together:

- [REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_postmortem_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_postmortem_20260418.md)
- [PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_relaunch_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_relaunch_20260418.md)

## Why A Matrix Is Justified

The unresolved v2 surface is now small enough to target precisely, but heterogeneous enough that a single-arm replay is unlikely to be decisive.

Observed v2 patterns:

- unresolved set size: `10`
- failures still cluster around `latent_v` invalid-draw breakdowns
- `gausmix` is the hardest family
- `tau = 0.50` is still the hardest tau bucket
- `exal` remains weaker than `al`
- some failures occur late enough that startup warmup alone is not a sufficient explanation

That combination argues for a broad but disciplined design:

- one family of arms centered on direct `latent_v` rescue
- one stronger `latent_v` arm that stretches the schedule
- two exAL-only kernel/conditioning arms for the hardest pocket

## Exact Surface

The matrix is frozen against the unresolved v2 inventory using:

- [scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R)

Generated manifests:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv)

Surface counts:

- `AL`: `3`
- `EXAL`: `7`
- canary roots: `6`
- residual roots: `4`

## Experiment Arms

### Arm A: rescue baseline

Defaults file:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml)

Intent:

- keep the v2 warmup schedule
- add bounded `latent_v` rescue
- measure whether a single bad `v` draw is what still kills recoverable chains

Primary additions:

- `rescue_on_invalid = true`
- `rescue_strategy = previous_state`
- `rescue_max_consecutive = 3`
- `rescue_burn_only = false`
- `rescue_force_retry_next_iter = true`

### Arm B: rescue extended

Defaults file:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml)

Intent:

- keep the same rescue logic
- broaden the latent-`v` schedule for the possibility that several failures still need a longer transition to stable updates

Primary differences from Arm A:

- `freeze_burnin_iters = 100`
- `sparse_update_every = 5`
- `sparse_update_until_iter = 2000`
- `rescue_max_consecutive = 5`

### Arm C: exAL QR tight-slice

Defaults file:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml)

Intent:

- keep the baseline rescue logic
- test whether the hardest exAL roots mainly need stronger conditioning and a tighter slice geometry

Primary differences:

- `conditioning.mode = qr_whiten`
- narrower `sigma/gamma` slice widths
- otherwise keep the standard exAL core ordering

### Arm D: exAL alternative core

Defaults file:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml)

Intent:

- keep rescue enabled
- test whether the exAL failures are better addressed by a different sigma/gamma core ordering plus tighter geometry

Primary differences:

- `conditioning.mode = qr_whiten`
- `core_update_mode = gamma_sigma_gamma`
- tighter slice widths
- reduced extra passes

## Package-Side Changes Required

### Failure export and instrumentation

- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)

Required outcomes:

- failed fits export a structured `latent_v` failure payload
- stdout carries a parseable failure marker
- validation summaries preserve failure metadata
- successful fits export rescue traces and rescue summary counters

### Normalized rescue controls

- [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)

Required outcomes:

- a package-level `mcmc.latent_v.*` rescue surface
- defaults remain off unless a study YAML enables them

### Wrapper wiring

- [scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

Required outcomes:

- each arm has named canary and residual phases
- the phase names encode the arm identity clearly

## Test Battery

Tests to keep green:

- [tests/testthat/test-exal-inference-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-inference-config.R)
- [tests/testthat/test-exal-mcmc.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-mcmc.R)
- [tests/testthat/test-qdesn-latent-v-warmup-validation-export.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-latent-v-warmup-validation-export.R)
- [tests/testthat/test-qdesn-dynamic-tau050-remaining-failed-mcmc-v3-matrix-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-remaining-failed-mcmc-v3-matrix-config.R)

## Rollout Order

### Phase 1: implementation

Checklist:

- [ ] latent-`v` rescue controls implemented
- [ ] failed-fit export preserved
- [ ] v3 matrix defaults added
- [ ] v3 manifests materialized deterministically
- [ ] wrapper phases added
- [ ] tests passing

### Phase 2: prepare-only

Checklist:

- [ ] rescue AL canary prepare-only
- [ ] rescue EXAL canary prepare-only
- [ ] rescue-extended AL canary prepare-only
- [ ] rescue-extended EXAL canary prepare-only
- [ ] EXAL QR tight-slice canary prepare-only
- [ ] EXAL altcore canary prepare-only

### Phase 3: live canary launch

Launch in small batches to avoid materialization races.

Checklist:

- [ ] launch AL rescue canary
- [ ] launch EXAL rescue canary
- [ ] launch AL rescue-extended canary
- [ ] launch EXAL rescue-extended canary
- [ ] launch EXAL QR tight-slice canary
- [ ] launch EXAL altcore canary

### Phase 4: interpretation gate

Checklist:

- [ ] compare success / fail rates by arm
- [ ] compare rescue counts by arm
- [ ] check whether recovered fits are merely surviving or also diagnostically usable
- [ ] decide whether to promote any arm to residual launch

## Reproducibility Rules

- keep each arm in its own defaults file
- keep all v3 results under the dedicated `v3_matrix_validation` root
- preserve selected grids in the launch folders
- keep worktree snapshots with each live launch
- do not retrofit old runs
- do not mutate v2 manifests after v3 starts

## Decision Rule

Promote an arm only if it is better than v2 on the same unresolved surface and produces interpretable artifacts, not just fewer hard crashes.

The preferred winner is the arm that:

- reduces terminal failures
- preserves diagnostic usability
- improves the hardest `gausmix / tau=0.50 / exal` pocket
- does so with the least additional algorithmic complexity
