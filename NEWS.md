# exdqlm 0.4.0

## New
- `exdqlmLDVB`: Laplace–Delta variational Bayes routine for fast quantile
  state-space fitting under the extended asymmetric Laplace error distribution.
- ELBO diagnostics available during LDVB fitting (mirrors existing ISVB diagnostics).
- Optional C++ bridges remain available for Kalman filtering and sampling via
  runtime options; pure R paths preserved.

## Changes
- Documentation expanded for the new LDVB workflow and runtime options.
- Minor internal robustness tweaks around covariance handling and coercions.

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
- New AL/exAL helper functions with C++ backends:
  - `dexal()`, `pexal()`, `qexal()`, `rexal()`; `get_gamma_bounds()`.

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
