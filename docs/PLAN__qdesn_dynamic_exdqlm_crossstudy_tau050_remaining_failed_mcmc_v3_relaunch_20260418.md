# QDESN Tau050 Remaining-Failed MCMC V3 Relaunch Plan

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Objective

Launch a high-quality, reproducible, well-instrumented `v3` rerun for the unresolved MCMC failures that remained after the completed `remaining_failed_mcmc_v2` relaunch.

The v3 relaunch should:

- target only the unresolved `10` fits
- preserve the parts of v2 that clearly helped
- avoid another broad warmup-only replay
- add better failure capture
- add a small number of coherent, testable interventions rather than many loosely coupled tweaks

## Source Of Truth

Use these documents together:

- [REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_postmortem_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_postmortem_20260418.md)
- [REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md)
- [PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_execution_checklist_20260418.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_execution_checklist_20260418.md)

## Why A V3 Relaunch Is Justified

The v2 rerun improved the surface from `0 / 18` unresolved recoveries to `8 / 18` recoveries, but `10 / 18` still failed.

From the postmortem:

- `normal` recovered well
- `gausmix` remained hard
- `tau = 0.50` remained hard
- `exal` remained weaker than `al`
- remaining failures were still `latent_v` invalid-draw crashes
- remaining failures occurred in both late burn and keep phase

That means there is still recoverable structure, but not enough to justify another unchanged v2 replay.

## V3 Design Principles

1. Keep the working v2 baseline.
2. Change only one or two major things at a time.
3. Preserve exact manifests and run tags.
4. Export failure context into result summaries, not just logs.
5. Stage the relaunch through canary gates.
6. Avoid rerunning already recovered roots unless a design test specifically needs them.

## What To Keep From V2

Keep these controls as the baseline unless a specific v3 arm overrides them:

- VB `min_iter_elbo = 80`
- VB tau freeze `50`
- MCMC tau freeze `500`
- VB `sigmagam.freeze_warmup_iters = 20`
- VB post-warmup damping
- VB warm-start `max_iter = 500`
- MCMC `sigmagam.freeze_burnin_iters = 500`
- MCMC `latent_v.freeze_burnin_iters = 50`
- MCMC `latent_v.sparse_update_every = 10`
- MCMC `latent_v.sparse_update_until_iter = 500`

These settings were not sufficient, but they were better than the pre-v2 baseline and should be retained unless a specific counterexample emerges.

## What Must Change Before V3 Launch

### 1. Failure Export Must Be Fixed

Current issue:

- failed fits still end up with `missing_chain_diagnostics`
- the `mcmc_failure_*` payload is not surviving into failed `health_summary.csv` rows

Why this matters:

- v3 needs artifact-level failure analysis
- we should not need to reopen raw logs for every failed case

Primary edit targets:

- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)

Required outcome:

- failed fits retain `mcmc_failure_family`
- failed fits retain failure iteration and phase
- failed fits retain `sigma`, `gamma`, `tau`, `c2`, and `beta_norm` context if available
- failed fits retain `chi_v` and `psi_v` summary fields if available
- failed fits retain `latent_v` warmup-active and update-reason fields if available

### 2. Exact Unresolved-10 Inventory Must Be Frozen

Create a new v3 manifest materializer that only enumerates the unresolved `10`.

Recommended new script:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R`

Recommended new grid outputs:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_canary_grid.csv`

## Recommended V3 Strategy

### Primary v3 change

Do not broaden warmup again first. Instead, preserve v2 warmup and add one coherent new intervention:

- a safer `latent_v` failure-handling / recovery policy

This can mean one of the following, in order of preference:

1. retry-and-reuse-last-valid-`v` for a bounded number of attempts inside burn only
2. bounded `latent_v` rescue that falls back to the previous valid state for the current iteration, with explicit trace markers
3. a guarded reinitialization of `v` from the previous valid state only when the draw becomes invalid

The intent is not to hide failure. The intent is to prevent a single bad `latent_v` draw from killing an otherwise stable chain, while recording exactly when rescue logic fired.

This should be a separate, explicit control family and should default to off at package level.

Suggested control shape:

