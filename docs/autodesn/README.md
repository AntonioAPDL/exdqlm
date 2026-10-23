# Gaussian AutoDESN

AutoDESN learns probabilities over a **finite, prespecified bank** of DESN
specifications and averages their forecasts. It reuses `qdesn_fit_vb()` for
reservoir construction and `forecast_paths.qdesn_normal_fit()` for recursion.
Choose `beta_prior = "ridge"` (default) or `beta_prior = "rhs"` for the
normalized regularized horseshoe. Both use the same bank and forecast API.
The [RHS guide](RHS.md) gives the prior, sampler, controls, and validation
contract. The [C1 comparison](../../validation/autodesn/rhs_comparison/README.md)
compares ridge AutoDESN, RHS AutoDESN, and AutoGP on the frozen rolling experiment.
The new inference code is additive: existing Normal and quantile fitters,
dispatchers, priors, model-selection facades and forecast methods are unchanged.
The shared builder also fixes a scalar-feature dimension issue so one-unit
reservoirs retain their time rows; multi-feature designs are unchanged.

```r
library(exdqlm)
set.seed(1)
y <- as.numeric(arima.sim(list(ar = 0.6), n = 250))
specs <- autodesn_candidates(D = c(1L, 2L), n = c(8L, 12L),
                             m = c(1L, 4L), alpha = 0.5,
                             rho = c(0.4, 0.8), seed = c(11L, 29L),
                             washout = 20L)
bank <- autodesn_build_bank(y, specs, conditioning = 30L)
chains <- lapply(c(101L, 507L, 901L), function(s)
  autodesn_fit_bank(bank, n_burn = 1500L, n_mcmc = 3000L, seed = s))
autodesn_diagnostics(chains)
forecast <- forecast_paths.autodesn_fit(chains[[1L]], H = 12L, nd = 1000L, seed = 52L)
interval <- apply(forecast$yrep, 1L, quantile, probs = c(.05, .5, .95))
```

The convenience entry point is `autodesn_fit(y, candidates = specs,
mcmc_args = list(...))`. Explicit bank construction permits multiple chains to
reuse reservoir states, designs and SVDs. `n_mcmc` is the number of post-burn
sweeps **before thinning**; `thin = 1` is generally preferred.

Inspect the complete settings of a candidate with
`bank$specifications[[j]]`, including layer widths, bridges, leak, radius and
input preprocessing. The most probable row is
`which.max(chains[[1L]]$model_summary$posterior_probability)`; forecasts still
average joint draws over the bank rather than substituting that one model.

## Statistical model and default ridge prior

For candidate $j$, let $H_j$ be the slopes from the shared DESN builder,

$$
 F_j=H_j/\sqrt{d_j},\quad X_j=[\mathbf1,F_j],\qquad
 y_t\mid j,\beta_j,s^2,\mathcal F_{t-1}
 \sim N(x_{jt}^{\mathsf T}\beta_j,s^2).
$$

The division is optional but is fixed before scoring. It controls the
dimension dependence of the slope prior's total output variance; it does not
make different widths or nonlinear feature maps equivalent.

$$
 \beta_{j0}\sim N(0,v_0),\quad
 \beta_{j,-0}\mid\lambda\sim N(0,I/\lambda),\quad
 s^2\sim\mathrm{IG}(a_s,b_s),\quad
 \lambda\sim\mathrm{Gamma}(a_\lambda,b_\lambda).
$$

All gamma distributions use shape/rate. The inverse-gamma density is
proportional to $x^{-a-1}\exp(-b/x)$. Defaults are $v_0=10$,
$a_s=3,b_s=1,a_\lambda=2,b_\lambda=2$, in standardized response units.
`learn_ridge = FALSE` holds `ridge_precision` fixed. The alternative normalized
RHS prior adds global, local, and slab scales; see [RHS.md](RHS.md). Neither
readout introduces latent AL variables or time-varying coefficients.

**This prior is independent of observation variance.** The existing
`normal_desn_fit(beta_prior_type = "ridge")` uses a different, scaled ridge
prior, with coefficients conditional on observation variance. Its exact
Normal-inverse-gamma posterior and marginal likelihood cannot be substituted
here. The new readout sampler therefore lives separately, while feature and
forecast computation are shared.

## How ridge selection works

For fixed variance and precision, integrate all coefficients analytically:

$$
 C_j=s^2I+v_0\mathbf1\mathbf1^{\mathsf T}+F_jF_j^{\mathsf T}/\lambda,
 \quad \ell_j=-\tfrac12\{n\log(2\pi)+\log|C_j|+y^{\mathsf T}C_j^{-1}y\}.
