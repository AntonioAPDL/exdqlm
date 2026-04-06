# TRACK: QDESN Dynamic exdqlm Cross-Study Validation

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
Reference repo: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

## 1) Mission

Build the QDESN counterpart to the **dynamic** exdqlm validation study on the same recovered
dynamic dataset surface, using:

- likelihoods:
  - `exal`
  - `al`
- methods:
  - `vb`
  - `mcmc`
- QDESN priors:
  - `ridge`
  - `rhs_ns`

This tracker is for the corrected dynamic comparison-facing program.

## 2) Current Status

Status: **dynamic relaunch implementation completed; canonical grid recovered from the live
reference surface; smoke and full prepare-only passed; real smoke completed successfully on the
correct dynamic surface; broad supervised launch is the next step**

Scope correction summary:

- the completed `qdesn_static_exdqlm_crossstudy_*` program was scientifically valid as a static
  analog study;
- it was not the intended deliverable if the goal is direct comparison against the exdqlm dynamic
  validation surface;
- the next required move is therefore a dynamic exdqlm-aligned relaunch.

Implementation update:

- the corrected dynamic helper stack is now implemented;
- the canonical dynamic grid was materialized directly from the exdqlm reference tree and checked
  in as:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- prepare-only passed for:
  - smoke batch
  - full batch
- the first real smoke run exposed a YAML scalar coercion bug on `external_data.y_column`;
- that bug is now fixed in both config and shared config normalization;
- a second runtime issue then exposed child BLAS oversubscription;
- that thread-cap issue is now fixed in the shared pipeline launcher path;
- the corrected smoke run finished with:
  - `4/4 SUCCESS` roots,
  - `16` fit rows,
  - `6 PASS / 8 WARN / 2 FAIL`,
  - recommendation:
    - `COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND`

Authoritative implementation report:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_implementation_and_smoke_20260406.md`

## 3) Current Best Read Of The Target Dynamic Surface

Observed live reference surface on disk:

- root family:
  - `function_testing_20260309_dynamic_dlm_family_qspec`
- scenario currently observed:
  - `dlm_constV_smallW`
- families:
  - `gausmix`
  - `laplace`
  - `normal`
- taus:
  - `0.05`
  - `0.25`
  - `0.95`
- dynamic fit horizons:
  - `lastTT500`
  - `lastTT5000`

Observed reference dataset-cell count:

- `18`

Hard rule:

- do not trust this by memory alone;
- materialize the canonical reference grid directly from the live reference roots before any real
  launch.

## 4) Correct QDESN Analog Grid

If the observed `18`-cell dynamic surface is confirmed:

- `18` dynamic dataset cells
- `2` QDESN priors
- total roots:
  - `36`

Per root fit matrix:

- `vb/exal`
- `mcmc/exal`
- `vb/al`
- `mcmc/al`

Expected fit rows:

- `144`

## 5) What Is Explicitly Out Of Scope

- no further compute on the static cross-study as the primary validation target;
- no direct reuse of `config/validation/qdesn_dynamic_family_prior_grid.csv` as the launch grid;
- no broad search for one generic tuning profile before the dynamic-aligned baseline run exists;
- no reopening of the closed dynamic certification family search.

## 6) Read First

1. `docs/REPORT__qdesn_exdqlm_dynamic_scope_correction_20260406.md`
2. `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_validation_20260406.md`
3. `docs/TRACK__qdesn_static_exdqlm_crossstudy_validation.md`
4. `docs/PLAN__qdesn_validation_final_r512_certification_20260403.md`
5. `config/validation/qdesn_dynamic_family_prior_grid.csv`
6. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`

## 7) Core Assets

Implemented:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`
- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_grid.R`
- `R/qdesn_dynamic_exdqlm_crossstudy.R`
- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`

Validated campaign artifacts:

- smoke prepare-only:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-155404__git-eb141cc/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- full prepare-only:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-full-20260406-155404__git-eb141cc/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- corrected smoke run:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation/qdesn-dynamic-exdqlm-crossstudy-smoke-20260406-threadsfix__git-eb141cc/20260406-161217__git-eb141cc/summary/qdesn_dynamic_crossstudy_summary.md`

## 8) Move-Forward Rules

1. reconstruct the canonical dynamic reference surface from disk first;
2. write a checked-in grid only after the reconstruction matches expectations;
3. run a narrow smoke batch before the broad batch launch if the external dynamic path is new;
4. use prepare-only before any real launch batch;
5. launch the broad dynamic analog before any local debt-only follow-up;
6. only after the broad dynamic analog completes should local tuning be considered.

## 9) Success Criteria

This corrected dynamic study is ready for the broad launch only when:

1. the canonical dynamic reference grid is materialized and validated;
2. the QDESN dynamic analog runner can consume those external dynamic inputs;
3. prepare-only passes cleanly;
4. the narrow real smoke batch closes successfully on the mirrored dynamic surface;
5. the batch launch contract is documented and reproducible.
