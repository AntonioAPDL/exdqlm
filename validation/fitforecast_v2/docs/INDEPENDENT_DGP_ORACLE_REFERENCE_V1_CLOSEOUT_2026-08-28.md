# Independent DGP Oracle Reference v1 Closeout

## Decision

The independent simulation interval figures can carry a deterministic DGP
oracle reference without any model replay. Fit RMSE and forecast MAE use the
exact zero oracle. Forecast check loss uses the population expected score at
the true conditional quantile. The realized true-path check loss on the fixed
held-out block remains a separate diagnostic.

## Frozen values

| Family | Target | Expected check loss | Realized held-out oracle |
|---|---:|---:|---:|
| Gaussian | 0.05 | 1.0313564 | 1.0437989 |
| Gaussian | 0.25 | 3.1777657 | 3.2136420 |
| Gaussian | 0.50 | 3.9894228 | 3.9521510 |
| Laplace | 0.05 | 1.6512925 | 1.8212553 |
| Laplace | 0.25 | 4.2328680 | 4.3366242 |
| Laplace | 0.50 | 5.0000000 | 4.9779953 |
| Gaussian mixture | 0.05 | 1.5087319 | 1.4749757 |
| Gaussian mixture | 0.25 | 4.5018308 | 4.4562734 |
| Gaussian mixture | 0.50 | 5.4148337 | 5.3916415 |

## Validation

- 13/13 scientific and protocol checks pass.
- The grid contains 34 origins and 1,000 unique lead-target pairs spanning
  source indices 9001--10000 exactly once.
- All nine source series are SHA-256 pinned.
- Raw quantile CDF errors are below `3e-17`.
- The largest analytic-versus-numerical expected check-loss discrepancy is
  below `1.5e-12`.
- No fitted-model binary is retained.
- No article metric or winner changes.

## Interpretation

The expected check-loss reference is a population Bayes risk. Posterior metric
intervals condition on one simulated data set, so finite-sample score draws can
fall on either side of that population line. This does not imply that a fitted
model improves on the true conditional quantile in expectation.

## Integration boundary

This branch owns only the scientific oracle ledger and its verification code.
The Article-v2 projection is prepared separately and must be reviewed and
integrated by the coordinator. This lane does not merge shared validation,
Article-v2 main, or Overleaf.
