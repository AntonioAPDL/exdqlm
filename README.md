exdqlm — Extended Dynamic Quantile Linear Models
================

<!-- badges: start -->

[![R-CMD-check](https://github.com/AntonioAPDL/exdqlm/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/AntonioAPDL/exdqlm/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

`exdqlm` is a **Bayesian quantile-regression** package that combines
**dynamic state-space quantile models** with **static exAL regression**
under one API family. It is built for problems where quantiles, rather
than means, are the main object of interest, but the user still wants
familiar state-space/model-matrix inputs and explicit posterior
inference.

In **v0.4.0**, the package brings together the strongest parts of the
current development line:

- dynamic exDQLM inference via **LDVB** and **MCMC**, with legacy
  **ISVB** retained for backward compatibility and historical
  comparisons
- static Bayesian exAL regression via **LDVB** and **MCMC**
- modular model builders for **trend**, **seasonality**, and
  **regression** components
- reduced **AL/DQLM** paths through `dqlm.ind = TRUE` (dynamic and static),
  with a static convenience alias `al.ind = TRUE`
- standardized **VB trace diagnostics** at `fit$diagnostics$vb_trace`
  for ELBO, `sigma`, `gamma`, and convergence deltas
- static shrinkage priors `beta_prior = "ridge"`, `"rhs"`, and
  `"rhs_ns"`
- post hoc **posterior-predictive synthesis** via
  `quantileSynthesis()`

The most distinctive aspect of the package is the **feature bundle**:
native Bayesian dynamic quantile state-space modeling, static Bayesian
quantile regression, multiple inference engines, shrinkage priors for
static coefficients, and in-package post hoc synthesis across quantiles.

> **Terminology (exAL).** We use **exAL** for the extended Asymmetric
> Laplace family throughout this package. It generalizes the standard AL
> by adding a skewness parameter, allowing for asymmetric tails. The
> standard AL is a special case with zero skewness. We refer to the
> generalized AL from Kotz et al. as **Kotz-GAL** to avoid confusion.

## Installation

CRAN (when available):

``` r
install.packages("exdqlm")
```

Development (GitHub):

``` r
# install.packages("pak")
pak::pak("AntonioAPDL/exdqlm")
```

## Why `exdqlm` 0.4.0 is distinctive

- **Dynamic Bayesian quantile state-space modeling** is the core use
  case: `exdqlmLDVB()` is the main VB path, `exdqlmMCMC()` provides
  posterior simulation, and legacy `exdqlmISVB()` remains available for
  backward compatibility and historical comparisons.
- **Static Bayesian quantile regression** is now part of the same
  package via `exalStaticLDVB()` and `exalStaticMCMC()`, rather than
  living in a separate code path or companion repository.
- **Multiple inference engines** are available depending on the use
  case: deterministic Laplace-Delta VB (`LDVB`) as the main dynamic VB
  engine, posterior simulation (`MCMC`), and legacy fast approximate
  dynamic VB (`ISVB`) when older workflows need to be reproduced.
- **User-facing VB diagnostics are standardized** through
  `fit$diagnostics$vb_trace`, so plotting and monitoring code can use
  the same iteration-wise API across VB engines.
- **Static shrinkage priors** go beyond ridge: `rhs` and `rhs_ns`
  provide a horseshoe-family regularization story for sparse or weakly
  identified static coefficient problems.
- **Post hoc multi-quantile synthesis** is built in through
  `quantileSynthesis()`, which combines separately fitted quantile
  models into a unified posterior predictive distribution using
  isotonic correction and optional monotone rearrangement.

## Workflow map

| Goal | Main functions | Inference engines | Notes |
|---|---|---|---|
| Dynamic quantile state-space model | `exdqlmLDVB()`, `exdqlmMCMC()`, `exdqlmISVB()` | LDVB, MCMC, legacy ISVB | Main entry point for univariate time-series quantile modeling |
| Build state-space components | `polytrendMod()`, `seasMod()`, `regMod()` | n/a | Compose trend, seasonal, and regression blocks with `+.exdqlm` |
| Static Bayesian exAL regression | `exalStaticLDVB()`, `exalStaticMCMC()` | LDVB, MCMC | Supports `al.ind = TRUE` (alias of `dqlm.ind = TRUE`), posterior draws from either engine, and `ridge`, `rhs`, `rhs_ns` priors |
| Static regression block inside a dynamic model | `regMod()` | n/a | Adds fixed coefficients as a state-space component |
| Combine several separately fitted quantiles | `quantileSynthesis()` | post hoc synthesis | Builds a unified posterior predictive distribution using isotonic correction and optional rearrangement |

## Which engine should I use?

| Setting | Recommended start | Use when | Alternatives |
|---|---|---|---|
| Dynamic exDQLM | `exdqlmLDVB()` | You want the standard variational fit for dynamic exDQLM | `exdqlmMCMC()` or legacy `exdqlmISVB()` |
| Dynamic exDQLM with posterior sampling | `exdqlmMCMC()` | You want retained posterior draws and full simulation-based summaries | warm-start from VB if needed |
| Legacy dynamic exDQLM VB | `exdqlmISVB()` | You need backward-compatible behavior or historical comparisons | `exdqlmLDVB()` |
| Static exAL regression | `exalStaticLDVB()` | You want a fast Bayesian approximation, often useful before MCMC | `exalStaticMCMC()` |
| Static exAL regression with posterior draws | `exalStaticLDVB()` or `exalStaticMCMC()` | Use `exalStaticLDVB()` for a fast approximate draw-based summary and `exalStaticMCMC()` for the simulation baseline | `init.from.vb = TRUE` can help the MCMC fit |

## Default warmup behavior

The package now applies a **conservative automatic warmup profile** for
the most numerically delicate shared blocks, so ordinary users do not
have to assemble nested warmup lists just to get a stable first fit.

- `beta_prior = "rhs"` and `beta_prior = "rhs_ns"` keep the package's
  shared `tau` warmup schedule on by default.
- exAL VB entry points (`exalStaticLDVB()`, `exdqlmLDVB()`) apply a
  light automatic warmup for the `(sigma, gamma)` block.
- exAL MCMC entry points (`exalStaticMCMC()`, `exdqlmMCMC()`) apply a
  light automatic `(sigma, gamma)` warmup and keep VB warm starts
  available for the harder cases where they help.
- Advanced warmup control remains available through `vb_control` and
  `mcmc_control`, but those controls are now intended as the
  **override path**, not the default user workflow.

In practice, the recommended workflow is:

1. fit the model with the default API;
2. inspect diagnostics if the fit still looks unstable;
3. only then override the warmup controls explicitly.

## Quick start (≤ 10 lines)

Local-level model at a **single quantile** (the median) using the
package's main dynamic VB engine. We keep the **pure-R** path for
CRAN-style reproducibility and use the reduced DQLM path to keep the
example small.

``` r
set.seed(1)
library(exdqlm)

T      <- 120
state  <- cumsum(rnorm(T, sd = 0.2))
y      <- state + rnorm(T, sd = 1.0)

model  <- list(FF = matrix(1), GG = matrix(1), m0 = 0, C0 = 100)
options(exdqlm.use_cpp_kf = FALSE, exdqlm.use_cpp_samplers = FALSE)

fit <- exdqlmLDVB(
  y = y, p0 = 0.5, model = model, df = 0.98, dim.df = 1,
  dqlm.ind = TRUE, sig.init = 1.0
)

tail(fit$diagnostics$elbo, 3)
```

For plotting or monitoring VB convergence, use the standardized trace
table:

``` r
head(fit$diagnostics$vb_trace[, c("iter", "elbo", "sigma", "gamma")])
```

## Core concepts (at a glance)

- **State-space skeleton**: *design* (`FF`) and *evolution* (`GG`)
  matrices with a prior for the **state vector** (`m0`, `C0`).
- **Quantile of interest**: `p0` (e.g., `0.1`, `0.5`, `0.9`).
- **exAL errors**: controlled by **scale** and **skewness**; ordinary
  workflows should usually let LDVB/MCMC update them, while
  fixed-parameter paths remain available for explicit baseline or
  compatibility runs.
- **Discount factors**: `df` and `dim.df` control evolution per block
  (e.g., trend vs seasonality).
- **VB traces**: `fit$diagnostics$vb_trace` provides a standardized
  iteration-by-iteration table for ELBO, `sigma`, `gamma`, and
  convergence deltas across VB engines.
- **ELBO**: retained at `fit$diagnostics$elbo` and mirrored in
  `fit$diagnostics$vb_trace$elbo` (weakly monotone up to
  importance-sampling noise).

## What’s new in v0.4.0

- **Dynamic LDVB algorithm** via `exdqlmLDVB()` as the main VB routine
  for exDQLM fitting, with legacy `exdqlmISVB()` retained for backward
  compatibility.
- **Synthesis helper** `quantileSynthesis()` to combine
  posterior predictive draws from separately fitted quantile models.
- **Dynamic regression blocks** via `regMod()` and **static exAL regression**
  via `exalStaticLDVB()` and `exalStaticMCMC()`.
- **Reduced AL/DQLM paths** across dynamic and static APIs via
  `dqlm.ind = TRUE`, with `al.ind = TRUE` available as a static convenience alias.
- **Static shrinkage priors** in both static LDVB/MCMC via
  `beta_prior = "ridge"`, `"rhs"`, or `"rhs_ns"`.
- **Transfer-function helpers** `exdqlmTransferLDVB()` and
  `exdqlmTransferMCMC()`, with legacy `exdqlmTransferISVB()` retained for
  backward compatibility, plus expanded static object generics
  (`exalStaticMCMC`, `exalStaticLDVB`).
- **Standardized user-facing naming**: the primary API now uses
  `exalStatic...`, `exdqlmTransfer...`, and `quantileSynthesis()`,
  while documented legacy ISVB entry points remain available for
  backward-compatible workflows.
- **C++ backend controls** retained as optional: Kalman bridge default
  **TRUE**; builders, samplers, and post-predictive C++ paths default
  **FALSE**.
- **Standardized VB trace diagnostics** via `fit$diagnostics$vb_trace`,
  giving plot-ready iteration histories for ELBO, `sigma`, `gamma`, and
  convergence deltas across VB fits.

> For CI/CRAN-style runs, keep optional C++ builders/samplers/post-pred
> **FALSE** and set `exdqlm.use_cpp_kf = FALSE` for strict R-path
> reproducibility.

### Runtime options (summary)

| Option                    | Default | Effect                           | Use when…                                |
|---------------------------|:-------:|----------------------------------|------------------------------------------|
| `exdqlm.use_cpp_kf`       |  TRUE   | C++ Kalman filter bridge         | you have compilers/OpenMP and want speed |
| `exdqlm.use_cpp_builders` |  FALSE  | C++ matrix builders (`polytrendMod`, `seasMod`) | opt-in parity-tested builder speedups |
| `exdqlm.use_cpp_samplers` |  FALSE  | C++ samplers for posterior draws | same as above; keep OFF on CRAN/examples |
| `exdqlm.use_cpp_postpred` |  FALSE  | C++ posterior predictive sampler | optional speed path after parity checks  |
| `exdqlm.use_cpp_mcmc`     |  TRUE   | MCMC backend routing             | C++ FFBS by default for MCMC             |
| `exdqlm.cpp_mcmc_mode`    | `fast`  | MCMC mode (`strict`/`fast`)      | strict parity checks or fast C++ FFBS    |

Set with:

``` r
options(exdqlm.use_cpp_kf = TRUE)
options(exdqlm.use_cpp_builders = FALSE)
options(exdqlm.use_cpp_samplers = TRUE)
options(exdqlm.use_cpp_postpred = FALSE)
options(exdqlm.use_cpp_mcmc = TRUE)
options(exdqlm.cpp_mcmc_mode = "fast")
```

Backend control (minimal):
- Force pure-R backend: set `options(exdqlm.use_cpp_kf = FALSE, exdqlm.use_cpp_builders = FALSE)`.
- Keep builder calls explicit with `backend = "R"` or `backend = "cpp"` in `polytrendMod()` and `seasMod()`.

## Minimal examples (CRAN-safe)

### 1) Single-quantile fit on built-in data (tiny slice)

Trend + seasonality + one climate-index regressor. **Note**: `FF` for
the regressor is `1 × T`. Combine components **pairwise**.

``` r
data("BTflow", package = "exdqlm")
data("climateIndices", package = "exdqlm")

set.seed(2)
T <- 150
y <- log(BTflow[seq_len(T)])
bt_dates <- seq(as.Date("1987-01-01"), by = "month", length.out = T)
idx <- match(bt_dates, climateIndices$date)
x <- scale(climateIndices$noi[idx])[, 1]

trend.comp <- polytrendMod(order = 1, m0 = 0, C0 = 1)
seas.comp  <- seasMod(p = 12, h = 1, C0 = diag(1, 2))

# 1-d regressor block (explicit 1 x T design)
reg.comp <- list(m0 = 0, C0 = 1, FF = matrix(x, nrow = 1), GG = matrix(1))

# combine via +.exdqlm
reg.comp <- as.exdqlm(reg.comp)
model    <- trend.comp + seas.comp + reg.comp

# one discount per block: (trend, seasonal[2-d], reg)
df     <- c(1.00, 0.98, 1.00)
dim.df <- c(1,       2,   1)

options(exdqlm.use_cpp_kf = FALSE, exdqlm.use_cpp_samplers = FALSE)

fit <- exdqlmLDVB(
  y = y, p0 = 0.5, model = model,
  df = df, dim.df = dim.df,
  dqlm.ind = TRUE, sig.init = 0.2
)

# quick checks
tail(fit$diagnostics$elbo, 2)
dim(fit$theta.out$sm)  # state-dimension x time
```

### 2) exAL helper sanity check (CDF ↔ quantile)

``` r
set.seed(3)
x      <- seq(-2, 2, length.out = 5)
p0     <- 0.25
mu     <- 0
sigma  <- 1
gamma  <- 0.0

# CDF then invert with QF — should approximately return x
cdf_vals <- pexal(x,  p0 = p0, mu = mu, sigma = sigma, gamma = gamma)
x_back   <- qexal(cdf_vals, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)

round(cbind(x, x_back), 4)
#>       x x_back
#> [1,] -2     -2
#> [2,] -1     -1
#> [3,]  0      0
#> [4,]  1      1
#> [5,]  2      2

# A few random draws
rexal(5, p0 = p0, mu = mu, sigma = sigma, gamma = gamma)
#> [1] -0.5296664  5.4402490  0.7934288  0.4376783  2.5354967
```

> **CRAN-safety.** All examples set a seed, use tiny data, finish in a
> few seconds, and explicitly keep the pure-R path.

### 3) Static Bayesian regression with reduced AL and RHS-family priors

``` r
set.seed(4)
n <- 80
p <- 5
X <- matrix(rnorm(n * p), n, p)
beta <- c(1, -1, 0, 0, 0.5)
y <- as.numeric(X %*% beta + rnorm(n))

# Reduced AL fit (gamma fixed at zero)
fit_al <- exalStaticLDVB(
  y = y, X = X, p0 = 0.5,
  al.ind = TRUE,
  max_iter = 150, tol = 1e-4, verbose = FALSE
)

# exAL fit with regularized horseshoe prior on coefficients
fit_rhs <- exalStaticMCMC(
  y = y, X = X, p0 = 0.5,
  beta_prior = "rhs",
  n.burn = 200, n.mcmc = 200, thin = 1,
  mh.proposal = "slice",
  trace.diagnostics = FALSE,
  verbose = FALSE
)

# exAL fit with rhs_ns controls (same API family, additive option)
fit_rhs_ns <- exalStaticMCMC(
  y = y, X = X, p0 = 0.5,
  beta_prior = "rhs_ns",
  beta_prior_controls = list(
    tau0 = 0.5,
    a_zeta = 2,
    b_zeta = 1,
    shrink_intercept = FALSE
  ),
  n.burn = 200, n.mcmc = 200, thin = 1,
  mh.proposal = "slice",
  trace.diagnostics = FALSE,
  verbose = FALSE
)

fit_al$dqlm.ind
fit_rhs$beta_prior$type
fit_rhs_ns$beta_prior$type
```

### 4) Multi-quantile synthesis (conceptual sketch)

Fit several quantiles separately, then combine their posterior
predictive draws into a single unified posterior predictive
distribution.

``` r
p_grid <- c(0.1, 0.5, 0.9)
fits <- lapply(p_grid, function(tau) {
  exdqlmLDVB(
    y = y, p0 = tau, model = model,
    df = df, dim.df = dim.df,
    sig.init = 0.2, gam.init = 0
  )
})

draws <- lapply(fits, function(m) m$samp.post.pred)

syn <- quantileSynthesis(
  draws_list = draws,
  p = p_grid,
  T_expected = length(y)
)

names(syn)
```

## FAQ / Troubleshooting

- **It runs slowly.** Use short series (≤ 200), fix
  **scale**/**skewness**, and keep discount factors near but below one
  (≈ 0.96–0.99). Enable C++ bridges only if your toolchain supports
  them.

- **Which VB diagnostic object should I plot?** Start with
  `fit$diagnostics$vb_trace`. It provides one iteration-wise table
  across VB engines; use engine-specific internals only when you need
  lower-level block traces.

- **ELBO dips slightly—bug?** Small downward blips in
  `fit$diagnostics$vb_trace$elbo` are expected from importance-sampling
  noise. Look for an overall upward trend; if not, simplify the model or
  adjust variance/discounts.

- **OpenMP not available.** That’s fine. It is optional. Everything runs
  serially; examples here use the pure-R path.

- **Numerical stability tips.** Avoid extremely tight `C0`; start with
  moderate priors (e.g., `C0` around 1–100 for simple models), and fix
  **scale**/**skewness** for initial runs.

## How to cite

Barata, R., Prado, R., & Sansó, B. (2022). *Fast inference for
time-varying quantiles via flexible dynamic models with application to
the characterization of atmospheric rivers*. **Annals of Applied
Statistics**, 16(1), 247–271. <https://doi.org/10.1214/21-AOAS1497>

## License

MIT © The authors. See `LICENSE`.

## Getting help

Open an issue: <https://github.com/AntonioAPDL/exdqlm/issues>
