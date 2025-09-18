## Test environments

* **Local**: Ubuntu 24.04, R 4.5.1 — `R CMD check --as-cran`
* **Win-builder**: r-devel, r-release, r-oldrel — OK
* **R-hub (v2 / GitHub Actions)**: `linux`, `windows`, `macos-arm64` — OK

## R CMD check results

0 errors | 0 warnings | 0 notes (all platforms above)

## Notes for CRAN

* **Maintenance (hygiene) release**; **no user-visible API changes**.
* Internal performance work:

  * Added an **optional** C++ Kalman bridge and **optional** C++ samplers, controlled via runtime options.
  * Defaults preserve previous behavior for users; examples/tests stay fast and CRAN-friendly.
  * Added ELBO diagnostics; parity tests ensure R/C++ paths agree numerically.
* Housekeeping:

  * Removed non-ASCII in R sources and tightened numeric guards in examples/tests.
  * Cleaned package sources (no stray or hidden files in tarball).
* Documentation:

  * Clarified runtime options in help; examples kept short (under CRAN timing thresholds).
* **Reverse dependencies**: none.

