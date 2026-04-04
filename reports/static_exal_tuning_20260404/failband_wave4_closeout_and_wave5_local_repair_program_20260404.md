# Validation Campaign: Fail-Band Wave-4 Closeout and Wave-5 Local Repair Program

Date: 2026-04-04

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave3_closeout_and_wave4_targeted_repair_program_20260404.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave4_schedule_20260404.csv`

## Status Note

Wave-5 is now complete.

The active next-step program has moved on to:

- `reports/static_exal_tuning_20260404/failband_wave5_closeout_and_wave6_row_specific_closure_program_20260404.md`

This document remains the decision record for the wave-4 closeout and the
wave-5 local confirmation/probe lane.

This is good news scientifically and operationally.

Why it is good news:

- the targeted repair matrix completed end to end without orchestration issues
- it showed that the `9`-row static residual band does not need a new generic
  shared setup
- it established a defensible default-plus-local repair map that removes all
  static FAILs on the residual band using completed evidence
- it shrank the active static problem from "repair 9 failing rows" to
  "confirm a local repair map and probe only the stubborn WARN-only rows"

The active next-step program is therefore no longer another neighborhood
search. Wave-5 has completed and the next lane is now a row-specific closure
program built from the wave-5 closeout.

## Wave-4 Closeout

### Final wave-4 result

| stage | total | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|---:|
| `repair9` | 81 | 13 | 28 | 40 | 0 |

### What improved

- wave-4 established the first scenario-specific static repair map with
  `0 FAIL` on the old `9`-row residual band when rows are allowed to use local
  overrides instead of one shared tuning profile
- the active static baseline can now be expressed cleanly as:
  - default tuning: `F085_sub2_s100`
  - local row-specific overrides only where needed
- the static planning debt is no longer "repair 9 failing rows"
  but "confirm 3 WARN-only local fixes and preserve provenance"
- the best local repair candidates are now clear enough to stop broad search

### What still fails or remains risky

- dynamic row `15` remains unresolved and separate
- no static row remains unresolved under the provisional local repair map, but
  three rows are still only `WARN` under their best local candidate:
  - current row `87`
  - current row `174`
  - legacy row `269`
- these three WARN-only rows are the highest-value static confirmation/probe
  targets for the next lane

### What worked best

1. keeping `F085_sub2_s100` as the broad default baseline
2. allowing local scenario-specific overrides instead of forcing one generic
   fix profile across the full residual band
3. upper-mid bridge candidates for the paper/shrink normal and laplace rows:
   - `F0835_sub2_s1025`
   - `F0845_sub2_s1025`
4. moderate upper-mid control for the hardest shared gausmix row:
   - `F0845_sub2_s100`
5. preserving row-level evidence from earlier waves instead of discarding it
   just because the broader family was screened out

### What clearly did not help

1. continuing the search for a new generic shared residual-band baseline
2. treating all `9` rows as if they needed the same tuning family
3. `F0835_sub2_s100` and repeated low-value bridge controls that do not beat
   the chosen local repairs
4. broad reruns of previously screened families:
   - `F075_*`
   - `F080_*`
   - `F0875_*` as a generic direction
   - `F090 / F095`
   - `s095` and `s105` broad restarts

## Promoted Static Baseline

The new promoted static repair baseline is:

- default baseline: `F085_sub2_s100`
- local repair map: row-specific overrides on the old `9`-row residual band

This is a clear improvement over the previous broad baseline because it turns
the full `9`-row residual band into:

- `6 PASS`
- `3 WARN`
- `0 FAIL`

### Provisional local repair map v1

| scope | row_id | family | tt | tau | chosen candidate | outcome |
|---|---:|---|---:|---|---|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` | `F085_sub2_s1025` | `WARN` |
| `current_rhsns_refresh` | `115` | `laplace` | `100` | `0p95` | `F0845_sub2_s1025` | `PASS` |
| `current_rhsns_refresh` | `135` | `normal` | `1000` | `0p25` | `F0835_sub2_s1025` | `PASS` |
| `current_rhsns_refresh` | `174` | `gausmix` | `1000` | `0p25` | `F0845_sub2_s100` | `WARN` |
| `current_rhsns_refresh` | `190` | `gausmix` | `1000` | `0p95` | `F085_sub2_s1025` | `PASS` |
| `current_rhsns_refresh` | `206` | `laplace` | `1000` | `0p05` | `F0835_sub2_s1025` | `PASS` |
| `current_rhsns_refresh` | `278` | `normal` | `100` | `0p95` | `F0845_sub2_s1025` | `PASS` |
| `legacy_rhs_refresh` | `181` | `gausmix` | `100` | `0p95` | `F085_sub2_s100` | `PASS` |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` | `F085_sub2_s100` | `WARN` |

### Interpretation

This is the first point in the repair study where the static residual debt can
be expressed as a local repair map rather than an unresolved shared-tuning
problem.

That means the default static baseline should now be promoted as:

- `F085_sub2_s100` by default
- scenario-specific override only where the default still fails

## Active Wave-5 Strategy

### Guiding principle

Wave-5 should not reopen a broad search.

Instead it should:

1. confirm the selected local repair map under a fresh, final-tagged repair
   lane
2. probe only the two hardest WARN-only rows with the one historically useful
   exception candidate that still has row-specific value

### Why the search space is now much smaller

The completed evidence already tells us:

- rows `115`, `135`, `190`, `206`, `278`, and `181` have clear `PASS`
  candidates
- rows `87`, `174`, and `269` have at least one credible `WARN` candidate
- the only remaining static uncertainty is whether the chosen WARN-only fixes
  hold up under confirmation and whether the stubborn `174`/`269` rows benefit
  from one additional row-specific probe

### Wave-5 stage design

| stage | rows | purpose | run count |
|---|---:|---|---:|
| `confirm9` | 9 | confirm the promoted local repair map v1 | 9 |
| `probe2` | 2 | probe the hardest WARN-only rows with the only still-credible row-specific outlier | 2 |
| `overall` | 11 | tightly targeted local confirmation/probe lane | 11 |

### Wave-5 candidate schedule

#### `confirm9`

- rerun the exact `9` local repair map choices above under fresh final tags
- this is the minimum compute needed to turn the provisional repair map into a
  clean merge candidate

#### `probe2`

These probes are included only because they still have targeted historical
value on the two hardest rows:

| scope | row_id | probe candidate | why included |
|---|---:|---|---|
| `current_rhsns_refresh` | `174` | `F0875_sub2_s105` | strongest historical WARN-only outlier for this row |
| `legacy_rhs_refresh` | `269` | `F0875_sub2_s105` | strongest historical WARN-only outlier for this row |

### Explicit exclusions

Do **not** rerun:

- any full-band or broad shared-setup wave
- `F075_*`
- `F080_*`
- `F090 / F095`
- generic `F0875_*` search beyond the two targeted probes above
- `s095` variants
- lambda-tempering, no-jump, and `substeps = 3`

These directions are now either dominated or irrelevant to the remaining
scenario-specific problem.

## Decision Rule After Wave-5

For each of the `9` static repair rows:

1. prefer `PASS`
2. otherwise accept `WARN`
3. break ties by:
   - keeping the default baseline if it already achieves `PASS` or `WARN`
   - lower jump distance from the default baseline
   - lower scale distance from the default baseline
   - fewer distinct override profiles across the final repair map

If wave-5 confirms the provisional map without introducing new FAILs, the
static repair lane should be treated as comparison-ready and the remaining open
problem should collapse to dynamic row `15`.

## Dynamic Row `15`

Dynamic row `15` remains separate.

Reason:

- no new dynamic repair hypothesis has emerged from the static local-tuning
  evidence
- an identical rerun is still low learning value
- the highest-value overnight compute right now is static repair-map
  confirmation

## Operational Bottom Line

The study is still moving in the right direction.

The next rigorous step is now:

1. promote `F085_sub2_s100` plus the local repair map as the active static
   baseline
2. confirm that map on the `9` repaired rows
3. probe only rows `174` and `269` with the one remaining row-specific outlier
4. keep dynamic row `15` separate until there is a genuine repair hypothesis

That is the shortest organized path from the completed wave-4 state to a
comparison-ready static campaign with scenario-specific local tuning.
