# Validation Campaign: Fail-Band Wave-6 Closeout and Wave-7 Triplet Closure Program

Date: 2026-04-04

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave5_closeout_and_wave6_row_specific_closure_program_20260404.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave6_schedule_20260404.csv`

## Status Note

Wave-6 is complete.

This is still good news even though wave-6 did not finish the static repair
problem outright.

Why it is still good news:

- the row-specific closure lane completed cleanly end to end
- it converted rows `135` and `190` from active static `FAIL` targets into
  fresh `WARN` outcomes
- it held the already-strong rows `115`, `181`, and `278` at `PASS`
- it reduced the true static blocking core to only `3` rows:
  - current row `87`
  - current row `174`
  - legacy row `269`

The active question is therefore no longer:

- "which broad residual family should replace the baseline?"

It is now:

- keep `F085_sub2_s100` as the broad default
- keep only the row-local overrides that are still supported by repeated or
  freshly improved evidence
- spend new compute only on the remaining static hard core plus the small set
  of non-`FAIL` rows that still need stability/provenance confirmation

Dynamic row `15` remains a separate sidecar debt and is not part of the active
static wave-7 closure lane.

## Wave-6 Closeout

### Final wave-6 result

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `confirm9_v2` | 9 | 3 | 2 | 4 | 0 | 5 |
| `repair13` | 13 | 0 | 5 | 8 | 0 | 5 |
| `overall` | 22 | 3 | 7 | 12 | 0 | 10 |

### What improved

- rows `135` and `190` are no longer part of the blocking static `FAIL` core
- row `135` now has a fresh improved `WARN` outcome under:
  - `F0840_sub2_s1025`
- row `190` remains non-`FAIL` and now has a reinforced row-local ridge across:
  - `F0825_sub2_s100`
  - `F0825_sub2_s1025`
  - `F0835_sub2_s1025`
  - `F0845_sub2_s1025`
- row `206` stayed non-`FAIL`
- the active static closure problem is now smaller and cleaner:
  - `3` blocking static `FAIL` rows
  - `3` non-`FAIL` but still unstable/provenance rows

### What still fails

The remaining static blocking rows after wave-6 are:

| scope | row_id | family | tt | tau | best current anchor |
|---|---:|---|---:|---|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` | `F085_sub2_s1025` (best repeated WARN anchor, but still unresolved) |
| `current_rhsns_refresh` | `174` | `gausmix` | `1000` | `0p25` | `F0875_sub2_s105` (row-specific exception, still unresolved) |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` | `F0845_sub2_s100` (best current fallback anchor, still unresolved) |

Rows that are now non-`FAIL` but still matter for stability/provenance:

| scope | row_id | current best read | current preferred candidate |
|---|---:|---|---|
| `current_rhsns_refresh` | `135` | improved `WARN` | `F0840_sub2_s1025` |
| `current_rhsns_refresh` | `190` | durable `WARN` ridge | `F0825_sub2_s100` |
| `current_rhsns_refresh` | `206` | reusable `WARN` anchor | `F0825_sub2_s1025` |

Stable non-problematic resolved rows:

| scope | row_id | current best read | current preferred candidate |
|---|---:|---|---|
| `current_rhsns_refresh` | `115` | `PASS` | `F0825_sub2_s100` |
| `current_rhsns_refresh` | `278` | `PASS` | `F0845_sub2_s1025` |
| `legacy_rhs_refresh` | `181` | `PASS` | `F0825_sub2_s100` |

Dynamic row `15` remains unresolved and separate.

## What Worked Best

1. keeping `F085_sub2_s100` as the broad default instead of trying to replace
   it globally again
2. promoting only row-level overrides with repeated or freshly improved
   non-`FAIL` evidence
3. the row-`135` midpoint repair:
   - `F0840_sub2_s1025`
4. the lower-mid control on `tt100`/legacy edge rows:
   - `F0825_sub2_s100`
5. the row-`174` exception staying isolated to:
   - `F0875_sub2_s105`
6. narrowing the search to exact unresolved rows instead of relaunching
   broader shared-setup sweeps

## What Clearly Did Not Help

1. rerunning more generic shared-setup search after wave-4 and wave-5 had
   already shown the problem was local
2. preserving the wave-5 provisional map unchanged
3. continuing to use scale-`1.000` control reruns on row `269` as if they were
   still promising enough by themselves
4. broad `F080_*`, `F075_*`, and outer-frontier families in the residual band
5. treating row `174` as anything other than a row-specific outlier

## Promoted Static Baseline v3

The active static baseline should now be treated as:

- broad default:
  - `F085_sub2_s100`
- promoted local repair baseline v3:
  only on rows that now have cleaner evidence than the old v2 map

### Active local repair baseline v3

| scope | row_id | family | tt | tau | preferred candidate | current role | current best read |
|---|---:|---|---:|---|---|---|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` | `F085_sub2_s1025` | unresolved anchor only | `FAIL` |
| `current_rhsns_refresh` | `115` | `laplace` | `100` | `0p95` | `F0825_sub2_s100` | stable local PASS | `PASS` |
| `current_rhsns_refresh` | `135` | `normal` | `1000` | `0p25` | `F0840_sub2_s1025` | promoted improved WARN override | `WARN` |
| `current_rhsns_refresh` | `174` | `gausmix` | `1000` | `0p25` | `F0875_sub2_s105` | unresolved row-specific anchor | `FAIL` |
| `current_rhsns_refresh` | `190` | `gausmix` | `1000` | `0p95` | `F0825_sub2_s100` | promoted stability anchor | `WARN`-heavy history |
| `current_rhsns_refresh` | `206` | `laplace` | `1000` | `0p05` | `F0825_sub2_s1025` | reusable WARN anchor | `WARN` |
| `current_rhsns_refresh` | `278` | `normal` | `100` | `0p95` | `F0845_sub2_s1025` | stable local PASS | `PASS` |
| `legacy_rhs_refresh` | `181` | `gausmix` | `100` | `0p95` | `F0825_sub2_s100` | stable local PASS | `PASS` |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` | `F0845_sub2_s100` | unresolved anchor only | `FAIL` |

Interpretation:

- stable resolved `PASS` rows:
  - `115`, `181`, `278`
- promoted or retained non-`FAIL` stability rows:
  - `135`, `190`, `206`
- unresolved blocking rows:
  - `87`, `174`, `269`

This is an improvement over the wave-6 starting map because row `135` now has
an actually improved promoted candidate, and the active repair problem is no
longer diffuse.

## Highest-Value Directions Now

1. keep `F085_sub2_s100` as the broad static default
2. treat the residual static problem as a three-row closure task:
   - `87`
   - `174`
   - `269`
3. keep the `135/190/206` lane small and focused on confirmation or stability
   only
4. for rows `87` and `174`, stay inside the surviving `gausmix / tt1000 /
   tau0p25` neighborhoods that still show any non-`FAIL` evidence
5. for row `269`, allow a slightly broader row-local search because the
   repeated scale-`1.000` reruns keep regressing
6. introduce only one new execution-control axis where it is justified:
   - longer run length
   - a limited `slice_eta` proposal pilot on the remaining hard rows

## Wave-7 Strategy

### Guiding principle

Wave-7 should not reopen another general family search.

It should do three things only:

1. confirm the promoted `v3` non-`FAIL` choices on `135`, `190`, and `206`
2. probe only the remaining blocking triplet `87`, `174`, and `269`
3. mix geometry micro-neighborhoods with a very small execution-control lane
   only where the plain short `laplace_rw` setup has now repeatedly failed

### Why this is the right search shape

- row `87` still lives only in the narrow `F085_sub2_s1025` corridor plus the
  lower-jump fallback `F0825_sub2_s100`
- row `174` still behaves like a single-row outlier centered on
  `F0875_sub2_s105`
- row `269` is the only remaining case where the promising region is still
  ambiguous enough to justify trying both lower-mid and upper-mid anchors
- the repeated failures on all three rows are now mixing/drift failures, not
  broad family collapse failures, so a small longer-run / `slice_eta` pilot is
  justified

### Wave-7 stage design

| stage | rows | purpose | run count |
|---|---:|---|---:|
| `stability3_v3` | 3 | confirm the promoted non-`FAIL` map on rows `135`, `190`, `206` under longer fresh tags | 3 |
| `core17_triplet` | 3 | probe only rows `87`, `174`, `269` with row-local geometry and proposal variants | 17 |
| `overall` | 20 | targeted static triplet-closure program | 20 |

### Wave-7 row-local search space

#### Row `87` (`gausmix / tt1000 / tau0p25 / current`)

Included:

- `F085_sub2_s1025` long-run control
- `F0855_sub2_s1025`
- `F0860_sub2_s1025`
- `F085_sub2_s1025` with `slice_eta`
- `F0825_sub2_s100` long-run fallback

Why:

- this stays inside the only corridor that has produced repeated non-`FAIL`
  evidence for row `87`
- it avoids the now-dominated lower band and the already weak outer `F0875`
  expansion on this row
- it adds only one new proposal-style pilot on the best geometry anchor

Excluded:

- `F075_*`
- `F080_*`
- any scale-`1.050` broad restarts for row `87`
- `F0875_*` broad restarts on row `87`

#### Row `174` (`gausmix / tt1000 / tau0p25 / current`)

Included:

- `F0875_sub2_s105` long-run control
- `F0865_sub2_s105`
- `F0880_sub2_s105`
- `F0885_sub2_s105`
- `F0875_sub2_s105` with `slice_eta`

Why:

- row `174` still behaves like the single `F0875_sub2_s105` exception case
- the search therefore stays tightly centered on that exception instead of
  widening back toward the broad residual band
- a small upper micro-band is still warranted because `174` remains the
  hardest current static row

Excluded:

- broad `F085_*` restarts
- scale-`1.025` restarts that have already been screened out here
- any generic family sweep outside the `F0875_s105` exception corridor

#### Row `269` (`normal / tt1000 / tau0p25 / legacy`)

Included:

- `F0845_sub2_s100` long-run control
- `F0825_sub2_s100` long-run repeated-WARN fallback
- `F0825_sub2_s1025` long-run scale bridge
- `F0875_sub2_s105` long-run upper-scale anchor
- `F0845_sub2_s100` with `slice_eta`
- `F0825_sub2_s100` with `slice_eta`
- `F0875_sub2_s105` with `slice_eta`

Why:

- row `269` is the only remaining legacy row still at `FAIL`
- the geometry evidence is still split across lower-mid scale-`1.000`,
  one scale-`1.025` bridge, and one upper-scale historical WARN
- the repeated fresh failures on the scale-`1.000` controls justify one narrow
  proposal-style pilot here

Excluded:

- more broad scale-`1.000` sweeps above `F0860`
- broad `F0835_*` restarts
- previously screened low-value outer families

## Acceptance Rule for Wave-7

Wave-7 is successful if it improves the current static blocking state to:

- `0` static `FAIL` rows on `87`, `174`, and `269`
- while preserving rows `135`, `190`, and `206` at least at `WARN`

`WARN` remains acceptable for the final campaign.

## Operational Bottom Line

The study is in a materially better place now.

The open static problem is no longer a band, a family, or a wave-scale search.
It is now a three-row closure task with a small supporting stability lane.

That means the shortest rigorous next step is:

1. confirm the `v3` non-`FAIL` rows `135`, `190`, and `206`
2. close rows `87`, `174`, and `269`
3. keep dynamic row `15` separate until it has its own repair hypothesis

That is the most compute-efficient path from the current branch state to a
campaign with only a very small final unresolved core.
