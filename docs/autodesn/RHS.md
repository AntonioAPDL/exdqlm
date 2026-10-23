# AutoDESN with a normalized regularized horseshoe readout

AutoDESN supports two readout priors through the same fit and forecast API.
`beta_prior = "ridge"` remains the default. `beta_prior = "rhs"` uses the
normalized Piironen–Vehtari regularized horseshoe. Reservoir construction,
causal feature rows, architecture priors, response scaling, and recursive
forecasting are shared. The existing AL/exAL `rhs_ns` model is a different
prior and is not an alias for this one.

## Use the same bank for both priors

```r
library(exdqlm)

specs <- autodesn_candidates(
  D = c(1L, 2L), n = 12L, m = c(1L, 4L),
  alpha = 0.5, rho = 0.8, seed = c(11L, 29L)
)
bank <- autodesn_build_bank(y, specs, conditioning = 30L)

ridge <- autodesn_fit_bank(
  bank, beta_prior = "ridge", n_burn = 1500L, n_mcmc = 3000L, seed = 101L
)
rhs <- autodesn_fit_bank(
  bank, beta_prior = "rhs",
  rhs_control = autodesn_rhs_control(tau0 = 1, slab_scale = 2, slab_df = 4),
  model_control = list(method = "mh", moves = 2L),
  backend = "auto", n_burn = 1500L, n_mcmc = 3000L, seed = 101L
)
fc <- forecast_paths.autodesn_fit(
  rhs, H = 30L, nd = 192L, inner_paths = 8L, backend = "batched", seed = 52L
)
predictive_intervals <- apply(fc$yrep, 1L, quantile, c(.05, .5, .95))
```

These iteration counts illustrate the API; convergence must be assessed for
the fitted bank. Build the bank once and run independently initialized chains.
The series facade accepts the same prior controls as top-level arguments:

```r
rhs <- autodesn_fit(
  y, candidates = specs, conditioning = 30L, beta_prior = "rhs",
  rhs_control = list(tau0 = 1, slab_scale = 2),
  model_control = list(method = "mh", moves = 2L),
  mcmc_args = list(n_burn = 1500L, n_mcmc = 3000L, seed = 101L)
)
```

`mcmc_args` contains common run controls, observation-variance controls, and
the intercept prior. Set `beta_prior`, `rhs_control`, `model_control`, and
`backend` at the facade's top level. Unknown controls fail explicitly. Passing
ridge-only hyperparameters to an RHS fit also fails, preventing an apparently
successful run that silently ignores the requested prior.

## Statistical target

For model $m$, the existing feature convention is
$F_m=H_m/\sqrt{d_m}$, $X_m=[\mathbf 1,F_m]$, unless feature normalization is
explicitly disabled when building the bank. The response likelihood is

$$
y\mid m,\beta_m,s^2\sim N(X_m\beta_m,s^2I),\qquad
s^2\sim\operatorname{IG}(a_\sigma,b_\sigma).
$$

The intercept has its own proper prior
$\beta_{m0}\sim N(0,v_0)$ with default $v_0=10$. For slopes,

$$
u\sim C^+(0,1),\quad \tau_m=\tau_{0m}u,\quad
\lambda_j\sim C^+(0,1),\quad
c^2\sim\operatorname{IG}\left(\frac{\nu}{2},\frac{\nu s_c^2}{2}\right),
$$

$$
v_{mj}=\left(\frac{1}{c^2}+\frac{1}{\tau_m^2\lambda_j^2}\right)^{-1},
\qquad \beta_{mj}\mid u,\lambda_j,c^2,m\sim N(0,v_{mj}).
$$

Here `tau0` is $\tau_{0m}$, `slab_scale` is $s_c$, and `slab_df` is $\nu$.
The default values are 1, 2, and 4. Inverse-gamma uses shape and inverse-scale
rate: its density is proportional to $x^{-a-1}\exp(-b/x)$.

All coefficient priors are independent of observation variance. In particular,
the variance update has shape $a_\sigma+n/2$, without a coefficient-dimension
term. The small-value shrinkage scale is $\tau_m\lambda_j$; large local scales
approach the finite slab variance $c^2$. The intercept is outside this shrinkage
hierarchy.

