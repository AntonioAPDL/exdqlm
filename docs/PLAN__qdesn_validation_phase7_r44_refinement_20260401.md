# PLAN: QDESN Validation Phase 7 R44 Refinement + Stability Screen (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next disciplined screen from the practical best current profile, `R44_r31_ridge_chain900_stepsout`,
and explicitly separate two remaining needs:

1. squeeze the last near-threshold FAILs toward `WARN`;
2. confirm that any apparent winner is stable enough to trust.

This wave is designed to:

- keep the proven `R18 -> R31 -> R44` progress;
- avoid replaying dead family branches;
- focus only on the current remaining fail mechanisms;
- use the full fixed 6-root harness as the decision surface;
- add a second-stage rerun of the strongest Stage-1 survivors.

## 2) Current Best Read

The latest completed evidence says:

- `R44_r31_ridge_chain900_stepsout` is the best practical current profile;
- `R44` gets the full-6 harness to `3 FAIL`, with `0` sentinel FAILs;
- the remaining `R44` fail roots are:
  1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
  2. `dlm_constV_bigW @ tau=0.05 exal ridge`
  3. `dlm_constV_smallW @ tau=0.95 exal ridge`

Current mechanism read:

- `ar1V exal rhs_ns` is now a mild drift + Geweke stabilization problem;
- both ridge roots are now ESS + ACF + half-drift problems;
- `R51` proved that the ridge pair can be pushed harder, but its rhs settings were too destabilizing.

## 3) What This Wave Will Not Redo

Explicitly out of scope:

- rerunning the full Phase 6 family unchanged;
- carrying `R51` forward as the main baseline;
- replaying `R41`, `R43`, `R48`, or `R49` style rhs-led families that already regressed;
- reopening QR-led or conditioning-led families;
- reopening the broader validation ladder.

This wave is intentionally `R44`-centered and stability-aware.

## 4) Objectives

Primary objective:

- reduce the fixed 6-root harness below the current `3 FAIL` level while keeping sentinel fails at `0`.

Acceptance logic:

- `WARN` is acceptable;
- the first strong win is `total_fail_n <= 2`;
- the preferred win is `total_fail_n <= 2` with `sentinel_fail_n = 0`;
- a useful stability signal is a candidate that reproduces across the Stage-2 rerun without losing its ranking.

## 5) Stage Structure

### Stage S1: broad full-6 refinement

Purpose:

- search the remaining useful tuning space around `R44`;
- include `R31` as a control;
- identify the top practical descendants.

Advance rule:

- keep the top `3` survivors;
- require:
  - `total_fail_n <= 4`
  - `sentinel_fail_n <= 1`
  - `runtime_inflation <= 1.25`
  - `fail_reduction >= 0.30`
  - `severe_improved_n >= 1`

### Stage S2: stability confirmation

Purpose:

- rerun the Stage-S1 survivors on the same full-6 harness;
- separate real winners from single-run noise.

Advance rule:

- keep the top `2` stable survivors;
- require:
  - `total_fail_n <= 3`
  - `sentinel_fail_n = 0`
  - `runtime_inflation <= 1.10`
  - `fail_reduction >= 0.40`
  - `severe_improved_n >= 1`

## 6) Candidate Families

### Controls

`R60_r31_control`

- exact Phase-6 `R31` carry-forward baseline
- purpose: maintain continuity with the previous wave

`R61_r44_anchor`

- exact Phase-6 `R44` profile
- purpose: live anchor for Stage 1 and Stage 2

### Mild rhs stabilization on top of `R44`

`R62_r44_rhs_chain1100`

- ridge fixed at `R44`
- rhs chain length increased modestly
- purpose: improve `ar1V` drift without destabilizing sentinels

`R63_r44_rhs_chain1200_freeze100`

- ridge fixed at `R44`
- rhs chain length and tau freeze increased modestly
- purpose: stronger `ar1V` stabilization test

`R64_r44_rhs_chain1100_softsigma`

- ridge fixed at `R44`
- rhs chain increased modestly and rhs local movement softened slightly
- purpose: see if the residual rhs problem wants gentler movement rather than heavier burn alone

### Ridge refinement on top of `R44`

`R65_r44_ridge_chain1200_stepsout`

- rhs fixed at `R44`
- ridge chain extended further while keeping the successful `R44` geometry pattern
- purpose: push both ridge roots with minimal conceptual change

