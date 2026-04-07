# Original-288 Synced-Base Rerun Program

Date: 2026-04-06

## Purpose

This program starts the **true rerun / revalidation** of the accepted original
`288` study-cell map on the synced `0.4.0` integration branch.

The scientific baseline for this phase is the accepted carry-forward `v4`
state:

- `282 / 288` healthy
- `6 / 288` unresolved

That accepted state is currently evidence-backed by predecessor-worktree
artifacts. This program does **not** try to fix the remaining `6` unresolved
cells yet. It instead asks a different question:

> if we replay the accepted current per-case configuration map on the synced
> `0.4.0` base, how much of the `282 / 288` accepted healthy state reproduces?

## Worktree / Branch Context

Historical evidence source only:

- predecessor worktree:
  `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- predecessor branch:
  `validation/rerun-after-0.4.0-sync`

Active synced rerun branch:

- active worktree:
  `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- active branch:
  `validation/rerun-after-0.4.0-sync-0p4p0-integration`

## Key Design Choice

This rerun uses the **accepted per-case repaired baseline**, not the old raw
March broad-default baseline.

Reason:

- many accepted healthy rows were promoted from local repairs or later dynamic
  rescue lanes
- some static healthy cells now rely on repaired `rhs_ns`-style settings even
  when the original raw baseline cell had weaker settings
- the correct object to validate is the current accepted publication-target
  map, not the obsolete pre-repair default schedule

## Input / Output Split

Read-only historical inputs come from the predecessor worktree:

- `method_signoff_long.csv`
- `run_config.rds`
- `sim_output.rds`
- accepted selected fit paths from `v4`

Fresh rerun outputs are written into the synced integration worktree:

- mirrored scenario `results/.../fits/.../*_orig288_sync0p4p0_reval_20260406.rds`
- run telemetry and row-health under:
  `tools/merge_reports/full288_original288_syncedbase_rerun_20260406`

This preserves the predecessor worktree as historical evidence and makes the
new rerun genuinely belong to the synced `0.4.0` code base.

## Health Convention

Carry-forward and rerun health use the existing gate convention:

- `PASS` = healthy
- `WARN` = healthy but suspicious
- `FAIL` = unresolved / unhealthy

Operationally:

- healthy = `PASS` or `WARN`

## Phase Plan

The full `288` rerun is split into three automatic phases:

| phase | rows | intent | parallelism |
|---|---:|---|---:|
| `phase1_vb_all` | `144` | rerun every accepted VB row first | `24` |
| `phase2_static_mcmc` | `108` | rerun static accepted MCMC rows after VB | `12` |
| `phase3_dynamic_mcmc` | `36` | rerun dynamic accepted MCMC rows last | `8` |

Why this shape:

- VB runs are cheapest and also provide fresh same-tag warm starts
- static MCMC is the largest heavy block but can safely use moderate parallelism
- dynamic MCMC is the most sensitive rerun block and should reuse fresh synced
  VB outputs where available

## Configuration Replay Rules

Per-row replay is reconstructed from the accepted selected fit:

- dynamic `mcmc`:
  replay accepted kernel family, joint-sample flag, adaptation, trace rate,
  slice settings, and refresh settings from the selected fit object
- static `mcmc`:
  replay accepted prior family, prior controls, `init_from_vb`, burn, keep,
  thin, and MH settings from the selected fit object
- static `vb`:
  replay accepted prior family and prior controls from the selected fit object
- dynamic `vb`:
  use the current scenario config from the historical validation tree

This is the minimum faithful replay needed to test the accepted `v4` map on the
synced code base.

## What This Program Does Not Do

- it does **not** try to repair the remaining `6` unresolved cells
- it does **not** reopen static tuning
- it does **not** reuse the hybrid `291` assembly
- it does **not** overwrite historical predecessor outputs

## Success Criterion

The first checkpoint question after this rerun is:

- how many of the accepted `282` healthy rows still rerun as `PASS` or `WARN`
  on the synced `0.4.0` base?

Only after that rerun is complete should we summarize:

- healthy reproduced
- warn reproduced
- unresolved still unresolved
- any newly regressed cells
