# QDESN Gamma Sigma Warmup Design Proposal

- date: `2026-04-17`
- repo target: `qdesn_0p4p0_integration`
- scope: design and implementation blueprint only; no `gamma/sigma` warmup code is implemented in this document

## Goal

Define a qdesn-native plan for adding an explicit, reproducible, auditable
warmup or freeze policy for the joint likelihood-side `gamma/sigma` block in:

1. direct VB;
2. the LDVB warm start used by MCMC; and
3. direct MCMC.

This note is intentionally close in spirit to the refreshed288 design note, but
it is adapted to the active qdesn branch and the actual code and validation
surfaces that are running now.

## Scope And Status

What this note does:

- identifies the exact qdesn insertion points;
- recommends qdesn-native control placement;
- defines intended semantics for VB and MCMC warmup;
- spells out diagnostics, validation export, reproducibility, and testing;
- gives a staged qdesn-first implementation order.

What this note does not do:

- it does not implement `sigmagam` warmup yet;
- it does not change the current interrupted or already-running validation run;
- it does not activate any new defaults in the refreshed-main YAML yet.

## Repo Targeting

We now have two related but different design surfaces.

| target | repo path | role | how to use it |
|---|---|---|---|
| refreshed288 / broad documentation backbone | `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration` | more general design note, broader study-facing framing | keep as the high-level backbone |
| active qdesn continuation | `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration` | actual implementation surface for the current qdesn continuation | this note is the implementation-facing plan for qdesn |

Interpretation:

- the refreshed288 note remains useful as the broad design backbone;
- qdesn should not implement that note verbatim;
- the current work should follow qdesn-native config resolution, engine, and
  validation-export paths.

## Terminology

Preferred terminology:

- public docs, YAML, reports, and health summaries: `sigmagam`
- internal object names may continue to use existing local names such as
  `qsiggam`, `eta_sigma`, `eta_gamma`, and similar engine-local variables

Reason:

- `sigmagam` is easier to read in YAML and documentation;
- the existing internal code names are already serviceable and do not need to
  be renamed just to support this feature.

## Background

The qdesn branch already has an explicit warmup/freeze policy for the
`rhs_ns`-side `tau` block:

- direct VB now carries explicit tau-freeze controls through the inference
  resolver into the active `rhs_ns` prior object;
- the MCMC LDVB warm start inherits the same explicit tau controls;
- MCMC carries an explicit `freeze_tau_burnin_iters` policy.

That gives us a strong template:

- explicit controls;
- deterministic early-iteration behavior;
- diagnostics that can be audited after the fact;
- resolved settings captured in run metadata rather than hidden in package
  defaults.

What we do not have yet is the corresponding warmup system for the joint
likelihood-side `gamma/sigma` block.

Current stabilization is only indirect:

- VB damping and mode checks;
- VB convergence thresholds;
- MCMC burn-in;
- MCMC slice settings and repeated core passes;
- optional VB warm starts.

Those matter, but they are not the same as a true warmup scheduler.

## Current QDESN State

Current truth in the active qdesn repo:

| block | current behavior | interpretation |
|---|---|---|
| direct VB | `q(sigma,gamma)` is refreshed every VB iteration through the joint LD block | stabilized, but not warmup-aware |
| MCMC LDVB warm start | inherits the same direct VB behavior | stabilized, but not warmup-aware |
| direct MCMC | `sigma/gamma` are refreshed every iteration through the core slice update loop | burn-in exists, but not block-specific warmup |
| validation export | VB exposes per-iteration traces; MCMC export mostly exposes kept draws | asymmetric export surface |

So the present state is simple:

- there is no explicit `sigmagam` warmup scheduler in qdesn;
- there is no explicit `sigmagam` freeze trace;
- there is no explicit forced first post-warmup `sigmagam` update.

## Important QDESN-Specific Fact

The active qdesn MCMC loop samples latent `v` before the `sigma/gamma` block.

Relevant file:

- `R/exal_mcmc_fit.R`

Operational implication:

- MCMC-side `sigmagam` freezing alone cannot change the first fragile
  `latent_v` regime;