`R66_r44_ridge_softsigma_stepsout`

- rhs fixed at `R44`
- ridge local movement softened slightly while keeping the widened step-outs
- purpose: try to reduce half-drift without giving back all ESS

`R67_r44_ridge_chain1200_stepsout_wide`

- rhs fixed at `R44`
- ridge chain and step-out budgets pushed farther than `R65`
- purpose: heavier ridge-only stress test

`R68_r44_ridge_pass1_stepsout_chain900`

- rhs fixed at `R44`
- one ridge-only extra pass is reintroduced, but only on top of the `R44` step-out pattern
- purpose: test whether the old pass idea only works when paired with the better ridge geometry

### Combined descendants

`R69_r44_rhschain1100_ridgechain1200`

- combine `R62` rhs stabilization with `R65` ridge refinement

`R70_r44_rhschain1200freeze100_ridgewide`

- combine `R63` rhs stabilization with `R67` ridge refinement

`R71_r44_rhssoft_ridgepass1`

- combine `R64` rhs stabilization with `R68` ridge refinement

## 7) Exact Schedule

| profile | bucket | main idea | purpose |
|---|---|---|---|
| `R60_r31_control` | control | exact `R31` | continuity control |
| `R61_r44_anchor` | control | exact `R44` | live anchor |
| `R62_r44_rhs_chain1100` | rhs | modest rhs chain increase | fix `ar1V` without sentinel regression |
| `R63_r44_rhs_chain1200_freeze100` | rhs | stronger rhs stabilization | harder `ar1V` test |
| `R64_r44_rhs_chain1100_softsigma` | rhs | gentler rhs local path | rhs drift/geweke cleanup |
| `R65_r44_ridge_chain1200_stepsout` | ridge | more ridge chain, same good geometry | first ridge carry-forward |
| `R66_r44_ridge_softsigma_stepsout` | ridge | softer ridge local path | reduce drift while preserving ESS |
| `R67_r44_ridge_chain1200_stepsout_wide` | ridge | heavier ridge-only stress test | see if the ridge pair can both drop to WARN |
| `R68_r44_ridge_pass1_stepsout_chain900` | ridge | reintroduce pass only on top of step-outs | test pass-plus-geometry interaction |
| `R69_r44_rhschain1100_ridgechain1200` | combined | low-risk joint repair | balanced joint candidate |
| `R70_r44_rhschain1200freeze100_ridgewide` | combined | stronger joint repair | highest-coverage heavy candidate |
| `R71_r44_rhssoft_ridgepass1` | combined | gentler joint repair | combine mild rhs with pass-plus-geometry ridge |

## 8) Resource Plan

Execution plan:

- supervisor level: sequential
- Stage 1 uses the full fixed 6-root harness
- Stage 2 reruns only the top `3` Stage-1 survivors
- `campaign_workers = 4`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 180`
- plots off

Why this is efficient:

- the root set is already small;
- the broad screen is limited to new `R44` descendants only;
- the Stage-2 rerun spends extra compute only on the most promising candidates;
- the design trades a small amount of extra runtime for much better confidence in the morning ranking.

## 9) Morning Review

First files to inspect:

1. `summary/family_b_screen_results.md`
2. `tables/stage_execution_status.csv`
3. `stages/S1_full_six_refinement/summary/stage_candidate_selection.md`
4. `stages/S2_stability_confirmation/summary/stage_candidate_selection.md`
5. `stages/S2_stability_confirmation/.../tables/profile_rank_summary.csv`

Key questions:

- does any candidate get to `<= 2 FAIL`?
- does any candidate keep `sentinel_fail_n = 0` in both Stage 1 and Stage 2?
- do the best ridge descendants stay better than `R44` when rerun?
- does any mild rhs stabilization improve `ar1V` without reintroducing sentinel FAILs?

## 10) Decision Rules

If a candidate reaches:

- `total_fail_n <= 2`
- `sentinel_fail_n = 0`
- stable reproduction in Stage 2

then:

- carry that candidate into the next closeout-facing confirmation wave.

If the best stable candidate remains at `3 FAIL`:

- promote it as the new local baseline only if it is clearly better than `R44` and reproduces in Stage 2;
- otherwise keep `R44` as the baseline and treat configuration-only tuning as nearly exhausted.

If the Stage-2 winners collapse back toward `R44`:

- interpret that as a stability warning;
- stop widening the manifest search space and prepare to pivot toward deeper kernel work.
