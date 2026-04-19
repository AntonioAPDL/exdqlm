# PLAN: QDESN tau050 Remaining-Failed MCMC v2 Implementation And Relaunch Checklist

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## 1) Purpose

This is the canonical implementation and relaunch plan for the remaining failed
QDESN tau050 MCMC cases after:

- the source refreshed-main campaign completed at `121 / 144` fit successes and
  `23 / 144` fit failures; and
- the first failed-only rerun completed at `5 / 23` recoveries and `18 / 23`
  repeat failures.

This plan is intended to be followed operationally, one checklist at a time, in
 a way that is:

- well tested;
- well documented;
- reproducible;
- explicit about file ownership and change scope;
- careful not to mix old and new rerun specifications.

This note consolidates and supersedes the execution details that were
distributed across the earlier handoff, investigation, and comparison notes.

## 2) Current Problem

### Confirmed remaining-failure surface

The exact remaining failed inventory is:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv`

Current counts:

- remaining `mcmc_al` failures: `7`
- remaining `mcmc_exal` failures: `11`
- total remaining failed fits: `18`

### Dominant failure mode

All `18 / 18` repeat failures are still hard MCMC runtime crashes in the
latent-`v` sampling path:

- `exal_mcmc_fit::latent_v returned ... invalid draws ... value=NA`

This is a runtime-failure problem, not merely a mixing or signoff problem.

### Key empirical read

The first rerun already proved that warmup helps:

- it recovered `5 / 23` previously failed fits;
- recovery was strongest at low `tau`;
- but half of the remaining failures now occur late enough that startup-only
  warmup is probably not sufficient by itself.

So the next move should be:

1. warmup-led again;
2. but more coherent than the first rerun;
3. directly targeted at `latent_v`;
4. instrumented well enough to explain the next failures;
5. launched in stages, not as one blind remaining-18 rerun.

## 3) Study Context

### Data surface

This is the dynamic-only QDESN validation surface:

- scenario: `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- quantiles:
  - `0.05`
  - `0.25`
  - `0.50`
- effective sizes:
  - `500`
  - `5000`

### Model / inference surface

QDESN readout:

- deep DESN reservoir profile:
  - `deep_d3_n100x3_skip100_w300_m30`
- readout input mode:
  - `raw_y_lags`
- lag structure:
  - `m_y = 12`
  - `m_x = 0`

Inference:

- VB:
  - LDVB
- MCMC:
  - slice-based kernel
  - LDVB warm start
- likelihood families:
  - `al`
  - `exal`
- beta priors:
  - `ridge`
  - `rhs_ns`

Important prior policy:

- raw `rhs` is excluded from the canonical refreshed-main lane
- the active lane is `ridge + rhs_ns`
- under `rhs_ns`, tau warmup/freeze must remain explicit in both VB-init and
  MCMC

## 4) High-Level Strategy

### Primary objective

Recover the remaining failed MCMC cases without contaminating the canonical
refreshed-main defaults or losing reproducibility across rerun specs.

### Primary levers for v2

The v2 recovery package should be built around four coordinated levers:

1. stronger and smoother warmup continuity from the existing rerun;
2. direct MCMC `latent_v` warmup;
3. richer persisted failure instrumentation;
4. staged pilot-first rerun execution.

### Secondary levers

These should stay secondary, to be used only if the v2 warmup package still
leaves a substantial late-failure subset:

1. `exal` kernel pilot:
   - `core_update_mode = "gamma_sigma_gamma"`
2. conditioning pilot:
   - `mcmc_control$conditioning$mode = "qr_whiten"`
3. `rhs_ns` burn-phase width adaptation
4. smaller slice widths for an `exal`-only secondary arm

### Non-goals for the first v2 pass

Do not do these first:

1. do not change the canonical refreshed-main defaults YAML in-place for the
   remaining-failure rerun;
2. do not rerun all `144` fits;
3. do not add a new raw `rhs` lane;
4. do not make slice-width tuning the first global change;
5. do not mix prepare-only output, v1 rerun output, and v2 rerun output under
   the same run tags or report folders.

## 5) Canonical v2 Spec To Build

### Keep from the current stronger warmup package

Carry forward:

- VB warm-start `min_iter_elbo = 80`
- VB RHS-NS tau freeze = `50`
- MCMC RHS-NS tau freeze burn-in = `500`
- package-off / study-on `sigmagam` controls

### Strengthen for v2

Recommended v2 pilot defaults:

- VB warm-start:
  - `max_iter = 500`
  - `min_iter_elbo = 80`
