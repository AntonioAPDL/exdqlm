# Refreshed288 Runtime-Failure Final Implementation Plan

Date: `2026-04-18`

Scope:

- this plan starts only **after** the active canonical refreshed288 relaunch has fully finished
- this plan covers only the **runtime / numerical crash** cohort
- this plan does **not** cover static post-fit mixing failures

Primary references:

- `reports/static_exal_tuning_20260418/refreshed288_runtime_failure_investigation_and_rerun_plan_20260418.md`
- `reports/static_exal_tuning_20260418/refreshed288_runtime_failure_vs_qdesn_comparison_and_plan_20260418.md`
- `tools/merge_reports/LOCAL_refreshed288_extract_runtime_failure_audit_20260418.R`

## 1. Goal

Deliver one clean, reproducible, crash-focused rerun lane for the dynamic numerical failures in the
refreshed288 study.

This lane must:

- stay separate from static gate-fail / mixing issues
- use one frozen rerun contract
- be fully documented
- be fully reproducible
- be staged and tested before any full failed-row relaunch

## 2. What We Are Solving

Current scientific split:

- static MCMC `FAIL` rows are mainly post-fit chain-health / mixing failures
- dynamic `FAIL` rows are numerical/runtime crashes

Current dynamic runtime signatures:

- `invalid state before chi update`
- `chi has ... non-finite values`
- `ldvb_q_t1 is NA`

Current structural interpretation:

- DQLM failures are dominated by the early `Ut` path
- exDQLM failures are dominated by the early `Ut/st` path before the slice gamma step
- direct dynamic VB failures are LDVB failures, not MCMC failures

Therefore the current crash-focused solution must be:

- stronger VB initialization
- stronger and more coherent warmup
- explicit latent-state warmup
- better failure instrumentation
- only secondary slice sensitivity

## 3. Guiding Rules

We will follow these rules throughout:

1. Never mutate the active canonical run root.
2. Never mix runtime-failure reruns with static mixing/gate-fail reruns.
3. Never launch from memory or chat context alone; always regenerate the runtime-failure manifest.
4. Never change multiple major levers at once without recording the exact rerun arm.
5. Keep the primary rerun arm focused on init quality plus latent-state warmup, not slice tuning.
6. Use a fresh run tag and fresh run root for every launchable crash-focused rerun.
7. Commit and push code/docs before launching.

## 4. Final Strategy

The final strategy has four technical components:

### A. Stronger init

Use stronger LDVB settings for:

- direct dynamic VB rerun
- dynamic MCMC VB warm starts

### B. Latent-state warmup

Add explicit MCMC warmup/freeze scheduling to the earliest fragile latent block:

- DQLM: `Ut`
- exDQLM: `Ut + st`

### C. DQLM sigma-only warmup

Add an explicit sigma freeze/warmup in the DQLM branch because current `sigmagam` warmup only
protects the exDQLM branch.

### D. Failure instrumentation

Persist richer failure-state details around the pre-`Ut` / pre-`chi` failure path so future reruns
are evidence-driven.

## 5. Final Target Spec

### 5.1 Direct dynamic VB runtime rerun

Applies to the direct dynamic VB crash lane.

Target settings:

- `vb_max_iter = 800`
- `vb_min_iter = 80`
- `vb_tol = 0.01`
- `sigmagam_vb_warmup_iters = 50`
- `sigmagam_vb_min_postwarmup_updates = 5`
- `sigmagam_vb_postwarmup_damping = 0.5`
- `sigmagam_vb_postwarmup_damping_iters = 5`

### 5.2 Dynamic MCMC VB-init rerun

Target settings:

- `vb_init_max_iter = 800`
- `vb_init_min_iter = 80`
- `vb_init_tol = 0.01`
- `vb_init_n_samp = 5000`
- `vb_init_sigmagam_warmup_iters = 50`
- `vb_init_sigmagam_min_postwarmup_updates = 5`
- `vb_init_sigmagam_postwarmup_damping = 0.5`
- `vb_init_sigmagam_postwarmup_damping_iters = 5`

### 5.3 Dynamic latent-state warmup

Primary pilot defaults:

- `freeze_burnin_iters = 100`
- `freeze_only_during_burn = TRUE`
- `force_after_warmup = TRUE`

Mode by branch:

- DQLM: `u_only`
- exDQLM: `u_st_pair`

Warmup behavior:

