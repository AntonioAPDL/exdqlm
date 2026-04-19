# Refreshed288 Gamma Sigma Warmup Design

Date: `2026-04-17`

## Scope

This note is a design investigation only. It does **not** implement
`gamma/sigma` warmup or freezing yet.

The goal is to define, in a package-facing and study-facing way, how we would
add a smooth, explicit, reproducible warmup/freeze policy for the joint
likelihood-side `gamma/sigma` block in:

- static VB
- dynamic VB
- static MCMC
- dynamic MCMC

This note is intentionally more operational than the earlier sketch. It is
meant to answer:

- where the logic should live
- how controls should be threaded from the refreshed study tooling
- what the semantics should be in each inference class
- what diagnostics we need
- how to test it safely
- what order we should implement it in later

## Repo Targeting

This note now distinguishes two implementation surfaces.

| target | repo path | role | how this note should be used |
|---|---|---|---|
| refreshed288 / general package work | `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration` | documentation backbone for the refreshed validation study and future general package rollout | primary documentation target |
| active qdesn continuation | `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration` | current implementation surface for the live qdesn validation branch | use this note as a design backbone, but map controls and exports onto qdesn-native config and scripts |

This means:

- the refreshed288 structure is still the right documentation backbone
- the active qdesn branch should **not** implement this note verbatim
- the qdesn implementation should follow qdesn-native control surfaces and
  validation exports

## Terminology

For public documentation, use `sigmagam` as the preferred human-readable term.

Reason:

- `sigmagam` is easier to read in design notes, YAML, method registries, and
  reports
- the codebase already contains internal object names like `qsiggam`, which can
  stay as implementation-local names

Recommended convention:

- documentation / YAML / method registry: `sigmagam`
- internal variable names may still reuse existing package-local names like
  `qsiggam`, `siggam`, `eta_hat`, `ell_hat`

## Background

We already have an explicit warmup/freeze policy for the `rhs_ns` prior `tau`
block on the static shrinkage side. That gave us a useful template:

- explicit controls
- predictable early-iteration behavior
- auditable diagnostics
- no hidden dependence on package defaults

We do **not** currently have an analogous policy for the joint
likelihood-side `gamma/sigma` block.

Today, `gamma/sigma` behavior is stabilized only indirectly through:

- VB damping
- VB direct vs damped commit logic
- VB cycle detection
- VB mode-quality checks
- MCMC burn-in
- MCMC RW adaptation
- MCMC Laplace refresh
- optional VB warm starts

Those are important, but they are **not** the same thing as an explicit
warmup/freeze schedule.

## Core Design Goal

We want a future `gamma/sigma` warmup design that is:

- explicit
- reproducible
- local to the `gamma/sigma` block
- compatible with current `rhs_ns` tau warmup
- easy to reason about in traces and diagnostics
- safe for the refreshed288 study tooling

Just as important, we want to avoid a design that:

- silently changes scientific behavior in kept MCMC draws
- contaminates MH adaptation bookkeeping
- couples unrelated warmup systems together
- requires row-local rescue knobs in the main study

## Current State

Current behavior by block:

| block | current behavior | interpretation |
|---|---|---|
| static VB | LD block with damping, direct vs damped commit, auto-stabilize, cycle detection, mode-quality signoff | stabilization, not warmup/freeze |
| dynamic VB | LD block with damping, auto-stabilize, mode checks, trace capture | stabilization, not warmup/freeze |
| static MCMC | burn-in, optional RW adaptation, optional Laplace refresh, optional VB warm start | burn/adaptation, not warmup/freeze |
| dynamic MCMC | burn-in, optional RW adaptation, optional Laplace refresh, optional VB warm start | burn/adaptation, not warmup/freeze |

So the current truth is simple:

- there is no explicit `gamma/sigma` warmup scheduler
- there is no explicit `gamma/sigma` freeze window
- there is no explicit post-warmup forced first update

## Exact Package-Side Insertion Points

These are the exact code regions we would work with later.

### Static VB

Main control resolver:

- `R/exal_static_LDVB.R`
- `.exal_static_ld_controls()`

Main static VB entry point:

- `R/exal_static_LDVB.R`
- `exal_static_LDVB()`

Main `q(sigma,gamma)` update block:

- `R/exal_static_LDVB.R`
- the `# ---- (4) q(sigma,gamma) via LD` block