- VB `sigmagam`:
  - `freeze_warmup_iters = 20`
  - `postwarmup_damping = 0.35`
  - `postwarmup_damping_iters = 10`
  - `min_postwarmup_updates = 3`
- MCMC `sigmagam`:
  - `freeze_burnin_iters = 500`

### New v2 `latent_v` warmup

Recommended first implementation:

- new normalized block:
  - `mcmc.latent_v.*`
- package default:
  - off
- study v2 default:
  - on

Recommended first pilot settings:

- `freeze_burnin_iters = 50`
- `freeze_only_during_burn = true`
- `sparse_update_every = 10`
- `sparse_update_until_iter = 500`
- `force_first_postwarmup_update = true`
- `trace = true`

Intended semantics:

1. iterations `1:50`
   - hold `v` fixed at its current initialized state
2. iterations `51:500`
   - update `v` only every 10th iteration
   - otherwise carry forward the last valid `v`
3. after iteration `500`
   - return to standard per-iteration `v` updates
4. at the first thawed update
   - force a real `v` update
   - record that event explicitly in traces

Why this is the recommended first design:

- it directly targets the known crash block;
- it protects the fragile early regime;
- it is smoother than a very long hard freeze;
- it preserves a clear warmup boundary that can be tested and documented.

## 6) Files To Modify

### Core config normalization

Modify:

- `R/exal_inference_config.R`

Add:

- default `mcmc$latent_v` control block
- validation and normalization logic for:
  - `freeze_burnin_iters`
  - `freeze_only_during_burn`
  - `sparse_update_every`
  - `sparse_update_until_iter`
  - `force_first_postwarmup_update`
  - `trace`

Requirements:

- package defaults must leave the feature off
- resolved controls must be serializable into `fit_request.json`
- study-level YAML must be able to override them cleanly

### Core MCMC implementation

Modify:

- `R/exal_mcmc_fit.R`

Add:

- `latent_v` warmup scheduler
- stateful trace vectors
- persisted failure instrumentation around the latent-`v` GIG draw

Implementation requirements:

1. preserve existing behavior when `latent_v` warmup is off;
2. keep all control logic local and explicit, not implicit through unrelated
   warmup flags;
3. record at least:
   - `latent_v_warmup_active_trace`
   - `latent_v_update_performed_trace`
   - `latent_v_update_reason_trace`
   - `latent_v_force_update_trace`
4. persist failure-state fields when the `latent_v` draw fails:
   - iteration
   - burn vs keep phase
   - `sigma`
   - `gamma`
   - `tau` when present
   - `c2` when present
   - summaries of `chi_v`
   - summaries of `psi_v`
   - whether `latent_v` warmup was active

### Validation export

Modify:

- `R/qdesn_mcmc_validation.R`

Add:

- compact MCMC summary export for `latent_v` warmup
- compact persisted failure-summary export

Requirements:

- do not assume MCMC `progress_trace.csv` captures burn-in behavior;
- export full burn/keep warmup state into `misc` and concise fit-level summary
  fields;
- make failure-state information survive a halted fit.

### Study-specific v2 config