$$

For autoregressive features this is the algebraic integral of the causal
conditional likelihood. It is not a claim that the entire unconditional
autoregressive series is multivariate Gaussian with a fixed exogenous design.
An SVD per model plus a rank-one intercept update evaluates the same score
without a dense observation covariance factorization at every sweep.

This is also the precise GP connection: conditional on a specification and
ridge precision, Gaussian readout weights induce the kernel
$K_j(t,s)=v_0+\lambda^{-1}\sum_k F_{j,tk}F_{j,sk}$ on observed histories.
AutoDESN therefore searches over kernels induced by recurrent feature maps,
integrates their linear readouts, and averages their posterior predictions.
Its specification bank takes the place of a GP kernel grammar.

One Gibbs sweep is:

1. Draw $j$ with probabilities proportional to
   $p(j)\exp\{\ell_j(s^2,\lambda)\}$.
2. **Immediately redraw** $\beta_j$ from its Gaussian conditional. Steps 1
   and 2 form one joint update of model and coefficients, even when dimensions
   differ. No stale coefficient vector survives a model update.
3. Draw $s^2$ from
   $\mathrm{IG}(a_s+n/2,b_s+\|y-X_j\beta_j\|^2/2)$.
4. If enabled, draw $\lambda$ from
   $\mathrm{Gamma}(a_\lambda+d_j/2,b_\lambda+\|\beta_{j,-0}\|^2/2)$.

There is no coefficient-dimension addition in step 3 because the coefficient
prior is independent of variance. The proper intercept is excluded from step
4. Both mistakes would change the posterior.

`model_summary$posterior_probability` averages model conditional probabilities
across the model-update substeps; `occupancy` records sampled frequencies.
These are Monte Carlo estimates. Stored `conditional_probabilities` precede
the variance and precision updates in their sweeps and should not be paired
with the stored end-of-sweep hyperparameters as conditional probabilities.

## Prior over specifications

By default, prior mass is uniform over represented depths, and uniform within
each depth. Other candidate dimensions, including reservoir seed, are discrete
model variables. Supply `model_prior` to express another architecture prior.
Duplicating a model changes the prior unless its existing mass is explicitly
split between the copies. Adding more seeds without accounting for prior mass
can also change comparisons. Feature scaling and model priors should be fixed
before examining held-out scores.

This borrows AutoGP's philosophy of structural priors, integrated nuisance
parameters, and posterior predictive averaging. It is not AutoGP's kernel
grammar or an unbounded architecture search. Posterior probabilities are
relative to the listed models and the chosen prior; they do not establish a
unique true depth or uniquely identify the internal reservoir dynamics.

## Causality and forecasting

The initial `conditioning` observations determine a frozen response mean and
standard deviation. They are excluded from scoring. A common further warmup
equals the largest lag count or requested washout across the bank. Every model
scores exactly the same remaining observations. A constant prefix uses scale
one. Input standardization, if requested, uses frozen zero/one overrides on the
already standardized response; the shared builder never estimates it from the
scored response window. Input scales and bounded inputs retain normal Q-DESN
semantics.

The optional bank argument `washout` specifies the **total** unscored prefix,
including conditioning, rather than adding another warmup. For exactly 500
training observations after 500 warmup observations, pass a length-1000 history
with `conditioning = 500L, washout = 500L`. It must cover every candidate's
lag/washout requirement. With the same controls, a length-2500 history gives
exactly 2,000 training rows (501:2500). Keep the 100 future targets outside that
history. The legacy additive convention remains the default.

Adding a candidate with a larger lag count or washout can change this common
response window. To compare different banks on identical data, give all of them
the same sufficient washout and conditioning prefix.

Forecasts retain reservoir weights, bridge matrices, terminal layer states,
the observed history and preprocessing. Each path selects one retained joint
draw of model, coefficients and variance and retains it for all horizons.
Gaussian innovations are sampled and fed back. Slopes are converted back to
the shared builder's feature scale before calling the Normal forecast method.
Forecasts and fitted means return to the original response scale.

For nested simulation, `nd` controls outer joint posterior draws and
`inner_paths` controls innovation paths per draw. A supplied `draw_index`
reuses specific retained draws, and `innovations` accepts a standard-normal
noise bank for paired calculations. `backend = "batched"` propagates paths
through the same transition using matrix operations; serial remains default.
`mean_conditional_location` averages conditional means over inner paths for
each outer draw. It also equals applying that draw's linear readout to its
average readout state. Pool all `yrep` outcomes to estimate marginal predictive
quantiles. The separately labeled `conditional_mean_plugin` mode is a
zero-innovation diagnostic, not the predictive distribution.

