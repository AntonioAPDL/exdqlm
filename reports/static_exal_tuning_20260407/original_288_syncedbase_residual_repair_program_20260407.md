# Original-288 Synced-Base Residual Repair Program

Date: 2026-04-07

## Purpose

This program is the next phase after the completed synced-base faithful replay
of the accepted healthy `282` rows.

The faithful replay did two important things:

1. it validated that the synced `0.4.0` base can still reproduce the `VB`
   side cleanly and much of the dynamic MCMC side reasonably
2. it isolated the remaining replay regressions into a tight residual queue of
   `84` rows that should be repaired before the unresolved accepted tail of
   `6` dynamic rows is reopened

This program therefore focuses only on the remaining replay regressions and
does **not** reopen already healthy regions.

## Accepted Baseline

Accepted publication-target baseline is now `v5`:

- source:
  `tools/merge_reports/LOCAL_original288_carryforward_selection_v5_20260407.csv`
- accepted healthy:
  `282 / 288`
- accepted unresolved:
  `6 / 288`
- accepted gate split:
  - `226 PASS`
  - `56 WARN`
  - `6 FAIL`

## What Improved

Strict improvements promoted from faithful replay:

- `31` rows were better than accepted and have now been promoted into `v5`
- all promoted improvements were strict non-failing upgrades on already
  accepted-healthy rows
- no new row was promoted from the unresolved `6` tail in this checkpoint

## What Still Fails

Residual replay-repair queue:

- `84` rows total
- all are `mcmc`
- split:
  - `54` static `al :: mcmc`
  - `27` static `exal :: mcmc`
  - `3` dynamic `exdqlm :: mcmc`

Residual interpretation:

- `54` static `al :: mcmc` rows are invalid runtime failures caused by the
  shared proposal-resolution bug and should be rerun after the replay bug fix
- `27` static `exal :: mcmc` rows are completed-but-unhealthy reruns that need
  exact replay first and local tuning only if exact replay still fails
- `3` dynamic `exdqlm :: mcmc` rows are completed-but-unhealthy reruns that
  should be replayed exactly before reopening the unresolved `6` dynamic tail

## What Worked Best

- forcing original `static_shrink::rhs` rows to use `rhs_ns`
- replaying from accepted-reference fit paths
- keeping the unresolved `6` dynamic tail separate from the fidelity question
- promoting only strict same-row improvements
- tightening the replay analysis down to specific residual lanes instead of a
  broad generic search

## What Did Not Help

- the deprecated broad synced-base rerun from `2026-04-06`
- treating baseline-kept MCMC rows like fresh runs
- relying on implicit proposal defaults during replay
- broad generic relaunches before first isolating the replay failure structure

## Highest Expected-Value Directions

1. fix and rerun the `54` static `al :: mcmc` runtime-invalid rows
2. replay the `27` static `exal :: mcmc` fails exactly from accepted evidence
3. replay the `3` dynamic `exdqlm :: mcmc` fails exactly from accepted
   evidence
4. only after exact replay closes should any smaller local-tuning search be
   opened, beginning with the residual static `exal :: mcmc` rows if needed

## Residual Lanes

| phase | rows | intent |
|---|---:|---|
| `phase1_static_al_mcmc_bugfix` | `54` | rerun all static `al :: mcmc` rows after fixing the shared proposal-resolution replay bug |
| `phase2_static_exal_mcmc_exact` | `27` | rerun the completed-but-unhealthy static `exal :: mcmc` rows under corrected exact replay |
| `phase3_dynamic_exdqlm_mcmc_exact` | `3` | rerun the completed-but-unhealthy dynamic `exdqlm :: mcmc` rows under corrected exact replay |
| `total` | `84` | complete residual replay-repair scope |

Accepted-gate composition of the residual queue:

- `phase1_static_al_mcmc_bugfix`:
  - `54` originally accepted `PASS`
- `phase2_static_exal_mcmc_exact`:
  - `6` originally accepted `PASS`
  - `21` originally accepted `WARN`
- `phase3_dynamic_exdqlm_mcmc_exact`:
  - `3` originally accepted `WARN`

Prior structure of the static residual queue:

- static `al :: mcmc` bugfix lane:
  - `36` ridge
  - `18` rhs replayed as `rhs_ns`
- static `exal :: mcmc` exact lane:
  - `19` ridge
  - `8` rhs replayed as `rhs_ns`

## Replay Rules

1. keep accepted `v5` as the publication-target baseline during this run
2. replay only rows that failed in the faithful replay
3. keep the unresolved accepted `6` dynamic rows out of this run
4. use accepted-reference fit paths for replay
5. keep `rhs_ns` as the effective replay prior for all original
   `static_shrink::rhs` rows
6. use the corrected runner / helper precedence that treats `NA` accepted MCMC
   fields as missing rather than valid overrides
7. do not broaden the search space during this program

## Resource Plan

The program is organized to match failure type and compute value:

- static `al` bugfix lane first:
  high count, cheap to interpret, likely large payoff if the bug is resolved
- static `exal` exact lane second:
  moderate count, scientifically important, candidate local-tuning frontier if
  exact replay remains weak
- dynamic `exdqlm` exact lane last:
  tiny count, keep it separate from the unresolved dynamic tail

Default launch parallelism:

- static `al` max parallel:
  `12`
- static `exal` max parallel:
  `10`
- dynamic max parallel:
  `4`

These defaults are chosen to keep the server busy without mixing too many
different failure modes at once.

## Validation Requirements Before Launch

- prepare writes all `84` residual rows
- `0` missing inputs
- evaluator can summarize the empty prelaunch state
- shell syntax passes for launch / supervisor / monitor scripts
- launcher dry-run passes phase-by-phase

## Primary References

- `reports/static_exal_tuning_20260407/original_288_syncedbase_faithful_replay_execution_20260407.md`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_fail_inventory_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_20260407.csv`
