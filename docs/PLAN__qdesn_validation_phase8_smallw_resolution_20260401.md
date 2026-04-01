# PLAN: QDESN Validation Phase 8 SmallW Resolution Screen (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight program from the new stable baseline: the exact `R61/R44` settings.

This wave is designed around one fact:

- after Phase 7 stability confirmation, the remaining fail set is only the two
  `smallW @ tau=0.95 exal` roots.

So the next wave should:

1. target the two remaining fail roots directly;
2. protect the current `WARN` guard rails from regression;
3. avoid replaying broad families we already know are weak;
4. keep full-6 compute for confirmation and stability, not for the broad search itself.

## 2) New Baseline

Current stable baseline:

- profile: `R61_r44_anchor`
- meaning: exact practical Phase-6 `R44` settings
- stable full-6 outcome:
  - `2 FAIL`
  - `0 sentinel FAIL`
  - `runtime_inflation = 0.7038`

Remaining fail roots:

1. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
2. `dlm_constV_smallW @ tau=0.95 exal ridge`

Current guard-rail `WARN` roots:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`

The `al` root stays in the final confirmation harness, but it is no longer the highest-value screen root.

## 3) What This Wave Will Not Redo

Explicitly out of scope:

- replaying the full broad Phase 7 family as the primary search surface;
- rerunning `R62`, `R64`, `R67`, `R69`, `R70`, or `R71` as lead ideas;
- reopening QR-only, conditioning-only, bridge-only, or earlier transformed-sigma family branches;
- treating the broad Stage-1 Phase 7 ranking as more important than the stability reruns;
- reopening broad branch validation or closeout reruns.

This wave is deliberately narrow in root set, but still broad in the remaining useful tuning space.

## 4) Objectives

Primary objective:

- reduce the current stable baseline from `2 FAIL` to `1` or `0` on the remaining `smallW` fail pair,
  without turning current `WARN` guard rails back into `FAIL`.

Practical win conditions:

- best win: `0 FAIL` on full 6-root confirmation;
- meaningful win: `1 FAIL` on full 6-root confirmation with `0` sentinel FAIL;
- minimum scientific win: strong target-root improvement that reproduces in the stability rerun.

## 5) Stage Structure

### Stage S1: SmallW resolution broad screen

Purpose:

- search the remaining rhs-local and ridge-local tuning space efficiently;
- include the two current fail roots and the most informative current `WARN` guard rails;
- allow more candidates overnight without spending full-6 compute on obviously weak profiles.

Stage-1 root set:

1. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
2. `dlm_constV_smallW @ tau=0.95 exal ridge`
3. `dlm_ar1V @ tau=0.95 exal rhs_ns`
4. `dlm_constV_bigW @ tau=0.05 exal ridge`
5. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`

Advance rule:

- keep the top `5` survivors;
- require:
  - `total_fail_n <= 3`
  - `sentinel_fail_n <= 0`
  - `runtime_inflation <= 1.20`
  - `fail_reduction >= 0.45`
  - `severe_improved_n >= 1`

### Stage S2: full-6 confirmation

Purpose:

- rerun the best Stage-1 survivors on the complete fixed 6-root harness;
- confirm that target-root gains survive the full branch-facing harness.

Advance rule:

- keep the top `3` survivors;
- require:
  - `total_fail_n <= 3`
  - `sentinel_fail_n = 0`
  - `runtime_inflation <= 1.10`
  - `fail_reduction >= 0.50`
  - `severe_improved_n >= 1`

### Stage S3: stability confirmation

Purpose:

- rerun the best full-6 survivors exactly once more;
- separate real progress from ranking noise.

Advance rule:

- keep the top `1` survivor;
- require:
  - `total_fail_n <= 2`
  - `sentinel_fail_n = 0`
  - `runtime_inflation <= 1.05`
  - `fail_reduction >= 0.60`
  - `severe_improved_n >= 2`

## 6) Candidate Families

### Controls

`R80_r61_stable_anchor`

- exact Stage-2-stable `R61/R44` baseline
- purpose: live anchor and required reference

`R81_r63_rhs_signal_control`

- exact `R63` rhs-side signal profile from Phase 7
- purpose: preserve the strongest clean rhs-side lead we observed in Stage 1

`R82_r68_ridge_signal_control`

- exact `R68` ridge-side signal profile from Phase 7
- purpose: preserve the cleanest ridge-side zero-sentinel lead from Stage 1

### RHS residual family

`R83_r61_rhs_freeze100_softblock`

- start from `R61`
- keep chain length moderate
- modestly soften the rhs transformed tau/c2 block widths
- add only a small burn/freeze increase
- purpose: reduce rhs Geweke and half-drift on the `smallW rhs_ns` fail root without destabilizing guard rails

`R84_r61_rhs_freeze100_blockpass5`

- build on `R83`
- increase rhs transformed block passes from `4 -> 5`
- purpose: test whether the rhs residual wants more transformed-block refresh, not just softer movement

`R85_r61_rhs_chain1100_freeze100_softblock`

- build on `R83`
- add a modest chain increase
- purpose: see whether the rhs residual improves with slightly more keep-size once the local path is softened

`R86_r61_rhs_freeze120_blockpass5`

