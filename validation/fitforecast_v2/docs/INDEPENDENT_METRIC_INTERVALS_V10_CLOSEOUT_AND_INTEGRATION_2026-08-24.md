# Independent Single-Quantile Metric Intervals v10: Closeout and Integration

Date: 2026-08-24

## Scope and decision

This record unifies the design, execution, closeout, scientific interpretation,
and article-integration contract for the independent Q-DESN/DQLM posterior
metric-interval campaign. It supersedes planning notes only for publication of
metric uncertainty. It does not alter the case-specific specifications selected
by article v9, refit a different model, or touch Joint Q-DESN, PriceFM, GloFAS,
or application results.

The campaign is complete and the compact packet is
`READY_FOR_INTEGRATION`. No additional computation is required before article
integration. Article v9 remains the rollback authority.

## Completed production audit

| Component | Complete | Failed | Remaining |
|---|---:|---:|---:|
| DQLM/exDQLM VB | 18/18 | 0 | 0 |
| Q-DESN/exQ-DESN VB | 18/18 | 0 | 0 |
| DQLM/exDQLM MCMC | 54/54 | 0 | 0 |
| Q-DESN/exQ-DESN MCMC | 108/108 | 0 | 0 |
| **Total** | **198/198** | **0** | **0** |

The run contains 90 replay identities, 270 source--metric summaries, 216
article metric roles, and 72 article rows. VB summaries use 10,000 draws per
source. MCMC summaries pool 4,000 deterministic retained draws from each of
three chains, for 12,000 equally weighted draws per source. All eleven closeout
checks pass. No fitted-model `.rds`, `.rda`, or `.RData` payload is retained.

## Scientific estimand

For each retained conditional-quantile draw, the campaign recomputes fitting
RMSE, rolling-origin forecast MAE, and forecast check loss on the frozen article
evaluation grid. The displayed center is the posterior mean of the resulting
draw-wise metric and the interval is its equal-tailed 95 percent credible
interval. This is distinct from applying a nonlinear metric to a posterior
point path:

\[
  \operatorname{E}\{L(q^{(b)})\mid y\}
  \ne
  L[\operatorname{E}\{q^{(b)}\mid y\}]
\]

in general. The v10 center can therefore differ from the v9 scalar even though
the model, data, and evaluation grid are unchanged. Mixing v9 centers with v10
intervals is prohibited.

The intervals condition on the fixed simulated data set, evaluation grid, and
case-specific reservoir realization. They do not represent repeated-simulation
uncertainty, reservoir-design uncertainty, or response-predictive uncertainty.
VB intervals are explicitly labeled approximate.

## Diagnostic interpretation

Of 162 MCMC source--metric diagnostics, 159 pass and 3 are warnings. Two warning
metrics contribute to displayed cells: exDQLM Gaussian-mixture forecast MAE at
`p=0.25` and Q-DESN exAL--RHS Gaussian-mixture forecast check loss at `p=0.25`.
The third warning belongs to a source metric that is not selected for its
article role. Warnings are marked at the metric-cell level and are disclosure
fields, not exclusion rules.

The Q-DESN forecast-MAE posterior intervals are materially wider than the
DQLM/exDQLM intervals. Their median interval width is approximately 190 percent
of the posterior mean under both AL--RHS and exAL--RHS, compared with 8.7
percent for DQLM and 1.2 percent for exDQLM. Because chain diagnostics are
otherwise strong, this is interpreted as conditional forecast-path uncertainty
under nonlinear propagation rather than a general chain-mixing failure.

## Result pattern

Across the 27 MCMC family--quantile--metric cells, the lowest posterior mean is
attained by Q-DESN exAL--RHS in 11 cells, Q-DESN AL--RHS in 8, DQLM in 4, and
exDQLM in 4. Thus a Q-DESN variant has the lowest displayed posterior mean in
19 of 27 cells. All 27 MCMC winner intervals overlap the runner-up interval;
the manuscript may describe posterior-mean rankings but must not claim decisive
posterior separation.

## Frozen promotion packet

Promotion id:
`qdesn_dqlm_500obs_metric_intervals_v10_20260824`

Run id:
`independent_metric_intervals_v1_production_20260823_225856`

Execution and promotion implementation commit:
`e7479a930f5c9c56fa315ad18cbab9f73016c8b4`

Key hashes:

| Artifact | SHA-256 |
|---|---|
| v10 interface | `9d845ad06686b82c5ce57b2762784d92da7a846990843f9e9fd9a0d445b061b4` |
| promotion file ledger | `0a11fde26fe963c91cda7b326ff04211b1bd5e3cad9b083f84b8b38dcfc3d298` |
| article asset manifest | `2c268d5cac16fc151e384a9311a59579276e1dec094a84f0d2421ea956e0a248` |
| promotion manifest | `b8b6006666a9167d1fea3a2ac76a90d7bde30dcbac5fab6bc21f4b3e716c5798` |

The tracked packet contains the interface, source summaries, role ledger,
MCMC diagnostics, job audit, closeout checks, nine article assets, and a
complete hash ledger. The compact payload is 603,734 bytes. The 1.5 GB runtime
draw archive remains ignored and is not required by Overleaf.

## Article integration contract

1. Merge this validation branch into the shared validation authority before
   merging the article branch.
2. Pin the promotion id, promotion-manifest hash, interface hash, ledger hash,
   estimator id, draw counts, and v9 rollback authority in the Article-v2
   configuration.
3. Verify all promotion-ledger hashes before copying or rendering an asset.
4. Replace the three scalar MCMC family tables with the v10 posterior metric
   interval tables. Place the three VB companion tables in the supplement.
5. Replace scalar-estimator prose throughout the single-quantile criteria,
   results, and supplementary sections. Do not retain v9 numeric-improvement
   claims beside v10 centers.
6. State that boldface ranks posterior metric means and that interval overlap
   prevents a claim of posterior separation.
7. Retain v9 artifacts as a tracked rollback surface, but remove their inputs
   from the active manuscript path.
8. Run the strict article builder/checker, compile the main article and
   supplement to reference convergence, and inspect all six tables for width,
   clipping, warning markers, and label consistency.
9. Publish only through the Article Q-DESN integration workflow. The scientific
   lane does not merge Article-v2 `main` or push an Overleaf snapshot.

## Why this is the preferred path

The campaign replays every article-v9 metric source under one predeclared
draw-wise estimator. It avoids selective interval construction, preserves
case-specific model selection, and separates posterior uncertainty from
repeated-simulation uncertainty. Reusing the completed draws is both more
efficient and more defensible than refitting. Freezing a compact, hashed packet
before article editing makes the update reproducible while preserving an exact
rollback.

Final status: `READY_FOR_INTEGRATION`.