Important existing scheduler state already in this block:

- `ld_update_every`
- `ld_update_every_stable`
- `stabilize_active`
- `direct_commit`
- `damping`
- candidate / committed mode checks

Implication:

- static VB already has a natural place to host a true `sigmagam` warmup gate
- the clean design is to wrap the existing `do_ld_update` logic with a
  warmup-aware precheck rather than rewriting the whole LD block

### Dynamic VB

Main entry point:

- `R/exdqlmLDVB.R`
- `exdqlmLDVB()`

Main helper for the likelihood block:

- `R/exdqlmLDVB.R`
- `update_gamma_sigma()`

Main outer-loop call site:

- `R/exdqlmLDVB.R`
- `new.gamsig.out <- update_gamma_sigma(...)`

Current convergence / trace integration:

- `R/exdqlmLDVB.R`
- `.vb_joint_step(...)`
- `ld_trace_rows[[iter]] <- ...`

Implication:

- dynamic VB already isolates `gamma/sigma` inside a named helper, which makes
  it a good target for a future freeze scheduler
- we should gate the call to `update_gamma_sigma()` in the outer loop rather
  than burying freeze logic deeply inside every subroutine

### Static MCMC

Main entry point:

- `R/exal_static_mcmc.R`
- `exal_static_mcmc()`

Main sampling loop:

- `R/exal_static_mcmc.R`
- `for (i in 1:I)`

Likelihood-side block inside the loop:

- exact / conditional sigma update for non-joint kernels
- then gamma / transformed `(eta, ell)` kernel

Adaptation bookkeeping currently tied to the same loop:

- `mh.adapt`
- `mh.adapt.interval`
- `mh.min_burn_adapt`
- `laplace_refresh_*`
- acceptance windows
- `adapt.history`

Implication:

- static MCMC is the first MCMC place where we must be careful not to count a
  frozen `gamma/sigma` iteration as a real proposal attempt
- the implementation must separate:
  - loop iteration happened
  - sigmagam block was active
  - a real proposal / adaptation event occurred

### Dynamic MCMC

Main entry point:

- `R/exdqlmMCMC.R`
- `exdqlmMCMC()`

VB-init setup:

- `init.from.vb`
- `vb_init_controls`
- `vb_init_fit`

Main loop:

- `R/exdqlmMCMC.R`
- `for (i in 1:I)`

Likelihood-side block:

- exact conditional sigma update when `mh.proposal == "slice"`
- joint transformed update through `ex_samp_lsiglgam()` otherwise

Adaptation bookkeeping:

- `mh.adapt`
- `mh.adapt.interval`
- `mh.min_burn_adapt`
- `mh.laplace.refresh.*`
- `adapt.history`

Implication:

- dynamic MCMC has the same warmup-design burden as static MCMC
- it also has a stronger reason to keep the design clean, because this block
  has historically been one of the touchier parts of the validation work

## Refreshed288 Tooling Touch Points

The warmup feature will eventually need to flow from the refreshed study stack
into the package calls. These are the relevant study-side files.

### Method profile generation

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R`

Relevant builders:

- `build_dynamic_profile()`
- `build_static_profile()`
- `flatten_method_profiles_refreshed288()`

Why this matters:

- this is where the study should declare canonical warmup policy
- if we add `sigmagam` warmup later, it must become a manifest-visible method
  choice, not an invisible package default

### Row execution

- `tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R`

Relevant builders:

- `build_dynamic_ldvb_fit_refreshed288()`
- `build_static_ldvb_fit_refreshed288()`
- dynamic MCMC `call_args <- list(...)`
- static MCMC `call_args <- list(...)`

Why this matters:

- this is where the resolved study controls are passed into the package
- this is also where we must ensure the same canonical control profile is used
  for:
  - standalone VB rows
  - MCMC VB-init fits
  - main MCMC rows

### Prepare / manifest refresh

- `tools/merge_reports/LOCAL_refreshed288_prepare_20260416.R`

Why this matters:

- once `sigmagam` warmup becomes real, the method registry and generated
  manifests should expose it explicitly so the run is auditable later

## Active QDESN Touch Points

These are the active qdesn files that matter if the same idea is carried into
the current qdesn continuation branch.

### QDESN inference resolution

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R`
- `.exal_resolve_vb_config()`
- `.exal_resolve_mcmc_config()`
- `resolve_exal_inference_config()`

