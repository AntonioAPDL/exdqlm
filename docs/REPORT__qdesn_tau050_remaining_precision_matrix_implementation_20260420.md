## Summary

This report records the implementation of a broad precision-stabilization experiment matrix for the final unresolved tau050 crash surface after the run-specific remaining-fail relaunch recovered `13 / 15` hard failures.

The matrix is intentionally narrow in root scope but broad in mechanism scope:

- root scope: the exact remaining precision pair only
- mechanism scope: multiple conditioning and slice-stability variants across AL and EXAL

The goal is to identify a precision-stable relaunch spec for the last unresolved root under both `al` and `exal`.

## Remaining unresolved surface

The unresolved roots after the run-specific relaunch are:

1. `AL / laplace / tau 0.50 / fit_size 5000 / ridge`
1. `EXAL / laplace / tau 0.50 / fit_size 5000 / ridge`

Both had moved beyond the earlier latent-`v` invalid-draw failure family and were now failing in the precision Cholesky path.

## Design

The matrix keeps the successful shared stabilization baseline:

- tau freeze
- theta freeze
- bounded latent-`v` rescue
- `gig_eps = 1e-10`

It varies the precision-facing controls that looked most promising from the recent failures:

- conditioning mode
- `gram_ridge`
- `use_log_sigma`
- `width_sigma`
- `core_extra_passes`
- EXAL `core_update_mode`

## Implemented matrix arms

### AL arms

1. `remaining_precision_matrix_al_qr_v1`
   - `conditioning.mode = qr_whiten`
   - `gram_ridge = 1e-4`
   - `use_log_sigma = true`
   - `width_sigma = 0.22`
   - `core_extra_passes = 1`

1. `remaining_precision_matrix_al_qr_v2`
   - `conditioning.mode = qr_whiten`
   - `gram_ridge = 1e-2`
   - `use_log_sigma = true`
   - `width_sigma = 0.20`
   - `core_extra_passes = 2`

1. `remaining_precision_matrix_al_diag_v1`
   - `conditioning.mode = diag_scale`
   - `scale_metric = rms`
   - `use_log_sigma = true`
   - `width_sigma = 0.22`
   - `core_extra_passes = 1`

### EXAL arms

1. `remaining_precision_matrix_exal_qr_v1`
   - `conditioning.mode = qr_whiten`
   - `gram_ridge = 1e-3`
   - `core_update_mode = gamma_sigma_gamma`
   - `use_log_sigma = true`
   - `width_sigma = 0.22`
   - `core_extra_passes = 1`

1. `remaining_precision_matrix_exal_qr_v2`
   - `conditioning.mode = qr_whiten`
   - `gram_ridge = 1e-2`
   - `core_update_mode = gamma_sigma_gamma`
   - `use_log_sigma = true`
   - `width_sigma = 0.20`
   - `core_extra_passes = 2`

1. `remaining_precision_matrix_exal_qr_sig_v1`
   - `conditioning.mode = qr_whiten`
   - `gram_ridge = 1e-2`
   - `core_update_mode = sigma_then_gamma`
   - `use_log_sigma = true`
   - `width_sigma = 0.20`
   - `core_extra_passes = 2`

1. `remaining_precision_matrix_exal_diag_v1`
   - `conditioning.mode = diag_scale`
   - `scale_metric = rms`
   - `core_update_mode = gamma_sigma_gamma`
   - `use_log_sigma = true`
   - `width_sigma = 0.22`
   - `core_extra_passes = 1`

## Implemented files

New files:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix.R`
- `tests/testthat/test-qdesn-dynamic-tau050-remaining-precision-matrix-config.R`
- `docs/PLAN__qdesn_tau050_remaining_precision_matrix_20260420.md`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_map.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_qr_v1_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_qr_v2_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_al_diag_v1_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_v1_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_v2_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_qr_sig_v1_defaults.yaml`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_exal_diag_v1_defaults.yaml`

Updated files:

- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

## Validation

Materializer validation:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix.R
```

This produced a `7`-row matrix map covering the exact remaining AL/EXAL precision pair.

Focused test battery:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-remaining-precision-matrix-config|qdesn-dynamic-tau050-remaining-precision-pair-config|exal-inference-config|exal-mcmc|qdesn-dynamic-failure-repair|qdesn-sigmagam-warmup-validation-export", reporter = "summary")'
```

Prepare-only validation passed for all seven phases:

- `remaining_precision_matrix_al_qr_v1`
- `remaining_precision_matrix_al_qr_v2`
- `remaining_precision_matrix_al_diag_v1`
- `remaining_precision_matrix_exal_qr_v1`
- `remaining_precision_matrix_exal_qr_v2`
- `remaining_precision_matrix_exal_qr_sig_v1`
- `remaining_precision_matrix_exal_diag_v1`

## Operational intent

The experiment matrix is intended to be launched in parallel with one worker per lane so the two remaining roots are screened quickly across multiple promising precision-stability strategies without materially increasing per-lane risk.