The normalized Gaussian slope density includes
$\prod_j v_{mj}^{-1/2}$. Omitting it changes both scale conditionals and
architecture probabilities. This implementation keeps that factor throughout.
It does not substitute a product of unnormalized Gaussian penalties or reuse
variational model scores.

`tau0` may be a scalar or one positive value per bank candidate. Its units refer
to coefficients multiplying the actual normalized features. A global-scale
heuristic derived for unit-variance columns must be adjusted before applying it
to $H_m/\sqrt{d_m}$. No sampled residual standard deviation is automatically
inserted into `tau0`; doing so would define a different prior. Choose these
settings using prior knowledge or training data, then freeze them before the
held-out comparison.

## Architecture moves and coefficient updates

Conditional on scales, set $D_m=\operatorname{diag}(v_0,v_{m1},\ldots,v_{md_m})$.
Integrating coefficients gives the exact conditional score

$$
\ell_m=-\tfrac12\left[n\log(2\pi)+\log|C_m|+y^TC_m^{-1}y\right],
\qquad C_m=s^2I+X_mD_mX_m^T.
$$

This is the integral of the causal conditional training likelihood. It does
not assert an unconditional multivariate Gaussian law for the autoregressive
series. Scale uncertainty remains sampled, so finite-chain model weights are
Monte Carlo estimates.

RHS is sensitive to the coefficient basis. The engine retains the original
reservoir columns and caches their crossproducts. It factors
$I+D_m^{1/2}X_m^TX_mD_m^{1/2}/s^2$ for stable coefficient integration and
Gaussian draws. It never rotates the features into ridge SVD coordinates.

The sampler uses a common auxiliary vector of $d_{\max}$ local scales. A model
with $d_m$ slopes uses its first $d_m$ entries. Inactive entries have proper
half-Cauchy priors and are refreshed from those priors. Integrating them gives
one, so this computational coupling preserves every model's intended prior
and introduces no dimension-dependent evidence factor.

