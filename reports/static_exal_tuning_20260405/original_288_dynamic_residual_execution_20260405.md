# Original 288 Dynamic Residual Execution

Date: 2026-04-05

This document records the implemented dynamic-only residual recovery phase for
the corrected original-`288` publication target.

## Pre-Launch State

- corrected original target: `288`
- healthy before this phase: `269`
- unresolved before this phase: `19`
- all unresolved cells are dynamic

Primary references:

- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_program_20260405.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_scoreable_candidate_inventory_v1_20260405.csv`

## Implemented Stack

- `tools/merge_reports/LOCAL_original288_dynamic_residual_helpers_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_prepare_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_evaluate_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_select_20260405.R`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_launch_20260405.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_supervisor_20260405.sh`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_monitor_20260405.sh`

## Validation Checkpoint

Completed before launch:

- shell syntax passed for launch/supervisor/monitor
- prepare regeneration passed
- evaluator passed on the pre-launch empty state
- selection preview passed on the pre-launch empty state
- staged launcher dry-run passed

Validated pre-launch manifest:

| phase | rows |
|---|---:|
| `archive_rescore_existing` | `22` |
| `vb_relaxed` | `2` |
| `mcmc_targeted` | `17` |
| `total` | `41` |

Validated pre-launch selection preview:

- promoted rows: `0`
- healthy preview: `269 / 288`
- dynamic healthy preview: `53 / 72`

## Launch Checkpoint

The overnight run was launched from the clean pushed branch tip:

- commit: `1973062`
- branch: `validation/rerun-after-0.4.0-sync`

Live tmux sessions:

- `original288-dynamic-residual-20260405`
- `original288-dynamic-residual-monitor-20260405`

Immediate post-launch state:

- active phase: `archive_rescore_existing`
- active archive parallelism: `10`
- initial evaluated snapshot: `0 / 41` done, `41 / 41` missing

Launch notes:

- no post-launch script fixes were needed before leaving the run active
- runtime-generated evaluator outputs are intentionally left out of git
  tracking so the branch can stay clean while the overnight run progresses

## Archive-Stage Closeout Checkpoint

The first residual phase completed partially rather than end to end.

What happened:

- the full `archive_rescore_existing` stage completed
- all `22` archive rows were scored successfully from on-disk candidates
- the supervisor then stopped before stage-2 because the evaluator/selector
  path hit a merged-schema bug after real row outputs existed
- that reporting bug has now been fixed in the helper/evaluator/selector stack
- no new rerun has been launched in this checkpoint

Archive-stage result:

| phase | total | done | PASS | WARN | FAIL | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `archive_rescore_existing` | `22` | `22` | `7` | `4` | `11` | `11` |

Promoted archive-stage improvements:

- `11` original dynamic baseline-`FAIL` cells now have promoted non-`FAIL`
  carry-forward replacements
- all `7` unresolved `dqlm mcmc` cells were rescued to `PASS`
- both unresolved `exdqlm vb` long-horizon low-tail cells were rescued to
  `WARN`
- `2` unresolved `exdqlm mcmc` cells were rescued to `WARN`

Promoted original-`288` state after archive-stage carry-forward:

- healthy now: `280 / 288`
- unresolved now: `8 / 288`
- dynamic healthy now: `64 / 72`
- remaining unresolved cells are all `dynamic :: exdqlm :: mcmc`

Authoritative outputs from this checkpoint:

- `tools/merge_reports/LOCAL_original288_dynamic_residual_selection_update_20260405.csv`
- `tools/merge_reports/LOCAL_original288_carryforward_selection_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_recovery_block_status_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_audit_v2_20260405.csv`

This checkpoint intentionally stops here:

- archive-stage promotions have been applied
- the corrected original-`288` health state has been regenerated
- no residual relaunch plan is introduced in this document
