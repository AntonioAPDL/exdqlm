# Original288 Dynamic TT5000 Post-Fix Smoke Execution

## Intent

This execution note tracks the isolated post-fix smoke that gates any resumed
dynamic `TT5000` repair relaunch.

## Rules

- use the validation checkout after syncing the package-level TT5000 fixes
- keep smoke outputs isolated from the full repair lane
- only resume the full repair lane if the smoke completes without runtime
  failures on representative cases

## Current Status

Implemented and run from:

- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_prepare_20260415.R`
- `tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_launch_20260415.sh`

Observed signal:

- first representative completed row:
  - `dynamic::gausmix::0p05::5000::default::dqlm::vb`
  - `status = done`
  - `gate_overall = WARN`
  - runtime about `273s`
- representative MCMC rows stayed active for extended time without reproducing
  the old immediate startup failures
- the first smoke attempt uncovered a separate missing-helper issue in the
  metrics layer (`.exdqlm_crps_vec`), which was then fixed and regression-tested

Interpretation:

- the smoke succeeded in its main job: it proved that the validation checkout
  had moved beyond the old immediate singular/non-finite startup failures
- after that evidence was captured, the smoke was stopped so the fresh post-fix
  repair rerun could use the resources instead
