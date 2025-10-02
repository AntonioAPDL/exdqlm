## Test environments

* Local: Ubuntu 24.04, R 4.5.1 — `R CMD check --as-cran`
* Win-builder: R-devel, R-release — OK
* R-hub (GitHub Actions): linux, windows, macos-arm64 (R-devel) — OK

## R CMD check results

0 errors | 0 warnings | 0 notes (all environments above)

## Notes for CRAN

* **Feature** release introducing `exdqlmLDVB`, a Laplace–Delta variational Bayes
  routine for fast quantile state-space fitting with exALD errors.
* **Backwards-compatible**:
  * Existing functions keep previous behavior and interfaces.
  * Optional C++ bridges (Kalman filter / samplers) remain opt-in via runtime
    options; pure-R paths remain available.
* **Diagnostics & docs**:
  * ELBO monitoring available; examples kept brief to meet CRAN time limits.
* **Build hygiene**:
  * OpenMP is **optional** and properly guarded; builds serially on platforms
    lacking `omp.h`.
  * `useDynLib(exdqlm, .registration = TRUE)` with registered routines.
* Reverse dependencies: none.
