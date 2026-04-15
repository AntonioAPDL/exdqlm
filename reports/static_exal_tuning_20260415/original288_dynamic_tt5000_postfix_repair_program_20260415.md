# Original288 Dynamic TT5000 Post-Fix Repair Program

## Purpose

Resume the narrow `36`-row dynamic `TT5000` repair only after the package-level
root-cause fixes are present in the validation checkout and a representative
post-fix smoke shows that the old fast-fail behavior is gone.

This is a fresh rerun lane, not a reuse of the failed `2026-04-14` outputs.

## Provenance Rules

- preserve the current exact-spec replay configs in phase 1
- preserve row-local historical repair controls in phase 2 when available
- standardize only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - deterministic `4`-seed expansion

## Post-Fix Preconditions

The rerun is built on top of the package stabilization checkpoint:

- `dlm_df()` backward smoother bug fixed
- dynamic covariance regularization threaded through the dynamic R-side paths
- stale dynamic `dqlm.ind = TRUE` MCMC FFBS branch fixed
- replay init/adapt drift fixed in the validation runner
- missing internal `CRPS` helper added and regression-tested

## Representative Smoke Gate

The post-fix smoke uses isolated representative `TT5000` rows across:

- `dqlm / vb`
- `exdqlm / vb`
- `dqlm / mcmc`
- `exdqlm / mcmc`

with:

- `gausmix / tau = 0p05`
- `normal / tau = 0p25`

The smoke criterion is runtime stability, not scientific closure:

- representative rows must stop reproducing the old immediate
  `computationally singular` / `chi has non-finite values` startup failures
- row artifacts must write cleanly

## Implemented Stack

Core scripts:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_helpers_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_prepare_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_build_phase2_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_run_row_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_evaluate_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_reduce_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_refresh_comparison_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_launch_20260415.sh`

Prepared artifacts:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase1_source_audit_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase2_candidate_inventory_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase1_manifest_20260415.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_full_manifest_20260415.csv`

## Prepared Counts

| artifact | count |
|---|---:|
| target rows | `36` |
| phase-1 rows | `144` |
| phase-2 historical candidates | `13` |
| missing phase-1 inputs | `0` |

## Launch Design

The rerun stays conservative:

1. exact replay on all unresolved `TT5000` rows
2. reduce phase-1 outcomes
3. only then build historical phase 2 for rows still selecting to `FAIL`
4. refresh the repaired comparison after reduction

Worker caps:

- phase 1: `3`
- phase 2: `2`
