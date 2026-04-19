# PLAN: QDESN Remaining-Failed MCMC Strategy Compared With Refreshed288

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Purpose

This note compares the current QDESN remaining-failure recovery plan against the
similar refreshed288 runtime-failure plan in:

- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260418/refreshed288_runtime_failure_vs_qdesn_comparison_and_plan_20260418.md`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260418/refreshed288_runtime_failure_investigation_and_rerun_plan_20260418.md`

The goal is to decide what transfers into the current QDESN recovery lane and
what should stay different because the fragile latent block is not the same.

This note should be read together with:

- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_handoff_20260418.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`

## Short Answer

The refreshed288 findings support the current QDESN direction, but they do not
replace it.

Most important conclusion:

- in refreshed288, the correct analogue of QDESN `latent_v` warmup is a latent
  `Ut` or `Ut/st` warmup
- in QDESN, the problem is already explicit: the failing block is `latent_v`

So for the current QDESN study, the comparison argues for:

1. keeping the warmup-led strategy;
2. adding direct MCMC `latent_v` warmup now;
3. strengthening failure instrumentation around the `latent_v` GIG draw;
4. keeping slice-kernel changes secondary;
5. keeping a dedicated remaining-failure v2 relaunch spec, separate from the
   canonical refreshed-main defaults.

## Shared Context

The two studies are genuinely comparable:

- they use the same dynamic source surface
- they stress similar dynamic DGP families and quantiles
- they both fail in an early latent-state path before the full downstream
  posterior machinery stabilizes
- both show that warmup helps but is not sufficient on its own

## Main Similarities

### 1. Same data surface

Both studies target the same synthetic dynamic source family:

- scenario:
  - `dlm_constV_smallW`
- DGP families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.50`
- effective sizes:
  - `500`
  - `5000`

This makes the comparison meaningful. We are not comparing unrelated failure
surfaces.

### 2. Runtime crashes are the real issue

In both studies, the relevant repair lane is the hard numerical crash lane, not
the post-fit mixing or signoff lane.

QDESN:

- dominant repeat failure:
  - `latent_v returned ... invalid draws ... value=NA`

Refreshed288:

- dominant runtime failures:
  - `invalid state before chi update`
  - `chi has ... non-finite values`
  - `ldvb_q_t1 is NA`

Operational implication:

- crash reruns should remain isolated from “finished but mixed badly” rows

### 3. Warmup is directionally right

QDESN:

- first failed-only rerun recovered `5 / 23`

Refreshed288:

- the crash plan also prioritizes stronger init and stronger warmup over
  immediate slice tuning

Interpretation:

- warmup is not a dead end in either repo
- the first question is not whether warmup matters
- the real question is how to target the right latent block with a coherent
  warmup contract

### 4. Slice tuning is secondary

Both plans converge on the same conclusion:

- the current dominant crashes happen before slice gamma tuning becomes the main
  active lever
- so changing `slice_width`, `max_steps_out`, or similar settings is not the
  first move

## Main Differences

### 1. The fragile latent block is different

Refreshed288:

- the fragile latent state is `Ut` in DQLM
- or the `Ut/st` pair in exDQLM

QDESN:

- the fragile latent state is already explicit:
  - `v`

Relevant QDESN file:

- `R/exal_mcmc_fit.R`

Important QDESN fact:

- `v` is initialized from VB if available
- then MCMC resamples `v` first in the loop
- only after that do `s`, `beta`, RHS, and `sigmagam` updates proceed

So the refreshed288 analogy does **not** imply “copy their warmup literally.”
It implies:

- in QDESN, use a **direct `latent_v` warmup**

### 2. Refreshed288 is more startup-only; QDESN is mixed

Refreshed288:

- crashes are strongly startup / iter-1 style

QDESN:

- remaining failures split between:
  - early failures
  - burn-phase failures
  - late keep-phase failures

Implication for QDESN:

- `latent_v` warmup is likely high value for the early and burn subset
- but it is unlikely to be the whole story for the late keep-phase subset

### 3. Refreshed288 still has a DQLM sigma warmup gap; QDESN does not

Refreshed288:

- needed a new DQLM sigma-only warmup because its current `sigmagam` warmup did
  not protect the DQLM branch

QDESN:

- both `al` and `exal` lanes already run through `R/exal_mcmc_fit.R`
- the current repo already has:
  - VB `sigmagam` warmup
  - MCMC `sigmagam` freeze
  - RHS tau freeze

So the analogous QDESN gap is **not** “add sigma-only warmup.”
The analogous QDESN gap is:

- add **latent_v warmup**
- add better `latent_v` failure instrumentation

### 4. Refreshed288 has a direct VB crash lane; QDESN does not

Refreshed288:

- still has a direct dynamic-VB runtime-crash row

QDESN:

- the source run and reruns did not show VB runtime failures
- VB completed cleanly in the original full campaign
- the current remaining hard surface is MCMC-only

Implication:

- QDESN should not split effort toward a separate VB crash-recovery lane
- the next QDESN work should stay focused on the MCMC remaining-failure surface