- strongest low-risk rhs local candidate
- slightly deeper freeze plus more block refresh, but without the heavier Phase-7 chain inflation
- purpose: maximal rhs cleanup attempt that still stays inside the disciplined local family

### Ridge residual family

`R87_r61_ridge_pass1_softsigma`

- start from the `R68` idea, but soften ridge movement slightly
- purpose: try to keep the good zero-sentinel shape while trading half-drift down

`R88_r61_ridge_pass1_chain1000`

- start from `R68`
- add a modest ridge chain increase only
- purpose: target ESS/ACF directly without reopening the heavier `R65/R67` regime

`R89_r61_ridge_steps70_chain900`

- start from `R61`
- make a mild step-out increase only
- purpose: explore the middle ground between `R61` and `R65`

`R90_r61_ridge_pass1_steps70_chain900`

- combine the `R68` extra-pass idea with the milder step-out expansion
- purpose: test whether the clean ridge win wants a small geometry expansion without the heavier chain cost

### Combined local family

`R91_r61_rhssoftblock_ridgepass1`

- combine `R83` with `R87`
- purpose: low-risk joint candidate for the two remaining fail roots

`R92_r61_blockpass5_ridgepass1chain1000`

- combine `R84` with `R88`
- purpose: strongest disciplined combined candidate before heavier stress

`R93_r61_r63rhs_r68ridge`

- combine the exact Phase-7 rhs-side signal (`R63`) with the exact ridge-side signal (`R68`)
- purpose: explicit “best-of-both-signals” candidate without inventing a new family

## 7) Exact Schedule

| profile | bucket | main idea | inclusion reason |
|---|---|---|---|
| `R80_r61_stable_anchor` | control | exact stable baseline | mandatory anchor |
| `R81_r63_rhs_signal_control` | control | exact rhs signal | preserve best clean rhs Stage-1 lead |
| `R82_r68_ridge_signal_control` | control | exact ridge signal | preserve best clean ridge Stage-1 lead |
| `R83_r61_rhs_freeze100_softblock` | rhs | soften rhs local block + small freeze | direct fix for rhs drift/geweke residual |
| `R84_r61_rhs_freeze100_blockpass5` | rhs | rhs block refresh increase | test rhs mixing via extra transformed passes |
| `R85_r61_rhs_chain1100_freeze100_softblock` | rhs | modest chain + soft block | see whether keep-size helps once drift is controlled |
| `R86_r61_rhs_freeze120_blockpass5` | rhs | strongest disciplined rhs local repair | max rhs cleanup without reopening heavy chain families |
| `R87_r61_ridge_pass1_softsigma` | ridge | softer `R68` | reduce drift while preserving ridge signal |
| `R88_r61_ridge_pass1_chain1000` | ridge | `R68` plus modest chain | target ridge ESS/ACF directly |
| `R89_r61_ridge_steps70_chain900` | ridge | mild step-out expansion from `R61` | middle ground between `R61` and `R65` |
| `R90_r61_ridge_pass1_steps70_chain900` | ridge | pass + mild step-out expansion | disciplined ridge geometry test |
| `R91_r61_rhssoftblock_ridgepass1` | combined | low-risk dual repair | balanced joint candidate |
| `R92_r61_blockpass5_ridgepass1chain1000` | combined | strongest disciplined dual repair | broadest joint candidate still inside current family |
| `R93_r61_r63rhs_r68ridge` | combined | exact best-of-signals hybrid | reuse only the strongest clean ideas already observed |

## 8) Resource Plan

Execution plan:

- stage supervisor: sequential
- profile campaigns: parallel root execution
- `campaign_workers = 4`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 180`
- plots off

Why this is efficient:

- the broad search uses only a 5-root resolution set;
- full-6 compute is spent only on the most promising survivors;
- stability reruns are reserved for the top full-6 survivors;
- the candidate space is broad across mechanisms, but narrow across root targets.

## 9) Morning Review

First files to inspect:

1. `summary/family_b_screen_results.md`
2. `tables/stage_execution_status.csv`
3. `stages/S1_smallw_resolution_screen/summary/stage_candidate_selection.md`
4. `stages/S2_full_six_confirmation/summary/stage_candidate_selection.md`
5. `stages/S3_stability_confirmation/summary/stage_candidate_selection.md`
6. `stages/S3_stability_confirmation/.../tables/profile_rank_summary.csv`

Key questions:

- does any candidate reduce the focused 5-root screen to `<= 1 FAIL`?
- does any candidate confirm at `<= 2 FAIL` on the full 6-root harness?
- do the clean zero-sentinel leads (`R63` / `R68`) hold up when rerun?
- can the remaining `smallW rhs_ns` fail be removed without destabilizing the `ar1` or `tau=0.50` rhs guard rails?
- can the remaining `smallW ridge` fail be removed without turning the `bigW ridge` guard rail back into `FAIL`?

## 10) Decision Rules

If a candidate reaches:

- `total_fail_n <= 2` on full-6 confirmation,
- `sentinel_fail_n = 0`,
- and reproduces in stability confirmation,

then:

- carry that candidate forward as the new operational baseline.

If the best stability-confirmed candidate remains at `2 FAIL`:

- keep `R61` as the baseline unless the new candidate is clearly better and equally stable.

If the targeted screen fails to improve the `smallW` pair:

- stop broad schedule expansion and treat configuration-only tuning as nearly exhausted on the current kernel.
