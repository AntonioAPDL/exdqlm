# QDESN Tau050 Remaining Precision Matrix Plan

Date: `2026-04-20`  
Status: prepared for launch

## Why A Matrix Is Now The Right Move

The run-specific relaunch recovered `13 / 15` remaining hard failures, leaving only one root unresolved under two lanes:

- `AL / laplace / tau 0.50 / fit_size 5000 / ridge`
- `EXAL / laplace / tau 0.50 / fit_size 5000 / ridge`

The final pair relaunch confirmed that both failures are now **precision-Cholesky** failures, not latent-`v` failures. That means the next step should screen precision-stability controls directly rather than repeat more warmup-only retries.

## Experiment Surface

This matrix keeps the surface exact and cheap:

- only the single remaining `AL` root
- only the single remaining `EXAL` root
- multiple precision-stability specs per lane
- one worker per lane

## AL Arms

| Phase | Main idea |
|---|---|
| `remaining_precision_matrix_al_qr_v1` | `qr_whiten`, `gram_ridge=1e-4`, `use_log_sigma`, `width_sigma=0.22`, `core_extra_passes=1` |
| `remaining_precision_matrix_al_qr_v2` | stronger `qr_whiten`, `gram_ridge=1e-2`, `use_log_sigma`, `width_sigma=0.20`, `core_extra_passes=2` |
| `remaining_precision_matrix_al_diag_v1` | `diag_scale` instead of QR, `use_log_sigma`, `width_sigma=0.22`, `core_extra_passes=1` |

## EXAL Arms

| Phase | Main idea |
|---|---|
| `remaining_precision_matrix_exal_qr_v1` | `qr_whiten`, `gram_ridge=1e-3`, `gamma_sigma_gamma`, `use_log_sigma` |
| `remaining_precision_matrix_exal_qr_v2` | stronger `qr_whiten`, `gram_ridge=1e-2`, `gamma_sigma_gamma`, `use_log_sigma`, `core_extra_passes=2` |
| `remaining_precision_matrix_exal_qr_sig_v1` | same stronger QR ridge, but back to `sigma_then_gamma` |
| `remaining_precision_matrix_exal_diag_v1` | `diag_scale` instead of QR, `gamma_sigma_gamma`, `use_log_sigma` |

## Shared Design Choices

Across all arms:

- keep tau freeze
- keep theta freeze
- keep bounded latent-`v` rescue
- turn on `use_log_sigma = TRUE`
- narrow sigma slice widths
- reduce steps-out/shrink to tighter precision-friendly settings

## Reproducible Assets

Materializer:

- [remaining precision matrix materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix.R)

Matrix manifest:

- [remaining precision matrix map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_matrix_map.csv)

Shared grids:

- [AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_al_grid.csv)
- [EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_pair_exal_grid.csv)

## Launch Rule

Launch all 7 arms in parallel with one worker each. That is broad enough to separate promising precision strategies while still staying small enough to read and compare cleanly.
