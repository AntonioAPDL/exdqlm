# Original288 Dynamic TT5000 Operator Stop Freeze

Date: 2026-04-16

## Purpose

This note freezes the current partial `TT5000` postfix repair lane on the
synced `0.4.0` integration branch and records the operator stop decision taken
before any further continuation.

The immediate goal is to preserve the exact stop-state evidence, keep the
accepted publication-target baseline explicit, and make clear that the next
dynamic relaunch must start from scratch after the branch is resynced to the
latest remote `cransub/0.4.0` package state.

## Decision Summary

- accepted publication-target baseline remains `v7`:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- the partial `original288_dynamic_tt5000_postfix_repair_20260415` lane is now
  frozen as diagnostic evidence only
- no result from this partial postfix lane is eligible for promotion into the
  accepted baseline
- the branch must first absorb the newer package-function updates from
  `origin/cransub/0.4.0`
- the next dynamic validation rerun should restart from scratch after that sync
  rather than resuming the stopped phase-2 queue

## Why The Current Lane Was Stopped

Several issues had converged enough that continuing the live run would have
made the branch state harder to interpret rather than more reliable.

### 1. Workstream confusion was real

- the live lane was still the legacy `original288` dynamic repair corridor
  using the accepted broader dynamic tau grid `0p05 / 0p25 / 0p95`
- that is distinct from the separate paper-aligned static benchmark direction
  using `0.05 / 0.25 / 0.50`
- because both lines were being discussed near each other, continuing the live
  dynamic lane without a freeze note risked further conflation

### 2. The branch package code was behind remote `0.4.0`

At stop time, `origin/cransub/0.4.0` was ahead of this branch on package-side
changes affecting the current validation environment.

Main remote update groups not yet present on this branch at the stop point:

- dynamic / static fit progress and output cleanup:
  - `8b790c9`
  - `a0122df`
  - `33e5c5f`
  - `e0d2830`
  - `f871d98`
  - `3a38a43`
- dynamic MCMC default-policy update:
  - `5ca7ba3`
- static LDVB / Example-4 robustness and signoff updates:
  - `e006ed7`
  - `1429427`
  - `4410a76`
  - `5f99aeb`
  - `1aa9d96`
- transfer-function workflow / wrapper updates:
  - `b8bd6db`
  - `668685f`

Affected tracked package files in the branch comparison:

- `R/exal_static_mcmc.R`
- `R/exdqlmISVB.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmMCMC.R`
- `R/utils.R`
- `man/exdqlmMCMC.Rd`

### 3. The live postfix lane was still scientifically unfavorable

- phase 1 exact replay had completed, but phase 2 historical repair remained
  fully unhealthy on all completed rows
- continuing the same lane before the package sync would have spent more time
  on a branch state that was no longer the desired package baseline

### 4. Earlier replay ambiguity had not earned another incremental extension

- the exact-spec replay work had already surfaced provenance drift and control
  ambiguity
- the current postfix lane was therefore best treated as a partial diagnostic
  checkpoint, not as something to extend indefinitely while the package line
  remained behind remote `0.4.0`

## Operator Stop Snapshot

Stop timestamp:

- `2026-04-16 19:43:06 EDT`

Active phase-2 rows immediately before the stop:

- `187`
- `188`

These were interrupted by the operator stop and therefore remain part of the
pending inventory together with the not-yet-started rows.

### Phase Summary At Stop

| scope | total | done | missing | pass | warn | fail | healthy |
|---|---:|---:|---:|---:|---:|---:|---:|
| phase 1 exact replay | `144` | `144` | `0` | `12` | `60` | `72` | `72` |
| phase 2 historical repair | `52` | `42` | `10` | `0` | `0` | `42` | `0` |
| overall postfix lane | `196` | `186` | `10` | `12` | `60` | `114` | `72` |

### Phase-2 Completed Rows By Tau At Stop

| tau | completed | healthy | fail |
|---|---:|---:|---:|
| `0p05` | `10` | `0` | `10` |
| `0p25` | `24` | `0` | `24` |
| `0p95` | `8` | `0` | `8` |

### Pending Phase-2 Inventory At Stop

- pending rows:
  - `187`
  - `188`
  - `189`
  - `190`
  - `191`
  - `192`
  - `193`
  - `194`
  - `195`
  - `196`

## Freeze Interpretation

- accepted `v7` remains the latest defensible publication-target baseline
- the partial postfix lane does **not** replace or weaken that accepted state
- the committed manifest changes for this lane should be read only as a
  stop-state record of what had been built and what had completed before the
  reset
- the correct next move is branch/package stabilization first, then a clean
  rerun from scratch

## Restart Policy

Before any fresh validation rerun:

1. sync this branch to the latest remote `cransub/0.4.0` package-function
   state
2. rerun package verification on the synced branch
3. refresh the relaunch definition explicitly so the intended tau grid and lane
   purpose are unambiguous
4. rebuild the new manifests from scratch
5. do **not** resume the stopped phase-2 queue in place

## Freeze Artifacts

Primary stop-state artifacts now associated with this freeze:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_full_manifest_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase2_manifest_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_full_manifest_status_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase2_manifest_status_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_full_phase_summary_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase2_phase_summary_20260415.csv`

This note should be read together with:

- `reports/static_exal_tuning_20260415/original288_dynamic_tt5000_postfix_repair_execution_20260415.md`
- `reports/static_exal_tuning_20260415/original288_dynamic_tt5000_rootcause_debug_20260415.md`
- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`
