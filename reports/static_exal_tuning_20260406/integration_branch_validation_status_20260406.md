# Exdqlm Validation Status on Synced 0.4.0 Integration Branch

Date: 2026-04-06

## Purpose

This note records the current validation status after moving the exdqlm
validation study onto the synced `0.4.0` continuation branch.

It separates two different concepts that must not be conflated:

1. the **accepted publication-target carry-forward state** for the original
   `288` study cells
2. the **rerun-on-this-branch state** for the new synced
   `validation/rerun-after-0.4.0-sync-0p4p0-integration` worktree

## Branch / Worktree Lineage

Predecessor validation worktree and branch:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- branch:
  `validation/rerun-after-0.4.0-sync`

Current active synced continuation point:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- branch:
  `validation/rerun-after-0.4.0-sync-0p4p0-integration`

Integration-base merge commit:

- `66d1e3e`
- summary:
  merge `cransub/0.4.0` into the validation continuation branch

Current synced tracker checkpoint commit on this branch:

- `f9694b9`
- summary:
  incorporate the latest tail-7 `rw` promotion and tracker refresh

## Canonical Status Files

Primary operational tracker for the residual original-`288` study:

- `tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md`

Primary branch-level readiness / historical rollup:

- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`

Primary accepted carry-forward artifacts:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v4_20260406.csv`
- `tools/merge_reports/LOCAL_original288_row_health_v4_20260406.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v4_20260406.csv`
- `tools/merge_reports/LOCAL_original288_recovery_block_status_v4_20260406.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v4_20260406.csv`
- `tools/merge_reports/LOCAL_original288_audit_v4_20260406.csv`

Latest completed residual execution report:

- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_execution_20260406.md`

## Case Universe In Scope

The active publication-target case universe is the corrected original `288`
study-cell registry:

- `72` `static_paper`
- `144` `static_shrink`
- `72` `dynamic`

Grid structure:

- `static_paper`:
  `3` families x `3` taus x `2` sample sizes x `2` models x `2` inference
- `static_shrink`:
  `3` families x `3` taus x `2` sample sizes x `2` prior semantics x
  `2` models x `2` inference
- `dynamic`:
  `3` families x `3` taus x `2` horizons x `2` models x `2` inference

The families remain:

- `gausmix`
- `laplace`
- `normal`

## Health Convention

The active carry-forward uses the existing gate convention:

- `PASS`: healthy and accepted
- `WARN`: non-failing / usable, but still suspicious or uncertified on some
  diagnostic dimension
- `FAIL`: broken, inconsistent, or not acceptable as a healthy final fit

Operationally, the study currently treats:

- `healthy = PASS or WARN`
- `unhealthy = FAIL`

This is the convention encoded in the row-health and health-summary files.

## Accepted Carry-Forward Status

Accepted publication-target state under `v4`:

- overall healthy: `282 / 288`
- overall unresolved: `6 / 288`
- dynamic healthy: `66 / 72`
- static paper healthy: `72 / 72`
- static shrink healthy: `144 / 144`

Accepted gate breakdown:

| slice | total | PASS | WARN | FAIL | healthy |
|---|---:|---:|---:|---:|---:|
| overall | `288` | `195` | `87` | `6` | `282` |
| dynamic | `72` | `27` | `39` | `6` | `66` |
| static_paper | `72` | `56` | `16` | `0` | `72` |
| static_shrink | `144` | `112` | `32` | `0` | `144` |

Method-level breakdown of the accepted state:

| block | model | inference | PASS | WARN | FAIL |
|---|---|---|---:|---:|---:|
| dynamic | `dqlm` | `mcmc` | `12` | `6` | `0` |
| dynamic | `dqlm` | `vb` | `11` | `7` | `0` |
| dynamic | `exdqlm` | `mcmc` | `4` | `8` | `6` |
| dynamic | `exdqlm` | `vb` | `0` | `18` | `0` |
| static_paper | `al` | `mcmc` | `18` | `0` | `0` |
| static_paper | `al` | `vb` | `18` | `0` | `0` |
| static_paper | `exal` | `mcmc` | `8` | `10` | `0` |
| static_paper | `exal` | `vb` | `12` | `6` | `0` |
| static_shrink | `al` | `mcmc` | `36` | `0` | `0` |
| static_shrink | `al` | `vb` | `36` | `0` | `0` |
| static_shrink | `exal` | `mcmc` | `16` | `20` | `0` |
| static_shrink | `exal` | `vb` | `24` | `12` | `0` |

## Latest Completed Validation Campaign

The latest completed residual campaign is:

- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_execution_20260406.md`

