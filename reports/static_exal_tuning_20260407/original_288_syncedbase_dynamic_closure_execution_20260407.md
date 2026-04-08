# Original-288 Synced-Base Dynamic Closure Execution

Date: 2026-04-07

## Prelaunch Validation

Prepared dynamic closure queue:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_queue_20260407.csv`

Prepared deferred inventory:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_deferred_inventory_20260407.csv`

Prepared dynamic closure schedule:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_schedule_20260407.csv`

Prepared manifest:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_20260407.csv`

Prepared stage counts:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_stage_counts_20260407.csv`

Prelaunch evaluator outputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_manifest_status_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_phase_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_block_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_accepted_compare_20260407.csv`

Validated prelaunch state:

- `9` in-scope dynamic source rows prepared
- `17` deferred rows recorded for later work
- `12 / 12` dynamic closure rows prepared
- phase split:
  - `6` primary accepted-tail repairs
  - `3` alternate accepted-tail repairs
  - `3` replay-repair rows
- `0` missing inputs
- `0 / 12` complete before launch
- `12 / 12` pending before launch
- `bash -n` passed for launch / supervisor / monitor scripts
- launcher `--prepare-only=1 --skip-prepare=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed

## Launch Intent

This execution is intended to answer:

- whether the remaining accepted unresolved dynamic tail can be reduced with a
  disciplined row-local exact-kernel closure program
- whether the `3` synced-base dynamic replay regressions can be repaired
  without reopening another broad dynamic search band

It is not intended to reopen:

- deferred static replay-fail rows
- deferred PASS-to-WARN stability-review rows

## Launch Sessions

- tmux supervisor:
  `original288-syncedbase-dynamic-closure-20260407`
- tmux monitor:
  `original288-syncedbase-dynamic-closure-monitor-20260407`

## Initial Expected State

- active phase:
  `phase1_dynamic_tail_primary`
- initial done count:
  `0 / 12`

## Final Outcome

The dynamic closure wave completed with:

- `12 / 12` rows done
- `0 PASS`
- `0 WARN`
- `12 FAIL`
- `0` promotable gains

Accepted-state effect:

- none
- accepted `v7` remains:
  - `282 / 288` healthy
  - `230 PASS`
  - `52 WARN`
  - `6 FAIL`

Accepted comparison:

- `9` matches accepted
- `0` better than accepted
- `3` worse than accepted

## Key Finding

This closeout surfaced a runner-precedence bug that materially affects how the
wave should be interpreted.

Observed issue:

- the case runner still prioritized MCMC settings from the reference fit object
  ahead of manifest overrides
- intended deeper budgets and row-local kernel overrides therefore did not
  fully propagate into the actual launched runs

Implication:

- the wave is still valid as directional evidence about which row-local
  corridors looked softer or weaker
- but it is not valid as a full negative test of the intended stronger local
  schedules

That precedence bug has now been fixed in:

- `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`

## What We Learned

- accepted-tail rows often failed less badly than the original baseline even
  though none cleared the health gate
- replay-repair rows were low-value and should be deferred
- best current row-local directions are:
  - `gausmix / 0p05 / TT5000`: slice
  - `gausmix / 0p25 / TT500`: slice
  - `laplace / 0p05 / TT500`: RW
  - `laplace / 0p05 / TT5000`: slice
  - `normal / 0p05 / TT500`: RW from historical `rhsns_full_relaunch_20260327`
  - `normal / 0p05 / TT5000`: RW from historical `rhsns_full_relaunch_20260327`