Add:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml`

Requirements:

- keep it separate from:
  - `qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`
- clearly encode:
  - carried-forward tau policy
  - strengthened `sigmagam` policy
  - new `latent_v` warmup policy
- scope it only to the remaining-failure rerun surface

### Wrappers and launch plumbing

Modify or extend:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

Either:

1. add dedicated v2 phases, or
2. add a new paired v2 wrapper if phase branching becomes too crowded

Preferred naming:

- `remaining_failed_mcmc_al_v2`
- `remaining_failed_mcmc_exal_v2`

### Tests

Modify:

- `tests/testthat/test-exal-inference-config.R`
- `tests/testthat/test-exal-mcmc.R`
- `tests/testthat/test-qdesn-sigmagam-warmup-validation-export.R`

Add if needed:

- `tests/testthat/test-qdesn-latent-v-warmup-validation-export.R`
- `tests/testthat/test-qdesn-dynamic-tau050-remaining-failed-mcmc-v2-config.R`

## 7) Implementation Order

The implementation must follow this order.

### Phase A: Freeze baseline and inventory

Goal:

- make the exact v2 target surface immutable before changing code

Checklist:

- [ ] rerun `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_grids.R`
- [ ] verify the counts are still `7 + 11 = 18`
- [ ] write or refresh a short report note if the counts changed
- [ ] capture `git status --short`
- [ ] capture `git diff --stat`
- [ ] do not launch any compute from this phase

### Phase B: Add instrumentation first

Goal:

- make the next failure wave more informative even if recovery is incomplete

Checklist:

- [ ] add normalized instrumentation controls if needed in `R/exal_inference_config.R`
- [ ] implement persisted latent-`v` failure-state capture in `R/exal_mcmc_fit.R`
- [ ] export compact failure-state fields in `R/qdesn_mcmc_validation.R`
- [ ] add tests proving that failure-state summaries survive a simulated halted fit
- [ ] document the new summary fields in a dedicated report or proposal note

Gate to proceed:

- all new instrumentation tests pass

### Phase C: Add `latent_v` warmup controls and scheduler

Goal:

- implement the new direct recovery lever

Checklist:

- [ ] add `mcmc.latent_v` defaults and resolver logic in `R/exal_inference_config.R`
- [ ] implement hard-freeze window in `R/exal_mcmc_fit.R`
- [ ] implement sparse-update window in `R/exal_mcmc_fit.R`
- [ ] implement forced first post-warmup update
- [ ] add trace vectors and trace summaries
- [ ] ensure feature-off behavior exactly matches legacy behavior

Gate to proceed:

- resolver and engine tests pass

### Phase D: Strengthen the v2 warmup package coherently

Goal:

- align the rest of the warmup contract with the new `latent_v` schedule

Checklist:

- [ ] create `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml`
- [ ] carry forward current tau freeze policy exactly
- [ ] raise VB `sigmagam.freeze_warmup_iters` to `20`
- [ ] set VB `sigmagam.postwarmup_damping = 0.35`
- [ ] set VB `sigmagam.postwarmup_damping_iters = 10`
- [ ] set VB `sigmagam.min_postwarmup_updates = 3`
- [ ] set VB warm-start `max_iter = 500`
- [ ] set MCMC `sigmagam.freeze_burnin_iters = 500`
- [ ] encode the new `latent_v` warmup study defaults

Gate to proceed:

- config-resolution tests and study-config tests pass

### Phase E: Extend wrappers and reporting

Goal:

- make the v2 rerun operationally launchable and inspectable

Checklist:

- [ ] add or wire `remaining_failed_mcmc_al_v2`
- [ ] add or wire `remaining_failed_mcmc_exal_v2`
- [ ] ensure both phases point to the v2 defaults YAML
- [ ] ensure both phases use the exact remaining-failure CSV inventories
- [ ] ensure report folders clearly separate v1 and v2
- [ ] ensure healthcheck surfaces the new `latent_v` summary fields

Gate to proceed:

- wrapper tests and prepare-only validation pass

### Phase F: Test battery before any live compute

Goal:

- prove the code path is correct before launching new MCMC jobs

Required test checklist:

- [ ] `test-exal-inference-config.R` passes for new `latent_v` controls
- [ ] `test-exal-mcmc.R` passes for:
  - freeze window
  - sparse-update window
  - forced first thawed update
  - feature-off legacy behavior
  - failure instrumentation persistence
- [ ] validation-export tests pass for the new summary fields
- [ ] study-config tests pass for the v2 defaults
- [ ] no unrelated tests are regressed in the touched area

Recommended command family:

- targeted `testthat::test_local(...)` for touched files first
- then the nearest broader regression band covering config, MCMC, and export

Gate to proceed:

- all targeted tests pass cleanly

### Phase G: Prepare-only proof

Goal:

- verify that launch materialization is correct without starting compute

Checklist:

- [ ] run prepare-only for `remaining_failed_mcmc_al_v2`
- [ ] run prepare-only for `remaining_failed_mcmc_exal_v2`
- [ ] inspect generated `fit_request.json` files
- [ ] confirm serialized v2 controls are present:
  - tau warmup
  - `sigmagam` warmup
  - `latent_v` warmup
- [ ] archive worktree snapshots in launch folders:
  - `worktree_status.txt`
  - `worktree_diff_stat.txt`
  - `worktree.diff`
- [ ] write a prepare-only report

Gate to proceed:

- both prepare-only phases pass and serialize the expected controls

### Phase H: Canary launch

Goal:

- test the new spec on a small but representative subset before the full `18`

Recommended canary design:

- one early-failing `mcmc_al` case
- one late-failing `mcmc_al` case
- one early-failing `mcmc_exal` case
- one late-failing `mcmc_exal` case
- include at least one `gausmix`
- include at least one `tau=0.50`

Checklist:

- [ ] materialize a canary subset manifest
- [ ] launch canary only
- [ ] monitor startup behavior and first thaw boundary
- [ ] inspect whether new failure instrumentation is populated on any crash
- [ ] compare canary outcomes against the v1 rerun on the same cases
- [ ] write a canary report before scaling up

Scale-up gate:

- proceed only if the canary is at least directionally better than v1

### Phase I: Full remaining-failure v2 relaunch

Goal:

- rerun the exact remaining `18` failed fits under the v2 spec

Checklist:

- [ ] launch `remaining_failed_mcmc_al_v2`
- [ ] launch `remaining_failed_mcmc_exal_v2`
- [ ] keep separate run tags for `al` and `exal`
- [ ] capture tmux session names
- [ ] run periodic healthchecks
- [ ] save launch-time worktree snapshots
- [ ] write a launch report the same day

### Phase J: Decision after v2 completes

Goal:

- decide whether warmup-v2 is enough or whether a secondary kernel arm is
  justified

Checklist:

- [ ] compare recovery rate vs v1 rerun
- [ ] split remaining failures by:
  - early burn
  - late keep
  - family
  - tau
  - prior
- [ ] inspect the new failure-state summaries
- [ ] if late keep failures still dominate, prepare a kernel-v1 pilot with:
  - `gamma_sigma_gamma` for `exal`
  - optional `qr_whiten`
  - optional `rhs_ns` width adaptation
- [ ] do not open all secondary knobs at once

## 8) Test Matrix

This is the minimum test matrix that must exist before live v2 rerun launch.

### Resolver tests

Checklist:

- [ ] default `mcmc.latent_v` resolves to off
- [ ] study YAML resolves requested v2 `latent_v` settings correctly
- [ ] invalid combinations fail cleanly

### Engine tests

Checklist:

- [ ] `latent_v` stays fixed during hard-freeze window
- [ ] sparse update fires only on scheduled iterations
- [ ] first thawed update is forced
- [ ] trace outputs reflect actual behavior
- [ ] feature-off behavior matches legacy path

### Failure instrumentation tests

Checklist:

- [ ] failure summary records iteration
- [ ] failure summary records phase
- [ ] failure summary records `sigma`, `gamma`
- [ ] failure summary records `tau` / `c2` when present
- [ ] failure summary records `chi_v` / `psi_v` summaries
- [ ] failure summary records warmup-active state

### Export tests

Checklist:

- [ ] fit-level summary exports latent-`v` warmup fields
- [ ] fit-level summary exports latent-`v` failure fields
- [ ] export logic handles halted fits without dropping summaries

### Study-config tests

Checklist:

- [ ] v2 defaults YAML resolves correctly
- [ ] `remaining_failed_mcmc_al_v2` phase targets only the AL remaining-failure grid
- [ ] `remaining_failed_mcmc_exal_v2` phase targets only the EXAL remaining-failure grid

## 9) Documentation And Reproducibility Rules

These rules are mandatory for the v2 rerun.

### Documentation checklist

- [ ] maintain this plan as the canonical execution checklist
- [ ] write a prepare-only report
- [ ] write a same-day launch report
- [ ] write a completion report
- [ ] write a postmortem report if v2 still leaves unresolved failures

### Reproducibility checklist

- [ ] never overwrite v1 rerun folders
- [ ] keep v2 defaults in a separate YAML
- [ ] keep v2 phases separate from canonical refreshed-main phases
- [ ] save worktree snapshots in every prepare/launch folder
- [ ] ensure `fit_request.json` contains resolved v2 control values
- [ ] record exact run tags, session names, and commit hash at launch
- [ ] keep the remaining-failure inventory CSVs as frozen manifests for the rerun

### Change-control checklist

- [ ] do not mix code changes and live launches without rerunning the targeted test battery
- [ ] do not relaunch from an undocumented spec change
- [ ] if the v2 spec changes after canary, mint a new explicit spec or phase name

## 10) Immediate Next Actions

This is the exact short sequence to start from now.

1. Refresh the remaining-failure inventory and confirm the target is still `18`.
2. Implement latent-`v` failure instrumentation first.
3. Implement `mcmc.latent_v` controls and scheduler.
4. Add validation-export coverage for the new fields.
5. Add the dedicated v2 defaults YAML.
6. Wire new v2 phases into launch and healthcheck.
7. Pass the targeted test battery.
8. Run prepare-only for both v2 phases.
9. Launch a canary subset.
10. Only then launch the full remaining-18 rerun.

## 11) Primary References

Read together with:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_handoff_20260418.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_comparison_with_refreshed288_20260418.md`
- `docs/PROPOSAL__qdesn_sigmagam_warmup_design_20260417.md`

Operational inventory:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv`

Core implementation files:

- `R/exal_inference_config.R`
- `R/exal_mcmc_fit.R`
- `R/qdesn_mcmc_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