- VB-side `sigmagam` warmup is the higher-leverage first intervention, because
  it changes the startup state that MCMC inherits.

This is the main reason the recommended order in qdesn is:

1. implement VB `sigmagam` warmup first;
2. implement MCMC `sigmagam` warmup second.

## Exact QDESN Package-Side Insertion Points

### Config Resolution

Primary file:

- `R/exal_inference_config.R`

Important surfaces:

- `.exal_default_vb_args_base()`
- `.exal_default_mcmc_control()`
- `.exal_resolve_vb_config()`
- `.exal_resolve_mcmc_config()`
- `resolve_exal_inference_config()`
- `resolve_exal_quantile_fit_spec()`

Why this is the right home:

- qdesn already centralizes resolved inference settings here;
- this is the cleanest place to keep the feature explicit, reproducible, and
  study-config-driven;
- it avoids scattering feature semantics across launch scripts and fit wrappers.

### Direct VB And MCMC Warm-Start VB

Primary file:

- `R/exal_ldvb_engine.R`

Current joint block:

- the engine initializes `qsiggam` from the starting `gamma/sigma` state;
- it computes initial `xis` from that starting `qsiggam`;
- it updates `q(beta)`, `q(v)`, and `q(s)` first;
- it then refreshes `q(sigma,gamma)` jointly through `find_mode_ld()`;
- it records `gamma_trace`, `sigma_trace`, `elbo_trace`, and RHS traces in
  `misc`.

Why this is the right insertion point:

- this engine is used directly for VB and indirectly as the MCMC LDVB warm
  start;
- freezing here changes the startup state inherited by MCMC;
- the current engine structure already lets us gate the joint LD refresh
  without rewriting the rest of the VB loop.

### Direct MCMC

Primary file:

- `R/exal_mcmc_fit.R`

Current relevant structure:

- latent `v` is sampled first;
- `s` and `beta` follow;
- RHS-family updates happen before the core `sigma/gamma` block;
- `sigma/gamma` are updated inside `update_sigma_gamma_once()`;
- the core block may run multiple times per iteration through
  `core_extra_passes`;
- the engine already records freeze-like traces for RHS tau warmup.

Why this is the right insertion point:

- the engine already has the right control-style precedent through
  `rhs_tau_frozen_trace`;
- all core `sigma/gamma` accounting lives here already;
- this is where we must keep frozen iterations out of adaptation-like
  bookkeeping summaries.

### Validation Export

Primary file:

- `R/qdesn_mcmc_validation.R`

Current export fact:

- VB `progress_trace.csv` is a true per-iteration trace surface;
- MCMC `progress_trace.csv` is a kept-draw surface, not a burn-in trace.

Implication:

- VB `sigmagam` warmup state can be exported directly in the progress trace;
- MCMC `sigmagam` warmup state should primarily live in `fit$misc` and compact
  health-summary fields, because most warmup happens before kept draws exist.

## QDESN Study And Script Touch Points

Study-facing files:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

Role of these files:

- the YAML is the natural study-level home for future `sigmagam` controls;
- the launch and run scripts already pass resolved config through the existing
  qdesn pipeline;
- no algorithmic `sigmagam` logic should live in these scripts;
- after implementation, these scripts only need to materialize and report the
  new settings, not own the inference logic.

## Recommended Control Placement

For qdesn, the clean control surface is:

```yaml
pipeline:
  inference:
    vb:
      sigmagam:
        freeze_warmup_iters: 0
        force_after_warmup: true
        min_postwarmup_updates: 1
        trace: true
    mcmc:
      vb_warm_start_control:
        sigmagam:
          freeze_warmup_iters: 0
          force_after_warmup: true
          min_postwarmup_updates: 1
          trace: true
      sigmagam:
        freeze_burnin_iters: 0
        freeze_only_during_burn: true
        trace: true
        delay_accounting_until_after_warmup: true
```

Design intent:

- direct VB gets its own `sigmagam` block;
- the MCMC LDVB warm start gets its own nested `sigmagam` block under
  `vb_warm_start_control`;
- direct MCMC gets its own `mcmc.sigmagam` block.

This is better than overloading unrelated knobs because:

