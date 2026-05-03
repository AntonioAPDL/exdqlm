## exdqlm 0.4.0

### Release context

This submission updates CRAN 0.3.0 to exdqlm 0.4.0 and consolidates
previously staged internal work into one CRAN submission:

- 0.4.0 line: LDVB integration and stability/diagnostic cleanup.
- 0.5.0 line: synthesis API (`quantileSynthesis`).
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
  - `Rscript -e 'Sys.setenv(NOT_CRAN="true"); testthat::test_local(reporter = "summary")'`
  - `Rscript -e 'rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "never")'`

### R CMD check results

- `0 errors | 0 warnings | 4 notes`.

### Notes for CRAN

1) Installed size note

- Installed size is approximately `30.8 MB`, with `libs/` approximately `29.0 MB`.
- This package includes compiled C++ backends (Rcpp/RcppArmadillo), and the shared library is the dominant contributor.

2) Future timestamp note

- The local AlmaLinux check reported `unable to verify current time`.
- This appears to be a local system-time verification limitation rather than a package timestamp issue.

3) README/NEWS pandoc note

- The local check host does not have `pandoc`, so `README.md` and `NEWS.md`
  could not be checked locally by `R CMD check`.
- The package does not include built vignettes in this release.

4) Compiler hardening flag note

- The local AlmaLinux toolchain reported non-portable compiler hardening flags
  (`-Werror=format-security`, `_FORTIFY_SOURCE`, and `_GLIBCXX_ASSERTIONS`).
- These flags are injected by the platform compiler configuration, not by the
  package Makevars.

### Win-builder / additional platform checks

- win-builder r-release: `0 errors | 0 warnings | 1 note`
- win-builder r-devel: `0 errors | 0 warnings | 1 note`
- Note: `Possibly misspelled words in DESCRIPTION: 
  DQLM (21:46)
  ISVB (20:49)
  LDVB (20:26, 21:20)
  exAL (18:6, 20:66)
  exDQLMs (19:37)` 
  All acronyms listed are specific to the models implemented in our package. Spelling was double checked and is correct.
