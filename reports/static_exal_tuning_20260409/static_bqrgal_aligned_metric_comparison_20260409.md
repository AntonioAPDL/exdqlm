# Static BQRGAL-Aligned Metric Comparison

Date: 2026-04-09

## Scope

This note summarizes the **fit-performance metric comparison** for the paper-aligned static benchmark, using the metrics that mirror the `bqrgal-examples` evaluation:

- correct inclusion/exclusion (`cie`)
- regression-coefficient RMSE (`beta_rmse_mean`)
- coefficient coverage (`beta_coverage_mean`)
- prediction interval score (`pred_interval_score_mean`)

This comparison is intentionally **metric-based**, not health-gate-based.

## Important Caveat

The benchmark stalled before full completion. The current comparison therefore uses only the **completed matched AL vs exAL pairs** available in the metric files:

- paper-matched core `n = 100`: completed matched rows are currently all at `tau = 0.05`
- extension lane `n = 1000`: only `gausmix / tau = 0.05` currently has matched completed rows

So this is already informative, but it is **not yet a full-paper-grid result**.

## Data Sources

- metrics:
  - `tools/merge_reports/static_bqrgal_aligned_20260408/metrics/`
- comparison outputs:
  - `tools/merge_reports/static_bqrgal_aligned_metric_comparison_20260409/static_bqrgal_aligned_metric_pair_detail_20260409.csv`
  - `tools/merge_reports/static_bqrgal_aligned_metric_comparison_20260409/static_bqrgal_aligned_metric_scenario_summary_20260409.csv`
  - `tools/merge_reports/static_bqrgal_aligned_metric_comparison_20260409/static_bqrgal_aligned_metric_lane_summary_20260409.csv`
- paper-style table logic reference:
  - `bqrgal-examples/data-examples/sim/produce_tables.R`

## Metric Orientation

The comparison direction is:

- `cie`: larger is better
- `beta_rmse_mean`: smaller is better
- `beta_coverage_mean`: closer to `0.95` is better
- `pred_interval_score_mean`: smaller is better

Coverage is therefore evaluated by **distance to 0.95**, not just by whether the raw coverage is larger.

## Main Result

On the completed paper-matched rows, the metric comparison strongly favors **exAL** over **AL**.

### Paper-Matched Core (`n = 100`)

Matched completed pairs: `300`

| Metric | AL | exAL | exAL - AL | Read |
|---|---:|---:|---:|---|
| median `cie` | `0.7182` | `0.8390` | `+0.1156` | exAL better |
| median `beta_rmse_mean` | `0.6572` | `0.4832` | `-0.1739` | exAL better |
| mean coverage | `0.7433` | `0.9408` | `+0.1975` | exAL much closer to `0.95` |
| mean coverage gap to `0.95` | `0.2233` | `0.0732` | `-0.1502` | exAL better |
| median interval score | `24.2132` | `14.9710` | `-8.6447` | exAL better |
| median runtime ratio | `1.00` | `1.63` | `1.63x` | exAL slower |

Rep-level win counts out of `300` matched pairs:

- `cie`: exAL better in `282 / 300`
- `rmse`: exAL better in `284 / 300`
- coverage closeness to `0.95`: exAL better in `224 / 300`
- interval score: exAL better in `299 / 300`

### Extension Lane (`n = 1000`, partial)

Matched completed pairs: `68`

Only `gausmix / tau = 0.05` is currently available here, but the same direction appears:

| Metric | AL | exAL | exAL - AL | Read |
|---|---:|---:|---:|---|
| median `cie` | `0.9998` | `1.0000` | `+0.0002` | tie to tiny exAL edge |
| median `beta_rmse_mean` | `0.1615` | `0.1167` | `-0.0389` | exAL better |
| mean coverage | `0.7224` | `0.9118` | `+0.1893` | exAL much closer to `0.95` |
| mean coverage gap to `0.95` | `0.2320` | `0.0926` | `-0.1393` | exAL better |
| median interval score | `17.5115` | `10.3974` | `-7.0816` | exAL better |
| median runtime ratio | `1.00` | `1.23` | `1.23x` | exAL slower |

## Family-Level Read Within The Completed Paper-Matched Core

Currently completed core scenarios:

- `normal / tau = 0.05 / n = 100`
- `laplace / tau = 0.05 / n = 100`
- `gausmix / tau = 0.05 / n = 100`

All three favor exAL on every paper-style fit metric.

| Family | CIE delta | RMSE delta | Coverage-gap delta | Interval-score delta | Runtime ratio |
|---|---:|---:|---:|---:|---:|
| `normal` | `+0.1065` | `-0.1454` | `-0.1450` | `-8.9263` | `1.60x` |
| `laplace` | `+0.1636` | `-0.3547` | `-0.1668` | `-13.4609` | `1.64x` |
| `gausmix` | `+0.0846` | `-0.1153` | `-0.1388` | `-6.4729` | `1.63x` |

The strongest completed exAL gain is currently the `laplace / tau = 0.05 / n = 100` case.

## Comparison To The Older Broad Validation Read

This metric-based paper-aligned read is materially different from the older `original288 / v7` health-gate comparison:

- old broad validation often had `al` looking better than `exal` on static gate quality
- this paper-aligned metric comparison instead shows **completed paper-matched rows clearly favoring exAL**

The most likely explanation is that the old broad validation was not apples-to-apples:

- different tau grid (`0.95` instead of `0.50`)
- mixed carryforward baseline
- mixed inference regimes
- many accepted static exAL runs using non-paper kernels/settings

By contrast, this benchmark is much closer to the paper setup:

- static only
- `tau = 0.05, 0.25, 0.50`
- MCMC only
- exAL using `slice`
- paper-style fit metrics

## Bottom Line

The current completed paper-aligned metric evidence supports the original expectation much more strongly than the older broad validation did:

- **exAL is outperforming AL on the completed paper-style rows**
- the advantage is visible in **all four** paper-style fit metrics
- the tradeoff is **runtime**, with exAL roughly `1.6x` slower in the completed `n = 100` core

So the surprising old “static AL looks better than exAL” story does **not** appear to hold under the currently completed apples-to-apples paper-aligned metric comparison.

## Remaining Limitation

The result is not yet final because:

- the full paper-matched grid did not complete
- `tau = 0.25` and `tau = 0.50` are still missing from the completed core metric comparison

So the right read is:

- **promising and directionally important**
- **not yet complete enough to serve as the final paper-aligned benchmark conclusion**
