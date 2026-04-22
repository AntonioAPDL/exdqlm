# Dynamic Candidate Dataset Refresh Outputs

## Status

This period-90 steeper-trend surface is now the promoted main dynamic dataset
choice for the next Q-DESN dynamic relaunch, pending the explicit relaunch-grid
rewrite. The historical `tau050_refreshed_main` study artifacts are preserved
unchanged for auditability; the paths below are the new source-of-truth paths
for future dataset mirroring and relaunch preparation.

## Main output roots

### Canonical candidate source bundle

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1`

### Q-DESN washout-materialized windows

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_qdesn_sources`

### Flat review pack

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_dataset_audit_local/qdesn-dynamic-exdqlm-crossstudy-candidate-datasetaudit-20260422-035737__git-a4ecc81`

### Canonical last5000-vs-last500 review pack

- `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_local/qdesn-dynamic-candidate-last5000-last500-audit-20260422-035753__git-a4ecc81`

## Inventory counts

| Layer | Count |
|---|---:|
| full family-by-tau roots | `9` |
| canonical exDQLM tail slices | `18` |
| Q-DESN washout windows | `18` |
| flat audit PNGs | `36` |

## What is in the canonical source bundle

For each family/tau root:

- `series_wide.csv`
- `series_long.csv`
- `true_quantile_grid.csv`
- `sim_output.rds`
- `meta.txt`
- `validation.txt`
- root preview PNG
- `fit_input_lastTT500/`
- `fit_input_lastTT5000/`

Top-level inventories:

- `000__full_root_inventory.csv`
- `000__canonical_slice_inventory.csv`
- `000__bundle_manifest.json`
- `000__bundle_summary.md`

## What is in the flat review pack

The audit pack is intentionally flat and split into two review scopes:

### Canonical exDQLM tail windows

- `001` to `018`
- filenames start with `exdqlm`
- examples:
  - `001__exdqlm__gausmix__tau_0p05__fit_500__lastTT500.png`
  - `018__exdqlm__normal__tau_0p50__fit_5000__lastTT5000.png`

### Q-DESN washout windows

- `019` to `036`
- filenames start with `qdesn`
- examples:
  - `019__qdesn__gausmix__tau_0p05__fit_500__effTT500_totalTT813.png`
  - `036__qdesn__normal__tau_0p50__fit_5000__effTT5000_totalTT5313.png`

Metadata files:

- `000__run_metadata.json`
- `000__candidate_dataset_audit_manifest.json`
- `000__candidate_dataset_audit_summary.md`
- `000__dataset_index.csv`

## Review guidance

Recommended order:

1. Review the `exdqlm` PNGs first to judge the canonical `500` / `5000` source windows.
2. Then review the `qdesn` PNGs to see how the same source roots look after the Q-DESN washout-preserving materialization.
3. If a root looks good canonically but odd after washout, that points to the downstream windowing rather than the DGP itself.
4. If both views look bad, that points to the source DGP and should be fixed before any relaunch.
