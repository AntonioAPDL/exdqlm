# Q-DESN/DQLM 500-Observation MCMC Current-Best Promotion

Date: 2026-07-23

This note records the current-best MCMC evidence combiner for the independent Q-DESN/DQLM validation study. It does not launch new model fits.

## Purpose

The Q-DESN VB-candidate MCMC campaign is complete, but not every completed root is clean comparison evidence. The current-best combiner solves the next problem: it merges the completed Q-DESN closeout with prior authoritative Q-DESN and DQLM/exDQLM promotions, keeps provenance, and separates clean comparison rows from diagnostic failures.

## Implementation

Materializer:

`validation/fitforecast_v2/scripts/materialize_qdesn_dqlm_500obs_mcmc_current_best.R`

Rerun command:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript validation/fitforecast_v2/scripts/materialize_qdesn_dqlm_500obs_mcmc_current_best.R
```

Promotion root:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_current_best_20260723`

## Inputs

| source key | rows | role |
|---|---:|---|
| `qdesn_vbcandidate` | 72 | completed 2026-07-23 Q-DESN VB-candidate MCMC closeout |
| `qdesn_alrhs_recalibrated` | 9 | older authoritative Q-DESN AL RHS recalibration, including tau 0.50 |
| `qdesn_legacy_mcmc` | 9 | older Q-DESN MCMC fallback, mainly useful for exAL legacy coverage |
| `exdqlm_dqlm_c13` | 18 | current authoritative DQLM/exDQLM C13 MCMC baseline |

Source hashes are recorded in:

`validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_current_best_20260723/source_manifest.csv`

## Selection Rule

Within each model variant / family / tau / fit-size / inference group:

1. require `comparison_eligible == TRUE` for the clean table;
2. minimize `fit RMSE + H1000 RMSE + H1000 check loss`;
3. retain PASS/WARN as diagnostic labels and use them only as tie-breakers;
4. use source priority and runtime after metric and signoff tie-breakers.

This is intentionally metric-first among clean rows. WARN rows are not hidden; they remain clearly labeled, but they may still be the best clean scientific evidence when their metrics are better.

## Outputs

| file | purpose |
|---|---|
| `qdesn_dqlm_500obs_mcmc_current_best_all_candidates_20260723.csv` | all standardized candidate rows |
| `qdesn_dqlm_500obs_mcmc_current_best_clean_20260723.csv` | clean current-best row per model variant/cell |
| `qdesn_dqlm_500obs_mcmc_current_best_diagnostic_nonclean_20260723.csv` | best non-clean rows retained for diagnosis |
| `qdesn_dqlm_500obs_mcmc_current_best_cell_winners_20260723.csv` | best clean model by family/tau cell |
| `qdesn_dqlm_500obs_mcmc_targeted_relaunch_targets_20260723.csv` | targeted relaunch priorities |
| `qdesn_dqlm_500obs_mcmc_current_best_manifest_20260723.json` | reproducibility manifest |
| `file_manifest.csv` | output hashes |

## Counts

| quantity | count |
|---|---:|
| all standardized candidates | 108 |
| clean current-best rows | 34 |
| Q-DESN clean rows | 16 |
| DQLM/exDQLM clean rows | 18 |
| best non-clean diagnostic rows | 10 |
| family/tau winner rows | 9 |
| relaunch target rows | 6 |

## Current Cell Winners

The current metric-first clean winners by family/tau are:

| family | tau | winner | source | profile/candidate | signoff | objective |
|---|---:|---|---|---|---|---:|
| gausmix | 0.05 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 7.604 |
| gausmix | 0.25 | Q-DESN AL RHS MCMC | Q-DESN VB-candidate closeout | mcvbc_017_al | PASS | 8.948 |
| gausmix | 0.50 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 10.209 |
| laplace | 0.05 | Q-DESN exAL RHS MCMC | Q-DESN legacy MCMC fallback | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | WARN | 11.106 |
| laplace | 0.25 | Q-DESN exAL RHS MCMC | Q-DESN VB-candidate closeout | mcvbc_046_exal | WARN | 7.903 |
| laplace | 0.50 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 8.545 |
| normal | 0.05 | Q-DESN exAL RHS MCMC | Q-DESN legacy MCMC fallback | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | WARN | 7.141 |
| normal | 0.25 | Q-DESN AL RHS MCMC | Q-DESN VB-candidate closeout | mcvbc_060_al | PASS | 8.950 |
| normal | 0.50 | DQLM MCMC | exdqlm/dqlm C13 | c13_trend100_season1_df0995s099 | PASS | 7.997 |

Q-DESN is current-best in 5 of 9 cells by the decision objective. DQLM is current-best in 4 of 9 cells. exDQLM is not the current-best winner in these MCMC cells under this objective.

## Relaunch Diagnosis

A full relaunch is still not justified. The current-best combiner narrows the issue to specific Q-DESN exAL coverage problems.

High-priority targeted MCMC relaunches:

| family | tau | reason |
|---|---:|---|
| gausmix | 0.25 | no clean Q-DESN exAL candidate exists |
| normal | 0.25 | no clean Q-DESN exAL candidate exists |

Optional current-protocol refreshes:

| family | tau | reason |
|---|---:|---|
| gausmix | 0.05 | legacy Q-DESN exAL fallback exists, but current VB-candidate exAL attempts were not clean |
| gausmix | 0.50 | only legacy Q-DESN exAL evidence exists |
| laplace | 0.50 | only legacy Q-DESN exAL evidence exists |
| normal | 0.50 | only legacy Q-DESN exAL evidence exists |

The practical next launch, if any, should therefore be a small exAL-focused MCMC diagnostic relaunch, not a full campaign rerun.

## Article-Facing Guidance

For clean comparison tables:

- Use `qdesn_dqlm_500obs_mcmc_current_best_clean_20260723.csv`.
- Use `qdesn_dqlm_500obs_mcmc_current_best_cell_winners_20260723.csv` to determine metric winners.
- Do not use `qdesn_dqlm_500obs_mcmc_current_best_diagnostic_nonclean_20260723.csv` for winner claims.
- If WARN rows are shown, label them as diagnostically usable but marginal.
- If the article requires only PASS rows in a headline table, generate a PASS-only sensitivity table rather than silently dropping stronger WARN rows.

## Recommendation

Freeze this combined current-best evidence as the decision layer for the current validation state. Then decide whether to run the two high-priority exAL relaunches:

1. gausmix, tau 0.25, Q-DESN exAL RHS MCMC;
2. normal, tau 0.25, Q-DESN exAL RHS MCMC.

Only after those two are resolved should we consider optional current-protocol tau 0.50 refreshes.
