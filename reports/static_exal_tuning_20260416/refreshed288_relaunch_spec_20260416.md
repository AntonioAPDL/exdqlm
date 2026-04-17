# Refreshed288 Relaunch Spec

Date: `2026-04-16`

## Purpose

This document freezes the new canonical relaunch definition for the refreshed
`288`-case validation study on the synced `0.4.0` branch.

This is a new workstream. It is **not** a continuation of the frozen legacy
`original288 / v7` study.

## Core Decisions

- use the paper-aligned quantile grid `0.05`, `0.25`, `0.50`
- exclude `qdesn` inputs and use the direct non-`qdesn` source trees
- keep the full `288`-case structure
- use `LDVB` as the canonical VB engine
- use `slice` as the canonical MCMC kernel
- require explicit VB warm starts for MCMC
- use one deterministic seed per study row
- stage execution as:
  - smoke
  - full static VB
  - full dynamic VB
  - full static MCMC
  - full dynamic MCMC

## Study Axes

| axis | values |
|---|---|
| taus | `0.05`, `0.25`, `0.50` |
| families | `normal`, `laplace`, `gausmix` |
| dynamic models | `dqlm`, `exdqlm` |
| static models | `al`, `exal` |
| inference | `vb`, `mcmc` |
| dynamic fit sizes | `TT500`, `TT5000` |
| static fit sizes | `TT100`, `TT1000` |
| static shrink priors | `ridge`, `rhs_ns` |

| block | count | formula |
|---|---:|---|
| dynamic | `72` | `3 families x 3 taus x 2 sizes x 2 models x 2 inference` |
| static paper | `72` | `3 families x 3 taus x 2 sizes x 2 models x 2 inference` |
| static shrink | `144` | `3 families x 3 taus x 2 sizes x 2 priors x 2 models x 2 inference` |
| total | `288` | `72 + 72 + 144` |

## Source Data

The relaunch uses the direct CSV-backed source trees under:

- `results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW`
- `results/function_testing_20260309_static_paper_family_qspec`
- `results/function_testing_20260309_static_shrinkage_family_qspec`

Important implementation note:

- the source `validation.csv` and `validation.txt` files still point to
  relative `sim_output.rds` locations
- for this relaunch the dynamic lane intentionally uses the direct
  `series_wide.csv` plus `q_target` / `true_quantile_grid.csv` inputs instead
  of relying on a materialized `sim_output.rds`

## Canonical Method Policy

| lane | engine | policy |
|---|---|---|
| dynamic VB | `exdqlmLDVB` | canonical `LDVB` |
| static VB | `exal_static_LDVB` | canonical `LDVB` |
| dynamic MCMC | `exdqlmMCMC` | `slice` with explicit `LDVB` init |
| static MCMC | `exal_static_mcmc` | `slice` with explicit `LDVB` init |

### MCMC Initialization

The relaunch requires explicit VB initialization for MCMC.

- dynamic MCMC rows build or load a dedicated `LDVB` init fit
- static MCMC rows build or load a dedicated static `LDVB` init fit
- the init fit is passed via `vb_init_fit`
- the init artifact is stored separately under `vb_init/`

### Slice Profiles

| lane | `mh.proposal` | `slice.width` | `slice.max.steps` |
|---|---|---:|---:|
| static paper | `slice` | `0.01` | `Inf` |
| static shrink | `slice` | `0.10` | `Inf` |
| dynamic | `slice` | `0.10` | `Inf` |

## Budget Policy

| quantity | value |
|---|---:|
| MCMC burn-in | `5000` |
| MCMC kept draws | `20000` |
| MCMC thin | `1` |
| stored posterior draws | `20000` |
| dynamic VB `max_iter` | `300` |
| dynamic VB `n.samp` | `20000` |
| static VB `max_iter` | `300` |
| static VB `n_samp_xi` | `1000` |

### VB Init Budgets

| lane | init method | init budget |
|---|---|---|
| dynamic MCMC init | `LDVB` | `max_iter = 300`, `n.samp = 1000` |
| static MCMC init | `LDVB` | `max_iter = 300`, `n_samp_xi = 1000` |

## Implemented Artifacts

The relaunch stack is implemented as a new isolated tool family:

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_prepare_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_evaluate_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_refresh_comparison_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh`

Generated registries and manifests:

- `LOCAL_refreshed288_dataset_registry_20260416.csv`
- `LOCAL_refreshed288_method_registry_20260416.csv`
- `LOCAL_refreshed288_smoke_manifest_20260416.csv`
- `LOCAL_refreshed288_full_manifest_20260416.csv`

## Smoke Intent

The smoke manifest is a targeted subset that covers:

- dynamic `TT500` and `TT5000`
- static paper `TT100` and `TT1000`
- static shrink `ridge` and `rhs_ns`
- both model pairs
- both inference classes
- the new `tau = 0.50` lane

## Operational Guardrails

- no `0.95` rows in the refreshed study
- no `qdesn` inputs in the refreshed study
- no hidden legacy `ISVB` init behavior in the canonical lane
- no row-local repair knobs in the core study definition
- static VB stored posterior draws come from an explicit export adapter rather
  than pretending `n_samp_xi` is the same thing
