# Independent Q-DESN Forecast-Uncertainty Rescue v8

## Purpose

The v7 Gaussian-mixture, AL, `p = 0.05` campaign reduced mean forecast MAE
from 4.6032 to 3.2762 and brought it within 4.5% of the matched DQLM value.
Its posterior forecast-MAE interval nevertheless remained about 4.7 times as
wide as DQLM. This campaign tests whether that residual width is reducible by
case-specific RHS shrinkage while holding the validated DESN representation
fixed.

This is a diagnostic and confirmation campaign. It cannot update article
tables, Article-v2 main, shared validation, or Overleaf.

## Frozen Scientific Contract

- Cell: Gaussian-mixture, AL, `p = 0.05`.
- Training size: 2,000 observations with a 500-observation washout.
- Architecture: v7 winner `ee86f44d691bd40b`, held fixed.
- Readout: intercept plus every identity-Q reservoir layer; no raw inputs.
- Forecasting: observations are assimilated when the origin advances;
  forecasts are recursive within each 30-step horizon.
- Selection folds: S1 and S3 only.
- Confirmation folds: S2 and S4 only.
- Article holdout: source indices 9001-10000 are never opened.
- Software: CRAN `exdqlm` 1.1.2 under R 4.6.0, one thread per worker.

## Estimators

The primary estimator remains the existing recursive posterior forecast: each
posterior coefficient draw is propagated through its own recursively simulated
future path, then its conditional location is averaged over 128 inner paths.

The campaign adds a diagnostic shared-state estimator. At every origin and
lead it averages the conditioned readout-state vector across all posterior
coefficient and process paths first, then applies every posterior coefficient
draw to that common mean state. This removes propagated-state heterogeneity
while preserving readout-coefficient uncertainty. It is not silently treated
as a full posterior predictive distribution and cannot be promoted without a
separate scientific decision.

## Stages and Budgets

| Stage | Jobs | Purpose | Budget |
|---|---:|---|---|
| Replay | 6 | Reconstruct shared-state forecasts from retained v7 winner draws | no refit |
| Smoke | 1 | End-to-end MCMC, estimator, evidence, and hash check | 20 burn + 40 retained |
| Warm | 14 | VB initializers for 7 tau multipliers on S1/S3 | 800 iterations |
| Discovery | 14 | Direct MCMC tau screening on S1/S3 | 1,500 burn + 5,000 retained |
| Confirm warm | 4 | VB initializers for 2 selected tau arms on S2/S4 | 1,000 iterations |
| Confirmation | 12 | 2 arms x 2 folds x 3 chains | 3,000 burn + 10,000 retained |

Tau multipliers are `0.5, 0.75, 1, 1.5, 2, 2.5, 3`. Up to 30 workers run in
parallel, with one physical core and one numerical-library thread per model.

## Selection and Decision Rules

Discovery ranks the primary recursive estimator by forecast MAE, forecast-MAE
interval width, and interval score. Candidates more than 10% above the best
discovery MAE are excluded. The best multi-objective arm and the v7 tau=3
anchor proceed to confirmation (or the runner-up if tau=3 is already best).

A confirmed rescue must satisfy all of the following across S2/S4 and three
chains:

1. mean forecast MAE no more than 1.10 times DQLM;
2. worst-fold forecast MAE no more than 1.20 times DQLM;
3. mean forecast MAE no more than 2% above v7;
4. forecast-MAE interval width strictly below v7;
5. forecast check loss no more than 2% above v7;
6. interval score no more than 2% above v7.

If no arm passes, the closeout is
`TAU_RESCUE_INSUFFICIENT_PREPARE_LOCAL_ARCHITECTURE_FALLBACK`. A local
architecture fallback is then designed as a new frozen campaign; it is not
dynamically appended to this run.

## Reproducibility and Storage

Every stage has frozen JSON configurations and SHA-256 manifests. Each evidence
directory contains score draws, origin/lead diagnostics, all three forecast
estimators, diagnostics, and a self-manifest. Retained v7 MCMC samples are read
through verified parent manifests. Fitted model binaries (`.rds`, `.rda`, and
`.RData`) are forbidden; the closeout records zero fitted binary payloads.
