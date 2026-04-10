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
