# Original 288 Dynamic Tail-8 Closure Program

Date: 2026-04-05

This document defines the next residual dynamic repair phase after the corrected
original-`288` carry-forward table reached `280 / 288` healthy and the archive
promotion pass reduced the remaining debt to `8` original dynamic cells.

## Starting State

- publication-target universe: original `288`
- healthy now: `280 / 288`
- unresolved now: `8 / 288`
- unresolved block: dynamic only
- unresolved method family: `mcmc :: exdqlm` only

Authoritative carry-forward references:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v2_20260405.csv`
- `tools/merge_reports/LOCAL_original288_audit_v2_20260405.csv`

## What Improved

- the archive-stage promotions are now part of the corrected original-`288`
  baseline
- dynamic healthy coverage improved from `53 / 72` to `64 / 72`
- the remaining queue is now only `8` original dynamic cells
- all unresolved `dqlm :: mcmc` and `exdqlm :: vb` dynamic cells have already
  been cleared

## What Still Fails

Only these `8` original dynamic case keys remain unresolved:

- `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Residual shape:

- `5` at `TT500`
- `3` at `TT5000`
- `6` at `tau = 0p05`
- `1` at `tau = 0p25`
- `1` at `tau = 0p95`

## What Worked Best

- correcting the original-`288` carry-forward table before more tuning
- archive-first promotion
- scenario-local repair instead of global search
- dynamic `exdqlm mcmc` rescues that use:
  - `mh_proposal = slice`
  - `mh_adapt = FALSE`
  - `n_burn = 1200`
  - `n_mcmc = 4000`
  - `slice_width = 0.12`
  - `slice_max_steps = 80`
  - `init_from_vb = TRUE`
- explicit healthy `exdqlm vb` warm starts from the corrected carry-forward map

## What Did Not Help

- broad mixed residual reruns after the archive stage
- reopening static work
- relying on the older mixed `joint_long` dynamic corridor as the main follow-up
- `laplace_rw`-style long-horizon retries in the remaining `exdqlm mcmc` tail
  when compared with the stronger slice-based historical rescues

## Highest-Value Direction

The highest-value next step is a reduced dynamic-only tail program that:

1. touches only the `8` unresolved original case keys
2. uses the exact successful slice corridor as the anchor configuration
3. keeps explicit healthy `exdqlm vb` warm starts for every case
4. adds only one small low-tail escalation on the `tau = 0p05` subset
5. does not rerun archive rescoring, resolved `dqlm :: mcmc`, or resolved
   `exdqlm :: vb`

## Tail-8 Program Design

### Stage 1: `anchor8_slice_sync`

Scope:

- all `8` unresolved original dynamic cells

Configuration:

- `mcmc_exdqlm_slice_sync`
- `mh.proposal = slice`
- `mh.adapt = FALSE`
- `n.burn = 1200`
- `n.mcmc = 4000`
- `trace.every = 50`
- `slice.width = 0.12`
- `slice.max.steps = 80`
- `init.from.vb = TRUE`
- explicit `vb_candidate_fit_path` from the selected healthy same-scenario
  `exdqlm vb` fit in carry-forward `v2`

Reason:

- this is the exact strongest historical rescue corridor on the surviving
  `exdqlm mcmc` analogs

### Stage 2: `tau05_long6_slice_sync`

Scope:

- only the `6` unresolved `tau = 0p05` cases

Configuration:

- `mcmc_exdqlm_slice_sync_long`
- same slice geometry and same explicit healthy VB warm starts
- longer runtime budget:
  - `n.burn = 2000`
  - `n.mcmc = 8000`

Reason:

- `tau = 0p05` is the dominant remaining tail cluster
- this adds breadth only where the residual pattern actually concentrates
- it keeps the historically successful slice geometry rather than reopening
  weaker corridors

## Explicit Exclusions

These are intentionally excluded from this phase:

- static reruns of any kind
- `dqlm :: mcmc` residual work
- `exdqlm :: vb` residual work
- archive rescoring
- broad mixed residual relaunch manifests
- `joint_long` as the primary dynamic rescue corridor
- generic `laplace_rw` retries across the remaining tail

## Planned Schedule

| phase | rows | rationale |
|---|---:|---|
| `anchor8_slice_sync` | `8` | exact historical rescue corridor on the whole remaining tail |
| `tau05_long6_slice_sync` | `6` | disciplined low-tail escalation only where residual debt clusters |
| `total` | `14` | dynamic-only residual closure program |

## Promotion Rule

Promote only when a tail-8 candidate:

1. maps to the same `original_case_key`
2. yields `PASS` or `WARN`
3. strictly improves the baseline `FAIL`

Tie-breaking among non-`FAIL` candidates:

1. `PASS` over `WARN`
2. longer targeted low-tail escalation over anchor when the gate ties
3. faster runtime only after gate and phase preference tie

## Validation Requirements Before Launch

- prepare writes exactly `14` rows
- every row has an explicit healthy `vb_candidate_fit_path`
- no row is marked `missing_inputs = TRUE`
- evaluator works on the empty pre-launch state
- selection preview works against carry-forward `v2`
- launch/supervisor/monitor pass `bash -n`
- branch is committed and pushed cleanly before overnight launch
