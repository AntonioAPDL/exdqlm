# Q-DESN + exDQLM/DQLM Calibration Resume Plan

Generated: `2026-07-08 02:25:37 EDT`

## Lane Lock

This document belongs only to the shared Q-DESN + exDQLM/DQLM fit+forecast validation worktree. It does not authorize Article-Q-DESN, PriceFM, GloFAS, or joint-QVP work.

## Current Validation Baseline

- branch: `validation/shared-fitforecast-v2-1.0.0`
- commit: `17cf71b001c1c8dd269670180971521d7d890d42`
- package baseline: `exdqlm` 1.0.0
- source registry hash: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- fit window: source indices `8501:9000`
- forecast block: source indices `9001:10000`
- rolling protocol: no refit, state update over observed lags
- maximum lead: `30`; origin stride: `30`

## Validation-Local Baseline

Baseline CSV: `validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv`

The baseline is normalized from validation-side evidence only. No Article-Q-DESN table is used as the source of truth for this calibration lane.

## exDQLM/DQLM Gap Summary

| family | tau | best_fit_rmse_ratio | best_forecast_mae_ratio | best_forecast_check_ratio | recommendation |
| --- | --- | --- | --- | --- | --- |
| gausmix | 0.05 | 2.112 | 1.882 | 1.155 | needs_more_vb_calibration |
| laplace | 0.05 | 1.892 | 3.166 | 1.153 | needs_more_vb_calibration |
| normal | 0.05 | 1.203 | 1.970 | 1.028 | near_or_noninferior |

The low-quantile exDQLM rows remain the main exDQLM/DQLM calibration target. The next pass expands the dynamic prior/discount grid around the tau=0.05 winners and c13 reference, then ranks candidates before any MCMC is considered.

## Q-DESN RHS Gap Summary

| model_variant | family | tau | best_fit_rmse_ratio | best_forecast_mae_ratio | best_forecast_check_ratio | recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| qdesn_al_rhs | gausmix | 0.25 | 2.007 | 0.413 | 0.954 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | gausmix | 0.05 | 1.883 | 0.497 | 0.956 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | laplace | 0.05 | 1.792 | 0.705 | 0.999 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | gausmix | 0.25 | 1.631 | 0.308 | 0.946 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | gausmix | 0.05 | 1.587 | 0.520 | 0.961 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | laplace | 0.05 | 1.582 | 1.160 | 1.027 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | normal | 0.05 | 1.482 | 1.724 | 1.001 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | normal | 0.05 | 1.477 | 1.186 | 0.986 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | gausmix | 0.50 | 1.454 | 0.525 | 0.982 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | laplace | 0.25 | 1.412 | 1.247 | 1.010 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | gausmix | 0.50 | 1.409 | 0.490 | 0.981 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | normal | 0.50 | 1.359 | 2.009 | 1.020 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | normal | 0.50 | 1.358 | 1.807 | 1.014 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | laplace | 0.50 | 1.270 | 0.997 | 0.994 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | laplace | 0.50 | 1.268 | 0.993 | 0.993 | needs_more_vb_fit_calibration |
| qdesn_al_rhs | normal | 0.25 | 1.241 | 0.705 | 0.979 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | normal | 0.25 | 1.185 | 1.021 | 0.991 | needs_more_vb_fit_calibration |
| qdesn_exal_rhs | laplace | 0.25 | 1.131 | 0.387 | 0.983 | needs_more_vb_fit_calibration |

The newest Q-DESN RHS fit-first screen remains diagnostic because the fit-RMSE ratios stay above the best validation-local DQLM/exDQLM VB baseline. The next pass therefore regenerates the fit-first grid against the validation-local baseline with a wider but still bounded profile budget.

## New Candidate Registry

exDQLM/DQLM candidate CSV: `validation/fitforecast_v2/config/exdqlm_dqlm_vb_calibration_resume_candidates_20260708.csv`

## Launch Policy

- Run VB calibration first for both tracks.
- Do not launch MCMC from this pass unless VB produces cell-specific candidates that are best or near-best on both fit and rolling forecast metrics.
- Keep all outputs storage-light and diagnostic until a separate strict promotion audit.
- Keep this chat and this worktree in the validation lane only.
