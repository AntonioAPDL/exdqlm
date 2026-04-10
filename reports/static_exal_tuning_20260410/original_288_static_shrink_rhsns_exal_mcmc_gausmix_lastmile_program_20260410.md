# Original-288 Static Shrink RHS_NS exAL MCMC Gausmix Last-Mile Program

Date: `2026-04-10`

## Purpose

This lane follows the completed `rhs_ns` repair wave and the completed
final-closure wave.

Current state before launch:

- accepted branch: `v8`
- accepted health: `282 / 288`
- accepted unresolved dynamic rows: `6`
- corrected `static_shrink / rhs_ns` working branch: `71 / 72`
- remaining corrected static unresolved row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`

## What Improved

- the corrected `rhs_ns` branch advanced from `70 / 72` to `71 / 72` healthy
- `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc` is now `WARN`
  under the corrected working baseline

## What Still Fails

- corrected static:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
- accepted dynamic:
  - the same `6` deferred `dynamic / exdqlm / mcmc` rows, still blocked by
    missing source artifacts

## What Worked Best

1. no-VB-init row-local `laplace_rw` corridors
2. targeted promotion only when the row improved on the corrected working
   baseline
3. keeping the static shrinkage correction separate from accepted `v8`

## What Did Not Help

1. replaying the hard gausmix row with short or medium chains
2. materially wider slice corridors on that row without a real gamma-ESS plan
3. reopening already-weak high-band rw corridors without another new lever

## Highest Expected-Value Direction

For the last corrected gausmix row, the evidence now points to a specific
last-mile problem:

- no-VB-init converts the old iter-2 crash into a scored but unhealthy chain
- the best row-44 profiles are all `laplace_rw`
- the dominant remaining failure is `gamma = FAIL`, driven mainly by gamma ESS
  and high gamma autocorrelation

So this program is built around:

1. longer rw chains on the best row-local anchors
2. more gamma substeps
3. earlier/heavier laplace refresh
4. a smaller number of aggressive slice hedges, but not a slice-dominated map

## Search Space

Total candidates: `28`

Phases:

1. `phase1_static_shrink_rhsns_exal_mcmc_gausmix_rw_length`
   - `8` high-value rw anchor extensions
2. `phase2_static_shrink_rhsns_exal_mcmc_gausmix_rw_refresh`
   - `8` rw refresh / gamma-substep candidates
3. `phase3_static_shrink_rhsns_exal_mcmc_gausmix_rw_scale`
   - `6` jump-scale / band hedges
4. `phase4_static_shrink_rhsns_exal_mcmc_gausmix_slice`
   - `6` exact-kernel hedges

Candidate families:

1. `rw_length`
   - push the best `F085 / s100` and `F0845 / s100` anchors to much longer
     chains and more gamma substeps
2. `rw_refresh`
   - start laplace refresh earlier, run it more frequently, and increase its
     weight
3. `rw_scale`
   - keep the search broad with lower/higher scale hedges and one softer-band
     fallback
4. `slice_lastmile`
   - keep exact-kernel options alive, but only as disciplined hedges after the
     rw evidence

## Why These Candidates Are Included

- `lastmile_rw_f085_s100_xxlong[_sub3|_sub4]`
  - strongest combined ESS anchor so far; direct gamma-ESS closure attempt
- `lastmile_rw_f0845_s100_xxlong[_sub3|_sub4]`
  - best low-mid rw hedge with cleaner drift
- `lastmile_rw_f085_s100_noadapt_xxlong_sub3`
  - checks whether adaptation is still suppressing gamma ESS
- `lastmile_rw_f0825_s1025_xxlong_sub3`
  - keeps one softer-band hedge alive without reopening clearly weak extremes
- refresh-map profiles
  - convert the next wave into a true gamma-mixing search rather than a pure
    budget search
- scale hedges
  - keep the search broad without returning to the already weak `F0875` branch
- slice profiles
  - preserve exact-kernel coverage, but only with new longer/deeper settings

## Validation State

Validated artifacts:

- `tools/merge_reports/LOCAL_original288_apply_rhsns_final_closure_promotions_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_helpers_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_prepare_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_evaluate_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_launch_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_monitor_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_supervisor_20260410.sh`

Validation summary:

- corrected working promotion script: passed
- corrected working branch after promotion: `71 / 72`
- prepare: `28` rows
- missing inputs: `0`
- `bash -n`: passed
- launcher `--prepare-only=1`: passed
- launcher `--dry-run=1 --skip-prepare=1`: passed

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_selection_update_v2_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_baseline_v2_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_summary_v2_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_working_unresolved_v2_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_stage_counts_20260410.csv`

## Decision

This gausmix-only last-mile lane is ready for overnight launch.
