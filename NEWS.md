# exdqlm 0.4.0

## New
- Consolidated CRAN release (updating CRAN 0.3.0) that bundles the internal
  0.4.0/0.5.0/0.6.0 feature line in one submission.
- `exdqlmLDVB`: Laplace-Delta variational Bayes routine for dynamic quantile
  state-space fitting under the extended asymmetric Laplace error distribution.
- Reduced-model controls for dynamic routines (`exdqlmISVB()`,
  `exdqlmLDVB()`, `exdqlmMCMC()`) through `dqlm.ind = TRUE`, fixing `gamma = 0`
  for AL/DQLM inference when desired.
- Added synthesis helper `exdqlm_synthesize_from_draws()` for combining
  posterior quantile-draw objects.
- Added static regression support with `regMod()` plus static exAL inference
  routines for VB/LDVB and MCMC workflows.
- Added static reduced AL support (`dqlm.ind = TRUE`) in
  `exal_static_LDVB()` and `exal_static_mcmc()`.
- Added static coefficient prior options for ridge and regularized horseshoe
  (`beta_prior = "ridge"` / `"rhs"`) in both static LDVB and static MCMC.
- Added `transfn_exdqlmLDVB()` for post-fit transformed summaries analogous to
  the ISVB path.
- Documentation updates for new APIs: explicit argument contracts (types/dims),
  return-value structure, and CRAN-safe examples aligned with existing package style.

## Fixes and clarifications
- Fixed R-path FFBS backward transition indexing to use `G_{t+1}` for parity
  with the C++ bridge and theory derivations.
- Fixed static MCMC `psi = 0` boundary behavior in exAL sigma updates to avoid
  unstable scale draws in reduced/near-reduced settings.
- Aligned static LDVB `(sigma, gamma)` transformed objective/entropy handling
  with the Jacobian contract used in the static theory reference.
- Clarified that C++ `elbo.part` in `kalman.cpp` is an internal diagnostic;
  package-level ELBO reporting remains R-level contract output.
- Added dedicated static-fit object generics for `exal_mcmc` and `exal_ldvb`
  and aligned post-fit compatibility for exdqlm classes.
- Replaced deprecated `arma::is_finite(...)` usage in FFBS C++ with
  `std::isfinite(...)` to eliminate compiler deprecation warnings.
- Optional C++ builder acceleration remains opt-in (`exdqlm.use_cpp_builders`
  default `FALSE`); no backend default flip in this release.
- Optional C++ post-predictive sampler remains opt-in
  (`exdqlm.use_cpp_postpred` default `FALSE`).

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
  - function exdqlmISVB() and (inherently) transfn_exdqlmISVB() now return objects of class 'exdqlmISVB'
  - function exdqlmMCMC() now returns objects of class 'exdqlmMCMC'
  - function exdqlmDiagnostics() now returns objects of class 'exdqlmDiagnostic'
  - function exdqlmForecast() now returns objects of class 'exdqlmForecast'
  - returns from exdqlmMCMC(), exdqlmISVB(), and transfn_exdqlmISVB() now include data (y)
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
  - kt added to transfn_exdqlmISVB return
- Dataset changes
  - Niño 3.4 dataset added
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
