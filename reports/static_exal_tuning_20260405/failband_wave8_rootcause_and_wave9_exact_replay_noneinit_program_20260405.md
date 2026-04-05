# Validation Campaign: Wave-8 Static Root Cause and Wave-9 Exact-Replay + None-Init Closure Program

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave7_closeout_and_wave8_seedinit_dynamic_closure_program_20260405.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave8_failures_20260405_010431_8030_1967051.log`
- `tools/merge_reports/LOCAL_static_exal_failband_wave8_schedule_20260405.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_wave8_matrix_20260405.csv`

## Status Note

The dynamic row-15 sidecar is still running and should be left alone.

The static wave-8 lane stopped because of a real scientific failure mode plus a
real orchestration bug:

1. the remaining row-`135` and row-`174` `vb` probes were invalid and crashed
   immediately
2. the static launcher/supervisor path still treated "launcher returned" as a
   finished stage even when crashed rows remained `MISSING`

Wave-9 therefore needs to do two things at once:

- fix the static launcher/supervisor completeness rule
- replace the low-value `vb` probes on rows `135` and `174` with the highest
  value remaining exact historical replays plus `init_mode = none`

## Wave-8 Static Root Cause

### What actually stopped

Static wave-8 did **not** stall because of tmux or because jobs were still
quietly running in the background.

What happened was:

- the row-`87` confirmation finished and regressed to `FAIL`
- the row-`269` `vb` probes improved to `WARN`
- all six remaining `vb` probes for rows `135` and `174` crashed with `rc=1`
- the launcher kept going, wrote those failures into the failure log, and then
  exited as if the stage had completed
- the supervisor then ran its final evaluation and exited, even though six rows
  were still `MISSING`

### Scientific failure mode

The wave-8 failure log and row logs show a shared crash signature:

`Static MCMC state invalid (iter=2): static_exal chi has 1000 non-finite values (first index=1)`

Affected rows:

| row | candidate corridor | init mode | wave-8 outcome |
|---|---|---|---|
| `135` | `F0825_sub2_s105` | `vb` | runtime crash |
| `135` | `F0835_sub2_s1025` | `vb` | runtime crash |
| `135` | `F0840_sub2_s1025` | `vb` | runtime crash |
| `174` | `F0835_sub2_s1025` | `vb` | runtime crash |
| `174` | `F0845_sub2_s100` | `vb` | runtime crash |
| `174` | `F0875_sub2_s105` | `vb` | runtime crash |

Interpretation:

- `vb` is now clearly a **bad closure axis** for rows `135` and `174`
- row `269` is different; its `vb` path improved to `WARN` and remains useful

### Orchestration root cause

The static launch/supervisor stack had a completeness bug:

- row crashes were logged, but `keep_going = 1` allowed the launcher to return
  success
- the supervisor used launcher return status as a stage-success proxy
- it did **not** stop when the evaluator still reported `missing > 0`

This is the main operational root cause of the static supervisor stop.

### Fix applied

The static launcher now:

- runs the evaluator after each launch stage
- parses the `SUMMARY` line
- exits non-zero if any rows remain `MISSING`

That means a crash-heavy stage can no longer masquerade as a finished stage.

## What Improved

1. the static problem is now even narrower than before: the real active set is
   only rows `87`, `135`, `174`, and `269`
2. row `269` improved from `FAIL` to a fresh `WARN` under:
   - `F0845_sub2_s100_vb`
3. wave-8 proved that row `87` is not missing a geometry corridor; it is
   **seed-sensitive / unstable**
4. the static launch path is now repaired so future overnight runs will stop
   loudly instead of quietly "finishing" with missing rows

## What Still Fails

Current active static issues:

| row | current read | current best anchor |
|---|---|---|
| `87` | unstable (`WARN` history, wave-8 replay regressed to `FAIL`) | `F085_sub2_s1025` exact-history corridor |
| `135` | `FAIL` | exact historical short `PASS/WARN` anchors only |
| `174` | `FAIL` | exact historical short `WARN` anchors only |
| `269` | `WARN` | `F0845_sub2_s100_vb` |

Dynamic sidecar:

| row | current state |
|---|---|
| `15` | still running in the separate dynamic slice lane |

## What Worked Best

1. keep `F085_sub2_s100` as the broad static default instead of replacing the
   whole baseline again
2. promote row-local improvements only when fresh evidence clearly improves on
   the previous map
3. use exact historical rescue anchors for the final hard rows
4. allow `vb` only where it already proved helpful:
   - row `269`
5. treat row `87` as a seed-stability problem, not a generic geometry-search
   problem

## What Did Not Help

1. `vb` init on rows `135` and `174`
2. another generic confirmation replay on row `87` with a new seed
3. more broad family search
4. returning to already screened weak corridors outside the narrow
   `F0825` to `F0855` local-repair band

## Promoted Static Baseline v5

The promoted static baseline should now be:

- broad default:
  - `F085_sub2_s100`
- promoted row-local map:

| scope | row_id | preferred candidate | role | current best read |
|---|---:|---|---|---|
| `current_rhsns_refresh` | `87` | `F085_sub2_s1025` exact-history replay corridor | unstable local exception | `WARN_then_FAIL` |
| `current_rhsns_refresh` | `115` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `current_rhsns_refresh` | `135` | open closure set | historical exact replay only | `FAIL` |
| `current_rhsns_refresh` | `174` | open closure set | historical exact replay only | `FAIL` |
| `current_rhsns_refresh` | `190` | `F0825_sub2_s100_rwlong` | stable `WARN` | `WARN` |
| `current_rhsns_refresh` | `206` | `F0825_sub2_s1025_rwlong` | stable `PASS` | `PASS` |
| `current_rhsns_refresh` | `278` | `F0845_sub2_s1025` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `181` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `269` | `F0845_sub2_s100_vb` | promoted local `WARN` anchor | `WARN` |

## Highest-Value Directions Now

1. keep `F085_sub2_s100` as the broad static default
2. do **not** spend more compute on another generic shared-setup search
3. use exact historical seed replay to stabilize row `87`
4. use exact historical short anchors plus `init_mode = none` on rows `135`
   and `174`
5. treat row `269` as nearly solved and focus on confirming the promoted
   `F0845_sub2_s100_vb` anchor plus one no-warm-start fallback
6. keep dynamic row `15` separate until its two active slice runs finish

## Wave-9 Static Strategy

### Guiding principle

Wave-9 is not another discovery wave.

It is a controlled exact-replay closure lane that:

1. replays the known non-`FAIL` row-`87` anchors using their original seeds
2. confirms and hardens the promoted row-`269` local rescue
3. closes rows `135` and `174` using exact historical short anchors plus
   `init_mode = none`

### Stage design

| stage | purpose | runs |
|---|---|---:|
| `stability7_exact` | exact-history replay on row `87` and row `269` | 7 |
| `closure12_exact_none` | exact historical short anchors plus `none` init on rows `135` and `174` | 12 |
| `overall` | total static wave-9 closure budget | 19 |

### Why these candidates are included

#### Row `87`

Included:

- exact replay of the successful wave-7 `slice_eta` WARN anchor
- exact replay of the successful wave-7 `rwlong` WARN anchor
- exact replay of the earlier short historical WARN anchor

Why:

- row `87` is now a seed-stability problem
- the remaining value is in exact-history replay, not in new geometry search

#### Row `135`

Included:

- exact replay of both historical PASS anchors
- exact replay of the strongest historical WARN fallbacks
- `init_mode = none` probes on the two historical PASS anchors

Why:

- wave-8 showed `vb` is invalid here
- the highest-value remaining space is exact rescue replay plus no-warm-start

#### Row `174`

Included:

- exact replay of all credible historical WARN anchors
- `init_mode = none` probes on the two strongest historical rescue corridors

Why:

- wave-8 showed `vb` is invalid here
- wave-7 showed longer generic runs are not enough

#### Row `269`

Included:

- exact replay of the promoted wave-8 `vb` WARN rescue
- exact replay of the strongest historical short WARN anchor
- one `init_mode = none` variant on the promoted geometry
- one lower-jump `vb` comparator still supported by wave-8 evidence

Why:

- row `269` is now the closest static row to closure
- the right question is no longer "can any geometry help?" but
  "which local version is the cleanest non-FAIL anchor?"

### Explicit exclusions

Wave-9 intentionally excludes:

- any new broad family search
- more `vb` probes on rows `135` and `174`
- any rerun of weak `F075` / `F080` residual-band families
- any outer-frontier `F088+` broad restarts
- any generic long-run search on rows that already have cleaner exact-history
  evidence

## Operational validation before launch

The wave-9 stack is valid only if all of the following pass:

1. prepare writes the new schedule cleanly
2. evaluator reads the new schedule cleanly
3. shell scripts pass `bash -n`
4. the static launcher exits non-zero if a stage still has `MISSING` rows
5. the old static wave-8 monitor is retired before wave-9 starts

## Bottom line

This is still good progress.

The campaign tail is now small, interpretable, and highly local:

- static: `87`, `135`, `174`, `269`
- dynamic: `15`

The right overnight move is therefore:

1. leave the dynamic row-15 sidecar running
2. fix the static launcher/supervisor completeness rule
3. launch wave-9 static on the exact remaining local-repair space only

That is the shortest rigorous path toward eliminating the last `FAIL`s without
reopening broad low-value search.
