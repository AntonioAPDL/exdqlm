# MCMC C++ Gap Audit (branch `jaguir26/mcmc-cpp-gap-audit`)

## 1) Branch and sync status

- Base requested: `origin/cransub/0.4.0`
- Verified state before branching:
  - `git rev-list --left-right --count HEAD...origin/cransub/0.4.0` -> `0 0`
- Working branch created from synced head:
  - `jaguir26/mcmc-cpp-gap-audit`

## 2) Repo map (relevant to inference backends)

- Dynamic variational algorithms:
  - `R/exdqlmISVB.R`
  - `R/exdqlmLDVB.R`
- Dynamic MCMC algorithm:
  - `R/exdqlmMCMC.R`
- Static algorithms:
  - `R/exal_static_LDVB.R`
  - `R/exal_static_mcmc.R`
- C++ bridge and samplers:
  - `R/update_theta_bridge.R`
  - `src/kalman.cpp`
  - `src/sampling_utils.cpp`
  - `src/sampling_truncnorm.cpp`
  - `R/RcppExports.R`

## 3) What LDVB/ISVB already have in C++ (dynamic path)

- Optional C++ Kalman+smooth bridge is wired in both ISVB and LDVB:
  - `R/exdqlmISVB.R:438-450`
  - `R/exdqlmLDVB.R:556-568`
  - bridge wrapper: `R/update_theta_bridge.R:6-126`
  - C++ kernel: `src/kalman.cpp:167-360`
- Optional C++ post-fit samplers are wired for:
  - truncated normal `s_t`: `R/exdqlmISVB.R:646-657`, `R/exdqlmLDVB.R:755-766`
  - GIG `u_t` (when psi is constant): `R/exdqlmISVB.R:680-689`, `R/exdqlmLDVB.R:789-798`
  - posterior predictive sampler: `R/exdqlmISVB.R:722-736`, `R/exdqlmLDVB.R:833-847`
- Runtime options are already present:
  - `R/zzz.R:5-10`

Note: despite the option text saying samplers for `s_t`, `u_t`, `theta`, the current ISVB/LDVB code samples `theta` in R loops:
- `R/exdqlmISVB.R:691-701`
- `R/exdqlmLDVB.R:800-808`

## 4) MCMC implementations lacking C++ integration vs LDVB/ISVB

### 4.1 Dynamic `exdqlmMCMC` (exDQLM branch)

Completely R-only in current wiring (no `use_cpp` toggles, no bridge calls):

- FFBS smoother for map summaries:
  - `smoothed_theta`: `R/exdqlmMCMC.R:131-177`
- FFBS state sampling per iteration:
  - `ex_samp_theta`: `R/exdqlmMCMC.R:247-296`
- `u_t` sampler (R `GeneralizedHyperbolic::rgig`):
  - `R/exdqlmMCMC.R:299-302`
- `s_t` sampler (R `truncnorm::rtruncnorm`):
  - `R/exdqlmMCMC.R:305-309`
- joint MH for `(log sigma, logit gamma)`:
  - `R/exdqlmMCMC.R:312-336`
- chain loop:
  - `R/exdqlmMCMC.R:339-392`

### 4.2 Dynamic `exdqlmMCMC` (dQLM branch)

Also R-only:

- FFBS sampler:
  - `samp_theta`: `R/exdqlmMCMC.R:428-477`
- `u_t` sampler:
  - `R/exdqlmMCMC.R:480-483`
- sigma Gibbs update:
  - `R/exdqlmMCMC.R:486-489`
- chain loop:
  - `R/exdqlmMCMC.R:492-522`

### 4.3 Static `exal_static_mcmc`

Partially C++-accelerated, but not fully C++:

- Uses C++ for `v`, `s`, and `sigma` draws:
  - `R/exal_static_mcmc.R:212-214`
  - `R/exal_static_mcmc.R:222`
  - `R/exal_static_mcmc.R:241-243`
- Still R for:
  - beta Gaussian update: `R/exal_static_mcmc.R:224-235`
  - gamma Laplace-Delta step: `R/exal_static_mcmc.R:246-250`
- No backend option/fallback switch for static MCMC currently.

## 5) Existing C++ kernels that are available but currently unwired for MCMC

Exports exist (via `R/RcppExports.R`), but dynamic MCMC does not use them:

