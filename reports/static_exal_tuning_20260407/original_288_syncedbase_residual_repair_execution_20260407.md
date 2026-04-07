# Original-288 Synced-Base Residual Repair Execution

Date: 2026-04-07

## Prelaunch Validation

Prepared residual manifest:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_20260407.csv`

Prepared residual fail inventory:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_fail_inventory_20260407.csv`

Prepared stage counts:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_stage_counts_20260407.csv`

Prelaunch evaluator outputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_status_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_phase_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_block_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_accepted_compare_20260407.csv`

Validated prelaunch state:

- `84 / 84` residual rows prepared
- `0` missing inputs
- `0 / 84` complete before launch
- `84 / 84` pending before launch
- `bash -n` passed for launch / supervisor / monitor scripts
- launcher `--prepare-only=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed

Validated lane split:

- `54` static `al :: mcmc` bug-fix reruns
- `27` static `exal :: mcmc` exact replay reruns
- `3` dynamic `exdqlm :: mcmc` exact replay reruns

## Corrective Changes Included In This Launch

Included fixes:

1. accepted MCMC replay precedence now treats `NA` accepted values as missing
   rather than valid overrides
2. the faithful replay prepare path now materializes selected-fit-derived
   config fields and selected seeds correctly
3. residual prepare uses accepted reference fit paths directly for every
   rerun row
4. residual lane construction now includes runtime-invalid static `al` rows,
   not only completed unhealthy rows

## Launch Intent

This execution is intended to answer:

- how much of the faithful-replay residual queue disappears once the replay bug
  is fixed and the failed rows are rerun under corrected exact replay

It is not intended to reopen the unresolved accepted tail of `6` dynamic rows
yet.

## Live Launch Checkpoint

This section should be refreshed after launch:

- tmux supervisor:
  `original288-syncedbase-residual-repair-20260407`
- tmux monitor:
  `original288-syncedbase-residual-repair-monitor-20260407`
- initial expected state:
  - active phase:
    `phase1_static_al_mcmc_bugfix`
  - `0 / 84` done at launch
