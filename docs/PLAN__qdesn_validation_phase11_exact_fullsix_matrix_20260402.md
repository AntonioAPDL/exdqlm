# PLAN: QDESN Validation Phase 11 Exact Full-Six Matrix (2026-04-02)

Date: 2026-04-02  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight QDESN wave as an exact full-6 transfer matrix rather than another
reduced-screen-first search.

This is driven by two now-consistent signals:

1. Phase 10 showed that the focused 5-root local winner did not survive the full-6 confirmation;
2. the concurrent static-exAL long-run work on `validation/rerun-after-0.4.0-sync` is solving the
   same class of problem by forcing challengers through an exact reference-control ladder before
   promotion.

The core objective of Phase 11 is:

1. search only the still-plausible `R68/R65/R61` neighborhood;
2. start on the exact full-6 harness immediately;
3. keep the exact `R68` control present in every stage;
4. rerun selected survivors before any new promotion decision.

## 2) Current Reference State

### Family ordering from Phase 9

| family | median_total_fail_n | median_sentinel_fail_n | min_total_fail_n | median_runtime_inflation |
|---|---:|---:|---:|---:|
| `r68_ridge_signal` | `4` | `0` | `2` | `1.1174` |
| `r65_ridge_chain_stepsout` | `4` | `0` | `3` | `0.8785` |
| `r61_stable_anchor` | `4` | `1` | `4` | `0.7117` |
| `r84_rhs_blockpass5` | `5` | `2` | `4` | `0.7982` |

### Transfer lesson from Phase 10

| view | profile | total_fail_n | sentinel_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---|
| focused Stage-1 winner | `R201_r65_balanced_control` | `3` | `0` | `0.904` | best reduced-screen result |
| full-6 reference control | `R200_r68_replicated_anchor` | `4` | `1` | `1.072` | better full-6 result |
| Stage-2 selected survivor | `R201_r65_balanced_control` | `5` | `1` | `0.853` | local winner did not transfer |

Operational interpretation:

- exact `R68` remains the active scientific reference family;
- exact `R65` remains the balanced challenger control;
- exact `R61` remains the runtime reference control;
- promotion should now require success against the exact full-6 reference harness, not just a focused local screen.

## 3) What This Wave Will Not Redo

Explicitly out of scope:

- reopening the dead `R84` rhs-led family as a lead idea;
- replaying bridge-only, QR-only, conditioning-only, or early transformed-sigma families;
- trusting a reduced root subset as the first promotion gate;
- running another broad local screen that omits the full branch-facing guard rails;
- spending compute on heavy widening or clearly weak Phase-10 descendants.

## 4) Candidate Program

### Controls

| profile | role | why it is included |
|---|---|---|
| `R300_r68_exact_anchor` | scientific reference | strongest replicated family and current exact full-6 reference |
| `R301_r65_balanced_control` | balanced challenger control | best runtime-balanced replicated family |
| `R302_r61_runtime_reference` | runtime reference | cheapest still-credible family |

### `R68` exact-neighborhood descendants

Purpose:

- keep the strongest replicated scientific family in the lead position;
- test whether the best local ridge idea from Phase 10 can be made transfer-stable;
- add only mild rhs guard support where it protects sentinel behavior.

| profile | idea |
|---|---|
| `R310_r68_pass1_chain1000` | direct full-6 test of the strongest Phase-10 ridge-local winner |
| `R311_r68_pass1_chain1000_rhsfreeze100_softblock` | add mild rhs guard to `R310` |
| `R312_r68_pass1_chain950` | moderate chain interpolation between exact `R68` and `R310` |
| `R313_r68_pass1_chain950_rhsfreeze100_softblock` | guarded version of `R312` |
| `R314_r68_softsigma_rhsfreeze100_softblock` | softer ridge movement plus mild rhs guard |
| `R315_r68_steps70_pass1_rhsfreeze100_softblock` | moderate step-out plus mild rhs guard |

### `R65` exact-neighborhood descendants

Purpose:

- keep the best balanced family alive without over-trusting its Phase-10 local result;
- test whether moderate runtime trims make the `R65` hybrids more exact-stable on full-6;
- preserve only the `R65` directions that still looked scientifically plausible.

