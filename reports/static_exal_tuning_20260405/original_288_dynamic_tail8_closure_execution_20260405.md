# Original 288 Dynamic Tail-8 Closure Execution

Date: 2026-04-05

This document records the reduced dynamic-only tail program launched after the
post-archive corrected original-`288` baseline reached `280 / 288` healthy.

## Pre-Launch State

- corrected original target: `288`
- healthy before this phase: `280`
- unresolved before this phase: `8`
- unresolved block: dynamic only
- unresolved method family: `mcmc :: exdqlm` only

Primary references:

- `reports/static_exal_tuning_20260405/original_288_dynamic_tail8_closure_program_20260405.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_carryforward_selection_v2_20260405.csv`

## Implemented Stack

- `tools/merge_reports/LOCAL_original288_dynamic_tail8_helpers_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail8_prepare_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail8_evaluate_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail8_select_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail8_launch_20260405.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_tail8_supervisor_20260405.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_tail8_monitor_20260405.sh`

## Validation Checkpoint

Completed before launch:

- shell syntax passed for launch/supervisor/monitor
- prepare regeneration passed
- evaluator passed on the pre-launch empty state
- selection preview passed against carry-forward `v2`
- staged launcher dry-run passed

Validated pre-launch manifest:

| phase | rows |
|---|---:|
| `anchor8_slice_sync` | `8` |
| `tau05_long6_slice_sync` | `6` |
| `total` | `14` |

Validated pre-launch selection preview:

- promoted rows: `0`
- healthy preview: `280 / 288`
- dynamic healthy preview: `64 / 72`

## Launch Checkpoint

The overnight run was launched from the clean pushed branch tip:

- commit: clean pushed branch tip used at launch time
- branch: `validation/rerun-after-0.4.0-sync`

Live tmux sessions:

- `original288-dynamic-tail8-20260405`
- `original288-dynamic-tail8-monitor-20260405`

Immediate post-launch state:

- active phase: `anchor8_slice_sync`
- active anchor parallelism: `6`
- initial evaluated snapshot: `0 / 14` done, `14 / 14` missing

Launch notes:

- this phase intentionally supersedes the broader mixed residual relaunch idea
- no archive rescoring rows are included
- all rows use explicit healthy `exdqlm vb` warm starts from carry-forward `v2`

## Closeout Result

Tail-8 is now complete and has been applied back into the corrected
original-`288` carry-forward table.

Outcome:

- total rows: `14`
- `PASS`: `1`
- `WARN`: `0`
- `FAIL`: `13`
- promoted rescues: `1`

Promoted rescue:

- `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
- promoted candidate:
  - `orig288_dyn_tail8_slice_sync_20260405`
- new gate:
  - `PASS`

Post-closeout corrected state:

- healthy: `281 / 288`
- unresolved: `7 / 288`
- unresolved block: dynamic only

Main takeaways:

- the exact `0.12 / 80` slice corridor still works on at least one upper-tail
  residual case
- the longer low-tail rerun at the same exact geometry did not rescue the
  surviving `tau = 0p05` cluster
- the next credible search axis is slice geometry, not more time at the same
  geometry