- it matches the current qdesn inference resolver structure;
- it keeps the feature explicit in manifests and `fit_request.json`;
- it avoids tying `sigmagam` warmup to RHS semantics or online-VB semantics.

Important non-recommendation:

- do not overload `vb$online$update_sigmagam` for this feature

Reason:

- that flag belongs to the online-VB path;
- reusing it for batch LDVB warmup would blur two different semantics.

## Package Defaults Versus Study Defaults

Recommended policy:

- package default: feature off
- study default: explicit and opt-in

That means:

- resolver defaults should set all `sigmagam` freeze lengths to `0`;
- no silent behavior change should occur in unrelated studies;
- refreshed-main or future pilot studies can turn the feature on explicitly in
  YAML.

Candidate first study defaults:

- direct VB and MCMC warm-start VB: `freeze_warmup_iters = 10`
- direct MCMC: `freeze_burnin_iters = 50`

Possible escalation arm if needed:

- direct VB and MCMC warm-start VB: test `freeze_warmup_iters = 20`

These are candidate study settings only. They should not be treated as package
defaults, and they should not be retrofitted into the already-running April 16
relaunch.

## Proposed VB Semantics

### Main Design

The VB design should freeze the joint `q(sigma,gamma)` block, not `gamma` and
`sigma` separately.

Reason:

- the current engine already treats them as a coupled LD approximation;
- a joint freeze is easier to reason about and easier to test;
- separate freezing would create extra state and extra failure modes without a
  clear benefit.

### Recommended Controls

```yaml
vb:
  sigmagam:
    freeze_warmup_iters: 10
    force_after_warmup: true
    min_postwarmup_updates: 1
    trace: true
```

### Intended Engine Behavior

During warmup:

- initialize `qsiggam` as usual from the starting `gamma/sigma` state;
- initialize `xis` as usual from that starting `qsiggam`;
- on each warmup iteration, skip the call to `find_mode_ld()`;
- carry forward the current `qsiggam` unchanged;
- still recompute or reuse the downstream quantities consistently so the rest
  of the loop remains well-formed.

After warmup:

- perform the first real `sigmagam` update explicitly;
- then resume normal per-iteration LD updates;
- record whether the first post-warmup update was forced.

### Why This Is Smooth In QDESN

Because the current engine already:

- seeds `qsiggam` before iteration `1`;
- computes initial `xis` before the main loop;
- isolates the joint `q(sigma,gamma)` refresh in one place.

So the implementation can be small and local:

- a warmup-aware gate before the joint LD refresh;
- trace fields recording whether the block was frozen or updated;
- no need to rewrite the rest of the VB loop.

### VB Convergence Guard

This is required.

Stopping should not be allowed until:

- `min_iter_elbo` is met;
- normal ELBO and parameter-stability conditions are met; and
- at least `min_postwarmup_updates` true post-warmup `sigmagam` refreshes have
  occurred.

Reason:

- otherwise a frozen `sigmagam` block can make the stopping rule look better
  than it really is;
- qdesn currently uses ELBO plus `gamma/sigma` stability in its stop logic, so
  this guard is necessary for honest convergence.

### Recommended VB Diagnostics

Add to `fit$misc` and to the VB progress trace surface:

- `sigmagam_frozen_trace`
- `sigmagam_update_performed_trace`
- `sigmagam_update_reason_trace`
- `sigmagam_update_count_trace`
- `sigmagam_forced_postwarmup_trace`

Recommended VB `progress_trace.csv` additions:

- `sigmagam_frozen`
- `sigmagam_update_reason`
- `sigmagam_update_count`
- `sigmagam_forced_postwarmup`

## Proposed MCMC Semantics

### Main Design

MCMC should freeze the whole `sigma/gamma` core block during the chosen warmup
window.

Recommended controls:

```yaml
mcmc:
  sigmagam:
    freeze_burnin_iters: 50
    freeze_only_during_burn: true
    trace: true
    delay_accounting_until_after_warmup: true
```

### Intended Engine Behavior

During MCMC `sigmagam` warmup:

- sample latent `v`, `s`, `beta`, and RHS-family blocks as usual;
- skip the `sigma/gamma` core update block entirely;
- keep `sigma`, `gamma`, `eta_sigma`, and `eta_gamma` unchanged for that
  iteration;
