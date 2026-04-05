# Original 288 Dynamic Recovery Tracker

Date: 2026-04-05

Purpose: operational tracker for the residual dynamic-only recovery phase after
the corrected original-`288` carry-forward rebuild.

## Current Corrected State

- original publication-target cells: `288`
- healthy now: `269`
- unresolved now: `19`
- unresolved block: dynamic only
- static paper: `72 / 72` healthy
- static shrink: `144 / 144` healthy

Authoritative references:

- `reports/static_exal_tuning_20260405/original_288_realignment_execution_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_program_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_dynamic_residual_execution_20260405.md`

## Residual Inventory Shape

### By method

- `7` `mcmc::dqlm`
- `10` `mcmc::exdqlm`
- `2` `vb::exdqlm`

### By horizon

- `14` at `TT500`
- `5` at `TT5000`

### By quantile

- `11` at `tau = 0p05`
- `4` at `tau = 0p25`
- `4` at `tau = 0p95`

## What Improved

- the target universe is now the original `288`, not the hybrid `291`
- all static debt has been removed from the publication-target recovery queue
- dynamic healthy coverage already rose from `47 / 72` to `53 / 72` via
  corrected carry-forward plus archive harvest
- the residual queue is now explicit and machine-readable

## What Still Fails

- `19` original dynamic cells remain unresolved
- all are still baseline `FAIL`
- none of those `19` should be promoted until a residual candidate yields
  `PASS` or `WARN`

## What Worked Best

- carry-forward correction before more tuning
- archive-first rescue logic
- local scenario or cluster-specific repair instead of generic global search
- keeping the original case key as the canonical promotion unit

## What Did Not Help

- relying on the hybrid `291` assembly for publication comparison
- reopening healthy static regions
- broad generic tuning across already resolved cells

## Active Residual Program

| phase | rows | intent |
|---|---:|---|
| `archive_rescore_existing` | `22` | score archived on-disk candidates not yet explicitly certified |
| `vb_relaxed` | `2` | rescue the remaining unresolved dynamic VB cells |
| `mcmc_targeted` | `17` | rescue unresolved dynamic MCMC cells by method/horizon cluster |
| `total` | `41` | full residual dynamic program |

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
- [ ] morning-after promotion preview reviewed
- [ ] corrected original-`288` carry-forward table updated if new non-`FAIL`
      dynamic rescues land

Current live sessions:

- `original288-dynamic-residual-20260405`
- `original288-dynamic-residual-monitor-20260405`
