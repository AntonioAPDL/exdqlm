# Original288 Normalized Multi-Seed Relaunch Program (0.4.0)

Date: `2026-04-11`

## Purpose

This program implements the normalized relaunch defined in:

- `reports/static_exal_tuning_20260411/original288_normalized_multiseed_relaunch_plan_20260411.md`

The relaunch normalizes the current corrected `0.4.0` validation state so
that:

1. every rerun `mcmc` row uses `n.burn = 5000`
2. every rerun `mcmc` row uses `n.mcmc = 20000`
3. every rerun row uses `4` deterministic seeds
4. dynamic `vb` uses `n.samp = 20000`
5. static and dynamic seed winners are chosen with the same deterministic
   rule

## Seed Selection Rule

Each original study row expands to `4` seed rows.

Winner ranking:

1. better gate: `PASS` over `WARN` over `FAIL`
2. lower `crps`
3. lower primary-accuracy metric
4. lower runtime
5. smaller seed value

## Current Input Universe

The relaunch uses the corrected current-state comparison-selection source:

- `tools/merge_reports/LOCAL_original288_comparison_selection_rhsns_v1_20260411.csv`

Expected scope:

- `288` study rows
- `1152` seed-level full rows
- `48` seed-level pilot rows

## Implemented Outputs

Core machine-readable artifacts:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_universe_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_control_audit_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_seedbank_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_manifest_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_manifest_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_pilot_stage_counts_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_stage_counts_20260411.csv`

Core execution stack:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_prepare_20260411.R`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_run_row_20260411.R`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_evaluate_20260411.R`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_reduce_20260411.R`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_refresh_comparison_20260411.R`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_launch_20260411.sh`

Post-run selected-seed outputs:

- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_seed_ranking_20260411.csv`
- `tools/merge_reports/LOCAL_original288_normalized_multiseed_full_selected_20260411.csv`
- `tools/merge_reports/LOCAL_original288_comparison_selection_normalized_multiseed_v1_20260411.csv`
- `reports/static_exal_tuning_20260411/original288_tablebacked_cluster_comparison_normalized_multiseed_20260411.md`

## Phase Order

Pilot:

1. `pilot_static_mcmc`
2. `pilot_static_vb`
3. `pilot_dynamic_vb`
4. `pilot_dynamic_mcmc`

Full relaunch:

1. `full_static_mcmc`
2. `full_static_vb`
3. `full_dynamic_vb`
4. `full_dynamic_mcmc`

## Worker Caps

The launcher uses the current conservative caps from the plan:

| phase family | cap |
|---|---:|
| static `mcmc` | `4` |
| static `vb` | `8` |
| dynamic `vb` | `6` |
| dynamic `mcmc` | `3` |

## Important Implementation Notes

- static reruns use a native runner path so that static `vb` can export
  deterministic posterior-draw contracts and `crps`
- dynamic reruns reuse the proven generic row runner, then add normalized
  metrics and seed-reduction artifacts on top
- the refreshed comparison script now accepts explicit selection/output/report
  args and can read direct normalized metrics CSVs, while still preserving the
  legacy corrected `2026-04-11` comparison mode

## Launch Contract

The staged launcher:

1. prepares the manifests
2. runs the pilot phases
3. evaluates the pilot manifest
4. reduces pilot seeds
5. runs the full phased relaunch
6. evaluates and reduces the full relaunch
7. refreshes the normalized selected-seed comparison automatically
