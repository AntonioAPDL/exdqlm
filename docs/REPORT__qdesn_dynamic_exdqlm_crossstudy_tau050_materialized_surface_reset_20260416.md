# QDESN Dynamic exdqlm Cross-Study Tau-0.50 Materialized Surface Reset

Date: `2026-04-16`

## Purpose

Reset the active dynamic relaunch surface from `tau = 0.95` to `tau = 0.50` for the
materialized-source QDESN validation campaigns, using the upstream dynamic source roots now
available under:

- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/gausmix/tau_0p50`
- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/laplace/tau_0p50`
- `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW/normal/tau_0p50`

This reset applies to the active dynamic dataset surfaces only.

## Important Scope Clarification

- QDESN continues to target `dynamic` datasets only.
- QDESN continues to use the static `al` / `exal` package algorithms as the readout backend.
- The active prior axis remains:
  - `ridge`
  - `rhs_ns`
- The old base dynamic reference-inventory defaults are intentionally left on the historical
  `0.05 / 0.25 / 0.95` contract because the mirrored upstream signoff inventory still only exists
  on that older surface.
- The active relaunch surfaces that we control locally are now:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml`

## Code And Config Changes

Updated:

- `R/qdesn_dynamic_exdqlm_crossstudy.R`
  - removed the stale validator ban on `tau = 0.50`
  - added a fallback dynamic-source loader that reconstructs the minimal `sim_output` object from
    `series_wide.csv` plus `true_quantile_grid.csv` when root-level `sim_output.rds` is absent
  - added reference-summary aliases used by the dynamic run wrapper
  - made the legacy reference-comparison writer degrade cleanly when the active surface is
    materialized-source-only and does not have a mirrored signoff inventory
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
  - preflight now distinguishes:
    - `reference_inventory`
    - `materialized_source_inputs`
  - materialized-source relaunches now audit the staged-source contract instead of forcing the old
    mirrored signoff inventory
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml`
  - `taus: [0.05, 0.25, 0.50]`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_defaults.yaml`
  - `taus: [0.05, 0.25, 0.50]`

Focused test coverage added:

- `tests/testthat/test-qdesn-dynamic-failure-repair.R`
  - new unit test for the CSV-based dynamic-source sim fallback

## Staged Source Reset

Cleaned the active staged-source caches by removing the stale local `tau_0p95` directories from:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_sources`
- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_sources`

Re-materialized the active staged-source roots so they now contain only:

- `tau_0p05`
- `tau_0p25`
- `tau_0p50`

for each of:

- `gausmix`
- `laplace`
- `normal`

## Active Dynamic Surface After Reset

The active relaunch surface is now:

- scenario:
  - `dlm_constV_smallW`
- families:
  - `gausmix`, `laplace`, `normal`
- taus:
  - `0.05`, `0.25`, `0.50`
- fit sizes:
  - `500`, `5000`
- priors:
  - `ridge`, `rhs_ns`

Counts:

- unique dataset cells: `18`
- QDESN roots: `36`
- per-root fit families:
  - `vb + al`
  - `vb + exal`
  - `mcmc + al`
  - `mcmc + exal`

## Regenerated Active Grids

Regenerated:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv`

Both grids now validate to:

- rows: `36`
- unique dataset cells: `18`
- taus:
  - `0.05`, `0.25`, `0.50`

## Validation Performed

Unit test:

- `tests/testthat/test-qdesn-dynamic-failure-repair.R`

Full prepare-only preflights from committed code state:

- postdraw:
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-postdraw-tau050-preflight-20260416`
  - launch root:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation/qdesn-dynamic-exdqlm-crossstudy-postdraw-tau050-preflight-20260416/launch`
- deep-DESN:
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-deepdesn-tau050-preflight-20260416`
  - launch root:
    - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-tau050-preflight-20260416/launch`

Both preflights completed successfully.

## Current Interpretation

The branch is now in the correct state for the next dynamic-only relaunch:

- active staged sources now reflect the intended `0.50` quantile surface
- the active postdraw and deep-DESN relaunch wrappers are launch-valid on that new surface
- the older mirrored `0.95` reference inventory is preserved as historical evidence, but it is no
  longer allowed to block the new materialized-source relaunch contract
