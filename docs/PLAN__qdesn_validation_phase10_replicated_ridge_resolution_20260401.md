# PLAN: QDESN Validation Phase 10 Replicated Ridge Resolution Screen (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight wave as a ridge-led, replication-aware staged screen rooted in the best Phase-9 families.

This wave is built around the core Phase-9 outcome:

- `R68` is now the best replicated scientific family;
- `R65` is the best runtime-balanced fallback;
- `R61` is still useful as a runtime reference control, but it is no longer the lead baseline;
- `R84` is no longer a viable lead family.

The goal of Phase 10 is:

1. search the remaining live ridge-led neighborhood around `R68` and `R65`;
2. add only mild rhs-side guard descendants where they support the ridge lead;
3. avoid replaying families we now understand to be weak or unstable;
4. keep the run broad enough to explore real alternatives, but disciplined enough to protect compute;
5. require full-6 confirmation and a final rerun before any promotion decision.

## 2) Current Reference State

Phase-9 family ranking:

| family | median_total_fail_n | median_sentinel_fail_n | min_total_fail_n | median_runtime_inflation |
|---|---:|---:|---:|---:|
| `r68_ridge_signal` | `4` | `0` | `2` | `1.1174` |
| `r65_ridge_chain_stepsout` | `4` | `0` | `3` | `0.8785` |
| `r61_stable_anchor` | `4` | `1` | `4` | `0.7117` |
| `r84_rhs_blockpass5` | `5` | `2` | `4` | `0.7982` |

Operational interpretation:

- use exact `R68` as the new scientific lead control;
- use exact `R65` as the balanced ridge fallback control;
- keep exact `R61` as the cheaper runtime reference control;
- retire exact `R84` from lead-candidate consideration.

Residual read:

- the remaining fail surface is now ridge-dominant;
- the most important unresolved roots are still:
  - `dlm_constV_smallW @ tau=0.95 exal ridge`
  - `dlm_ar1V @ tau=0.95 exal rhs_ns`
- the next search should therefore be ridge-led with only mild rhs-guard support.

## 3) What This Wave Will Not Redo

Explicitly out of scope:

- rerunning `R84`-style rhs blockpass-5 descendants as lead ideas;
- reopening bridge-only, QR-only, conditioning-only, or early transformed-sigma families;
- replaying heavy ridge widening (`R67`-style) or other Phase-7/Phase-8 descendants already shown to be weak;
- spending full-6 compute on every broad candidate before targeted screening filters them;
- treating a single Stage-1 ranking as enough evidence for promotion.

## 4) Candidate Program

### Controls

| profile | role | why it is included |
|---|---|---|
| `R200_r68_replicated_anchor` | active scientific lead | best replicated family from Phase 9 |
| `R201_r65_balanced_control` | balanced fallback | best runtime-balanced ridge family |
| `R202_r61_runtime_reference` | runtime reference | cheapest useful control and comparison point |

### `R68` plus mild rhs-guard descendants

Purpose:

- preserve the strongest replicated ridge family;
- test whether a modest rhs guard layer can remove the remaining ar1V / smallW rhs sensitivity without repeating the dead `R84` blockpass family.

Profiles:

| profile | idea |
|---|---|
| `R210_r68_rhs_freeze100_softblock` | modest tau-freeze increase plus softer transformed rhs block |
| `R211_r68_rhs_chain1200_freeze100` | stronger rhs keep-size plus freeze increase on top of `R68` |
| `R212_r68_rhs_chain1100_freeze100_softblock` | midpoint rhs guard variant between `R210` and `R211` |
| `R213_r68_rhs_freeze100_softblock_steps70` | `R210` plus slightly wider ridge step-out support |

### `R68` ridge-local descendants

Purpose:

- explore the immediate ridge neighborhood around the replicated `R68` lead without leaving the successful pass-1 family.

Profiles:

| profile | idea |
|---|---|
| `R220_r68_softsigma_pass1` | lighter ridge local movement with the pass-1 structure preserved |
| `R221_r68_steps70_pass1` | modest ridge step-out expansion around the `R68` pass-1 geometry |
| `R222_r68_pass1_chain1000` | modest ridge chain increase without leaving the `R68` shape |
| `R223_r68_softsigma_steps70_pass1` | combined soft-width plus moderate step-out expansion |

### `R65` balanced descendants

Purpose:

