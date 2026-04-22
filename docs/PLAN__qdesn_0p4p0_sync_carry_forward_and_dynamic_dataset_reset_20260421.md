# Plan: 0.4.0 Sync Carry-Forward and Dataset-Reset Staging

Date: 2026-04-21

## Goal

Bring the current QDESN validation-study branch into line with the authoritative
`0.4.0` package surface while preserving the warmup, freeze, and
numerical-stability improvements that were required to recover the tau050
validation program.

This plan intentionally stops before changing the dynamic datasets.

## Scope

### In Scope

- align package-facing API names with upstream `0.4.0`
- restore reusable warmup and numerical-stability features from the proven
  validation backport
- preserve stronger newer QDESN-side recovery logic where it goes beyond the
  backport
- update package-facing docs and examples to follow the `0.4.0` API
- regenerate package metadata and verify focused regression coverage
- leave a clear carry-forward checklist for the follow-on validation-study repo

### Out of Scope

- changing the dynamic datasets
- rerunning the tau050 study
- porting validation-orchestration scripts into the package layer

## Carry-Forward Rules

| Decision area | Rule |
|---|---|
| Public naming | follow upstream `0.4.0` |
| Dynamic warmup / freeze | preserve the strongest validation-derived behavior |
| Static warm-start / warmup | preserve validation-derived warm-start plumbing inside the upstream package shape |
| VB trace diagnostics | keep the upstream `0.4.0` trace framework compatible with shorter validation warmup traces |
| QDESN precision rescue | keep the newer QDESN-side implementation |
| Validation runner/report code | do not backport into the package layer |

## Verification Gate Before Dataset Changes

Before any future dynamic-dataset reset, the synced branch must pass:

- package load / namespace generation
- focused warmup and convergence regression tests
- static diagnostics and shared-helper regression tests
- documentation regeneration without misleading churn

Only after that gate should the next repo start the dynamic-dataset swap.

## Follow-On Work After This Sync

Once this sync is complete and verified:

1. update the `0.4.0` validation-study repo using the carry-forward checklist
2. make the dynamic-dataset change there
3. run minimal canaries first
4. then rerun the larger validation surfaces on the new datasets
