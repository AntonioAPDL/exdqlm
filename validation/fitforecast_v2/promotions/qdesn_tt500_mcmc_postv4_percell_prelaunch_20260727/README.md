# Q-DESN 500-Observation MCMC Post-v4 Per-cell Prelaunch

- generated_at: `2026-07-27 21:50:07.866549`
- stage_file: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell`
- launch_status: `prepared_not_launched`
- source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- unresolved cells: `15`
- target MCMC specs: `90`
- workers prepared: `16`

## Decision

This launch materialization implements the reviewed post-v4 per-cell plan.
It launches all 15 unresolved cells and all six arms per cell, for 90
reduced-budget MCMC specifications. The goal is metric-gap calibration, not
a global DESN specification.

## Cell Plan

| priority_rank | family | tau | likelihood_target | primary_gap | current_worst_ratio | n_candidates | cell_status | launch_status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | normal | 0.05 | al | forecast_mae | 1.95305779354387 | 6 | forecast_dominated | prepared_not_launched |
| 2 | normal | 0.05 | exal | fit | 1.2821232272294 | 6 | fit_dominated | prepared_not_launched |
| 3 | normal | 0.25 | al | forecast_mae | 1.15877506366042 | 6 | forecast_dominated | prepared_not_launched |
| 4 | normal | 0.25 | exal | forecast_mae | 1.41174487173136 | 6 | forecast_dominated | prepared_not_launched |
| 5 | normal | 0.5 | al | forecast_mae | 2.20546875963638 | 6 | forecast_dominated | prepared_not_launched |
| 6 | normal | 0.5 | exal | forecast_mae | 2.11384255503987 | 6 | forecast_dominated | prepared_not_launched |
| 7 | laplace | 0.05 | al | fit | 1.45313858121741 | 6 | fit_dominated | prepared_not_launched |
| 8 | laplace | 0.05 | exal | fit | 1.75996698344217 | 6 | fit_dominated | prepared_not_launched |
| 9 | laplace | 0.25 | al | fit | 1.31750130695349 | 6 | fit_dominated | prepared_not_launched |
| 10 | gausmix | 0.05 | al | fit | 1.2077432818807 | 6 | fit_dominated | prepared_not_launched |
| 11 | gausmix | 0.05 | exal | fit | 1.38894113650221 | 6 | fit_dominated | prepared_not_launched |
| 12 | gausmix | 0.25 | al | fit | 1.36440023565633 | 6 | fit_dominated | prepared_not_launched |
| 13 | gausmix | 0.25 | exal | forecast_mae | 1.57433601985176 | 6 | forecast_dominated | prepared_not_launched |
| 14 | gausmix | 0.5 | al | forecast_mae | 1.42637302779026 | 6 | forecast_dominated | prepared_not_launched |
| 15 | gausmix | 0.5 | exal | forecast_mae | 1.43706994629525 | 6 | forecast_dominated | prepared_not_launched |

## Gates

- Prepare-only must resolve all 90 specs.
- Smoke runs one MCMC spec before full launch.
- Full screen runs in detached tmux only after the config state is committed.
- Storage-light settings remain active.
- No article table update is implied by this launch.

## Prepared Inputs

- profiles: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_profiles.csv`
- assignments: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_cell_assignments.csv`
- defaults: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_defaults.yaml`
- grid: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_grid.csv`
- target specs: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_target_spec_ids.csv`
- materialization manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_materialization_manifest.json`
