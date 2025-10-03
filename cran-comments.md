## Test environments

* Local: Ubuntu 24.04, R 4.5.1 — `R CMD check --as-cran`
* Win-builder: R-devel, R-release
* R-hub: linux, windows, macos-arm64 (R-devel)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes for CRAN

* Feature release adding posterior predictive synthesis across multiple quantile
  models via `exdqlm_synthesize_from_draws()`. The method performs isotonic
  adjustment, distributional alignment, piecewise-linear blending, and optional
  monotone rearrangement to ensure valid, monotone quantile functions.
* Backwards-compatible:
  * Existing functions keep previous behavior and interfaces.
  * Optional C++ bridges (Kalman filter / samplers) remain opt-in via runtime
    options; pure-R paths remain available.
* Diagnostics & docs:
  * Examples are short and CRAN-safe; unit tests avoid long runs.
* Build hygiene:
  * OpenMP is optional and properly guarded.
  * `useDynLib(exdqlm, .registration = TRUE)` with registered routines.
* Reverse dependencies: none.
