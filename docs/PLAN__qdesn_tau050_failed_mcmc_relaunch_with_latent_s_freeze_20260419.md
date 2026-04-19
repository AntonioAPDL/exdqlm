# PLAN: QDESN Tau050 23-Fit Failed-MCMC Relaunch With Latent `s` Freeze

Date: 2026-04-19
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Current Reproducible State

Authoritative source campaign:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674`

Current source-run status:

- `144 / 144` fits terminal
- `121` `SUCCESS`
- `23` hard `FAIL`
- `95` acceptable fits by signoff (`71 PASS + 24 WARN`)

Current documentation baseline:

- storage cleanup and preserved artifact surface:
  - `docs/REPORT__qdesn_validation_storage_cleanup_20260419.md`
- post-cleanup source-run retention note:
  - `docs/REPORT__qdesn_tau050_source_run_artifact_retention_and_crash_focus_20260419.md`
- existing crash-only relaunch plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_relaunch_execution_20260418.md`

Current reproducible crash-only manifests:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv`

Important preservation rule:

- do **not** delete or overwrite the current `PASS` / `WARN` source-run surface
- do **not** mutate the canonical source-run result tree
- do **not** reuse the `v2` / `v3` residual-failure trees as the relaunch source of truth

This relaunch is anchored to the original `23` hard numerical MCMC failures from the 144-fit source campaign.

## 2) Why Add A Latent `s` Freeze

The active MCMC implementation already has direct warmup logic for latent `v`, but latent `s` is still updated every iteration with no analogous freeze schedule.

Relevant code path:

- latent `s` initialization:
  - `R/exal_mcmc_fit.R:1419-1421`
- latent `v` update block:
  - `R/exal_mcmc_fit.R:1927-2047`
- latent `s` update block:
  - `R/exal_mcmc_fit.R:2049-2054`

Current loop ordering is:

1. derive `z_v = y - X beta - Cabs * sigma * s`
2. sample or freeze `v`
3. derive `r_s = y - X beta - A * v`
4. sample `s`
5. update `beta`
6. update RHS state
7. update `sigma / gamma`

That ordering matters because:

- the current `s` state enters the next `latent_v` draw through `z_v`
- the newly sampled `s` also feeds the `beta` update through `y_star`
- this makes `s` a true latent-state stabilizer, not just a downstream nuisance variable

Interpretation:

- the observed hard crash family is still `latent_v` invalid draws
- latent `s` is not the direct crashing sampler
- but unstable early `s` movement can still amplify the same feedback loop that pushes `latent_v` into bad `chi_v / psi_v` regimes

So the reason to add latent `s` freeze is:

- not because `s` is the proven crash site
- but because `s` sits directly on both sides of the unstable `v` update and should be stabilized coherently with `v`

## 3) Design Principle

Use a **coherent latent-state warmup policy** for the 23-fit crash-only relaunch:

- keep the current strengthened tau and `sigmagam` warmup contract
- keep the current latent `v` warmup contract
- add a new latent `s` warmup contract that mirrors the `v` schedule at first

This is more coherent than:

- increasing tau freeze again without touching `s`
- broadening slice settings first
- or jumping directly to a large new kernel redesign before testing the simpler latent-state stabilization step

## 4) Proposed Latent `s` Freeze Spec

Recommended initial spec for the 23-fit relaunch:

```yaml
pipeline:
  inference:
    mcmc:
      latent_s:
        enabled: true
        freeze_burnin_iters: 50
        freeze_only_during_burn: true
        sparse_update_every: 10
        sparse_update_until_iter: 500
        force_first_postwarmup_update: true
        trace: true
