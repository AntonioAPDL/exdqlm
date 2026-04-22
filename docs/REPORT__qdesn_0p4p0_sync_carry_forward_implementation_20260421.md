# Report: 0.4.0 Sync Carry-Forward Implementation

Date: 2026-04-21

## Summary

This implementation reconciles the current QDESN validation-study branch with
the authoritative `0.4.0` package line by combining:

- upstream `0.4.0` naming and package shape from `dc032e6`
- proven validation/backport decisions from `5bdc943` and `54fb296`
- newer QDESN-side numerical-recovery work already present on this branch

## Main Decisions Implemented

### 1. Upstream `0.4.0` naming is restored at the package surface

The branch now exposes the canonical `0.4.0` names:

- `exalStaticLDVB()`
- `exalStaticMCMC()`
- `exalStaticDiagnostics()`
- `exdqlmTransferISVB()`
- `exdqlmTransferLDVB()`
- `exdqlmTransferMCMC()`
- `quantileSynthesis()`

Lower-snake-case validation-era names remain available as compatibility aliases
on this branch.

### 2. Proven dynamic warmup/stability code is restored

The following package files were realigned to the proven validation backport:

- `R/exdqlmMCMC.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmISVB.R`

This restores the validation-derived warmup, freeze, and stabilization logic
that should carry forward into the next dataset phase.

### 3. Newer QDESN-side static and precision behavior is preserved

The branch keeps the stronger current-QDESN static and numerical-recovery
behavior in:

- `R/exal_static_LDVB.R`
- `R/exal_static_mcmc.R`
- `R/exal_mcmc_fit.R`
- `R/exalDiagnostics.R`
- `R/exal_inference_config.R`
- `R/utils.R`

This is where the current branch still goes beyond the older `54fb296`
backport, especially for the recent tau050 numerical-recovery program.

In practice, the static files were re-harmonized to the proven backport
behavior and then kept compatible with current-QDESN consumers by retaining the
lower-snake entry points plus dual class aliases:

- `exal_ldvb` / `exal_vb` / `exalStaticLDVB`
- `exal_mcmc` / `exal_static_mcmc` / `exalStaticMCMC`

### 4. Upstream dataset/docs additions are retained

The branch includes upstream `0.4.0` additions such as:

- `R/BTflowUSGS.R`
- package-facing docs/examples aligned to the `0.4.0` API story

## Carry-Forward Checklist For The Validation-Study `0.4.0` Repo

When updating the validation-study `0.4.0` repo, carry forward this package
slice first:

### Must-carry package files

- `R/exdqlmMCMC.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmISVB.R`
- `R/compat_0p4p0_api_aliases.R`
- `R/exal_static_LDVB.R`
- `R/exal_static_mcmc.R`
- `R/exal_mcmc_fit.R`
- `R/exalDiagnostics.R`
- `R/exal_inference_config.R`
- `R/utils.R`
- `R/BTflowUSGS.R`

### Must-carry focused tests

- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/test-mcmc-dynamic-strict-parity.R`
- `tests/testthat/test-static-diagnostics.R`
- `tests/testthat/test-crps-helper-regression.R`
- `tests/testthat/test-dlm-df-smoother-regression.R`

### Docs/examples to keep aligned

- `README.Rmd`
- `README.md`
- `R/exdqlm-package.R`

## Verification Completed

The synced branch was verified with:

- `Rscript -e 'roxygen2::roxygenise()'`
- `Rscript -e 'pkgload::load_all(\".\", quiet = TRUE)'`
- `Rscript -e 'testthat::test_local(filter = \"0p4p0-api-compatibility|vb-mcmc-convergence-controls|mcmc-dynamic-strict-parity|static-diagnostics|crps-helper-regression|dlm-df-smoother-regression\", reporter = \"summary\")'`

The focused test slice passed after restoring:

- shared dynamic covariance regularization helpers
- the shorter-trace-compatible VB trace builder
- static `sigmagam` warmup controls
- the reduced-DQLM helper signature expected by the synced dynamic callers

## Environment Note

`README.Rmd` and `README.md` were kept aligned in source, but a full
`rmarkdown::render(\"README.Rmd\", output_format = \"github_document\")` could
not be completed in this environment because `pandoc` was unavailable. This did
not affect package metadata or test verification.

## What This Sync Does Not Do

- it does not change the dynamic datasets
- it does not relaunch tau050 validation
- it does not port validation orchestration/reporting scripts into package code

Those changes belong in the next repo phase after this package sync is in a
clean, verified state.
