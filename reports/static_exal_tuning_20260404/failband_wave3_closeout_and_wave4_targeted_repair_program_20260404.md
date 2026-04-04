# Validation Campaign: Fail-Band Wave-3 Closeout and Wave-4 Targeted Repair Program

Date: 2026-04-04

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave2_closeout_and_wave3_residual_program_20260404.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave3_schedule_20260404.csv`

## Status Note

Wave-3 is complete.

This is still good news scientifically, even though it did not produce a new
better broad baseline.

Why it is still good news:

- it completed cleanly and end to end
- it gave a decision-quality answer about the remaining shared-setup search
- it showed that the broad upper-central bridge search is close to exhausted
- it reduced the active remaining static repair scope from the full
  `30`-row residual band to the `9` rows that still fail under the best
  completed broad baseline

The active next-step program is therefore no longer another broad shared-setup
wave. It is a targeted repair matrix on only the rows that still need fixing.

## Wave-3 Closeout

### Final wave-3 result

| stage | total | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|---:|
| `residual18` | 144 | 28 | 44 | 72 | 0 |
| `confirm30` | 60 | 7 | 28 | 25 | 0 |
| `overall` | 204 | 35 | 72 | 97 | 0 |

### What improved

- wave-3 confirmed that the best completed broad static repair baseline is
  still `F085_sub2_s100`
- wave-3 showed that `F0825_sub2_s100` and `F0835_sub2_s1025` are the most
  credible complementary bridge candidates on the residual-only screen
- the active static repair problem now collapses cleanly to the `9` rows that
  still fail under `F085_sub2_s100` on the full `30`-row band
- this reduces the active unresolved planning debt from `31` cases to `10`
  cases:
  - `9` static rows
  - `1` dynamic sidecar row (`15`)

### What still fails

Static rows still failing under the best completed broad baseline
`F085_sub2_s100`:

| scope | row_id | family | tt | tau |
|---|---:|---|---:|---|
| `current_rhsns_refresh` | `87` | `gausmix` | `1000` | `0p25` |
| `current_rhsns_refresh` | `115` | `laplace` | `100` | `0p95` |
| `current_rhsns_refresh` | `135` | `normal` | `1000` | `0p25` |
| `current_rhsns_refresh` | `174` | `gausmix` | `1000` | `0p25` |
| `current_rhsns_refresh` | `190` | `gausmix` | `1000` | `0p95` |
| `current_rhsns_refresh` | `206` | `laplace` | `1000` | `0p05` |
| `current_rhsns_refresh` | `278` | `normal` | `100` | `0p95` |
| `legacy_rhs_refresh` | `181` | `gausmix` | `100` | `0p95` |
| `legacy_rhs_refresh` | `269` | `normal` | `1000` | `0p25` |

Dynamic row `15` remains unresolved and stays outside this static overnight
program.

### What worked best

1. `F085_sub2_s100` as the best completed broad residual-band baseline
2. `F0825_sub2_s100` as the strongest complementary row-repair control
3. `F0835_sub2_s1025` as the most credible mid-bridge hedge
4. row-specific evidence that some failures now have clear historical rescue
   candidates:
   - row `135`: `F0825_sub2_s105`
   - row `190`: `F0825_sub2_s1025`
   - row `206`: `F0825_sub2_s100` or `F085_sub2_s1025`
   - row `278`: several upper-mid or upper-edge candidates

### What clearly did not work

1. another one-size-fits-all bridge profile replacing `F085_sub2_s100`
2. the broader `F0875` extension as an active repair direction
3. re-running the older `F080` or low-jump directions as if the broad search
   were still open
4. treating the full `30`-row band as if every row still needed the same kind
   of repair

## Interpretation

Wave-3 is the point where the search changes shape.

Before wave-3, the main open question was:

- can a slightly different shared setup beat the best broad baseline?

After wave-3, the cleaner question is:

- which targeted candidate profiles repair the `9` rows that still fail under
  the best broad baseline?

That means the highest-value direction is now cluster-aware targeted repair,
not another broad shared-setup wave.

## Active Wave-4 Strategy

### Guiding principle

Wave-4 should spend compute only on the rows that still need repair, but it
should still explore the real remaining alternatives inside the only credible
candidate neighborhood.

That means:

- keep `F085_sub2_s100` as the active broad default baseline
- isolate only its `9` remaining FAIL rows
- search broadly only within the surviving bridge band:
  - jump in `[0.0825, 0.0850]`
  - scale in `[1.000, 1.025]`
  - plus one special-case probe:
    - `F0825_sub2_s105` because it is the only observed `PASS` on row `135`

### Wave-4 row scope

| scope slice | rows |
|---|---:|
| current RHS-NS fail rows under `F085_sub2_s100` | 7 |
| legacy RHS fail rows under `F085_sub2_s100` | 2 |
| total static repair rows | 9 |

### Wave-4 candidate set

| candidate_id | jump | scale | why included |
|---|---:|---:|---|
| `F0825_sub2_s100` | 0.0825 | 1.000 | strongest complementary control; only surviving shared repair anchor for rows `87`, `174`, `269` |
| `F0825_sub2_s1025` | 0.0825 | 1.025 | strongest lower-mid widened hedge; best evidence on row `190` |
| `F0825_sub2_s105` | 0.0825 | 1.050 | special-case probe; only observed `PASS` on row `135` |
| `F0835_sub2_s100` | 0.0835 | 1.000 | lower-mid bridge control |
| `F0835_sub2_s1025` | 0.0835 | 1.025 | best mid-bridge hedge from wave-3 residual screen |
| `F0845_sub2_s100` | 0.0845 | 1.000 | upper-mid bridge; useful on row `278` |
| `F0845_sub2_s1025` | 0.0845 | 1.025 | upper-mid widened bridge; useful on rows `115`, `190`, `278` |
| `F085_sub2_s100` | 0.0850 | 1.000 | active broad baseline control |
| `F085_sub2_s1025` | 0.0850 | 1.025 | retained upper-edge widened hedge; useful on row `206` |

### Explicit exclusions

Do **not** rerun:

- `F080_*`
- `F075_*`
- `F0875_*`
- `F085_sub2_s095`
- `F085_sub2_s105`
- `F090 / F095`
- lambda-tempering, no-jump, and `substeps = 3`

These now have enough negative evidence relative to the active residual problem.

## Execution Design

### Why a targeted matrix instead of another staged broad wave

Wave-2 and wave-3 already answered the broad shared-setup question well enough.

The next efficient use of compute is:

1. test the remaining credible candidates only on the `9` rows that still fail
   under the best broad baseline
2. compare row-level rescue behavior directly
3. use that result to define the smallest defensible repair map for the
   remaining static debt

### Wave-4 stage

| stage | rows | candidates | run count |
|---|---:|---:|---:|
| `repair9` | 9 | 9 | 81 |

This is broad inside the active failure set, but it avoids spending compute on
the `21` rows already resolved by the best broad baseline.

### Decision rule after wave-4

For each of the `9` active fail rows:

1. prefer `PASS`
2. otherwise prefer `WARN`
3. break ties by:
   - lower jump distance from the broad baseline
   - lower scale distance from the broad baseline
   - simpler shared reuse across multiple rows

If wave-4 still leaves only a tiny stubborn residue, the next step should be a
very small confirmatory repair lane, not another broad search.

## Dynamic Row `15`

Dynamic row `15` remains separate.

Reason:

- the static evidence still does not generate a new dynamic repair hypothesis
- the current priority is to remove the last static FAILs as efficiently as
  possible

## Operational Bottom Line

The study is still moving in the right direction.

The next rigorous step is now:

1. freeze `F085_sub2_s100` as the best completed broad repair baseline
2. repair only its `9` remaining static FAIL rows
3. keep dynamic row `15` separate
4. use the smallest defensible repair map to reach a comparison-ready merged
   campaign
