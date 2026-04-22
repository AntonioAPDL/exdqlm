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

- dynamic exDQLM inference via **ISVB**, **LDVB**, and **MCMC**
- static Bayesian exAL regression via **LDVB** and **MCMC**
- modular model builders for **trend**, **seasonality**, and
  **regression** components
- reduced **AL/DQLM** paths through `dqlm.ind = TRUE`
- static shrinkage priors `beta_prior = "ridge"`, `"rhs"`, and
  `"rhs_ns"`
- posterior predictive **non-crossing synthesis** via
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
  case: `exdqlmISVB()`, `exdqlmLDVB()`, and `exdqlmMCMC()` all fit
  univariate time-series quantile models with a familiar DLM/state-space
  specification.
- **Static Bayesian quantile regression** is now part of the same
  package via `exalStaticLDVB()` and `exalStaticMCMC()`, rather than
  living in a separate code path or companion repository.
- **Multiple inference engines** are available depending on the use
  case: fast approximate dynamic VB (`ISVB`), deterministic
  Laplace-Delta VB (`LDVB`), and posterior simulation (`MCMC`).
- **Static shrinkage priors** go beyond ridge: `rhs` and `rhs_ns`
  provide a horseshoe-family regularization story for sparse or weakly
  identified static coefficient problems.
- **Post hoc multi-quantile synthesis** is built in through
  `quantileSynthesis()`, which can enforce isotonicity and apply
  monotone rearrangement after fitting quantiles separately.

## Workflow map

| Goal | Main functions | Inference engines | Notes |
|---|---|---|---|
| Dynamic quantile state-space model | `exdqlmISVB()`, `exdqlmLDVB()`, `exdqlmMCMC()` | ISVB, LDVB, MCMC | Main entry point for univariate time-series quantile modeling |
| Build state-space components | `polytrendMod()`, `seasMod()`, `regMod()` | n/a | Compose trend, seasonal, and regression blocks with `+.exdqlm` |
| Static Bayesian exAL regression | `exalStaticLDVB()`, `exalStaticMCMC()` | LDVB, MCMC | Supports `dqlm.ind = TRUE`, posterior draws from either engine, and `ridge`, `rhs`, `rhs_ns` priors |
| Static regression block inside a dynamic model | `regMod()` | n/a | Adds fixed coefficients as a state-space component |
| Combine several separately fitted quantiles | `quantileSynthesis()` | post hoc synthesis | Isotonic correction plus optional rearrangement for non-crossing output |

## Which engine should I use?

| Setting | Recommended start | Use when | Alternatives |
|---|---|---|---|
| Dynamic exDQLM | `exdqlmISVB()` | You want a fast first fit or a stable working approximation | `exdqlmLDVB()` or `exdqlmMCMC()` |
| Dynamic exDQLM with deterministic VB | `exdqlmLDVB()` | You want a variational fit without IS noise in the `(\sigma,\gamma)` block | `exdqlmISVB()` |
| Dynamic exDQLM with posterior sampling | `exdqlmMCMC()` | You want retained posterior draws and full simulation-based summaries | warm-start from VB if needed |
| Static exAL regression | `exalStaticLDVB()` | You want a fast Bayesian approximation, often useful before MCMC | `exalStaticMCMC()` |
| Static exAL regression with posterior draws | `exalStaticLDVB()` or `exalStaticMCMC()` | Use `exalStaticLDVB()` for a fast approximate draw-based summary and `exalStaticMCMC()` for the simulation baseline | `init.from.vb = TRUE` can help the MCMC fit |

## Precision-stabilized MCMC readouts

For hard ridge-style MCMC readouts, the package now supports a user-facing
`precision_beta` control block for the Gaussian beta draw:

- `"ladder_v2"` is the recommended repair preset.
- `"eigen_v1"` is the stronger fallback when the ladder alone is not enough.
- full custom control is still available through
  `exal_make_precision_beta_control()`.

