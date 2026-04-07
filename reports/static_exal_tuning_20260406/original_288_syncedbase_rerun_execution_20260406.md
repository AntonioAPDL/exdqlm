# Original-288 Synced-Base Rerun Execution

Date: 2026-04-06

## Purpose

Execution log for the full rerun / revalidation of the accepted original `288`
study-cell map on the synced `0.4.0` integration branch.

## Prelaunch Reference State

Accepted carry-forward `v4` state before launch:

- `282 / 288` healthy
- `6 / 288` unresolved
- `72 / 72` `static_paper` healthy
- `144 / 144` `static_shrink` healthy
- `66 / 72` `dynamic` healthy

This accepted state still points to predecessor-worktree fit evidence.

## Launch Design

Program:

- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_program_20260406.md`

Prepared artifacts:

- `tools/merge_reports/LOCAL_original288_registry_syncedbase_source_v1_20260406.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_rerun_manifest_20260406.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_rerun_stage_counts_20260406.csv`

Prepare/evaluate validation:

- prepare completed successfully on the synced branch
- accepted reference check:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- manifest rows: `288`
- missing inputs: `0`
- prelaunch evaluate:
  - `0 / 288` done
  - `288 / 288` pending

Automatic phase order:

1. `phase1_vb_all`
2. `phase2_static_mcmc`
3. `phase3_dynamic_mcmc`

Parallel budgets:

- `phase1_vb_all`: `24`
- `phase2_static_mcmc`: `12`
- `phase3_dynamic_mcmc`: `8`

## Initial Launch Note

This rerun reads historical validation inputs from:

- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

and writes fresh rerun outputs into the synced integration worktree:

- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`

That keeps the predecessor worktree as read-only evidence and makes the rerun a
true synced-base validation campaign.
