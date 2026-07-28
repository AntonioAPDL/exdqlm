# Q-DESN 500-Observation MCMC Metric-Gap v4 Closeout and Next Plan

Date: 2026-07-27

Scope: independent Q-DESN / exQ-DESN versus DQLM / exDQLM simulation-validation study only.
This document does not update article tables and does not launch new compute.

## Evidence Bundle

The v4 targeted MCMC screen is closed out here:

`validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727/`

Primary inputs:

- Run tag: `qdesn-tt500-mcmc-metricgap-v4-targeted-full-20260727__git-4f42747`
- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted`
- Results root: `results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted/qdesn-tt500-mcmc-metricgap-v4-targeted-full-20260727__git-4f42747/20260727-145445__git-4f42747`
- Report root: `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted/qdesn-tt500-mcmc-metricgap-v4-targeted-full-20260727__git-4f42747/20260727-145445__git-4f42747`
- Parent envelope: `validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_metric_envelope_20260727/`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

## Closeout Result

The run completed cleanly and remains storage-light:

| Check | Result |
|---|---:|
| Planned roots | 75 |
| Completed roots | 75 |
| Failed roots | 0 |
| Targeted cells | 15 |
| Target-cell improvements | 6 |
| Metric-wise envelope promotions | 7 |
| Cells with metric-wise promotions | 6 |
| Refreshed envelope rows | 36 |
| Post-v4 unresolved cells | 15 |
| Retained heavy payloads | 0 |

The closeout uses a status-agnostic metric rule, as requested: a metric may be
promoted even if the candidate signoff is WARN or FAIL. The signoff grade,
status, source path, source hash, and run tag remain explicit in the output
tables. Non-improving v4 candidates remain diagnostic evidence and do not
replace earlier metric-envelope entries.

## What Improved

Metric-wise promotions:

| Model | Family | Tau | Metric | Improvement |
|---|---|---:|---|---:|
| Q-DESN AL RHS | gausmix | 0.05 | fit RMSE | 1.53% |
| Q-DESN AL RHS | gausmix | 0.25 | fit RMSE | 3.57% |
| Q-DESN AL RHS | gausmix | 0.25 | forecast check loss | 0.01% |
| Q-DESN AL RHS | gausmix | 0.50 | forecast MAE | 0.84% |
| exQ-DESN exAL RHS | gausmix | 0.05 | fit RMSE | 1.67% |
| exQ-DESN exAL RHS | gausmix | 0.25 | forecast MAE | 1.47% |
| exQ-DESN exAL RHS | normal | 0.50 | forecast MAE | 2.80% |

These are valid local improvements and should be retained in the refreshed
metric envelope candidate:

`qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_refreshed_article_envelope.csv`

They are not a broad enough breakthrough to stop calibration.

## Diagnosis

The v4 screen confirms that the current search surface is partially useful but
too narrow to close the remaining scientific gap:

1. The successful improvements are concentrated in Gaussian-mixture cells and
one normal-median exQ-DESN forecast cell.
2. Laplace cells did not benefit from the v4 high-memory or low-tau0 variants;
some high-capacity variants worsened the target metric substantially.
3. The normal lower-quantile forecast cells remain forecast dominated after v4.
4. Lower tau0 helped in some cells, but it is not a universal rescue. The anchor
arms still won several cells, which means simply increasing depth, memory, or
weight count is not the right next move by itself.
5. All 15 targeted cells remain above the 1.10 external-best worst-ratio
threshold after the refreshed metric envelope, so the next screen should remain
case-specific rather than global.

## Why This Is the Best Next Move

The optimal immediate action is to promote only verified metric-wise gains and
then prepare a new per-cell screen from the unresolved-cell handoff. This avoids
three bad outcomes:

1. Promoting non-improving v4 rows would make the article-facing table worse.
2. Repeating the same v4 surface would spend compute on a pattern that has
already plateaued.
3. Searching for one global Q-DESN specification would contradict the observed
case-specific behavior across family, tau, likelihood, and metric.

Therefore the next launch should be designed from:

`qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_next_screen_handoff.csv`

but should not be launched until we decide the new candidate arms.

## Next-Screen Design Principles

The next screen should be per-cell and should break away from the current
tradeoff surface.

Fit-dominated cells:

- Use fit-first designs with explicit fit RMSE guardrails.
- Keep stronger shrinkage, but avoid assuming `tau0 = 1e-6` is always best.
- Test multi-seed variants of the best anchor/simple designs before adding
  large capacity.
- Add capacity only when paired with stronger shrinkage and stability checks.

Forecast-dominated cells:

- Treat rolling-origin forecast stability as the primary objective.
- Jointly vary memory, spectral radius, alpha/leak, and lag structure.
- Keep a fit guardrail so forecast gains do not come from pathological fit.
- Prefer a small number of diverse, interpretable arms per cell over a wide
  undifferentiated grid.

Laplace cells:

- Do not reuse the v4 high-memory arms as-is.
- Start from the best previous metric-envelope anchors and explore local
  perturbations, then add one or two genuinely different capacity/shrinkage
  arms only if the local anchors remain weak.

Normal median / high-forecast-ratio cells:

- Prioritize forecast dynamics rather than fit.
- Continue from the exQ-DESN tau0-reduced improvement, but require multi-seed
  confirmation before article promotion.

## Required Next Artifacts

Before any new launch, materialize:

1. A post-v4 per-cell diagnostic table with current best, external best, worst
   ratio, and bottleneck metric.
2. A candidate-arm design table with no global-winner assumption.
3. A launch manifest that records source hash, parent closeout id, and all
   per-cell arms.
4. A storage-light contract that keeps scalar metrics, compact paths, logs,
   manifests, and status only.
5. A test that blocks launch if the design is not per-cell or if any active
   path uses `/home/jaguir26/local/src`.

## Current Recommendation

Freeze the v4 closeout as diagnostic/promotion evidence. Do not launch another
screen until the next candidate arms are explicitly materialized and reviewed.
Do not update article tables automatically from this closeout unless the user
asks for a surgical article refresh using the refreshed envelope candidate.