- `sample_multivariate_normal` (`src/sampling_utils.cpp:158-196`)
- `generate_samples` / `generate_samples_ext` (`src/sampling_utils.cpp:254-261`, `434-441`)
- `samp_post_pred` / `samp_post_pred_extended` (`src/sampling_utils.cpp:200-250`, `366-430`)

## 6) Critical blocker for “exact same behavior” parity: RNG semantics

If the requirement is exact reproducibility versus R scripts at fixed seed, current C++ RNG setup is not compatible:

- `sample_truncnorm` uses Boost RNG seeded from wall-clock or fixed 0, not R RNG stream:
  - `src/sampling_truncnorm.cpp:50-53`, `66`
- `sample_multivariate_normal` uses Boost RNG seeded by thread id / fixed 0:
  - `src/sampling_utils.cpp:166-167`, `181`
- `sample_gig_devroye_vector` uses `R::runif` inside OpenMP loops:
  - `src/sampling_utils.cpp:104-110` + `sample_gig_devroye` at `37-96`
  - this is not thread-safe/deterministic under parallel calls.

Conclusion: exact parity requires a dedicated deterministic mode with controlled RNG and threading.

## 7) What is needed for a high-quality C++ MCMC implementation

### 7.1 Backend contract and wiring

- Add explicit MCMC backend options (separate from LDVB/ISVB):
  - `exdqlm.use_cpp_mcmc` (default `FALSE` initially)
  - `exdqlm.cpp_mcmc_mode` in `{strict, fast}`
  - `exdqlm.cpp_threads` (default 1 for strict mode)
- Keep fail-safe behavior:
  - `auto` mode can fall back to R with warning
  - forced C++ mode should error on backend failure.

### 7.2 Kernel decomposition (incremental)

- Phase A: deterministic FFBS kernels in C++ for dynamic MCMC:
  - replace `smoothed_theta`, `ex_samp_theta`, `samp_theta`
  - reuse/update `update_theta_cpp` contract where possible
- Phase B: latent samplers (`u_t`, `s_t`) in strict-compatible mode:
  - either preserve R samplers, or implement C++ samplers driven by R RNG in serial
- Phase C: gamma/sigma block porting:
  - preserve exact transform/Jacobian and acceptance logic (`R/exdqlmMCMC.R:312-336`)
- Phase D: optional fast mode with OpenMP/specialized RNG, gated behind statistical (not bitwise) equivalence tests.

### 7.3 Exact parity mode requirements

- Single-thread execution (`OMP_NUM_THREADS=1`)
- Shared RNG stream semantics with R path (same draw order)
- Preserve update ordering and shape conventions exactly
- Preserve numerical linear algebra behavior (symmetrization/floors) where it affects acceptance decisions.

## 8) Test plan required before enabling any default switch

### 8.1 Strict parity tests (must pass first)

Add focused files:

- `tests/testthat/test-mcmc-dynamic-exdqlm-cpp-strict-parity.R`
- `tests/testthat/test-mcmc-dynamic-dqlm-cpp-strict-parity.R`
- `tests/testthat/test-mcmc-static-cpp-strict-parity.R`

Assertions under fixed seed and tiny chains:

- identical draw arrays where strict mode claims exact parity:
  - `samp.theta`, `samp.vts`, `samp.sts`, `samp.sigma`, `samp.gamma`, `samp.post.pred`
- identical diagnostics:
  - acceptance rate, `Sig.mh`, map forecast errors
- identical object structure/classes/dimensions.

### 8.2 Statistical parity tests (fast mode)

- Compare posterior summaries with tolerances:
  - means/SD/quantiles for key latent and parameter draws
  - state summaries (`theta.out$sm`, selected `sC` entries)
- Force single-thread for CRAN tests; keep any multi-thread stress tests out of CRAN path.

### 8.3 Reproducibility and safety tests

- repeated run with same seed and strict mode produces identical outputs
- fallback behavior tests:
  - C++ error path returns R results in auto mode
  - forced C++ mode errors clearly
- thread setting tests to prevent accidental nondeterministic strict mode.

## 9) Practical recommendation

- Immediate target: implement dynamic MCMC C++ FFBS backend first (largest gap vs LDVB/ISVB and largest runtime hotspot), behind a flag.
- Do not claim “exact same behavior” until strict RNG parity is formally established by tests.
- Keep default `exdqlm.use_cpp_mcmc = FALSE` until strict parity suite is green on Linux + macOS + Windows.
