# Legacy Dynamic `.rds` Cleanup

Date: 2026-04-19
Repo: `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`

## Goal

Free disk space by deleting old dynamic-study `.rds` binaries while preserving the most recent usable big-run artifacts.

The cleanup rule used here was:

- keep the newer dynamic `.rds` cohort associated with the latest accepted/final usable outputs
- delete the older superseded dynamic `.rds` cohort

## Keep Rule

The following dynamic `.rds` labels were preserved:

1. `orig288_dynamic_tt5000_postfix_repair_20260415_exact_accepted_source_*`
2. `orig288_sync0p4p0_dynamic_restored_closure_20260410_final_*`

These correspond to the current kept usable dynamic outputs we still want available.

## Delete Rule

The following older legacy dynamic `.rds` cohort was removed:

- `orig288_exactspec_multiseed_20260412_seedXX`

This was the dominant old superseded binary set under:

- `results/function_testing_20260309_dynamic_dlm_family_qspec`

## Manifests

The exact file lists were recorded before deletion:

- delete manifest:
  [legacy_dynamic_rds_delete_manifest_20260419.tsv](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260419/legacy_dynamic_rds_delete_manifest_20260419.tsv)
- keep manifest:
  [legacy_dynamic_rds_keep_manifest_20260419.tsv](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260419/legacy_dynamic_rds_keep_manifest_20260419.tsv)

## Deletion Summary

| Category | Count | Size |
|---|---:|---:|
| deleted legacy dynamic `.rds` files | `144` | `74.47 GiB` |
| preserved newer dynamic `.rds` files | `75` | `14.12 GiB` |

Post-delete verification:

| Check | Result |
|---|---|
| remaining delete-manifest candidates | `0` |
| remaining delete-manifest bytes | `0.00 GiB` |

## Before / After

### Dynamic study tree

| Path | Before | After |
|---|---:|---:|
| `results/function_testing_20260309_dynamic_dlm_family_qspec` | `89G` | `15G` |

### Whole repo

| Path | Before | After |
|---|---:|---:|
| repo root | `91G` | `16G` |

### Filesystem

Measured with `df -h .`.

| Mount | Before | After |
|---|---:|---:|
| `/home` use | `90%` | `43%` |
| `/home` available | `89G` | `504G` |

## Notes

- This cleanup targeted only old dynamic binary fit artifacts.
- It did not remove code, reports, manifests, logs, health summaries, metrics, or lightweight reproducibility artifacts.
- It did not remove the preserved newer dynamic `.rds` keep-set.
- This leaves the repo in a much safer storage state for the next relaunch.
