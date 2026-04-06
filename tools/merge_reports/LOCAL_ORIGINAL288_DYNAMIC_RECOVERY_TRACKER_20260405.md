# Original 288 Dynamic Recovery Tracker

Date: 2026-04-05

Purpose: operational tracker for the residual dynamic-only recovery phase after
the corrected original-`288` carry-forward rebuild.

## Current Corrected State

- original publication-target cells: `288`
- healthy now: `280`
- unresolved now: `8`
- unresolved block: dynamic only
- static paper: `72 / 72` healthy
- static shrink: `144 / 144` healthy

Authoritative references:

- `reports/static_exal_tuning_20260405/original_288_realignment_execution_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_program_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_execution_20260405.md`

## Residual Inventory Shape

### By method

- `8` `mcmc::exdqlm`

### By horizon

- `5` at `TT500`
- `3` at `TT5000`

### By quantile

- `6` at `tau = 0p05`
- `1` at `tau = 0p25`
- `1` at `tau = 0p95`

## What Improved

- the target universe is now the original `288`, not the hybrid `291`
- all static debt has been removed from the publication-target recovery queue
- dynamic healthy coverage has now risen from `53 / 72` to `64 / 72` after
  archive-stage promotion
- the residual queue is now explicit and machine-readable
- all unresolved `dqlm::mcmc` and `exdqlm::vb` cells were cleared in the
  archive stage

## What Still Fails

- `8` original dynamic cells remain unresolved
- all `8` are `exdqlm::mcmc`
- none of those `8` should be promoted until a residual candidate yields
  `PASS` or `WARN`

## What Worked Best

- carry-forward correction before more tuning
- archive-first rescue logic
- local scenario or cluster-specific repair instead of generic global search
- keeping the original case key as the canonical promotion unit
- stopping to regenerate the corrected original-`288` health state before any
  further relaunch planning

## What Did Not Help

- relying on the hybrid `291` assembly for publication comparison
- reopening healthy static regions
- broad generic tuning across already resolved cells

## Residual Program Status

| phase | rows | intent |
|---|---:|---|
| `archive_rescore_existing` | `22` | score archived on-disk candidates not yet explicitly certified |
| `vb_relaxed` | `2` | rescue the remaining unresolved dynamic VB cells |
| `mcmc_targeted` | `17` | rescue unresolved dynamic MCMC cells by method/horizon cluster |
| `total` | `41` | full residual dynamic program |

Current execution checkpoint:

- `archive_rescore_existing`: `22 / 22` complete
- archive-stage outcome: `7 PASS / 4 WARN / 11 FAIL`
- promoted archive rescues: `11`
- later phases were not started in this checkpoint because the evaluator path
  failed after archive completion and has now been repaired
- no new relaunch is planned in this tracker checkpoint

## Promotion Rule

Promote only when a residual candidate:

1. maps to the same `original_case_key`
2. yields `PASS` or `WARN`
3. strictly improves over the unresolved baseline `FAIL`

Tie-breaking among non-`FAIL` candidates:

1. higher gate first: `PASS > WARN`
2. later targeted compute preferred over archive rescoring when gates tie

## Checklist

- [x] corrected original-`288` registry built
- [x] unresolved dynamic inventory frozen
- [x] archive catalog built
- [x] residual manifest built
- [x] evaluator implemented
- [x] promotion preview implemented
- [x] launcher/supervisor/monitor implemented
- [x] pre-launch validation completed
- [x] overnight residual run launched from clean pushed branch
- [x] morning-after promotion preview reviewed
- [x] corrected original-`288` carry-forward table updated with archive-stage
      non-`FAIL` dynamic rescues
- [x] residual evaluator/selector merged-schema bug fixed
- [ ] remaining `8`-cell residual relaunch plan intentionally deferred
      beyond this checkpoint

Current live sessions:

- none
