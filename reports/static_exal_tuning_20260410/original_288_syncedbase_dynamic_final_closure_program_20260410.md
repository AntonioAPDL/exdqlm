# Original-288 Synced-Base Dynamic Final Closure Program

Date: `2026-04-10`

## Purpose

This program defines the final targeted closure schedule for the remaining
accepted dynamic failures under accepted `v8`.

Current accepted dynamic unresolved rows:

1. `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
2. `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
3. `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
4. `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
5. `dynamic::normal::0p05::500::default::exdqlm::mcmc`
6. `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

## Design Rules

1. Keep the accepted `v8` branch as the default baseline.
2. Reopen only the unresolved accepted dynamic rows.
3. Use row-specific historical evidence rather than generic tuning.
4. Avoid previously weak or redundant corridors.
5. Split the schedule into:
   - reinforcement of the strongest historical corridors
   - broader repair hedges around the unresolved hard rows

## Planned Search Space

Total planned candidates: `24`

- phase 1 `dynamic_reinforcement`: `12`
- phase 2 `dynamic_broad_repair`: `12`

High-level candidate logic:

- `gausmix / 0p05 / TT5000`
  - deep slice reinforcement plus one rw hedge
- `gausmix / 0p25 / TT500`
  - deep slice reinforcement corridor
- `laplace / 0p05 / TT500`
  - rw reinforcement, no-adapt rw, slice hedge, and longer rw hedge
- `laplace / 0p05 / TT5000`
  - deep slice reinforcement plus one rw hedge
- `normal / 0p05 / TT500`
  - rw-joint reinforcement, non-joint rw hedge, and slice hedges
- `normal / 0p05 / TT5000`
  - rw-joint long, non-joint rw long, no-adapt rw long, and slice hedge

Tracked schedule inputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_queue_20260410.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_dynamic_final_closure_deferred_inventory_20260410.csv`

## Important Status

The search design is complete, but the lane is not launch-ready until the
source-artifact dependency audit passes.
