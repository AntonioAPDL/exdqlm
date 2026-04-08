# Original 288 Dynamic Recovery Tracker

Date: 2026-04-05

Purpose: operational tracker for the residual dynamic-only recovery phase after
the corrected original-`288` carry-forward rebuild.

## Synced Integration Continuation Note (2026-04-06)

This tracker now lives on the synced continuation branch and should be read in
that context.

Predecessor validation worktree and branch:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- branch:
  `validation/rerun-after-0.4.0-sync`

Current active synced continuation point:

- worktree:
  `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration`
- branch:
  `validation/rerun-after-0.4.0-sync-0p4p0-integration`

Canonical synced-branch status note:

- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`

Important distinction carried forward on this branch:

- accepted publication-target state under `v7` is current:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- but the accepted selected fit paths still point to the predecessor worktree
- therefore the accepted carry-forward status and the rerun-on-synced-base
  status must be treated separately in planning and reporting

## Dynamic Tail6 Refine Closeout and Localmix Relaunch (2026-04-08)

The synced-base dynamic tail6 refine wave has now completed.

Accepted publication-target state remains unchanged under `v7`:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

Tail6 refine closeout:

- scope:
  - `6` accepted unresolved dynamic rows
- outcome:
  - `0 PASS`
  - `0 WARN`
  - `6 FAIL`
  - `0 / 6` healthy
- accepted comparison:
  - `6` matches accepted
  - `0` better than accepted
  - `0` worse than accepted
- promotions:
  - none

Most important learning:

- gamma remains the universal failing gate
- but several rows are no longer failing because of gross drift alone
- the strongest remaining blocker is now efficiency:
  - ESS-per-1k
  - autocorrelation
  - especially on gamma

Highest-value row-level reads:

- `gausmix / 0p25 / TT500` is the clearest ESS-limited near-miss
- `gausmix / 0p05 / TT5000` and `laplace / 0p05 / TT5000` improved under slice
  but stayed too sticky
- `normal / 0p05 / TT5000` improved under RW but still mixed too slowly
- `normal / 0p05 / TT500` remains the weakest short-horizon row

Current highest-value next move:

- keep the launch accepted-tail only
- do not reopen replay-repair rows
- do not run another generic longer-budget wave
- run a new compact localmix lane of `6` rows:
  - `4` bug-delayed closure corridors that never truly ran at intended budgets
  - `2` adaptive non-joint RW continuations on the normal rows

Primary references:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_tail6_refine_execution_20260407.md`
- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_program_20260408.md`
- `reports/static_exal_tuning_20260408/original_288_syncedbase_dynamic_tail6_localmix_execution_20260408.md`

## Dynamic Closure Closeout and Tail6 Refine Relaunch (2026-04-07)

The synced-base dynamic closure wave has now completed.

Accepted publication-target state remains unchanged under `v7`:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

Dynamic closure closeout:

- scope:
  - `12` rows
- outcome:
  - `0 PASS`
  - `0 WARN`
  - `12 FAIL`
  - `0 / 12` healthy
- accepted comparison:
  - `9` matches accepted
  - `0` better than accepted
  - `3` worse than accepted
- promotions:
  - none

Most important implementation finding:

- the case runner was still prioritizing reference-fit MCMC settings over
  manifest overrides
- that meant the intended stronger dynamic local schedules were not actually
  being honored in the completed closure wave

This bug is now fixed in:

- `tools/merge_reports/LOCAL_full288_case_runner_20260327.R`

Current highest-value next move:

- keep the launch accepted-tail only
- defer replay-repair rows that already looked low-value or worse
- relaunch only the `6` accepted unresolved dynamic rows
- use the best current row-local corridor per case with real override-respecting
  budgets

Active immediate next step on this branch:

- run the corrected dynamic tail6 refine lane:
  - `6` rows
  - one row-local continuation per accepted unresolved dynamic case
  - no replay-repair rows
  - no static reopening

Primary references:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_tail6_refine_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_tail6_refine_execution_20260407.md`

## Targeted Follow-Up Closeout and Dynamic Closure Launch (2026-04-07)

The synced-base targeted follow-up has now completed and its strict
improvements have been promoted into accepted `v7`.

Current accepted publication-target state:

- `282 / 288` healthy
- `230 PASS`
- `52 WARN`
- `6 FAIL`

Targeted follow-up closeout:

- scope:
  - `29` rows
- outcome:
  - `3 PASS`
  - `10 WARN`
  - `16 FAIL`
  - `13 / 29` healthy
- accepted comparison:
  - `3` better than accepted
  - `6` matches accepted
  - `20` worse than accepted

Dynamic implications:

- the accepted unresolved original dynamic tail is still:
  - `6` rows
  - all `exdqlm :: mcmc`
- the synced-base replay regression queue still contains:
  - `3` accepted-healthy dynamic rows that reproduce as `FAIL`
  - all `3` are `exdqlm :: mcmc`

Active immediate next step on this branch:

