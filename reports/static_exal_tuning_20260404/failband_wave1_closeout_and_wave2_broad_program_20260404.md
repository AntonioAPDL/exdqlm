# Validation Campaign: Fail-Band Wave-1 Closeout and Wave-2 Broad Staged Program

Date: 2026-04-04

Primary references:

- `reports/static_exal_tuning_20260403/failband_wave1_overnight_program_20260403.md`
- `reports/static_exal_tuning_20260403/static_refresh_closeout_and_failband_program_20260403.md`
- `reports/static_exal_tuning_20260403/post_wave8_campaign_readiness_plan_20260403.md`
- `tools/merge_reports/LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv`
- `tools/merge_reports/LOCAL_static_exal_failband_wave1_schedule_20260403.csv`
- `tools/merge_reports/LOCAL_static_case_health_summary_failband1_F080_sub2_s0975.csv`
- `tools/merge_reports/LOCAL_static_case_health_summary_failband1_F085_sub2_s105.csv`

## Status Note

Fail-band wave-1 is complete.

Wave-2 has now also completed enough launched work to serve as a
decision-quality closeout, and the active next-step program has moved on to:

- `reports/static_exal_tuning_20260404/failband_wave2_closeout_and_wave3_residual_program_20260404.md`

This document remains the design record for the broad staged wave-2 search.

## Wave-1 Closeout

### Final wave-1 result

| candidate_id | PASS | WARN | FAIL | resolved |
|---|---:|---:|---:|---:|
| `F080_sub2_s0975` | 7 | 11 | 12 | 18 |
| `F085_sub2_s105` | 7 | 11 | 12 | 18 |
| `F075_sub2_s105` | 3 | 13 | 14 | 16 |
| `F0825_sub2_s100` | 3 | 13 | 14 | 16 |
| `F080_sub2_s100_ref` | 3 | 8 | 19 | 11 |
| `F085_sub2_s095` | 3 | 7 | 20 | 10 |

### What improved

- the completed wave-1 screen touched all `30` residual static FAIL
  scope-cases and finished cleanly end to end
- the branch now has direct candidate-vs-candidate evidence on the full static
  residual band, not just on bridge rows or partial transfer slices
- the residual space is now better structured:
  - co-lead repair anchors:
    - `F080_sub2_s0975`
    - `F085_sub2_s105`
  - useful tertiary midpoint control:
    - `F0825_sub2_s100`
- row-level hardness is now measurable rather than assumed

### What still fails

- no candidate reached `0 FAIL`
- the residual static band is still not comparison-ready
- four rows failed under all six wave-1 candidates:
  - current RHS-NS:
    - `87` / `gausmix` / `tt=1000` / `tau=0p25`
    - `254` / `normal` / `tt=1000` / `tau=0p05`
    - `286` / `normal` / `tt=1000` / `tau=0p95`
  - legacy RHS:
    - `269` / `normal` / `tt=1000` / `tau=0p25`
- dynamic row `15` is still the only unresolved dynamic sidecar debt

### What worked best

1. central-tight `F080_sub2_s0975`
2. upper-edge wide `F085_sub2_s105`
3. midpoint `F0825_sub2_s100` on the recurring `gausmix / tau=0p25 /
   tt=1000` cluster
4. the repaired orchestration stack:
   deterministic manifests, locked summaries, supervisor, and monitor

### What clearly did not work

1. low-jump recovery:
   - `F075_sub2_s105`
2. central neutral control as the main fail-band repair choice:
   - `F080_sub2_s100_ref`
3. upper-edge tight scale:
   - `F085_sub2_s095`
4. reopening previously rejected families or mechanics:
   - `C060`
   - `F090 / F095`
   - lambda-tempering
   - no-jump
   - `substeps = 3`

## Interpretation

Wave-1 did not fail. It narrowed the remaining tuning problem.

The best current read is:

- some rows still want more movement than the `F080` center provides
- some rows regress when that movement is paired with the wrong scale
- the remaining useful search space is therefore:
  - `F0825` bridge variants
  - `F085` upper-edge variants
  - one cautious `F0875` extension below the rejected `F090` frontier

The evidence does **not** support returning to lower-jump or tighter-scale
variants.

## Active Wave-2 Strategy

### Guiding principle

Wave-2 should be broad enough to explore the real remaining alternatives, but
it should spend almost all compute on rows and candidates that are still
informative.

That means:

- keep the residual static scope at `30` rows only
- keep dynamic row `15` separate
- screen broadly across the surviving upper-central neighborhood
- stage the screen so broad exploration happens on the hardest rows first

## Wave-2 Candidate Set

### Retained anchors

| candidate_id | jump | scale | why retained |
|---|---:|---:|---|
| `F080_sub2_s0975` | 0.0800 | 0.975 | co-lead wave-1 winner; strongest central-tight anchor |
| `F0825_sub2_s100` | 0.0825 | 1.000 | useful midpoint control; uniquely helpful on the `gausmix / 0p25 / tt1000` cluster |
| `F085_sub2_s105` | 0.0850 | 1.050 | co-lead wave-1 winner; strongest upper-edge wide anchor |

