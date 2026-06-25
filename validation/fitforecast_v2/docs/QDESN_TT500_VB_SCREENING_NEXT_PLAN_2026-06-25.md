# Q-DESN TT500 VB Screening: Audit and Next Plan

Date: 2026-06-25

Worktree:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

Branch:
`validation/shared-fitforecast-v2-1.0.0`

This note records the post-run audit of the first Q-DESN TT500 VB median
screen and the recommended next screening stage before any Q-DESN replacement
validation launch.

## Completed Median Scout

Run tag:
`qdesn-tt500-vb-screen-median-scout-200draw-20260625-045828__git-437dc73-dirty`

Campaign report root:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/qdesn-tt500-vb-screen-median-scout-200draw-20260625-045828__git-437dc73-dirty/20260625-045959__git-437dc73`

Campaign results root:
`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/qdesn-tt500-vb-screen-median-scout-200draw-20260625-045828__git-437dc73-dirty/20260625-045959__git-437dc73`

Completion evidence:

- Finished at `2026-06-25 06:21:44`.
- `189/189` roots succeeded.
- `189/189` fits succeeded.
- `189/189` fit signoffs were `PASS`.
- Campaign recommendation:
  `COMPARISON_READY_QDESN_DYNAMIC_EXDQLM_COMPLETE`.
- Per-fit forecast lead metrics exist for `189/189` fits.
- Lead metric rows: `5670 = 189 fits x 30 leads`.
- Lead export scale status: `original_scale_backtransformed` for all rows.
- Storage footprint: results about `329M`, reports about `3.0M`.
- Binary diagnostic payloads: `189` small `rhs_trace.rds` files, about
  `4.24M` total.

## Diagnosis

The median scout is operationally successful, but it is not sufficient as a
final Q-DESN model-selection result.

1. Forecast metrics are present but not campaign-lifted.

   The campaign-level `campaign_fit_summary.csv` has `forecast_*` scalar
   columns, but those are `NA`. The valid rolling-origin metrics are in each
   fit's `tables/forecast_lead_metrics.csv`. Any ranking or article-facing
   interface must aggregate these lead metrics explicitly.

2. The `tau0` axis is not informative in this run.

   The grid contained `63` profile ids but only `21` unique reservoir profile
   bases after removing the `_tau0_*` suffix. For all `63/63`
   family/profile-base groups, train and holdout metrics were identical across
   `tau0 = 1e-3, 1e-4, 1e-5`. Inspected `fit_request.json` files confirm the
   requested `tau0` reached the config, but fitted RHS diagnostics were
   identical for matched reservoir profiles (`tau`, `lambda_med`,
   `E_invV_med`, and `beta_l2` unchanged). Therefore the next screen should
   not spend compute on duplicated `tau0` values unless a dedicated canary
   first proves that a revised prior-scale parameterization changes fitted
   diagnostics.

3. Compact reservoirs dominate the useful region.

   After aggregating fit recovery and rolling-origin forecast metrics and
   collapsing exact `tau0` duplicates, the best profiles are concentrated in
   small to moderate readout dimensions (`p/n` about `0.086` to `0.206`).
   Larger `p/n` profiles are not needed for the next stage.

4. Median-only performance is useful but not final.

   The median screen is a good scout because it is cheap and stable, but the
   article-facing validation must compare all target quantiles on the same
   source/window/rolling-origin protocol. Extreme quantiles can reorder
   candidates, especially under non-Gaussian families.

## Candidate Set for Confirmation

The next stage should confirm a compact candidate set across all validation
quantiles, all three families, and the same TT500 rolling-origin protocol.

Primary candidates:

| id | profile base | reason |
|---|---|---|
| C1 | `tt500vb_d2_n30_a0p30_r0p85` | Best cross-family combined fit + rolling-forecast score. |
| C2 | `tt500vb_d1_n50_a0p30_r0p85` | Strong cross-family score with low dimension. |
| C3 | `tt500vb_d1_n30_a0p30_r0p85` | Cheapest strong profile and best normal-family profile. |
| C4 | `tt500vb_d1_n70_a0p30_r0p85` | Strong forecast behavior; moderate dimension. |
| C5 | `tt500vb_d1_n30_a0p10_r0p70` | Best gausmix profile and very cheap. |
| C6 | `tt500vb_d1_n50_a0p10_r0p70` | Best laplace profile; included as a family-robust guard. |

Updated implementation note:

After implementing the lead-aware ranking builder, the confirmation set was
expanded from the hand-written six-profile list to a top-10 set. The top-10
set keeps the strongest score-ranked profiles and the original family-guard
profiles. This is still compact but reduces the risk of overfitting the next
stage to one weighted score.

Run size:

- Profiles: `10`.
- Families: `3` (`gausmix`, `laplace`, `normal`).
- Quantiles: `3` (`0.05`, `0.25`, `0.50`).
- Fit size: `TT500`.
- Method/likelihood/prior: `VB`, `exAL`, `rhs_ns`.
- Total fits: `90`.

This is the best next confirmation screen because it is still small, but large
enough to catch quantile-specific and family-specific reversals.

## Do Not Do Next

- Do not launch the full TT500 replacement validation yet.
- Do not promote the median scout to Article-Q-DESN final tables.
- Do not run another `567`-fit broad screen until the all-quantile confirmation
  shows the candidate set is insufficient.
- Do not spend confirmation budget on the current `tau0` triplicates.

## Required Build Before Confirmation

Before launching the all-quantile confirmation screen, add a storage-light
ranking/interface step that:

1. Reads `campaign_fit_summary.csv`.
2. Validates that every `forecast_lead_metrics_path` exists.
3. Aggregates each fit's 30 lead rows into:
   - all-lead forecast MAE/RMSE/pinball/coverage error,
   - short-lead `L=1:5` MAE and pinball,
   - optional lead-band summaries such as `1:5`, `6:15`, `16:30`.
4. Collapses exact `tau0` duplicates by `family`, `tau`, and profile base.
5. Writes a reproducible profile ranking CSV and Markdown summary.
6. Fails loudly if campaign-level `forecast_*` fields are used while all are
   missing.

Suggested artifact paths:

- `reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/<run_tag>/<stamp>/tables/qdesn_tt500_vb_screen_profile_ranking.csv`
- `reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_tt500_vb_screen/<run_tag>/<stamp>/summary/qdesn_tt500_vb_screen_profile_ranking.md`

## Optional Tau0 Canary

Only run this if prior-scale tuning remains scientifically important.

Purpose:
prove whether a revised prior-scale configuration changes fitted RHS
diagnostics before reintroducing `tau0` as a grid axis.

Minimal canary:

- One family: `normal`.
- One quantile: `0.50`.
- Two profiles: `C1` and `C3`.
- Three prior-scale settings.
- Explicitly record both requested `tau0` and resolved diagnostics:
  `tau`, `lambda_med`, `E_invV_med`, `beta_l2`, `train_qtrue_mae`,
  `holdout_qtrue_mae`, and rolling forecast metrics.

Decision rule:

- If diagnostics and metrics are unchanged to numerical tolerance, drop
  `tau0` from all confirmation and final grids.
- If diagnostics move materially and at least one setting improves validation
  metrics without collapse warnings, run a tiny all-quantile prior-scale
  confirmation before final model selection.

## Confirmation Launch Plan

Implemented runbook:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/QDESN_TT500_VB_ADAPTIVE_SCREENING_RUNBOOK_2026-06-25.md`

After the ranking step is implemented and tested:

1. Materialize a confirmation profile registry containing only C1--C6.
2. Generate a confirmation grid for all three families and all three quantiles.
3. Run prepare-only.
4. Run a one-root smoke.
5. Launch the 54-fit confirmation screen with `20` workers if the machine is
   otherwise available.
6. Audit status, storage, lead metrics, and profile ranking.
7. Freeze one Q-DESN specification for the final TT500 replacement validation.

Expected run duration:

The 189-fit median scout finished in about 82 minutes with 20 workers. A
54-fit confirmation screen should be materially smaller; expected wall time is
roughly 25--40 minutes if per-fit forecast cost is similar.

## Final TT500 Replacement Gate

The final replacement validation may be launched only after:

- confirmation has `SUCCESS/PASS` for all requested fits,
- all quantiles have complete rolling-origin lead metrics,
- the chosen profile is frozen in a versioned config,
- article-facing outputs use the shared schema and source hashes,
- storage-light audit passes,
- stale `/home/jaguir26/local/src` path checks pass,
- and the user explicitly approves the final validation launch.