```yaml
pipeline:
  inference:
    mcmc:
      latent_v:
        freeze_burnin_iters: 50
        sparse_update_every: 10
        sparse_update_until_iter: 500
        rescue_on_invalid: true
        rescue_max_consecutive: 3
        rescue_burn_only: false
        rescue_use_previous_state: true
        record_rescue_trace: true
```

### Secondary v3 change

Add one exAL-only secondary arm for the hardest unresolved pocket, not globally:

- smaller slice widths for `exal`
- or a different `mcmc_core_update_mode`

This should not be the first arm across the whole unresolved surface. It should be limited to the hardest `exal` canary roots first.

## What Not To Do First

- do not reopen raw `rhs`
- do not rerun all 18 v2 targets again unchanged
- do not make prior choice the main lever
- do not do a global slice-width retune before we fix failure export
- do not treat longer startup warmup as the only next move

## Unresolved-10 Pockets To Prioritize

The v3 canary should prioritize the hardest surface:

### Hardest pocket

- `gausmix`
- `tau = 0.50`
- `exal`
- `fit_size = 5000`

### Secondary pocket

- `laplace`
- `tau = 0.50`
- both `al` and `exal`

### Comparator pocket

- `normal`
- higher tau unresolved case(s)

This gives the relaunch a meaningful comparison set:

- hardest unresolved `gausmix`
- intermediate unresolved `laplace`
- relatively healthier `normal`

## Proposed V3 Rollout

### Phase 0: documentation and reproducibility

Checklist:

- [ ] create v3 post-v2 unresolved manifests
- [ ] create a dedicated v3 defaults YAML
- [ ] keep v3 separate from refreshed-main and v2 defaults
- [ ] record exact parent runs and parent manifests in the v3 plan doc
- [ ] keep worktree status and diff snapshots in launch folders

### Phase 1: failure-export fix

Checklist:

- [ ] persist structured `mcmc_failure_*` payloads for failed fits
- [ ] add test coverage for failed-fit summary export
- [ ] confirm failed `health_summary.csv` contains the payload
- [ ] confirm failed `fit_summary_row.csv` contains an interpretable failure family / reason

### Phase 2: package-side v3 controls

Checklist:

- [ ] add normalized `latent_v` rescue controls in [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)
- [ ] implement rescue scheduling in [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
- [ ] export rescue counters / traces in [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)
- [ ] keep the feature off by default at package level

### Phase 3: tests

Checklist:

- [ ] config resolution tests in `tests/testthat/test-exal-inference-config.R`
- [ ] rescue scheduler tests in `tests/testthat/test-exal-mcmc.R`
- [ ] validation export tests in `tests/testthat/test-qdesn-latent-v-warmup-validation-export.R`
- [ ] v3 config/materializer tests in a new targeted v3 test file

### Phase 4: prepare-only

Checklist:

- [ ] materialize exact v3 canary grid
- [ ] materialize exact v3 unresolved-full grid
- [ ] run prepare-only for v3 canary
- [ ] run prepare-only for v3 full unresolved grid
- [ ] verify fit requests serialize the new controls

### Phase 5: v3 canary launch

Checklist:

- [ ] launch only the hardest unresolved `3-4` roots first
- [ ] include at least one `gausmix tau 0.50 exal`
- [ ] include at least one `laplace tau 0.50`
- [ ] include at least one `normal` unresolved comparator
- [ ] do not launch full unresolved-10 until canary outcome is reviewed

### Phase 6: expand only if justified

Promotion rule:

- if the v3 canary materially reduces repeat `latent_v` terminal failures without producing obviously worse diagnostics, expand to the unresolved full set
- if it does not, stop and redesign before spending more compute

## Exact Files Expected To Change For V3

Core code:

- [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)
- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)

Configs and manifests:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_canary_grid.csv`

Scripts:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R`
- [scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

Tests:

- [tests/testthat/test-exal-inference-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-inference-config.R)
- [tests/testthat/test-exal-mcmc.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-mcmc.R)
- `tests/testthat/test-qdesn-dynamic-tau050-remaining-failed-mcmc-v3-config.R`

## Recommended Decision

The recommended next move is:

1. fix failed-fit failure export
2. freeze the unresolved-10 manifests
3. implement a bounded `latent_v` rescue policy on top of the v2 warmup baseline
4. run a hard canary first
5. only then decide whether to expand to the full unresolved-10

That is the highest-signal, lowest-waste v3 path available from the current evidence.
