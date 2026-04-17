# REPORT: QDESN Dynamic Tau-0.50 Refreshed Main Implementation And Preflight

Date: 2026-04-16
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Implement the refreshed dynamic-only QDESN relaunch contract on top of the synced `0.4.0` package
core, using the corrected `tau = 0.05 / 0.25 / 0.50` materialized-source surface and a canonical
main lane.

This checkpoint covers:

- implementation of the refreshed study contract;
- materialization of the new dynamic-only `36`-root study surface;
- phase-aware wrappers for smoke and full relaunch work; and
- focused validation plus `prepare-only` preflight confirmation before the actual committed-state
  relaunch.

## 2) Implemented Contract

The refreshed main lane is now wired to use:

- dynamic datasets only;
- families:
  - `gausmix`, `laplace`, `normal`
- taus:
  - `0.05`, `0.25`, `0.50`
- fit sizes:
  - `500`, `5000`
- priors:
  - `ridge`, `rhs_ns`
- likelihood backends:
  - `al`, `exal`
- methods:
  - `vb`, `mcmc`

Canonical inference contract:

- VB:
  - `LDVB` everywhere
- MCMC:
  - `slice` everywhere
- MCMC warm start:
  - explicit `LDVB` initialization
- banned from the core lane:
  - `init_from_isvb`
  - `rw`
  - `laplace_rw`
- rescue settings:
  - retained only as explicit overlays, disabled by default in the refreshed main study

Budget contract:

- MCMC burn-in:
  - `5000`
- MCMC kept iterations:
  - `20000`
- MCMC thin:
  - `1`
- posterior metric / export draws:
  - `20000`
- LDVB main-study iterations:
  - `300`
- LDVB warm-start budget for MCMC:
  - `300` iterations
  - `1000` synthesis samples

## 3) Implementation Assets

Checked-in refreshed study assets:

- defaults:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`
- full grid:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv`
- phase subset grids:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_smoke_grid.csv`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_ridge_grid.csv`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt500_grid.csv`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt5000_grid.csv`
- grid materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R`
- phase-aware launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- phase-aware healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- touched core builders:
  - `R/qdesn_static_exdqlm_crossstudy.R`
  - `R/qdesn_dynamic_exdqlm_crossstudy.R`
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- focused contract test:
  - `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`

## 4) Key Wiring Changes

### 4.1 Generic Contract / Overlay Support

The generic cross-study builders now understand:

- `execution.methods`
- `execution.likelihood_families`
- `study_contract`
- `rescue_overlays`

This allows the refreshed study to be defined by explicit canonical rules rather than old
replay-only semantics.

### 4.2 Core-Lane Guardrails

The refreshed main lane is validated so that:

- MCMC must resolve to `slice`;
- `init_from_vb` must be `TRUE`;
- `vb_warm_start_control$method` must be `ldvb`;
- banned proposal families are rejected in the core lane.

### 4.3 Deterministic Seed Policy

The refreshed dynamic grid now uses one deterministic seed per root, with all `36` roots receiving
distinct reproducible seed assignments.

### 4.4 Phase-Aware Execution

The new wrapper layer supports:

- `smoke`
- `vb`
- `mcmc_ridge`
- `mcmc_rhsns_tt500`
- `mcmc_rhsns_tt5000`
- `full`

Subset phases now automatically identify themselves as audited grid subsets instead of requiring a
manual subset-approval flag.

## 5) Validation

Focused validation completed successfully on the refreshed implementation:

- `pkgload::load_all(...)`
- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/test-qdesn-dynamic-failure-repair.R`
- `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`
- `tests/testthat/test-pipeline-inference-validation.R`
- `tests/testthat/test-qdesn-prior-defaults.R`
- `tests/testthat/test-qdesn-validation-group-summary-robustness.R`

Materialization validation:

- canonical refreshed full grid:
  - `36` roots
  - `18` unique dataset cells
  - taus `0.05 / 0.25 / 0.50`
  - fit sizes `500 / 5000`
- audited subset grids:
  - smoke `6` roots
  - MCMC ridge `18` roots
  - MCMC `rhs_ns` `TT500` `9` roots
  - MCMC `rhs_ns` `TT5000` `9` roots

Prepare-only confirmation completed for:

- smoke subset
- full relaunch surface

## 6) Interpretation

The refreshed relaunch machinery is now implemented and validation-ready.

What this means:

- the branch now contains a canonical tau-`0.50` dynamic-only relaunch surface;
- the refreshed study contract is explicit and auditable;
- the core lane no longer depends on hidden replay drift or legacy init behavior;
- rescue knowledge is preserved as an optional explicit overlay instead of contaminating the default
  main lane.

## 7) Next Step

Launch the refreshed study from the committed-state implementation, then freeze the launch metadata
and update the branch-local trackers with the authoritative run tag and session information.
