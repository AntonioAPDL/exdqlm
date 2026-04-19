# Refreshed288 Runtime Failures Versus QDESN Latent-v Failures

Date: `2026-04-18`

## Purpose

This note compares:

- the current refreshed288 runtime-crash surface in this repo
- the similar QDESN dynamic-validation runtime-crash surface documented in:
  - `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_handoff_20260418.md`
  - `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_investigation_20260418.md`

The goal is to decide what transfers cleanly from the QDESN recovery plan into the current
refreshed288 crash-recovery plan, and what needs a different implementation because the fragile
latent block is not exactly the same.

## Executive read

The two studies are similar in a very important way:

- both are failing on dynamic data
- both are failing in an early latent-variable path
- both show that warmup is directionally useful but not sufficient by itself
- both need a dedicated crash-only rerun lane, separate from mixing failures

But they differ in one equally important way:

- in QDESN, the first fragile block is explicitly `latent_v`
- in refreshed288 dynamic MCMC, the first fragile block is the `Ut / st` latent block
  immediately before the `sigma/gamma` step

So the QDESN idea does transfer, but it must be translated.

The right analogue here is not literally “add latent-v warmup.”  
The right analogue is:

- add an explicit **latent-state warmup** for `Ut` in DQLM
- add an explicit **latent-state warmup** for the `Ut + st` pair in exDQLM
- add a **DQLM sigma-only warmup** because current `sigmagam` warmup does not touch the DQLM branch

## Similarities

### 1. Same dynamic source surface

Both studies target the same synthetic dynamic source family:

- scenario: `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.50`
- fit sizes:
  - `500`
  - `5000`

That means the failure comparison is scientifically meaningful. We are not comparing unrelated data
or unrelated DGPs.

### 2. Runtime crashes are distinct from mixing failures

In both studies the current question is about hard fit termination, not poor-signoff chains.

QDESN:

- dominant repeat failure: `latent_v returned ... invalid draws ... value=NA`

Refreshed288:

- dominant runtime failures:
  - `invalid state before chi update`
  - `chi has ... non-finite values`
  - `ldvb_q_t1 is NA`

So in both repos the operational plan must keep runtime crashes separate from later
mixing/diagnostic triage.

### 3. Warmup helped, but did not finish the job

QDESN:

- first failed-only rerun recovered `5 / 23`
- `18 / 23` still failed again

Refreshed288:

- the canonical run completed most of the study
- the remaining numerical crash surface is still concentrated in dynamic MCMC plus one direct
  dynamic VB row

Interpretation shared by both studies:

- stronger warmup is not a dead end
- but “just a bit more of the same warmup” is unlikely to be the whole answer

### 4. Slice tuning is not the first lever

QDESN investigation conclusion:

- kernel changes are reasonable as a secondary pilot, not the first undifferentiated move

Refreshed288 investigation conclusion:

- in `R/exdqlmMCMC.R:873-950`, slice gamma happens only after the fragile latent-state path
- therefore `slice_width` is secondary, not primary

This is a strong point of agreement between the two studies.

## Main differences

### 1. The fragile latent block is different

QDESN MCMC update order in `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R:1761-1778`:

1. compute `chi_v` and `psi_v`
2. sample `v`
3. sample `s`
4. sample `beta`
5. then later move into prior and `sigmagam`

So in QDESN the first fragile step is literally the explicit latent `v` draw.

Refreshed288 exDQLM update order in `R/exdqlmMCMC.R:873-950`:

1. derive `tau`, `a_tau`, `b_tau`, `c_tau`
2. sample `theta`
3. sample `Ut`
4. sample `st`
5. only then update `sigma/gamma`

Refreshed288 DQLM update order in `R/exdqlmMCMC.R:1392-1415`:

1. sample `theta`
2. check `sigma` and `reg1`
3. sample `Ut`
4. sample `sigma`

So the current-study analogue of QDESN `latent_v` is:

- DQLM: `Ut`
- exDQLM: the `Ut` draw, plus the coupled `st` update

### 2. The current refreshed288 failures are much more front-loaded

QDESN:

- failures split into early, burn-phase, and late keep-phase crashes
- that justified considering kernel changes after warmup-v2

Refreshed288:

- the dominant runtime signatures are at `iter=1`
- `invalid_pre_chi` and `nonfinite_chi` are startup crashes
- the crash surface is more obviously an initialization / first-latent-update problem

This difference matters a lot for prioritization:

