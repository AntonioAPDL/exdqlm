# PLAN: QDESN Validation Phase 15 R512 Sentinel Crossover Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight QDESN wave as a broader but still disciplined exact full-6 crossover matrix
around the promoted `R512` baseline.

Phase 14 showed that the problem is no longer a family-selection problem. It is now a
signal-combination problem:

1. `R600` is the best broad repair pattern;
2. `R612` is the best ridge rescue;
3. `R622` is the best rhs-local hedge;
4. `R616` is the only sentinel-clean geometry clue.

The Phase-15 purpose is therefore:

1. combine those surviving local signals without reopening dead families;
2. allow scientifically promising low-fail candidates to rerun even if they still carry one
   sentinel FAIL in Stage 1;
3. require zero-sentinel rerun confirmation before any promotion call;
4. promote a new baseline only if a candidate reaches a true `2 FAIL / 0 sentinel FAIL` outcome.

## 2) Current Reference State

### Phase-13 promoted baseline

| view | profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---:|---|
| promoted baseline | `R512_r412_pass2_chain1000` | `3` | `0` | `3` | `1.106` | current active baseline |
| previous anchor | `R500_r412_provisional_anchor` | `3` | `1` | `4` | `1.060` | previous-anchor control |
| clean control | `R402_r65_balanced_control` | `4` | `1` | `5` | `0.975` | cheapest useful balanced control |

### Phase-14 crossover clues

| role | profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | why it matters |
|---|---|---:|---:|---:|---:|---|
| best raw rerun | `R600_r512_promoted_anchor` | `1` | `1` | `2` | `1.115` | strongest broad repair pattern |
| ridge rescue reference | `R612_r512_burn550_chain1100` | `2` | `1` | `3` | `1.031` | only local line that repaired `bigW ridge` cleanly enough to matter |
| rhs hedge reference | `R622_r512_rhssoft_freeze90` | `2` | `1` | `3` | `1.086` | best rhs-local hedge without reopening `R421` |
| sentinel clue reference | `R616_r512_softgamma_steps80` | `4` | `0` | `4` | `1.138` | only completed zero-sentinel signal |
| clean benchmark | `R602_r402_balanced_control` | `2` | `1` | `3` | `0.890` | runtime/sentinel control |

Interpretation:

- the residual cluster is now small enough that the next broad wave should be a crossover matrix,
  not another one-axis sweep;
- the most likely useful candidates are untried combinations of the surviving `R600/R612/R622/R616`
  signals;
- we should not require strict anchor dominance at Stage 1, because Phase 14 showed that a
  sentinel-clean clue can be scientifically useful even when the anchor still has the best raw fail
  count.

## 3) What This Wave Will Not Redo

Explicitly out of scope:

- reopening `R421`, trimmed `R421`, or `R412 + R421` combined families;
- replaying chain-only `R512` descendants (`R610`, `R611`) as if they were still informative;
- replaying pass-only `R513`-style inflation;
- replaying raw `steps80` / `steps80 + chain1100` geometry lines as main candidates;
- replaying the weak Phase-14 coupled lines (`R630`, `R631`);
- reopening `R84`, `R422`, bridge, QR-only, conditioning-only, or heavy-widening families.

## 4) Candidate Program

### Controls and reference signals

| profile | role | why it is included |
|---|---|---|
| `R700_r512_anchor_control` | promoted-anchor control | current active branch-facing baseline |
| `R701_r402_balanced_control` | clean control | cheapest useful balanced benchmark |
| `R702_r612_ridge_reference` | ridge reference | strongest Phase-14 ridge rescue |
| `R703_r622_rhs_reference` | rhs reference | strongest Phase-14 rhs hedge |
| `R704_r616_sentinel_reference` | sentinel reference | only completed zero-sentinel clue |

### Gentle soft-geometry descendants

Purpose:

- test whether the sentinel-clean `R616` clue becomes useful once it is made less aggressive or
  paired with the best ridge rescue.

| profile | idea |
|---|---|
| `R710_r512_softgamma_steps70` | softer ridge geometry without the wider `steps80` push |
| `R711_r512_softgamma_steps75` | intermediate geometry between the anchor and `R616` |
| `R712_r512_burn550_chain1100_softgamma_steps70` | `R612` ridge rescue plus gentler soft geometry |
| `R713_r512_burn550_chain1100_softgamma_steps75` | `R612` ridge rescue plus intermediate soft geometry |

### Ridge + rhs crossover descendants

