# Q-DESN 500-observation MCMC post-v4 per-cell closeout plan

Date: 2026-07-28

Workstream: independent QDESN/DQLM validation only.

## Scope

This closeout handles the completed post-v4 per-cell Q-DESN MCMC screen:

- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell`
- Run tag: `qdesn-tt500-mcmc-postv4-percell-full-20260727__git-786905f`
- Campaign stamp: `20260727-215608__git-786905f`
- Parent closeout: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727`
- Source registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`

No article files are modified by this plan. No new model fitting is launched.

## Audit result

The run is complete and comparison-ready:

- 90 planned roots
- 90 materialized roots
- 90 successful roots
- 0 failed roots
- 90 H=1000 rolling-origin forecast summaries
- 8000 kept MCMC iterations in every row
- Signoff mix: 10 PASS, 27 WARN, 53 FAIL
- No retained `.rds`, `.rda`, `.RData`, or `__design.rds` payloads in the post-v4 results, reports, or closeout tree

## Promotion rule

The closeout is status-agnostic but not numerically naive:

- WARN and FAIL rows can be metric candidates.
- Every promoted row retains status, signoff grade, run tag, path, hash, and source-registry hash.
- A metric is promoted only if it improves by more than
  `max(1e-8, 1e-6 * abs(previous_value))`.
- Floating-point ties are not treated as scientific improvements.

This materiality rule is important because one apparent post-v4 improvement is a
numerical tie at roughly `1e-12` and should not be promoted.

## Current evidence

Relative to the parent v4 closeout envelope, post-v4 adds four material
metric-wise improvements across three cells:

1. `qdesn_exal_rhs_ns`, `gausmix`, tau `0.25`, fit RMSE.
2. `qdesn_exal_rhs_ns`, `gausmix`, tau `0.25`, forecast MAE.
3. `qdesn_exal_rhs_ns`, `normal`, tau `0.05`, fit RMSE.
4. `qdesn_exal_rhs_ns`, `normal`, tau `0.50`, forecast MAE.

The corresponding primary-target improvements occur in three cells:

1. `qdesn_exal_rhs_ns`, `gausmix`, tau `0.25`, forecast MAE.
2. `qdesn_exal_rhs_ns`, `normal`, tau `0.05`, fit RMSE.
3. `qdesn_exal_rhs_ns`, `normal`, tau `0.50`, forecast MAE.

Most other post-v4 arms are diagnostic regressions or non-improvements.

## Non-repeat decision

The metric-gap v4 and post-v4 per-cell surfaces should not be repeated as broad
screens. They have now served their purpose:

- v4 found several metric-wise gains and became the parent envelope.
- post-v4 tested 90 additional per-cell arms and found only a few material gains.

The next screen must therefore state a new cell-specific hypothesis. Replays of
the same surfaces are allowed only as explicit confirmation controls, not as a
new broad search.

## Implementation artifacts

The closeout materializer writes:

- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_postv4_candidate_metrics.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_combined_candidate_ledger.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_metricwise_promotions.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_refreshed_article_envelope.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_target_cell_best.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_target_metric_promotions.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_unresolved_cells.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_next_screen_handoff.csv`
- `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_nonrepeat_audit.csv`
- source, file, execution, storage, summary, README, and manifest files

## Test contract

The closeout test verifies:

- 90/90 roots completed.
- All rows report 8000 kept iterations.
- Signoff mix is 10 PASS, 27 WARN, 53 FAIL.
- Candidate design is 15 cells with 6 candidates per cell.
- Four material metric-wise promotions are present and exactly identified.
- Three material primary-target improvements are present and exactly identified.
- The refreshed envelope remains 36 rows.
- The source registry hash is unchanged.
- No stale `/home/jaguir26/local/src` or article-repo authority path leaks into the closeout.
- No forbidden heavy payloads are retained.

## Recommendation

Promote the four material metric-wise gains in the validation-side refreshed
envelope, retain all signoff flags, and use the next-screen handoff only as a
diagnostic guide. Do not update the article or launch another screen from this
closeout without a separate explicit task.