- run the new dynamic-only closure lane:
  - `6` primary accepted-tail repairs
  - `3` alternate kernel/family tests for the hardest accepted-tail rows
  - `3` replay-repair rows for the synced-base dynamic regressions
  - `12` total

Deferred for now:

- `13` static replay-fail rows
- `4` PASS-to-WARN stability-review rows

Primary references:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_program_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_dynamic_closure_execution_20260407.md`

## Faithful Replay Closeout and Residual Repair Pivot (2026-04-07)

The synced-base faithful replay of the accepted healthy `282` rows has now
completed and its strict improvements have been promoted into accepted `v5`.

Current accepted publication-target state:

- `282 / 288` healthy
- `6 / 288` unresolved
- accepted gate split:
  - `226 PASS`
  - `56 WARN`
  - `6 FAIL`

Faithful replay closeout:

- replay scope:
  - accepted healthy `282` rows only
- replay outcome:
  - `198 / 282` healthy
  - `84 / 282` fail
- comparison against accepted:
  - `31` better than accepted
  - `155` matches accepted
  - `96` worse than accepted

Important refinement:

- the active immediate repair queue on the synced branch is no longer
  dynamic-only
- the residual replay-repair queue is now:
  - `54` static `al :: mcmc` rows
  - `27` static `exal :: mcmc` rows
  - `3` dynamic `exdqlm :: mcmc` rows

This tracker remains authoritative for the unresolved original dynamic tail of
`6`, but the immediate next branch task is the broader residual replay-repair
program, not another direct attack on that unresolved tail.

## Residual Repair Closeout and Dynamic Follow-Up Refinement (2026-04-07)

The residual replay-repair program has now completed and the accepted baseline
has been refreshed to `v6`.

Accepted publication-target state:

- `282 / 288` healthy
- `227 PASS`
- `55 WARN`
- `6 FAIL`

Dynamic implications from the completed residual repair:

- the accepted unresolved original dynamic tail is still:
  - `6` rows
  - all `exdqlm :: mcmc`
- the synced-base replay regression queue now also contains:
  - `3` accepted-healthy dynamic rows that replayed as `FAIL`
  - all `3` are `exdqlm :: mcmc`
  - all `3` are now in scope for an exact-kernel longer-budget follow-up

Immediate dynamic next step on this branch:

- do **not** reopen the unresolved accepted tail of `6` yet
- first run the small synced-base follow-up dynamic lane:
  - `3` exact-kernel longer-budget reruns
  - same accepted kernel family
  - no broad new dynamic geometry search

Primary references:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_execution_20260407.md`
- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_program_20260407.md`

## Synced-Base Rerun Priority Note (2026-04-06)

Residual repair is no longer the immediate next action on this branch.

Before any further attempt to close the remaining `6` unresolved dynamic cells,
the study should first rerun the full accepted original-`288` map on the synced
`0.4.0` code base.

Validated rerun program:

- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_program_20260406.md`
- `reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_execution_20260406.md`

That rerun:

- keeps the accepted publication-target reference at `282 / 288` healthy
- uses the predecessor worktree only as read-only evidence and input source
- writes fresh candidate outputs into the synced integration worktree
- phases the full `288` as:
  - `144` VB
  - `108` static MCMC
  - `36` dynamic MCMC

So this tracker remains authoritative for the unresolved dynamic tail, but the
active immediate branch task is now synced-base rerun / revalidation, not
another residual-tail search.

## Current Corrected State

- original publication-target cells: `288`
- healthy now: `282`
- unresolved now: `6`
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
- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_program_20260406.md`
- `reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_execution_20260406.md`
- `reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md`

## Residual Inventory Shape

### By method

- `6` `mcmc::exdqlm`

### By horizon

- `3` at `TT500`
- `3` at `TT5000`

### By quantile

- `5` at `tau = 0p05`
- `1` at `tau = 0p25`

## What Improved

- the target universe is now the original `288`, not the hybrid `291`
- all static debt has been removed from the publication-target recovery queue
- dynamic healthy coverage has now risen from `53 / 72` to `64 / 72` after
  archive-stage promotion
- tail-8 promoted one additional original dynamic case:
  - `dynamic::gausmix::0p95::500::default::exdqlm::mcmc`
  - upgraded from `FAIL` to `PASS`
- tail-7 `rw` promoted one additional original dynamic case:
  - `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
  - upgraded from `FAIL` to `WARN`
- dynamic healthy coverage is now `66 / 72`
- the residual queue is now explicit, machine-readable, and down to `6` cases
- all unresolved `dqlm::mcmc` and `exdqlm::vb` cells were cleared in the
  archive stage

## What Still Fails

- `6` original dynamic cells remain unresolved
- all `6` are `exdqlm::mcmc`
- none of those `6` should be promoted until a residual candidate yields
  `PASS` or `WARN`

## What Worked Best

- carry-forward correction before more tuning
- archive-first rescue logic
- local scenario or cluster-specific repair instead of generic global search
- keeping the original case key as the canonical promotion unit
- stopping to regenerate the corrected original-`288` health state before any
  further relaunch planning
