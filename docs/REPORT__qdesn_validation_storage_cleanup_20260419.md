# QDESN Validation Storage Cleanup Report

Date: 2026-04-19

## Summary

This cleanup removed old generated validation result surfaces and pruned large binary forecast artifacts from the recent `tau050` runs while preserving the logs, manifests, reports, and small summary files needed for investigation and relaunch work.

At cleanup start, there was no live tmux validation session to stop. The captured tmux state is in [tmux_status_before.txt](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260419_qdesn_validation_cleanup/tmux_status_before.txt).

The cleanup was executed with the scripted workflow in [cleanup_qdesn_validation_storage.sh](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/cleanup_qdesn_validation_storage.sh).

## Before / After

| Metric | Before | After | Change |
|---|---:|---:|---:|
| `/home` used | `781G` | `441G` | `-340G` |
| `/home` available | `89G` | `429G` | `+340G` |
| `/home` utilization | `90%` | `51%` | `-39 pts` |

Evidence:
- [filesystem_before.txt](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260419_qdesn_validation_cleanup/filesystem_before.txt)
- [filesystem_after.txt](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260419_qdesn_validation_cleanup/filesystem_after.txt)

## What Was Removed

Two cleanup modes were used:

1. Full deletion of older generated result trees that are no longer needed for the current `tau050` continuation.
2. Pruning of large `forecast_objects.rds` binaries from the recent `tau050` validation trees so their run structure, manifests, and logs remain available.

### Full-delete set

The exact delete list is recorded in [directories_to_delete.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260419_qdesn_validation_cleanup/directories_to_delete.tsv).

Key large removals:

| Path | Footprint |
|---|---:|
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation` | `102.83 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave` | `44.93 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave` | `34.15 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave` | `22.56 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation` | `19.64 GB` |

### Pruned binary set

The exact prune list is recorded in [forecast_objects_to_prune.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260419_qdesn_validation_cleanup/forecast_objects_to_prune.tsv).

Cleanup removed `145` large `forecast_objects.rds` files from:

- [dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation)
- [dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation)
- [dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_matrix_validation](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_matrix_validation)

Post-cleanup verification confirmed that those preserved trees contain `0` remaining `forecast_objects.rds` files.

## What Was Preserved

The cleanup intentionally preserved:

- `reports/qdesn_mcmc_validation/...`
- all `*_sources` directories under `results/qdesn_mcmc_validation`
- the recent `tau050` result trees themselves, minus the large forecast binaries
- logs, manifests, CSV summaries, fit requests, and lightweight model sidecars still needed for debugging and relaunch work

Post-cleanup retained result surface:

| Path | Retained size |
|---|---:|
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation` | `235M` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation` | `42M` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_matrix_validation` | `5.8M` |

## Operational Read

This cleanup removed the storage pressure that was contaminating the recent relaunch work. The repo now has enough headroom for a clean new relaunch, but the scientific rerun should still wait for the next code change set:

- latent `s` freeze / warmup work
- the AL post-fit reference-compare merge fix or temporary gating

The relaunch-ready plan is in [PLAN__qdesn_tau050_relaunch_after_storage_cleanup_20260419.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_relaunch_after_storage_cleanup_20260419.md).
