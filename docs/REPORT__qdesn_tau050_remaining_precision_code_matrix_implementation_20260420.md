# QDESN Tau050 Remaining Precision Code Matrix Implementation

Date: `2026-04-20`

## Summary

This report records the implementation of the next recovery phase after the config-only precision search failed on the final unresolved tau050 pair.

The new program is intentionally:

- narrow in root scope: the exact final unresolved pair only
- broad in mechanism scope: six code-level precision rescue policies
- reproducible: generated defaults, frozen map, tests, wrapper wiring, and prepare-only validation

## Evidence-Based Motivation

Recent source-of-truth results before this implementation:

- original hard crash surface: `23`
- recovered by run-specific relaunches: `21`
- still unresolved: `2`
- latest config-only precision matrix: `0 / 7` recovered

The unresolved pair is:

1. `AL / laplace / tau 0.50 / fit_size 5000 / ridge`
1. `EXAL / laplace / tau 0.50 / fit_size 5000 / ridge`

Both are now failing in the beta precision Cholesky path rather than in the earlier latent-`v` draw path.

## Implemented Code Changes

### Precision-beta config and normalization

Updated:

- [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)

Added first-class `mcmc.precision_beta` support with:

- `enabled`
- `symmetrize`
- `jitter_ladder`
- `eigen_fallback`
- `eigen_floor_abs`
- `eigen_floor_rel`
- `trace`

### Precision-beta sampler rescue logic

Updated:

- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)

Implemented:

- adaptive precision repair helper
- optional matrix symmetrization
- diagonal-jitter ladder rescue
- optional eigenvalue-floored SPD fallback
- structured precision failure emission via `QDESN_PRECISION_BETA_FAILURE_JSON`
- successful rescue accounting in MCMC diagnostics

### Validation export

Updated:

- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)

Added:

- parsing of structured precision-beta failure payloads
- failure-health-row export for precision rescue metadata
- successful-fit export for precision rescue counters

### Materializer and wrapper wiring

Added:

- [remaining precision code matrix materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix.R)

Updated:

- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

New phases:

- `remaining_precision_code_al_ladder_v1`
- `remaining_precision_code_al_ladder_v2`
- `remaining_precision_code_al_eigen_v1`
- `remaining_precision_code_exal_ladder_v1`
- `remaining_precision_code_exal_ladder_v2`
- `remaining_precision_code_exal_eigen_v1`

## Generated Reproducible Assets

- [matrix map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix_map.csv)
- [AL ladder v1 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v1_defaults.yaml)
- [AL ladder v2 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_ladder_v2_defaults.yaml)
- [AL eigen v1 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_al_eigen_v1_defaults.yaml)
- [EXAL ladder v1 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_ladder_v1_defaults.yaml)
- [EXAL ladder v2 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_ladder_v2_defaults.yaml)
- [EXAL eigen v1 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_exal_eigen_v1_defaults.yaml)

## Tests Added

New tests:

- [test-exal-precision-beta-rescue.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-precision-beta-rescue.R)
- [test-qdesn-precision-beta-validation-export.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-precision-beta-validation-export.R)
- [test-qdesn-dynamic-tau050-remaining-precision-code-matrix-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-remaining-precision-code-matrix-config.R)

Focused suite passed:

```bash
Rscript -e 'testthat::test_local(filter = "exal-precision-beta-rescue|qdesn-precision-beta-validation-export|qdesn-dynamic-tau050-remaining-precision-code-matrix-config|exal-inference-config|exal-mcmc|qdesn-dynamic-failure-repair|qdesn-sigmagam-warmup-validation-export", reporter = "summary")'
```

## Prepare-Only Validation

Materializer passed:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix.R
```

All six phases passed `prepare-only`:

- `remaining_precision_code_al_ladder_v1`
- `remaining_precision_code_al_ladder_v2`
- `remaining_precision_code_al_eigen_v1`
- `remaining_precision_code_exal_ladder_v1`
- `remaining_precision_code_exal_ladder_v2`
- `remaining_precision_code_exal_eigen_v1`

## Resulting State

At the end of this implementation step, the repo is ready for a disciplined code-level launch on the final unresolved pair:

- exact root scope stays frozen
- launch and healthcheck wrappers recognize the new phases
- defaults and map are materialized in-repo
- tests and prepare-only checks are green

The next step is to launch the six pair-only code-level lanes in parallel with `1` worker each and evaluate whether any structural precision rescue succeeds.
