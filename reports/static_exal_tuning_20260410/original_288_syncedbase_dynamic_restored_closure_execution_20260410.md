# Original-288 Synced-Base Dynamic Restored Closure Execution

Date: `2026-04-10`

## Purpose

Execute the restored-source replay lane for the `6` remaining accepted
`dynamic / exdqlm / mcmc` failures under accepted `v8`.

Prelaunch branch state:

- accepted `v8`: `282 / 288` healthy
- corrected `static_shrink / rhs_ns` working branch: `72 / 72` healthy
- remaining accepted unresolved rows:
  - the `6` `dynamic / exdqlm / mcmc` rows only

## Validation Checklist

- restored source queue: `6` rows
- deferred screened attempts: `24`
- manifest row count: `24`
- missing inputs: `0`
- restored source audit:
  - all `6 / 6` rows have:
    - materialized source dir
    - restored `sim_output.rds`
    - synthetic baseline `.rds`
- `bash -n`: `passed`
- prelaunch evaluate:
  - `0 / 24` done
  - `24 / 24` pending
- `--prepare-only=1`: `passed`
- `--dry-run=1 --skip-prepare=1`: `passed`

## Launch State

- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- accepted baseline at launch: `v8`
- launch mode: full overnight run
- worker cap: `4` MCMC workers

Supervisor session:

- `original288-syncedbase-dynamic-restored-closure-20260410`

Monitor session:

- `original288-syncedbase-dynamic-restored-closure-monitor-20260410`

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_source_audit_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_stage_counts_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_status_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_phase_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_block_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_accepted_compare_20260410.csv`

## Decision

This restored-source lane is launch-ready and is now the only remaining
overnight compute lane from the branch state.
