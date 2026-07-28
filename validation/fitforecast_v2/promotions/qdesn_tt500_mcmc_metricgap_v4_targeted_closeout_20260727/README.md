# Q-DESN MCMC Metric-Gap v4 Targeted Closeout

- Promotion id: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727`
- Parent metric envelope: `qdesn_dqlm_500obs_mcmc_metric_envelope_20260727`
- Run tag: `qdesn-tt500-mcmc-metricgap-v4-targeted-full-20260727__git-4f42747`
- Validation branch: `validation/shared-fitforecast-v2-1.0.0`
- Materialization commit: `4f427473920d88d014e4e9e0fbae9dfebb30e3c1`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Completed roots: `75/75`
- Target cells: `15`
- Target-cell improvements: `6`
- Metric-wise envelope promotions: `7` across `6` cells
- Refreshed envelope rows: `36/36`
- Unresolved post-v4 cells: `15`
- Heavy payloads retained in v4 trees: `0`

## Decision

The v4 targeted MCMC run completed cleanly and is storage-light. The closeout
uses the requested status-agnostic metric policy: metric improvements are
eligible even when a candidate has WARN or FAIL signoff, but the signoff grade
is retained in every table. This run produced six improved target cells and
seven metric-wise envelope updates. Non-improving v4 candidates are kept as
diagnostic evidence only and do not replace earlier envelope entries.

## Main Artifacts

- V4 candidate metrics: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_v4_candidate_metrics.csv`
- Target-cell winners: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_target_cell_best.csv`
- Target metric promotions: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_target_metric_promotions.csv`
- Metric-wise promotions: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_metricwise_promotions.csv`
- Refreshed article envelope candidate: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_refreshed_article_envelope.csv`
- Unresolved cells: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_unresolved_cells.csv`
- Next-screen handoff: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_next_screen_handoff.csv`
- Manifest: `qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727_manifest.json`

## Next Scientific Move

Use the unresolved-cell handoff as a diagnostic/candidate-selection table, not
as a launch file. The next design should be case-specific and should break away
from repeating the same tradeoff surface: fit-dominated cells need fit-first
capacity/memory redesign with stronger shrinkage and multi-seed confirmation;
forecast-dominated cells need rolling-origin stability and joint memory/rho/alpha
redesign with fit guardrails.