Why this matters:

- qdesn already has a native `pipeline -> inference -> vb/mcmc` resolution
  structure
- qdesn should use that control surface instead of inventing ad hoc wrapper
  arguments

### QDESN VB engine

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_ldvb_engine.R`

Why this matters:

- the VB engine already combines ELBO stabilization, gamma/sigma updates, RHS
  tau scheduling, and stopping rules in one place
- qdesn-specific sigmagam warmup has to cooperate with that stopping logic

### QDESN MCMC engine

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R`

Why this matters:

- the qdesn MCMC loop samples `latent_v` before the sigma/gamma block
- this ordering means MCMC sigmagam warmup cannot solve the earliest bad
  `latent_v` regime by itself

### QDESN validation export layer

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R`

Why this matters:

- current VB validation export already has full-iteration traces
- current MCMC validation export mostly summarizes kept draws
- burn-phase sigmagam warmup therefore needs additional export plumbing if we
  want the behavior to be auditable

### QDESN study-level config / launch surfaces

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`

Why this matters:

- these are the natural places where explicit study-level sigmagam defaults
  would be declared and serialized for qdesn

## Recommended Control Placement

The smoothest design is **not** to put everything in one generic global
control bag. Instead, we should use the control surface that already matches
the implementation structure.

### Refreshed288 / general package VB control placement

Recommendation:

- place `sigmagam` warmup controls inside `ld_controls`

Why:

- the VB `gamma/sigma` block is already an LD-managed block
- static VB already resolves all LD controls through
  `.exal_static_ld_controls()`
- dynamic VB already uses an LD-oriented helper structure and trace
  vocabulary
- keeping these controls in `ld_controls` keeps the feature close to the
  existing stabilization machinery

Recommended future VB fields:

- `freeze_sigmagam_warmup_iters`
- `force_sigmagam_after_warmup`
- `sigmagam_postwarmup_damping`
- `sigmagam_postwarmup_damping_iters`
- `sigmagam_min_postwarmup_updates`

Recommendation:

- do **not** introduce a separate top-level VB argument just for this in the
  refreshed288 / general-package surface
- instead, extend the existing LD control resolver in a backwards-compatible
  way

### Active QDESN VB control placement

Recommendation:

- in qdesn, resolve the feature through the existing inference config surface

Preferred qdesn study-level path:

- `pipeline.inference.vb.sigmagam.*`

Example shape:

```yaml
inference:
  vb:
    sigmagam:
      freeze_warmup_iters: 10
      force_after_warmup: true
      postwarmup_damping: 0.5
      postwarmup_damping_iters: 3
      min_postwarmup_updates: 1
```

Implementation target:

- resolve in `R/exal_inference_config.R`
- thread into the qdesn VB engine

### Refreshed288 / general package MCMC control placement

Recommendation:

- add a dedicated `sigmagam_warmup_controls` argument to the public MCMC
  wrappers

Why:

- the MCMC `gamma/sigma` block is not purely an MH proposal concern
- it touches exact conditional sigma updates, slice kernels, RW kernels, and
  adaptation
- hiding this inside `mh.*` would blur two different responsibilities

Recommended future MCMC fields:

- `freeze_sigmagam_burnin_iters`
- `freeze_only_during_burn`
- `force_sigmagam_after_warmup`
- `delay_adapt_until_after_warmup`
- `delay_laplace_refresh_until_after_warmup`

Recommendation:

- do **not** overload `mh.adapt` or `mh.min_burn_adapt` to mean sigmagam
  warmup
- those are related but distinct concepts

### Active QDESN MCMC control placement

Recommendation:

- in qdesn, resolve the feature through the existing inference config surface

Preferred qdesn study-level paths:

- `pipeline.inference.mcmc.sigmagam.*`
- `pipeline.inference.mcmc.vb_warm_start_control.sigmagam.*`

Example shape:

```yaml
inference:
  mcmc:
    sigmagam:
      freeze_burnin_iters: 50
      freeze_only_during_burn: true
      force_after_warmup: true
      delay_adapt_until_after_warmup: true
      delay_laplace_refresh_until_after_warmup: true
    vb_warm_start_control:
      sigmagam:
        freeze_warmup_iters: 10
        force_after_warmup: true
        postwarmup_damping: 0.5
        postwarmup_damping_iters: 3
        min_postwarmup_updates: 1
```

