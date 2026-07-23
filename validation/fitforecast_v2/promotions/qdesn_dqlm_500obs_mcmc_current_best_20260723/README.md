# Q-DESN/DQLM 500-Observation MCMC Current-Best Evidence

- Promotion id: `qdesn_dqlm_500obs_mcmc_current_best_20260723`
- Generated: `2026-07-23 18:02:03.518634`
- Git branch: `validation/shared-fitforecast-v2-1.0.0`
- Git commit: `3d69ad8f5b57bd201dca679fd3295ca0fa5ce1c4`

## Selection Rule

Within each model variant / family / tau / fit-size / inference group:

1. use only comparison-eligible rows for the clean table;
2. minimize `fit RMSE + H1000 RMSE + H1000 check loss`;
3. retain PASS/WARN as diagnostic labels and use them only as tie-breakers;
4. use source priority and runtime after the metric and signoff tie-breakers.

Non-clean rows are retained in the diagnostic table and must not be promoted as clean winners.

## Outputs

- All standardized candidates: `qdesn_dqlm_500obs_mcmc_current_best_all_candidates_20260723.csv`
- Clean current-best table: `qdesn_dqlm_500obs_mcmc_current_best_clean_20260723.csv`
- Diagnostic non-clean table: `qdesn_dqlm_500obs_mcmc_current_best_diagnostic_nonclean_20260723.csv`
- Cell winners among clean rows: `qdesn_dqlm_500obs_mcmc_current_best_cell_winners_20260723.csv`
- Targeted relaunch targets: `qdesn_dqlm_500obs_mcmc_targeted_relaunch_targets_20260723.csv`
- Manifest: `qdesn_dqlm_500obs_mcmc_current_best_manifest_20260723.json`

## Counts

- All candidates: `108`
- Clean current-best rows: `34`
- Diagnostic non-clean best rows: `10`
- Cell winners: `9`
- Targeted relaunch targets: `6`
