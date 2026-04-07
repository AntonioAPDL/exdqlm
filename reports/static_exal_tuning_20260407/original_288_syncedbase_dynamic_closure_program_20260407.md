# Original-288 Synced-Base Dynamic Closure Program

Date: 2026-04-07

## Purpose

This program continues from the completed synced-base targeted follow-up
checkpoint.

The current accepted baseline is already back at the historical healthy count:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

So the next lane should focus only on the rows that can still change the final
publication-target failure count, plus the small dynamic replay-regression queue
that still blocks confidence in the synced-base dynamic behavior.

## What Improved

The finished targeted follow-up produced `3` strict improvements, all
`WARN -> PASS`:

- `static_paper::gausmix::0p25::1000::paper::exal::mcmc`
- `static_shrink::laplace::0p05::100::ridge::exal::mcmc`
- `static_shrink::laplace::0p95::1000::ridge::exal::mcmc`

Those promotions strengthen accepted `v7` without changing the healthy total.

## What Still Fails

Accepted publication-target unresolved tail:

- `6` rows
- all `dynamic :: exdqlm :: mcmc`

Additional synced-base dynamic replay regressions:

- `3` rows
- all `dynamic :: exdqlm :: mcmc`
- these were accepted-healthy rows that replayed as `FAIL`

Deferred from this program:

- `13` static replay-fail rows
- `4` PASS-to-WARN stability-review rows

## Which Ideas Worked Best

1. keep the accepted carry-forward baseline frozen and promote only strict
   same-row improvements
2. separate publication-target failures from replay-regression failures
3. reuse strongest historically non-catastrophic dynamic kernels on the same
   scenario instead of reopening broad family-wide search
4. use larger budgets only when paired with a corridor that already showed
   partial diagnostic improvement

## Which Ideas Did Not Help

1. repeating already-screened weak slice-geometry bands unchanged
2. repeating exact-long dynamic follow-ups that already failed under the same
   kernel corridor
3. reopening static follow-up while the only accepted `FAIL` rows remain
   dynamic

## Highest Expected-Value Direction

1. keep the launch dynamic-only
2. treat the accepted unresolved tail and the synced-base replay regressions as
   one small dynamic closure problem
3. use row-local corridor selection:
   - stronger `laplace_rw` refresh for the hardest full-instability rows
   - longer/wider `slice` corridors only where gamma remained the dominant
     blocker after earlier RW attempts
4. avoid rerunning any already-screened weak corridor without a clear row-level
   reason

## Program Shape

| phase | rows | intent |
|---|---:|---|
| `phase1_dynamic_tail_primary` | `6` | one strongest row-local primary repair for each accepted unresolved dynamic tail row |
| `phase2_dynamic_tail_alternate` | `3` | one alternate exact corridor for the hardest accepted-tail rows after repeated same-family failures |
| `phase3_dynamic_replay_repair` | `3` | repair the `3` synced-base dynamic replay-fail rows with the strongest alternate local corridor |
| `total` | `12` | full dynamic-only closure scope |

## Why Each Phase Is Included

### `phase1_dynamic_tail_primary`

Every accepted unresolved dynamic row gets one best-evidence primary repair:

- `gausmix / 0p05 / TT5000`: stronger `laplace_rw` refresh plus a much larger
  budget after earlier RW retries improved diagnostics but stayed unstable
- `gausmix / 0p25 / TT500`: wider/longer `slice` corridor because the archived
  slice pilot stayed gamma-limited rather than fully unstable
- `laplace / 0p05 / TT500` and `TT5000`: stronger `laplace_rw` refresh because
  both sigma and gamma were unstable under earlier exact attempts
- `normal / 0p05 / TT500` and `TT5000`: longer/wider `slice` corridor because
  RW improved sigma more than gamma and gamma remained the dominant blocker

### `phase2_dynamic_tail_alternate`

This phase is deliberately narrow and only touches the three hardest accepted
tail rows:

- `gausmix / 0p05 / TT5000`
- `laplace / 0p05 / TT500`
- `laplace / 0p05 / TT5000`

These rows already exhausted their primary historical family more than once, so
the highest-value alternate is to test the strongest opposite exact corridor
once, not to reopen a wide search band.

### `phase3_dynamic_replay_repair`

The `3` synced-base replay regressions are not publication-target `FAIL`s, but
they still matter for trust in the synced dynamic behavior. Each gets one
strong local repair:

- row `254`: pivot from failed RW exact-long to the strongest long `slice`
  corridor
- row `266`: keep `slice`, but widen stepping and extend budget
- row `276`: pivot from failed `slice` replay to stronger `laplace_rw`
  refresh

## Resource Plan

Default launch parallelism:

- primary tail phase: `6`
- alternate tail phase: `3`
- replay-repair phase: `3`

This keeps the run compact, fully interpretable, and efficient on the server
without turning the dynamic tail into another brute-force search.

## Validation Requirements Before Launch

- `prepare` writes the full `12`-row manifest
- `0` missing inputs
- evaluator sees `0 / 12` complete before launch
- `bash -n` passes for launch / supervisor / monitor
- launcher `--prepare-only=1 --skip-prepare=1` passes
- launcher `--dry-run=1 --skip-prepare=1` passes

## Primary References

- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_execution_20260407.md`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_queue_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_schedule_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_deferred_inventory_20260407.csv`
