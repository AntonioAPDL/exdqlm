## Test environments

* Local: Ubuntu 24.04, R 4.5.1 — `R CMD check --as-cran`
* Win-builder: r-devel, r-release, r-oldrel — OK
* R-hub (GitHub Actions): `linux`, `windows`, `macos-arm64` on R-devel — OK

## R CMD check results

0 errors | 0 warnings | 0 notes (all platforms above)

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