- test whether the balanced `R65` family can be sharpened enough to match `R68` scientifically without giving up its runtime advantage.

Profiles:

| profile | idea |
|---|---|
| `R230_r65_pass1_stepsout` | add one ridge extra pass to the balanced `R65` chain/step-out geometry |
| `R231_r65_softsigma_stepsout` | soften ridge movement while preserving the `R65` chain/step-out structure |
| `R232_r65_rhs_freeze100_stepsout` | mild rhs guard support on top of `R65` |
| `R233_r65_rhs_freeze100_pass1` | strongest balanced hybrid: mild rhs guard plus one ridge extra pass |

Total Stage-1 candidates:

- `15` profiles (`3` controls + `12` new descendants)

## 5) Why These Candidates

This program is intentionally broad, but it is not random.

1. every candidate descends from a Phase-9 surviving family (`R68`, `R65`, or `R61`);
2. every candidate varies only one or two live levers:
   - mild rhs guard;
   - ridge pass count;
   - ridge width softness;
   - ridge step-out budget;
   - moderate ridge keep-size;
3. no candidate reopens dead search space such as `R84`-style blockpass-5 leadership, QR/conditioning families, or heavy widening;
4. the schedule is broad enough to tell us whether the next winner should be:
   - pure `R68` ridge-local,
   - `R68` plus mild rhs guard,
   - or a balanced `R65` descendant.

## 6) Stage Design

### Stage 1: ridge-resolution plus rhs-guard broad screen

Root set:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
4. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
5. `dlm_constV_smallW @ tau=0.95 exal ridge`

Why this set:

- it keeps the remaining ridge problem in scope;
- it keeps the key rhs guard rails in scope;
- it avoids spending early compute on the stable `al` guard rail that has not been decision-changing recently.

Advance rule:

- `top_n = 6`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.25`
- `min_fail_reduction >= 0.40`
- `min_severe_improved_n >= 1`

### Stage 2: full fixed 6-root confirmation

Purpose:

- confirm that Stage-1 survivors generalize to the branch-facing harness.

Advance rule:

- `top_n = 3`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.20`
- `min_fail_reduction >= 0.50`
- `min_severe_improved_n >= 1`

### Stage 3: exact rerun stability confirmation

Purpose:

- rerun the confirmed survivors exactly once more before any promotion decision.

Advance type:

- `report_only`

Interpretation:

- this stage is about decision quality, not filtering again inside the overnight run.

## 7) Resource Plan

Execution plan:

- staged supervisor via the existing phase-3 family screen runner
- Stage 1 on the 5-root targeted screen
- Stage 2 and Stage 3 only on selected survivors
- `campaign_workers = 4`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 180`
- plots off

Why this is efficient:

- the broadest part of the search is on the cheaper 5-root targeted screen;
- the expensive full-6 and rerun stages are reserved for survivors only;
- the program is broad in candidate count, but narrow in live hypothesis space.

## 8) Decision Rules

Primary review files:

1. `stage_execution_status.csv`
2. `S1 .../profile_rank_summary.csv`
3. `S2 .../profile_rank_summary.csv`
4. `S3 .../profile_rank_summary.csv`
5. `S3 .../summary/screen_results.md`

Interpretation rules:

- promotion requires surviving Stage 2 and then looking stable in Stage 3;
- a family lead must be judged by:
  - full-6 fail count,
  - sentinel behavior,
  - runtime discipline,
  - rerun stability;
- no single Stage-1 leader should be promoted without Stage-2 and Stage-3 support.

Practical success target:

- stable `total_fail_n <= 3`
- `sentinel_fail_n = 0`
- no new finite/domain/collapse regressions
- credible runtime behavior

## 9) Morning Review

Open these first:

1. `reports/.../tables/stage_execution_status.csv`
2. `reports/.../stages/S1_.../tables/profile_rank_summary.csv`
3. `reports/.../stages/S2_.../tables/profile_rank_summary.csv`
4. `reports/.../stages/S3_.../tables/profile_rank_summary.csv`
5. `reports/.../summary/family_b_screen_plan.md`

Questions to answer:

1. does the `R68` family still lead once nearby descendants are introduced;
2. do mild rhs guards improve the `R68` family without reintroducing the dead `R84` behavior;
3. can a balanced `R65` descendant match the `R68` family on fail count while preserving better runtime;
4. which survivor is strong enough to become the next active branch-facing candidate.
