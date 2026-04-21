# Precision-Beta API Productization

Date: 2026-04-20
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`

## Goal

Turn the winning code-level precision-beta rescue strategies from the final ridge-pair recovery matrix into a stable, user-facing API that is:

- easy to configure from `qdesn_fit_mcmc()` and `exal_mcmc_fit()`
- backward compatible with the existing nested `mcmc_control` contract
- fully wired into validation/export diagnostics
- reproducible in the current YAML/materializer workflow

## Implemented API

### Public helper

New exported helper:

- `exal_make_precision_beta_control()`

Supported presets:

- `recommended` -> alias for `ladder_v2`
- `off`
- `ladder_v1`
- `ladder_v2`
- `eigen_v1`

### Runtime entrypoints

`qdesn_fit_mcmc()` now accepts:

- `mcmc_args$precision_beta = "ladder_v2"`
- `mcmc_args$precision_beta = "eigen_v1"`
- `mcmc_args$precision_beta = exal_make_precision_beta_control(...)`
- `mcmc_args$precision = ...` as a backward-compatible alias

`exal_mcmc_fit()` now normalizes `mcmc_control$precision_beta` through the same preset-aware resolver, so direct package users and QDESN users share the same behavior.

## Diagnostic/export changes

Successful validation rows now also persist:

- `mcmc_precision_beta_preset`

The existing precision-beta rescue diagnostics remain intact:

- enable flag
- symmetrize flag
- eigen fallback flag
- jitter ladder max
- direct/jitter/eigen success counts
- rescue count / first rescue iteration / max jitter used

## Materializer/product wiring

The remaining precision-code matrix materializer now writes the cleaner preset form:

- `precision_beta: { preset: ladder_v2, trace: yes }`
- `precision_beta: { preset: eigen_v1, trace: yes }`

instead of embedding raw jitter ladders in every generated defaults file.

## Verification

Passed after implementation:

```bash
Rscript -e 'testthat::test_local(filter = "exal-inference-config|exal-precision-beta-rescue|qdesn-precision-beta-validation-export|qdesn-dynamic-tau050-remaining-precision-code-matrix-config|qdesn-fit-mcmc-precision-beta-api|exal-mcmc", reporter = "summary")'
```

Regenerated package docs:

```bash
Rscript -e 'roxygen2::roxygenise()'
```

Regenerated preset-based matrix defaults:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_code_matrix.R
```

## Practical recommendation

For future hard precision-beta failures:

1. start with `precision_beta = "ladder_v2"`
2. escalate to `precision_beta = "eigen_v1"` only if the stronger ladder is still not enough
3. do not reuse `ladder_v1` as the default repair policy; it lost on both AL and EXAL in the final pair matrix
