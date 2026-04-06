# Original 288 Dynamic Tail-7 Geometry Execution

Date: 2026-04-06

This document records the geometry-band dynamic-only closure phase launched
after the corrected original-`288` carry-forward table reached `281 / 288`
healthy and the unresolved tail shrank to `7` dynamic `exdqlm :: mcmc` cells.

## Pre-Launch State

- corrected original target: `288`
- healthy before this phase: `281`
- unresolved before this phase: `7`
- unresolved block: dynamic only
- unresolved method family: `mcmc :: exdqlm` only

Primary references:

- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_geometry_program_20260406.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_carryforward_selection_v3_20260406.csv`

## Implemented Stack

- `tools/merge_reports/LOCAL_original288_dynamic_tail7_helpers_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_prepare_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_evaluate_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_select_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_launch_20260406.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_supervisor_20260406.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_monitor_20260406.sh`

## Validation Checkpoint

Completed before launch:

- shell syntax passed for launch/supervisor/monitor
- prepare regeneration passed
- evaluator passed on the pre-launch empty state
- selection preview passed against carry-forward `v3`
- staged launcher dry-run passed

Validated pre-launch manifest:

| phase | rows |
|---|---:|
| `anchor7_slice_band18` | `7` |
| `anchor7_slice_band24` | `7` |
| `tau05_long6_slice_band18` | `6` |
| `total` | `20` |

Validated pre-launch selection preview:

- promoted rows: `0`
- healthy preview: `281 / 288`
- dynamic healthy preview: `65 / 72`

## Launch Checkpoint

The overnight run was launched from the clean pushed branch tip:

- commit: clean pushed branch tip used at launch time
- branch: `validation/rerun-after-0.4.0-sync`

Live tmux sessions:

- `original288-dynamic-tail7-20260406`
- `original288-dynamic-tail7-monitor-20260406`

Immediate post-launch state:

- active phase: `anchor7_slice_band18`
- active anchor parallelism: `5`
- initial evaluated snapshot: `0 / 20` done, `20 / 20` missing

Launch notes:

- this phase intentionally supersedes the old tail-8 exact-geometry rerun as
  the active residual plan
- no static rows are touched
- no archive rescoring rows are included
- all rows use explicit healthy `exdqlm :: vb` warm starts from carry-forward
  `v3`