Implementation target:

- resolve in `R/exal_inference_config.R`
- thread into the qdesn MCMC engine and VB warm-start path

## Recommended Default Policy

These are the current recommended defaults for the future feature as **study
defaults**, not package defaults.

| context | proposed future study default |
|---|---:|
| static VB | `freeze_sigmagam_warmup_iters = 10` |
| dynamic VB | `freeze_sigmagam_warmup_iters = 10` |
| static MCMC | `freeze_sigmagam_burnin_iters = 50` |
| dynamic MCMC | `freeze_sigmagam_burnin_iters = 50` |

These are intentionally **not** tied to the `rhs_ns` `tau` warmup lengths.

Reason:

- `rhs_ns` prior `tau` warmup solves a prior-scale stabilization issue
- `sigmagam` warmup would solve a likelihood-block stabilization issue
- these are different mechanisms and should remain independently tunable

## Package Defaults Versus Study Defaults

Recommended policy:

- package default: feature off
- study default: feature explicit and serialized
- smoke / pilot default for refreshed288: `VB = 10`, `MCMC = 50`
- qdesn stabilization experiments may test alternative VB values such as `20`
  before hard-coding them as study defaults

Why:

- keeps backward compatibility clean
- avoids silently changing historical behavior
- makes the scientific choice a study-level decision, not an implicit package
  side effect

## Detailed Proposed Semantics

### VB semantics

During VB warmup:

- hold `eta_hat` fixed
- hold `ell_hat` fixed
- hold the associated covariance fixed
- skip the LD mode-search / commit step for the `sigmagam` block
- continue updating the other blocks normally
- continue recording trace rows, but mark the block as frozen

Immediately after VB warmup:

- force one real `sigmagam` LD update
- mark that iteration as a post-warmup forced update
- optionally use a slightly damped commit for a short number of iterations
  after warmup
- after that, fall back to the existing LD stabilization logic

The clean mental model is:

- warmup overrides the `sigmagam` update cadence briefly
- then the current LD machinery takes over again

### VB convergence guard

This is important enough to state explicitly:

- VB stop rules must not fire before at least
  `sigmagam_min_postwarmup_updates >= 1`

Reason:

- if the block is frozen early, gamma/sigma stability can look artificially
  good
- ELBO-based stopping plus frozen sigmagam can otherwise terminate before the
  block has actually moved post-warmup

Recommended rule:

- convergence checks may continue to be recorded during warmup
- final VB termination should require:
  - warmup finished
  - at least one forced post-warmup sigmagam update occurred
  - the minimum post-warmup update count has been satisfied

### MCMC semantics

During MCMC warmup:

- freeze the current `gamma` and `sigma`
- skip the `sigmagam` update block entirely
- continue updating the remaining blocks
- do **not** count the skipped block as:
  - an MH proposal attempt
  - an MH rejection
  - a slice evaluation event
  - an adaptation window contribution

Immediately after MCMC warmup:

- force one real `sigmagam` update
- only after the block is active do we allow:
  - RW adaptation windows
  - Laplace refresh
  - acceptance accounting

This is crucial because we do **not** want a frozen block to poison:

- acceptance rates
- scale adaptation
- Laplace refresh timing
- downstream diagnostics

### MCMC ordering caveat

This matters especially in qdesn.

In the active qdesn MCMC loop:

- `latent_v` is updated before the sigma/gamma block
- the sigma/gamma block is updated later in the loop

Implication:

- MCMC sigmagam warmup cannot fix the earliest bad `latent_v` regime by itself
- VB sigmagam warmup is the higher-leverage first implementation
- MCMC sigmagam warmup is secondary stabilization, not the first rescue lever

### Kernel-specific MCMC accounting rules

These rules should be stated explicitly.

For RW kernels:

- frozen iterations must not count as proposal attempts
- frozen iterations must not count as rejections
- frozen iterations must not enter acceptance windows

For slice kernels:

- frozen iterations must not contribute to step-out / shrink summaries
- frozen iterations must not be treated as active kernel evaluations

For Laplace refresh:

- frozen iterations must not trigger refresh timing
- refresh timing should begin only after the sigmagam block becomes active

## Smooth Implementation Strategy

This is the recommended sequence for future implementation.

### Step 1. Freeze the public semantics first

Before touching package code, lock the behavior contract:

