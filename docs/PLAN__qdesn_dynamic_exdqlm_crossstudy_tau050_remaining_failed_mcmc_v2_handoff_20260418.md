# PLAN: QDESN tau050 Remaining-Failed MCMC Relaunch v2 Handoff

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## 1) Purpose

This note is the handoff plan for a fresh chat that needs to continue the QDESN
tau050 validation recovery work without re-deriving context from scratch.

It summarizes:

- the study and data surface we are running;
- the source run and rerun history;
- the current remaining-failure problem;
- what has already been implemented and tested;
- the next coherent strategy to try;
- the exact files to modify and what to change in each one;
- the reproducibility and documentation requirements for the next relaunch.

This is the canonical starting point for the next chat.

## 2) Executive Summary

Current truth:

- the original tau050 refreshed-main campaign finished at `121 / 144` fit
  successes and `23 / 144` fit failures
- a first failed-only rerun was launched with stronger warmup
- that rerun completed and recovered `5 / 23` failed fits
- `18 / 23` failed again
- all `18 / 18` repeat failures are still the same hard MCMC numerical crash:
  `exal_mcmc_fit::latent_v returned ... invalid draws ... value=NA`

Interpretation:

- the warmup direction is valid, because it did recover a subset
- but the first warmup package did not broadly solve the failed surface
- the next relaunch should remain warmup-led, but it should be more coherent,
  better instrumented, and include a direct MCMC-side `latent_v` warmup lever
- kernel changes are reasonable as a secondary pilot for the late-crash subset,
  not as the first undifferentiated move

## 3) Study Surface

### Main Validation Campaign

Primary defaults file:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`

Main wrapper scripts:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

Main grid and source materialization:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv`
- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R`

### Data Surface

This is a synthetic dynamic-only QDESN validation study built from staged
source inputs.

Source materialization contract from the main defaults YAML:

- source root kind: `dynamic`
- scenario: `dlm_constV_smallW`
- DGP families:
  - `gausmix`
  - `laplace`
  - `normal`
- quantiles:
  - `tau = 0.05`
  - `tau = 0.25`
  - `tau = 0.50`
- effective train sizes:
  - `500`
  - `5000`
- total staged sizes:
  - `813`
  - `5313`
- holdout:
  - one-step forecast window

Staged source root:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_sources`

Reference source root:

- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/results/function_testing_20260309_dynamic_dlm_family_qspec`

### Model / Inference Surface

QDESN readout configuration from the canonical defaults:

- deep DESN reservoir profile:
  - `deep_d3_n100x3_skip100_w300_m30`
- readout input mode:
  - `raw_y_lags`
- lags:
  - `m_y = 12`
  - `m_x = 0`
- preprocessing:
  - `scale_y = true`
  - `scale_x = true`

Likelihoods and methods:

- methods:
  - `vb`
  - `mcmc`
- likelihood families:
  - `al`
  - `exal`

Inference backends:

- VB:
  - LDVB
- MCMC:
  - slice-based kernel
  - LDVB warm start for every MCMC fit

Beta priors:

- `ridge`
- `rhs_ns`

Important policy:

- raw `rhs` is not part of the canonical refreshed-main lane
- the active lane is `ridge + rhs_ns`

## 4) Run History And Current Status

### Source Full Run

Authoritative full run tag:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`

Source run root:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674`

Source run outcome:

- roots:
  - `36 / 36` terminal
  - `20` success
  - `16` fail
- fits:
  - `144 / 144` terminal
  - `121` success
  - `23` fail

Lane split:

- `vb_al`: `36 / 36` success
- `vb_exal`: `36 / 36` success
- `mcmc_al`: `27` success, `9` fail
- `mcmc_exal`: `22` success, `14` fail

### First Failed-Only Rerun

Launch report:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_relaunch_launch_20260418.md`

Plan:

- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_relaunch_execution_20260418.md`

Failed-only launch tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955`

Rerun outcome:

- `23 / 23` targeted fits terminal
- recovered:
  - `5 / 23`
- failed again:
  - `18 / 23`

Remaining-failure investigation:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`

### Exact Remaining-Failure Inventory

Materializer:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_grids.R`

