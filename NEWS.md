# exdqlm 1.0.0

## New and changed
- Changed the dynamic diagnostics CRPS calculation to use a finite integrated
  quantile-score approximation over posterior predictive empirical quantiles.
  The default grid is `seq(0.01, 0.99, by = 0.01)`, with optional user-supplied
  quantile levels and weights through `exdqlmDiagnostics()`.
- Added `exdqlmForecastDiagnostics()` for held-out `exdqlmForecast()` objects,
  reporting target-quantile check loss and CRPS from posterior predictive
  forecast draws without redefining article-side scoring helpers.
- Added optional plotting controls to `exdqlmPlot()` and `compPlot()`, including
  `plot = FALSE` summary extraction and user-supplied axis limits/labels, while
  preserving the existing plotting defaults.
- Added coefficient-interval summaries to `exalStaticDiagnostics()` objects and
  a `plot(..., type = "coefficients")` display for static LDVB/MCMC coefficient
  comparisons, with an optional `beta.ref` overlay for simulation benchmarks.
- Fixed `exdqlmForecast()` handling of future evolution matrices so constant
  `fGG` matrices expand across the forecast horizon and time-varying `fGG`
  arrays are validated against horizon `k`.
- Replaced the stochastic `FNN::KL.divergence()` dynamic diagnostic with a
  deterministic one-dimensional semiclosed KL normality diagnostic for MAP
  standardized forecast errors. The scalar `KL` is the primary user-facing
  calibration diagnostic, `KL (flipped)` is a secondary sensitivity diagnostic,
  and by-`k` sensitivity/Gaussian plug-in checks are stored under `kl.details`
  rather than as competing top-level KL fields.
- Corrected the dynamic diagnostic KL direction so `KL` now corresponds to the
  documented forecast-error-to-standard-normal diagnostic
  `KL(P_error || N(0,1))`; `KL (flipped)` reports the reverse direction.

# exdqlm 0.4.0

## New
- Consolidated CRAN release (updating CRAN 0.3.0) that bundles several internal
  development branches in one submission.
- `exdqlmLDVB`: Laplace-Delta variational Bayes routine for dynamic quantile
  state-space fitting under the extended asymmetric Laplace error distribution.
- Reduced-model controls for dynamic routines (`exdqlmISVB()`,
  `exdqlmLDVB()`, `exdqlmMCMC()`) through `dqlm.ind = TRUE`, fixing `gamma = 0`
  for AL/DQLM inference when desired.
- Added synthesis helper `quantileSynthesis()` for combining
  posterior quantile-draw objects.
- Added dynamic regression-block construction with `regMod()` and static exAL
  inference routines for VB/LDVB and MCMC workflows.
- Added static reduced AL support (`dqlm.ind = TRUE`) in
  `exalStaticLDVB()` and `exalStaticMCMC()`.
- Added static coefficient prior options for ridge and regularized horseshoe
  (`beta_prior = "ridge"` / `"rhs"`) in both static LDVB and static MCMC.
- Added additive static `rhs_ns` prior support for both static LDVB and static
  MCMC (`beta_prior = "rhs_ns"`), including slab-control aliases
  (`a_zeta`, `b_zeta`, `zeta2_fixed`) while preserving existing `rhs` and
  `ridge` behavior.
- Added `exdqlmTransferLDVB()` for post-fit transformed summaries analogous to
  the ISVB path.
- Added `exdqlmTransferMCMC()` for fixed-`lam` transfer-function exDQLM
  fitting under the dynamic MCMC workflow.
- Documentation updates for new APIs: explicit argument contracts (types/dims),
  return-value structure, and CRAN-safe examples aligned with existing package style.
- Standardized VB diagnostics traces across VB fits via
  `fit$diagnostics$vb_trace`, exposing iteration-wise ELBO, `sigma`,
  `gamma`, and convergence deltas in a plot-ready table while preserving the
  existing engine-specific diagnostics.
- Standardized the main user-facing naming scheme around `exalStatic...`,
  `exdqlmTransfer...`, and `quantileSynthesis()`, while retaining documented
  legacy ISVB entry points where needed for backward-compatible workflows.