That campaign:

- targeted only the remaining `7` unresolved dynamic `exdqlm :: mcmc` cells
- completed with `14 / 14` rows done
- produced `1` promotable improvement
- promoted:
  - `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
  - from `FAIL` to `WARN`

After that promotion, the accepted carry-forward moved from:

- `281 / 288` healthy
- `7 / 288` unresolved

to:

- `282 / 288` healthy
- `6 / 288` unresolved

## Remaining Failing Cases

The current unresolved accepted tail is:

- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Shape of remaining unresolved tail:

- all `6` are `dynamic`
- all `6` are `exdqlm :: mcmc`
- `3` are `TT500`
- `3` are `TT5000`
- `5` are `tau = 0p05`
- `1` is `tau = 0p25`

## Rerun Status on This Synced Integration Branch

This is the critical distinction for the new branch:

- accepted carry-forward status exists and is current
- but the accepted evidence still points to the predecessor validation
  worktree outputs

Observed fit-path provenance in the accepted `v4` row-health file:

- selected fit paths in new integration worktree:
  - `0 / 288`
- selected fit paths in predecessor worktree:
  - `288 / 288`

So the rerun status **on this synced integration branch itself** is:

- `0 / 288` rerun here on the updated `0.4.0` continuation base
- `288 / 288` still pending rerun here if the scientific goal is
  base-synchronized revalidation rather than carry-forward acceptance

Therefore:

- accepted publication-target status: `282 healthy / 6 fail`
- rerun-on-synced-base status: effectively **pending**

## Synced-Base Replay Status

The first broad synced-base rerun attempted on this branch is now deprecated.

Deprecated program:

- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_program_20260406.md`
- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_execution_20260406.md`

Deprecation reason:

- static and dynamic MCMC replay were not faithful enough to the accepted
  historical reference state
- in particular, MCMC rows were not consistently inheriting accepted replay
  controls, and original `static_shrink::rhs` rows were not uniformly replayed
  under `rhs_ns`

The active replacement program on this branch is now:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_execution_20260407.md`

Validated faithful-replay structure:

| phase | rows | purpose |
|---|---:|---|
| `phase1_vb_all` | `144` | replay all accepted healthy VB rows |
| `phase2_static_paper_mcmc` | `36` | faithful replay of paper-static MCMC |
| `phase3_static_shrink_ridge_mcmc` | `36` | faithful replay of shrink ridge MCMC |
| `phase4_static_shrink_rhsns_mcmc` | `36` | faithful replay of shrink rhs rows under forced `rhs_ns` |
| `phase5_dynamic_mcmc` | `30` | faithful replay of accepted healthy dynamic MCMC |

Validated operational assumptions:

- accepted reference state still checks out as:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- this faithful replay intentionally scopes to the accepted healthy `282`
  rows only
- predecessor-worktree input files are readable for all reference rows
- all MCMC replay rows have accepted companion VB reference fits
- all original `static_shrink::rhs` replay rows now use
  `prior_override = rhs_ns`
- current prelaunch faithful-replay state is:
  - `0 / 282` done
  - `282 / 282` pending

## Interpretation

The synced integration branch is now the correct place to continue the study,
because it contains:

- the updated `0.4.0` base
- the latest accepted validation-tracker state
- the accepted `v4` carry-forward artifacts

But it is not yet true that the original `288` study has been rerun on this
updated base. What exists here right now is:

- a clean synced continuation branch
- plus the accepted carry-forward state imported from the predecessor
  validation worktree

## Highest-Priority Next Validation Tasks

1. Freeze this branch as the active synced continuation point.
2. Treat the accepted `v4` state as the working baseline for planning.
3. Treat the deprecated `2026-04-06` synced-base rerun as invalid for
   scientific comparison.
4. Execute the faithful replay of the accepted healthy `282` rows first.
5. After the faithful replay completes, summarize:
   - reproduced healthy rows
   - rows that regress on the synced base under faithful replay
   - any residual static vs dynamic discrepancy patterns
6. Only after that should the unresolved `6` dynamic repair tail be reopened.
