# Validation Campaign: Fail-Band Wave-2 Closeout and Wave-3 Residual Program

Date: 2026-04-04

Primary references:

- `reports/static_exal_tuning_20260404/failband_wave1_closeout_and_wave2_broad_program_20260404.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_failband_wave2_schedule_20260404.csv`
- `tools/merge_reports/LOCAL_static_exal_failband_wave2_manifest_20260404_023811_13255_3919934.csv`
- `tools/merge_reports/LOCAL_static_exal_failband_wave2_manifest_20260404_031149_17720_3924339.csv`
- `tools/merge_reports/LOCAL_static_exal_failband_wave2_manifest_20260404_032347_24675_3926031.csv`

## Status Note

Wave-2 is no longer running.

This is good news operationally because the stopped state is decision-clean:
there are no live tmux sessions, no active runner processes, and the launched
wave-2 evidence is already strong enough to move forward without blindly
resuming the old staged run.

The right next step is therefore not "restart wave-2 exactly as-is."

The right next step is:

1. treat the launched wave-2 evidence as the new residual-band planning
   baseline
2. keep only the scientifically alive candidate neighborhood
3. rerun only the still-informative residual rows first
4. then confirm finalists back on the full `30`-row fail band

## Wave-2 Closeout

### Actual launched stage summary

| stage | total | done | missing | PASS | WARN | FAIL |
|---|---:|---:|---:|---:|---:|---:|
| `sentinel12` | 120 | 119 | 1 | 10 | 42 | 67 |
| `expand20` | 100 | 100 | 0 | 13 | 47 | 40 |
| `full30` | 60 | 59 | 1 | 13 | 27 | 19 |

The two bookkeeping misses were:

- `sentinel12 / F080_sub2_s0975 / legacy row 269`
- `full30 / F0825_sub2_s100 / current row 103`

Only the second one remains decision-relevant. The first sits on a screened-out
candidate and does not justify resuming the whole wave-2 program.

### Candidate closeout from the actual launched stages

#### `sentinel12`

| candidate_id | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|
| `F0825_sub2_s100` | 2 | 7 | 3 | 0 |
| `F085_sub2_s100` | 2 | 5 | 5 | 0 |
| `F085_sub2_s1025` | 1 | 5 | 6 | 0 |
| `F0875_sub2_s1025` | 1 | 5 | 6 | 0 |
| `F0825_sub2_s1025` | 1 | 4 | 7 | 0 |
| `F0875_sub2_s100` | 1 | 4 | 7 | 0 |
| `F085_sub2_s105` | 1 | 3 | 8 | 0 |
| `F0875_sub2_s105` | 0 | 4 | 8 | 0 |
| `F080_sub2_s0975` | 0 | 3 | 8 | 1 |
| `F0825_sub2_s105` | 1 | 2 | 9 | 0 |

#### `expand20`

| candidate_id | PASS | WARN | FAIL |
|---|---:|---:|---:|
| `F085_sub2_s100` | 2 | 12 | 6 |
| `F0825_sub2_s100` | 4 | 9 | 7 |
| `F0825_sub2_s1025` | 2 | 10 | 8 |
| `F0875_sub2_s1025` | 2 | 9 | 9 |
| `F085_sub2_s1025` | 3 | 7 | 10 |

#### `full30`

| candidate_id | PASS | WARN | FAIL | missing |
|---|---:|---:|---:|---:|
| `F085_sub2_s100` | 6 | 15 | 9 | 0 |
| `F0825_sub2_s100` | 7 | 12 | 10 | 1 |

### What improved

- wave-2 improved the best completed residual-band candidate from the
  wave-1 co-lead level (`12 FAIL`) to a new best completed broad finalist:
  `F085_sub2_s100` with `9 FAIL`
- `F0825_sub2_s100` remained scientifically valuable as a complement because
  it resolves a different subset of rows than `F085_sub2_s100`
- the broad wave-2 search eliminated the need to keep exploring:
  - `F080_sub2_s0975`
  - `F0825_sub2_s105`
  - `F085_sub2_s105`
  - `F0875_sub2_*`
- the useful search space collapsed from the old `F080` to `F0875` band to a
  much tighter upper-central neighborhood:
  - jump in `[0.0825, 0.0850]`
  - scale in `[1.000, 1.025]`

### What still fails

- no wave-2 candidate reached `0 FAIL`
- the union of rows still `FAIL` or `MISSING` under the two full30 finalists is
  `18` rows
- two rows remain stubborn under both finalists:
  - current RHS-NS row `87` (`gausmix / tt1000 / tau0p25`)
  - current RHS-NS row `174` (`gausmix / tt1000 / tau0p25`)
- dynamic row `15` remains unresolved and separate

### What worked best