Purpose:

- combine the strongest ridge rescue and rhs-local hedge patterns without reopening the old
  `R421` family.

| profile | idea |
|---|---|
| `R720_r512_burn550_chain1100_rhsfreeze90` | `R612` ridge rescue plus mild rhs freeze |
| `R721_r512_burn550_chain1100_rhssoft_freeze90` | `R612` ridge rescue plus the best rhs-soft signal |
| `R722_r512_softgamma_steps70_rhssoft_freeze90` | gentler sentinel geometry plus rhs-soft support |
| `R723_r512_softgamma_steps75_rhssoft_freeze90` | intermediate geometry plus rhs-soft support |

### High-value coupled hedges

Purpose:

- test only the two most plausible three-signal crossovers.

| profile | idea |
|---|---|
| `R730_r512_burn550_chain1100_softgamma_steps70_rhssoft_freeze90` | combine the strongest ridge rescue, gentler sentinel geometry, and rhs-soft hedge |
| `R731_r402_softgamma_steps70_rhssoft_freeze90` | clean-control hedge with the same sentinel-oriented crossover logic |

Total Stage-1 candidates:

- `15` profiles (`5` controls + `10` descendants)

## 5) Why These Candidates

This is intentionally broader than a single-axis repair wave, but still disciplined:

1. every non-control candidate descends directly from a signal that Phase 14 kept alive;
2. no candidate reopens a dominated family;
3. every candidate changes only one or two still-plausible local ingredients:
   - gentler soft-geometry,
   - `R612`-style ridge rescue,
   - `R622`-style rhs softness;
4. the final coupled block is deliberately tiny and only tests the highest-value three-way merges;
5. the exact full-6 harness remains the only stage harness.

## 6) Stage Design

### Stage 1: exact full-6 crossover matrix

Root set:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_bigW @ tau=0.95 al rhs_ns`
4. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
5. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
6. `dlm_constV_smallW @ tau=0.95 exal ridge`

Advance rule:

- `top_n = 6`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 1`
- `max_runtime_inflation <= 1.30`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R700_r512_anchor_control`

Interpretation:

- Stage 1 is still exact and branch-facing;
- unlike Phase 14, it intentionally allows low-fail / one-sentinel candidates into rerun because
  that is where the surviving scientific signal currently lives.

### Stage 2: zero-sentinel rerun confirmation

Purpose:

- rerun only the strongest exact Stage-1 survivors;
- require that the local signal becomes zero-sentinel under rerun.

Advance rule:

- `top_n = 4`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.30`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R700_r512_anchor_control`

### Stage 3: final residual confirmation

Purpose:

- rerun the confirmation survivors one more time;
- require a true residual-set reduction before any new promotion decision.

Advance rule:

- `top_n = 2`
- `max_total_fail_n <= 2`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.30`
- `min_fail_reduction >= 0.667`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R700_r512_anchor_control`

## 7) Resource Plan

Execution plan:

- staged supervisor via the existing family-screen runner
- exact full-6 harness in every stage
- `campaign_workers = 6`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 240`
- plots off

Why this is efficient:

- the program is broad only inside the now-tiny surviving search space;
- the early stage explores all still-plausible crossover moves in one overnight wave;
- rerun and final confirmation remain survivor-only;
- the program is optimizing for learning value per unit of compute, not family breadth.

## 8) Decision Rules

Primary review files:

1. `tables/stage_execution_status.csv`
2. `stages/S1_.../summary/stage_candidate_selection.md`
3. `stages/S1_.../tables/profile_rank_summary.csv`
4. `stages/S2_.../summary/stage_candidate_selection.md`
5. `stages/S3_.../summary/stage_candidate_selection.md`

Primary decision questions:

1. can any crossover candidate preserve the low-fail behavior of `R600` and remove the remaining
   sentinel FAIL;
2. if yes, does that survive zero-sentinel rerun confirmation;
3. if not, which surviving ingredient should become the final narrow axis for the next repair wave:
   - `R612` ridge rescue,
   - `R622` rhs softness,
   - or `R616` sentinel geometry.

## 9) Expected Decision Output

At the end of Phase 15, we should be able to make one of three clean calls:

1. promote a new baseline because a crossover candidate reached `2 FAIL / 0 sentinel FAIL`;
2. keep `R512` as the active baseline and narrow the next wave to one final local axis;
3. stop local crossover search and escalate to a deeper redesign only if all three surviving local
   ingredients fail to combine productively.
