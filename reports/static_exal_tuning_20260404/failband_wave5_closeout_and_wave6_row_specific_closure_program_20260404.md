# Validation Campaign: Fail-Band Wave-5 Closeout and Wave-6 Row-Specific Closure Program

Date: 2026-04-04

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave4_closeout_and_wave5_local_repair_program_20260404.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave5_schedule_20260404.csv`

## Status Note

Wave-5 is complete.

This is still good news operationally and scientifically, even though wave-5
did not cleanly confirm the first provisional local map.

Why it is still good news:

- the local confirmation/probe lane completed cleanly end to end
- it narrowed the real remaining static closure problem from a diffuse
  `9`-row residual band to a much smaller row-specific closure task
- it showed which provisional local choices were genuinely durable and which
  ones were too brittle to promote unchanged
- it supports a better evidence-weighted local baseline rather than forcing us
  back into another shared-setup search

The active next-step program is therefore no longer:

- "find a new generic bridge profile"

It is now:

- keep `F085_sub2_s100` as the broad default
- promote only the row-level overrides that still look durable after wave-5
- spend new compute only on the remaining static `FAIL` rows plus a small
  stability lane for the non-`FAIL` rows that are still shaky

## Wave-5 Closeout

### Final wave-5 result

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `confirm9` | 9 | 1 | 4 | 4 | 0 | 5 |
| `probe2` | 2 | 0 | 1 | 1 | 0 | 1 |
| `overall` | 11 | 1 | 5 | 5 | 0 | 6 |

### What improved

- wave-5 confirmed that the static repair problem should now be treated as a
  row-specific closure task, not a residual shared-setup search
- the broad default baseline remains:
  - `F085_sub2_s100`
- the local override map improved materially after reweighting the evidence
  toward repeated `PASS` / `WARN` support instead of one-off best hits
- rows `115`, `174`, `181`, `206`, and `278` now have clearer row-specific
  leaders than they did before wave-5

### What still fails

The remaining static `FAIL` rows after the wave-5 confirmation/probe lane are:

| scope | row_id | family | tt | tau | best current non-FAIL fallback |
|---|---:|---|---:|---|---|
| `current_rhsns_refresh` | `135` | `normal` | `1000` | `0p25` | `F0845_sub2_s100` (`WARN`) |
| `current_rhsns_refresh` | `190` | `gausmix` | `1000` | `0p95` | `F0825_sub2_s1025` (`PASS/WARN` history, but still needs closure confirmation) |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` | `F0845_sub2_s100` (`WARN`) |

Rows that are no longer `FAIL` but still matter for stability/provenance:

| scope | row_id | current best read | current preferred candidate |
|---|---:|---|---|
| `current_rhsns_refresh` | `87` | stable `WARN` | `F085_sub2_s1025` |
| `current_rhsns_refresh` | `115` | stable `PASS` | `F0825_sub2_s100` |
| `current_rhsns_refresh` | `174` | stable `WARN` | `F0875_sub2_s105` |
| `current_rhsns_refresh` | `206` | promising `PASS/WARN` | `F0825_sub2_s1025` |
| `legacy_rhs_refresh` | `181` | stable `PASS/WARN` | `F0825_sub2_s100` |
| `current_rhsns_refresh` | `278` | stable `PASS` | `F0845_sub2_s1025` |

Dynamic row `15` remains separate and unresolved.

## What Worked Best

1. keeping `F085_sub2_s100` as the broad default instead of replacing it
2. promoting row-level overrides only when they have repeated non-`FAIL`
   support
3. `F0825_sub2_s100` for the `tt100` paper/shrink edge rows
4. `F0825_sub2_s1025` as the best current control for the difficult
   `gausmix / tt1000 / tau0p95` row `190`
5. `F0845_sub2_s100` as the safest current fallback on the stubborn normal
   `tt1000 / tau0p25` rows
6. `F0875_sub2_s105` only as a row-specific outlier for row `174`, not as a
   generic family direction

## What Clearly Did Not Help