```r
fit <- qdesn_fit_mcmc(
  y = y,
  p0 = 0.5,
  mcmc_args = list(
    likelihood_family = "exal",
    precision_beta = "ladder_v2"
  )
)

fit_hard <- qdesn_fit_mcmc(
  y = y,
  p0 = 0.5,
  mcmc_args = list(
    likelihood_family = "exal",
    precision_beta = exal_make_precision_beta_control("eigen_v1")
  )
)
```

## Quick start (≤ 10 lines)

Local-level model at a **single quantile** (the median). We fix
**scale** and **skewness** to keep it fast and stable for CRAN; we keep
the **pure-R** path.

``` r
set.seed(1)
library(exdqlm)

T      <- 120
state  <- cumsum(rnorm(T, sd = 0.2))
y      <- state + rnorm(T, sd = 1.0)

model  <- list(FF = matrix(1), GG = matrix(1), m0 = 0, C0 = 100)
options(exdqlm.use_cpp_kf = FALSE, exdqlm.use_cpp_samplers = FALSE)

fit <- exdqlmISVB(
  y = y, p0 = 0.5, model = model, df = 0.98, dim.df = 1,
  fix.sigma = TRUE, sig.init = 1.0,
  fix.gamma = TRUE, gam.init = 0.0
)
#> ISVB converged: 2 iterations, 0.514 seconds

tail(fit$diagnostics$elbo, 3)
#> [1] -113.62048  -67.45699
```

## Core concepts (at a glance)

- **State-space skeleton**: *design* (`FF`) and *evolution* (`GG`)
  matrices with a prior for the **state vector** (`m0`, `C0`).
- **Quantile of interest**: `p0` (e.g., `0.1`, `0.5`, `0.9`).
- **exAL errors**: controlled by **scale** and **skewness**; fixing them
  often stabilizes small examples.
- **Discount factors**: `df` and `dim.df` control evolution per block
  (e.g., trend vs seasonality).
- **ELBO**: recorded at `fit$diagnostics$elbo` (weakly monotone up to
  importance-sampling noise).

## What’s new in v0.4.0

- **Dynamic LDVB algorithm** via `exdqlmLDVB()` for exDQLM fitting.
- **Synthesis helper** `quantileSynthesis()` to combine posterior
  quantile-draw objects.
- **Static regression support** via `regMod()`, `exalStaticLDVB()`, and
  `exalStaticMCMC()`.
- **Reduced AL/DQLM paths** across dynamic and static APIs via
  `dqlm.ind = TRUE`.
- **Static shrinkage priors** in both static LDVB/MCMC via
  `beta_prior = "ridge"`, `"rhs"`, or `"rhs_ns"`.
- **Transfer-function helpers** `exdqlmTransferLDVB()`,
  `exdqlmTransferMCMC()`, and `exdqlmTransferISVB()`, plus native static
  object generics (`exalStaticMCMC`, `exalStaticLDVB`).
- **C++ backend controls** retained as optional: Kalman bridge default
  **TRUE**; builders, samplers, and post-predictive C++ paths default
  **FALSE**.
- **ELBO diagnostics** retained for iterative monitoring.

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

Trend + seasonality + one regressor (`nino34`). **Note**: `FF` for the
regressor is `1 × T`. Combine components **pairwise**.

``` r
set.seed(2)
T <- 150
y <- log(BTflow[seq_len(T)])
x <- nino34[seq_len(T)]

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

fit <- exdqlmISVB(
  y = y, p0 = 0.5, model = model,
  df = df, dim.df = dim.df,
  fix.sigma = TRUE, sig.init = 0.2,
  fix.gamma = TRUE, gam.init = 0.0
)
#> ISVB converged: 2 iterations, 0.547 seconds

# quick checks
tail(fit$diagnostics$elbo, 2)
#> [1] -1078.8072  -934.9032
dim(fit$theta.out$sm)  # state-dimension x time
#> [1]   4 150
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
  dqlm.ind = TRUE,
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
predictive draws into a single non-crossing predictive object.

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

- **ELBO dips slightly—bug?** Small downward blips are expected from
  importance-sampling noise. Look for an overall upward trend; if not,
  simplify the model or adjust variance/discounts.

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
