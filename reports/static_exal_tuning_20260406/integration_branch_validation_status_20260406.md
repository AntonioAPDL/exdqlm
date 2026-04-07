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

Current synced tracker checkpoint on this branch:

- `2026-04-07` post-residual-repair refresh
- scope:
  - apply residual strict improvements into accepted `v6`
  - document the completed residual repair outcome
  - document the next targeted synced-base follow-up queue

## Canonical Status Files

Primary operational tracker for the residual original-`288` study:

- `tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md`

Primary branch-level readiness / historical rollup:

- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`

Primary accepted carry-forward artifacts:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v6_20260407.csv`
- `tools/merge_reports/LOCAL_original288_row_health_v6_20260407.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v6_20260407.csv`
- `tools/merge_reports/LOCAL_original288_recovery_block_status_v6_20260407.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v6_20260407.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_inventory_v6_20260407.csv`

Latest completed rerun execution report:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`

Active residual repair planning / execution notes:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_execution_20260407.md`

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

Accepted publication-target state under `v6`:

- overall healthy: `282 / 288`
- overall unresolved: `6 / 288`
- dynamic healthy: `66 / 72`
- static paper healthy: `72 / 72`
- static shrink healthy: `144 / 144`

Accepted gate breakdown:

| slice | total | PASS | WARN | FAIL | healthy |
|---|---:|---:|---:|---:|---:|
| overall | `288` | `227` | `55` | `6` | `282` |
| dynamic | `72` | `56` | `10` | `6` | `66` |
| static_paper | `72` | `56` | `16` | `0` | `72` |
| static_shrink | `144` | `115` | `29` | `0` | `144` |

Method-level breakdown of the accepted state:

| block | model | inference | PASS | WARN | FAIL |
|---|---|---|---:|---:|---:|
| dynamic | `dqlm` | `mcmc` | `17` | `1` | `0` |
| dynamic | `dqlm` | `vb` | `18` | `0` | `0` |
| dynamic | `exdqlm` | `mcmc` | `6` | `6` | `6` |
| dynamic | `exdqlm` | `vb` | `15` | `3` | `0` |
| static_paper | `al` | `mcmc` | `18` | `0` | `0` |
| static_paper | `al` | `vb` | `18` | `0` | `0` |
| static_paper | `exal` | `mcmc` | `8` | `10` | `0` |
| static_paper | `exal` | `vb` | `12` | `6` | `0` |
| static_shrink | `al` | `mcmc` | `36` | `0` | `0` |
| static_shrink | `al` | `vb` | `36` | `0` | `0` |
| static_shrink | `exal` | `mcmc` | `19` | `17` | `0` |
| static_shrink | `exal` | `vb` | `24` | `12` | `0` |

## Latest Completed Validation Campaign

The latest completed rerun campaign is:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`

That campaign:

- reran the faithful-replay residual queue only
- completed with `84 / 84` rows done
- yielded:
  - `55 PASS`
  - `10 WARN`
  - `19 FAIL`
  - `65 / 84` healthy
- recovered:
  - all `54 / 54` static `al :: mcmc` rows to non-`FAIL`
  - `11 / 27` static `exal :: mcmc` rows to non-`FAIL`
  - `0 / 3` dynamic `exdqlm :: mcmc` rows to non-`FAIL`
- comparison against accepted:
  - `60` matched accepted status
  - `1` was better than accepted
  - `23` were worse than accepted

The one strict improvement was promoted into accepted `v6`, which keeps the
overall accepted publication-target state at:

- `282 / 288` healthy
- `6 / 288` unresolved

while improving the pass/warn split from:

- `226 PASS / 56 WARN / 6 FAIL`

to:

- `227 PASS / 55 WARN / 6 FAIL`

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

Observed fit-path provenance in the accepted `v6` row-health file:

- selected fit paths in new integration worktree:
  - `32 / 288`
- selected fit paths in predecessor worktree:
  - `256 / 288`

So the rerun-on-synced-base status is no longer pending in the broad sense:

- faithful replay of the accepted healthy `282` rows is complete
- first-pass residual repair of the replay failures is complete
- the remaining synced-base work is now a much smaller targeted follow-up
  queue of:
  - `16` static `exal :: mcmc` fail rows
  - `3` dynamic `exdqlm :: mcmc` fail rows
  - `4` PASS-to-WARN stability-review rows
- the accepted unresolved dynamic tail of `6` remains deferred and separate

Therefore:

- accepted publication-target status: `282 healthy / 6 fail`
- synced-base rerun status:
  - broad fidelity replay complete
  - residual repair complete
  - targeted follow-up now active

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

The active replacement sequence on this branch is now:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_execution_20260407.md`

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
- faithful-replay final state is:
  - `282 / 282` done
  - `198 / 282` healthy
  - `84 / 282` fail

## Faithful-Replay Closeout and Residual Repair Status

The faithful replay answered the main synced-base question clearly:

- `VB` reproduced cleanly
- `dynamic :: mcmc` reproduced reasonably
- the dominant residual problem is now `static :: mcmc`

Observed failure queue after faithful replay:

| residual lane | rows | interpretation |
|---|---:|---|
| `phase1_static_al_mcmc_bugfix` | `54` | invalid runtime failures caused by a shared proposal-resolution bug |
| `phase2_static_exal_mcmc_exact` | `27` | completed-but-unhealthy static `exal :: mcmc` rows needing exact replay / local repair |
| `phase3_dynamic_exdqlm_mcmc_exact` | `3` | completed-but-unhealthy dynamic `exdqlm :: mcmc` rows needing exact replay |
| `total residual queue` | `84` | active next-phase repair scope |

Key interpretation:

- all `54` static `al :: mcmc` failures are operationally invalid
- the remaining `30` rows are scientifically meaningful unhealthy reruns
- the unresolved accepted tail of `6` dynamic `exdqlm :: mcmc` rows remains
  separate from this residual queue and should be reopened only after the
  replay-repair checkpoint is complete

The active next-phase program is now:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`

## Interpretation

The synced integration branch is now the correct place to continue the study,
because it contains:

- the updated `0.4.0` base
- the latest accepted validation-tracker state
- the accepted `v5` carry-forward artifacts

What exists here right now is:

- a clean synced continuation branch
- the accepted `v5` carry-forward state
- a completed faithful replay of the accepted healthy `282` rows
- a fully enumerated residual repair queue for the replay regressions

## Highest-Priority Next Validation Tasks

1. Freeze this branch as the active synced continuation point.
2. Treat accepted `v5` as the working publication-target baseline.
3. Treat the deprecated `2026-04-06` broad rerun as invalid for scientific
   comparison.
4. Repair the `84` faithful-replay failures in the residual order:
   - static `al :: mcmc` bug-fix replay
   - static `exal :: mcmc` exact replay
   - dynamic `exdqlm :: mcmc` exact replay
5. After the residual repair completes, summarize:
   - rows recovered to `PASS` / `WARN`
   - rows still regressing on the synced base
   - what remains before reopening the unresolved `6` dynamic tail
6. Only after that should the unresolved `6` dynamic repair tail be reopened.