- QDESN reasonably escalates sooner toward kernel experimentation
- refreshed288 should stay more init-and-latent-warmup-led first

### 3. Current refreshed288 has a DQLM warmup gap that QDESN does not have

In the current refreshed288 code:

- `sigmagam` MCMC warmup is only active in the exDQLM branch
- see `R/exdqlmMCMC.R:891-978`

But the DQLM branch:

- goes directly into `Ut` and then `sigma`
- see `R/exdqlmMCMC.R:1398-1415`
- has no analogous sigma freeze or latent-state freeze at all

That means the current dynamic DQLM failure surface is even less protected than the exDQLM one.

This is not the same as QDESN, where the proposed latent-v warmup is a shared MCMC-side control
surface.

### 4. Current refreshed288 failures split by model in a very structured way

Current runtime crash split:

- DQLM:
  - `invalid state before chi update`
- exDQLM:
  - `chi has ... non-finite values`
- direct VB:
  - `ldvb_q_t1 is NA`

That is more structured than the current QDESN remaining-failure surface, where the remaining hard
signature is much more uniformly latent-`v` invalid draws.

So the current-study plan should be lane-specific:

- direct VB crash lane
- DQLM dynamic-MCMC crash lane
- exDQLM dynamic-MCMC crash lane

## What transfers directly from the QDESN plan

These ideas transfer cleanly:

### 1. Add warmup to the first fragile latent block

QDESN recommendation:

- add MCMC latent-`v` warmup/freeze scheduling

Current-study translation:

- add dynamic latent-state warmup/freeze scheduling
  - DQLM: freeze `Ut`
  - exDQLM: freeze `Ut` and `st` as a coordinated block

### 2. Keep warmup explicit and serialized

QDESN plan:

- add normalized `mcmc.latent_v.*` controls and export them into validation summaries

Current-study translation:

- add explicit latent-state warmup controls to package arguments
- serialize them through refreshed288 method profiles and rerun contracts
- export them into row-level summaries and failure notes

### 3. Add richer failure instrumentation

QDESN recommendation:

- persist failure-state details around the latent-`v` crash

Current-study translation:

- persist the pre-`Ut` or pre-`chi` state:
  - iter
  - burn vs keep
  - sigma
  - gamma when present
  - `reg1` finiteness
  - max abs `reg1`
  - max abs `theta`
  - summaries of `chi` and `psi`
  - whether latent-state warmup was active

### 4. Keep kernel changes secondary

QDESN:

- kernel tuning is a secondary pilot, not first move

Current study:

- same conclusion
- especially because current crashes happen before slice gamma is the main active lever

## What does not transfer directly

### 1. Do not literally implement “latent_v warmup” here

This repo does not have a single latent-`v` block in dynamic MCMC.

The correct translation is:

- DQLM `Ut` warmup
- exDQLM `Ut/st` warmup

### 2. Do not jump immediately to late-phase kernel pilots

QDESN had clear late keep-phase repeat failures.

Current refreshed288 runtime crashes are still mostly startup failures.

So for the current study:

- latent-state warmup and stronger init come first
- smaller `slice_width` remains a second arm only

### 3. Do not assume the current sigmagam warmup already protects DQLM

It does not.

That means a current-study plan copied too literally from QDESN would miss the DQLM warmup gap.

## Current-study plan

This is the recommended next plan for the crash-focused rerun lane in this repo.

### Phase 0. Finish and freeze the canonical run

Before launching anything new:

1. let the current canonical run finish
2. rerun `tools/merge_reports/LOCAL_refreshed288_extract_runtime_failure_audit_20260418.R`
3. freeze the final runtime-failure manifest and watchlist

Reason:

- the current runtime cohort is still changing while rows `60`, `62`, `64` are active

### Phase 1. Add current-study-specific instrumentation

Code target:

- `R/exdqlmMCMC.R`

Add failure-state capture around the first latent-state step:

- DQLM:
  - before `samp_uts`
  - record sigma, reg1 stats, theta stats
- exDQLM:
  - before `ex_samp_uts`
  - record chi/psi summaries, sigma, gamma, reg1 stats, `st` stats

Persist those diagnostics into:

- `status$error`
- returned diagnostics / `misc`
- refreshed288 failure summaries if the row ends in `failed_runtime`

This is the direct analogue of the QDESN “better latent-v failure instrumentation” recommendation.

### Phase 2. Add dynamic latent-state warmup controls