- Added `climateIndices`, a documented monthly NOI/AMO climate-index data frame
  used for reproducible external-regressor examples.

## Fixes and clarifications
- Normalized the shared dynamic exDQLM VB policy around LDVB: `exdqlmLDVB()`
  and `exdqlmTransferLDVB()` are now the main VB entry points, while
  `exdqlmISVB()` and `exdqlmTransferISVB()` are documented as legacy
  compatibility paths.
- Added `al.ind` as a static-model convenience alias for `dqlm.ind` in
  `exalStaticLDVB()` and `exalStaticMCMC()`, with conflict checks when both
  flags are provided.
- Changed `fix.sigma` defaults from `TRUE` to `FALSE` for the shared dynamic
  exDQLM VB entry points and the reduced dynamic DQLM CAVI helper, while
  preserving explicit fixed-sigma workflows when users request them.
- Fixed R-path FFBS backward transition indexing to use `G_{t+1}` for parity
  with the C++ bridge and theory derivations.
- Fixed static MCMC `psi = 0` boundary behavior in exAL sigma updates to avoid
  unstable scale draws in reduced/near-reduced settings.
- Aligned static LDVB `(sigma, gamma)` transformed objective/entropy handling
  with the Jacobian contract used in the static theory reference.
- Corrected the positive-truncated-normal entropy sign used in exAL LDVB
  monitored ELBO diagnostics and centralized the shared entropy calculation.
- Clarified that C++ `elbo.part` in `kalman.cpp` is an internal diagnostic;
  package-level ELBO reporting remains R-level contract output.
- Added dedicated static-fit object generics for `exalStaticMCMC` and `exalStaticLDVB`
  and aligned post-fit compatibility for exdqlm classes.
- Replaced deprecated `arma::is_finite(...)` usage in FFBS C++ with
  `std::isfinite(...)` to eliminate compiler deprecation warnings.
- Optional C++ builder acceleration remains opt-in (`exdqlm.use_cpp_builders`
  default `FALSE`); no backend default flip in this release.
- Optional C++ post-predictive sampler remains opt-in
  (`exdqlm.use_cpp_postpred` default `FALSE`).
- Transfer-function wrappers now share the same augmentation helper and accept
  either one or two discount factors through `tf.df`.
- Shared entry points now apply a conservative automatic warmup baseline for
  the most failure-prone common blocks: RHS-family `tau` scheduling remains on
  by default, while exAL VB/MCMC entry points apply a light `(sigma, gamma)`
  warmup unless users explicitly override it through `vb_control` or
  `mcmc_control`.
- Streamlined default LDVB/MCMC console progress lines to prioritize run phase,
  iteration, keep counters, acceptance summaries, and runtime while leaving
  full `sigma`/`gamma` histories in diagnostics objects and callbacks.
- Clarified the `BTflow` dataset provenance as observed monthly USGS
  streamflow and removed the unused `BTprec` dataset from the package data API.
- Slimmed the shipped climate-index data API to the two manuscript predictors
  used in the Big Trees example.

# exdqlm 0.3.0

- **C++ bridge and optional samplers**
  - Optional C++ Kalman filter/smoother bridge and sampling kernels (theta, s_t, u_t).
  - Runtime toggles via `options(exdqlm.use_cpp_kf = TRUE)` and `options(exdqlm.use_cpp_samplers = TRUE)`.
  - Defaults preserve the R implementation for backward compatibility.

- **ELBO diagnostics and stopping**
  - New `diagnostics$elbo` recorded per ISVB iteration.
  - Optional ELBO-based stopping via `options(exdqlm.compute_elbo = TRUE)` and `options(exdqlm.tol_elbo = 1e-4)`.

- **Numerical robustness**
  - Stabilized log-determinant computations and truncated-normal entropy updates.
  - Guard rails for edge cases in intermediate calculations.

- **Build & hygiene**
  - OpenMP usage is optional and gated by compiler support.
  - Makevars link against R BLAS/LAPACK; internal headers centralized.

- **Docs & tests**
  - Runtime options documented; parity checks added for R vs C++ paths.

# exdqlm 0.2.0

