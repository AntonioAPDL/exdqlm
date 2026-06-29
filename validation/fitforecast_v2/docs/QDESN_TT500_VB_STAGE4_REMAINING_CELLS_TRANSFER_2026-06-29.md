# Q-DESN TT500 VB Stage 4A Remaining-Cell Transfer

## Purpose

Stage 4A is a narrow VB-only transfer lane for the remaining weak Q-DESN TT500 fit+forecast cells. It tests whether the compact Stage 3 winning profile pair generalizes before launching any wider screen.

This stage is not MCMC, not TT5000, and not article-facing until strict audit and explicit promotion.

## Current Article TT500 VB Diagnosis

The Article TT500 summary shows three Q-DESN VB cells already beating the best exDQLM/DQLM VB baseline on the primary fit+forecast metrics:

- `gausmix tau=0.25`
- `normal tau=0.25`
- `normal tau=0.50`

The unresolved transfer targets are:

| family | tau | main issue |
|---|---:|---|
| `gausmix` | 0.05 | forecast metrics trail baseline |
| `gausmix` | 0.50 | forecast metrics trail baseline |
| `laplace` | 0.05 | near-miss forecast metrics |
| `laplace` | 0.25 | forecast metrics trail baseline |
| `laplace` | 0.50 | forecast metrics trail baseline |
| `normal` | 0.05 | forecast metrics trail baseline |

## Transfer Profiles

Stage 4A transfers only the compact Stage 3 winning pair:

| role | profile id |
|---|---|
| primary | `tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` |
| backup | `tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3` |

Both profiles use:

- `D = 1`
- `n_each = 30`
- `m = 15`
- `readout_y_lags = 15`
- `reservoir_lags = 0`
- `pi_w = 0.03`
- `pi_in = 0.30`
- `p_over_n_tt500 = 0.102`

Expected full Stage 4A scope without sentinels:

- `6` target family/tau cells
- `2` transfer profiles
- `12` Q-DESN VB roots

## Reproducibility Contract

Stage 4A must use:

- shared validation worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- Article summary input: `/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv`
- source profile registry: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue_profiles.csv`
- base defaults: `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue_defaults.yaml`
- source registry and rolling-origin protocol unchanged from shared fit+forecast v2
- VB only
- RHS-NS prior only
- TT500 only
- storage-light outputs only

## Generated Stage Files

Materialization writes:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_materialization_manifest.json`

Diagnostics write under:

- `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer/materialization_diagnostics`

## Commands

Materialize only:

```bash
cd /data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0
Rscript scripts/materialize_qdesn_tt500_vb_stage4_remaining_cells_transfer.R --workers 12
```

Prepare-only:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_stage4_remaining_cells_transfer.R \
  --workers 12 \
  --prepare-only \
  --run-tag qdesn-tt500-vb-stage4-transfer-prepare-20260629
```

Smoke plus full Stage 4A transfer:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_stage4_remaining_cells_transfer.R \
  --workers 12 \
  --skip-materialize \
  --smoke \
  --full \
  --run-tag qdesn-tt500-vb-stage4-transfer-full-20260629
```

## Promotion Criteria

A Stage 4A profile/cell result can be promoted only if the completed strict-audited run beats the best exDQLM/DQLM VB baseline on all primary metrics for that cell:

- fit qtrue RMSE
- fit pinball
- rolling-origin forecast qtrue MAE
- rolling-origin forecast pinball

Near-misses should be documented but not promoted without explicit approval.

## If Stage 4A Does Not Solve Everything

Run a later Stage 4B targeted VB expansion only for the remaining failed cells. The expansion should stay centered on the compact winning profile family and avoid a full Cartesian grid.

Recommended expansion families:

- `D = 1` first, `D = 2` only for unresolved cells
- `n_each in {20, 30, 40, 50, 70}`
- `alpha in {0.01, 0.015, 0.02, 0.03, 0.04, 0.05}`
- `rho in {0.35, 0.40, 0.45, 0.50, 0.55, 0.60}`
- `m/readout_y_lags in {10, 15, 20, 30}`
- `reservoir_lags = 0` first
- `pi_w in {0.02, 0.03, 0.05}`
- `pi_in in {0.30, 0.60, 0.80}`

Keep Stage 4B VB-only and cell-specific. Do not launch MCMC based on Stage 4A alone.