Materialized remaining-failure grids:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv`

Current inventory:

- remaining `mcmc_al` failures:
  - `7`
- remaining `mcmc_exal` failures:
  - `11`
- total remaining failed fits:
  - `18`
- overlap roots across the two remaining-failure grids:
  - `5`

## 5) Current Issue

### Dominant Failure Mode

The remaining failures are still hard MCMC numerical crashes in the latent-`v`
sampling path.

Representative failure signature:

- `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`
- `Execution halted`

Relevant code path:

- latent `v` is sampled in `R/exal_mcmc_fit.R`
- the crash happens at the GIG draw call in the MCMC loop

Important operational read:

- these are not merely poor-signoff chains
- these are runtime failures that terminate the fit

### Why This Matters

The first rerun already strengthened:

- VB tau warmup
- MCMC tau burn-in freeze
- VB `sigmagam` warmup
- MCMC `sigmagam` freeze

But it did **not** materially change:

- the slice kernel structure
- the slice widths
- conditioning
- failure instrumentation
- the fact that MCMC resamples `v` first every iteration

So the current unresolved problem is still directly on the earliest and most
fragile MCMC latent-variable update.

## 6) What We Learned From The First Rerun

### What Improved

The warmup changes were not a no-op.

Evidence:

- `5 / 23` failed fits were recovered
- some rerun failures survived much longer than the source failures before
  crashing

So the warmup direction is scientifically credible.

### What Did Not Improve Enough

The remaining-failure report shows:

- all `18 / 18` repeat failures still have the same latent-`v` crash signature
- recovery is concentrated at low tau
- `gausmix` remains the hardest family
- prior does not separate failures cleanly:
  - `rhs_ns` and `ridge` both still fail
- failures split into:
  - early / burn-only crashes
  - late keep-phase crashes

Interpretation:

- stronger warmup is still justified
- but a single generic “more warmup everywhere” spec is unlikely to solve all
  `18` remaining cases

## 7) Recommended Next Strategy

The next relaunch should be framed as a **remaining-failed v2 recovery plan**
with three pieces:

1. better failure instrumentation
2. stronger and more coherent warmup-v2
3. direct MCMC-side `latent_v` warmup

Kernel changes should be piloted after that if the late-crash subset remains.

### Recommended v2 Package

Warmup-v2:

- keep VB RHS-NS tau freeze at `50`
- keep MCMC RHS-NS tau freeze burn-in at `500`
- raise VB `sigmagam.freeze_warmup_iters` from `10` to `20`
- raise VB `sigmagam.postwarmup_damping_iters` from `3` to `10`
- lower VB `sigmagam.postwarmup_damping` from `0.5` to around `0.35` or `0.40`
- raise VB `sigmagam.min_postwarmup_updates` from `1` to `3`
- raise MCMC LDVB warm-start `max_iter` from `300` to `500`
- align MCMC `sigmagam.freeze_burnin_iters` with tau at `500`

New MCMC latent-`v` warmup:

- add an explicit MCMC `latent_v` control family
- use the VB-initialized `v` state as the starting value
- apply only in burn-in

Recommended latent-`v` v1 semantics:

- `freeze_burnin_iters: 50`
- `freeze_only_during_burn: true`
- `force_after_warmup: true`
- `update_every_warmup: 10`
- `update_every_warmup_iters: 500`

Interpretation:

- a short hard freeze protects the most fragile startup zone
- a sparse warmup schedule after that is safer than a very long hard freeze
- this is more coherent than letting `v` move every iteration while tau and
  `sigmagam` are still heavily constrained

### Kernel-v1 As A Secondary Pilot

Only after warmup-v2 plus latent-`v` warmup is in place:

- for `exal`, pilot `core_update_mode = "gamma_sigma_gamma"`
- consider enabling RHS width adaptation during burn-in for `rhs_ns`
- consider `conditioning.mode = "qr_whiten"` for the late-crash subset

What not to prioritize first:

- `max_steps_out` / `max_shrink`

Reason:

- the current failures are latent-`v` invalid-draw crashes, not slice-exhaustion
  failures

## 8) Files To Modify And How

This section is the most important part for a new chat that will implement the
next step.

### A. `R/exal_inference_config.R`

Role:

- central config resolver for VB and MCMC inference controls

Modify to:

- add a normalized MCMC `latent_v` control family, parallel to the existing
  `sigmagam` normalization
- allow study-level config to pass:
  - `freeze_burnin_iters`
  - `freeze_only_during_burn`
  - `force_after_warmup`
  - `update_every_warmup`
  - `update_every_warmup_iters`
- keep defaults off or conservative in the package-level default resolver
- preserve the existing `sigmagam`, `rhs`, `slice`, `conditioning`, and
  `multi_start` merges

Concrete target surfaces:

- `.exal_default_mcmc_control()`
- `.exal_resolve_mcmc_config()`
- any helper normalizer adjacent to `.exal_normalize_mcmc_sigmagam_cfg()`

### B. `R/exal_mcmc_fit.R`

Role:

- active MCMC engine

Modify to:

1. parse the new `latent_v` warmup control block
2. gate the `v` resampling step in the MCMC loop
3. preserve and reuse the current `v` state when frozen
4. support sparse warmup updates after the hard-freeze window
5. record explicit traces and summaries
6. improve failure instrumentation around the `latent_v` draw

Concrete behavior to add:

- before the current latent-`v` draw:
  - determine whether this iteration is:
    - frozen
    - scheduled for a sparse warmup refresh
    - normal update
- if frozen:
  - keep `v` unchanged
- if scheduled:
  - run the current GIG draw
- after warmup:
  - force the first normal post-warmup `v` update

Failure instrumentation to add around the latent-`v` call:

- iteration index
- whether failure is in burn or keep phase
- current `sigma`
- current `gamma`
- current `tau` and `c2` when RHS-family
- summary of `chi_v`
  - min
  - median
  - max
- summary of `psi_v`
  - min
  - median
  - max

Recommended new traces / summaries:

- `latent_v_frozen_trace`
- `latent_v_update_reason_trace`
- `latent_v_update_performed_trace`
- `latent_v_update_count_trace`
- `latent_v_first_active_iter`
- `latent_v_updates_burn`
- `latent_v_updates_keep`
- `latent_v_frozen_burn_rate`

Important note:

- this should be implemented in a way that does not break `store_latent_draws`
  semantics or kept-draw indexing

### C. `R/qdesn_mcmc_validation.R`

Role:

- fit summary and validation export layer

Modify to:

- export the new latent-`v` warmup summary into `health_summary.csv`
- export failure-state context for crashed fits
- preserve the existing `sigmagam` warmup summary fields

Recommended new health-summary fields:

- `mcmc_latent_v_warmup_iters`
- `mcmc_latent_v_first_active_iter`
- `mcmc_latent_v_updates_burn`
- `mcmc_latent_v_updates_keep`
- `mcmc_latent_v_frozen_burn_rate`
- `mcmc_latent_v_failure_iter`
- `mcmc_latent_v_failure_phase`
- `mcmc_latent_v_failure_sigma`
- `mcmc_latent_v_failure_gamma`
- `mcmc_latent_v_failure_tau`
- `mcmc_latent_v_failure_c2`
- `mcmc_latent_v_failure_chi_min`
- `mcmc_latent_v_failure_chi_med`
- `mcmc_latent_v_failure_chi_max`
- `mcmc_latent_v_failure_psi_min`
- `mcmc_latent_v_failure_psi_med`
- `mcmc_latent_v_failure_psi_max`

### D. New v2 Defaults YAML

Recommended action:

- do **not** overwrite the canonical refreshed-main defaults for the next
  experiment
- instead create a new dedicated v2 recovery defaults file

Recommended new file:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml`