## What Transfers Cleanly Into QDESN

These lessons transfer directly:

### 1. Warm up the first fragile latent block

Refreshed288 takeaway:

- warm up `Ut` / `Ut-st`

QDESN translation:

- warm up `latent_v`

This is the strongest comparison-based recommendation.

### 2. Keep the warmup contract explicit and serialized

The current QDESN repo already does this well for:

- VB tau warmup
- MCMC tau warmup
- VB `sigmagam` warmup
- MCMC `sigmagam` warmup

The new `latent_v` warmup should follow the same pattern:

- explicit config block
- normalized through the inference resolver
- serialized in `fit_request.json`
- summarized in validation outputs

### 3. Add richer failure instrumentation before the next full rerun

The refreshed288 plan reinforces the same lesson:

- do not launch another large rerun with the same sparse failure state

For QDESN that means persisting, at minimum:

- failure iteration
- burn vs keep phase
- `sigma`
- `gamma`
- `tau` and `c2` when present
- `chi_v` summaries
- `psi_v` summaries
- whether latent-`v` warmup was active

### 4. Keep kernel changes as a secondary arm

The comparison strengthens, not weakens, the current QDESN view:

- do not make slice tuning the primary explanation or first intervention
- use it later if warmup-v2 plus `latent_v` warmup still leaves a late-crash
  subset

## What Does Not Transfer Literally

These refreshed288-specific ideas should **not** be copied literally into QDESN:

- `Ut` warmup
- `Ut/st` warmup
- DQLM sigma-only warmup
- direct VB crash-lane handling

Those are correct for the refreshed288 package surface, but the QDESN package
surface is different.

## Updated QDESN Strategy After This Comparison

The current QDESN plan should now be stated as:

### Phase 1: Instrumentation

Before the next large remaining-failure relaunch:

- add failure-state instrumentation around the `latent_v` GIG draw in
  `R/exal_mcmc_fit.R`
- export the new failure fields in `R/qdesn_mcmc_validation.R`

### Phase 2: Warmup-v2

Keep the existing strengthened warmup direction, but make it more coherent:

- keep VB RHS tau freeze at `50`
- keep MCMC RHS tau freeze at `500`
- increase VB `sigmagam` warmup depth
- align MCMC `sigmagam.freeze_burnin_iters` with tau at `500`
- raise MCMC VB warm-start `max_iter`

### Phase 3: Direct `latent_v` warmup

Add a new MCMC control family for `latent_v` in:

- `R/exal_inference_config.R`
- `R/exal_mcmc_fit.R`

Recommended primary pilot:

- hard freeze for the earliest iterations
- then sparse warmup updates during burn-in
- force first normal post-warmup update

Recommended v1 semantics:

- `freeze_burnin_iters: 50`
- `freeze_only_during_burn: true`
- `force_after_warmup: true`
- `update_every_warmup: 10`
- `update_every_warmup_iters: 500`

Why this is the best translation of the refreshed288 lesson:

- it targets the exact QDESN fragile latent block
- it is coherent with the existing tau and `sigmagam` warmups
- it is more surgical than an undifferentiated kernel rewrite

### Phase 4: Secondary kernel arm only if needed

If warmup-v2 plus `latent_v` warmup still leaves a stubborn late-crash subset:

- for `exal`, pilot `core_update_mode = "gamma_sigma_gamma"`
- consider RHS width adaptation during burn
- consider `conditioning.mode = "qr_whiten"`

## File-Level Action Plan

### `R/exal_inference_config.R`

Add:

- normalized `mcmc.latent_v.*` controls

Keep consistent with:

- existing `mcmc.sigmagam.*`
- existing `mcmc.rhs.*`

### `R/exal_mcmc_fit.R`

Add:

- `latent_v` warmup scheduler
- traces and summary counts
- rich failure-state capture around the GIG draw

Do not change first:

- slice widths
- core update mode defaults

### `R/qdesn_mcmc_validation.R`

Add:

- latent-`v` warmup summary fields
- latent-`v` failure context export

### New dedicated v2 defaults YAML

Create:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml`

Reason:

- the refreshed288 comparison reinforces the need to keep specs separated and
  reproducible across runs

### Remaining-failure rerun inventory

Already materialized:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv`

These should remain the authoritative rerun surface for the next recovery wave.

## Recommended Message To A Fresh QDESN Chat

If a new QDESN chat is opened, the shortest correct briefing is:

1. Read:
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_handoff_20260418.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_comparison_with_refreshed288_20260418.md`
2. The source tau050 run had `23` failed MCMC fits.
3. The first failed-only rerun recovered `5`, but `18` still fail.
4. All remaining repeat failures are still `latent_v ... invalid draws ... NA`.
5. The refreshed288 comparison supports the current direction:
   - keep warmup-led recovery
   - add direct MCMC `latent_v` warmup
   - add failure instrumentation first
   - keep kernel tuning secondary
6. Use the remaining-failure grids as the next rerun surface.

That is the correct comparison-based continuation point.