```

Recommended interpretation:

- iterations `1:50`:
  - keep `s` fixed at the initialized state
- iterations `51:500`:
  - update `s` every 10th iteration
  - otherwise carry forward the previous `s`
- first iteration after the warmup window:
  - force a real `s` refresh
- after iteration `500`:
  - revert to ordinary every-iteration `s` updates

Why start with the same schedule as `v`:

- it keeps the latent-state warmup surface easy to reason about
- it avoids a new independently tuned schedule before we have evidence
- it makes diagnostics easier to compare because `v` and `s` warmup windows line up

## 5) Exact Package Targets To Modify

### A. Config normalization

Primary file:

- `R/exal_inference_config.R`

Add:

- `.exal_normalize_mcmc_latent_s_cfg()`

Recommended normalized fields:

- `enabled`
- `freeze_burnin_iters`
- `freeze_only_during_burn`
- `sparse_update_every`
- `sparse_update_until_iter`
- `force_first_postwarmup_update`
- `trace`

Implementation placement:

- next to `.exal_normalize_mcmc_latent_v_cfg()`
- resolved through the same `mcmc_control` surface as the other warmup blocks

### B. MCMC engine

Primary file:

- `R/exal_mcmc_fit.R`

Required additions:

1. parse normalized `latent_s` config near the existing `latent_v` / `sigmagam` warmup parsing block
2. initialize `latent_s_force_pending` and per-iteration traces
3. gate the `s` update around the existing block at `R/exal_mcmc_fit.R:2049-2054`
4. export `latent_s` diagnostics alongside `latent_v` diagnostics
5. add `s` summary context into the existing latent-`v` failure payload so the failure record captures the current latent-state context

Recommended new traces:

- `latent_s_warmup_active_trace`
- `latent_s_hard_freeze_trace`
- `latent_s_sparse_window_trace`
- `latent_s_force_update_trace`
- `latent_s_update_performed_trace`
- `latent_s_update_reason_trace`
- `latent_s_update_count_trace`

Recommended new diagnostics summary:

- `freeze_burnin_iters`
- `freeze_only_during_burn`
- `sparse_update_every`
- `sparse_update_until_iter`
- `first_postwarmup_update_iter`
- `updates_burn`
- `updates_keep`
- `frozen_burn_rate`
- `sparse_hold_burn_rate`

Important behavioral rule:

- latent `s` freeze should **not** extend into kept draws
- this is a burn-only stabilization device, not a change to the stationary target

### C. Validation export

Primary file:

- `R/qdesn_mcmc_validation.R`

Add:

- fit-summary / health-summary columns for latent `s` warmup
- full progress-trace columns when the trace length matches the iteration count

Recommended health-summary columns:

- `mcmc_latent_s_warmup_iters`
- `mcmc_latent_s_sparse_update_every`
- `mcmc_latent_s_sparse_update_until_iter`
- `mcmc_latent_s_first_postwarmup_update_iter`
- `mcmc_latent_s_updates_burn`
- `mcmc_latent_s_updates_keep`
- `mcmc_latent_s_frozen_burn_rate`
- `mcmc_latent_s_sparse_hold_burn_rate`

Recommended full-trace columns:

- `latent_s_warmup_active`
- `latent_s_hard_freeze`
- `latent_s_sparse_window`
- `latent_s_force_update`
- `latent_s_update_performed`
- `latent_s_update_reason`
- `latent_s_update_count`

### D. Tests

Primary files:

- `tests/testthat/test-exal-inference-config.R`
- `tests/testthat/test-exal-mcmc.R`
- `tests/testthat/test-qdesn-sigmagam-warmup-validation-export.R`

Test objectives:

1. config normalization:
  - `latent_s` defaults resolve correctly
  - aliases normalize correctly
2. engine schedule:
  - hard freeze holds `s` fixed through the specified burn window
  - sparse window updates only on scheduled iterations
  - first post-warmup `s` update is forced and recorded
3. export:
  - health summary exposes latent `s` warmup fields
  - progress trace emits latent `s` schedule markers

## 6) Relaunch-Specific Config Surface

Do **not** mutate the canonical source defaults again.

Instead add a dedicated relaunch defaults file such as:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_sfreeze_defaults.yaml`

That defaults file should:

- inherit the already strengthened tau / `sigmagam` / latent `v` policy
- add the new `latent_s` block
- keep results and reports isolated from the prior failed-only reruns

Recommended wrapper phases:

- `failed_mcmc_al_sfreeze`
- `failed_mcmc_exal_sfreeze`

Primary wrapper files:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

## 7) Reproducibility Checklist

Before any code launch:

- [ ] keep the existing source-run retention note checked in
- [ ] keep the storage-cleanup report checked in
- [ ] preserve the original 23-fit failed-only AL / EXAL grids as the relaunch source of truth
- [ ] create a dedicated `sfreeze` defaults YAML rather than reusing the current generic defaults
- [ ] route the relaunch to new results / reports roots
- [ ] record the exact launch SHA
- [ ] keep launch commands and healthcheck commands in the execution report

Before any live compute:

- [ ] run targeted tests for config + MCMC + validation export
- [ ] run `--prepare-only` for `failed_mcmc_al_sfreeze`
- [ ] run `--prepare-only` for `failed_mcmc_exal_sfreeze`
- [ ] record generated run tags, manifests, and defaults path in a launch note

During execution:

- [ ] monitor root-level manifests, not only the top-level campaign tables
- [ ] capture latent `v` failure payloads with new `s` context
- [ ] do not delete the preserved `PASS` / `WARN` source-run sidecar `.rds`

## 8) Recommended Launch Order

Recommended order:

1. implement + test latent `s` freeze
2. run `prepare-only` for both 23-fit relaunch lanes
3. run a small canary first:
   - `2` AL roots
   - `3` EXAL roots
4. inspect whether:
   - the old `latent_v` crash appears later or not at all
   - the new latent-state traces look coherent
   - no new regressions appear in the acceptable artifact surface
5. only then launch the full `23`-fit crash-only relaunch

Reason for the canary:

- this keeps the 23-fit surface as the authoritative target
- while still avoiding a blind full relaunch before validating the new `s`-freeze behavior

## 9) What This Plan Does Not Claim

This plan does **not** claim that latent `s` is already proven to be the root cause.

What it claims is narrower:

- the hard crash is still the latent-`v` family
- latent `s` is structurally upstream and downstream of that unstable step
- the current relaunch surface should therefore stabilize `s` coherently with `v` before we escalate to more disruptive kernel changes

If the `s`-freeze relaunch still fails broadly, the next escalation should be:

- stronger latent-state rescue or reinitialization
- or a more fundamental kernel change

But the next immediate step should be the cleaner latent-state freeze experiment above.

## 10) Bottom Line

The repo is ready to prepare a fresh relaunch of the original `23` hard numerical MCMC crashes.

The right next preparation step is:

- keep the current preserved source-run and artifact surface fixed
- add a dedicated MCMC latent `s` freeze schedule
- test and document it cleanly
- then relaunch the 23-fit crash-only surface from the original failed-only manifests

That keeps the next wave:

- well documented
- reproducible
- isolated from prior residual-failure experiments
- and directly grounded in the actual source campaign that still defines the repair target.