- explicit healthy same-scenario `exdqlm :: vb` warm starts
- slice-based `exdqlm :: mcmc` rescues on moderate and upper-tail analogs
- archive and targeted evidence promotion before new compute

## What Did Not Help

- relying on the hybrid `291` assembly for publication comparison
- reopening healthy static regions
- broad generic tuning across already resolved cells
- keeping the older mixed residual relaunch shape after the archive stage had
  already isolated the tail to `8` `exdqlm mcmc` cells
- rerunning the old exact `0.12 / 80` long low-tail slice follow-up after it
  already failed across the tau-`0p05` cluster in tail-8
- the full tail-7 slice-geometry relaunch:
  - `slice.width = 0.18`, `slice.max.steps = 120`
  - `slice.width = 0.24`, `slice.max.steps = 160`
  - long `0.18 / 120` tau-`0p05` follow-up

## Highest-Value Direction

- keep the corrected original-`288` carry-forward table as the only
  publication-target baseline
- keep the current accepted dynamic baseline at `282 / 288` healthy and
  promote only strict same-case improvements
- stop expanding slice geometry on the surviving tail
- shift the residual search to a narrow `laplace_rw` corridor with:
  - explicit healthy same-scenario `exdqlm :: vb` warm starts
  - dynamic `joint.sample = TRUE`
  - adaptive refresh control for the Laplace proposal
  - horizon-specific runtime budgets rather than one universal setting
- prioritize learning value per unit compute:
  - one all-tail `laplace_rw` anchor
  - one TT500-focused refresh lane
  - one TT5000-focused long lane

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

## Tail-7 Geometry Relaunch Closeout

Tail-7 completed cleanly and produced no promotable improvements.

| phase | rows | intent |
|---|---:|---|
| `anchor7_slice_band18` | `7` | moderate slice-geometry expansion on the full remaining tail |
| `anchor7_slice_band24` | `7` | wider slice-geometry expansion on the full remaining tail |
| `tau05_long6_slice_band18` | `6` | longer follow-up only on the dominant low-tail cluster |
| `total` | `20` | dynamic-only geometry-band closure program |

Tail-7 outcome:

- `0` promoted rescues
- `20 / 20` completed rows remained `FAIL`
- corrected original-`288` baseline stays at:
  - `281 / 288` healthy
  - `7 / 288` unresolved
- the slice-geometry expansion family is now screened out on the surviving
  dynamic tail

## Tail-7 RW-Joint Closeout

Tail-7 `rw` completed cleanly and produced one promotable improvement.

| phase | rows | intent |
|---|---:|---|
| `anchor7_rw_joint` | `7` | all-tail `laplace_rw` anchor with VB warm starts and joint covariance rebuild |
| `tt500_rw_refresh4` | `4` | short-horizon refresh-focused follow-up |
| `tt5000_rw_joint_long3` | `3` | long-horizon joint/length follow-up |
| `total` | `14` | dynamic-only `laplace_rw` residual program |

Tail-7 `rw` outcome:

- `1` promoted rescue
- `13` non-promotable failures
- corrected original-`288` baseline moved from:
  - `281 / 288` healthy
  - `7 / 288` unresolved
- to:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- the promoted case is:
  - `dynamic::gausmix::0p05::500::default::exdqlm::mcmc`
  - upgraded from `FAIL` to `WARN`
- the `TT5000` long lane produced `0` rescues
- remaining unresolved cases are:
  - `dynamic::gausmix::0p25::500::default::exdqlm::mcmc`
  - `dynamic::laplace::0p05::500::default::exdqlm::mcmc`
  - `dynamic::normal::0p05::500::default::exdqlm::mcmc`
  - `dynamic::gausmix::0p05::5000::default::exdqlm::mcmc`
  - `dynamic::laplace::0p05::5000::default::exdqlm::mcmc`
  - `dynamic::normal::0p05::5000::default::exdqlm::mcmc`

Operational rules carried into the follow-up:

- touch only the `7` remaining unresolved original dynamic case keys
- use explicit healthy `exdqlm vb` warm starts for every row
- do not rerun archive rescoring
- do not reopen `dqlm :: mcmc`, `exdqlm :: vb`, or any static work
- do not rerun the old exact `0.12 / 80` short or long tail-8 geometry
- do not rerun the failed tail-7 slice geometry bands
- promote only when a new candidate improves a baseline `FAIL` to `PASS` or
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
- [x] corrected original-288 baseline moved to `282 / 288` healthy
- [x] remaining unresolved tail shrank to `6`
- [x] tail-7 geometry-band manifest and helper stack implemented
- [x] tail-7 prepare/evaluate/select and shell validation completed
- [x] tail-7 overnight geometry-band run completed and reviewed
- [x] tail-7 rw-joint manifest and helper stack implemented
- [x] tail-7 rw-joint prepare/evaluate/select and shell validation completed
- [x] tail-7 rw-joint overnight run launched from clean pushed branch
- [x] tail-7 rw-joint overnight run completed and reviewed
- [x] tail-7 rw-joint promotion applied to carry-forward `v4`
