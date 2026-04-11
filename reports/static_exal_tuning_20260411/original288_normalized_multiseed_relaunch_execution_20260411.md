# Original288 Normalized Multi-Seed Relaunch Execution (0.4.0)

Date: `2026-04-11`

## Execution Purpose

This note records the implementation, validation, and launch state for the
normalized `4`-seed relaunch of the corrected original-`288` study.

## Validation Completed Before Launch

Completed implementation checks:

- parser/syntax validation passed for:
  - `LOCAL_original288_normalized_multiseed_helpers_20260411.R`
  - `LOCAL_original288_normalized_multiseed_prepare_20260411.R`
  - `LOCAL_original288_normalized_multiseed_run_row_20260411.R`
  - `LOCAL_original288_normalized_multiseed_evaluate_20260411.R`
  - `LOCAL_original288_normalized_multiseed_reduce_20260411.R`
  - `LOCAL_original288_normalized_multiseed_refresh_comparison_20260411.R`
  - patched `LOCAL_original288_tablebacked_cluster_comparison_20260411.R`
- `bash -n` passed for:
  - `LOCAL_original288_normalized_multiseed_launch_20260411.sh`
- prepare passed:
  - pilot rows: `48`
  - full rows: `1152`
  - pilot missing inputs: `0`
  - full missing inputs: `0`
- launcher `--prepare-only=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed
- patched table-backed comparison reran successfully in legacy mode:
  - `TABLEBACKED_COMPARISON static_mcmc=34/54 static_vb=17/36 dynamic_mcmc=3/18 dynamic_vb=9/18 errors=0`

Cross-path smoke evidence:

- one real static native pilot row completed successfully:
  - `pilot_static_vb`
  - `static_paper::normal::0p25::100::paper::al::vb`
  - row result: `PASS`
  - normalized metrics CSV and draw-export RDS both written successfully

## Key Engineering Fixes During Implementation

The final implementation includes several fixes that were discovered during
validation:

- dynamic source-data resolution now falls back cleanly across worktrees
  instead of assuming the current validation worktree contains every source CSV
- static `data_ready` now uses resolved source paths rather than stale current
  worktree paths
- static defaults now read actual `beta_prior` and MCMC proposal metadata from
  validation tables where available
- the manifest now carries `original_case_key` explicitly instead of relying on
  `study_row_key` only
- the comparison refresh path now supports direct normalized metrics CSVs
  without breaking the corrected legacy `2026-04-11` comparison mode

## Current Relaunch Outputs

Prepared relaunch artifacts:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_universe_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_seedbank_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_manifest_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_manifest_20260411.csv`

Live execution/reporting artifacts:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_manifest_status_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_manifest_status_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_phase_summary_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_phase_summary_20260411.csv`

Post-run reducer / comparison artifacts to be written automatically by the
launcher:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_seed_ranking_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_selected_20260411.csv`
- `tools/merge_reports/LOCAL_original288_comparison_selection_normalized_multiseed_v1_20260411.csv`
- `reports/static_exal_tuning_20260411/original288_tablebacked_cluster_comparison_normalized_multiseed_20260411.md`

## Launch State

The staged tmux launch is now live.

Supervisor session:

- `original288-normalized-multiseed-20260411`

Monitor session:

- `original288-normalized-multiseed-monitor-20260411`

Console log:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_launcher_console_20260411.log`

Startup snapshot recorded after launch:

- prepare reran successfully
- pilot manifest rows: `48`
- full manifest rows: `1152`
- missing inputs:
  - pilot: `0`
  - full: `0`
- pilot prelaunch evaluator:
  - done: `0 / 48`
  - missing: `48 / 48`
- active first phase:
  - `pilot_static_mcmc`
- configured worker cap for the live first phase:
  - `4`

The live supervisor is responsible for:

1. pilot
2. pilot reduction
3. full phased relaunch
4. full reduction
5. normalized comparison refresh
