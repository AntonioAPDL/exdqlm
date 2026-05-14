## exdqlm 0.5.0

### Release context

This development update builds on the consolidated 0.4.0 package line and
focuses on dynamic diagnostic reproducibility:

- `exdqlmDiagnostics()` now computes CRPS through a finite integrated
  quantile-score approximation over posterior predictive empirical quantiles.
- `exdqlmForecastDiagnostics()` adds package-level held-out forecast scoring for
  `exdqlmForecast()` objects, using target-quantile check loss and CRPS from
  posterior predictive forecast draws.
- `exdqlmDiagnostics()` now uses a deterministic one-dimensional semiclosed KL
  normality diagnostic for MAP standardized forecast errors.
- The reported `KL` direction is aligned with the documented diagnostic target
  `KL(P_error || N(0,1))`; `KL (flipped)` reports the reverse direction.
- The stochastic default `FNN::KL.divergence()` path was removed, so `FNN` is no
  longer required as an imported package dependency.

No default backend flip is introduced in this update:

- `exdqlm.use_cpp_builders` remains opt-in (`FALSE` by default).
- Existing R fallbacks remain available.

This update intentionally excludes branch-local simulation/validation-study
artifacts; only package-facing API, documentation, and tests are included.

### Test environments

- Local: AlmaLinux/Rocky-compatible Linux (x86_64), R 4.5.3 (2026-03-11).
- Local development tools available for this check included `pandoc` 3.9.0.2
  and the R package `V8`, so README/NEWS and HTML math rendering checks ran.
- Local commands used:
  - `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-kl-diagnostics.R")'`
  - `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-diagnostics-metrics.R")'`
  - `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-exdqlm-transfer-mcmc.R")'`
  - `Rscript -e 'testthat::test_local(reporter = "summary")'`
  - `R CMD build .`
  - `Rscript -e 'rcmdcheck::rcmdcheck("exdqlm_0.5.0.9000.tar.gz", args = "--as-cran", error_on = "never")'`

### R CMD check results

- `0 errors | 0 warnings | 3 notes`.

### Notes for CRAN

1) Dependency reduction

- `FNN` has been removed from `Imports` because dynamic KL diagnostics no longer
  use `FNN::KL.divergence()`.
- The replacement KL diagnostic is implemented with package-internal base-R
  one-dimensional nearest-neighbor calculations and deterministic reference
  grids.

2) Installed size note

- This package includes compiled C++ backends (Rcpp/RcppArmadillo), and the
  shared library is expected to remain the dominant contributor to installed
  package size.

3) README/NEWS pandoc note

- The current local check host has `pandoc` 3.9.0.2 available, and the
  top-level README/NEWS checks completed successfully.

4) Development-version note

- The current development branch uses version `0.5.0.9000`; this should be
  changed to the final release version before CRAN submission.

5) Future timestamp note

- The local Linux check reported `unable to verify current time`.
- This appears to be a local system-time verification limitation rather than a
  package timestamp issue.

6) Compiler hardening flag note

- Some local Linux toolchains inject non-portable compiler hardening flags such
  as `-Werror=format-security`, `_FORTIFY_SOURCE`, and `_GLIBCXX_ASSERTIONS`.
  These flags are injected by the platform compiler configuration, not by the
  package Makevars.
