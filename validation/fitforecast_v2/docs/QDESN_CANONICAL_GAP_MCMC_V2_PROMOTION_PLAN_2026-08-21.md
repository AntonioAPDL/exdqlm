# Independent Q-DESN canonical-gap MCMC v2 promotion plan

## Scope and authority

This closeout belongs only to the independent single-quantile Q-DESN/DQLM
validation study. It does not modify joint-QDESN, PriceFM, GloFAS, or any
application analysis. The frozen parent authority is
`qdesn_dqlm_500obs_trainonly_article_v8_forecast_gap_adaptive_20260819`.

The completed campaign is
`qdesn-canonical-gap-v2-20260820_003025__git-ec9a921`. It contains 176
successful jobs and no implementation failures: 2 smoke, 4 calibration, 128
screen, 36 refinement, and 6 canonical confirmation jobs. All confirmation
chains used 5,000 burn-in and 20,000 retained iterations with one core per
chain. exAL used exact M0 (`m0_v_collapsed_support_logit`); AL used the frozen
`sigma_then_gamma` transition.

## Promotion estimand

The article authority is metric-specific. A candidate may replace one forecast
criterion without replacing its fit RMSE or any other criterion. The promoted
forecast estimate is the arithmetic mean across the three full-budget
canonical chains. A role is eligible when all three jobs complete successfully,
all values are finite, and the chain mean is strictly below the frozen v8
value. Diagnostic grades are preserved as scientific metadata but are not a
metric-promotion veto, as predeclared for this campaign.

Exactly four roles satisfy this rule:

| Model and case | Criterion | v8 | Confirmed mean | Relative gain |
|---|---|---:|---:|---:|
| Q-DESN AL-RHS, Gaussian, p=0.05 | Forecast MAE | 8.410107 | 6.916594 | 17.76% |
| Q-DESN AL-RHS, Gaussian, p=0.05 | Forecast check loss | 1.220900 | 1.200170 | 1.70% |
| Q-DESN exAL-RHS, Gaussian mixture, p=0.50 | Forecast MAE | 2.562274 | 1.419645 | 44.59% |
| Q-DESN exAL-RHS, Gaussian mixture, p=0.50 | Forecast check loss | 5.610103 | 5.486730 | 2.20% |

No fit-window criterion is eligible. Every other numeric role must remain
identical to v8.

## Reproducibility and storage contract

The v9 packet must freeze:

- the complete 72-row inherited-and-updated article interface;
- the four-role decision, effect, rollback, and cumulative article-delta
  ledgers;
- the two promoted case-specific DESN/RHS specifications;
- all six chain-level metrics and diagnostic grades;
- exact confirmation configs, compact status and metric evidence, and the
  canonical CSV inputs needed to reconstruct scoring;
- stage-level completion evidence for all 176 jobs;
- a source ledger and output manifest with SHA-256 checksums.

No `.rds`, `.rda`, `.RData`, fitted-model object, posterior-draw payload, or
other large transient binary may enter the tracked packet. The ignored runtime
tree remains evidence until integration is complete; it is not required by the
standalone promotion verifier.

## Article integration contract

The validation lane creates and pushes only its dedicated task branch. Article
assets are generated in an isolated Article-v2 task worktree so the unrelated
dirty primary `main` checkout is not touched. The article builder must consume
the complete v9 interface, regenerate all independent-validation tables and the
MCMC comparison figure, and pass strict source/hash checks and both manuscript
compilations.

The final handoff must be labeled `READY_FOR_INTEGRATION`. Only the ARTICLE
QDESN INTEGRATION lane may merge task branches into authoritative `main` and
publish the article-only snapshot to direct Overleaf.
