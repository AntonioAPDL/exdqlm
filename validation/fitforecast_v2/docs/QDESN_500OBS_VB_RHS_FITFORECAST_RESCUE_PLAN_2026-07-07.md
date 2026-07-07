# Q-DESN 500-Observation VB RHS Fit+Forecast Rescue Plan

Date: 2026-07-07

## Purpose

The completed Q-DESN RHS fit-balanced broad VB screen is technically complete, storage-light, and reproducible, but it should not be promoted as a global replacement. The dominant failure mode is not rolling-origin forecast export or storage policy. The scientific bottleneck is fit recovery: no Q-DESN RHS VB candidate in the broad screen beats the current best DQLM/exDQLM VB fit-RMSE baseline across the evaluated family/quantile cells.

This plan prepares a smaller targeted VB-only rescue screen. It is designed for candidate selection before any MCMC spending. It is not article-authoritative until a later freeze/signoff promotes specific rows.

## Evidence Basis

- Completed broad-screen report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad/qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c/20260706-140543__git-4a4975c`
- Primary source table:
  `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- Baseline interface:
  `/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv`
- Source branch:
  `validation/shared-fitforecast-v2-1.0.0`

## Diagnosis

The read-only audit found:

- 2375 successful, comparison-eligible broad-screen VB fit rows;
- 217 rejected/non-rankable rows retained in the rejected-fit ledger;
- 0 globally dominant RHS profiles against current best DQLM/exDQLM VB baselines;
- forecast MAE/check-loss improvements in several Gaussian-mixture and Laplace cells;
- no fit-RMSE wins against the current best DQLM/exDQLM VB baseline;
- normal-family edge cells at tau 0.05 and tau 0.50 still need forecast-MAE rescue.

The next screen should therefore be targeted, not another unconstrained broad sweep.

## Parameter Policy

Use the observed strong region as the center:

- compact reservoirs: mostly `D = 1`, `n_each = 20, 30, 40`;
- limited depth probe for Gaussian-mixture left tail: `D = 2`, `n_each = 20, 30`;
- low-to-moderate dynamics: `alpha` from 0.0015 to 0.05 and matched `rho` from 0.15 to 0.60;
- short memory/readout lags: 10, 15, 20, 30, with 45 only for normal edge forecast rescue;
- sparse readout/input settings: `pi_w` in 0.02 to 0.05 and `pi_in` in 0.20 to 0.50;
- RHS prior scale: primary `tau0 = 1e-4`, limited robustness at `3e-4`;
- explicitly exclude the failed `tau0 = 3e-5` surface.

Expected size with defaults:

- up to 32 profile assignments per family/quantile cell;
- about 276 selected roots under the current evidence surface;
- about 552 VB fits if both AL and exAL are run;
- no MCMC work in this stage.

## Implemented Stage

Stage stub:

`qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue`

Tracked outputs:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue_materialization_manifest.json`

Diagnostic outputs are written under:

`reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue/materialization_diagnostics`

These report outputs are intentionally not article-facing.

## Commands

Materialize only:

```sh
Rscript scripts/materialize_qdesn_tt500_vb_rhs_fitforecast_rescue.R \
  --workers 24 \
  --max-profiles-per-cell 32 \
  --max-p-over-n 0.35
```

Dry-run launch wrapper:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitforecast_rescue.R \
  --dry-run \
  --materialize-only \
  --workers 24 \
  --max-profiles-per-cell 32 \
  --max-p-over-n 0.35
```

Future prepare-only gate:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitforecast_rescue.R \
  --prepare-only \
  --skip-materialize \
  --workers 24
```

Future smoke gate:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitforecast_rescue.R \
  --smoke \
  --skip-materialize \
  --workers 24
```

Future full launch, only after explicit approval:

```sh
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitforecast_rescue.R \
  --full \
  --launch-approved \
  --skip-materialize \
  --workers 24
```

The orchestrator refuses full compute unless both `--full` and `--launch-approved` are supplied.

## Promotion Rule

Do not send candidates to MCMC merely because they improve one forecast metric. A candidate should be considered for MCMC only if it satisfies one of:

- beats the current best DQLM/exDQLM VB baseline on all primary cell metrics;
- closes the fit-RMSE gap materially while preserving forecast MAE and check loss;
- provides a clearly interpretable family/quantile-specific improvement with no storage or diagnostic regression.

Article-facing promotion requires a separate freeze with exact source hashes, branch/commit provenance, interface hashes, and storage-light audit.
