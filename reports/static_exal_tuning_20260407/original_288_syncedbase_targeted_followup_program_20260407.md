# Original-288 Synced-Base Targeted Follow-Up Program

Date: 2026-04-07

## Purpose

This program continues from the completed synced-base residual repair checkpoint.

The broad fidelity replay and the first residual repair pass have already told
us what matters most:

1. the accepted publication-target baseline is still `282 / 288` healthy and
   is now frozen as `v6`
2. the invalid static `al :: mcmc` replay collapse was a real bug and is now
   cleared
3. the remaining synced-base replay debt is narrow enough that the next wave
   should be a targeted local follow-up, not another broad replay

## Accepted Baseline

Accepted publication-target baseline is now `v6`:

- source:
  `tools/merge_reports/LOCAL_original288_carryforward_selection_v6_20260407.csv`
- accepted healthy:
  `282 / 288`
- accepted unresolved:
  `6 / 288`
- accepted gate split:
  - `227 PASS`
  - `55 WARN`
  - `6 FAIL`

## What Improved

Strict improvements now captured in `v6`:

- the faithful replay had already contributed `31` strict improvements over
  `v4`
- the completed residual repair added `1` more strict improvement over `v5`
- net accepted carry-forward remains `282 / 288` healthy, but with a stronger
  pass/warn composition than earlier checkpoints

## What Still Fails

Current synced-base follow-up queue in scope:

- `19` fail rows:
  - `16` static `exal :: mcmc`
  - `3` dynamic `exdqlm :: mcmc`
- `4` accepted-`PASS` rows that now reproduce only as `WARN`

Explicitly deferred for this wave:

- the accepted unresolved dynamic tail of `6`

That deferred tail remains the final publication-target failure queue, but it
is deliberately excluded from this program because the current highest-value
task is to finish closing the synced-base replay regressions first.

## Which Ideas Worked Best

1. keep the accepted carry-forward baseline frozen and promote only strict
   same-row improvements
2. keep `rhs_ns` as the effective replay prior for original
   `static_shrink::rhs`
3. separate invalid runtime failures from real mixing-quality failures
4. reuse already-proven same-scenario local profiles instead of reopening broad
   search bands
5. keep dynamic follow-ups inside the accepted kernel family before widening
   geometry again

## Which Ideas Did Not Help

1. broad faithful replay as a residual search program
2. reopening already-screened weak global static tuning families
3. reopening the unresolved dynamic tail before the synced-base replay
   regression map was cleaned up
4. repeating exact replay unchanged after it already failed on the same row

## Highest Expected-Value Directions

1. static `exal :: mcmc` fail rows:
   use explicit same-scenario local profiles already known on disk
2. dynamic `exdqlm :: mcmc` fail rows:
   keep the accepted kernel family, but extend runtime budgets only
3. PASS-to-WARN rows:
   verify stability with longer budgets before opening new families
4. accepted unresolved dynamic tail of `6`:
   keep deferred until the synced-base regression queue is smaller

## Explicit Exclusions

This program intentionally excludes:

- all static `al :: mcmc` rows
- all already healthy `VB` regions
- another broad synced-base replay
- another broad dynamic slice-geometry search
- the accepted unresolved dynamic tail of `6`

## Program Shape

| phase | rows | intent |
|---|---:|---|
| `phase1_static_exal_primary` | `16` | one best-evidence same-scenario local profile for each static `exal :: mcmc` fail row |
| `phase2_static_exal_rowlocal` | `6` | extra row-local alternates only for the hardest or highest-value static fail cases |
| `phase3_dynamic_exdqlm_exactlong` | `3` | same-kernel longer-budget reruns for the `3` dynamic replay fails |
| `phase4_stability_review` | `4` | longer-budget confirmations for the `PASS -> WARN` rows |
| `total` | `29` | full targeted follow-up scope |

## Why Each Phase Is Included

### `phase1_static_exal_primary`

This is the core recovery lane. Every static `exal :: mcmc` fail row gets one
targeted same-scenario candidate chosen from historically proven on-disk
profiles:

- row-`152` uses the documented row-`87` low-mid best historical anchor
- row-`176` uses the row-`135` row-local histshort corridor
- compact-paper and compact-shrink rows with weak baseline replay pivot to the
  strongest reusable `rhsns_current` / `rhsns_impl` family in the same
  scenario
- larger ridge rows with many weak generic baselines pivot to the documented
  `failband2_F085_sub2_s100` default rather than reopening a broad family grid

### `phase2_static_exal_rowlocal`

This phase is deliberately small. It is reserved for rows where phase-1's
single best guess is not enough:

- two additional row-`152` lower-mid anchors that were already non-`FAIL`
  historically
- one alternate broad default for row-`176`
- two old tier-B/C same-scenario repair candidates for the hardest gausmix
  ridge rows
- one broad failband fallback for the legacy rhs row

### `phase3_dynamic_exdqlm_exactlong`

This is the dynamic replay-regression lane:

- row `254` keeps the accepted `laplace_rw` refresh corridor and only extends
  runtime
- rows `266` and `276` keep the accepted `slice` corridor and only extend
  runtime

No new dynamic geometry family is opened here.

### `phase4_stability_review`

These are not failures, but they are still worth cleaning up:

- `4` rows reproduced as `WARN` after being accepted `PASS`
- all `4` keep their accepted profile and only get a longer-budget confirmation

## Resource Plan

Default launch parallelism:

- static primary:
  `10`
- static row-local:
  `6`
- dynamic exact-long:
  `4`
- stability review:
  `4`

This keeps the run compact and interpretable while still using the server
efficiently.

## Validation Requirements Before Launch

- `prepare` writes the full `29`-row follow-up manifest
- `0` missing inputs
- evaluator sees `0 / 29` complete before launch
- shell syntax passes for launch / supervisor / monitor
- launcher `--prepare-only=1` passes
- launcher `--dry-run=1 --skip-prepare=1` passes

## Primary References

- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`
- `tools/merge_reports/LOCAL_original288_syncedbase_followup_queue_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_followup_schedule_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_followup_deferred_dynamic_tail_20260407.csv`