- record that the block was frozen.

After warmup:

- resume the normal core `sigma/gamma` update block;
- if desired later, support one explicit first post-warmup update flag for
  diagnostics, but that is optional for the first implementation.

### MCMC Ordering Caveat

This caveat must stay explicit in the design.

Because qdesn samples latent `v` before the `sigma/gamma` core update:

- MCMC `sigmagam` freezing does not repair the very first latent-`v` regime by
  itself;
- VB `sigmagam` warmup is the higher-leverage stabilization lever for startup;
- MCMC `sigmagam` warmup should be viewed as secondary stabilization rather
  than the first rescue mechanism.

### Kernel-Specific Accounting Rule

Frozen MCMC iterations must not contaminate kernel diagnostics.

That means:

- they should not be counted as real `sigmagam` proposal attempts;
- they should not inflate step-out or shrink summaries;
- if later we add adaptation windows for this block, frozen iterations should
  not count toward those windows either;
- if later we add refresh counters, frozen iterations should not be treated as
  true refreshes.

In the current qdesn slice-based core, that specifically means:

- zero or clearly flagged `sigmagam` accounting on frozen iterations;
- no accidental mixing of frozen iterations into slice-quality summaries.

### Recommended MCMC Diagnostics

Store in `fit$misc`:

- `sigmagam_frozen_trace`
- `sigmagam_update_count_trace`
- `sigmagam_steps_out_trace`
- `sigmagam_shrink_trace`

Add compact reporting fields to diagnostics and health summaries:

- `sigmagam_first_active_iter`
- `sigmagam_updates_burn`
- `sigmagam_updates_keep`
- `sigmagam_frozen_burn_rate`

## QDESN Validation Export Plan

The qdesn validation export surface is asymmetric, so the design should follow
that reality rather than fight it.

### VB Export

Use the existing VB `progress_trace.csv` surface in
`R/qdesn_mcmc_validation.R`.

Recommended additions:

- `sigmagam_frozen`
- `sigmagam_update_reason`
- `sigmagam_update_count`
- `sigmagam_forced_postwarmup`

This is natural because VB progress export is already full-iteration.

### MCMC Export

Do not rely on MCMC `progress_trace.csv` alone for warmup diagnostics.

Reason:

- MCMC progress export is built from kept draws;
- most `sigmagam` warmup will happen during burn-in.

Recommended approach:

- keep the full freeze and accounting traces in `fit$misc`;
- surface compact summary fields in `health_summary.csv`;
- only add kept-draw progress fields later if they serve a real reporting need.

This is the same design discipline already used for other burn-in-only or
engine-internal signals.

## Smooth QDESN Implementation Strategy

The qdesn-first implementation path should be:

1. add dormant config-resolver support with package defaults off;
2. implement VB `sigmagam` warmup and its convergence guard;
3. add VB diagnostics and VB validation-export fields;
4. implement MCMC `sigmagam` warmup with clean accounting;
5. add MCMC diagnostics and health-summary export;
6. only then wire explicit study-level settings into the refreshed-main YAML.

Why this order is preferred:

- VB warmup has the higher leverage on startup stability;
- the qdesn MCMC ordering caveat makes VB the better first intervention;
- export and diagnostics should land alongside the engine changes so the
  feature is auditable from the first implementation wave.

## Detailed QDESN Implementation Map

### Phase 1: Resolver Plumbing Only

Files:

- `R/exal_inference_config.R`

Changes:

- add dormant `vb$sigmagam` defaults;
- add dormant `mcmc$sigmagam` defaults;
- add dormant `mcmc$vb_warm_start_control$sigmagam` support;
- serialize these settings into resolved control objects even when set to `0`.

Outcome:

- no behavior change yet;
- reproducibility improves immediately because the future settings have a
  stable resolved home.

### Phase 2: VB Engine Support

Files:

- `R/exal_ldvb_engine.R`

Changes:

- gate the joint LD refresh with a warmup-aware condition;
- add the post-warmup forced-first-update logic;
- add the convergence guard requiring post-warmup updates;
- store the new traces in `fit$misc`.

