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

Status: **Wave 1 broad launch is source-complete enough to define debt; Wave 2 debt-only rerun is the active follow-up**

Current scope decision:

- launch surface: `static only`
- dynamic row-15 sidecar: `excluded`
- `gausmix @ tau=0.50`: `excluded`
- current move-forward mode: `scientific debt only`

Wave-1 source baseline:

- run tag:
  - `qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- root materialization:
  - `72/72`
- root status:
  - `66 SUCCESS`
  - `6 FAIL`
- authoritative source:
  - root-level outputs, not campaign-level closeout

Recovered reference contract:

- final static signoff roots: `54`
  - `18` paper
  - `36` shrink
- unique dataset cells: `36`
- QDESN analog grid: `72` roots

Main Wave-1 scientific takeaways:

- the shared static QDESN setup is broadly viable;
- the hard root FAIL band is narrow:
  - `static_shrink x laplace x tt=1000 x tau in {0.05, 0.25, 0.95} x prior in {ridge, rhs_ns}`
- `ridge` is the current broad cross-study baseline family;
- `rhs_ns` remains a debt family because most successful roots are still not comparison-eligible;
- the next step should therefore be a debt-only wave, not another `72`-root relaunch.

Validation checkpoints completed:

- canonical grid materialization: `PASS`
- prepare-only preflight: `PASS`
- one-root live smoke: `PASS`
- Wave-1 broad shared-setup launch: `SOURCE_BASELINE_ESTABLISHED`
- Wave-2 debt-wave plan + runner implementation: `READY`

## 3) Read First

1. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
2. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave1_broad_launch_20260404.md`
3. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave2_debt_resolution_20260404.md`
4. `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
5. `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
6. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
7. `config/validation/qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml`
8. `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
9. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`
10. `scripts/run_qdesn_static_exdqlm_crossstudy_debt_wave.R`
11. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_debt_wave.R`
12. `scripts/materialize_qdesn_static_exdqlm_crossstudy_grid.R`
13. `R/qdesn_static_exdqlm_crossstudy.R`
14. `R/qdesn_static_exdqlm_crossstudy_debt_wave.R`

## 4) Hard Rules

1. Recover the dataset surface from disk; do not approximate it.
2. Preserve current-vs-legacy provenance in metadata and reporting.
3. Do not reopen the finished dynamic DLM tuning program here.
4. Keep the first launch static-only.
5. Treat comparison tables as required outputs.
6. Use prepare-only before real launch.
7. Keep compute conservative and single-threaded per fit.
8. Do not relaunch the whole `72`-root surface while the debt set remains narrow.

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
- debt-wave manifest:
  - `config/validation/qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml`
- debt-wave helper:
  - `R/qdesn_static_exdqlm_crossstudy_debt_wave.R`
- debt-wave launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_debt_wave.R`
- debt-wave healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_debt_wave.R`

## 6) Current Debt

Remaining scientific debt is now split cleanly:

1. hard root FAIL band:
   - `6` roots
2. rhs comparison debt:
   - `30` additional successful `rhs_ns` roots with
     `root_comparison_eligible_any = FALSE`

Current highest-value questions:

- can the anchor replay rescue the six hard root FAILs under the patched PSOCK runner?
- can a narrow ridge/rhs crossover profile improve the debt slice without reopening the full study?
- does a targeted rhs diagnostics probe reduce any rhs comparison debt, or does that debt require a
  separate code-path fix later?
