exdqlm — Extended Dynamic Quantile Linear Models
================

``` r
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.path = "man/figures/README-",
  out.width = "100%"
)
```

<!-- badges: start -->

[![R-CMD-check](https://github.com/AntonioAPDL/exdqlm/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/AntonioAPDL/exdqlm/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

`exdqlm` provides Bayesian **dynamic quantile** state-space models built
on the **extended Asymmetric Laplace** error family. It targets applied
time-series problems where you need conditional quantiles across time,
not only conditional means. Models are expressed in standard state-space
form (design and evolution matrices with a state vector), and estimation
uses routines tailored to quantiles. **v0.3.0** adds **optional C++
bridges** for speed (Kalman filter and samplers) and **ELBO monitoring**
for the variational path—defaults remain the pure-R implementations for
portability.

> **Terminology (exAL)** We use **exAL** for the extended Asymmetric
> Laplace family throughout this package. It generalizes the standard AL
> by adding a skewness parameter, allowing for asymmetric tails. The
> standard AL is a special case with zero skewness.

------------------------------------------------------------------------

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

------------------------------------------------------------------------

## What’s new in v0.3.0

**Major internal upgrade introducing optional C++ bridges and ELBO
diagnostics.**

- **C++ Kalman filter bridge** (parity with the pure-R path). Toggle
  with `options(exdqlm.use_cpp_kf = TRUE)` (default **FALSE**).
- **ELBO monitoring** for the IS-VB routine: per-iteration values
  recorded at `fit$diagnostics$elbo` (weakly monotone up to IS noise).
- **Optional C++ samplers** for posterior draws: multivariate-normal for
  the state vector, truncated-normal for latent scales, and GIG with
  index 1/2 for augmentation. Toggle with
  `options(exdqlm.use_cpp_samplers = TRUE)` (default **FALSE**).
- **Portability**: OpenMP is **optional and gated**; builds cleanly
  without it (e.g., macOS CRAN machines).

------------------------------------------------------------------------

## Runtime options (default off)

- `options(exdqlm.use_cpp_kf = TRUE)` — use the C++ Kalman filter
  bridge.
- `options(exdqlm.use_cpp_samplers = TRUE)` — use the C++ samplers for
  posterior draws.

> Keep both **FALSE** in examples and CI. They are drop-in accelerators
> when your toolchain supports them.

------------------------------------------------------------------------

## Minimal examples (CRAN-safe)

All examples set a seed, use small series, and stick to pure-R code
paths.

### 1) Quick single-quantile IS-VB fit (tiny built-in series)

We use a simple trend + seasonal + one regressor model on a short slice
of built-in data. Note: we **fix** the scale and skewness to keep this
fast and stable.

``` r
set.seed(1)
library(exdqlm)

# tiny slice for speed
T <- 150
y <- log(BTflow[seq_len(T)])
x <- nino34[seq_len(T)]

# components
trend.comp <- polytrendMod(order = 1, m0 = 0, C0 = 1)
seas.comp  <- seasMod(p = 12, h = 1, C0 = diag(1, 2))
reg.comp   <- list(m0 = 0, C0 = 1, FF = matrix(x, nrow = 1), GG = 1)

model <- combineMods(trend.comp, seas.comp, reg.comp)

# one discount per block: (trend, seasonal(2-dim), reg)
df     <- c(1.00, 0.98, 1.00)
dim.df <- c(1,       2,   1)

# IMPORTANT: keep C++ bridges OFF in examples
options(exdqlm.use_cpp_kf = FALSE, exdqlm.use_cpp_samplers = FALSE)

fit <- exdqlmISVB(
  y        = y,
  p0       = 0.5,      # median
  model    = model,
  df       = df,
  dim.df   = dim.df,
  fix.sigma = TRUE,  sig.init = 0.2,  # fixed scale
  fix.gamma = TRUE,  gam.init = 0.0,  # fixed skewness (symmetric)
  verbose   = FALSE
)

# quick diagnostics
tail(fit$diagnostics$elbo, 3)
dim(fit$theta.out$sm)  # state-dimension x time
```

### 2) exAL helpers sanity check (density ↔ quantile)

These helpers are convenient for quick unit checks.

``` r
set.seed(2)

x  <- seq(-2, 2, length.out = 5)
p0 <- 0.25
loc <- 0; sc <- 1; sk <- 0.0

# CDF then invert with QF — should approximately return x
cdf_vals <- pexal(x,  p0 = p0, location = loc, scale = sc, skewness = sk)
x_back   <- qexal(cdf_vals, p0 = p0, location = loc, scale = sc, skewness = sk)

round(cbind(x, x_back), 4)
rexal(5, p0 = p0, location = loc, scale = sc, skewness = sk)
```

> **Tip:** To experiment with the C++ bridges locally (not for CRAN):
>
> ``` r
> options(exdqlm.use_cpp_kf = TRUE)
> options(exdqlm.use_cpp_samplers = TRUE)
> ```
>
> If compiled code or OpenMP are unavailable, the package falls back to
> the pure-R path.

------------------------------------------------------------------------

## FAQ / Troubleshooting

- **Runs are slow on my laptop. What can I do?** Start with short series
  (≤ 200), keep the scale and skewness fixed, and reduce iteration caps
  where available. When your toolchain supports it, enable the C++
  bridges via the runtime options above.

- **OpenMP is not available on my platform.** That’s fine. OpenMP is
  optional. The package compiles and runs serially; the examples here
  use the pure-R path.

- **ELBO is not perfectly increasing. Is that a bug?** Minor dips can
  occur from importance-sampling noise in the ELBO estimate. Look for
  overall upward trend; if not, reduce noise or simplify the model.

- **Numerical stability tips** Use reasonable priors (e.g., not too
  small initial state variance), set discount factors near but below one
  (e.g., 0.96–0.99), and consider fixing the scale and skewness on first
  passes.

------------------------------------------------------------------------

## How to cite

Barata, R., Prado, R., & Sansó, B. (2022). *Fast inference for
time-varying quantiles via flexible dynamic models with application to
the characterization of atmospheric rivers*. **Annals of Applied
Statistics**, 16(1), 247–271. <https://doi.org/10.1214/21-AOAS1497>

------------------------------------------------------------------------

## License

MIT © The authors. See `LICENSE`.

------------------------------------------------------------------------

## Acknowledgments

Optional C++ components use Rcpp/RcppArmadillo/BH backends. Thanks to
contributors and testers who helped validate parity between the R and
C++ paths.

------------------------------------------------------------------------
