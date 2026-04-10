# Original-288 Static Shrink RHS_NS exAL MCMC Repair Program

Date: `2026-04-10`

## Current State

Promotion decision before this launch:

- no completed result is promoted into accepted `v7` yet
- accepted `v7` remains the branch baseline because the corrected explicit
  `rhs_ns` replacement branch is still incomplete
- the completed `static_shrink_rhsns_rebuild_20260409` wave is scientifically
  better specified than the legacy mixed-prior `rhs` branch, but it still ends
  with a concentrated `12`-row `FAIL` pocket

Corrected rebuild status:

- total rebuilt rows: `72`
- healthy rebuilt rows: `60 / 72`
- remaining failures: `12 / 72`
- all remaining failures are:
  - `static_shrink / rhs_ns / exal / mcmc`

Remaining failure split:

- family:
  - `6` `gausmix`
  - `3` `laplace`
  - `3` `normal`
- tau:
  - `4` at `0p05`
  - `6` at `0p25`
  - `2` at `0p95`

## What Improved

- the full `72`-row shrinkage branch now exists as an explicit `rhs_ns`
  replacement instead of mixed-prior legacy carryforward
- `vb :: al`, `vb :: exal`, and `mcmc :: al` are all fully healthy under the
  corrected branch
- the unresolved debt is now narrow and auditable: exactly `12`
  `exal :: mcmc` rows

## What Still Fails

The remaining `12` failures split into two classes:

1. crash-band failures at `tau = 0p25`
   - `6` rows fail with:
     `Static MCMC state invalid (iter=2): static_exal chi has non-finite values`
2. chain-quality failures outside the crash band
   - `6` rows complete but still fail gates through low ESS, autocorrelation,
     or half-chain drift

## What Worked Best

- explicit `rhs_ns` regeneration rather than dead-artifact replay
- row-local historical anchors instead of broad generic sweeps
- nearby rhs_ns static repair evidence suggests useful transfer candidates:
  - `normal / 0p25 / 1000`: `F0825_sub2_s105_none`, `F0835_sub2_s1025`
  - `gausmix / 0p95`: `F0825_sub2_s100`, `F085_sub2_s100`,
    `F085_sub2_s1025`
  - `laplace / 0p05 / 1000`: `F0835_sub2_s1025`,
    `F0825_sub2_s1025`
- the new paper-aligned static benchmark also supports using `slice` as a
  legitimate static exAL rescue kernel, not only `laplace_rw`

## What Did Not Help

- replaying the rebuild default profiles unchanged:
  - `baseline_like`
  - `f080_sub2_s105`
  - `failband2_f085_sub2_s100`
  - `repairmap6_f0825_sub2_s100`
  - `repairmap9_f0845_sub2_s100`
  - `faithful_like`
- keeping the VB warm-start path in the `tau = 0p25` crash band
- treating all `12` rows as one generic tuning problem

## Highest-Value Directions

1. remove the shared `tau = 0p25` invalid-state crash with no-VB
   initialization
2. probe `slice` selectively on the crash band and on the hardest gausmix /
   normal drift rows
3. use longer row-local rw anchors only on the completed-but-still-failing rows
   where drift/ESS is the real blocker

## Overnight Program

Run tag:

- `original288_static_shrink_rhsns_exal_mcmc_repair_20260410`

Shape:

- total candidates: `38`
- phase 1 crash repair: `20`
- phase 2 mixing repair: `18`
- target rows: the exact `12` remaining corrected `rhs_ns` failures only

Design rules:

- do not rerun the rebuild defaults that already failed
- keep tuning local to each scenario
- allow both `laplace_rw` and selective `slice`
- separate crash-removal from chain-quality repair
- compare every candidate both to:
  - the accepted legacy branch gate
  - the failed corrected `rhs_ns` rebuild gate

Main candidate families:

| repair class | candidate idea | purpose |
|---|---|---|
| invalid-state | `laplace_rw` + `init_from_vb = FALSE` | remove the shared iter-2 crash without changing the whole kernel |
| invalid-state | `slice` + `init_from_vb = FALSE` | test whether slice avoids the unstable warm-start geometry |
| chain-quality | historical rw anchors with longer chains | target ESS / half-drift failures directly |
| chain-quality | selective `slice` probes | test whether the paper-aligned static exAL kernel helps the hardest remaining rows |

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_stage_counts_20260410.csv`

Launch stack:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_helpers_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_prepare_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_run_row_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_evaluate_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_launch_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_monitor_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_supervisor_20260410.sh`
