# QDESN 0.4.0 Core Sync And Validation Freeze

Date: `2026-04-16`

## Purpose

Freeze the current QDESN validation state before pulling the latest package-core updates from
`origin/cransub/0.4.0` into the active QDESN integration branch
`feature/qdesn-mcmc-alternative-0p4p0-integration`.

The key rule for this sync is:

- `origin/cransub/0.4.0` stays free of QDESN workflow scripts;
- the active QDESN branch absorbs the newer `0.4.0` package-core work and keeps the QDESN layer on
  top of it.

## Sync Scope

This is a follow-on `0.4.0` sync, not the first one. The current branch already contains an older
merge of `cransub/0.4.0` at:

- `975c509 Merge branch 'cransub/0.4.0' into feature/qdesn-mcmc-alternative-0p4p0-integration`

The current sync brings in the `15` newer commits now present on `origin/cransub/0.4.0`, focused on:

- static `al` / `exal` package-core workflows
- `VB` / `MCMC` package-core updates
- transfer-function wrappers, including `MCMC`
- package docs, diagnostics, and tests

The merge conflict surface was small and limited to:

- `NAMESPACE`
- `R/exal_static_LDVB.R`

Resolution rule:

- keep QDESN-side exports and wiring;
- add the new `0.4.0` package-core exports and diagnostics;
- preserve the richer LDVB progress output while keeping the upstream stabilization logic.

## Frozen Validation Evidence

The finished deep-DESN validation work remains valid branch-local evidence from the pre-sync code
state and is now frozen as a checkpoint.

Primary frozen artifacts:

- row-faithful replay closeout:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_closeout_and_failure_audit_20260416.md`
- finished replay run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-20260412-124648__git-7144048`
- deep-DESN comparison pack:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_outputs_20260416.md`
- finished comparison-analysis run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500`

Interpretation:

- the replay and comparison pack are still the correct evidence for the pre-sync branch state;
- they should not be discarded;
- but they should also not be treated as the final post-sync validation answer.

## Why A Fresh Relaunch Is Required

The newly synced `0.4.0` package-core changes directly touch shared inference behavior used by the
QDESN branch, especially:

- `R/exal_static_LDVB.R`
- `R/exal_static_mcmc.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `R/utils.R`
- transfer-function helpers and wrappers

Because of that, the deep-DESN validation study should be rerun from scratch after the sync rather
than reusing the pre-sync outputs as if they were final.

## Validation Performed On The Sync

The synced branch was validated with focused package-core and QDESN touchpoint tests:

- `tests/testthat/test-transfer-mcmc-wrapper.R`
- `tests/testthat/test-static-diagnostics.R`
- `tests/testthat/test-static-p025-stability.R`
- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/test-qdesn-prior-defaults.R`
- `tests/testthat/test-pipeline-inference-validation.R`
- `tests/testthat/test-qdesn-dynamic-failure-repair.R`
- `tests/testthat/test-qdesn-validation-group-summary-robustness.R`

## Current Branch-Level Decision

Current branch state after the sync:

- absorb the newer `0.4.0` package-core updates into the QDESN integration branch;
- keep the QDESN workflow layer and documentation;
- freeze the completed validation artifacts as pre-sync evidence;
- plan the next deep-DESN validation relaunch from scratch on top of the synced package core.
