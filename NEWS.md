# exdqlm 0.3.0

Major internal upgrade with C++ Kalman bridge and ELBO diagnostics.

- **C++ Kalman filter bridge** (parity with R path). New runtime option
  `options(exdqlm.use_cpp_kf = TRUE)` (default via `.onLoad`) switches to the C++ path.
- **ELBO monitoring** for ISVB:
  - Adds θ-entropy from smoothed covariance and IS-based log-normalizer for the (σ, γ) block.
  - `fit$diagnostics$elbo` recorded each iteration; weakly monotone up to tiny IS noise.
- **Posterior sampling pipeline**:
  - Optional C++ samplers for θ (MVN), s_t (truncated normal), and u_t (GIG, λ=1/2).
    Toggle via `options(exdqlm.use_cpp_samplers = TRUE)` (default FALSE).
  - Predictive draws keep the R/`brms::rasym_laplace()` path by default for parity.
- **Stability & hygiene**
  - Robust `log|Σ_t|` computation for p=1 and array→matrix coercion.
  - ASCII-only comments (Greek symbols written as LaTeX names).
  - Internal bridges remain unexported.
- **Docs & tests**
  - Added smoke tests for ELBO monotonicity and KF parity (R vs C++).
  - Documented runtime options in `?exdqlmISVB`.

# exdqlm 0.1.5

- New AL/GAL helper functions with C++ backends:
  - `dexal()`, `pexal()`, `qexal()`, `rexal()` for density, cdf, quantile and random generation.
  - `get_gamma_bounds()` to compute valid `(L, U)` bounds for `gamma` given `p0`.
- Implementation details:
  - Core numerics in C++ via Rcpp/RcppArmadillo and BH (Boost) for root-finding and Φ.
  - Parameter validation to keep `gamma` within bounds; clearer errors.
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
