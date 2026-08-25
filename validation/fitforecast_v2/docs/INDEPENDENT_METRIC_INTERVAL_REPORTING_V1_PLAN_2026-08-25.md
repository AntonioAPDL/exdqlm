# Independent Metric-Interval Reporting and Visualization v1

Date: 2026-08-25

## Objective

Close the independent single-quantile posterior metric-interval audit without
presuming that sensitivity to cross-origin coupling makes the existing bands
incorrect. Verify the implementation against its declared estimand, retain the
frozen v10 numbers whenever the implementation is internally correct, disclose
the model-specific dependence contracts, and prepare publication-quality
figures from the authoritative interval record.

This phase does not reopen DESN calibration, change a case-specific winner,
replace an article metric, or modify Article-v2. It produces a frozen scientific
handoff for the article integration lane.

## Authorities and scope

- Source promotion:
  `qdesn_dqlm_500obs_metric_intervals_v10_20260824`.
- Estimator:
  `posterior_mean_draw_metric_equal_tailed_95cri_v1`.
- Portable raw-evidence bundle:
  `/data/jaguir26/local/artifacts/independent_qdesn_validation/metric_intervals_v10_evidence_bundle_v1_20260824.tar.gz`.
- Coupling pilot:
  `independent_metric_interval_coupling_pilot_v1_20260825_000726`.
- Deterministic same-draw tolerance: `1e-6`.
- Fresh MCMC chains are assessed statistically, not by bitwise or `1e-6`
  equality.

Joint Q-DESN, PriceFM, GloFAS, application code, Article-v2 main, and Overleaf
are out of scope.

## Estimands

For retained posterior or variational draw `s`, the three metrics are

```text
fit_rmse[s] = sqrt(mean_t((q_fit[s,t] - q_oracle[t])^2))
forecast_mae[s] = mean_(o,h)(abs(q_forecast[s,o,h] - q_oracle[o+h]))
forecast_check[s] = mean_(o,h)(rho_p(y[o+h] - q_forecast[s,o,h]))
```

where `rho_p(u) = u * (p - I(u < 0))`. The reported center is the mean of the
draw-wise metric, and the band is its equal-tailed 2.5 and 97.5 percent
quantiles. These are conditional-quantile metric draws, not response-predictive
metrics and not repeated-simulation uncertainty.

## Contract audit

The implementation audit distinguishes arithmetic correctness from dependence
sensitivity.

1. Q-DESN/exQ-DESN fit metrics preserve each sampled readout across the
   500-row training path. Forecast metrics preserve the native posterior
   readout identity across rolling origins and leads.
2. DQLM/exDQLM fit metrics use sampled state paths. Forecast metrics use the
   product coupling of the origin--lead latent quantile marginals represented by
   `ff` and `fQ` after each rolling state update.
3. Both implementations use exactly 500 fit rows and 1,000 scored
   rolling-origin lead-target pairs, and both exclude response-predictive draws.
4. The portable same-draw replay reproduced all 270 source-metric summaries.
5. The 33-job paired sensitivity pilot completed without failures. Alternative
   couplings preserved posterior means to numerical precision, changed widths
   materially in all 22 pilot comparisons, and changed none of the tested
   winner--runner interval-overlap conclusions.

The native contracts are different, but the code matches the contracts. The
coupling result is therefore sensitivity evidence rather than evidence of an
implementation defect. The v10 intervals remain the primary native posterior
intervals and must be labeled accordingly. No refit is required.

## Figure design

Generate six horizontal interval forest plots: three MCMC and three VB, one for
each metric. Every plot contains a 3-by-3 panel layout ordered by simulation
family and quantile. Each panel contains the four models, a horizontal 95
percent interval, and a cross at the posterior mean. Each panel has its own
horizontal scale because extreme exDQLM values otherwise compress competitive
results.

The fixed colorblind-accessible mapping is:

| Model | Color |
|---|---|
| DQLM | `#0072B2` |
| exDQLM | `#56B4E9` |
| Q-DESN AL--RHS | `#D55E00` |
| Q-DESN exAL--RHS | `#009E73` |

Vector PDFs are the LaTeX authority. Six-hundred-DPI PNGs are visual-inspection
companions. The crosses and direct y-axis labels provide redundant encoding for
grayscale use.

## Validation gates

- exactly 216 interval-role rows;
- exactly 108 rows per inference method;
- exactly 36 rows per inference/metric figure;
- one unique row per inference/model/family/quantile/metric key;
- finite and ordered endpoints;
- every posterior mean inside its interval;
- exact frozen estimator and interval labels;
- six PDFs and six PNGs;
- complete SHA-256 ledgers and article-destination manifest;
- no fitted-model binary payloads;
- no article or remote-main write from this lane.

## Publication recommendation

Retain the complete numeric tables as the exact record. Use the MCMC forest
plots in the main article if space permits, or prioritize the two forecast
figures and place fit RMSE in the supplement. Place the matching VB figures and
full interval tables in the supplement. Add the native-coupling clarification
near the interval definition. The article integration lane makes the final
placement decision after compiling the combined manuscript.

No coherent-trajectory or full replay campaign should be launched unless a
future scientific objective explicitly replaces the native posterior contracts
with a common cross-model coupling estimand. Such a campaign would be a new
sensitivity analysis, not a correction to v10.