See the [500/500/100 experiment](../../validation/autodesn/long_horizon/README.md)
for the exact split, identity-bridge bank, three-chain fits, 100-step recursive
forecasts, known-DGP reference, inner-path sensitivity and reproduction commands.

`mu_draws[h, ]` describes conditional means evaluated along simulated histories;
at later horizons it is not obtained by recursively feeding only mean forecasts.
`posterior_predict.autodesn_fit()` supports externally supplied fixed designs,
which contain slopes before normalization. It must not be used to smuggle
observed future targets into a nominal multi-step evaluation.

## Supported scope and costs

The first version supports finite univariate data, raw-y-lag reservoir inputs,
deterministic reservoir features and a reservoir-only readout with one proper
intercept. The shared builder's actual layer widths, projections, topology,
activations and preprocessing are retained. Missing responses, exogenous or
decomposition forecast inputs, segmented series, observation weights, noisy
training features and augmented readout memory are deliberately rejected.
These require explicit likelihood and forecast contracts before extension.

There is no new guarantee of echo-state or autonomous forecast stability.
The existing spectral-radius/leak safeguards are inherited. No input-driven
radius criterion alone proves stability after feeding stochastic outputs back.
Unbounded activations and aggressive settings should be inspected through
simulated paths.

For $M$ models, $n$ scored observations and $d$ slopes, each readout cache stores
$O(nd + d^2 + \min(n,d))$ values; full reservoir weights and state histories add
further memory. The SVD's left vectors are temporary, while their projections
are cached. Each complete ridge model scan is $O(M\min(n,d))$. A selected coefficient
draw uses a $(d+1)$-dimensional precision Cholesky and a residual matrix product.
Banks with hundreds of large reservoirs need screening, caching, or more
efficient linear algebra. The bank
is built once per forecast origin; it is not refit at each future step.

## Gibbs, SMC and future extension

Blocked Gibbs is the first implementation because the bank is finite, all model
probabilities can be evaluated, and Gaussian readout conditionals are exact.
It is asymptotically posterior-correct, not an exact finite-run enumeration of
variance and ridge uncertainty. Multiple chains and forecasting checks remain
necessary. A fixed scaled-ridge prior could instead permit fully analytic
model weights through the existing Normal backend, but changes the prior.

SMC is a reasonable later comparison for a large evolving grammar, multimodal
hyperparameters, tempered global exploration or online updating with a proper
static-parameter rejuvenation scheme. It is not inherently optimal and a
particle filter is unnecessary for deterministic reservoir states. Start with
this audited Gibbs target and compare equal compute budgets before adding SMC.

The normalized RHS readout now has its own coefficient-integrated Gaussian
scores and exact-target MCMC transitions; see [RHS.md](RHS.md). Its local scales
require Cholesky solves in the original feature basis. Collapsed MH avoids a
complete bank scan at every sweep. AL/exAL readout extensions still require a
separate derivation; approximate VB scores are not exact posterior model weights.

## Validation and reproduction

See `IMPLEMENTATION_PROMPT.md` for the task contract and `VALIDATION.md` for
the executed results. Reproduction assets are in `validation/autodesn/`:

```sh
Rscript validation/autodesn/run_oracle.R
Rscript validation/autodesn/run_simulations.R
python validation/autodesn/plot_results.py
Rscript validation/autodesn/run_tests.R
```

The scripts source the checked-out R implementation so the study records the
working implementation. The test runner instead exercises the installed API;
install the checkout first with `R CMD INSTALL .`. Set `AUTODESN_TEST_FILTER`
for a focused testthat filename filter, or leave it unset for the complete suite.
Set `NOT_CRAN=true` to include the additional computational tests normally
skipped by CRAN.
Simulation comparisons are modest implementation checks with repeated series,
not a comprehensive forecasting benchmark or proof of a benefit from depth.

The [500/2000 rolling-origin study](../../validation/autodesn/heteroscedastic/rolling/README.md)
extends the experiment to 2,000 likelihood rows and three nonlinear variance
mechanisms. A 100-observation test block supports 71 complete rolling origins,
each forecasting 30 leads. Following the corrected Q-DESN protocol, the
posterior and preprocessing stay fixed while observed states update between
origins; feedback within a forecast is simulated. Compact checkpoints support
new horizon/origin replays. The earlier fixed-origin and one-step experiments
remain separate diagnostics.
