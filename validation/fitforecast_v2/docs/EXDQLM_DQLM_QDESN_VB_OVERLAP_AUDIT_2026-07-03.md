# exDQLM/DQLM and Q-DESN VB Overlap Audit

Date: 2026-07-03

## Scope

This audit compares the completed exDQLM/DQLM VB forecast-confirmation rows against the current Article-facing Q-DESN VB simulation-study rows. It is intentionally limited to overlap cells present in the confirmation run; it does not promote unconfirmed exDQLM/DQLM cells.

## Inputs

- validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- validation branch: `validation/shared-fitforecast-v2-1.0.0`
- validation HEAD at audit generation: `a081f90670b40ce35667200c1d3c9e20c23eef9d`
- validation HEAD subject: `Document exDQLM DQLM VB forecast confirmation`
- exDQLM/DQLM confirmation summary: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260702_exdqlm_dqlm_vb_c0_discount_screen/manifests/top3_forecast_confirmation_summary_20260703.csv`
- Article-facing summary read-only input: `/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv`
- reproducible CSV output: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/exdqlm_dqlm_qdesn_vb_overlap_comparison_20260703.csv`

## Evidence Counts

- confirmed exDQLM/DQLM PASS rows: `21`
- confirmed model/family/tau winners compared here: `7`
- winners that improve the old Article exDQLM/DQLM forecast check where an old row exists: `6/7`
- cells where the current Q-DESN VB best row has lower forecast check than the confirmed exDQLM/DQLM winner: `4/7`
- cells eligible for narrow MCMC follow-up under the audit rule: `2/7`

## Overlap Comparison

| Family | Tau | Model | Candidate | Fit RMSE | Forecast MAE | Forecast check | Q-DESN comparator | Q-DESN fit RMSE | Q-DESN forecast MAE | Q-DESN forecast check | Check ratio vs Q-DESN | Recommendation |
| --- | ---: | --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- |
| gausmix | 0.50 | dqlm | `c13_trend100_season1_df0995s099` | 1.598 | 1.840 | 5.541 | Q-DESN exAL RHS | 2.669 | 1.387 | 5.443 | 1.018 | promote as improved VB baseline only; do not launch broad MCMC |
| gausmix | 0.50 | exdqlm | `c13_trend100_season1_df0995s099` | 1.595 | 1.859 | 5.542 | Q-DESN exAL RHS | 2.669 | 1.387 | 5.443 | 1.018 | promote as improved VB baseline only; do not launch broad MCMC |
| laplace | 0.05 | dqlm | `c13_trend100_season1_df0995s099` | 4.591 | 3.644 | 1.868 | Q-DESN exAL RHS | 8.349 | 3.038 | 1.879 | 0.994 | defer MCMC; run targeted laplace-left-tail VB screen first |
| laplace | 0.05 | exdqlm | `c13_trend100_season1_df0995s099` | 8.498 | 9.354 | 2.146 | Q-DESN exAL RHS | 8.349 | 3.038 | 1.879 | 1.142 | defer MCMC; run targeted laplace-left-tail VB screen first |
| normal | 0.25 | dqlm | `c13_trend100_season1_df0995s099` | 2.404 | 2.513 | 3.371 | Q-DESN exAL RHS | 2.987 | 1.715 | 3.287 | 1.025 | promote as improved VB baseline only; do not launch broad MCMC |
| normal | 0.50 | dqlm | `c13_trend100_season1_df0995s099` | 1.923 | 1.109 | 4.022 | Q-DESN exAL RHS | 2.696 | 2.005 | 4.079 | 0.986 | eligible for narrow MCMC follow-up if a matched VB/MCMC counterpart is required |
| normal | 0.50 | exdqlm | `c13_trend100_season1_df0995s099` | 1.988 | 1.125 | 4.023 | Q-DESN exAL RHS | 2.696 | 2.005 | 4.079 | 0.986 | eligible for narrow MCMC follow-up if a matched VB/MCMC counterpart is required |

## Interpretation

- The confirmed exDQLM/DQLM calibration improves the old Article exDQLM/DQLM rows in the overlap cells, especially fit RMSE for normal and gausmix cells.
- The comparison does not support a broad exDQLM/DQLM MCMC launch. Only cells passing the narrow eligibility rule should be considered, and only if the article needs a matched MCMC counterpart.
- Laplace left-tail behavior remains the weakest exDQLM/DQLM area in this evidence set; it should receive a targeted VB screen before any MCMC follow-up.
- Article-facing tables should not consume unconfirmed exDQLM/DQLM rows from this run. Promotion should be cell-specific and tied to the CSV output above.

## MCMC Recommendation

Narrow MCMC may be considered for: `dqlm/normal/0.5`, `exdqlm/normal/0.5`. Do not launch broad exDQLM/DQLM MCMC from this evidence alone.

## Regeneration Command

```bash
Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_qdesn_vb_overlap.R
```