- DQLM during warmup: hold `Ut` fixed at its VB-init value
- exDQLM during warmup: hold both `Ut` and `st` fixed at their VB-init values
- first post-warmup iteration: force one real latent-state update

### 5.4 DQLM sigma-only warmup

Primary pilot defaults:

- `freeze_burnin_iters = 500`
- `freeze_only_during_burn = TRUE`
- `force_after_warmup = TRUE`

### 5.5 exDQLM sigmagam warmup

Keep the already-planned stronger setting:

- `sigmagam_mcmc_warmup_iters = 500`

### 5.6 Slice sensitivity

This is secondary only.

Primary rerun:

- keep `mh_proposal = "slice"`
- keep `slice_width = 0.10`
- keep `slice_max_steps = Inf`

Secondary exDQLM-only sensitivity arm:

- `slice_width = 0.05`
- keep `slice_max_steps = Inf`

## 6. Files We Will Modify

### Package code

- `R/exdqlmMCMC.R`

### Refreshed288 study wiring

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R`
- optionally `tools/merge_reports/LOCAL_refreshed288_prepare_20260416.R` if new method-profile or rerun-manifest generation is needed

### Tests

- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/test-static-diagnostics.R`

### Documentation and reproducibility artifacts

- a new runtime-failure rerun contract CSV
- a new runtime-failure rerun note
- refreshed crash manifest and watchlist

## 7. Implementation Order

This is the execution order we will follow.

### Phase 0. Wait For Canonical Completion

Do not touch the rerun lane until the current canonical run is fully finished.

Checklist:

- [ ] Confirm no refreshed288 workers are still running.
- [ ] Confirm the canonical launch session has finished.
- [ ] Confirm the final row-status files are no longer changing.

### Phase 1. Freeze The Final Crash Cohort

Use the audit script to regenerate the final runtime cohort after the canonical run ends.

Artifacts:

- refreshed runtime-failure manifest
- refreshed runtime-failure watchlist
- refreshed runtime-failure summary

Checklist:

- [ ] Re-run `tools/merge_reports/LOCAL_refreshed288_extract_runtime_failure_audit_20260418.R`.
- [ ] Confirm the watchlist is empty.
- [ ] Freeze the final runtime-failure manifest for the completed canonical run.
- [ ] Record final row counts by runtime mode and by method lane.

### Phase 2. Add Failure Instrumentation

Modify `R/exdqlmMCMC.R` to persist better failure-state detail around the earliest latent-state
failure path.

Instrumentation requirements:

- iteration index
- burn vs keep phase
- sigma
- gamma when present
- `reg1` finite flag
- max abs `reg1`
- max abs `theta`
- summaries of `chi`
- summaries of `psi`
- latent-state warmup state
- DQLM sigma warmup state

Checklist:

- [ ] Add DQLM pre-`Ut` instrumentation.
- [ ] Add exDQLM pre-`Ut` / pre-`chi` instrumentation.
- [ ] Ensure failure diagnostics survive `failed_runtime`.
- [ ] Ensure diagnostics are accessible from returned `misc` / row-level outputs.

### Phase 3. Add Latent-State Warmup Controls

Add a dedicated control surface in `R/exdqlmMCMC.R`.

Recommended control names:

- `latent_state_controls`
- fields:
  - `freeze_burnin_iters`
  - `freeze_only_during_burn`
  - `force_after_warmup`
  - `mode`

Checklist:

- [ ] Add control parsing and defaults.
- [ ] Implement DQLM `Ut` warmup behavior.
- [ ] Implement exDQLM `Ut/st` warmup behavior.
- [ ] Add trace fields showing whether latent-state warmup was active.
- [ ] Add summary diagnostics for latent-state warmup activity.

### Phase 4. Add DQLM Sigma-Only Warmup

Add a DQLM-only sigma warmup/freeze path.

Checklist:

- [ ] Add a DQLM sigma warmup control surface.
- [ ] Freeze sigma during early burn as specified.
- [ ] Force one first post-warmup sigma update.
- [ ] Export DQLM sigma warmup diagnostics.

### Phase 5. Wire The Crash-Focused Study Controls

Push the new controls into refreshed288 method profiles and row-runner wiring.

Checklist:

- [ ] Add crash-rerun-specific method profiles in `LOCAL_refreshed288_helpers_20260416.R`.
- [ ] Serialize latent-state warmup controls into the method registry.
- [ ] Serialize DQLM sigma warmup controls into the method registry.
- [ ] Ensure the row runner passes these controls into `exdqlmMCMC()`.
- [ ] Create a fresh runtime-failure rerun contract CSV.

