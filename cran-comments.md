## Test environments

* Local: Ubuntu 24.04, R 4.5.1 — `R CMD check --as-cran` (to be re-run before submission)
* win-builder: r-devel, r-release, r-oldrel — scheduled prior to submission
* R-hub (GitHub Actions): `linux`, `windows`, `macos-arm64` on R-devel — scheduled prior to submission

## R CMD check results

Local (Ubuntu 24.04, R 4.5.1): **0 errors | 0 warnings | 0 notes**.
Win-builder and R-hub runs will be confirmed before upload.

## Notes for CRAN

* **Feature** release introducing `exdqlmLDVB`, a Laplace–Delta variational Bayes
  routine for fast quantile state-space fitting with exALD errors.
* Backwards-compatible:
  * Existing functions keep previous behavior and interfaces.
  * Optional C++ bridges (Kalman filter / samplers) remain opt-in via
    runtime options; pure-R paths remain available.
* Diagnostics:
  * ELBO monitoring available; examples kept brief to meet CRAN time limits.
* Build hygiene:
  * OpenMP is **optional** and guarded; builds serially on platforms lacking `omp.h`.
  * `useDynLib(exdqlm, .registration = TRUE)` with registered routines.
* Reverse dependencies: none.
