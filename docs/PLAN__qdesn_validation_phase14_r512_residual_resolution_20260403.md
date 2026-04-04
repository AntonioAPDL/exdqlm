# PLAN: QDESN Validation Phase 14 R512 Residual Resolution (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Purpose

Run the next overnight QDESN wave as a broader but still disciplined exact full-6 residual-resolution
matrix around the newly promoted `R512` baseline.

The purpose is not to reopen family search. The purpose is to resolve a narrower question:

1. can a close local descendant of `R512` reduce the remaining three-root fail set;
2. can that happen without losing the two rhs repairs and zero-sentinel behavior that made `R512`
   promotable;
3. can any such gain survive rerun and final confirmation strongly enough to replace `R512`.

## 2) Current Reference State

### Phase-13 ordering

| view | profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | read |
|---|---|---:|---:|---:|---:|---|
| promoted baseline | `R512_r412_pass2_chain1000` | `3` | `0` | `3` | `1.106` | new active baseline |
| previous anchor | `R500_r412_provisional_anchor` | `3` | `1` | `4` | `1.060` | previous practical lead |
| clean control | `R402_r65_balanced_control` | `4` | `1` | `5` | `0.975` | cheapest useful clean control |
| local-only winner | `R510_r412_chain1000` | `4` | `1` | `5` | `1.108` | Stage-1 leader, but not stable |

### Residual FAIL set under final `R512`

| root | failure reason | repair intent |
|---|---|---|
| `dlm_constV_bigW @ tau=0.05 exal ridge` | `low_ess; high_autocorrelation; half_chain_drift` | ridge ESS/ACF stabilization |
| `dlm_constV_smallW @ tau=0.95 exal rhs_ns` | `low_ess; high_autocorrelation; geweke_drift; half_chain_drift` | mild rhs stability without reopening the `R421` family |
| `dlm_constV_smallW @ tau=0.95 exal ridge` | `half_chain_drift` | ridge drift stabilization |

### Important retained WARN roots under final `R512`

| root | grade | read |
|---|---|---|
| `dlm_ar1V @ tau=0.95 exal rhs_ns` | `WARN` | repaired relative to `R500`; should not be broken again |
| `dlm_constV_smallW @ tau=0.50 exal rhs_ns` | `WARN` | repaired relative to `R500`; should stay usable |
| `dlm_constV_bigW @ tau=0.95 al rhs_ns` | `WARN` | sentinel should remain stable |

Interpretation:

- the remaining problem is now mostly ridge plus one stubborn rhs root;
- the next search should preserve the two rhs repairs already achieved by `R512`;
- the best next wave is therefore a narrow local search around `R512`, not another `R421` or
  combined-family reopening.

## 3) Cross-Worktree Lesson Applied Here

The concurrent long static-exAL transfer work is again the useful analog:

1. once a new exact winner is promoted, search should narrow around that winner;
2. the previous anchor and the clean control should stay in every stage;
3. dominated families should not be reopened just because the new winner still has residual FAILs.

That maps here to:

- `R512` as the active search anchor;
- `R500` as the previous-anchor control;
- `R402` as the clean control;
- no reopening of `R421`, combined `R412 + R421`, or retired families as main lines.

## 4) What This Wave Will Not Redo

Explicitly out of scope:

- reopening the trimmed `R421` family as a lead search line;
- replaying the combined `R412 + R421` family after its weak rerun performance;
- replaying `R510` as if the Stage-1 local win were stable;
- reopening `R84`, `R422`, bridge-only, QR-only, conditioning-only, or heavy-widening space;
- trusting a reduced root subset as the first promotion gate.

## 5) Candidate Program

### Controls

| profile | role | why it is included |
|---|---|---|
| `R600_r512_promoted_anchor` | scientific reference | current promoted baseline |
| `R601_r500_previous_anchor` | previous-anchor control | preserves direct comparison to the pre-promotion anchor |
| `R602_r402_balanced_control` | clean control | cheapest useful benchmark for sentinel/runtime discipline |

### `R512` ridge-local descendants

Purpose:

- stabilize the two remaining ridge FAIL roots;
- test only small levers that have not yet been exhausted.

| profile | idea |
|---|---|
| `R610_r512_chain1050` | smallest keep-size increase around the promoted baseline |
| `R611_r512_chain1100` | slightly larger keep-size increase around the promoted baseline |
| `R612_r512_burn550_chain1100` | longer chain plus slightly deeper burn-in |
| `R613_r512_pass3_chain1000` | one additional ridge core pass beyond the promoted winner |
| `R614_r512_steps80` | modestly wider ridge step-out budget |
| `R615_r512_steps80_chain1100` | combine modest step-out widening with a small keep-size increase |
| `R616_r512_softgamma_steps80` | slightly softer ridge widths plus the wider step-out budget |