### Phase 6. Testing

This phase must complete before any launch.

Required test classes:

- unit tests for control resolution
- unit tests for latent-state warmup scheduling
- unit tests for DQLM sigma warmup scheduling
- regression tests for current sigmagam warmup behavior
- trace / diagnostics export tests
- manifest / method-registry serialization tests

Checklist:

- [ ] Extend `tests/testthat/test-vb-mcmc-convergence-controls.R`.
- [ ] Extend `tests/testthat/test-static-diagnostics.R`.
- [ ] Add assertions for latent-state warmup traces and summaries.
- [ ] Add assertions for DQLM sigma warmup traces and summaries.
- [ ] Rebuild the method registry and verify the new fields.
- [ ] Run the focused test slice and review results.

### Phase 7. Documentation Freeze

Before launching, freeze the new crash-rerun documentation.

Required artifacts:

- final runtime-failure manifest
- final runtime-failure rerun contract
- launch note for the crash-focused rerun
- explicit run tag and variant tag

Checklist:

- [ ] Write the crash-rerun launch note.
- [ ] Freeze the method registry used by the rerun.
- [ ] Freeze the rerun contract CSV.
- [ ] Record the exact git SHA and branch.
- [ ] Commit and push all code/docs before launch.

### Phase 8. Staged Launch

Launch in three stages, never all at once first.

#### Stage A. Direct VB crash lane

Checklist:

- [ ] Run the direct dynamic VB crash row(s) first.
- [ ] Confirm no runtime failure remains in that direct VB lane.

#### Stage B. Representative pilot

Pilot rows should cover:

- DQLM `invalid_pre_chi`
- exDQLM `nonfinite_chi`
- `ldvb_q_t1 is NA`
- more than one family
- at least one `TT5000` case

Suggested first pilot set:

- `6`
- `8`
- `12`
- `30`
- `54`
- `72`

Checklist:

- [ ] Launch only the representative pilot rows.
- [ ] Review row-level artifacts, not just terminal status.
- [ ] Confirm whether runtime failures were eliminated or materially reduced.
- [ ] Confirm the new diagnostics are informative if any row still fails.

#### Stage C. Full crash cohort rerun

Checklist:

- [ ] Expand only if the representative pilot is favorable.
- [ ] Use the frozen runtime-failure manifest from the completed canonical run.
- [ ] Launch under a new dedicated run tag and run root.
- [ ] Keep logs detached and durable.

### Phase 9. Secondary Slice Sensitivity, Only If Needed

Do this only for exDQLM if the primary stronger-init plus latent-state-warmup arm still crashes.

Checklist:

- [ ] Open a separate exDQLM-only secondary arm.
- [ ] Change only `slice_width` to `0.05`.
- [ ] Keep all other primary-arm settings fixed.
- [ ] Document this as a secondary sensitivity arm, not the canonical primary rerun.

## 8. Reproducibility Contract

Every launchable crash-focused rerun must have:

- a fresh run tag
- a fresh variant tag
- a fresh run root
- a frozen manifest
- a frozen method registry
- a frozen rerun contract
- the exact git SHA
- the exact launch command
- the exact worker caps
- detached durable logs

Minimum required files to freeze:

- runtime-failure manifest CSV
- runtime-failure rerun contract CSV
- method registry CSV
- launch note markdown
- live launcher log path

## 9. What We Will Not Do

- We will not resume the crash cohort inside the canonical run root.
- We will not merge crash reruns with static mixing reruns.
- We will not use slice tuning as the primary first lever.
- We will not launch the full crash cohort before a pilot.
- We will not rely on stale row counts from chat summaries.

## 10. Definition Of Success

The primary crash-focused rerun is considered successful if:

- the direct dynamic VB crash lane no longer runtime-fails
- the representative pilot no longer shows the same dominant startup crashes, or shows a clear and documented reduction
- the crash-focused full rerun can be launched from one frozen, reproducible contract
- every remaining failure is accompanied by richer failure-state diagnostics than the current run

## 11. Immediate Next Step After Current Run Finishes

The first action to take after the current canonical run finishes is:

1. rerun the audit script
2. freeze the final runtime-failure manifest
3. start Phase 2 instrumentation in `R/exdqlmMCMC.R`

That is the official start of the post-canonical crash-recovery plan.
