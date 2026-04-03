# PLAN: QDESN Validation Phase 12 R312 Stabilization Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight QDESN wave as a broader but still disciplined exact full-6 stabilization
matrix rooted in the best rerun-confirmed Phase-11 scientific lead:

- `R312_r68_pass1_chain950`

The purpose is no longer to ask which family survives replication. Phase 9 already answered that.
The Phase-12 question is narrower and more operationally valuable:

1. can we preserve `R312`'s repaired roots;
2. remove the remaining three-root residual FAIL set;
3. do it without reopening dominated families or trusting one-pass local wins.

## 2) Current Reference State

### Phase-11 rerun confirmation ordering

| view | profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---:|---|
| new provisional scientific lead | `R312_r68_pass1_chain950` | `2` | `1` | `3` | `1.095` | best rerun-confirmed scientific result |
| clean control | `R301_r65_balanced_control` | `4` | `0` | `4` | `0.824` | best sentinel-clean control |
| old exact anchor | `R300_r68_exact_anchor` | `4` | `1` | `5` | `1.105` | now weaker than `R312` |
| Stage-1 local winner that failed to hold | `R323_r65_pass1_stepsout_chain1100` | `4` | `1` | `5` | `1.033` | local-only winner |

### Residual FAIL set under `R312`

| root | failure reason | repair intent |
|---|---|---|
| `dlm_constV_bigW @ tau=0.05 exal ridge` | `geweke_drift; half_chain_drift` | ridge stabilization |
| `dlm_constV_smallW @ tau=0.50 exal rhs_ns` | `geweke_drift` | rhs drift stabilization |
| `dlm_constV_smallW @ tau=0.95 exal rhs_ns` | `low_ess; high_autocorrelation` | rhs ESS / ACF stabilization |

Operational interpretation:

- `R312` should now be the search anchor for scientific improvement;
- `R301` should remain the clean balanced control because it is the best `0`-sentinel reference on
  rerun;
- the next program should search only local `R312` stabilization space plus a very small `R301`
  hedge.

## 3) Cross-Worktree Lesson Applied Here

The concurrent long static-exAL validation work on
`validation/rerun-after-0.4.0-sync` is now following a similar pattern:

1. exact-runner transfer matrices displaced the old tuning winner;
2. the search then narrowed around the new exact-runner lead instead of reopening dominated
   families;
3. rerun-confirmed reference controls remained present in every stage.

That is the exact discipline being applied here:

- `R312` replaces raw `R68` as the active scientific search anchor;
- `R68`, `R65`, and `R61` remain in the program as controls;
- no dead family is reopened just because the current winner is still imperfect.

## 4) What This Wave Will Not Redo

Explicitly out of scope:

- reopening the retired `R84` rhs-local family as a lead idea;
- replaying bridge-only, QR-only, conditioning-only, or heavy-widening families;
- replaying the softblock-heavy `R68` guard descendants that did not hold up in Phase 11;
- trusting a reduced screen as the first promotion gate;
- promoting a candidate from one exact pass with no rerun confirmation.

## 5) Candidate Program

### Controls

| profile | role | why it is included |
|---|---|---|
| `R400_r312_provisional_anchor` | scientific reference | current best rerun-confirmed scientific lead |
| `R401_r68_exact_anchor` | legacy exact reference | preserves direct comparison to the old exact anchor |
| `R402_r65_balanced_control` | clean balanced control | best rerun `0`-sentinel control |
| `R403_r61_runtime_reference` | runtime control | cheapest still-useful family |

### `R312` ridge-local descendants

Purpose:

- preserve the repaired rhs behavior while targeting the `bigW @ tau = 0.05 exal ridge` drift root;
- test only mild ridge levers that remain scientifically plausible.

| profile | idea |
|---|---|
| `R410_r312_steps70` | modest step-out expansion for ridge drift recovery |
| `R411_r312_softsigma` | slightly softer ridge movement to reduce drift |
| `R412_r312_softsigma_steps70` | combine softer ridge movement with modest step-out expansion |
| `R413_r312_chain975` | slight chain increase around the `950` sweet spot without reopening the weaker `1000` result directly |

### `R312` rhs-local descendants

Purpose:

- keep the `R312` ridge gains fixed while specifically targeting the two remaining `rhs_ns` FAIL roots;
- avoid replaying the broad softblock-heavy family that already looked weak.

| profile | idea |
|---|---|
| `R420_r312_rhsfreeze90` | slightly deeper tau freeze to stabilize the `tau = 0.50` drift root |
| `R421_r312_rhsfreeze100_chain1100` | deeper freeze plus moderate rhs keep-size increase for the `tau = 0.95` ESS/ACF root |
| `R422_r312_blockpass5` | one extra transformed rhs block refresh pass without full-family replay |
| `R423_r312_rhsfreeze100_blockpass5` | combined rhs drift and rhs mixing support |

