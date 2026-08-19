# Post-M0 Forecast-First Canonical Confirmation V1

Date: 2026-08-18

## Scope

This protocol closes the independent single-quantile Q-DESN post-M0 legacy
recheck. It does not modify Joint Q-DESN, PriceFM, GloFAS, or article files.
The authoritative article-v6 metric envelope remains frozen until confirmation
and a separate integration handoff.

## Frozen evidence

The campaign `qdesn_postm0_legacy_recheck_v1_20260814_prod1` completed 177 of
177 mandatory jobs: 2 smoke, 5 calibration, 90 discovery, 20 replication, and
60 sealed-holdout jobs. All jobs succeeded and all 30 sealed verification
checks passed. No fitted-model binary payload remains.

One candidate survived all four unseen sealed sources:

- target: `exal_gausmix_t0p25`;
- candidate: `plrv1_exal_gausmix_t0p25_08_576957a0bd`;
- objective: `forecast_qtrue_mae_H1000`;
- mean paired ratio: `0.912527917430575`;
- median paired ratio: `0.902204037407049`;
- improved sources: 4 of 4;
- maximum paired ratio: `0.999969659145608`.

The frozen DESN/RHS profile is `D=1`, `n=4`, `m=2`, `alpha=0.001`,
`rho=0.88`, and `tau0=1e-7`. The inference method is exact exAL M0,
`M0_v_collapsed_support_logit`.

## Primary estimand and decision

Forecast performance is the sole promotion criterion. For canonical chain
`c`, let

```text
R_c = forecast_MAE_candidate,c / forecast_MAE_article_v6.
```

The predeclared promotion statistic is the arithmetic mean of the three
canonical candidate forecast MAEs. Promote the metric if and only if:

1. all three jobs execute correctly;
2. all three forecast MAEs are finite and use the frozen aligned protocol; and
3. the three-chain mean forecast MAE is strictly below article v6.

No minimum effect-size threshold is imposed. Median performance, fit RMSE,
forecast check loss, ESS, autocorrelation, Geweke statistics, half-chain drift,
and PASS/WARN/FAIL signoff grades are retained as descriptive evidence but do
not veto a strict forecast-MAE improvement. This status-agnostic rule applies
only to diagnostic mixing grades. Crashes, nonfinite output, source drift,
index misalignment, configuration drift, or a method other than exact M0 remain
hard execution-integrity failures.

The article-facing update is metric-specific. A forecast-MAE promotion does not
replace fit RMSE or forecast check loss unless those fields independently enter
a later promotion ledger.

## Canonical execution contract

| Property | Frozen value |
|---|---|
| Chains | 3 |
| Burn-in per chain | 5,000 |
| Retained iterations per chain | 20,000 |
| Thinning | 1 |
| Threads per chain | 1 |
| Likelihood | exAL |
| exAL method | exact M0 |
| Forecast window | 1,000 observations |
| Leads | 1 through 30 |
| Origin stride | 30 |
| Refit per origin | false |
| Primary metric | oracle-quantile forecast MAE |
| Canonical registry hash | `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275` |

The three chains run concurrently on one core each. A resource gate requires
three idle cores, sufficient memory, and sufficient disk. Heartbeats are emitted
every 30 minutes. A completed job with a matching configuration hash is reused
when the same launch is resumed.

## Outputs

The closeout must retain:

- canonical source and window registries;
- confirmation plan and configuration hashes;
- per-chain primary and secondary metrics;
- lead-level forecast metrics;
- signoff grades and reasons;
- forecast-first promotion ledger;
- verification and runtime tables;
- artifact hash manifest; and
- final closeout decision.

Fitted draws and `.rds`, `.rda`, or `.RData` payloads are forbidden after each
job finishes. Diagnostics and compact metrics remain.

## Final disposition

If the strict forecast criterion passes, emit
`CONFIRMED_FORECAST_GAIN_READY_FOR_METRIC_SPECIFIC_PROMOTION`. Otherwise emit
`NO_CANONICAL_FORECAST_GAIN_RETAIN_V6`. Article modification and publication
remain manual integration steps after the scientific lane is frozen, committed,
pushed, and handed to the Article Q-DESN integration chat.