Reason:

- we are already using multiple specs across runs
- a dedicated defaults file is the cleanest way to keep future relaunches
  reproducible and auditable
- it prevents accidental drift of the canonical refreshed-main lane

This new file should:

- inherit the same study surface
- target only the remaining-failed recovery work
- encode warmup-v2 and latent-`v` controls explicitly
- optionally include commented candidate kernel-v1 toggles, but leave them off
  by default

### E. Wrapper Scripts

Current wrappers:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

Recommended action:

- add new phases or a new dedicated wrapper for the remaining-failed v2 study

Cleaner option:

- add a dedicated remaining-failed v2 wrapper pair:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_validation.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_validation.R`

Alternative option:

- extend the existing refreshed-main wrapper with:
  - `remaining_failed_mcmc_al`
  - `remaining_failed_mcmc_exal`
  - `remaining_failed_canary`

Preference:

- dedicated wrappers are cleaner because the next relaunch is now a distinct
  experimental spec, not just another refreshed-main phase

### F. Remaining-Failure Materializer

Current script:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_grids.R`

Possible extension:

- optionally emit curated canary grids for:
  - early-crash cases
  - late-crash cases
  - `gausmix` hotspot cases

This is optional but useful if the next step uses a canary before the full
remaining-18 rerun.

### G. Tests