### `R312` combined descendants

Purpose:

- test whether the hardest ridge and rhs residuals now need a small coupled repair rather than a
  single local lever;
- keep the combinations narrow and attributable.

| profile | idea |
|---|---|
| `R430_r312_steps70_rhsfreeze90` | ridge drift support plus mild rhs drift support |
| `R431_r312_steps70_blockpass5` | ridge drift support plus rhs mixing support |

### `R301` hedge

Purpose:

- keep one sentinel-clean balanced hedge in the program in case the `R312` neighborhood proves too
  hard to stabilize cleanly.

| profile | idea |
|---|---|
| `R440_r301_pass1_chain1100` | mild balanced hedge around the clean `R301` control without replaying the weaker `R323` steps-out variant |

Total Stage-1 candidates:

- `15` profiles (`4` controls + `11` descendants)

## 6) Why These Candidates

This program is broad, but it is still disciplined.

1. every non-control candidate descends from the rerun-confirmed `R312` lead or the clean `R301`
   control;
2. every candidate changes only one or two still-live levers:
   - modest ridge step-out expansion,
   - slightly softer ridge movement,
   - very small chain interpolation around `R312`,
   - deeper rhs tau freeze,
   - one extra rhs transformed-block refresh pass;
3. no candidate reopens dead `R84`, softblock-heavy Phase-11 guards, bridge, QR, conditioning, or
   heavy-widening space;
4. the program is broad enough to compare:
   - ridge-only stabilization,
   - rhs-only stabilization,
   - narrow coupled stabilization,
   - one balanced hedge;
5. every candidate is evaluated on the real branch-facing full-6 harness from the first stage.

## 7) Stage Design

### Stage 1: exact full-6 stabilization matrix

Root set:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_bigW @ tau=0.95 al rhs_ns`
4. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
5. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
6. `dlm_constV_smallW @ tau=0.95 exal ridge`

Advance rule:

- `top_n = 6`
- `max_total_fail_n <= 4`
- `max_sentinel_fail_n <= 1`
- `max_runtime_inflation <= 1.25`
- `min_fail_reduction >= 0.333`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R400_r312_provisional_anchor`
- `require_not_worse_than_reference = true`

Interpretation:

- a candidate must at least hold the line against `R312` on the same exact harness before it can
  advance;
- Stage 1 is broad, but it is already exact and branch-facing.

### Stage 2: rerun confirmation

Purpose:

- rerun only the strongest exact survivors against the same full-6 harness;
- test whether exact Stage-1 improvements replicate immediately.

Advance rule:

- `top_n = 4`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 1`
- `max_runtime_inflation <= 1.25`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R400_r312_provisional_anchor`
- `require_better_than_reference = true`

Interpretation:

- a candidate must beat `R312` on rerun to reach the final stage;
- this stage intentionally still allows `1` sentinel FAIL so that we do not discard scientifically
  better candidates before one more strict confirmation pass.

### Stage 3: sentinel confirmation

Purpose:

- force the rerun-confirmed survivors through one more exact pass before any promotion call;
- make `0` sentinel FAIL the final strict requirement.

Advance rule:

- `top_n = 2`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.25`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R400_r312_provisional_anchor`
- `require_better_than_reference = true`

## 8) Resource Plan

Execution plan:

- staged supervisor via the existing family-screen runner
- full-6 harness in every stage
- `campaign_workers = 6`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 240`
- plots off

Why this is still efficient:

- the wave is broader in candidate count, but not in hypothesis space;
- all candidates are exact full-6, so we avoid another overnight cycle on local winners that do not
  transfer;
- Stage 2 and Stage 3 rerun only survivors.

## 9) Decision Rules

Primary review files:

1. `tables/stage_execution_status.csv`
2. `stages/S1_.../summary/stage_candidate_selection.md`
3. `stages/S1_.../tables/profile_rank_summary.csv`
4. `stages/S2_.../tables/profile_rank_summary.csv`
5. `stages/S3_.../tables/profile_rank_summary.csv`

Interpretation rules:

- no candidate should be promoted from Stage 1 alone;
- `R312` is the active scientific reference until a challenger beats it on rerun;
- `R301` remains the main clean control when interpreting sentinel behavior;
- a final candidate should preserve `R312`'s repaired roots while also removing the remaining
  sentinel problem;
- runtime discipline matters, but only after exact rerun behavior is clearly better.

Practical success targets:

- preferred win:
  `2 FAIL / 0 sentinel FAIL` on rerun-confirmed exact full-6;
- acceptable win:
  `3 FAIL / 0 sentinel FAIL` while beating `R312` on rerun;
- minimum useful result:
  a rerun-confirmed exact candidate that preserves `R312`'s gains and isolates the remaining fail
  to a single mechanism.
