# Independent DGP Oracle Reference v1

## Objective

Add a mathematically matched data-generating-process reference to the posterior
metric-interval figures for the independent single-quantile study. This is a
deterministic reporting extension. It does not refit, rerank, or replace any
model result.

## Audited metric contract

The fit RMSE and forecast MAE compare conditional-quantile paths with the known
DGP quantile path. Their oracle values are therefore exactly zero. Forecast
check loss scores fixed held-out observations. Its population oracle is the
positive Bayes risk

```text
E[rho_tau(Y - q_tau)]
```

at the true conditional quantile. The realized score of the true path on the
fixed held-out sample is retained separately because it is directly comparable
to the conditional posterior score draws but is not the population expectation.

## DGP contract

The innovation laws are frozen as follows.

| Family | Parameters |
|---|---|
| Gaussian | standard deviation 10 |
| Laplace | scale 10 |
| Gaussian mixture | weights 0.1/0.9, means 0/1, standard deviations 0.5/15 |

For each target level, the innovation is shifted by its raw quantile so that
the conditional target quantile equals the latent dynamic location path. The
scale is constant, so population check-loss risk depends on family and target
level but not forecast origin or lead.

## Verification gates

1. Reconstruct the exact rolling grid: fit indices 8501--9000, forecast indices
   9001--10000, maximum lead 30, stride 30, 34 origins, and 1,000 unique target
   pairs.
2. Hash all nine frozen source series.
3. Verify `q_target == mu` and `eps == y - mu` to numerical tolerance.
4. Verify that each raw innovation quantile has CDF equal to its target level.
5. Calculate expected check loss analytically and by independent numerical
   integration; require maximum absolute disagreement at most `1e-8`.
6. Calculate the realized oracle check loss on the exact held-out target grid.
7. Freeze the 27-row family-by-level-by-metric reference ledger and a compact
   article projection.
8. Retain only CSV, JSON, and Markdown evidence. Fitted-model binaries are
   prohibited.

## Figure policy

- A black dashed line denotes the plotted DGP oracle.
- For fit RMSE and forecast MAE, the line is at zero.
- For forecast check loss, the line is the population expected DGP optimum.
- Captions state that posterior intervals condition on one simulated data set
  and can cross a population reference through finite-sample variation.
- The realized oracle remains in the evidence ledger and is not added as a
  second primary line, avoiding visual clutter.
- Existing v12 assets remain unchanged. New figures use a v13 identifier.

## Publication workflow

Scientific evidence is committed to a dedicated validation branch. Article
figures and prose are prepared on a dedicated Article-v2 work branch. Neither
branch merges main or publishes Overleaf. A combined review PDF remains under
an ignored `local_trackers` path until visual approval and coordinator-led
integration.