### New bridge and upper-edge candidates

| candidate_id | jump | scale | why included |
|---|---:|---:|---|
| `F0825_sub2_s1025` | 0.0825 | 1.025 | first bridge between midpoint neutral and upper-edge wide |
| `F0825_sub2_s105` | 0.0825 | 1.050 | tests whether midpoint jump plus wider scale captures `F085` benefits without full upper-edge cost |
| `F085_sub2_s100` | 0.0850 | 1.000 | isolates jump increase from scale widening |
| `F085_sub2_s1025` | 0.0850 | 1.025 | midpoint bridge between the two best upper-edge shapes |
| `F0875_sub2_s100` | 0.0875 | 1.000 | cautious extension toward the hard unresolved rows without jumping all the way to rejected `F090` |
| `F0875_sub2_s1025` | 0.0875 | 1.025 | same extension with modest widening |
| `F0875_sub2_s105` | 0.0875 | 1.050 | tests whether the hardest rows are still movement-starved even after wave-1 |

### Explicit exclusions

Do **not** rerun:

- `F075_sub2_s105`
- `F080_sub2_s100_ref`
- `F085_sub2_s095`
- `F075_sub2_s095`
- `F080_sub2_s095`
- `C060`
- `F090 / F095`
- lambda-tempering, no-jump, and `substeps = 3`

## Staged Execution Design

### Why staged instead of another flat screen

Wave-1 already proved that a flat full-band screen is possible. The next best
use of compute is to preserve breadth while pruning the weakest new candidates
before they consume full-band budget.

### Stage definitions

| stage | scope | purpose |
|---|---|---|
| `sentinel12` | hardest `12` rows | broad first-pass search over all `10` candidates |
| `expand20` | hardest `20` rows | widen only the top `5` candidates from `sentinel12` |
| `full30` | all `30` rows | final comparison of the top `2` candidates from `expand20` |

### Row selection rule

The hardest rows are selected from completed wave-1 row coverage using:

1. lowest `resolved_by_candidates`
2. highest `fail_by_candidates`
3. deterministic scope-preserving order

Scope balance is preserved explicitly:

| stage | current RHS-NS rows | legacy RHS rows | total |
|---|---:|---:|---:|
| `sentinel12` | 8 | 4 | 12 |
| `expand20` | 14 | 6 | 20 |
| `full30` | 21 | 9 | 30 |

### Candidate advancement rule

- advance top `5` candidates from `sentinel12`
- advance top `2` candidates from `expand20`
- rank by:
  1. lowest FAIL
  2. lowest WARN
  3. highest PASS
  4. stable candidate id tie-break

## Planned Compute Footprint

The schedule is broad in potential coverage but bounded in actual execution.

| stage | potential candidate count | launched candidate count | rows per candidate | actual run count |
|---|---:|---:|---:|---:|
| `sentinel12` | 10 | 10 | 12 | 120 |
| `expand20` | 10 | 5 | 20 | 100 |
| `full30` | 10 | 2 | 30 | 60 |
| overall | 10 | staged | mixed | 280 |

This is broader than wave-1 in search shape, but still efficient because the
full `30`-row budget is only spent on finalists.

## Readiness Verification

Wave-2 was validated in prepare-only mode before launch.

Verified:

- deterministic stage counts:
  - `sentinel12 = 120`
  - `expand20 = 200`
  - `full30 = 300`
- candidate coverage:
  - all `10` candidate profiles appear in each stage schedule
- scope balance:
  - `8/4`, `14/6`, and `21/9` current/legacy splits are preserved by stage
- shell launcher, supervisor, and monitor scripts pass `bash -n`
- stage promotion now penalizes missing rows ahead of gate FAILs

## Operational Rules

### Acceptance

The campaign-level acceptance rule is unchanged:

- `0` runtime failures
- `0` gate FAILs
- `WARN` acceptable if documented and scientifically interpretable

### Stop rule after wave-2

- if a finalist reaches `0 FAIL` on `full30`, promote it as the next
  campaign-repair baseline
- if no finalist reaches `0 FAIL`, do **not** reopen the entire campaign
- instead isolate only the residual rows that still fail under the best
  finalist and open a narrower wave-3 repair lane

## Dynamic Row `15`

Dynamic row `15` remains out of this program.

Reason:

- the current evidence still supports a separate chain-quality repair lane
- there is no new row-`15` repair hypothesis generated by wave-1
- launching it alongside the static wave would add noise without increasing
  learning value

## Operational Bottom Line

The study is still moving in the right direction.

The best completed broad static refresh and the completed wave-1 fail-band
screen both improved the state of the campaign. They also showed that the
remaining uncertainty is now concentrated in the upper-central `F080` to
`F0875` neighborhood.

Wave-2 should therefore:

1. treat wave-1 as the new planning baseline
2. search broadly only within the still-credible upper-central neighborhood
3. prune by stage instead of committing full-band budget to every variant
4. keep dynamic row `15` separate until it has its own real repair hypothesis
