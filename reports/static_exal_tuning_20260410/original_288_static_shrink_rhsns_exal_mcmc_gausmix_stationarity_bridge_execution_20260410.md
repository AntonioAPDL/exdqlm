# Original-288 Static Shrink RHS_NS exAL MCMC Gausmix Stationarity-Bridge Execution

Date: `2026-04-10`

## Purpose

Execute the next lane for the single remaining corrected static `rhs_ns`
failure after the fully negative gausmix last-mile wave.

Prelaunch branch state:

- accepted `v8`: `282 / 288` healthy
- corrected `rhs_ns` working branch: `71 / 72` healthy
- remaining corrected unresolved row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`

## Validation Checklist

- prepare row count: `24`
- missing inputs: `0`
- `bash -n`: `passed`
- `--prepare-only=1`: `passed`
- `--dry-run=1 --skip-prepare=1`: `passed`
- prelaunch evaluate:
  - `0 / 24` done
  - `24 / 24` pending

## Launch State

- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- accepted baseline at launch: `v8`
- launch mode: full overnight run
- worker cap: `4` MCMC workers

Supervisor session:

- `original288-static-shrink-rhsns-exal-mcmc-gausmix-stationarity-bridge-20260410`

Monitor session:

- `original288-static-shrink-rhsns-exal-mcmc-gausmix-stationarity-bridge-monitor-20260410`

Tracked artifacts:

- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_schedule_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_stage_counts_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_status_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_phase_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_target_summary_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_compare_working_20260410.csv`
- `tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_compare_accepted_20260410.csv`

## Run Design

Phases:

1. `phase1_static_shrink_rhsns_exal_mcmc_gausmix_burn_bridge`
   - `8` burn-heavy RW bridges
2. `phase2_static_shrink_rhsns_exal_mcmc_gausmix_vb_bridge`
   - `8` conservative LDVB warm-start bridges
3. `phase3_static_shrink_rhsns_exal_mcmc_gausmix_newkernels`
   - `8` targeted `slice_eta` / `slice` / `laplace_local` hedges

The lane is intentionally broad, but still disciplined:

- it stays on the single unresolved gausmix row
- it does **not** reopen solved static rows
- it does **not** rerun the already exhausted plain RW/slice last-mile map
- it keeps exact-kernel exploration small and focused

## Decision

This lane is ready and is the only overnight compute launch from this branch
state. The deferred dynamic closure work remains blocked by missing source fit
artifacts and is therefore not part of this run.

## Outcome

The stationarity-bridge lane completed with a partial but real corrected-working
improvement.

Final outcome:

- total candidates: `24`
- healthy candidates: `3`
- `PASS`: `0`
- `WARN`: `3`
- `FAIL`: `21`

Corrected-working promotion:

- promoted row:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
- promoted candidate:
  - `bridge_rw_f0845_s100_b12000_k2000_sub2`
- gate change:
  - `FAIL -> WARN`
- accepted comparison:
  - `matches_accepted`

Post-run branch state:

- accepted `v8`: `282 / 288` healthy
- corrected `static_shrink / rhs_ns` working branch: `72 / 72` healthy
- remaining static corrected unresolved rows: `0`
- remaining accepted unresolved rows:
  - the `6` `dynamic / exdqlm / mcmc` rows only

Interpretation:

- the burn-heavy RW bridge family was the only part of this lane with positive
  signal
- the result is strong enough to close the corrected `rhs_ns` branch
- the result is **not** strong enough to improve the accepted `v8` branch
- from this point onward, the remaining repair work is entirely dynamic
