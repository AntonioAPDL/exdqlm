## exdqlm 1.1.1

### Release context

This is a narrow reproducibility and inference-stability update to CRAN
version 1.1.0. The update was prepared while revising the accompanying Journal
of Statistical Software article after editorial prescreening comments on the
replication materials. The package API, exported object classes, and
manuscript-level statistical claims are unchanged.

The main changes are:

- compiled stochastic helper routines now use serial R-controlled random-number
  streams for manuscript-relevant stochastic paths, avoiding OpenMP worker RNG
  calls and wall-clock/thread-indexed private seeds;
- repeated-seed tests were added for compiled stochastic helpers and small
  dynamic/static MCMC workflows;
- the default MCMC update for dynamic and static exAL likelihood fits now uses
  a scale-collapsed gamma slice transition followed by an exact conditional GIG
  redraw for sigma;
- the default LDVB scale-skewness block for dynamic and static exAL likelihood
  fits now uses a structured `q(gamma) q(sigma | gamma)` approximation;
- legacy MCMC and LDVB scale-skewness options remain available by explicit
  user selection.

### Test environments

- Local: AlmaLinux/Rocky-compatible Linux (x86_64), R 4.6.0 (2026-04-24).
- GitHub Actions:
  - Ubuntu release;
  - Ubuntu devel;
  - Ubuntu oldrel-1;
  - macOS release;
  - Windows release.
- R-hub:
  - Linux R-devel;
  - Windows R-devel;
  - macOS ARM64 R-devel.

### Local commands

- `R CMD build .`
- `R CMD check --as-cran exdqlm_1.1.1.tar.gz`
- targeted package repeatability tests for compiled stochastic helpers and
  dynamic/static MCMC workflows.

### R CMD check results

- Local `R CMD check --as-cran`: `0 errors | 0 warnings | 2 notes`.
- GitHub Actions matrix: passed on all configured platforms.
- R-hub matrix: passed on all configured platforms.

The two local notes are expected:

1. the package specifies C++17;
2. the installed package size is dominated by the compiled shared library.

### Reverse dependencies

No reverse dependencies were found for `exdqlm` on CRAN under Depends, Imports,
LinkingTo, or Suggests.

### Notes for CRAN

1) Timing relative to version 1.1.0

- This update follows version 1.1.0 closely because the JSS prescreening
  process identified reproducibility-interface concerns in the article archive.
  While investigating those differences, we found and corrected stochastic
  helper paths that should not depend on OpenMP worker RNG behavior. The update
  also stabilizes the exAL scale-skewness default inference blocks. These
  changes are backward compatible.

2) CPU time during tests

- As in earlier releases, the test entrypoint caps native OpenMP/BLAS thread
  counts before loading the package. Heavyweight inference/backend-validation
  files are skipped on CRAN while lighter API, regression, class, method,
  diagnostic, and reproducibility tests remain covered by the CRAN suite.

3) Installed size note

- This package includes compiled C++ backends through Rcpp/RcppArmadillo and
  RcppEigen. The shared library is expected to remain the dominant contributor
  to installed package size.

4) Compiler hardening flag note

- Some local Linux toolchains inject non-portable compiler hardening flags such
  as `-Werror=format-security`, `_FORTIFY_SOURCE`, and `_GLIBCXX_ASSERTIONS`.
  These flags are injected by the platform compiler configuration, not by the
  package Makevars.
