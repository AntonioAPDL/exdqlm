## Test environments

* Local: AlmaLinux 8.10 (x86_64), R 4.4.0 — `R CMD check --as-cran`
* Win-builder: r-release and r-devel **submitted** on 2026-01-23 (results pending)
* R-hub: **not run** (no PAT available in this environment)

## R CMD check results

0 errors | 0 warnings | 2 notes (local)

## Notes for CRAN

* **Maintenance + internal performance** release; **no user-visible API changes**.
* Internal updates:
  * Optional **C++ Kalman filter bridge** and **optional** C++ sampling helpers.
  * Defaults preserve previous behavior (R implementations).
  * ELBO diagnostics added for ISVB.
* Build hygiene:
  * OpenMP is **optional** and properly guarded for platforms lacking `omp.h`.
  * `Makevars{,.win}` link to R’s BLAS/LAPACK and Fortran runtime via macros.
* Documentation & tests:
  * Runtime options documented in help; examples kept short.
* Reverse dependencies: none.

## Notes from local check

* Installed size NOTE (libs ~24.7 MB) due to compiled C++ backends.
* Non-portable compiler flags NOTE reflects the system toolchain defaults, not package Makevars.
