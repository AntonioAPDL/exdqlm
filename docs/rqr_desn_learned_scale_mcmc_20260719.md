# RQR-DESN learned-scale MCMC implementation note

Status: implemented and guarded for MCMC; VB learned-scale inference is deferred.

## Methodological decision

The production extension learns one global inverse RQR loss scale per fit. For
coverage level `c`, roots `beta1`, `beta2`, and residual product

```text
e_t = (y_t - x_t beta1) (y_t - x_t beta2),
```

the implemented generalized posterior is

```text
pi(beta1, beta2, lambda | y) proportional to
  pi(beta1, beta2) pi(lambda) lambda^T
  exp{-lambda L_c(beta1, beta2) / s_L}
```

where

```text
L_c(beta1, beta2) = sum_t rho_c(e_t).
```

The scale `s_L` is `loss_reference_scale`. The default `s_L = 1` reproduces
the raw-loss target. The frozen learned-scale relaunch uses the final-fit
training response variance, which is equivalent to learning `lambda` on a
standardized RQR loss scale while keeping endpoints and metrics on the original
response scale.

With `lambda ~ Gamma(a, b)`, the collapsed Gibbs update is

```text
lambda | beta1, beta2, y ~ Gamma(a + T, b + L_c(beta1, beta2) / s_L).
```

This is the default learned-scale target because the profiled objective
preserves the RQR expected-loss minimizer. The scalar `lambda` is an inverse
loss scale, not a response variance and not an automatic credible-interval
calibration parameter.

The diagnostic pure target

```text
pi(beta1, beta2, lambda | y) proportional to
  pi(beta1, beta2) pi(lambda) exp{-lambda L_c(beta1, beta2)}
```

is available as `learning_rate_mode = "learned_pure"`, with conditional
`Gamma(a, b + L_c)`. It is not used in the production relaunch config because
it is expected to be prior-sensitive and to push `lambda` toward zero as the
training length grows.

The normalized pseudo-density route was not implemented. Its normalizing
constant depends on the interval width and would change the RQR target while
destroying the simple Gamma update.

## Code contract

Implemented API:

```r
rqr_mcmc_fit(
  y,
  X,
  coverage_level,
  learning_rate = 1,
  loss_reference_scale = 1,
  learning_rate_mode = c("fixed", "learned_scale", "learned_pure"),
  lambda_prior = list(shape = 4, rate = 4),
  ...
)
```

Backward compatibility:

- `learning_rate_mode = "fixed"` remains the default.
- Existing fixed-rate calls keep using the numeric `learning_rate`.
- `samp.lambda` is stored for all MCMC fits; it is constant in fixed mode.
- `effective_learning_rate = lambda / loss_reference_scale` is used in the
  latent Gaussian updates.

Prediction contract:

- `lambda` is not inserted into endpoint formulas.
- Endpoint draws remain `min(x beta1, x beta2)` and `max(x beta1, x beta2)`.
- The learned scale influences prediction only through the posterior root draws.
- RQR-DESN still does not expose posterior predictive response draws.

VB status:

- Fixed-rate VB remains available.
- Learned-scale VB is intentionally guarded because it requires a reliable
  approximation to `E_q L_c(beta1, beta2)` and further validation.

## Relaunch configuration

The frozen relaunch config is

```text
config/rqr_desn/rqr_desn_article_congruent_learned_scale_rich_desn_20260719.R
```

It keeps the article-congruent split and DGP families, adds learned-scale RQR
MCMC as a primary method, retains the fixed-rate RQR grid as a continuity
benchmark, and uses richer dynamic DESN features:

```text
D = 2
n = 100 per layer
m = 50
alpha = 0.10
rho = 0.95
tau0 = 1e-4 for RQR and independent Q-DESN RHS priors
lambda prior = Gamma(4, 4)
RQR loss_reference_scale = training response variance
```

The config remains guarded: a full run requires `--confirm-full-launch true`.
Article updates remain blocked until the run is audited and promoted.
