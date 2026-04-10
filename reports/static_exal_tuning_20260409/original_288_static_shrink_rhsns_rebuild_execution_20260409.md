# Original 288 Static Shrink RHS_NS Rebuild Execution

Date: `2026-04-09`

## Launch Stack

Regeneration-based rebuild stack:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_helpers_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_prepare_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_run_row_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_evaluate_20260409.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_launch_20260409.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_monitor_20260409.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_supervisor_20260409.sh`

## Validation Completed Before Launch

Prepare and orchestration:

- `bash -n` passed for launch, monitor, and supervisor scripts
- prepare completed with:
  - `72` rows
  - `0` missing inputs
  - phase counts `36` VB + `36` MCMC
- evaluator prelaunch summary completed cleanly
- launcher `--prepare-only=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed

Smoke tests completed:

- row `1`: `vb :: al` completed cleanly
- row `37`: `mcmc :: al` completed cleanly after metric-alignment hardening
- row `38`: `mcmc :: exal` completed cleanly through the full runner path

Important implementation fixes made during validation:

- normalized merged inventory/accepted columns after duplicate-name merge
- hardened static metric extraction for MCMC objects without coefficient
  dimnames
- normalized evaluator phase handling so status summaries are stable

## Launch Intent

This wave is the explicit phase-0 prior correction required before any broader
 static propagation from the shrinkage branch.

Expected next use after completion:

- replace legacy mixed-prior `static_shrink / rhs`
- rerun broader metric comparison
- rerun cluster-by-cluster diagnosis with corrected `rhs_ns` shrinkage results

## Final Closeout

The full `72`-row rebuild has now completed and is recorded here as the durable
closeout for this recent correction wave.

Overall outcome:

- total rows: `72`
- completed statuses:
  - `63` `done`
  - `6` `failed_runtime`
  - `3` `skipped_existing`
- gate outcome:
  - `47` `PASS`
  - `13` `WARN`
  - `12` `FAIL`
- healthy total:
  - `60 / 72`

Model / inference breakdown:

| model | inference | total | PASS | WARN | FAIL | healthy |
|---|---|---:|---:|---:|---:|---:|
| `al` | `vb` | `18` | `18` | `0` | `0` | `18` |
| `exal` | `vb` | `18` | `12` | `6` | `0` | `18` |
| `al` | `mcmc` | `18` | `16` | `2` | `0` | `18` |
| `exal` | `mcmc` | `18` | `1` | `5` | `12` | `6` |

Main finding:

- the rebuild succeeded cleanly for all `36` VB rows
- the rebuild succeeded cleanly for all `18` `al :: mcmc` rows
- the only weak pocket is `static_shrink / rhs_ns / exal / mcmc`

The `12` failing rows are concentrated as follows:

- families:
  - `6` `gausmix`
  - `3` `laplace`
  - `3` `normal`
- taus:
  - `4` at `0p05`
  - `6` at `0p25`
  - `2` at `0p95`
- fit sizes:
  - `5` at `100`
  - `7` at `1000`

Exact failing scenarios:

- `gausmix / 0p05 / 100 / exal / mcmc`
- `gausmix / 0p05 / 1000 / exal / mcmc`
- `gausmix / 0p25 / 100 / exal / mcmc`
- `gausmix / 0p25 / 1000 / exal / mcmc`
- `gausmix / 0p95 / 100 / exal / mcmc`
- `gausmix / 0p95 / 1000 / exal / mcmc`
- `laplace / 0p05 / 1000 / exal / mcmc`
- `laplace / 0p25 / 100 / exal / mcmc`
- `laplace / 0p25 / 1000 / exal / mcmc`
- `normal / 0p05 / 1000 / exal / mcmc`
- `normal / 0p25 / 100 / exal / mcmc`
- `normal / 0p25 / 1000 / exal / mcmc`

Interpretation:

- this wave successfully established a clean explicit `rhs_ns` rebuild branch
- it did **not** justify a direct accepted-baseline promotion over the frozen
  legacy `static_shrink / rhs` carry-forward rows
- instead, it should be used as the corrected shrinkage input for the later
  metric-comparison, cluster-diagnosis, and propagation-planning passes

Primary output references:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_phase_summary_20260409.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_block_summary_20260409.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_manifest_status_20260409.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_manifest_20260409.csv`