1. preserving the wave-4 provisional local map unchanged after wave-5
2. treating one-off `PASS` outcomes as automatically better than repeated
   `WARN`/`PASS` support
3. reopening a generic shared-setup search after wave-5
4. scale-`1.025` on legacy row `269`
5. broad `F0875_*` search outside the single row-`174` exception
6. previously screened families and directions:
   - `F075_*`
   - `F080_*` as an active residual repair family
   - `F090 / F095`
   - `s095` broad restarts

## Promoted Static Baseline v2

The active static baseline is now:

- broad default: `F085_sub2_s100`
- local repair baseline v2: evidence-weighted row-specific overrides only where
  the default still fails or is dominated by a more durable local option

This should be treated as an improvement over the older provisional local map,
because it no longer anchors rows `115`, `174`, `181`, `190`, `206`, and
`269` to the choices that wave-5 directly weakened.

### Active local repair baseline v2

| scope | row_id | family | tt | tau | preferred candidate | current role | current best read |
|---|---:|---|---:|---|---|---|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` | `F085_sub2_s1025` | stable local WARN | `WARN` |
| `current_rhsns_refresh` | `115` | `laplace` | `100` | `0p95` | `F0825_sub2_s100` | promoted stable local PASS | `PASS` |
| `current_rhsns_refresh` | `135` | `normal` | `1000` | `0p25` | `F0845_sub2_s100` | safest current fallback; still active closure row | `WARN` |
| `current_rhsns_refresh` | `174` | `gausmix` | `1000` | `0p25` | `F0875_sub2_s105` | promoted row-specific WARN exception | `WARN` |
| `current_rhsns_refresh` | `190` | `gausmix` | `1000` | `0p95` | `F0825_sub2_s1025` | best current closure anchor | `PASS/WARN` history |
| `current_rhsns_refresh` | `206` | `laplace` | `1000` | `0p05` | `F0825_sub2_s1025` | promoted stable local PASS/WARN | `PASS/WARN` history |
| `current_rhsns_refresh` | `278` | `normal` | `100` | `0p95` | `F0845_sub2_s1025` | stable local PASS | `PASS` |
| `legacy_rhs_refresh` | `181` | `gausmix` | `100` | `0p95` | `F0825_sub2_s100` | promoted stable local PASS/WARN | `PASS/WARN` history |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` | `F0845_sub2_s100` | safest current fallback; still active closure row | `WARN` |

Evidence-weighted interpretation of this map:

- `5 PASS`
- `4 WARN`
- `0 FAIL`

This is an evidence-weighted planning baseline, not a final signoff baseline.
Rows `135`, `190`, and `269` still need a dedicated closure lane because their
best historical evidence is either unstable or only `WARN`.

## Active Remaining Work

The active static repair debt is now split into two different kinds of work.

### Core closure rows

These are the rows that still need the most careful local repair work:

| row_id | reason still active |
|---:|---|
| `135` | only unstable `PASS` evidence; safest stable fallback is still `WARN` |
| `190` | has one promising local winner, but prior confirmation regressed on a nearby choice |
| `269` | still no convincing `PASS`; safest evidence is `WARN` only |

### Stability/provenance rows

These are already non-`FAIL`, but they still merit one narrow confirmation pass
under the improved evidence-weighted map:

| row_id | current preferred candidate |
|---:|---|
| `87` | `F085_sub2_s1025` |
| `115` | `F0825_sub2_s100` |
| `174` | `F0875_sub2_s105` |
| `181` | `F0825_sub2_s100` |
| `206` | `F0825_sub2_s1025` |
| `278` | `F0845_sub2_s1025` |

Dynamic row `15` remains the only dynamic sidecar debt.

## Wave-6 Strategy

### Guiding principle

Wave-6 should not reopen any generic search.

Instead it should do two things only:

1. confirm the evidence-weighted local repair baseline v2 on the full
   `9`-row residual band
2. spend extra compute only on the `3` core closure rows with the highest-value
   row-specific alternatives and interpolants

### Why this is the right search shape

The completed evidence now tells us:

