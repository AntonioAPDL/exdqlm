# exdqlm 0.4.0 (development)

- Start LD (Laplace–Delta) VB workstream for (gamma, sigma).

# exdqlm 0.3.0

Major internal upgrade introducing optional C++ bridges and ELBO diagnostics.

- **C++ Kalman filter bridge** (parity with R path). New runtime option  
  `options(exdqlm.use_cpp_kf = TRUE)` switches to the C++ path (default remains R).
- **ELBO monitoring** for ISVB:
  - Adds θ-entropy from smoothed covariance and IS-based log-normalizer for the (σ, γ) block.
  - `fit$diagnostics$elbo` recorded per iteration; weakly monotone (up to IS noise).
- **Posterior sampling pipeline**:
  - Optional C++ samplers for θ (MVN), s_t (trunc-normal), and u_t (GIG, λ=1/2).
    Toggle via `options(exdqlm.use_cpp_samplers = TRUE)` (default FALSE).
  - Predictive draws keep the R/`brms::rasym_laplace()` path by default for parity.
- **Stability & hygiene**
  - Robust `log|Σ_t|` computation for `p=1` and array→matrix coercion fixes.
  - ASCII-only comments; numeric guards in examples/tests.
  - **OpenMP made optional** and gated, fixing macOS builds lacking `omp.h`.
- **Docs & tests**
  - Added smoke tests for ELBO monotonicity and KF parity (R vs C++).
  - Documented runtime options in `?exdqlmISVB`.

# exdqlm 0.1.5
<<<<<<< HEAD
- New AL/exAL helper functions with C++ backends:
  - `dexal()`, `pexal()`, `qexal()`, `rexal()`; `get_gamma_bounds()`.
=======

- New AL/exAL helper functions with C++ backends:
  - `dexal()`, `pexal()`, `qexal()`, `rexal()` for density, cdf, quantile and random generation.
  - `get_gamma_bounds()` to compute valid `(L, U)` bounds for `gamma` given `p0`.
- Implementation details:
  - Core numerics in C++ via Rcpp/RcppArmadillo and BH (Boost) for root-finding and Φ.
  - Parameter validation to keep `gamma` within bounds; clearer errors.
- Testing & docs:
  - Unit tests for pdf/cdf/quantile inverses and sampling sanity checks.
  - Package-level docs updated; **vignettes intentionally deferred** for a later release.
>>>>>>> origin/chore/exal-notation-0.2.0

# exdqlm 0.1.4
- CRAN hygiene & maintenance; examples/tests timing polish.

# exdqlm 0.1.3
- ‘dlm’ back on CRAN; fixes and utilities.

# exdqlm 0.1.2
- Forecast plotting fix; logic checks; input/output refinements; data updates.

# exdqlm 0.1.1
- Documentation and argument tweaks.

# exdqlm 0.1.0
- First release.
