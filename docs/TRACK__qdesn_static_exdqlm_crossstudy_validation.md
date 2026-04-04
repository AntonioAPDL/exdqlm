# TRACK: QDESN Static exdqlm Cross-Study Validation

Date: 2026-04-04  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Mission

Build the QDESN counterpart to the exdqlm static validation study on the same recovered static
dataset surface, using:

- likelihoods: `exal`, `al`
- methods: `vb`, `mcmc`
- priors: `ridge`, `rhs_ns`

This tracker is for the cross-study program only. It is not the dynamic DLM certification tracker.

## 2) Current Status

Status: **prepare-only passed and one-root smoke passed; full launch ready**

Scope decision:

- launch surface: `static only`
- dynamic row-15 sidecar: `excluded from initial launch`
- `gausmix @ tau=0.50`: `excluded`

Recovered reference contract:

- final static signoff roots: `54`
  - `18` paper
  - `36` shrink
- unique dataset cells: `36`
- QDESN analog grid: `72` roots

Validation checkpoints completed:

- canonical grid materialization: `PASS`
- prepare-only preflight: `PASS`
- one-root live smoke on
  `root__static_paper__gausmix__tau_0p05__tt_100__qdesn_ridge`: `PASS`
  - smoke recommendation:
    `COMPARISON_READY_WITH_DOCUMENTED_FAIL_BAND`

## 3) Read First

1. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
2. `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
3. `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
4. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
5. `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
6. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`
7. `scripts/materialize_qdesn_static_exdqlm_crossstudy_grid.R`
8. `R/qdesn_static_exdqlm_crossstudy.R`

## 4) Hard Rules

1. Recover the dataset surface from disk; do not approximate it.
2. Preserve current-vs-legacy provenance in metadata and reporting.
3. Do not reopen the finished dynamic DLM tuning program here.
4. Keep the first launch static-only.
5. Treat comparison tables as required outputs.
6. Use prepare-only before real launch.
7. Keep compute conservative and single-threaded per fit.

## 5) Core Assets

Implementation assets:

- defaults:
  - `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
- grid:
  - `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
- helper layer:
  - `R/qdesn_static_exdqlm_crossstudy.R`
- grid materializer:
  - `scripts/materialize_qdesn_static_exdqlm_crossstudy_grid.R`
- launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`

## 6) Open Questions

Remaining questions are operational, not conceptual:

- does the external-static real-mode path pass prepare-only cleanly?
- does the first smoke root complete without structural mismatch?
- what final recommendation does the full QDESN cross-study emit?