Outcome:

- direct VB and MCMC warm-start VB gain explicit `sigmagam` warmup behavior.

### Phase 3: VB Validation Export

Files:

- `R/qdesn_mcmc_validation.R`

Changes:

- extend the VB progress-trace export to include the new `sigmagam` fields;
- keep column addition backward-compatible for runs that do not have the new
  fields yet.

Outcome:

- the feature is visible in normal qdesn validation artifacts.

### Phase 4: MCMC Engine Support

Files:

- `R/exal_mcmc_fit.R`

Changes:

- add a warmup-aware gate around the `sigma/gamma` core update block;
- add `sigmagam` freeze and accounting traces;
- ensure frozen iterations do not contaminate core slice bookkeeping.

Outcome:

- direct MCMC gains explicit and auditable `sigmagam` warmup behavior.

### Phase 5: MCMC Reporting

Files:

- `R/qdesn_mcmc_validation.R`

Changes:

- add compact MCMC `sigmagam` health-summary fields;
- avoid forcing burn-in-only signals into kept-draw progress tables unless they
  are truly useful.

Outcome:

- healthcheck and closeout reporting can see whether the feature was active and
  how much of the chain it affected.

### Phase 6: Study Wiring

Files:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`
- launch and healthcheck scripts only as needed for surfaced reporting

Changes:

- turn the feature on explicitly for a future study wave or smoke pilot;
- preserve package default off / study default on discipline;
- keep the resolved settings visible in manifests and `fit_request.json`.

Outcome:

- feature activation is explicit, reproducible, and study-scoped.

## Reproducibility Requirements

When this feature is implemented later, the run record should preserve:

- the exact YAML used;
- the git commit at launch time;
- the resolved `fit_request.json` artifacts;
- the run tag and tmux session;
- the health summary and progress-trace outputs that show whether warmup was
  active.

Key rule:

- never retrofit the current interrupted or already-running April 16 relaunch

If the feature is turned on later, it should happen in a fresh, explicitly
named relaunch.

## Testing Plan

### Config Resolver Tests

Files to extend:

- `tests/testthat/test-exal-inference-config.R`

Add tests that confirm:

- `vb.sigmagam.*` resolves correctly;
- `mcmc.sigmagam.*` resolves correctly;
- `mcmc.vb_warm_start_control.sigmagam.*` resolves correctly;
- default-off behavior remains stable.

### VB Engine Tests

Recommended new or extended coverage:

- a focused VB test that asserts `qsiggam` stays fixed during warmup;
- a test that asserts the first post-warmup update is performed when
  `force_after_warmup = TRUE`;
- a test that asserts convergence cannot stop before the required
  post-warmup updates happen.

### MCMC Engine Tests

Recommended new or extended coverage:

- a focused MCMC test that asserts the `sigmagam` block is skipped during the
  freeze window;
- a test that asserts frozen iterations do not inflate slice bookkeeping;
- a test that asserts the new freeze traces are recorded in `fit$misc`.

### Study Config Tests

Files to extend later, only after explicit activation:

- `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`

Add tests that confirm:

- the refreshed-main YAML materializes the intended `sigmagam` study settings;
- direct VB, MCMC warm-start VB, and direct MCMC all receive the intended
  settings.

## What We Should Not Do

Avoid these design traps:

- do not retrofit the current live run;
- do not hide the feature behind unrelated knobs;
- do not overload online-VB settings for the batch-LDVB path;
- do not make this a raw launch-script feature instead of a resolved inference
  feature;
- do not rely on kept-draw progress tables to explain burn-in-only MCMC
  behavior;
- do not let frozen MCMC iterations contaminate slice-quality summaries.

## Practical Recommendation

For the active qdesn continuation, the best path is:

1. keep this feature documentation-only for now;
2. implement dormant resolver support first with package defaults off;
3. implement VB `sigmagam` warmup first;
4. implement MCMC `sigmagam` warmup second;
5. wire the feature into a fresh study run only after tests and reporting are
   in place.

This keeps the rollout smooth, auditable, and close to the current qdesn
architecture while still borrowing the stronger design discipline from the
refreshed288 note.
