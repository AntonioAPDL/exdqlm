## exdqlm 1.1.2

### Release context

This is a narrow reproducibility patch to CRAN version 1.1.1. While checking
the replication materials for the accompanying Journal of Statistical Software
article, we found that the fast C++ dynamic MCMC FFBS backend was fixed-seed
repeatable within a platform but could produce different multivariate-normal
state draws across operating systems. The source of the difference was the use
of an SVD covariance square root in the stochastic state simulation step, where
valid singular-vector bases can differ by BLAS/LAPACK platform.

The package API, exported object classes, model specification interface, and
statistical target are unchanged.

The main changes are:

- the fast C++ dynamic MCMC FFBS backend now uses a Cholesky covariance square
  root for stochastic state simulation, avoiding platform-dependent SVD bases
  under fixed seeds;
- a direct multistate C++ FFBS repeatability test was added;
- the fresh-process/thread-setting repeatability test now also covers the
  multistate C++ FFBS path;
- a manual GitHub Actions diagnostic was added to compare the same FFBS and
  small fast-MCMC probes across Linux, macOS, and Windows.

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

- `R CMD INSTALL .`
- targeted repeatability tests for compiled stochastic helpers, the direct C++
  FFBS path, and dynamic/static MCMC workflows;
- targeted MCMC backend-routing and fast/strict parity tests;
- `R CMD build .`
- `R CMD check --as-cran exdqlm_1.1.2.tar.gz`

### R CMD check results

- Local `R CMD check --as-cran`: `Status: OK` (`0 errors | 0 warnings | 0 notes`).
- Local `R CMD check --as-cran` produced two informational entries only:
  1. the package specifies C++17;
  2. the installed package size is dominated by the compiled shared library.
- GitHub Actions matrix: passed on Ubuntu release, Ubuntu devel,
  Ubuntu oldrel-1, macOS release, and Windows release.
- Manual GitHub FFBS cross-OS diagnostic: passed on Ubuntu, macOS, and
  Windows; the comparison job confirmed identical fixed-seed FFBS/MCMC
  diagnostic output across the three operating systems.
- R-hub: passed on Linux R-devel and Windows R-devel.
- R-hub macOS ARM64 R-devel did not reach package checking. The job failed in
  `r-hub/actions/setup-deps@v1` before package installation/checking, and
  `r-hub/actions/run-check@v1` was skipped. The retry reproduced the same
  setup-stage failure; the package itself was not checked on that runner.

### Reverse dependencies

No reverse dependencies were found for `exdqlm` on CRAN under Depends, Imports,
LinkingTo, or Suggests.

### Notes for CRAN

1) Timing relative to version 1.1.1

- This update follows version 1.1.1 closely because the JSS replication audit
  identified an additional platform-specific fixed-seed reproducibility issue
  in the fast dynamic MCMC backend. The correction is narrowly scoped to the
  covariance square root used for stochastic FFBS state simulation.

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
