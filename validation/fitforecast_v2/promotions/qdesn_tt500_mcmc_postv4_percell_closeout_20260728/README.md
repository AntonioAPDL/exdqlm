# Q-DESN MCMC Post-v4 Per-cell Closeout

- Promotion id: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728`
- Parent metric envelope: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727`
- Run tag: `qdesn-tt500-mcmc-postv4-percell-full-20260727__git-786905f`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Materialization commit: `786905f57e65c737409270cb49b1ab903b4bfefc`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Completed roots: `90/90`
- Kept MCMC iterations per root: `8000`
- Signoff mix: `10 PASS`, `27 WARN`, `53 FAIL`
- Target cells: `15`
- Candidates per cell: `6`
- Material target-cell improvements: `3`
- Material metric-wise envelope promotions: `4` across `3` cells
- Refreshed envelope rows: `36/36`
- Unresolved post-v4 cells: `15`
- Heavy payloads retained in post-v4 trees: `0`

## Decision

The post-v4 per-cell MCMC run completed cleanly and is storage-light. This
closeout uses a status-agnostic but material metric policy: WARN and FAIL
rows can improve a metric, but every promotion retains source status, signoff
grade, and source hashes. Floating-point ties are not treated as promotions.

The run produced four material metric-wise envelope updates across three
cells. Most of the post-v4 surface is diagnostic rather than promotable, so
the next step should not replay the same v4/post-v4 design.

## Main Artifacts

- Post-v4 candidate metrics: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_postv4_candidate_metrics.csv`
- Target-cell winners: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_target_cell_best.csv`
- Target metric promotions: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_target_metric_promotions.csv`
- Metric-wise promotions: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_metricwise_promotions.csv`
- Refreshed article-envelope candidate: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_refreshed_article_envelope.csv`
- Unresolved cells: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_unresolved_cells.csv`
- Next-screen handoff: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_next_screen_handoff.csv`
- Non-repeat audit: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728_nonrepeat_audit.csv`

## Non-repeat Guard

Do not relaunch the metric-gap v4 or post-v4 per-cell surfaces as a broad
screen. They should only be reused as explicit confirmation controls. New
screens must be case-specific and must state a new hypothesis: either a
fit-first redesign for fit-dominated cells or a forecast-stability redesign
for rolling-origin forecast-dominated cells.

## Article Decision

This closeout prepares validation-side evidence only. It does not update the
article repository. Article refresh remains a separate lane and should only
consume the refreshed envelope after explicit article-side approval.
