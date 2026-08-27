# Independent Location-Orthogonalized Tau0 V2 Promotion Closeout

Date: 2026-08-27

Final scientific status: `PROMOTION_READY`.

## Scope

This closeout belongs only to the independent single-quantile Q-DESN/DQLM
validation lane. It does not modify or authorize work in the joint-QDESN,
PriceFM, GloFAS, article-main, or Overleaf lanes.

The implementation follows the predeclared ignored tracker:

`validation/fitforecast_v2/local_trackers/INDEPENDENT_LOCATION_ORTHOGONALIZED_TAU0_V2_UNIFIED_PROMOTION_AND_NEXT_PLAN_2026-08-27.md`

The plan's conditional interval-precision branch was exercised. The original
600 retained metric draws narrowly failed the predeclared bootstrap-endpoint
precision gate for forecast check loss. The gate was not weakened. The same
three winner chains were replayed under the same scientific specification and
MCMC budget with 1,000 retained metric draws per chain. The resulting 3,000-draw
packet passed every precision criterion.

## Campaign completion

| Stage | Planned | Successful | Failed | Remaining |
|---|---:|---:|---:|---:|
| Smoke | 2 | 2 | 0 | 0 |
| Initial replication | 4 | 4 | 0 | 0 |
| Discovery screen | 33 | 33 | 0 | 0 |
| Adaptive replication | 4 | 4 | 0 | 0 |
| Canonical confirmation | 9 | 9 | 0 | 0 |
| Interval replay | 3 | 3 | 0 | 0 |
| **Total** | **55** | **55** | **0** | **0** |

Primary run:
`independent-location-orthogonalized-tau0-v2-20260827_005026__git-985bb3e`.

Interval replay:
`independent-location-orthogonalized-tau0-v2-interval-replay-20260827_162303__git-d6bc4c5`.

No process or tmux session from this lane remained active at closeout.

## Confirmed scientific result

The sole promoted case is MCMC Q-DESN AL-RHS for the Gaussian family at
`p = 0.05`. Selection is metric-specific and case-specific; no global DESN
specification is asserted.

| Criterion | Parent v9 | Promoted v11 | Change | Relative gain |
|---|---:|---:|---:|---:|
| Forecast MAE | 6.91659380458911 | 6.73382698952425 | -0.182766815064863 | 2.64244% |
| Forecast check loss | 1.20016989478546 | 1.19120186398605 | -0.008968030799413 | 0.74723% |

Lower is better. The promoted values are three-chain means of the canonical
posterior point-path scores. Fit RMSE was worse for this candidate and is
therefore retained exactly from the v9 metric-specific source. Every other
displayed point metric is inherited unchanged.

The winner is
`idol2_al_normal_t0p05_o1_orthogonalized_3e09_132580d19b`, with:

| Parameter | Value |
|---|---:|
| Depth `D` | 1 |
| States `n` | 40 |
| Memory `m` | 12 |
| `alpha` | 0.08 |
| `rho` | 0.35 |
| `pi_w` / `pi_in` | 0.30 / 0.15 |
| `tau0` | 3e-9 |
| Response / reservoir lags | 1 / 0 |
| Washout | 300 |
| Readout transform | training-only reservoir orthogonalization |

The transform residualizes reservoir columns against the known deterministic
location-feature block using training-window quantities only. It does not use
held-out outcomes or future preprocessing information.

## Posterior metric intervals

The interval replay produces chain-balanced draw-wise metric distributions
from 3,000 retained draws, 1,000 per chain:

| Criterion | Posterior mean | Posterior SD | Equal-tailed 95% CrI | Median |
|---|---:|---:|---:|---:|
| Forecast MAE | 7.173395 | 2.559110 | [2.718086, 12.226008] | 7.035608 |
| Forecast check loss | 1.234977 | 0.100977 | [1.081647, 1.453692] | 1.221434 |

These intervals describe posterior uncertainty in the aggregate metric under
the fitted model. They are not repeated-simulation confidence intervals. The
posterior means need not equal the primary table scores because the primary
table evaluates the canonical posterior point path, whereas the intervals are
formed by scoring each retained posterior quantile path.

The 3,000-draw replay passed all predeclared stability gates:

