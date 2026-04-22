# QDESN Warmup Builder Normalization and 0.4.0 Adoption

Date: 2026-04-21

## Summary

This update normalized the public warmup/control surface around the strongest
package-layer numerical-stability work that had already proven useful in the
QDESN validation study.

The work had three goals:

1. make the advanced QDESN-side warmup/rescue controls easier to read and use;
2. expose a cleaner package-native builder surface for the shared dynamic/static
   VB/MCMC warmup blocks;
3. propagate that normalized warmup layer into the `0.4.0` package branch and
   the `0.4.0` validation-study branch without dragging in QDESN-only rescue
   machinery where it does not belong.

## What Changed in the QDESN Branch

The QDESN branch gained a more explicit advanced control-builder layer in
`R/exal_inference_config.R`, including:

- `exal_make_vb_sigmagam_control()`
- `exal_make_vb_sts_control()`
- `exal_make_vb_online_control()`
- `exal_make_vb_control()`
- `exal_make_mcmc_sigmagam_control()`
- `exal_make_mcmc_theta_control()`
- `exal_make_mcmc_latent_state_control()`
- `exal_make_mcmc_dqlm_sigma_control()`
- `exal_make_mcmc_latent_v_control()`
- `exal_make_mcmc_latent_s_control()`
- `exal_make_mcmc_rhs_control()`
- `exal_make_mcmc_control()`
- `exal_make_precision_beta_control()`

The QDESN-facing wrappers were also rewired to consume the normalized control
surface more cleanly:

- `R/qdesn_mcmc.R`
- `R/qdesn_vb.R`

This preserves the richer QDESN-specific rescue surface, including the
precision-beta repair controls, while making the package-native warmup blocks
much easier to audit.

## What Was Carried to 0.4.0

The plain `0.4.0` package branch first received the earlier validated warmup
backport, then a package-native builder layer was added on top of it.

The new `0.4.0` package-facing builder file is:

- `R/exal_inference_config.R`

The builder surface carried into plain `0.4.0` is intentionally scoped to the
shared package-layer warmup controls:

- `exal_make_vb_sigmagam_control()`
- `exal_make_vb_sts_control()`
- `exal_make_vb_control()`
- `exal_make_mcmc_sigmagam_control()`
- `exal_make_mcmc_theta_control()`
- `exal_make_mcmc_latent_state_control()`
- `exal_make_mcmc_dqlm_sigma_control()`
- `exal_make_mcmc_control()`

The `0.4.0` branch does **not** adopt the QDESN-only readout rescue layer such
as `latent_v`, `latent_s`, `rhs`, or `precision_beta` blocks, because those
depend on the QDESN/exAL readout stack rather than the plain package-facing
dynamic/static fit functions.

## Package Entry Points Rewired in 0.4.0

The following package entry points were normalized so they can consume the new
builder surface directly:

- `exalStaticLDVB(..., vb_control = ...)`
- `exalStaticMCMC(..., mcmc_control = ...)`
- `exdqlmLDVB(..., vb_control = ...)`
- `exdqlmMCMC(..., mcmc_control = ...)`

This keeps the old raw arguments working while making the preferred control path
more readable and consistent.

## Verification

QDESN branch verification:

```bash
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'pkgload::load_all(".", quiet = TRUE)'
Rscript -e 'testthat::test_local(filter = "exal-inference-config|qdesn-fit-mcmc-precision-beta-api|0p4p0-api-compatibility", reporter = "summary")'
```

Plain `0.4.0` package verification:

```bash
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'pkgload::load_all(".", quiet = TRUE)'
Rscript -e 'testthat::test_file("tests/testthat/test-exal-inference-config.R", reporter = testthat::StopReporter$new())'
Rscript -e 'testthat::test_file("tests/testthat/test-vb-mcmc-convergence-controls.R", reporter = testthat::StopReporter$new())'
Rscript -e 'testthat::test_file("tests/testthat/test-mcmc-dynamic-strict-parity.R", reporter = testthat::StopReporter$new())'
Rscript -e 'testthat::test_file("tests/testthat/test-static-diagnostics.R", reporter = testthat::StopReporter$new())'
Rscript -e 'testthat::test_file("tests/testthat/test-crps-helper-regression.R", reporter = testthat::StopReporter$new())'
Rscript -e 'testthat::test_file("tests/testthat/test-dlm-df-smoother-regression.R", reporter = testthat::StopReporter$new())'
```

`0.4.0` validation-branch verification:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE)'
Rscript -e 'testthat::test_file("tests/testthat/test-exal-inference-config.R", reporter = testthat::StopReporter$new())'
Rscript -e 'testthat::test_file("tests/testthat/test-vb-mcmc-convergence-controls.R", reporter = testthat::StopReporter$new())'
```

## Branch Anchors

At the end of this normalization/adoption pass, the relevant branches are:

- QDESN validation branch:
  - `feature/qdesn-mcmc-alternative-0p4p0-integration`
- plain `0.4.0` package branch:
  - `cransub/0.4.0`
- `0.4.0` validation-study branch:
  - `validation/rerun-after-0.4.0-sync-0p4p0-integration`

The package and validation branches should now be updated from the normalized
package-layer warmup work, while the QDESN branch remains the superset branch
that additionally carries the QDESN-specific readout rescue logic.
