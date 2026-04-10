# Original 288 Static Shrink RHS_NS Rebuild Program

Date: `2026-04-09`

## Purpose

This program corrects the accepted `static_shrink / rhs` branch by rebuilding the
entire branch as explicit `rhs_ns`.

The scientific rule is now:

- always use `rhs_ns`
- never use legacy `rhs`

Because the accepted `static_shrink / rhs` branch is mixed-prior historical
output, the correction scope is the full `72` rows rather than a partial patch.

## Scope

- total rows: `72`
- block: `static_shrink`
- prior semantics: `rhs_ns`
- families: `normal`, `laplace`, `gausmix`
- taus: `0.05`, `0.25`, `0.95`
- fit sizes: `100`, `1000`
- method cells:
  - `vb :: al`
  - `vb :: exal`
  - `mcmc :: al`
  - `mcmc :: exal`

## Design

This rebuild is regeneration-based, not replay-based.

Why:

- the old replay stack depended on dead reference artifacts such as legacy
  `run_config.rds`, `sim_output.rds`, and selected-fit replay state
- the static shrinkage input CSVs still exist and are sufficient to regenerate
  fits cleanly

Surviving source inputs are read from the static shrinkage family-qspec tree in
the main source repository:

- `series_wide.csv`
- `coef_truth.csv`
- `selection_indices.csv`
- `true_quantile_grid.csv`

## Tuning policy

- `rhs_ns` is forced in all rebuilt rows
- historical exAL MCMC tuning is preserved where the surviving evidence is
  explicit enough to trust
- ambiguous or legacy-only cases fall back to clean `rhs_ns` defaults rather
  than replaying uncertain prior settings
- legacy chain restarts are replaced by `init.from.vb = TRUE`

## Phase structure

- `phase1_static_shrink_rhsns_vb`: `36` rows
- `phase2_static_shrink_rhsns_mcmc`: `36` rows

Default launch concurrency:

- VB: `6`
- MCMC: `4`

## Outputs

Generated outputs live under:

- `tools/merge_reports/full288_original288_static_shrink_rhsns_rebuild_20260409`

Run products include:

- manifest
- configs
- row status CSVs
- health CSVs
- metrics CSVs
- phase and block summaries

Fit artifacts are written to validation-owned shrinkage result roots under:

- `results/function_testing_20260309_static_shrinkage_family_qspec/.../validation_shrink_rhsns_tt{fit_size}`

## Success criteria

The rebuild is successful when:

- all `72` rows complete without missing-input failures
- `rhs_ns` is explicit across all rebuilt outputs
- the corrected branch is ready to replace the legacy mixed-prior branch in the
  next metric comparison and cluster diagnosis pass