- rows `87`, `115`, `174`, `181`, `206`, and `278` already have at least one
  credible row-specific non-`FAIL` choice
- rows `135`, `190`, and `269` are the only remaining rows where we still need
  better closure confidence
- the active tuning space is no longer "a family"
  but a small set of row-specific local neighborhoods

### Wave-6 stage design

| stage | rows | purpose | run count |
|---|---:|---|---:|
| `confirm9_v2` | 9 | confirm the evidence-weighted local repair baseline v2 under fresh final tags | 9 |
| `repair13` | 13 | probe only the three remaining core closure rows with row-specific alternatives | 13 |
| `overall` | 22 | targeted row-specific closure program | 22 |

### Wave-6 row-specific search space

#### Row `135` (`normal / tt1000 / tau0p25`)

Included:

- `F0825_sub2_s105`
- `F0830_sub2_s105`
- `F0835_sub2_s1025`
- `F0840_sub2_s1025`
- `F0845_sub2_s1025`

Why:

- `F0825_sub2_s105` and `F0835_sub2_s1025` are the only observed `PASS`
  profiles, but both are unstable
- `F0845_sub2_s100` becomes the confirm-stage anchor because it is the safest
  current non-`FAIL` fallback
- the new `F0830` / `F0840` probes are high-value interpolants between the
  unstable `PASS` hits and the safer upper-mid `WARN` region

#### Row `190` (`gausmix / tt1000 / tau0p95`)

Included:

- `F0830_sub2_s1025`
- `F0835_sub2_s1025`
- `F0840_sub2_s1025`
- `F0845_sub2_s1025`

Why:

- `F0825_sub2_s1025` becomes the confirm-stage anchor because it has the best
  current mixed `PASS/WARN` evidence without observed `FAIL`
- the remaining probes stay inside the same scale-`1.025` ridge where the best
  historical outcomes were observed

#### Row `269` (`normal / tt1000 / tau0p25`, legacy RHS)

Included:

- `F0825_sub2_s100`
- `F0840_sub2_s100`
- `F085_sub2_s100`
- `F0860_sub2_s100`

Why:

- `F0845_sub2_s100` becomes the confirm-stage anchor because it is the safest
  current `WARN`
- scale-`1.025` is screened out here because it has repeated negative evidence
- the remaining probes stay on the scale-`1.000` line and vary only jump
  frequency inside the still-credible upper-mid neighborhood

### Explicit exclusions

Do **not** rerun:

- `F075_*`
- `F080_*`
- `F090 / F095`
- `s095` broad restarts
- generic `F0875_*` search beyond row `174`
- scale-`1.025` on row `269`
- any full-band or shared-setup rerun

These directions now have enough negative or redundant evidence for the active
row-specific closure problem.

## Decision Rule After Wave-6

For each residual-band row:

1. prefer `PASS`
2. otherwise accept `WARN`
3. break ties by:
   - repeated non-`FAIL` support across prior completed runs
   - distance from the broad default baseline `F085_sub2_s100`
   - fewer distinct local profiles in the final map

If wave-6 confirms the evidence-weighted map and repairs the `3` core closure
rows to `PASS` or `WARN`, the static residual lane should be treated as
comparison-ready and the active campaign debt should collapse to dynamic row
`15`.

## Dynamic Row `15`

Dynamic row `15` remains separate.

Reason:

- no new dynamic repair hypothesis has emerged from the static row-specific
  evidence
- an identical dynamic rerun is still low learning value
- the highest-value overnight compute remains the static row-specific closure
  lane

## Operational Bottom Line

The study is still moving in the right direction.

The next rigorous step is now:

1. keep `F085_sub2_s100` as the broad default baseline
2. promote the evidence-weighted local repair baseline v2
3. confirm that improved map under fresh wave-6 tags
4. spend extra compute only on rows `135`, `190`, and `269`
5. keep dynamic row `15` separate until there is a real repair hypothesis

That is the shortest organized path from the completed wave-5 state to a
comparison-ready static campaign with scenario-specific local tuning.