### `R512` mild rhs-local descendants

Purpose:

- target the one remaining hard rhs FAIL root without reopening the weak `R421` family;
- retain the gentlest rhs lessons only.

| profile | idea |
|---|---|
| `R620_r512_rhsfreeze90` | mild increase in tau freeze during burn-in |
| `R621_r512_rhsfreeze100` | slightly stronger freeze, still without reopening trimmed `R421` keep sizes |
| `R622_r512_rhssoft_freeze90` | mild freeze plus slightly softer rhs slice widths |

### Narrow coupled descendants

Purpose:

- test whether the three-root residual set now wants only a light joint ridge/rhs move.

| profile | idea |
|---|---|
| `R630_r512_chain1100_rhsfreeze90` | modest longer-chain ridge variant plus mild rhs freeze |
| `R631_r512_steps80_rhsfreeze90` | modest step-out ridge variant plus mild rhs freeze |

Total Stage-1 candidates:

- `15` profiles (`3` controls + `12` descendants)

## 6) Why These Candidates

This program is broad, but still disciplined.

1. every non-control candidate descends directly from the promoted `R512` baseline;
2. every candidate changes only one still-live local lever or one narrow two-lever combination:
   - modest keep-size increases,
   - one more ridge pass,
   - modest step-out widening,
   - slightly softer ridge widths,
   - mild rhs freeze / adaptation changes;
3. no candidate reopens `R421`, combined `R412 + R421`, retired rhs families, bridge, QR,
   conditioning-only, or heavy-widening space;
4. the program is broad enough to compare:
   - ridge-only stabilization,
   - rhs-only stabilization,
   - very small coupled fixes,
   - controls anchored to the previous winner and clean control;
5. every candidate is evaluated on the exact fixed 6-root harness from Stage 1 onward.

## 7) Stage Design

### Stage 1: exact full-6 residual-resolution matrix

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
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.35`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R600_r512_promoted_anchor`
- `require_not_worse_than_reference = true`

Interpretation:

- Stage 1 is already exact and branch-facing;
- any survivor must at least hold the line against the promoted `R512` anchor;
- sentinel regressions are no longer worth carrying.

### Stage 2: rerun confirmation

Purpose:

- rerun only the strongest exact survivors against the same full-6 harness;
- test whether Stage-1 improvements replicate immediately.

Advance rule:

- `top_n = 4`
- `max_total_fail_n <= 3`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.35`
- `min_fail_reduction >= 0.500`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R600_r512_promoted_anchor`
- `require_better_than_reference = true`

### Stage 3: final residual confirmation

Purpose:

- rerun the confirmation survivors one more time;
- require a true residual-set reduction before any new promotion decision.

Advance rule:

- `top_n = 2`
- `max_total_fail_n <= 2`
- `max_sentinel_fail_n <= 0`
- `max_runtime_inflation <= 1.35`
- `min_fail_reduction >= 0.667`
- `min_severe_improved_n >= 1`
- `reference_profile_id = R600_r512_promoted_anchor`
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

- the candidate count is broad enough to compare every still-live local hypothesis;
- the hypothesis space is now much narrower than the earlier family waves;
- later stages rerun survivors only;
- the wave is optimized for learning value per unit of compute, not family breadth.

## 9) Decision Rules

Primary review files:

1. `tables/stage_execution_status.csv`
2. `stages/S1_.../summary/stage_candidate_selection.md`
3. `stages/S1_.../tables/profile_rank_summary.csv`
4. `stages/S2_.../summary/stage_candidate_selection.md`
5. `stages/S3_.../summary/stage_candidate_selection.md`

Primary decision questions:

1. does any `R512` descendant cut the final fail set from `3` to `2` without losing zero-sentinel
   behavior;
2. if so, is that gain rerun-confirmed and final-confirmed;
3. if not, which local lever is the highest-value next search axis:
   - longer ridge chain,
   - extra ridge pass,
   - modest ridge geometry widening,
   - mild rhs stabilization,
   - or a small coupled move.

## 10) Expected Decision Output

At the end of Phase 14 we should be able to say one of three things clearly:

1. `R512` remains the best validated baseline and no local descendant beat it;
2. a narrow `R512` descendant achieved `2 FAIL / 0 sentinel FAIL` and becomes the new baseline;
3. the `R512` neighborhood is now exhausted enough that the next move should be a different kind of
   redesign rather than another local matrix.
