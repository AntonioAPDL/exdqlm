## Test environments

* Local: AlmaLinux 8.10 (x86_64), R 4.4.0 — `R CMD check --as-cran`
* Win-builder: r-release and r-devel **submitted** on 2026-01-23 (results pending)
* R-hub (GitHub Actions):
  - linux (R-devel): **OK**
  - windows (R-devel): **OK**
  - macos-arm64 (R-devel): **ERROR** (see Notes below)
  - Run: https://github.com/AntonioAPDL/exdqlm/actions/runs/21305901121

## R CMD check results

0 errors | 0 warnings | 3 notes (local)

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
* “unable to verify current time” NOTE is an environment issue on the build host.
* Non-portable compiler flags NOTE reflects the system toolchain defaults, not package Makevars.

## R-hub macOS failure (R-devel)

macos-arm64 failed to compile with:
```
fatal error: 'R_ext/Callbacks.h' file not found
```
This appears to be a recent R-devel header change. To address it, we added a small compatibility header
`inst/include/R_ext/Callbacks.h` and updated `SystemRequirements` to `C++17`. A fresh R-hub run is pending.
