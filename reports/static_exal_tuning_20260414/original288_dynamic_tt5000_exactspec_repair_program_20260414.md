# Original288 Dynamic TT5000 Exact-Spec Repair Program (0.4.0)

Date: `2026-04-14`

## Purpose

This program implements the narrow dynamic `TT5000` repair relaunch defined in:

- `reports/static_exal_tuning_20260414/original288_dynamic_tt5000_exactspec_repair_plan_20260414.md`

It is the intended follow-up to the completed exact-spec replay when the
replay-based comparison still has a `36`-row dynamic `TT5000` failure hole.

## Scope

Targeted repair slice:

- block: `dynamic`
- fit size: `5000`
- families: `gausmix`, `laplace`, `normal`
- taus: `0p05`, `0p25`, `0p95`
- models: `dqlm`, `exdqlm`
- inference methods: `vb`, `mcmc`

## Implemented Stack

Core scripts:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_helpers_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_prepare_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_build_phase2_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_run_row_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_evaluate_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_reduce_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_refresh_comparison_20260414.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_launch_20260414.sh`

Core artifacts:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_source_audit_20260414.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_candidate_inventory_20260414.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase1_manifest_20260414.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_phase2_manifest_20260414.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_manifest_20260414.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_seed_ranking_20260414.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_full_selected_20260414.csv`
- `tools/merge_reports/LOCAL_original288_comparison_selection_exactspec_multiseed_dynamic_tt5000_repair_v1_20260414.csv`
- `reports/static_exal_tuning_20260414/original288_tablebacked_cluster_comparison_exactspec_dynamic_tt5000_repair_20260414.md`

## Provenance Design

### Phase 1

Phase 1 resolves each target row back to an exact source config using:

- the current exact-spec replay selection
- the corrected accepted comparison baseline
- the faithful replay registry in the synced validation branch

### Phase 2

Phase 2 does not invent new generic tuning.

It reconstructs row-local historical repair candidates from prior dynamic
artifacts, including:

- checkpoint files
- matrix manifests
- targeted manifests

Recovered control families include:

- `slice`
- `rw`
- `laplace_rw`
- Laplace refresh schedules
- historical VB-init flags
- historical source seeds

## Standardized Replay Controls

For both phases:

- `n.burn = 5000`
- `n.mcmc = 20000`
- stored posterior draws `= 20000`
- deterministic `4`-seed expansion

## Phase Counts

Current prepared counts:

| artifact | count |
|---|---:|
| target rows | `36` |
| phase-1 rows | `144` |
| phase-2 historical candidates | `13` |
| phase-1 missing inputs | `0` |

Current historical-source mix inside phase 2:

| source kind | candidates |
|---|---:|
| `checkpoint` | `10` |
| `matrix_manifest` | `2` |
| `targeted_manifest` | `1` |

## Launch Design

The launcher is staged and conservative:

1. prepare manifests
2. evaluate phase 1
3. run phase 1 with capped parallelism
4. reduce phase-1 winners
5. build phase 2 only for remaining failures
6. run phase 2 with lower parallelism
7. reduce combined winners
8. refresh repaired comparison outputs

Current worker caps:

- phase 1: `3`
- phase 2: `2`

That is intentionally cautious because the unresolved block is long-horizon
dynamic compute and the branch already has the necessary static comparison read.
