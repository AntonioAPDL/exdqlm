# QDESN Pre-p90 Validation Output Cleanup Dry-Run Report

Date: 2026-04-22

## Summary

A new guarded cleanup workflow was prepared for legacy qdesn validation outputs created
before the current `p90` steeper-trend relaunch.

The main finding is important:

- there are **no generated validation-study `.rda` outputs** to purge in this repo
- the only `.rda` files present are tracked package datasets under `data/`
- the large historical launch footprint is stored as `.rds` binaries inside older
  `results/qdesn_mcmc_validation/*_validation` trees

So the cleanup scope is now defined as:

- legacy validation result trees and their `.rds` payloads

while preserving:

- the live `p90` relaunch tree
- all `*_sources` dataset surfaces
- tracked package data `.rda` files

## Script Added

- [cleanup_qdesn_pre_p90_validation_outputs.sh](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/cleanup_qdesn_pre_p90_validation_outputs.sh)

This script:

- defaults to dry run
- writes explicit manifests
- separates package `.rda` inventory from generated validation outputs
- blocks execute mode while live `qdesn_*` tmux sessions are present unless explicitly overridden

## Dry-Run Root

- [dry-run artifacts](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun)

Key artifacts:

- [cleanup_summary.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun/cleanup_summary.md)
- [validation_dirs_to_delete.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun/validation_dirs_to_delete.tsv)
- [protected_paths.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun/protected_paths.tsv)
- [package_rda_inventory.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun/package_rda_inventory.tsv)
- [targeted_rda_inventory.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun/targeted_rda_inventory.tsv)
- [target_binary_inventory_top200.tsv](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_dryrun/target_binary_inventory_top200.tsv)

## Dry-Run Readout

| Metric | Value |
|---|---:|
| Tracked package `.rda` files | `4` |
| Generated validation `.rda/.RData` files outside protected surfaces | `0` |
| Legacy validation dirs targeted for deletion | `31` |
| Targeted delete footprint | `52.41 GB` |
| Protected source dirs | `6` |
| Protected footprint | `67.52 GB` |
| Top inventoried targeted binary files | `200` |
| Footprint of top-200 targeted binary files | `51.97 GB` |

## Largest Targeted Legacy Trees

| Path | Footprint |
|---|---:|
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation` | `10.17 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_al_validation` | `9.68 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_latent_v_exal_validation` | `8.10 GB` |
| `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_hard_fail_exal_ridge_precision_v1_validation` | `3.23 GB` |
| `results/qdesn_mcmc_validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_tau_only_validation` | `3.23 GB` |
| `results/qdesn_mcmc_validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_theta_tau_validation` | `3.23 GB` |

## What Is Protected

The cleanup explicitly preserves:

- [dynamic_exdqlm_crossstudy_p90_steepertrend_validation](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_validation)
- [dynamic_exdqlm_crossstudy_candidate_qdesn_sources](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_qdesn_sources)
- [dynamic_exdqlm_crossstudy_candidate_sources](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources)
- [dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_sources](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_sources)
- [dynamic_exdqlm_crossstudy_effective_w300_postdraw_sources](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_sources)
- [dynamic_exdqlm_crossstudy_p90_steepertrend_main_sources](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_main_sources)
- [dynamic_exdqlm_crossstudy_tau050_refreshed_main_sources](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_sources)

## Execute Safety Check

I also validated execute-mode blocking while the live relaunch is still active.

- [execute-block check root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/storage_cleanup/20260422_pre_p90_cleanup_execute_block_check)

The execute safety check produced:

| Check | Result |
|---|---|
| Requested mode | `execute` |
| Live `qdesn_*` tmux sessions detected | `yes` |
| Deletion performed | `no` |
| Script exit behavior | blocked as designed |

This is the desired behavior while the `p90` relaunch is still running.

The script also now carries a second hard guard:

- if any targeted delete surface ever contains `.rda/.RData`, execute mode blocks itself
- so this workflow will not delete current-launch or legacy `.rda` payloads by accident

## Recommended Next Step

Do **not** execute destructive cleanup yet. The cleanup is now ready, but the correct
sequence is:

1. let the current `p90` relaunch finish
2. review the run and preserve any needed artifacts
3. run the cleanup script in execute mode once the live `qdesn_*` tmux sessions are gone

That gives a clean, documented, and reversible decision point before deletion.
