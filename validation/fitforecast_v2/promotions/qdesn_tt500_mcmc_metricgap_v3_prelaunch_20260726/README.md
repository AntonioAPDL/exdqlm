# Q-DESN 500-Observation MCMC Metric-Gap v3 Prelaunch

- generated_at: `2026-07-26 19:03:47.615373`
- stage_file: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3`
- launch_status: `prepared_not_launched`
- source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- unresolved cells: `16/18`
- profiles/specs: `80`
- workers prepared: `20`

## Decision

This is a per-cell screen. It does not seek one global DESN specification.
The two Laplace median cells already dominate the external reference on all
three article metrics and are frozen. Every other family/tau/likelihood cell
receives its own five-arm slate.

The prior v2 evidence strongly rejects another indiscriminate high-capacity
search: compact one-layer profiles supplied all 18 fit-RMSE winners, 14 of
18 forecast-MAE winners, and 13 of 18 forecast-check winners. The new slate
therefore retains a current metric-source anchor, explores the compact
boundary, tests one small two-layer mechanism, and includes one controlled
moderate-memory bridge with tighter RHS shrinkage.

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
| 16 | laplace | 0.25 | exal | fit | 1.01000628870412 | 5 | prepared_not_launched |

## Budgets And Gates

- Screening: `n_burn = 2000`, `n_mcmc = 8000`, `thin = 1`.
- Full confirmation: one selected candidate per unresolved cell with `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`.
- MCMC uses VB initialization, but VB does not rank or gate the final candidates.
- Screening results cannot be promoted directly to the article.
- Diagnostic status is retained even when metric selection is status-agnostic.
- Storage stays light: no routine draws, forecast objects, VB-init payloads, or failure RDS files.

## Prepared Inputs

- profiles: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_profiles.csv`
- assignments: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_cell_assignments.csv`
- defaults: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_defaults.yaml`
- grid: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_grid.csv`
- target specs: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_target_spec_ids.csv`
- materialization manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_materialization_manifest.json`
- gap audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v3_prelaunch_20260726/qdesn_tt500_mcmc_metricgap_v3_gap_audit_20260726.csv`
- design: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v3_prelaunch_20260726/qdesn_tt500_mcmc_metricgap_v3_design_20260726.csv`
- cell plan: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v3_prelaunch_20260726/qdesn_tt500_mcmc_metricgap_v3_cell_plan_20260726.csv`

No prepare-only, smoke, or full compute command was executed by this materialization.