- New AL/exAL helper functions with C++ backends:
  - `dexal()`, `pexal()`, `qexal()`, `rexal()` for density, cdf, quantile and random generation.
  - `get_gamma_bounds()` to compute valid `(L, U)` bounds for `gamma` given `p0`.
  - Implementation details:
    - Core numerics in C++ via Rcpp/RcppArmadillo and BH (Boost) for root-finding and Φ.
    - Parameter validation to keep `gamma` within bounds; clearer errors.
- Updated exdqlmISVB() and exdqlmMCMC() to use rexal()
- exdqlmChecks() renamed exdqlmDiagnostics()
- Improved the performance of plotting functions exdqlmPlot() and compPlot()
- Return changes
  - functions polytrendMod(), and seasMod() now return objects of class 'exdqlm'
  - function exdqlmISVB() and (inherently) exdqlmTransferISVB() now return objects of class 'exdqlmISVB'
  - function exdqlmMCMC() now returns objects of class 'exdqlmMCMC'
  - function exdqlmDiagnostics() now returns objects of class 'exdqlmDiagnostic'
  - function exdqlmForecast() now returns objects of class 'exdqlmForecast'
  - returns from exdqlmMCMC(), exdqlmISVB(), and exdqlmTransferISVB() now include data (y)
- Input changes
  - y removed from the inputs of exdqlmDiagnostics(), exdqlmForecast(), compPlot(), and exdqlmPlot()
- Added generics_etc.R which includes generics & other functions for the objects of class 'exdqlm', 'exdqlmISVB','exdqlmMCMC', 'exdqlmDiagnostic', & 'exdqlmForecast'
- Removed dlmMod.R and replaced with the more robust function as.exdqlm (in generics_etc.R), which creates 'exdqlm' objects
- Removed combineMods.R and replaced with addition for 'exdqlm' objects (in generics_etc.R)
- Testing & docs:
  - Unit tests for pdf/cdf/quantile inverses and sampling sanity checks.
  - Package-level docs updated; **vignettes intentionally deferred** for a later release.

# exdqlm 0.1.4

- CRAN hygiene & maintenance
  - Removed legacy `MD5` file; added ignore so it won’t be re-created in builds.
  - Dropped stray placeholder files (e.g., `.gitkeep`) from package sources.
  - Tidied DESCRIPTION (`Imports`/`LinkingTo` clarified; encoding/notes consistent).
  - Ensured no hidden or invalid files end up in the tarball.
- Examples & tests
  - Updated examples to keep `gamma` within valid bounds for the chosen `p0`.
  - Converted tests to use exported package functions (no ad-hoc `sourceCpp()`).
- Documentation
  - Minor clarifications and consistency fixes in Rd pages.

# exdqlm 0.1.3
- exdqlm 0.1.2 was archived on 2022-10-23 as requires archived package 'dlm'. 'dlm' now back on CRAN.
- Fixes and general improvements
  - changed if/class conditions in exdqlmISVB, exdqlmMCMC to is()
  - added the function is.exdqlm() to utils
  - changed if/class conditions in compPlot, exdqlmChecks, exdqlmForcast, exdqlmPlot to is.exdqlm()
  
# exdqlm 0.1.2
- Fixes and general improvements
  - fixed a bug in the forecast plotting routine
  - dqlm.ind = TRUE automatically sets gam.init = 0 & fix.gamma = TRUE (implemented in check_logics)
  - added a check that gam.init is in the appropriate range in exdqlmISVB and exdqlmMCMC
- Input changes
  - added parameter to specify the percentage of the CrIs in compPlot, exdqlmPlot and exdqlmForecast
- Return changes
  - kt added to exdqlmTransferISVB return
- Dataset changes
  - BTflow dataset updated
  - monELI dataset removed

# exdqlm 0.1.1
- Documentation updates
  - added author (year) to citation in descriptions
- Argument changes
  - added input verbose to the functions exdqlmISVB & exdqlmMCMC to allow users to suppress progress updates
- Return changes
  - functions exdqlmPlot and compPlot now return a list of the MAP & CrI estimates that are plotted

# exdqlm 0.1.0
- First release.
