# Independent Metric-Interval Reporting v1 Closeout

Date: 2026-08-25

## Decision

`RETAIN_V10_NATIVE_INTERVALS_WITH_EXPLICIT_COUPLING_DISCLOSURE`

The frozen v10 intervals are internally correct under their declared native
posterior constructions. The audit found no indexing, arithmetic, draw-source,
or metric-aggregation defect. No model refit, coherent-trajectory correction,
or 54/72-job replay is required for the current estimand.

The coupling pilot remains important sensitivity evidence. It demonstrates
that aggregate interval widths depend on how finite origin--lead marginal draws
are coupled, while leaving posterior means unchanged. That sensitivity does not
invalidate the native intervals. It instead determines how they must be
labeled and interpreted.

## Verified evidence

| Item | Result |
|---|---:|
| Frozen article-role intervals | 216/216 |
| Unique inference/model/family/quantile/metric keys | 216/216 |
| MCMC interval rows | 108 |
| VB interval rows | 108 |
| Same-draw source-metric replay | 270/270 |
| Coupling pilot jobs | 33/33 |
| Pilot implementation failures | 0 |
| Paired coupling comparisons | 22 |
| Material width sensitivities | 22 |
| Posterior-mean changes under paired coupling | 0 to numerical precision |
| Tested winner/runner overlap changes | 0 |
| Fresh-chain statistically equivalent comparisons | 22/22 |
| Maximum fresh-chain mean displacement | 0.0818 posterior SD |
| Minimum fresh-chain interval overlap | 0.9895 |
| Deterministic fresh-chain matches within `1e-6` | 8/22 |
| Heavy fitted-model binaries retained | 0 |

The `1e-6` tolerance applies to deterministic recomputation from identical
stored draws. Independently sampled MCMC chains are evaluated by standardized
mean displacement and interval overlap rather than deterministic equality.

## Native contracts

- Q-DESN and exQ-DESN preserve the posterior readout-draw identity across the
  fit path, rolling origins, and forecast leads.
- DQLM and exDQLM use sampled state paths for fit RMSE and the pre-specified
  product coupling of rolling origin--lead latent quantile marginals for
  forecast MAE and check loss.
- All engines use conditional-quantile draws. Response-predictive draws are
  excluded.
- All fit metrics use 500 training rows. All forecast metrics use the same
  1,000 rolling-origin lead-target pairs.

These model-specific contracts must be disclosed. The intervals are posterior
uncertainty under those contracts, not repeated-simulation uncertainty and not
a common cross-model copula construction.

## Publication assets

The reporting packet is

```text
validation/fitforecast_v2/promotions/
qdesn_dqlm_500obs_metric_interval_reporting_v10_1_20260825
```

It contains:

- six vector PDF forest plots;
- six 600-DPI PNG inspection copies;
- one plot-ready 216-row CSV;
- MCMC and VB LaTeX figure wrappers;
- an article-ready estimator-contract clarification;
- complete source, article-asset, and output hash ledgers;
- compact coupling and replay evidence;
- an independently generated verification report.

Each figure displays one metric across all three families, three quantile
levels, and four models. Horizontal segments are interval endpoints and crosses
are posterior means. Per-panel horizontal scales prevent extreme baseline
values from flattening competitive comparisons.

## Recommended article placement

1. Place MCMC forecast MAE and forecast check-loss figures in the main article.
2. Place the MCMC fit-RMSE figure and all complete MCMC numerical tables in the
   supplement unless main-text space permits.
3. Place all three VB figures and complete VB numerical tables in the
   supplement.
4. Insert the coupling-contract clarification alongside the metric-interval
   definition.
5. Retain the numerical tables somewhere in the article package; figures should
   improve communication, not remove the exact reproducibility record.

The article integration lane owns final placement, manuscript compilation,
main-branch merge, and Overleaf publication. This scientific lane has not
modified Article-v2 or any unrelated application/validation work.

## Verification

- 99 focused expectations across the original interval, coupling-audit, and
  reporting suites passed.
- Six PDFs are one-page vector files at 7.2 by 6.6 inches with embedded fonts.
- Six PNGs were produced at 600 DPI and inspected visually.
- MCMC and VB wrappers each compiled in two passes to a clean three-page PDF.
- No unresolved references, box warnings, or LaTeX warnings remained.
- `git diff --check` passed.

## Integration state

`READY_FOR_INTEGRATION`

The coordinator should merge this validation branch, copy only the paths listed
in `article_asset_manifest.csv` into Article-v2, compile both manuscripts, and
publish through the established command-line Git workflow. It should not copy
runtime reports or result trees and should not alter the frozen v10 numbers.