| Criterion | MAE | Check loss | Limit |
|---|---:|---:|---:|
| Maximum leave-one-chain-out mean shift / pooled SD | 0.02407 | 0.01928 | 0.20 |
| Maximum leave-one-chain-out endpoint shift / width | 0.01814 | 0.01146 | 0.15 |
| Maximum bootstrap endpoint MCSE / width | 0.00984 | 0.01339 | 0.05 |

Decision: `PASS_USE_RETAINED_3000_DRAWS`.

## Frozen authorities

Point authority:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827`

- 72 interface rows;
- exactly two changed metric cells;
- 214 of 216 point-metric cells retained;
- parent: `qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821`;
- manifest SHA-256:
  `828f81fb714149937e088294ae433897354c7faa0ed941474936873718fb9958`.

Interval authority:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_metric_interval_reporting_v11_1_20260827`

- 216 reporting roles;
- exactly two updated forecast roles;
- 214 roles inherited exactly;
- parent: `qdesn_dqlm_500obs_metric_interval_reporting_v10_1_20260825`;
- decision-manifest SHA-256:
  `a683fb81d187f1d21829664e96f2ff0ce5c0903e987f8944a2418bbd64925357`.

Portable audit packet:

`validation/fitforecast_v2/audits/independent_location_orthogonalized_tau0_v2_20260827`

- 32 hashed evidence files totaling 266,256 bytes;
- no fitted-model binary payloads;
- artifact-manifest SHA-256:
  `96ef4185f314059c354524bc1901067457a4792fc89a3fdd24285ef888c661af`;
- audit-manifest SHA-256:
  `c61d84780145409105d116bcce6e9ef7bf72caac8bc1fdf09bee81df3a6a01fb`.

## Invariance and provenance audit

The exact parent-child comparison passed:

- point interface: 72 rows, two changed metric cells, no other metric changes;
- interval interface: 216 roles, two updated roles, 214 inherited roles;
- updated interval rows cite the interval-replay run tag, not the original
  600-draw campaign tag;
- the promoted forecast sources use repository-relative paths;
- the target row's fit source and 210 non-target interval source locators are
  inherited absolute provenance fields from the frozen v9/v10.1 parents.

Those inherited absolute strings are intentionally left unchanged to preserve
parent invariance. The portable audit packet contains the new requests,
registries, metric draws, hashes, and winner evidence needed by this promotion.

## Figures and article contract

Two article-safe figures were generated and visually inspected:

- `qdesn_validation_500obs_mcmc_forecast_mae_intervals.pdf`;
- `qdesn_validation_500obs_mcmc_forecast_check_loss_intervals.pdf`.

Both are one-page vector PDFs with matching high-resolution PNG previews. The
nine family-by-quantile panels, labels, means, and interval bars are visible
without clipping or overlap.

The integration coordinator, not this scientific lane, owns article changes.
The coordinator should:

1. replace only Gaussian `p = 0.05` MCMC Q-DESN AL-RHS forecast MAE and check
   loss with 6.734 and 1.191 after article rounding;
2. retain the existing fit RMSE and all other table values;
3. update the two MCMC forecast interval figures from the v11.1 assets;
4. state that the point estimates and posterior metric intervals use distinct,
   explicitly documented estimators;
5. preserve the WARN diagnostic disclosure;
6. compile and inspect the article before publishing the article-only snapshot.

## Verification

- Original V2 focused test: 26 expectations passed.
- Promotion/replay focused test: 43 expectations passed.
- Standalone promotion verifier: 8/8 checks passed.
- Exact point and interval invariance audit: passed.
- Figure visual inspection and PDF metadata checks: passed.
- Retained `.rds`, `.rda`, and `.RData` files: 0.
- Active task processes: 0.

## Next scientific decision

No additional screen is authorized by this closeout. First integrate v11/v11.1
so future work uses the correct baseline.

After integration, a later Gaussian `p = 0.05` AL-RHS refinement may explore a
small genuinely new mechanism set around this winner: partial projection,
group-specific RHS scales for deterministic and reservoir blocks, and a local
`tau0` neighborhood around `3e-9`, all subject to a nonrepeat audit.

The Gaussian median AL-RHS and exAL-RHS cells should not receive another broad
capacity, scalar-`tau0`, or full-orthogonalization rerun. Their retained V1/V2
evidence should first be mined for recursive feature drift, blockwise readout
concentration, and fit-to-forecast transfer failure. Exact exAL M0 remains
mandatory for every future exAL MCMC experiment.

Final status: `READY_FOR_INTEGRATION`.
