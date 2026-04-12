# Original288 Exact-Spec Multi-Seed Relaunch Program (0.4.0)

Date: `2026-04-12`

## Purpose

This program implements the exact-spec replay defined in:

- `reports/static_exal_tuning_20260412/original288_exactspec_multiseed_relaunch_plan_20260412.md`

It is the corrected replacement for the invalidated normalized relaunch.

## What This Program Preserves

For every corrected original-`288` row, this program preserves:

- model family
- inference type
- prior semantics
- row-local kernel / proposal family
- joint vs non-joint settings
- adapt vs no-adapt settings
- slice width / slice max steps
- RW scale controls
- refresh cadence
- VB-init and other local initialization settings
- row-local dynamic and static tuning controls carried in the source config

## What This Program Changes

Only the following global replay controls are changed:

- `n.burn = 5000`
- `n.mcmc = 20000`
- stored posterior draws `= 20000`
- deterministic `4`-seed expansion per base row

## Seed Selection Rule

Each base row expands to `4` deterministic seeds.

Seed ranking order:

1. better gate: `PASS`, then `WARN`, then `FAIL`
2. lower `crps`
3. lower primary-accuracy metric
4. lower runtime
5. smaller seed

## Implemented Stack

Core exact-spec scripts:

- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_prepare_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_run_row_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_evaluate_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_reduce_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_refresh_comparison_20260412.R`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_launch_20260412.sh`

Core machine-readable artifacts:

- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_config_index_20260412.csv`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_resolution_audit_20260412.csv`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_control_audit_20260412.csv`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_seedbank_20260412.csv`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_smoke_manifest_20260412.csv`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_manifest_20260412.csv`

Post-run outputs:

- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_seed_ranking_20260412.csv`
- `tools/merge_reports/LOCAL_original288_exactspec_multiseed_full_selected_20260412.csv`
- `tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_v1_20260412.csv`
- `reports/static_exal_tuning_20260412/original288_tablebacked_cluster_comparison_exactspec_multiseed_20260412.md`

## Prepare Contract

The prepare step:

1. reads the corrected `rhs_ns` comparison selection
2. resolves every row to its exact historical source config
3. writes a `4`-seed replay config per replay row
4. builds both smoke and full manifests
5. emits:
   - config-resolution audit
   - control audit
   - seed bank
   - phase counts

## Launch Contract

The launcher is staged:

1. prepare manifests
2. evaluate smoke manifest
3. run smoke phases in order
4. evaluate smoke
5. reduce smoke seeds
6. run full phases in order
7. evaluate full replay
8. reduce full seeds
9. refresh the comparison selection and comparison report

The staged launcher is intentionally conservative:

- it validates completion after smoke and full
- it checks that the selected winner table has one winner per base row
- it writes a dedicated console log for postmortem inspection

## Expected Scope

Expected row counts:

- corrected selection rows: `288`
- smoke rows: `48`
- full replay rows: `1152`

Phase counts:

| phase | rows |
|---|---:|
| `full_static_mcmc` | `432` |
| `full_static_vb` | `432` |
| `full_dynamic_vb` | `144` |
| `full_dynamic_mcmc` | `144` |

Smoke phase counts:

| phase | rows |
|---|---:|
| `full_static_mcmc` | `16` |
| `full_static_vb` | `16` |
| `full_dynamic_vb` | `8` |
| `full_dynamic_mcmc` | `8` |
