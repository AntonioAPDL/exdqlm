# Original-288 Static Shrink RHS_NS exAL MCMC Gausmix Stationarity-Bridge Program

Date: `2026-04-10`

## Purpose

This lane follows the fully negative gausmix last-mile wave.

Current state before launch:

- accepted branch: `v8`
- accepted health: `282 / 288`
- accepted unresolved dynamic rows: `6`
- corrected `static_shrink / rhs_ns` working branch: `71 / 72`
- remaining corrected static unresolved row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`

## What Improved

- the corrected `rhs_ns` branch remains narrowed to a single unresolved static
  row
- the last-mile wave clarified the hard row enough to stop replaying generic RW
  and plain slice settings

## What Still Fails

- corrected static:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
- accepted dynamic:
  - the same `6` deferred `dynamic / exdqlm / mcmc` rows

## What Worked Best

1. row-local `laplace_rw` anchors remained the strongest family on the hard
   gausmix row
2. the most informative failed profiles were:
   - long `F085 / s100`
   - long `F0845 / s100`
   - refresh-heavy `F085 / s100`
3. the negative wave still taught us that the row is closer to a gamma
   stationarity problem than a broad crash/geometry problem

## What Did Not Help

1. replaying more plain `slice` hedges
2. repeating the old RW map with only more keep
3. widening exact-kernel paths without changing the burn/stationarity geometry

## Highest Expected-Value Direction

The accepted legacy `rhs` `WARN` anchor for the corresponding row had:

- `ess_gamma_per1k ~= 10.4`
- `half_drift_gamma ~= 0.62`

The best corrected `rhs_ns` last-mile candidates only reached roughly:

- `ess_gamma_per1k ~= 5.2`
- `half_drift_gamma ~= 0.98`

So the next lane should **not** act like a generic broader sweep. The real gap
to bridge is:

1. better late-chain stationarity
2. without giving back the gamma ESS we already recovered

That is why this program is built around:

1. heavier burn with shorter retained windows
2. conservative VB warm-start bridges
3. a small set of untried kernels:
   - `slice_eta`
   - `slice`
   - `laplace_local`

## Search Space

Total candidates: `24`

Phases:

1. `phase1_static_shrink_rhsns_exal_mcmc_gausmix_burn_bridge`
   - `8` burn-heavy RW bridges
2. `phase2_static_shrink_rhsns_exal_mcmc_gausmix_vb_bridge`
   - `8` conservative VB-seeded bridges
3. `phase3_static_shrink_rhsns_exal_mcmc_gausmix_newkernels`
   - `8` small exact/approximate kernel hedges

Candidate families:

1. `burn_bridge`
   - keep only the strongest historical anchors
   - discard much more burn
   - reduce retained window size to attack half-chain drift directly
2. `vb_bridge`
   - use only conservative LDVB warm starts
   - keep the best row-local RW geometry as the primary path
3. `newkernel_bridge`
   - test `slice_eta` and `laplace_local` only on the strongest surviving
     anchors
   - keep the exact-kernel hedge disciplined and small

## Why These Candidates Are Included

- `bridge_rw_f085_s100_*`
  - strongest high-band RW anchor; most direct bridge from prior ESS leader to
    a more stationary retained segment
- `bridge_rw_f0845_s100_*`
  - cleaner lower-mid RW anchor; best chance to improve drift without total
    loss of gamma movement
- `bridge_rw_f0825_s1025_*`
  - one softer-band hedge so the bridge does not overfit only the F085/F0845
    neighborhood
- `bridge_vb_*`
  - tests whether a conservative warm start can remove the surviving transient
    without opening a broad new tuning family
- `bridge_local_*`, `bridge_sliceeta_*`, `bridge_vb_slice*`
  - small but real hedge against the possibility that the remaining row now
    needs a different gamma update family rather than more RW refinement

## Validation State

Validated artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_helpers_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_prepare_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_evaluate_20260410.R`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_launch_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_monitor_20260410.sh`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_supervisor_20260410.sh`

Validation summary:

- prepare: `24` rows
- missing inputs: `0`
- `bash -n`: passed
- launcher `--prepare-only=1`: passed
- launcher `--dry-run=1 --skip-prepare=1`: passed

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_stage_counts_20260410.csv`

## Decision

This stationarity-bridge lane is ready for overnight launch.