| profile | idea |
|---|---|
| `R320_r65_rhsfreeze100_pass1` | direct full-6 test of the strongest Phase-10 balanced hybrid |
| `R321_r65_rhsfreeze100_pass1_chain1100` | runtime-trimmed version of `R320` |
| `R322_r65_rhsfreeze100_pass1_softsigma` | softer-ridge version of `R320` |
| `R323_r65_pass1_stepsout_chain1100` | runtime-trimmed ridge-pass steps-out family |
| `R324_r65_rhsfreeze100_stepsout_chain1100` | guarded runtime-trimmed steps-out family |

Total Stage-1 candidates:

- `14` profiles (`3` controls + `11` descendants)

## 5) Why These Candidates

This program is broad, but still disciplined.

1. every non-control candidate descends from a replicated surviving family;
2. every candidate varies only one or two still-live levers:
   - modest ridge chain length;
   - one ridge extra pass;
   - softer ridge width;
   - mild rhs freeze / soft-block support;
   - moderate ridge step-out expansion;
3. no candidate reopens dead `R84`, QR, conditioning, or heavy-widening search space;
4. the search is broad enough to compare:
   - pure `R68` ridge-local refinements,
   - guarded `R68` refinements,
   - balanced `R65` challengers;
5. every candidate is evaluated on the real branch-facing harness from the first stage onward.

## 6) Stage Design

### Stage 1: exact full-6 matrix

Root set:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_bigW @ tau=0.95 al rhs_ns`
4. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
5. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
6. `dlm_constV_smallW @ tau=0.95 exal ridge`

Advance rule:

- `top_n = 5`
- `max_total_fail_n <= 4`
- `max_sentinel_fail_n <= 1`
- `max_runtime_inflation <= 1.30`
- `min_fail_reduction >= 0.333`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R300_r68_exact_anchor`
- `require_not_worse_than_reference = true`

Interpretation:

- challengers must at least hold the line against the exact `R68` reference on the real full-6 harness;
- this stage is broad, but it is already exact.

### Stage 2: rerun confirmation

Purpose:

- rerun only the strongest exact survivors against the same full-6 harness;
- test whether Stage-1 exact wins replicate immediately.

Advance rule:

- `top_n = 3`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.20`
- `min_fail_reduction >= 0.50`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R300_r68_exact_anchor`
- `require_better_than_reference = true`

### Stage 3: stability confirmation

Purpose:

- rerun the confirmed survivors one more time before any promotion call;
- preserve the Phase-7 and Phase-9 lesson that one good exact run is still not enough.

Advance type:

- `report_only`

## 7) Resource Plan

Execution plan:

- staged supervisor via the existing family-screen runner
- full-6 harness in every stage
- `campaign_workers = 6`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 240`
- plots off

Why this is still efficient:

- the run is broader in candidate count, but not in hypothesis space;
- all candidates are exact full-6, so we avoid wasting another overnight wave on transfer-mismatched local wins;
- later stages rerun survivors only.

## 8) Decision Rules

Primary review files:

1. `tables/stage_execution_status.csv`
2. `stages/S1_.../summary/stage_candidate_selection.md`
3. `stages/S1_.../tables/profile_rank_summary.csv`
4. `stages/S2_.../tables/profile_rank_summary.csv`
5. `stages/S3_.../tables/profile_rank_summary.csv`

Interpretation rules:

- no new profile should be promoted from a single exact run;
- the exact `R68` control remains the stage reference unless a challenger beats it on the same harness;
- stable `sentinel_fail_n = 0` matters as much as raw fail-count improvement;
- runtime discipline matters, but only after exact branch-facing behavior is credible.

Practical success target:

- stable `total_fail_n <= 3`
- `sentinel_fail_n = 0`
- no new finite/domain/collapse regressions
- at least one rerun that still beats the exact `R68` control

## 9) Morning Review

Open these first:

1. `reports/.../tables/stage_execution_status.csv`
2. `reports/.../stages/S1_.../summary/stage_candidate_selection.md`
3. `reports/.../stages/S1_.../tables/profile_rank_summary.csv`
4. `reports/.../stages/S2_.../tables/profile_rank_summary.csv`
5. `reports/.../stages/S3_.../tables/profile_rank_summary.csv`

Questions to answer:

1. does any challenger beat exact `R68` on the real full-6 harness;
2. do the guarded `R68` descendants clean the sentinel without throwing away the ridge gain;
3. can any balanced `R65` descendant transfer its local win to the full-6 harness;
4. which survivor still looks stable after rerun confirmation.
