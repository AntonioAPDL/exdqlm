# Independent Q-DESN Dynamic-Readout Validation v5

## Purpose

The v4 rolling-readout campaign showed that exact-M0 refitting on the most
recent 1000 observations materially improves the frozen static Q-DESN, but the
gain is not uniform across internal temporal folds. This campaign therefore
tests the narrower mechanism suggested by that result: gradual coefficient
drift between refits.

This is a validation-only mechanism experiment. It is not another DESN
architecture screen, it does not alter the frozen reservoir, and it does not
claim that the online posterior is exact MCMC. The initial readout posterior is
estimated by the exact-M0 sampler; subsequent causal updates use an
exAL-local-moment assumed-density filter.

## Frozen scientific contract

The sole target remains `normal__exal__p005` with candidate
`3a7a6653cb244f49813c`: depth 5, widths `36;38;29;20;20`, 143 states, 240
lags, leakage 0.1630299, spectral radius 0.9987975, and an
intercept-plus-reservoir readout. All three retained exact-M0 chains are pooled
within each fold to estimate the initial coefficient mean and covariance and
the exAL nuisance moments.

At each newly observed time point the prior coefficient covariance is inflated
by the standard discount evolution

`R_t = C_{t-1} / delta`, where `delta = 2^(-1 / half_life)`.

The observed response is then assimilated with the existing exAL local-moment
update. This gives a Gaussian assumed-density posterior for the readout while
holding the exact-M0 nuisance moment distribution fixed. Forecast origins are
teacher-forced as they advance; each 30-step forecast remains recursive within
the origin. Source indices 9001--10000 remain sealed.

## Half-life screen

The predeclared coefficient half-lives are infinite (online assimilation with
no covariance inflation), 1000, 500, 250, 125, and 62.5 observations. These
cover nearly static through moderately adaptive readouts without a dense grid.
The exact-M0 rolling-N=1000 policy and exDQLM are frozen comparators rather than
refitted controls.

1. Screen the six policies on offsets 50, 125, and 200 in folds S1--S4.
2. Advance the best policy only if it strictly improves the frozen rolling
   readout's median forecast-MAE ratio and wins against exDQLM in at least 6 of
   12 cells.
3. Evaluate only that policy at disjoint offsets 25, 75, 150, and 220.
4. Run two additional posterior-predictive seeds only if the selected policy
   has median Q-DESN/exDQLM forecast-MAE ratio below one, at least 9 of 16 wins,
   and a strict median improvement over rolling N=1000.

Forecast MAE is primary. Forecast check loss, RMSE, interval summaries,
origin/lead profiles, first-step identities, covariance conditioning, and
coefficient drift are retained. Diagnostics describe the approximation but do
not veto a predictive result.

## Interpretation and promotion boundary

A failure rejects the tested dynamic-readout filter and stops further work on
this path. A success establishes a causal mechanism worth implementing as a
fully specified dynamic Bayesian readout and confirming on fresh DGP
replicates. It does not directly replace an article MCMC row because the
post-initialization updates are assumed-density updates, not exact-M0 draws.

No article table, figure, or manuscript source is changed in this lane. The
integration coordinator may merge the validation implementation and closeout
evidence, but any article-facing change requires a separately frozen estimator
and fresh-DGP confirmation.

## Reproducibility and storage

Source, package, parent evidence, configs, seeds, stage plans, and outputs are
SHA-256 manifested. Workers are single-threaded and scheduled one per unused
physical core, up to 15 workers. No fitted-model `.rds`, `.rda`, or `.RData`
payload is retained.