- refreshed288 / general package VB uses `ld_controls`
- refreshed288 / general package MCMC uses `sigmagam_warmup_controls`
- qdesn uses `pipeline.inference.*` config resolution
- VB warmup is true block freeze
- MCMC warmup is burn-only block freeze
- a post-warmup first update is forced

Output:

- this design note
- relaunch spec note updated to mention the future warmup feature as a planned
  enhancement, not current behavior

### Step 2. Add control resolvers, no behavior change yet

Package-side:

- extend `.exal_static_ld_controls()` with the future VB warmup fields
- add a small `resolve_sigmagam_warmup_controls_*()` helper for MCMC

Study-side:

- extend `LOCAL_refreshed288_helpers_20260416.R` so method profiles can carry
  explicit sigmagam warmup settings
- extend the method registry flattening so those settings are visible

QDESN-side:

- extend `R/exal_inference_config.R` so qdesn-native config can resolve:
  - `inference.vb.sigmagam.*`
  - `inference.mcmc.sigmagam.*`
  - `inference.mcmc.vb_warm_start_control.sigmagam.*`

Important:

- in this step the new controls may exist, but they should default to the
  current off behavior unless explicitly activated

### Step 3. Implement static VB first

Why first:

- deterministic
- trace-rich
- easier to reason about than MCMC

Mechanically:

- add warmup-aware logic around the current `do_ld_update` calculation in
  `R/exal_static_LDVB.R`
- if warmup is active, override to hold
- when warmup ends, force one real LD update
- record warmup state in the LD trace

### Step 4. Implement dynamic VB second

Why second:

- same conceptual block
- isolated helper function
- still deterministic enough to validate carefully

Mechanically:

- gate the outer-loop call to `update_gamma_sigma()` in `R/exdqlmLDVB.R`
- if warmup is active, carry forward the current block state
- when warmup ends, force one real update
- add parallel trace fields to the dynamic LD trace output

### Step 5. Implement static MCMC third

Why third:

- simpler than dynamic MCMC
- exposes the full adaptation bookkeeping problem

Mechanically:

- add `sigmagam_warmup_active <- ...`
- if active:
  - skip sigma/gamma block update
  - skip MH bookkeeping for that block
  - skip adaptation-window contributions
- on first active iteration after warmup:
  - force one actual block update
- only then let ordinary adaptation resume

### Step 6. Implement dynamic MCMC last

Why last:

- highest risk
- historically the more delicate path

Mechanically:

- follow the same structure as static MCMC
- ensure both slice and RW-style kernels behave correctly
- keep the interaction with VB initialization explicit and auditable

### Step 7. Wire refreshed288 only after package behavior is stable

Study-side only after the package feature is tested:

- update `LOCAL_refreshed288_helpers_20260416.R`
- update `LOCAL_refreshed288_method_registry_20260416.csv`
- update `LOCAL_refreshed288_run_row_20260416.R`
- regenerate manifests only when we are ready for a new run root

Important:

- do **not** retroactively mutate the current interrupted partial run
- the refreshed study should only pick up this feature in a fresh prepared run

## Implementation Order

### General package order

This remains the right broad rollout order:

1. static VB
2. dynamic VB
3. static MCMC
4. dynamic MCMC
5. refreshed288 study wiring afterward

### Current qdesn priority order

For the active qdesn continuation branch, the more practical order is:

1. qdesn VB engine first
2. qdesn MCMC second
3. qdesn export / validation wiring third
4. qdesn study YAML / launch wiring last

Reason:

- the current qdesn problem is more directly tied to the active engine and
  validation export surface than to generic refreshed288 tooling
- qdesn VB warmup is likely the highest-leverage first intervention
- qdesn MCMC warmup should be treated as a second-stage stabilization measure

## Diagnostics We Should Add

### VB diagnostics

Each fit should eventually record:

- `sigmagam_warmup_iters`
- `sigmagam_warmup_active`
- `sigmagam_schedule_reason`
- `sigmagam_forced_postwarmup`
- `sigmagam_update_count`
- `sigmagam_first_active_iter`

For trace rows specifically:

- whether the `sigmagam` block was held
- whether the committed state changed
- whether the iteration was the first post-warmup active update

### MCMC diagnostics

Each fit should eventually record:

- `sigmagam_warmup_iters`
- `sigmagam_warmup_active`
- `sigmagam_first_active_iter`
- `sigmagam_forced_postwarmup`
- `sigmagam_adaptation_delayed`
- `sigmagam_updates_burn`
- `sigmagam_updates_keep`

And we should clearly separate:

- loop iterations
- actual block proposals / updates
- adaptation windows containing real proposals

### Current validation export plan

For qdesn specifically, export design should reflect the current split between
VB and MCMC reporting.

Recommended VB trace additions:

- `sigmagam_frozen`
- `sigmagam_update_reason`
- `sigmagam_forced_postwarmup`

Recommended MCMC burn-phase trace strategy:

- keep full burn / full-chain sigmagam traces in `misc`
- do not rely on kept-draw `progress_trace.csv` alone to represent warmup

Recommended MCMC summary additions:

- `sigmagam_first_active_iter`
- `sigmagam_updates_burn`
- `sigmagam_updates_keep`

## Study-Side Reproducibility Requirements

When the feature is eventually adopted, the study tooling should satisfy all of
these:

- method registry explicitly shows sigmagam warmup settings
- manifests inherit those settings deterministically
- VB rows and MCMC VB-init rows do not silently diverge
- row configs or `fit_request.json` serialize the resolved warmup controls
- final reports can say exactly which warmup policy was used

That means future registry / export fields will likely need to include
something like:

- `sigmagam_vb_warmup_iters`
- `sigmagam_mcmc_warmup_iters`
- `sigmagam_force_after_warmup`
- `sigmagam_delay_adapt`

For qdesn specifically:

- resolved YAML settings should flow through inference resolution into the
  realized fit request
- the launch and run scripts should preserve those controls in the generated
  run metadata

## Testing Plan

This is the recommended future test sequence.

### Package unit tests

Static VB:

- short fit with `freeze_sigmagam_warmup_iters = 3`
- verify first `3` iterations hold the block
- verify iteration `4` performs a forced update

Dynamic VB:

- same pattern
- verify dynamic LD trace reports the warmup state correctly
- verify the post-warmup update count guard prevents premature stopping

Static MCMC:

- short burn-only run with `freeze_sigmagam_burnin_iters = 5`
- verify no block-adaptation accounting happens before iteration `6`
- verify a real block update occurs immediately after warmup

Dynamic MCMC:

- same structure
- verify slice and RW cases separately
- verify frozen iterations do not contaminate kernel-specific summaries

### Refreshed288 wiring tests

Study-side:

- method registry contains the resolved fields
- row configs serialize the resolved fields
- row runner passes the controls through to package calls

### QDESN wiring tests

QDESN-side:

- inference config resolves the new sigmagam controls correctly
- VB and MCMC warm-start control profiles preserve the intended settings
- fit requests and run metadata serialize the resolved values

### Smoke-level validation

After package + wiring tests:

- use a tiny refreshed smoke subset
- one row per block is enough initially
- confirm traces and summaries report the warmup policy correctly

For qdesn:

- use a minimal validation subset
- confirm VB trace and MCMC summary exports both show the sigmagam warmup state

## What We Should Not Do

- do not implement this directly in refreshed288 study scripts first
- do not implement this directly in qdesn launch YAML first
- do not make MCMC warmup implicit through `mh.min_burn_adapt`
- do not treat skipped frozen iterations as rejected proposals
- do not freeze the block into kept MCMC draws
- do not tie `gamma/sigma` warmup length mechanically to the `rhs_ns` tau
  warmup length
- do not mutate the current interrupted refreshed run to retrofit this feature

## Practical Recommendation

The clean combined plan is:

1. keep this feature design-only for now
2. treat refreshed288 as the documentation backbone
3. treat qdesn as a separate implementation surface with qdesn-native control
   resolution
4. implement VB sigmagam warmup first
5. implement MCMC sigmagam warmup second
6. only after package verification, wire it into refreshed288 and qdesn study
   configs

The future study defaults I recommend remain:

- VB sigmagam warmup: `10` iterations
- MCMC sigmagam warmup: first `50` burn iterations only
- force one real post-warmup update
- require at least one post-warmup VB sigmagam update before convergence
- keep existing LD stabilization / MH adaptation logic after warmup

That gives us the smoothest path to a later implementation while keeping the
current study clean, explicit, auditable, and reproducible across both the
refreshed288 and qdesn surfaces.
