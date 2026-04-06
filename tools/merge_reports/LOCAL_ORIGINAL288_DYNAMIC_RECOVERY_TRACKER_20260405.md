# Original 288 Dynamic Recovery Tracker

Date: 2026-04-05

Purpose: operational tracker for the residual dynamic-only recovery phase after
the corrected original-`288` carry-forward rebuild.

## Current Corrected State

- original publication-target cells: `288`
- healthy now: `281`
- unresolved now: `7`
- unresolved block: dynamic only
- static paper: `72 / 72` healthy
- static shrink: `144 / 144` healthy

Authoritative references:

- `reports/static_exal_tuning_20260405/original_288_realignment_execution_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_program_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_execution_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_tail8_closure_program_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_tail8_closure_execution_20260405.md`
- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_geometry_program_20260406.md`
- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_geometry_execution_20260406.md`

## Residual Inventory Shape

### By method

- `7` `mcmc::exdqlm`

### By horizon

- `4` at `TT500`
- `3` at `TT5000`

### By quantile

- `6` at `tau = 0p05`
- `1` at `tau = 0p25`

## What Improved

- the target universe is now the original `288`, not the hybrid `291`
- all static debt has been removed from the publication-target recovery queue
- dynamic healthy coverage has now risen from `53 / 72` to `64 / 72` after
  archive-stage promotion
- tail-8 promoted one additional original dynamic case:
  - `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
  - upgraded from `FAIL` to `PASS`
- dynamic healthy coverage is now `65 / 72`
- the residual queue is now explicit, machine-readable, and down to `7` cases
- all unresolved `dqlm::mcmc` and `exdqlm::vb` cells were cleared in the
  archive stage

## What Still Fails

- `7` original dynamic cells remain unresolved
- all `7` are `exdqlm::mcmc`
- none of those `7` should be promoted until a residual candidate yields
  `PASS` or `WARN`

## What Worked Best

- carry-forward correction before more tuning
- archive-first rescue logic
- local scenario or cluster-specific repair instead of generic global search
- keeping the original case key as the canonical promotion unit
- stopping to regenerate the corrected original-`288` health state before any
  further relaunch planning
- the slice-based `exdqlm mcmc` rescue corridor with explicit healthy
  same-scenario `exdqlm vb` warm starts
- exact slice geometry on moderate and upper-tail analogs

## What Did Not Help

- relying on the hybrid `291` assembly for publication comparison
- reopening healthy static regions
- broad generic tuning across already resolved cells
- keeping the older mixed residual relaunch shape after the archive stage had
  already isolated the tail to `8` `exdqlm mcmc` cells
- treating `joint_long` or broader `laplace_rw` retries as the main follow-up
  corridor when the historical successes were slice-based
- rerunning the old exact `0.12 / 80` long low-tail slice follow-up after it
  already failed across the tau-`0p05` cluster in tail-8

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

## Tail-8 Closeout

Tail-8 has now completed and been applied back into the corrected original-288
baseline.

| phase | rows | intent |
|---|---:|---|
| `anchor8_slice_sync` | `8` | exact historical slice corridor on the full remaining tail |
| `tau05_long6_slice_sync` | `6` | longer low-tail follow-up only on the `tau = 0p05` cluster |
| `total` | `14` | reduced dynamic-only tail closure program |

Tail-8 outcome:

- `1` promoted rescue
- `13` non-promotable failures
- corrected state moved from `280 / 288` healthy to `281 / 288` healthy
- remaining unresolved tail moved from `8` to `7`

What tail-8 proved:

- exact `0.12 / 80` slice geometry can still rescue an upper/moderate tail case
- exact `0.12 / 80` long reruns do **not** rescue the residual `tau = 0p05`
  cluster
- the next credible search axis is slice geometry, not more time at the same
  geometry

## Tail-7 Geometry Relaunch Status

The next phase is now a reduced residual relaunch that starts from the
post-tail-8 corrected baseline and tests only slice-geometry changes on the
remaining `7` unresolved case keys.

| phase | rows | intent |
|---|---:|---|
| `anchor7_slice_band18` | `7` | moderate slice-geometry expansion on the full remaining tail |
| `anchor7_slice_band24` | `7` | wider slice-geometry expansion on the full remaining tail |
| `tau05_long6_slice_band18` | `6` | longer follow-up only on the dominant low-tail cluster |
| `total` | `20` | dynamic-only geometry-band closure program |

Operational rules carried into the relaunch:

- touch only the `7` remaining unresolved original dynamic case keys
- use explicit healthy `exdqlm vb` warm starts for every row
- do not rerun archive rescoring
- do not reopen `dqlm :: mcmc`, `exdqlm :: vb`, or any static work
- do not rerun the old exact `0.12 / 80` short or long tail-8 geometry
- promote only when a tail-7 candidate improves a baseline `FAIL` to `PASS` or
  `WARN`

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
- [x] remaining `8`-cell residual relaunch plan documented
- [x] reduced tail-8 manifest and helper stack implemented
- [x] prepare/evaluate/select and shell validation completed
- [x] reduced tail-8 overnight run completed and promoted back to carry-forward
- [x] corrected original-288 baseline moved to `281 / 288` healthy
- [x] remaining unresolved tail shrank to `7`
- [x] tail-7 geometry-band manifest and helper stack implemented
- [x] tail-7 prepare/evaluate/select and shell validation completed
- [ ] tail-7 overnight geometry-band run completed and reviewed

Current live sessions:

- `original288-dynamic-tail7-20260406`
- `original288-dynamic-tail7-monitor-20260406`
