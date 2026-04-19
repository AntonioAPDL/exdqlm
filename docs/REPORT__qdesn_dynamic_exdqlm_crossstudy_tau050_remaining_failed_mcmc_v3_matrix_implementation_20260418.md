# QDESN Tau050 Remaining-Failed MCMC V3 Matrix Implementation Report

Date: 2026-04-18  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Scope

This report captures the implementation of a broad `v3` experiment matrix for the unresolved `10` MCMC failures that remained after the completed `v2` rerun.

This step intentionally broadens the search space while keeping the matrix coherent and reproducible.

## What Was Implemented

### 1. Latent-v rescue control surface

Implemented in:

- [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)

Added normalized `mcmc.latent_v.*` controls for:

- `rescue_on_invalid`
- `rescue_strategy`
- `rescue_max_consecutive`
- `rescue_burn_only`
- `rescue_force_retry_next_iter`
- `record_rescue_trace`

### 2. Latent-v rescue scheduling and failure payloads

Implemented in:

- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)

Added:

- bounded reuse-of-previous-`v` rescue
- rescue counters and traces
- structured failure metadata for latent-`v` errors
- JSON stdout marker emission for downstream parsing

### 3. Validation export preservation

Implemented in:

- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)

Added:

- parsing of `QDESN_LATENT_V_FAILURE_JSON=...`
- failed-fit export of rescue-aware failure metadata
- successful-fit export of rescue counters and traces
- latent-`v` trace export fields for rescue activity

### 4. V3 matrix defaults

Added:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_defaults.yaml)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_rescue_extended_defaults.yaml)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_qr_tightslice_defaults.yaml)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_exal_altcore_defaults.yaml)

### 5. Frozen unresolved-10 manifests

Added:

- [scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_grids.R)

Generated:

- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_canary_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_canary_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v3_residual_grid.csv)
- [qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v3_residual_grid.csv)

### 6. Launch and healthcheck phases

Updated:

- [scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

Added canary and residual phases for:

- rescue
- rescue extended
- exAL QR tight-slice
- exAL alternative core

## Test Coverage

Updated / added:

- [tests/testthat/test-exal-inference-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-inference-config.R)
- [tests/testthat/test-exal-mcmc.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-exal-mcmc.R)
- [tests/testthat/test-qdesn-latent-v-warmup-validation-export.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-latent-v-warmup-validation-export.R)
- [tests/testthat/test-qdesn-dynamic-tau050-remaining-failed-mcmc-v3-matrix-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-remaining-failed-mcmc-v3-matrix-config.R)

Targeted test command:

```bash
Rscript -e 'testthat::test_local(filter = "exal-inference-config|exal-mcmc|qdesn-latent-v-warmup-validation-export|qdesn-dynamic-tau050-remaining-failed-mcmc-v3-matrix-config", reporter = "summary")'
```

Result:

- passing

## Prepare-Only Status

The following canary prepares were run successfully and produced preflight manifests:

- `remaining_failed_mcmc_al_v3_rescue_canary`
- `remaining_failed_mcmc_exal_v3_rescue_canary`
- `remaining_failed_mcmc_al_v3_rescue_extended_canary`
- `remaining_failed_mcmc_exal_v3_rescue_extended_canary`
- `remaining_failed_mcmc_exal_v3_qr_tightslice_canary`
- `remaining_failed_mcmc_exal_v3_altcore_canary`

These prepares were run before commit finalization, so the live launches should be repeated from the committed revision to ensure the run tags carry the exact implementation SHA.

## Launch Recommendation

1. commit the matrix implementation
2. push the branch
3. rerun canary prepare-only from the committed SHA
4. launch canaries in small batches
5. collect a health snapshot before promoting any residual phases

## Key Operational Note

The matrix is intentionally broad, but still disciplined:

- the rescue arms test whether bounded `latent_v` salvage is enough
- the extended arm tests whether the remaining failures still need a longer `v` schedule
- the exAL-specific arms test whether the hardest pocket benefits more from conditioning and kernel geometry than from warmup alone

That gives the next interpretation step a much better chance of identifying a true winner instead of merely replaying the same failure surface with cosmetic changes.