Existing related tests:

- `tests/testthat/test-exal-inference-config.R`
- `tests/testthat/test-exal-mcmc.R`
- `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`
- `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-relaunch.R`
- `tests/testthat/test-qdesn-sigmagam-warmup-validation-export.R`

Modify / extend to cover:

1. config resolution
   - new `mcmc.latent_v.*` controls normalize correctly
2. MCMC scheduler behavior
   - hard freeze window
   - sparse warmup schedule
   - forced first post-warmup update
3. trace export
   - latent-`v` warmup summary fields appear in `health_summary.csv`
4. failure instrumentation
   - the failure context is persisted for a synthetic failing path
5. wrapper-level config
   - new v2 defaults and phases resolve to the intended grids and defaults

## 9) Documentation To Add Or Update

Keep the documentation explicit.

Recommended docs to add:

- a v2 strategy or proposal note:
  - `docs/PROPOSAL__qdesn_tau050_remaining_failed_mcmc_v2_strategy_20260418.md`
- a prepare-only report for the next relaunch
- a launch report for the next relaunch

Keep and reference these existing docs:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`
- `docs/PROPOSAL__qdesn_sigmagam_warmup_design_20260417.md`
- `docs/NOTE__qdesn_sigmagam_warmup_implementation_20260417.md`
- `docs/NOTE__qdesn_rhsns_tau_policy_alignment_20260417.md`

## 10) Recommended Execution Order

The next chat should follow this order:

1. keep the current remaining-failure grids as the source of truth
2. implement failure instrumentation first
3. implement MCMC `latent_v` warmup
4. implement warmup-v2 updates
5. add tests
6. add a dedicated v2 defaults YAML
7. add wrapper support for:
   - canary
   - remaining `mcmc_al`
   - remaining `mcmc_exal`
8. run targeted tests
9. run prepare-only for:
   - canary
   - `remaining_failed_mcmc_al`
   - `remaining_failed_mcmc_exal`
10. launch canary first
11. if canary looks good, launch the full remaining-failed rerun

## 11) What The New Chat Should Avoid

The next chat should not:

- rerun the full 144-fit campaign
- overwrite the canonical refreshed-main defaults in place without a dedicated
  new run spec
- jump first to `max_steps_out` / `max_shrink` tuning
- treat `rhs_ns` as the only remaining issue
- assume the problem is only startup instability

Reason:

- the current remaining failures include both early and late crashes
- both `rhs_ns` and `ridge` still fail
- the current failure signature is not slice-exhaustion

## 12) Suggested Opening Prompt For A Fresh Chat

Suggested summary to hand to a fresh chat:

1. We are in `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`.
2. Read:
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_handoff_20260418.md`
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`
3. The original tau050 refreshed-main campaign ended with `23` failed MCMC fits.
4. A first failed-only rerun recovered `5` and still failed `18`.
5. All `18` repeat failures are still `latent_v ... invalid draws ... NA`.
6. The next task is to implement a reproducible v2 recovery path with:
   - better latent-`v` failure instrumentation
   - MCMC latent-`v` warmup
   - stronger warmup-v2
   - tests
   - dedicated v2 defaults and relaunch wrappers
7. Use the remaining-failure grids:
   - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv`
   - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv`

This prompt should be enough for a new chat to continue without losing the
current state.
