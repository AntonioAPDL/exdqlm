# Q-DESN 500-Observation VB Baseline Freeze And Diagnostic Disposition

- generated_at: `2026-07-15 02:07:18.208288`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- head: `e7d7704c476717ab647ff6b1b71baf78097ec05a`
- baseline_freeze_csv: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_active_baseline_freeze_20260715.csv`
- screen_disposition_csv: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_screen_disposition_20260715.csv`
- manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_baseline_freeze_manifest_20260715.json`

## Scope Implemented

Only items 1 and 2 from the next-step plan are implemented here.

1. Freeze `qvbm1` as the active Q-DESN VB calibration baseline for future screen comparisons.
2. Treat `qvbm2` and `qvbm2p3` as completed diagnostic screens, not as MCMC handoff or article-facing sources.

No broad screen is launched by this artifact. No MCMC handoff is opened by this artifact. No Article-Q-DESN files are modified by this artifact.

## Audit Diagnosis

- `qvbm1` is complete: `192 / 192` successful roots and `5760 / 5760` forecast lead rows.
- `qvbm1` MCMC promotion cells under the conservative closeout gate: `0`.
- `qvbm2` is terminal: `112` successes, `16` refused failures, `0` remaining.
- `qvbm2` invalid p03-only failure classification: `TRUE`.
- `qvbm2` cells beating qvbm1 all four metrics: `2`; cells beating exDQLM/DQLM all four metrics: `0`.
- `qvbm2p3` is terminal: `16` successes, `0` failures, `0` remaining.
- `qvbm2p3` cells beating qvbm1 all four metrics: `0`; cells beating exDQLM/DQLM all four metrics: `0`.

## Baseline Freeze

| active_vb_calibration_baseline | baseline_role | planned_roots | success_roots | forecast_lead_rows | mcmc_promote_after_review_cells | decision | caveat |
|---|---|---|---|---|---|---|---|
| qvbm1 | active_qdesn_vb_calibration_reference_not_article_facing | 192 | 192 | 5760 | 0 | freeze_as_current_vb_screening_baseline_for_future_design_comparison | not_promoted_to_mcmc_and_not_article_facing; use as calibration baseline only |

## Screen Disposition

| screen | status | role | planned_roots | success_roots | failed_or_refused_roots | remaining_roots | beats_qvbm1_all4_cells | beats_exdqlm_dqlm_all4_cells | promotion_policy |
|---|---|---|---|---|---|---|---|---|---|
| qvbm1 | COMPLETE | ACTIVE_VB_CALIBRATION_BASELINE | 192 | 192 | 0 | 0 |  |  | hold_mcmc; use only as baseline for future VB design comparison |
| qvbm2 | COMPLETE_WITH_REFUSED_INVALID_SURFACE | DIAGNOSTIC_ONLY | 128 | 112 | 16 | 0 | 2 | 0 | do_not_promote; successful rows do not clear external all-four gate; p03 failures refused |
| qvbm2p3 | COMPLETE | DIAGNOSTIC_ONLY | 16 | 16 | 0 | 0 | 0 | 0 | do_not_promote; p03 safe-floor repair succeeded but does not clear qvbm1/exdqlm all-four gates |

## Decision

`qvbm1` is now the active Q-DESN VB calibration baseline for future design comparison. It is not promoted to MCMC and it is not article-facing.

`qvbm2` and `qvbm2p3` are closed diagnostic evidence. They should not seed MCMC directly and should not replace qvbm1 in downstream comparison gates.

## Next Planning Boundary

The next broad screen should be planned separately. It should compare new per-cell candidates against this frozen qvbm1 baseline and the current exDQLM/DQLM VB baselines, with all-four primary metric gates before any MCMC handoff.
