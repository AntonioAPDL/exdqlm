# Q-DESN 500-Observation MCMC Metric-Gap v4 Targeted Prelaunch

- generated_at: `2026-07-27 14:51:23.41899`
- stage_file: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted`
- launch_status: `prepared_not_launched`
- source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- targeted rows above 10% gap: `15/18`
- profiles/specs: `75`
- workers prepared: `24`

## Decision

This is not a global-specification search. The unit of calibration is the
family x quantile x likelihood row because the current envelope shows
different failure modes across cells.

The v4 slate focuses only on rows still more than 10 percent worse than the
current DQLM/exDQLM reference. Cells already within that tolerance band are
frozen. Since earlier compact searches have plateaued, v4 deliberately
tests larger memory, depth, and width, but couples those larger reservoirs
with low alpha, high rho, sparse input/weight probabilities, and much
stronger RHS global shrinkage.

## Cell Plan

| priority_rank | family | tau | likelihood_target | primary_gap | current_worst_ratio | n_candidates | launch_status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | normal | 0.5 | al | forecast_mae | 2.20546875963638 | 5 | prepared_not_launched |
| 2 | normal | 0.5 | exal | forecast_mae | 2.1747358376774 | 5 | prepared_not_launched |
| 3 | normal | 0.05 | al | forecast_mae | 1.95305779354387 | 5 | prepared_not_launched |
| 4 | laplace | 0.05 | exal | fit | 1.75996698344217 | 5 | prepared_not_launched |
| 5 | gausmix | 0.25 | exal | forecast_mae | 1.59776345417472 | 5 | prepared_not_launched |
| 6 | laplace | 0.05 | al | fit | 1.45313858121741 | 5 | prepared_not_launched |
| 7 | gausmix | 0.5 | al | forecast_mae | 1.43850885372652 | 5 | prepared_not_launched |
| 8 | gausmix | 0.5 | exal | forecast_mae | 1.43706994629525 | 5 | prepared_not_launched |
| 9 | gausmix | 0.25 | al | fit | 1.41497074388218 | 5 | prepared_not_launched |
| 10 | gausmix | 0.05 | exal | fit | 1.41249219725034 | 5 | prepared_not_launched |
| 11 | normal | 0.25 | exal | forecast_mae | 1.41174487173136 | 5 | prepared_not_launched |
| 12 | laplace | 0.25 | al | fit | 1.31750130695349 | 5 | prepared_not_launched |
| 13 | normal | 0.05 | exal | fit | 1.2821232272294 | 5 | prepared_not_launched |
| 14 | gausmix | 0.05 | al | fit | 1.22653815185395 | 5 | prepared_not_launched |
| 15 | normal | 0.25 | al | forecast_mae | 1.15877506366042 | 5 | prepared_not_launched |

## Budgets And Gates

- Screening: `n_burn = 2000`, `n_mcmc = 8000`, `thin = 1`.
- Full confirmation: one selected candidate per improved cell with `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`.
- MCMC uses VB initialization, but VB is not used as the final ranking criterion.
- Screening results select candidates only; article promotion still requires closeout and confirmation.
- Diagnostic status is retained even when metric selection is status-agnostic.
- Storage stays light: no routine draws, forecast objects, VB-init payloads, or failure RDS files.

## Prepared Inputs

- profiles: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_profiles.csv`
- assignments: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_cell_assignments.csv`
- defaults: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_defaults.yaml`
- grid: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_grid.csv`
- target specs: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_target_spec_ids.csv`
- materialization manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_materialization_manifest.json`
- gap audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v4_targeted_prelaunch_20260727/qdesn_tt500_mcmc_metricgap_v4_targeted_gap_audit_20260727.csv`
- design: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v4_targeted_prelaunch_20260727/qdesn_tt500_mcmc_metricgap_v4_targeted_design_20260727.csv`
- cell plan: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v4_targeted_prelaunch_20260727/qdesn_tt500_mcmc_metricgap_v4_targeted_cell_plan_20260727.csv`

No prepare-only, smoke, or full compute command was executed by this materialization.
