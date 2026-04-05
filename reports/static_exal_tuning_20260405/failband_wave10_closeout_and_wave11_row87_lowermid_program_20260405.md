# Validation Campaign: Wave-10 Closeout and Wave-11 Row-87 Lower-Mid Closure Program

Date: 2026-04-05

Primary references:

- `reports/static_exal_tuning_20260405/failband_wave9_closeout_and_wave10_row87_microband_program_20260405.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave10_schedule_20260405.csv`
- `tools/merge_reports/LOCAL_dynamic_row15_wave8_matrix_20260405.csv`

## Status Note

Wave-10 completed cleanly. Nothing is currently running.

The campaign is now in a one-row endgame:

- static row `135` is closed to `PASS`
- static row `174` is closed to `WARN`
- static row `269` is closed to `WARN`
- dynamic row `15` is closed to `WARN`
- the only remaining blocking case is:
  - static row `87`

## Correction After The Wave-10 Artifact Audit

Wave-10 was scientifically useful, but the row-`87` narrative in the earlier
report was too narrow.

Corrected finding:

- the later `F085` / `F0855` scale-`1.025` micro-band is now exhausted
- however, row `87` also has historical non-`FAIL` anchors in the lower-mid
  short-run `laplace_rw` corridor:
  - `F0825_sub2_s100`
  - `F0825_sub2_s1025`
  - `F0835_sub2_s1025`
  - `F085_sub2_s1025`

So the right interpretation is:

- wave-10 exhausted the late micro-band
- it did **not** exhaust all credible row-`87` space

## Wave-10 Closeout

### Final wave-10 result

| stage | total | PASS | WARN | FAIL | missing | resolved |
|---|---:|---:|---:|---:|---:|---:|
| `anchor4_confirm` | 4 | 0 | 0 | 4 | 0 | 0 |
| `micro4_expand` | 4 | 0 | 0 | 4 | 0 | 0 |
| `overall` | 8 | 0 | 0 | 8 | 0 | 0 |

### What improved

1. wave-10 completed cleanly and produced valid negative evidence
2. dynamic row `15` remains resolved to `WARN / healthy = TRUE`
3. the final campaign tail is now clearly localized to row `87` only
4. the row-`87` artifact audit corrected the search-space map and recovered a
   broader credible lower-mid corridor for the final closure attempt

### What still fails

