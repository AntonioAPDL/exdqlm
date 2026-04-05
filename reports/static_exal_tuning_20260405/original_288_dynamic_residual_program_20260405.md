# Original 288 Dynamic Residual Program

Date: 2026-04-05

Status: validated residual-only execution plan for the corrected original-`288`
publication target.

## Current State

The corrected original-`288` carry-forward table is now the authoritative
comparison target.

Current audited state:

- original target: `288`
- healthy now: `269`
- unresolved now: `19`
- all `19` unresolved cells are dynamic
- static paper: `72 / 72` healthy
- static shrink: `144 / 144` healthy

So the remaining problem is no longer broad validation recovery. It is a
dynamic-only residual closure problem.

Primary upstream references:

- `reports/static_exal_tuning_20260405/original_288_realignment_investigation_and_recovery_plan_20260405.md`
- `reports/static_exal_tuning_20260405/original_288_realignment_execution_20260405.md`
- `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_scoreable_candidate_inventory_v1_20260405.csv`

## What Improved

- the study target is now correctly re-anchored to the original `288` baseline
  cells instead of the later hybrid `291` repair universe
- static recovery is complete under the original target
- dynamic healthy coverage already improved from `47 / 72` baseline healthy to
  `53 / 72` healthy through artifact harvest and corrected carry-forward
  assembly, without reopening static work
- the unresolved tail is now explicit, finite, and fully inventoried

## What Still Fails

There are `19` unresolved dynamic cells, all baseline-`FAIL`.

Residual shape:

- by method:
  - `7` `dqlm mcmc`
  - `10` `exdqlm mcmc`
  - `2` `exdqlm vb`
- by horizon:
  - `14` at `TT500`
  - `5` at `TT5000`
- by quantile:
  - `11` at `tau = 0p05`
  - `4` at `tau = 0p25`
  - `4` at `tau = 0p95`
- by family:
  - `8` `gausmix`
  - `8` `laplace`
  - `3` `normal`

## What Worked Best

- promoting repaired artifacts only when they clearly beat the baseline for the
  same original study cell
- keeping a corrected carry-forward table instead of mixing repaired and
  baseline semantics ad hoc
- harvesting archived candidate artifacts before launching new compute
- using scenario- or cluster-specific repair logic rather than forcing one
  universal tuning profile
- reusing the `LOCAL_full288_case_runner_20260327.R` runner so residual work
  stays aligned with the same execution and health-gating path used elsewhere

## What Did Not Help

- treating the healthy `291` repaired campaign as if it were the original
  publication target
- reopening solved static regions
- broad generic search over already weak or redundant directions
- rerunning healthy cells
- assuming late `F085`-band static lessons should directly control the dynamic
  tail without checking the dynamic archive and dynamic-specific runner history

## Highest-Value Direction

The next dynamic phase should:

1. rescore all still-unevaluated archived candidates for the `19` unresolved
   cells
2. rerun only the two unresolved dynamic `vb::exdqlm` long-horizon low-tail
   cells under relaxed VB controls
3. rerun only the `17` unresolved dynamic MCMC cells under cluster-specific
   MCMC repairs
4. promote any `PASS` or `WARN` result that clearly improves the baseline
   `FAIL` for the same original case key

## Residual Program Design

This phase is intentionally staged.

| phase | rows | purpose |
|---|---:|---|
| `archive_rescore_existing` | `22` | certify archived candidate fits already on disk but not yet explicitly scored into the corrected original-`288` carry-forward table |
| `vb_relaxed` | `2` | rescue the remaining `exdqlm vb` long-horizon low-tail failures under relaxed dynamic VB controls |
| `mcmc_targeted` | `17` | repair only the unresolved dynamic MCMC cells with method- and horizon-specific settings |
| `total` | `41` | full residual dynamic program |

### Archive Rescore Stage

Archived candidate mix:

- `19` from `rhsns_full_relaunch_20260327`
- `2` from `slice_wave1_20260319`
- `1` from `slice_pilot_20260318`

These candidates already exist on disk. They should be rescored first so we do
not waste compute rerunning cells that may already be salvageable.

### Relaxed VB Stage

Only `2` cells remain in unresolved `vb::exdqlm`, both long-horizon
`tau = 0p05` cases.

Config:

- `vb_relaxed`

Reason:

- keep the search extremely narrow
- relax convergence and stability controls only where the unresolved inventory
  says VB is still open

### Targeted MCMC Stage

This stage is split by problem cluster.

| config_id | rows | intended slice |
|---|---:|---|
| `mcmc_dqlm_cppgig_refresh` | `7` | unresolved `dqlm mcmc` cells |
| `mcmc_exdqlm_slice_short` | `7` | unresolved short-horizon `exdqlm mcmc` cells |
| `mcmc_exdqlm_joint_long` | `3` | unresolved long-horizon `exdqlm mcmc` cells |

Reason:

- `dqlm mcmc` and `exdqlm mcmc` have different failure patterns
- short- and long-horizon `exdqlm` cells should not be forced through the same
  geometry
- the `TT5000` `exdqlm` MCMC cells can optionally warm-start from the fresh
  stage-2 VB candidates when available

## Operational Rules

- do not reopen static work unless a provenance bug is discovered
- do not rerun any healthy original-`288` cells
- do not broaden the dynamic search space outside the unresolved `19`
- use current corrected original-`288` carry-forward as the baseline registry
- promote improvements only when they are `PASS` or `WARN` and clearly better
  than the unresolved baseline `FAIL`

## Acceptance Checks Before Launch

- prepare script regenerates the manifest and stage counts without errors
- evaluator runs cleanly on the pre-launch empty-result state
- selection preview runs cleanly on the pre-launch empty-result state
- shell scripts pass `bash -n`
- manifest count stays:
  - `22` archive rescoring rows
  - `2` VB rows
  - `17` MCMC rows
- no static rows are present in the manifest

## Morning-After Promotion Logic

For each unresolved original dynamic case key:

1. choose the best candidate by gate:
   - `PASS > WARN > FAIL > MISSING`
2. if tied on gate, prefer later targeted compute over earlier archive rescoring
3. only promote when the best candidate is `PASS` or `WARN` and strictly
   improves over the baseline `FAIL`

Outputs that will drive morning-after promotion:

- `tools/merge_reports/LOCAL_original288_dynamic_residual_case_best_20260405.csv`
- `tools/merge_reports/LOCAL_original288_dynamic_residual_selection_update_20260405.csv`
- `tools/merge_reports/LOCAL_original288_carryforward_selection_dynamic_residual_preview_20260405.csv`
- `tools/merge_reports/LOCAL_original288_health_summary_dynamic_residual_preview_20260405.csv`

## Completion Definition

This phase is complete when:

1. all `41` scheduled rows have a recorded status
2. the corrected original-`288` carry-forward preview has been regenerated
3. we know exactly how many of the `19` dynamic unresolved cells were repaired
   without ambiguity
4. any remaining unresolved dynamic cells are small enough to plan as a final
   residual follow-up rather than as another broad repair program
