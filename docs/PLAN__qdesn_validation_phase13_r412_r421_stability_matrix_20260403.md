# PLAN: QDESN Validation Phase 13 R412-R421 Stability Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight QDESN wave as a broader but still disciplined exact full-6 refinement matrix
around the two most informative Phase-12 signals:

- `R412_r312_softsigma_steps70` as the new provisional practical lead
- `R421_r312_rhsfreeze100_chain1100` as the high-upside rhs-local reference

The purpose is not to reopen family search. The purpose is to resolve a narrower question:

1. can `R412` be stabilized so that its Stage-2 gains survive final confirmation;
2. can the useful part of `R421` be retained without its runtime and sentinel costs;
3. can a narrow combined descendant outperform both lines on the same exact full-6 harness.

## 2) Current Reference State

### Phase-12 ordering

| view | profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---:|---|
| new provisional lead | `R412_r312_softsigma_steps70` | `3` | `0` | `3` | `1.072` | best practical rerun-confirmed result |
| previous anchor | `R400_r312_provisional_anchor` | `3` | `0` | `3` | `1.214` | now weaker practical reference |
| clean control | `R402_r65_balanced_control` | `4` | `0` | `4` | `0.944` | best clean balanced control |
| high-upside rhs signal | `R421_r312_rhsfreeze100_chain1100` | `1` | `1` | `2` | `1.291` | strongest local scientific result |

### Residual FAIL set under Stage-2 `R412`

| root | failure reason | repair intent |
|---|---|---|
| `dlm_ar1V @ tau=0.95 exal rhs_ns` | `low_ess; half_chain_drift` | rhs-side stability and mixing |
| `dlm_constV_bigW @ tau=0.05 exal ridge` | `low_ess; high_autocorrelation; half_chain_drift` | ridge ESS/ACF stabilization |
| `dlm_constV_smallW @ tau=0.95 exal ridge` | `high_autocorrelation; half_chain_drift` | ridge drift stabilization |

### High-upside local Phase-12 `R421` signal

`R421` produced:

- `2 FAIL`
- `1` sentinel FAIL
- runtime inflation `1.291`

Its remaining FAIL roots were:

1. `dlm_constV_bigW @ tau=0.95 al rhs_ns`
2. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`

Interpretation:

- `R421` fixes much of the ridge-heavy residual set, but it breaks one sentinel and remains too
  expensive;
- the best next search is therefore the narrow space between `R412` stability and `R421`
  de-risking.

## 3) Cross-Worktree Lesson Applied Here

The concurrent long static-exAL transfer work is again the useful analog:

1. once a new exact-runner lead emerges, search should narrow around that lead;
2. the previous anchor and the clean control should remain in every stage;
3. high-upside but not-yet-ready candidates should be retained as references, not promoted.

That maps here to:

- `R412` as the active search anchor;
- `R400` as the previous-anchor control;
- `R402` as the clean control;
- `R421` as the high-upside rhs reference.

## 4) What This Wave Will Not Redo

Explicitly out of scope:

- reopening the retired `R84` rhs-local family;
- replaying the blockpass-led `R422` line as a lead family;
- replaying softblock-heavy guarded descendants from earlier phases;
- reopening bridge-only, QR-only, conditioning-only, or heavy-widening families;
- trusting a reduced screen as the first promotion gate.

## 5) Candidate Program

### Controls

| profile | role | why it is included |
|---|---|---|
| `R500_r412_provisional_anchor` | scientific reference | best practical rerun-confirmed local lead |
| `R501_r400_previous_anchor` | previous-anchor control | preserves direct comparison to the prior `R312` anchor |
| `R502_r402_balanced_control` | clean balanced control | best clean control from Phase 12 |
| `R503_r421_upside_reference` | rhs-upside control | preserves the strongest Phase-12 local scientific result |

### `R412` stability descendants

Purpose:

- preserve the Stage-2 `R412` gains;
- improve ESS/ACF/drift stability on the three remaining residual roots;
- test only small levers that have not yet been exhausted.

| profile | idea |
|---|---|
| `R510_r412_chain1000` | slightly longer chain around the winning `R412` recipe |
| `R511_r412_pass2` | one extra ridge core pass around the winning `R412` recipe |
| `R512_r412_pass2_chain1000` | combine extra pass with a small keep-size increase |
| `R513_r412_burn550_chain1000` | slightly deeper burn-in plus small keep-size increase |

### `R421` trimmed descendants

Purpose:

- keep the very strong `R421` local signal alive;
- trim runtime and sentinel risk without reopening its whole neighborhood.

| profile | idea |
|---|---|
| `R520_r421_chain1000_trim` | reduce rhs keep-size from the high-upside `R421` local winner |
| `R521_r421_chain1050_trim` | intermediate trimmed rhs keep-size between the local winner and the anchor |

### `R412 + R421` combined descendants

Purpose:

- pair the best Phase-12 ridge-local recipe with the most promising rhs-local recipe;
- test whether the remaining blocker now wants a narrow coupled repair.

| profile | idea |
|---|---|
| `R530_r412_ridge_r421_rhs_chain1000` | `R412` ridge recipe plus trimmed `R421` rhs recipe |
| `R531_r412_ridge_r421_rhs_chain1050` | slightly larger rhs keep-size under the same combined recipe |
| `R532_r412_pass2_r421_rhs_chain1000` | add one extra ridge pass to the combined recipe |

### `R402` hedges

Purpose:

- retain one clean hedge that may inherit the `R412` ridge improvement without its instability.

| profile | idea |
|---|---|
| `R540_r402_softsigma_steps70` | apply the `R412` ridge recipe to the clean `R402` control |
| `R541_r402_softsigma_steps70_rhsfreeze90` | add only mild rhs support to that clean hedge |

Total Stage-1 candidates:

- `15` profiles (`4` controls + `11` descendants)

## 6) Why These Candidates

This program is broad, but still disciplined.

1. every non-control candidate descends from the best practical Phase-12 lead (`R412`), the
   strongest local rhs signal (`R421`), or the clean control (`R402`);
2. every candidate changes only one or two still-live levers:
   - modest keep-size increases,
   - one extra ridge core pass,
   - slightly deeper burn-in,
   - trimmed rhs keep-size,
   - narrow `R412 + R421` combinations;
3. no candidate reopens blockpass-led, softblock-heavy, retired rhs, bridge, QR, conditioning-only,
   or heavy-widening space;
4. the program is broad enough to compare:
   - `R412` stability-only fixes,
   - trimmed `R421` fixes,
   - narrow combined fixes,
   - one clean `R402` hedge;
5. every candidate is evaluated on the exact fixed 6-root harness from the first stage onward.

## 7) Stage Design

### Stage 1: exact full-6 refinement matrix

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
- `max_runtime_inflation <= 1.35`
- `min_fail_reduction >= 0.333`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R500_r412_provisional_anchor`
- `require_not_worse_than_reference = true`