| scope | row_id | family | tt | tau | current best read |
|---|---:|---|---:|---|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` | `FAIL` |

### Which ideas worked best

1. keeping `F085_sub2_s100` as the broad static default while promoting only
   local row-level improvements
2. exact historical rescue replay for the solved tail rows:
   - `135`
   - `174`
   - `269`
   - dynamic `15`
3. using wave-10 as an exhaustion test of the later row-`87` micro-band
   instead of reopening a broad family search
4. revisiting the historical artifacts directly when the current narrative and
   the observed evidence diverged

### Which ideas did not help

1. further search inside the late `F085` / `F0855` scale-`1.025` row-`87`
   micro-band
2. treating row `87` as if it only had two surviving families
3. reopening already-screened weak families outside the last credible
   lower-mid corridor
4. broad shared-setup search after the campaign had already reduced to one
   row-local blocker

## Promoted Static Baseline v8

The active campaign baseline should now be:

- broad default:
  - `F085_sub2_s100`
- promoted row-local map:

| scope | row_id | preferred candidate | role | current best read |
|---|---:|---|---|---|
| `current_rhsns_refresh` | `87` | open lower-mid replay / confirmation corridor | remaining blocker | `FAIL` |
| `current_rhsns_refresh` | `115` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `current_rhsns_refresh` | `135` | `F0825_sub2_s105_none` | promoted `PASS` | `PASS` |
| `current_rhsns_refresh` | `174` | `F085_sub2_s105_histshort` | promoted `WARN` | `WARN` |
| `current_rhsns_refresh` | `190` | `F0825_sub2_s100_rwlong` | stable `WARN` | `WARN` |
| `current_rhsns_refresh` | `206` | `F0825_sub2_s1025_rwlong` | promoted `PASS` | `PASS` |
| `current_rhsns_refresh` | `278` | `F0845_sub2_s1025` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `181` | `F0825_sub2_s100` | stable `PASS` | `PASS` |
| `legacy_rhs_refresh` | `269` | `F0845_sub2_s100_histshort` | promoted `WARN` | `WARN` |

Dynamic local baseline:

| workstream | row | preferred candidate | current best read |
|---|---:|---|---|
| `dynamic_tail_cppgig_refresh_20260331` | `15` | `row15_slice_exact_20260405` | `WARN` |

## Highest-Value Directions Now

1. spend new compute only on row `87`
2. stay inside the surviving lower-mid non-`FAIL` corridor:
   - `F0825_sub2_s100`
   - `F0825_sub2_s1025`
   - `F0835_sub2_s1025`
   - `F085_sub2_s1025`
3. replay the exact short historical anchors first
4. allow moderate-length confirmations only on the same corridor
5. allow a tiny `init_mode = none` lane on the lower-mid anchors only
6. explicitly exclude:
   - more broad family search
   - more late `F085` / `F0855` micro-band widening
   - more already-screened outer-frontier families
   - any rerun of already-closed rows

## Wave-11 Strategy

### Guiding principle

Wave-11 is the final broad-but-disciplined row-`87` closure wave.

It is broad only inside the last credible row-`87` lower-mid corridor and does
not touch any resolved row.

### Stage design

| stage | purpose | runs |
|---|---|---:|
| `anchor4_short_hist` | exact short replays of the surviving historical non-`FAIL` anchors | 4 |
| `confirm4_medium` | moderate-length confirmations on the same corridor | 4 |
| `none3_lowermid` | no-warm-start pivots on the best lower-mid anchors | 3 |
| `overall` | total | 11 |

### Included candidates

| candidate | why included |
|---|---|
| `F0825_sub2_s100` short replay | strongest overlooked lower-mid historical `WARN` anchor |
| `F0825_sub2_s1025` short replay | strongest scale-`1.025` lower-mid historical `WARN` anchor |
| `F0835_sub2_s1025` short replay | midpoint historical `WARN` anchor not exhausted by wave-10 |
| `F085_sub2_s1025` short replay | best upper-edge short historical control still worth keeping in scope |
| `F0825_sub2_s100` medium confirmation | tests whether the short lower-mid rescue holds with more kept draws |
| `F0825_sub2_s1025` medium confirmation | same for the strongest lower-mid scale-`1.025` anchor |
| `F0835_sub2_s1025` medium confirmation | same for the midpoint anchor |
| `F085_sub2_s1025` medium confirmation | upper-edge control against the lower-mid lane |
| `F0825_sub2_s100` none-init | tests whether row `87` is still being hurt by `baseline_last` warm-start dependence |
| `F0825_sub2_s1025` none-init | same on the best scale-`1.025` lower-mid anchor |
| `F0835_sub2_s1025` none-init | same on the midpoint anchor |

### Explicit exclusions

Wave-11 intentionally excludes:

- all resolved rows
- all `F075` / `F080` / outer-frontier families
- more late `F08525+` micro-band widening
- more row-`87` `slice_eta` broadening after the wave-10 exhaustion result
- any dynamic reruns; dynamic row `15` is already closed to non-`FAIL`

## Operational validation before launch

Wave-11 is launchable only if all of the following pass:

1. `prepare` regenerates the row-`87` schedule and TSV cleanly
2. `evaluate` sees the schedule correctly before launch
3. launcher, supervisor, and monitor all pass `bash -n`
4. the branch is committed and pushed cleanly before the overnight launch

## Bottom line

The campaign is now extremely close to closure.

Current endgame:

- static closed to non-`FAIL`: `135`, `174`, `269`
- dynamic closed to non-`FAIL`: `15`
- only blocker left: `87`

Wave-11 is therefore the right next move:
a disciplined row-`87` lower-mid replay / confirmation wave that is broad only
inside the last credible non-`FAIL` corridor.
