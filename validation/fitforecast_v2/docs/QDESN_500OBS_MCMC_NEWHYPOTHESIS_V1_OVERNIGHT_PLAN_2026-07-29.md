# Q-DESN 500-Observation MCMC New-Hypothesis v1 Overnight Screen

- Stage: `qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1`
- Promotion/design id: `qdesn_tt500_mcmc_newhypothesis_v1_design_20260729`
- Parent closeout: `qdesn_tt500_mcmc_postv4_percell_closeout_20260728`
- Source registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Roots: `96` MCMC target specs across `15` unresolved cells
- Workers: `16`, one R worker per root
- MCMC budget: `n_burn = 2000`, `n_mcmc = 8000`, `thin = 1`
- Smoke budget: `n_burn = 4`, `n_mcmc = 4` for a single selected root
- Launch policy: prepare-only, smoke, then explicit full detached launch
- Article policy: no article/table update from raw screening output; promote only after closeout.

## Why This Is Different

The post-v4 screen was valid but did not materially resolve 15 cells. This
screen intentionally does not replay the v3/v4/post-v4 high-capacity surface.
It tests lower p/n specifications, stronger RHS shrinkage, period-aware
memory at lags 30, 45, 60, and 90, and one-lag reservoir feedback for
rolling-origin stability.

## Target Cells

- `qdesn_al_rhs_ns`, family `normal`, tau `0.50000000`, primary gap `forecast_mae`, worst ratio `2.205`
- `qdesn_exal_rhs_ns`, family `normal`, tau `0.50000000`, primary gap `forecast_mae`, worst ratio `2.069`
- `qdesn_al_rhs_ns`, family `normal`, tau `0.05000000`, primary gap `forecast_mae`, worst ratio `1.953`
- `qdesn_exal_rhs_ns`, family `laplace`, tau `0.05000000`, primary gap `fit`, worst ratio `1.760`
- `qdesn_exal_rhs_ns`, family `gausmix`, tau `0.25000000`, primary gap `forecast_mae`, worst ratio `1.496`
- `qdesn_al_rhs_ns`, family `laplace`, tau `0.05000000`, primary gap `fit`, worst ratio `1.453`
- `qdesn_al_rhs_ns`, family `gausmix`, tau `0.50000000`, primary gap `forecast_mae`, worst ratio `1.426`
- `qdesn_exal_rhs_ns`, family `gausmix`, tau `0.50000000`, primary gap `forecast_mae`, worst ratio `1.437`
- `qdesn_al_rhs_ns`, family `gausmix`, tau `0.25000000`, primary gap `fit`, worst ratio `1.364`
- `qdesn_exal_rhs_ns`, family `gausmix`, tau `0.05000000`, primary gap `fit`, worst ratio `1.389`
- `qdesn_exal_rhs_ns`, family `normal`, tau `0.25000000`, primary gap `forecast_mae`, worst ratio `1.412`
- `qdesn_al_rhs_ns`, family `laplace`, tau `0.25000000`, primary gap `fit`, worst ratio `1.318`
- `qdesn_exal_rhs_ns`, family `normal`, tau `0.05000000`, primary gap `fit`, worst ratio `1.264`
- `qdesn_al_rhs_ns`, family `gausmix`, tau `0.05000000`, primary gap `fit`, worst ratio `1.208`
- `qdesn_al_rhs_ns`, family `normal`, tau `0.25000000`, primary gap `forecast_mae`, worst ratio `1.159`

## Design Rules

- Calibration is per model variant, family, and quantile; there is no global winner requirement.
- Every generated profile is assigned to exactly one target cell and one likelihood.
- `m` and `readout_y_lags` are capped at 90 to match the frozen period90/m90 source materialization.
- `p_over_n_tt500` is capped at 0.35 for this overnight screen.
- The non-repeat audit rejects exact target-specific repeats from prior TT500 Q-DESN profile catalogs.

## Generated Files

- Defaults: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_defaults.yaml`
- Profiles: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_profiles.csv`
- Cell assignments: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_cell_assignments.csv`
- Grid: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_grid.csv`
- Target spec ids: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_target_spec_ids.csv`
- Manifest: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_materialization_manifest.json`
- Promotion root: `validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_newhypothesis_v1_design_20260729`

## Next Command

Use the orchestrator; it materializes, prepares, smokes, and launches full only with explicit approval:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_newhypothesis_v1.R --full --launch-approved --workers 16
```
