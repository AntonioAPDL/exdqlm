# Original-288 Synced-Base Dynamic Restored Closure Program

Date: `2026-04-10`

## Purpose

Define the restored-source closure lane for the remaining accepted dynamic
failures after accepted `v8`, using reconstructed dynamic source inputs rather
than relying on the missing upstream `.rds` artifacts that blocked the earlier
generic closure lane.

Current accepted dynamic unresolved rows:

1. `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
2. `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
3. `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
4. `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
5. `dynamic::normal::0p05::500::default::exdqlm::mcmc`
6. `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

## Design Rules

1. Keep accepted `v8` as the default scientific baseline.
2. Reopen only the `6` unresolved accepted dynamic rows.
3. Use restored-source replay so the generic row runner can operate without the
   deleted upstream fit/state artifacts.
4. Preserve the strongest previously learned row-local corridors.
5. Avoid families and schedules already screened as weak:
   - no replay of the blocked generic final-closure lane
   - no return to the faithful `0.16 / 240` slice corridor
   - no broad static-style kernel transfer onto dynamic rows

## Restored-Source Strategy

For each unresolved row:

1. take the qdesn materialized source window:
   - `fit_input_effTT500_totalTT813` or
   - `fit_input_effTT5000_totalTT5313`
2. reconstruct the original `lastTT500` or `lastTT5000` `sim_output.rds`
   exactly from the surviving CSV/source indices
3. build a lightweight synthetic baseline object containing:
   - `p0`
   - dynamic model matrices
   - `df`
   - baseline proposal metadata
   - baseline seed
4. replay the curated dynamic closure schedule against those restored inputs

This keeps the comparison faithful to the accepted unresolved rows while making
the closure lane executable again.

## Planned Search Space

Total planned candidates: `24`

- phase 1 `dynamic_reinforcement`: `12`
- phase 2 `dynamic_broad_repair`: `12`

High-level candidate logic:

- `gausmix / 0p05 / TT5000`
  - deep slice reinforcement plus one wider exact-kernel hedge
- `gausmix / 0p25 / TT500`
  - reinforce the strongest mid-tail slice near-miss
- `laplace / 0p05 / TT500`
  - reinforce the best RW-refresh family and add a no-adapt hedge
- `laplace / 0p05 / TT5000`
  - keep slice as the lead family, plus one RW hedge
- `normal / 0p05 / TT500`
  - reinforce RW-joint and compare against non-joint / slice hedges
- `normal / 0p05 / TT5000`
  - reinforce the strongest long-run RW family and compare against lighter
    non-joint and exact-kernel hedges

Tracked schedule inputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_queue_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_deferred_inventory_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_restored_closure_schedule_20260410.csv`

## Expected Value

This lane has the highest expected value because it:

- attacks the only remaining accepted publication-target debt
- reuses the strongest existing row-local evidence
- avoids reopening solved static rows
- restores technical executability without inventing a new ad hoc dynamic
  runner
