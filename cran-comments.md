## exdqlm 0.4.0

### Release context

This submission updates CRAN 0.3.0 to exdqlm 0.4.0 and consolidates previously staged internal work into one CRAN submission:

- 0.4.0 line: LDVB integration and stability/diagnostic cleanup.
- 0.5.0 line: synthesis API (`exdqlm_synthesize_from_draws`).
- 0.6.0 internal line: static regression/regMod integration, plus targeted correctness fixes validated during consolidation.

No default backend flip was introduced in this consolidated 0.4.0 release:

- `exdqlm.use_cpp_builders` remains opt-in (`FALSE` by default).
- Existing R fallbacks remain available.

### Test environments

- Local: AlmaLinux 8.10 (x86_64), R 4.4.0 (2024-04-24).
- Local command used: `devtools::check(args = "--as-cran", cran = TRUE)`.

### R CMD check results

- `0 errors | 0 warnings | 3 notes`.

### Notes for CRAN

1) Installed size note

- Installed size is approximately `26.7 MB`, with `libs/` approximately `25.9 MB`.
- This package includes compiled C++ backends (Rcpp/RcppArmadillo), and the shared library is the dominant contributor.

2) Unable to verify current time

- This is an environment/time-sync note from the check host and is not caused by package code.

3) Non-portable compilation flags

- Reported flags:
  - `-Werror=format-security`
  - `-Wp,-D_FORTIFY_SOURCE=2`
  - `-Wp,-D_GLIBCXX_ASSERTIONS`
- These come from the system toolchain/hardening defaults on the check host, not from package `src/Makevars` custom non-portable flags.

### Win-builder / additional platform checks

Win-builder should be run by the submitting maintainer before final CRAN upload.

Recommended commands:

- `devtools::check_win_release()`
- `devtools::check_win_devel()`

Fill in prior to submission:

- win-builder r-release: `[PENDING / PASS / FAIL]`
- win-builder r-devel: `[PENDING / PASS / FAIL]`
- Additional notes (if any): `[ ... ]`