1. `F085_sub2_s100` as the new best completed broad residual-band baseline
2. `F0825_sub2_s100` as the strongest complementary control
3. moderate widening only up to `1.025` as a hedge, not as the main answer
4. broad search inside the live neighborhood, then finalist comparison on the
   full `30`-row band

### What clearly did not work

1. resuming or trusting `F080_sub2_s0975` as the main repair direction
2. wider `s105` variants in the upper-central band
3. the cautious `F0875` extension below the rejected frontier
4. broad reruns outside the residual fail band

## Interpretation

Wave-2 did not get stuck scientifically. It finished enough of the real work to
sharpen the next move.

The new decision-quality read is:

- `F085_sub2_s100` is the best completed broad residual-band baseline
- `F0825_sub2_s100` is the best complementary control
- the remaining uncertainty sits in the conflict between those two anchors plus
  the still-unresolved shared hard rows

That means the next useful search is not another large staged neighborhood.
It is a residual-only bridge search between those two anchors.

## Active Wave-3 Strategy

### Guiding principle

Wave-3 should spend almost all compute on rows that still need repair while
still giving us enough breadth to discover a genuinely better shared setup.

That means:

- do **not** resume the old wave-2 staged program
- do **not** rerun the entire `30`-row band for every candidate
- do run a broad bridge search on only the `18` still-informative rows
- then confirm only the best finalists on the full `30`-row band

### Wave-3 row scope

| stage | row scope | rows | why included |
|---|---:|---:|---|
| `residual18` | union of `FAIL` or `MISSING` under `F085_sub2_s100` or `F0825_sub2_s100` | 18 | all still-informative rows, including current row `103` |
| `confirm30` | original full residual fail band | 30 | finalist regression check before promotion |

### Wave-3 candidate set

| candidate_id | jump | scale | why included |
|---|---:|---:|---|
| `F0825_sub2_s100` | 0.0825 | 1.000 | strongest complement anchor; resolves some rows the leader still misses |
| `F0825_sub2_s1025` | 0.0825 | 1.025 | lower-jump widened hedge; partial resolver on residual rows |
| `F0835_sub2_s100` | 0.0835 | 1.000 | new lower-mid bridge between the two finalists |
| `F0835_sub2_s1025` | 0.0835 | 1.025 | same bridge with mild widening |
| `F0845_sub2_s100` | 0.0845 | 1.000 | new upper-mid bridge toward the best finalist |
| `F0845_sub2_s1025` | 0.0845 | 1.025 | same bridge with mild widening |
| `F085_sub2_s100` | 0.0850 | 1.000 | best completed broad residual-band baseline |
| `F085_sub2_s1025` | 0.0850 | 1.025 | upper-edge widened hedge retained as the last credible wider variant |

### Explicit exclusions

Do **not** rerun:

- `F080_sub2_s0975`
- `F0825_sub2_s105`
- `F085_sub2_s105`
- any `F0875_sub2_*`
- `F075_*`
- `F080_sub2_s100_ref`
- `F085_sub2_s095`
- `C060`, `F090 / F095`, lambda-tempering, no-jump, `substeps = 3`

## Execution Design

### Why residual-first instead of resuming wave-2

Wave-2 already proved enough of the neighborhood to make the next search much
smaller.

The next efficient use of compute is:

1. search broadly only on the `18` rows that are still unresolved under the
   two finalists
2. rank candidates there
3. rerun the top `2` candidates on the full `30` rows to check for regression

### Candidate advancement rule

- rank `residual18` candidates by:
  1. lowest `missing`
  2. lowest `FAIL`
  3. lowest `WARN`
  4. highest `PASS`
  5. stable candidate id tie-break
- advance top `2` candidates to `confirm30`

## Planned Compute Footprint

| stage | launched candidate count | rows per candidate | actual run count |
|---|---:|---:|---:|
| `residual18` | 8 | 18 | 144 |
| `confirm30` | 2 | 30 | 60 |
| overall | staged | mixed | 204 |

This is broader than a two-candidate cleanup run, but still much tighter than
repeating the old `30 x 10` or `30 x 6` screens.

## Dynamic Row `15`

Dynamic row `15` stays out of this overnight static program.

Reason:

- there is still no new row-`15` repair hypothesis generated by the static
  fail-band work
- relaunching it identically would spend compute without increasing learning
  value

## Operational Bottom Line

The next rigorous step is now clear:

1. keep `F085_sub2_s100` as the active residual-band planning baseline
2. keep `F0825_sub2_s100` as the primary complement
3. run a new wave-3 bridge search only on the `18` still-informative rows
4. confirm finalists on the full `30` rows before promoting any new baseline

That is the shortest organized path from the paused wave-2 state to a cleaner,
more defensible shared setup for the remaining static campaign debt.
