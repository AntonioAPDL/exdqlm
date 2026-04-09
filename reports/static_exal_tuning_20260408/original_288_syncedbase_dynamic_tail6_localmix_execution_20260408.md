# Original-288 Synced-Base Dynamic Tail6 Localmix Execution

Date: 2026-04-08

## Prelaunch Validation

Prepared tail queue:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_queue_20260408.csv`

Prepared deferred inventory:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_deferred_inventory_20260408.csv`

Prepared localmix schedule:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_schedule_20260408.csv`

Prepared manifest:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_manifest_20260408.csv`

Prepared stage counts:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_stage_counts_20260408.csv`

Prelaunch evaluator outputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_manifest_status_20260408.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_phase_summary_20260408.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_block_summary_20260408.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_tail6_localmix_accepted_compare_20260408.csv`

Validated prelaunch state:

- `6` accepted unresolved dynamic source rows prepared
- `18` previously completed dynamic-only weak or deferred attempts recorded in
  the local deferred inventory
- `6 / 6` localmix rows prepared
- phase split:
  - `6` `phase1_dynamic_tail6_localmix`
- `0` missing inputs
- `0 / 6` complete before launch
- `6 / 6` pending before launch
- `bash -n` passed for launch / supervisor / monitor scripts
- launcher `--prepare-only=1 --skip-prepare=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed

## Launch Intent

This execution is intended to answer one narrow question:

- can the remaining accepted unresolved dynamic tail be reduced when we switch
  from “more runtime everywhere” to row-local efficiency tuning grounded in the
  finished closure and tail6-refine evidence

It is explicitly not intended to reopen:

- replay-repair rows that were worse than accepted in dynamic closure
- static deferred rows
- generic family-wide dynamic search bands
- already screened tail6-refine geometries that stayed low-value

## Launch Sessions

- tmux supervisor:
  `original288-syncedbase-dynamic-tail6-localmix-20260408`
- tmux monitor:
  `original288-syncedbase-dynamic-tail6-localmix-monitor-20260408`

## Initial Expected State

- active phase:
  `phase1_dynamic_tail6_localmix`
- initial done count:
  `0 / 6`

## Planned Search Logic

The localmix lane is intentionally split by evidence type, even though it runs
as one compact phase:

- four rows reopen the strongest closure corridors whose intended budgets never
  actually ran before the manifest-override precedence fix
- two rows switch back to historical non-joint RW geometry on the normal
  family and add adaptation rather than more joint deepening

This keeps the run compact while still making each row answer a real
decision-grade question.

## Closeout Outcome

The localmix lane has now completed.

Outcome:

- `6 / 6` complete
- `0 PASS`
- `0 WARN`
- `6 FAIL`
- `0 / 6` healthy

Accepted comparison:

- `6` matches accepted
- `0` better than accepted
- `0` worse than accepted

Strict promotion result:

- none
- accepted `v7` remains authoritative:
  - `282 / 288` healthy
  - `230 PASS`
  - `52 WARN`
  - `6 FAIL`

## What This Wave Taught Us

The localmix wave was operationally negative, but it was still informative.

Most important interpretation:

- the manifest-override precedence bug was real and worth fixing
- but faithfully rerunning the intended closure corridors still did not rescue
  the accepted unresolved tail
- the remaining problem is therefore not just “the right schedule never truly
  ran”

Highest-value row-level reads:

- `gausmix / 0p25 / TT500`:
  - the faithfully rerun `slice 0.16 / 240` closure corridor was weaker than
    the later tail6-refine `slice 0.18 / 320` corridor
  - current result still has clean drift and Geweke, but lower ESS-per-1k than
    tail6-refine
- `laplace / 0p05 / TT500`:
  - the stronger `laplace_rw` refresh corridor improved ESS-per-1k over
    tail6-refine
  - but half-chain drift worsened materially, so the row still failed
  - this now looks like an efficiency-versus-stationarity tradeoff inside the
    `RW` family, not a simple “run longer” problem
- `normal / 0p05 / TT500`:
  - adaptive non-joint `RW` improved over the tail6-refine joint-deep attempt
    on ACF, Geweke, and drift
  - but both sigma and gamma still stayed far below the ESS-per-1k gate
- `gausmix / 0p05 / TT5000`:
  - the faithful `slice 0.16 / 240` rerun was essentially flat versus
    tail6-refine
  - no meaningful rescue signal emerged
- `laplace / 0p05 / TT5000`:
  - the reopened `slice 0.16 / 240` corridor was materially worse than the
    tail6-refine deep-slice result
  - this corridor should now be screened out
- `normal / 0p05 / TT5000`:
  - the adaptive non-joint long `RW` continuation was materially worse than the
    tail6-refine long `RW` result
  - this exact continuation should now be screened out

## Meaningful Learning

Yes, there was meaningful learning even without a rescue.

What the localmix wave clarified:

1. the closure-overrides bug is no longer a scientific explanation for the
   surviving `6`-row tail
2. the strongest long-row closure corridors (`slice 0.16 / 240`) are now
   directly screened out for `laplace / 0p05 / TT5000` and effectively
   exhausted for `gausmix / 0p05 / TT5000`
3. adaptive non-joint `RW` is not enough by itself to rescue the normal rows,
   though it helped the short normal row more than the earlier joint-deep path
4. the remaining tail is now better understood as a narrow row-local mixing
   problem, not a missing broad family-level schedule
