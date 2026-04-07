# Original 288 Dynamic Tail-7 RW-Joint Execution

Date: 2026-04-06

This document records the residual dynamic closure phase launched after the
completed tail-7 geometry relaunch produced no promotable improvements and the
corrected original-`288` carry-forward table remained at `281 / 288`
healthy, and it now includes the completed post-run outcome and promotion
checkpoint.

## Pre-Launch State

- corrected original target: `288`
- healthy before this phase: `281`
- unresolved before this phase: `7`
- unresolved block: dynamic only
- unresolved method family: `mcmc :: exdqlm` only

Primary references:

- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_program_20260406.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_carryforward_selection_v3_20260406.csv`

## Implemented Stack

- `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_helpers_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_prepare_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_evaluate_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_select_20260406.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_launch_20260406.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_supervisor_20260406.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_monitor_20260406.sh`

## Validation Checkpoint

Completed before launch:

- dynamic full-runner wrapper patched to expose `joint.sample` from the
  manifest-config path
- shell syntax passed for launch/supervisor/monitor
- prepare regeneration passed
- evaluator passed on the pre-launch empty state
- selection preview passed against carry-forward `v3`
- staged launcher dry-run passed

Validated pre-launch manifest:

| phase | rows |
|---|---:|
| `anchor7_rw_joint` | `7` |
| `tt500_rw_refresh4` | `4` |
| `tt5000_rw_joint_long3` | `3` |
| `total` | `14` |

Validated pre-launch selection preview:

- promoted rows: `0`
- healthy preview: `281 / 288`
- dynamic healthy preview: `65 / 72`

## Launch Checkpoint

The overnight run was launched from the clean pushed branch tip:

- branch: `validation/rerun-after-0.4.0-sync`
- commit: `c0d1685`

Live tmux sessions:

- `original288-dynamic-tail7-rw-20260406`
- `original288-dynamic-tail7-rw-monitor-20260406`

Immediate post-launch state:

- active phase: `anchor7_rw_joint`
- active anchor parallelism: `5`
- initial evaluated snapshot: `0 / 14` done, `14 / 14` missing

Launch notes:

- this phase intentionally supersedes the failed tail-7 slice-geometry relaunch
- no static rows are touched
- no archive rescoring rows are included
- every row uses explicit healthy `exdqlm :: vb` warm starts from carry-forward
  `v3`
- every row stays within the unresolved original-`288` dynamic tail

## Post-Run Outcome

Tail-7 `rw` completed cleanly.

Wave outcome:

- `14 / 14` rows completed
- `1` row improved to `WARN`
- `13` rows remained `FAIL`
- the promoted row is:
  - `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
  - promoted from `FAIL` to `WARN`
- the `TT5000` long lane produced `0` rescues

Stage-level closeout:

| phase | total | PASS | WARN | FAIL | resolved |
|---|---:|---:|---:|---:|---:|
| `anchor7_rw_joint` | `7` | `0` | `0` | `7` | `0` |
| `tt500_rw_refresh4` | `4` | `0` | `1` | `3` | `1` |
| `tt5000_rw_joint_long3` | `3` | `0` | `0` | `3` | `0` |
| `overall` | `14` | `0` | `1` | `13` | `1` |

Applied promotion checkpoint:

- accepted carry-forward baseline now lives in:
  - `tools/merge_reports/LOCAL_original288_carryforward_selection_v4_20260406.csv`
- updated health summary now lives in:
  - `tools/merge_reports/LOCAL_original288_health_summary_v4_20260406.csv`
- updated unresolved dynamic inventory now lives in:
  - `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v4_20260406.csv`
- updated audit now lives in:
  - `tools/merge_reports/LOCAL_original288_audit_v4_20260406.csv`

Post-run corrected state:

- corrected original target: `288`
- healthy after this phase: `282 / 288`
- unresolved after this phase: `6 / 288`
- dynamic healthy after this phase: `66 / 72`

Remaining unresolved dynamic cases:

- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`
