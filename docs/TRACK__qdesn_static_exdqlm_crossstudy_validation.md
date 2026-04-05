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

Status: **Wave 1 broad launch is the authoritative source baseline; Wave 2 completed Stage 1 and was intentionally stopped before Stage 2; Wave 3 local fit-fail closure is now the active follow-up, and the `rhs_ns` VB diagnostics-path fix has been validated on a representative smoke root**

Current scope decision:

- launch surface: `static only`
- dynamic row-15 sidecar: `excluded`
- `gausmix @ tau=0.50`: `excluded`
- current move-forward mode: `fit-fail closure with local tuning allowed`

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
- `rhs_ns` remains the main debt family, but the remaining problem is now better described as fit-level FAIL closure than comparison-only debt;
- the next step is therefore a local fit-fail closure wave, not another `72`-root relaunch.

Validation checkpoints completed:

- canonical grid materialization: `PASS`
- prepare-only preflight: `PASS`
- one-root live smoke: `PASS`
- Wave-1 broad shared-setup launch: `SOURCE_BASELINE_ESTABLISHED`
- Wave-2 debt-wave Stage-1 probe: `COMPLETED_AND_STOPPED_BEFORE_STAGE2`
- rhs-family diagnostics fallback validation on representative `rhs_ns` smoke root: `PASS`
- Wave-3 fit-fail closure plan + runner implementation: `READY_FOR_PREPARE_ONLY_AND_LAUNCH`

## 3) Read First

1. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
2. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave1_broad_launch_20260404.md`
3. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave2_stage1_closeout_20260404.md`
4. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closure_20260404.md`
5. `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
6. `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
7. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
8. `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
9. `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
10. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`
11. `scripts/run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
12. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
13. `scripts/materialize_qdesn_static_exdqlm_crossstudy_grid.R`
14. `R/qdesn_static_exdqlm_crossstudy.R`
15. `R/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`

## 4) Hard Rules

1. Recover the dataset surface from disk; do not approximate it.
2. Preserve current-vs-legacy provenance in metadata and reporting.
3. Do not reopen the finished dynamic DLM tuning program here.
4. Keep the first launch static-only.
5. Treat comparison tables as required outputs.
6. Use prepare-only before real launch.
7. Keep compute conservative and single-threaded per fit.
8. Do not relaunch the whole `72`-root surface while the debt set remains narrow.
9. Keep the shared static defaults as the default baseline unless a completed local slice result clearly beats them.
10. Allow local slice-specific tuning where needed; do not force one generic setup to solve every remaining FAIL.

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
- fit-fail closure manifest:
  - `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
- fit-fail closure helper:
  - `R/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
- fit-fail closure launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
- fit-fail closure healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`

## 6) Current Debt

Remaining scientific debt is now split more precisely:

1. root-status hard FAIL band:
   - `6` roots
   - all in `static_shrink x laplace x tt=1000`
2. rhs_ns VB diagnostics-path FAIL bucket:
   - `66` FAIL rows
   - `33` roots
   - likely helper-path debt, not pure tuning debt
3. ridge `exal/mcmc` stability FAIL bucket:
   - `24` FAIL rows
   - `24` roots
4. rhs_ns `mcmc` stability FAIL bucket:
   - `40` FAIL rows
   - `30` roots

Current highest-value questions:

- does the patched shared default clear the full `33`-root `rhs_ns` VB diagnostics bucket under a fresh campaign run the same way it did on the representative smoke root?
- can the completed `D410_ridge_rescue_reference` probe lead reduce the ridge `exal/mcmc` fail slice on the full targeted ridge set?
- do the remaining rhs_ns `mcmc` FAILs split better by `tt=100` versus `tt=1000` than by one generic rhs profile?

## 7) Current Baseline Map

Shared default baseline:

- keep the shared static defaults as the default baseline everywhere
- the active shared default now includes the validated `rhs_trace.rds` fallback so successful
  `rhs_ns` VB fits are not falsely marked `FAIL` when `rhs_run_summary.csv` is missing

Local promoted baseline:

- promote `D410_ridge_rescue_reference` as the current local ridge rescue baseline
- do **not** promote any rhs-local Stage-1 profile from Wave 2 as a general rhs baseline

Current practical read:

- the shared baseline is now the right default for the `rhs_ns` VB closure stage
- `D410` is the right local reference for the ridge `exal/mcmc` closure stage
- the rhs `mcmc` closure still needs separate `tt=100` and `tt=1000` local slices rather than
  one shared rescue profile