Interpretation:

- a candidate must at least hold the line against the new `R412` anchor;
- Stage 1 is broad, but it is already exact and branch-facing.

### Stage 2: rerun confirmation

Purpose:

- rerun only the strongest exact survivors against the same full-6 harness;
- test whether Stage-1 improvements replicate immediately.

Advance rule:

- `top_n = 4`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 1`
- `max_runtime_inflation <= 1.30`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R500_r412_provisional_anchor`
- `require_better_than_reference = true`

### Stage 3: final sentinel confirmation

Purpose:

- rerun the confirmation survivors one more time;
- keep the final strict `0`-sentinel requirement before any promotion decision.

Advance rule:

- `top_n = 2`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.30`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R500_r412_provisional_anchor`
- `require_better_than_reference = true`

## 8) Resource Plan

Execution plan:

- staged supervisor via the existing family-screen runner
- exact full-6 harness in every stage
- `campaign_workers = 6`
- `threads_per_worker = 1`
- `profile_timeout_minutes = 240`
- plots off

Why this is still efficient:

- the candidate count is broad enough to compare all still-live hypotheses;
- the hypothesis space remains narrow and well justified;
- later stages rerun survivors only.

## 9) Decision Rules

Primary review files:

1. `tables/stage_execution_status.csv`
2. `stages/S1_.../summary/stage_candidate_selection.md`
3. `stages/S1_.../tables/profile_rank_summary.csv`
4. `stages/S2_.../tables/profile_rank_summary.csv`
5. `stages/S3_.../tables/profile_rank_summary.csv`

Interpretation rules:

- `R412` is the active search anchor until a challenger beats it on rerun;
- `R402` remains the clean control when interpreting sentinel behavior;
- `R421` should be treated as a high-upside reference, not as an auto-promotable result;
- no candidate should be promoted from Stage 1 alone;
- the next winner should preserve `R412`'s good Stage-2 behavior and also survive final sentinel
  confirmation.

Practical success targets:

- preferred win:
  `2 FAIL / 0 sentinel FAIL` on rerun-confirmed exact full-6;
- acceptable win:
  `3 FAIL / 0 sentinel FAIL` while beating `R412` on rerun;
- minimum useful result:
  a rerun-confirmed exact candidate that materially de-risks `R412` final-stage instability or
  trims `R421` into a practical exact survivor.
