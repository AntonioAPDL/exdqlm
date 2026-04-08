# Original-288 Synced-Base Dynamic Tail6 Refine Program

Date: 2026-04-07

## Purpose

This program continues from the completed synced-base dynamic closure wave.

Accepted publication-target state is unchanged:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

All `6` remaining publication-target failures are still:

- `dynamic`
- `exdqlm :: mcmc`

## Dynamic Closure Closeout

The completed synced-base dynamic closure wave finished:

- `12 / 12` complete
- `0 PASS`
- `0 WARN`
- `12 FAIL`
- `9` matches accepted
- `0` better than accepted
- `3` worse than accepted

Strict promotion result:

- none
- accepted `v7` remains authoritative

## Important Implementation Finding

The closure wave revealed a real launch-stack issue:

- the case runner was still prioritizing MCMC settings from the reference fit
  object ahead of manifest overrides
- that meant deeper local budgets and kernel overrides in the closure manifest
  were not actually being honored at runtime

This matters because the closure wave still produced useful directional
evidence, but it should not be treated as a clean negative test of the intended
stronger local schedules.

That runner precedence bug has now been fixed in:

- `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`

Operational rule going forward:

- accepted replay defaults still come from the selected reference fit
- but explicit manifest overrides now win when a row-local continuation is
  intentionally requested

## What Improved

- no new publication-target promotions were available from dynamic closure
- the wave still sharpened the row-local picture:
  - `laplace / 0p05 / TT500`: primary `laplace_rw` remained the best near-miss
  - `gausmix / 0p25 / TT500`: slice remained the cleanest ESS-limited corridor
  - `gausmix / 0p05 / TT5000`: slice looked better than RW on the synced base
  - `laplace / 0p05 / TT5000`: slice looked less bad than RW
- the replay-repair sublane was screened down as low-value for the next step

## What Still Fails

Accepted unresolved publication-target tail:

- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Persistent pattern:

- gamma remains the universal failing gate
- sigma is secondary for some rows, but not the dominant blocker everywhere
- kernel choice is row-specific rather than family-generic

## Which Ideas Worked Best

1. keeping the accepted carry-forward frozen and only promoting strict same-row
   improvements
2. separating accepted publication-target failures from replay-confidence debt
3. using row-local kernel choice instead of another generic dynamic sweep
4. keeping RW on rows where sigma already approached stability
5. keeping slice on rows where the newer synced-base evidence softened drift
   without fully rescuing gamma

## Which Ideas Did Not Help

1. broad replay-repair rows mixed into the accepted-failure lane
2. treating dynamic closure as evidence against stronger budgets when the
   override-precedence bug meant those budgets were not actually applied
3. rerunning already weaker opposite-kernel alternates without a row-specific
   reason

## Highest Expected-Value Direction

1. keep the next run accepted-tail only
2. rerun only the `6` publication-target failures
3. use the best current per-row corridor rather than reopening replay rows
4. run the intended deeper budgets now that overrides are respected

## Program Shape

| phase | rows | intent |
|---|---:|---|
| `phase1_dynamic_tail6_refine` | `6` | one best-evidence row-local continuation for each accepted unresolved dynamic row |
| `total` | `6` | compact accepted-tail-only refine lane |

## Candidate Schedule

| case | reference | planned corridor | why it is included |
|---|---|---|---|
| `gausmix / 0p05 / TT5000` | current synced-base slice alternate | `slice`, `0.18 / 320`, `10000 + 32000` | best soft failure on this row; keep slice and pay a real long budget |
| `gausmix / 0p25 / TT500` | current synced-base slice primary | `slice`, `0.18 / 320`, `4000 + 16000` | drift cleaned up; remaining blocker looks like ESS rather than total instability |
| `laplace / 0p05 / TT500` | current synced-base RW primary | `laplace_rw`, joint, refresh `8 / 25 / 0.92`, `4000 + 16000` | best near-miss in the tail; now test the intended stronger RW corridor for real |
| `laplace / 0p05 / TT5000` | current synced-base slice alternate | `slice`, `0.18 / 320`, `10000 + 32000` | slice looked less bad than RW on the synced base |
| `normal / 0p05 / TT500` | historical `rhsns_full_relaunch_20260327` RW fit | `laplace_rw`, joint, refresh `8 / 25 / 0.92`, `4000 + 16000` | historical RW already made sigma pass; deepen the same family for gamma |
| `normal / 0p05 / TT5000` | historical `rhsns_full_relaunch_20260327` RW fit | `laplace_rw`, joint, refresh `8 / 25 / 0.92`, `8000 + 24000` | historical RW was stronger than the recent slice rerun; keep RW and pay a true long budget |

## Resource Plan

Default launch parallelism:

- `6` workers for the single refine phase

This is intentionally narrow:

- no replay-repair rows
- no static reopening
- no redundant alternate sweep inside the same launch

## Validation Requirements Before Launch

- `prepare` writes a `6`-row manifest
- `0` missing inputs
- evaluator sees `0 / 6` complete before launch
- `bash -n` passes for launch / supervisor / monitor
- launcher `--prepare-only=1 --skip-prepare=1` passes
- launcher `--dry-run=1 --skip-prepare=1` passes

## Primary References

- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_execution_20260407.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v7_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_schedule_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_refine_deferred_inventory_20260407.csv`
