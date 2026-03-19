## exdqlm 0.4.0

### Release context

This submission updates CRAN 0.3.0 to exdqlm 0.4.0 and consolidates
previously staged internal work into one CRAN submission:

- 0.4.0 line: LDVB integration and stability/diagnostic cleanup.
- 0.5.0 line: synthesis API (`exdqlm_synthesize_from_draws`).
- 0.6.0 internal line: static regression/regMod integration, reduced AL/DQLM
  paths, static RHS prior support, and targeted correctness fixes validated
  during consolidation.

This update intentionally excludes branch-local simulation/validation-study
artifacts; only package-facing API, documentation, and tests are included.

No default backend flip was introduced in this consolidated 0.4.0 release:

- `exdqlm.use_cpp_builders` remains opt-in (`FALSE` by default).
- Existing R fallbacks remain available.

### Test environments

- Local: AlmaLinux 8.10 (x86_64), R 4.4.0 (2024-04-24).
- Local commands used:
  - `Rscript -e 'testthat::test_local()'`
  - `R CMD check --no-manual exdqlm_0.4.0.tar.gz`

### R CMD check results

- `0 errors | 0 warnings | 1 note`.

### Notes for CRAN

1) Installed size note

- Installed size is approximately `30.1 MB`, with `libs/` approximately `29.0 MB`.
- This package includes compiled C++ backends (Rcpp/RcppArmadillo), and the shared library is the dominant contributor.

### Win-builder / additional platform checks

Win-builder should be run by the submitting maintainer before final CRAN upload.

Recommended commands:

- `devtools::check_win_release()`
- `devtools::check_win_devel()`

Fill in prior to submission:

- win-builder r-release: `[PENDING / PASS / FAIL]`
- win-builder r-devel: `[PENDING / PASS / FAIL]`
- Additional notes (if any): `[ ... ]`
