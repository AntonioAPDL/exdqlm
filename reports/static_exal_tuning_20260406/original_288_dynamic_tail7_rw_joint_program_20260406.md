# Original 288 Dynamic Tail-7 RW-Joint Program

Date: 2026-04-06

This document defines the next residual dynamic repair phase after the
completed tail-7 geometry relaunch produced no promotable improvements and the
corrected original-`288` carry-forward table remained at `281 / 288` healthy.

## Starting State

- publication-target universe: original `288`
- healthy now: `281 / 288`
- unresolved now: `7 / 288`
- unresolved block: dynamic only
- unresolved method family: `mcmc :: exdqlm` only

Authoritative carry-forward references:

- `tools/merge_reports/LOCAL_original288_carryforward_selection_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v3_20260406.csv`
- `tools/merge_reports/LOCAL_original288_audit_v3_20260406.csv`

## What Improved

- tail-8 remains the last completed phase that improved the corrected baseline:
  - `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
  - promoted from `FAIL` to `PASS`
- corrected dynamic healthy coverage remains `65 / 72`
- corrected overall healthy coverage remains `281 / 288`
- all static debt remains closed:
  - `72 / 72` static paper healthy
  - `144 / 144` static shrink healthy

## What Still Fails

Only these `7` original dynamic case keys remain unresolved:

- `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
- `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
- `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
- `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
- `dynamic::normal::0p05::500::default::exdqlm::mcmc`
- `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Residual shape:

- `4` at `TT500`
- `3` at `TT5000`
- `6` at `tau = 0p05`
- `1` at `tau = 0p25`

## What Worked Best

- correcting the original-`288` carry-forward table before more tuning
- archive-first promotion
- explicit healthy same-scenario `exdqlm :: vb` warm starts
- exact slice rescues on moderate and upper-tail analogs
- promoting only when a candidate improves the same original case key from
  `FAIL` to `PASS` or `WARN`
- using the original case key, not the repaired hybrid universe, as the
  canonical unit for publication-target recovery

## What Did Not Help

- reopening static work
- rerunning archive rescoring after archive promotions were already applied
- broad mixed manifests after the tail isolated to `7` dynamic `exdqlm :: mcmc`
  rows
- exact long reruns at the old slice geometry:
  - `slice.width = 0.12`
  - `slice.max.steps = 80`
- full slice-geometry expansion in tail-7:
  - `0.18 / 120`
  - `0.24 / 160`
  - long `0.18 / 120` tau-`0p05` follow-up

## Highest-Value Direction

The remaining failures no longer look like good candidates for more slice work.
The surviving evidence now points to a narrow `laplace_rw` corridor:

1. the original baseline and the March 27 relaunch both used `laplace_rw`
2. several remaining failures under that corridor are mixing-limited rather
   than collapsed:
   - `gausmix / 0p05 / TT500`
   - `normal / 0p05 / TT500`
   - `normal / 0p05 / TT5000`
3. the dynamic model code already supports `joint.sample = TRUE`, but the
   current full-runner wrapper has not been exposing it for these relaunches
4. the runner already exposes Laplace refresh controls, which match the
   observed failure mode better than another slice-geometry sweep

So the next highest-value direction is:

- keep the default accepted corrected baseline at `281 / 288`
- switch the residual search from slice to `laplace_rw`
- expose `joint.sample = TRUE` through the validated full-runner wrapper
- keep explicit healthy same-scenario `exdqlm :: vb` warm starts
- use horizon-specific follow-up configs instead of searching for one universal
  winner

## Tail-7 RW-Joint Program Design

### Stage 1: `anchor7_rw_joint`

Scope:

- all `7` unresolved original dynamic cells

Configuration:

- `mcmc_exdqlm_rw_joint_anchor`
- `mh.proposal = laplace_rw`
- `joint.sample = TRUE`
- `init.from.vb = TRUE`
- `mh.adapt = TRUE`
- `mh.adapt.interval = 25`
- `mh.target.accept = c(0.20, 0.45)`
- `mh.scale.bounds = c(0.10, 10.0)`
- `mh.max_scale_step = 0.35`
- `mh.min_burn_adapt = 50`
- `laplace_refresh_interval = 25`
- `laplace_refresh_weight = 0.70`
- case-local runtime budget:
  - `TT500`: `n.burn = 1200`, `n.mcmc = 4000`, `laplace_refresh_start = 150`
  - `TT5000`: `n.burn = 3000`, `n.mcmc = 8000`, `laplace_refresh_start = 300`

Reason:

- this is the cleanest first test of the still-plausible `laplace_rw`
  corridor, using the previously unlaunched joint-recovery idea without
  reopening any already-screened slice family

### Stage 2: `tt500_rw_refresh4`

Scope:

- only the `4` remaining `TT500` rows

Configuration:

- `mcmc_exdqlm_rw_refresh_tt500`
- keep the stage-1 `laplace_rw`, `joint.sample`, and VB warm-start policy
- strengthen the refresh schedule:
  - `n.burn = 2000`
  - `n.mcmc = 6000`
  - `laplace_refresh_interval = 15`
  - `laplace_refresh_start = 100`
  - `laplace_refresh_weight = 0.85`

Reason:

- the short-horizon rows are the best candidates for a more aggressive
  proposal-refresh policy because they show the clearest “almost mixed enough”
  pattern under `laplace_rw`

### Stage 3: `tt5000_rw_joint_long3`

Scope:

- only the `3` remaining `TT5000` rows

Configuration:

- `mcmc_exdqlm_rw_joint_tt5000_long`
- keep the stage-1 `laplace_rw`, `joint.sample`, and VB warm-start policy
- raise the runtime budget and keep a stronger refresh weight:
  - `n.burn = 4000`
  - `n.mcmc = 12000`
  - `laplace_refresh_interval = 25`
  - `laplace_refresh_start = 300`
  - `laplace_refresh_weight = 0.85`

Reason:

- the long-horizon rows are more likely to need stronger post-burn exploration
  than another geometry change, especially after the slice family already
  failed across both short and long horizon cases

## Explicit Exclusions

These are intentionally excluded from this phase:

- static reruns of any kind
- `dqlm :: mcmc` work
- `exdqlm :: vb` work
- archive rescoring
- all old exact slice anchors and long reruns
- all tail-7 slice geometry expansions
- any broad mixed residual manifest
- any retest of already-screened weak slice families

## Planned Schedule

| phase | rows | rationale |
|---|---:|---|
| `anchor7_rw_joint` | `7` | new all-tail anchor in the only still-plausible MCMC corridor |
| `tt500_rw_refresh4` | `4` | stronger refresh follow-up on the short-horizon subgroup |
| `tt5000_rw_joint_long3` | `3` | longer-run follow-up on the long-horizon subgroup |
| `total` | `14` | dynamic-only `laplace_rw` residual program |

## Promotion Rule

Promote only when a new candidate:

1. maps to the same `original_case_key`
2. yields `PASS` or `WARN`
3. strictly improves the baseline `FAIL`

Tie-breaking among non-`FAIL` candidates:

1. `PASS` over `WARN`
2. all-tail anchor over specialized follow-up when the gate ties
3. faster runtime only after gate and phase preference tie

## Validation Requirements Before Launch

- runner exposes dynamic `joint.sample` cleanly through the manifest config path
- prepare writes exactly `14` rows
- every row has an explicit healthy `vb_candidate_fit_path`
- no row is marked `missing_inputs = TRUE`
- evaluator works on the empty pre-launch state
- selection preview works against carry-forward `v3`
- launch/supervisor/monitor pass `bash -n`
- branch is committed and pushed cleanly before overnight launch