With `method = "mh"`, a full-support independence proposal $q(m')$ gives

$$
\alpha=\min\left\{1,
\frac{p(m')e^{\ell_{m'}}q(m)}{p(m)e^{\ell_m}q(m')}
\right\}.
$$

The default proposal equals the bank prior. `moves` controls the number of
model moves per sweep. With `method = "categorical"`, each sweep evaluates
the entire bank and samples its full conditional distribution; this is useful
as a reference for small banks. Either choice is followed **immediately** by a
Gaussian coefficient redraw in the selected dimension. The previous model's
coefficient vector is never used with the new architecture.

After that joint update, the sampler updates observation variance, active local
scales and their auxiliaries, inactive auxiliaries, global scale, and slab
variance. Local scales use an exact two-component inverse-gamma rejection
sampler whose proposal acceptance is at least $1/\sqrt{2}$. Global and slab
updates use unbounded log-coordinate slice sampling, including transformation
Jacobians. Numerical budgets raise an error if exhausted. They do not truncate
the prior or silently retain a failed draw.

## Controls and output

| Control | Meaning |
|---|---|
| `backend = "auto"` | Use native kernels when loaded; otherwise use the R reference. The actual choice is recorded in `fit$controls$backend`. |
| `backend = "cpp"` | Require native kernels; fail if unavailable. |
| `backend = "R"` | Use the R reference implementation; lowercase `"r"` is accepted. |
| `model_control$proposal` | Positive mass on every candidate, normalized internally. A frozen training-only pilot may inform a proposal without changing the target. |
| `model_control$rb_every` | Optional full-bank Rao–Blackwell scan every specified number of retained draws; zero disables it. |
| `model_control$initial_model` | Starting candidate index, useful for dispersed chains. |
| `learn_global`, `learn_slab` | Sample these scales, or hold their initial values fixed. |
| `initial_global`, `initial_slab` | Starting $u$ and $c^2$; also fixed values when learning is disabled. |
| `fixed_local_scales` | Optional fixed $\lambda$ values, scalar or length $d_{\max}$, useful for reference problems. |
| `save_local` | Store active local scales and their logs for every retained draw; disabled by default to limit memory. |

Each retained draw stores its model, observation variance, matching coefficient
vector, global and slab scales, intercept, fitted RMS, and diagnostic scale
summaries. `effective_slopes_diagonal` is a diagonal-design shrinkage summary,
not an exact effective degrees-of-freedom formula for correlated columns.
`mean_log_local` averages the common auxiliary vector, including inactive
entries, so it remains defined when a model has no slopes.

For MH, `model_summary$posterior_probability` is sampled occupancy and
`conditional_probabilities` is `NULL`. Optional full scans are stored separately
as `rb_probabilities` with `rb_iterations`; their averages have their own
`rao_blackwell_probability` column. For categorical sampling, the main estimate
averages the full conditional probabilities. These probabilities belong to the
model-update substep, before the stored end-of-sweep scale updates.

`sampler_stats` records model proposals, acceptances and transitions, Gaussian
evaluations, local rejection attempts, and slice work over all sweeps, including
burn-in. Inspect model movement as well as continuous-parameter convergence.
A prior proposal can be slow on a large concentrated bank. More draws, more
model moves, or a frozen full-support training-only proposal can improve
exploration; none of them substitutes for checking it.

## Diagnostics and forecasting

`autodesn_diagnostics(chains)` validates matching data, feature matrices,
architecture priors, and target-defining prior settings. Initial states,
proposal choices, run lengths, and R/C++ backends may differ. Learned variance
and scale traces, intercepts, fitted RMS and shrinkage summaries receive the
existing rank-normalized folded split R-hat, spectral ESS, and batch MCSE
screens. Fixed quantities are explicitly marked `sampled = FALSE`. Model
occupancy diagnostics are reported separately. An unvisited model's undefined
indicator ESS does not establish zero posterior mass.

Forecasts use the same joint model/coefficient/variance draw throughout a path.
Each horizon feeds back its simulated observation. Model probabilities and
readout parameters stay fixed between rolling origins in the C1 protocol;
only reservoir states are advanced with observations available at that origin.
Pooled `yrep` paths determine predictive intervals, while inner-path averages
of conditional locations estimate each draw's forecast mean.

RHS shrinks readout coefficients. It does not by itself add heteroscedastic
observation noise, create time-varying parameters, or prove stability of the
closed-loop forecast. Inspect recursive paths and held-out calibration.

## Validation and the C1 experiment

The tests include dense observation-covariance evidence oracles, coefficient
moments, rank-deficient and wider-than-sample designs, normalized transformed
scale densities, scalar local-update quadrature, prior-only architecture
recovery, independent integrated model odds, R/C++ parity, RNG restoration,
target compatibility, and causal forecast contracts. Longer independent
quadrature checks live in `validation/autodesn/rhs_validation/`.

The [comparison runner](../../validation/autodesn/rhs_comparison/README.md)
preserves the C1 data and bank, 500 unscored observations, 2,000 likelihood
rows, 471 rolling origins, and 30 leads. It separates compilation, bank
construction, inference, and forecasting times. Checkpoint hashes prevent
accidental reuse after changing data, priors, or source. A full forecast
comparison requires the frozen multi-chain convergence screens to pass.
Short smoke and pilot runs remain explicitly unqualified.

Reference: Juho Piironen and Aki Vehtari, *Sparsity information and regularization
in the horseshoe and other shrinkage priors*, [arXiv:1707.01694](https://arxiv.org/abs/1707.01694).

## Normalization and conditional derivation

Write `a_j = tau_m^2 * lambda_j^2` and `v_j = a_j*c2/(a_j+c2)`.
The normalized slope density is
`(2*pi*v_j)^(-1/2) * exp(-beta_j^2/(2*v_j))`. The existing
`R/qdesn_rhs_prior.R` uses this normalized variance and log-scale curvature
in its variational block. In contrast, `R/qdesn_rhs_ns_prior.R` explicitly
adds a horseshoe Gaussian density and a Gaussian pseudo-observation
`z_j=0 | beta_j,c2`. Its conjugate inverse-gamma updates belong to that
augmented target. The identity

```
N(beta;0,a) * N(0;beta,c2)
  = N(beta;0,a*c2/(a+c2)) * N(0;0,a+c2)
```

shows the extra scale-dependent factor. Its prior integral over all scales
is generally dimension dependent. Dropping it from an augmented target or
using its conjugate updates in the normalized target changes the posterior.
AutoDESN uses the normalized density directly; no unknown model-dependent
partition function remains.

For fixed architecture and scales, with `P=X'X/sigma2 + D^(-1)` and
`h=X'y/sigma2`, coefficients have `N(P^(-1)h,P^(-1))` conditional law.
The implementation factors the equivalent prior-whitened system rather
than explicitly inverting `P`. Given coefficients, observation variance is
`IG(a_sigma+n/2, b_sigma+||y-X beta||^2/2)`.

For the exact local update use `x=lambda_j^2`,
`x | nu_j ~ IG(1/2,1/nu_j)` and `nu_j ~ IG(1/2,1)`.
Holding `nu_j`, coefficients, global and slab scales fixed gives

```
p(x | rest) proportional to sqrt(A+B/x) * x^(-3/2) * exp(-b/x),
A=1/c2, B=1/tau_m^2, b=1/nu_j+beta_j^2/(2*tau_m^2).
```

The envelope `sqrt(A)+sqrt(B/x)` yields IG(1/2,b) and IG(1,b)
mixture weights proportional to `sqrt(A*pi/b)` and `sqrt(B)/b`.
The rejection ratio is `sqrt(A+B/x)/(sqrt(A)+sqrt(B/x))`.
Then `nu_j | x ~ IG(1,1+1/x)`. These are exact updates; the
remaining square-root factor prevents an ordinary conjugate IG local draw.

For `r=log(u)` and `s=log(c2)`, the global/slab conditional log target is

```
-0.5 * sum(log(2*pi*v_j) + beta_j^2/v_j)
+ log(2/pi) + r - log(1+exp(2*r))
+ a*log(b) - lgamma(a) - a*s - b*exp(-s),
a=slab_df/2, b=slab_df*slab_scale^2/2.
```

Both coordinate Jacobians are included. Slice updates alternate in `r` and
`s` on their full real supports. The code uses stable log-sum arithmetic.
All scale updates condition on the newly drawn coefficients, following the
coefficient-collapsed architecture move and its immediate coefficient draw.


## Explicit column standardization

`standardize_features=TRUE` in `autodesn_prepare_bank`, `autodesn_build_bank`
or `autodesn_fit` uses the same readout scaling helpers as Q-DESN model
selection. Column means and sample SDs are fitted only on the bank's scored
training rows, then frozen. The response/lag scaling and readout scaling are
separate. The intercept stays proper and unscaled. Nearly constant columns
are excluded with a frozen mask; `feature_sd_tol` defaults to 1e-8.

For unit-variance columns at the prior input, also set
`normalize_features=FALSE`. Keeping both flags TRUE instead gives column
variance 1/d after sqrt-d normalization. Defaults preserve historical behavior.
The coefficient transport to the raw reservoir engine includes both the
slope rescaling and the intercept shift; future data never refit a scaler.

```r
fit <- autodesn_fit(y, candidates=specs, conditioning=500L, washout=500L,
  standardize_features=TRUE, normalize_features=FALSE,
  beta_prior="rhs",
  rhs_control=list(tau0=0.001, slab_scale=1, slab_df=4),
  mcmc_args=list(n_burn=6000L,n_mcmc=32000L,seed=4066021L))
```

These budgets illustrate the API, not a convergence guarantee. The C1
sensitivity protocol and independent chains are specified in
`validation/autodesn/standardized_rhs/`. The previous C1 feature basis was
H/sqrt(d), not column z-scores. Its results remain results for that prior;
the new settings define a different prior and an exploratory sensitivity.

Standardization is a change in prior geometry, not just an algebraic speedup.
If z_j=(h_j-a_j)/s_j, a standardized draw maps to raw slopes beta_j/s_j
and raw intercept beta_0-sum(a_j*beta_j/s_j). Applying only the slope change
would give the wrong fitted and recursive forecast means. The saved transform
is also required when a new row lies far outside the training feature range;
its mean and SD must not be recomputed from the forecast batch.

## Optional mixing improvements

`rhs_control=list(local_layout="layerwise", interweave_global=TRUE)` adds
two exact computational changes without altering the normalized RHS marginal
prior, likelihood, or architecture prior. Defaults preserve the earlier sampler.
The layerwise embedding assigns common auxiliary half-Cauchy slots by layer
and readout-coordinate index. The reservoir design orders its deepest layer
first; using a simple prefix otherwise reassigns those scales to different
layers when depth changes. Inactive slots always have their proper normalized
prior. Their integral is one, so the architecture probabilities need no extra
dimension-dependent correction. A nonuniform `fixed_local_scales` vector is
interpreted in the chosen embedding and can therefore change that fixed target.

The extra global/local update holds `rho_j=log(u)+log(lambda_j)` fixed for
active coordinates. The transformation from `(log(u),log(lambda))` to
`(log(u),rho)` has determinant one. All coefficient variances and the
Gaussian likelihood stay fixed. The log conditional is therefore

```
log p(r | rho) = log HC_log(r) + sum(log HC_log(rho_j-r)) + constant,
HC_log(x) = exp(x)*2/(pi*(1+exp(2*x))).
```

An unbounded slice update samples `r`, then sets `log(lambda_j)=rho_j-r`.
The half-Cauchy augmentation variables are integrated out in this block and
immediately redrawn from `nu_j | lambda_j ~ IG(1,1+1/lambda_j^2)` afterward.
This restoration is necessary; retaining the old augmentation would be wrong.
The block changes no coefficient, slab, or fitted mean. It improves movement
along a strongly dependent global/local direction, but still requires actual
multiple-chain diagnostics, especially for architecture probabilities.


## Optional joint architecture and global-scale moves

A model-only proposal can mix poorly when architecture and shrinkage/noise
scales are strongly associated. `model_control$joint_proposal` optionally
adds a frozen independence proposal on
\(z=(\log\sigma^2,\log u,\log c^2)\) together with the architecture. Defaults
remain unchanged. Construct its normalized Student-t mixture with
`autodesn_rhs_joint_proposal(center, scale, ...)`; `model_control$proposal`
provides the positive model masses. The shape matrix is not a covariance
matrix unless adjusted by the Student-t degrees of freedom.

Let \(\ell\) denote the common full local-scale vector and \(\nu\) its
augmentation. Conditional on \((\ell,\nu)\), integrate all coefficients,
including the proper intercept. The density in log-scale coordinates is

\[
 \widetilde\pi(m,z\mid y,\ell,\nu)\propto
 p(m)\,N\!\left(y;0,e^{z_1}I+X_mD_m(z,\ell)X_m^T\right)
 h(z_2)\,j(z_1;a_\sigma,b_\sigma)\,j(z_3;\nu_c/2,\nu_cs_c^2/2),
\]

where

\[
 h(r)=\frac{2e^r}{\pi(1+e^{2r})},\qquad
 j(r;a,b)=\frac{b^a}{\Gamma(a)}\exp[-ar-be^{-r}].
\]

Both expressions include their coordinate Jacobians and prior normalizers.
Local-scale/augmentation priors are common, unchanged factors across the
move and cancel, including inactive coordinates. The Gaussian integral
retains every determinant and normalizer for each readout dimension.
For fixed proposal \(q(m')g_{m'}(z')\), accept with probability

\[
 1\wedge\frac{\widetilde\pi(m',z')q(m)g_m(z)}
                   {\widetilde\pi(m,z)q(m')g_{m'}(z')}.
\]

A same-architecture proposal still changes global scales and requires this
acceptance test. The conditional coefficient draw immediately follows the
collapsed moves. Only then are the ordinary variance/local/global/slab
conditionals applied. This ordering preserves the full joint posterior; old
coefficients must not be used between the collapsed move and their redraw.
The optional kernel requires sampled global and slab scales and MH model
moves. Both fitted and broad Student-t components have normalized densities;
all architectures keep positive proposal mass. Neither proposal fitting nor
its mixture weight defines or changes a shrinkage prior.

For NHS1, proposal centers and shape matrices use completed training chains
only and are frozen before fresh production chains. Independent checks use
SciPy normalized multivariate Gaussian/Student-t/IG/Cauchy densities, all
ordered acceptance-ratio pairs, and independent Sobol integration of a small
posterior with different readout dimensions. Disabled-kernel draws and
coefficients match the previous sampler exactly. These checks do not replace
full-size multiple-chain diagnostics.
