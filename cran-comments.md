## exdqlm 1.1.0

### Release context

This release updates CRAN version 1.0.0 with package-design and documentation
improvements made while preparing the accompanying JSS software article for
resubmission.

The main changes are user-facing but backward compatible:

- Dynamic fitted objects now inherit from the shared `exdqlmFit` class while
  retaining their existing first class names (`exdqlmLDVB`, `exdqlmMCMC`, and
  legacy `exdqlmISVB`).
- Static fitted objects now inherit from the shared `exalStaticFit` class while
  retaining their existing first class names (`exalStaticLDVB` and
  `exalStaticMCMC`).
- Fitted models and post-processing objects have more informative `print()` and
  `summary()` methods.
- Dynamic fits now support standard post-processing methods: `plot(fit)`,
  `plot(fit, type = "component")`, `plot(fit, type = "state")`, and
  `predict(fit, ...)`.
- Diagnostic constructors now return visible diagnostic objects that can be
  printed, summarized, and plotted with standard methods.
- `exdqlmForecast()` now returns forecast objects visibly and uses
  `plot = FALSE` by default. Explicit `plot = TRUE` remains supported.
- Documentation now describes the shared object families and the standard method
  workflow directly.

Existing named helper functions such as `exdqlmPlot()`, `compPlot()`,
`exdqlmForecast()`, `exdqlmDiagnostics()`, `exalStaticDiagnostics()`, and
`exdqlmForecastDiagnostics()` remain available.

### Test environments

- Local: AlmaLinux/Rocky-compatible Linux (x86_64), R 4.6.0 (2026-04-24).
- Local development tools available for this check included `pandoc` 3.9.0.2
  and the R package `V8`, so README/NEWS and HTML math rendering checks ran.
- Local commands used:
  - `Rscript -e 'source("tests/testthat/setup-cran-thread-controls.R"); pkgload::load_all("."); testthat::test_dir("tests/testthat", reporter = "summary")'`
  - `R CMD build .`
  - `R CMD check --no-manual --run-donttest exdqlm_1.1.0.tar.gz`

### R CMD check results

- `0 errors | 0 warnings | 0 notes`.

### Notes for CRAN

1) Timing relative to version 1.0.0

- This update follows version 1.0.0 closely because the accompanying software
  article was returned editorially by JSS before external review with a request
  to improve and document the package class/method design. The changes in this
  release address those package-design comments while preserving compatibility
  with the 1.0.0 API.

2) CPU time during tests

- As in version 1.0.0, the test entrypoint caps native OpenMP/BLAS thread
  counts before loading the package. Heavyweight inference/backend-validation
  files are skipped on CRAN while lighter API, regression, class, method, and
  diagnostic tests remain covered by the CRAN suite.

3) Installed size note

- This package includes compiled C++ backends (Rcpp/RcppArmadillo), and the
  shared library is expected to remain the dominant contributor to installed
  package size.

4) Compiler hardening flag note

- Some local Linux toolchains inject non-portable compiler hardening flags such
  as `-Werror=format-security`, `_FORTIFY_SOURCE`, and `_GLIBCXX_ASSERTIONS`.
  These flags are injected by the platform compiler configuration, not by the
  package Makevars.