Code target:

- `R/exdqlmMCMC.R`

Add a new explicit control surface, for example:

- `latent_state_controls`

Recommended semantics:

- `freeze_burnin_iters`
- `freeze_only_during_burn`
- `force_after_warmup`
- `mode`
  - `u_only`
  - `u_st_pair`

Proposed primary-study mapping:

- DQLM:
  - `mode = "u_only"`
- exDQLM:
  - `mode = "u_st_pair"`

Recommended primary pilot default:

- `latent_state_controls$freeze_burnin_iters = 100`
- `freeze_only_during_burn = TRUE`
- `force_after_warmup = TRUE`

Why `100`:

- longer than the current small sigmagam freeze
- still far shorter than the full `5000` burn
- enough to target the immediate iter-1 crash surface without over-freezing the whole chain

Implementation behavior:

- during warmup:
  - keep `Ut` fixed at the VB-init value in DQLM
  - keep both `Ut` and `st` fixed at the VB-init values in exDQLM
- after warmup:
  - force the first real latent-state update once
  - then continue normally

### Phase 3. Add a DQLM sigma-only warmup

Code target:

- `R/exdqlmMCMC.R`

This is a current-study-specific requirement.

Recommended control:

- `dqlm_sigma_controls`
  - `freeze_burnin_iters = 500`
  - `freeze_only_during_burn = TRUE`
  - `force_after_warmup = TRUE`

Reason:

- the exDQLM branch already has `sigmagam` warmup
- the DQLM branch does not
- current DQLM failures are `invalid state before chi update`, so leaving sigma fully unfrozen is
  inconsistent with the crash surface we are trying to stabilize

### Phase 4. Keep the stronger-init contract

Keep the stronger primary rerun contract already documented in
`tools/merge_reports/LOCAL_refreshed288_runtime_failure_rerun_contract_20260418.csv`:

- direct dynamic VB:
  - `vb_max_iter = 800`
  - `vb_min_iter = 80`
  - `vb_tol = 0.01`
  - `sigmagam_vb_warmup_iters = 50`
  - `sigmagam_vb_min_postwarmup_updates = 5`
- dynamic MCMC VB init:
  - `vb_init_max_iter = 800`
  - `vb_init_min_iter = 80`
  - `vb_init_tol = 0.01`
  - `vb_init_n_samp = 5000`
  - `vb_init_sigmagam_warmup_iters = 50`
  - `vb_init_sigmagam_min_postwarmup_updates = 5`
  - damping `0.5` for `5` postwarmup iters
- exDQLM MCMC:
  - keep `sigmagam_mcmc_warmup_iters = 500`

Add to that contract:

- latent-state warmup `100`
- DQLM sigma warmup `500`

### Phase 5. Use a staged crash-only rerun

Recommended launch order:

1. direct VB row:
   - `11`
2. representative pilot rows:
   - DQLM invalid-pre-chi:
     - `6`
     - `30`
     - `54`
   - exDQLM non-finite-chi:
     - `8`
     - `32`
     - `72`
   - exDQLM `ldvb_q_t1`:
     - `12`
3. if the pilot is materially better, expand to the full runtime-failure cohort

This is the current-study analogue of the QDESN staged failed-only rerun idea.

### Phase 6. Only then consider secondary slice sensitivity

If exDQLM still crashes after:

- stronger VB init
- latent-state warmup
- larger `sigmagam` warmup

then open a secondary exDQLM-only arm:

- reduce `slice_width` from `0.10` to `0.05`
- keep `slice_max_steps = Inf`

This remains secondary.

## Files to modify next

Package-side:

- `R/exdqlmMCMC.R`

Refreshed288 study wiring:

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R`

Tests:

- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/test-static-diagnostics.R`

Documentation / launch tracking:

- `reports/static_exal_tuning_20260418/refreshed288_runtime_failure_investigation_and_rerun_plan_20260418.md`
- a new crash-focused rerun contract and run tag after the canonical run finishes

## Bottom line

The QDESN plan is useful here, but not because this repo should copy it literally.

The transferable lesson is:

- warm up the earliest fragile latent block
- instrument that block heavily
- keep kernel changes secondary

For the current refreshed288 study, the correct translation is:

- stronger VB init
- latent `Ut` warmup for DQLM
- latent `Ut/st` warmup for exDQLM
- new DQLM sigma-only warmup
- crash-only staged rerun after the canonical run finishes
