# REPORT: QDESN Validation Phase 13 R412-R421 Stability Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase13-r412-r421-stability-20260403a__git-373aa5f`

## 1) Purpose

Capture the outcome of the first QDESN wave that started from the practical `R412` lead, carried
the high-upside `R421` rhs signal as a reference, and then required both rerun confirmation and a
final zero-sentinel confirmation before promotion.

Phase 13 was designed to answer a tighter question than Phase 12:

1. can the `R412` lead be stabilized enough to survive rerun and final confirmation;
2. can the useful part of the `R421` rhs-local signal be retained without reopening a weak family;
3. if a winner emerges, is it strong enough to replace `R412` as the branch-facing baseline.

## 2) Operational Outcome

Phase 13 completed cleanly end to end.

- `15/15` Stage-1 profiles completed
- `7/7` Stage-2 reruns completed
- `2/2` Stage-3 confirmations completed
- `0` timeouts
- `0` runner errors
- all completed profiles had full root success
- no finite, domain, collapse, or unhealthy regressions were introduced

This is a scientific result set, not an orchestration artifact.

## 3) Stage Outcome

### Stage 1: exact full-6 refinement matrix

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R510_r412_chain1000` | `2` | `0` | `2` | `0.667` | `1.046` | strongest local Stage-1 winner |
| `R502_r402_balanced_control` | `2` | `1` | `3` | `0.500` | `0.846` | best runtime-balanced control |
| `R521_r421_chain1050_trim` | `2` | `1` | `3` | `0.500` | `1.278` | best trimmed `R421` result |
| `R512_r412_pass2_chain1000` | `3` | `0` | `3` | `0.500` | `1.145` | best alternate `R412` result |
| `R500_r412_provisional_anchor` | `4` | `1` | `5` | `0.167` | `1.101` | weak opening anchor |

Read:

- Stage 1 again showed that one exact pass is useful but not decisive;
- the strongest local winner was `R510`, not the final promoted winner;
- the `R412` family still dominated the field overall;
- trimmed `R421` descendants improved on the raw `R421` reference, but were not convincing enough
  to beat the best `R412` line.

### Stage 2: rerun confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R512_r412_pass2_chain1000` | `3` | `0` | `3` | `0.500` | `1.076` | rerun winner and only advancing survivor |
| `R500_r412_provisional_anchor` | `4` | `0` | `4` | `0.333` | `1.094` | stable reference, but weaker |
| `R540_r402_softsigma_steps70` | `4` | `1` | `5` | `0.167` | `0.835` | cheaper, but not scientifically competitive |
| `R502_r402_balanced_control` | `4` | `1` | `5` | `0.167` | `0.975` | clean benchmark, not a lead |
| `R513_r412_burn550_chain1000` | `4` | `1` | `5` | `0.167` | `1.068` | deeper burn did not help |
| `R510_r412_chain1000` | `4` | `1` | `5` | `0.167` | `1.108` | Stage-1 winner did not hold up |
| `R521_r421_chain1050_trim` | `4` | `2` | `6` | `0.000` | `1.259` | trimmed `R421` did not survive rerun |

Read:

- rerun confirmation materially changed the ordering;
- `R510` was the strongest one-pass local winner, but not a stable winner;
- `R512` was the only candidate that beat the `R500` anchor cleanly enough to advance;
- the `R421` line and the `R412 + R421` combined line should no longer be treated as lead
  families.

### Stage 3: final sentinel confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R512_r412_pass2_chain1000` | `3` | `0` | `3` | `0.500` | `1.106` | final promoted winner |
| `R500_r412_provisional_anchor` | `3` | `1` | `4` | `0.333` | `1.060` | previous anchor lost final comparison |

Read:

- `R512` survived the final zero-sentinel confirmation step;
- `R500` remained scientifically respectable, but it no longer holds the baseline because it
  reintroduced a sentinel FAIL and preserved an extra total FAIL;
- Phase 13 therefore produced a promotable new baseline.

## 4) What Improved

Phase 13 produced the most important branch-facing improvement since the exact full-6 rerun program
began:

1. `R512_r412_pass2_chain1000` became the new promoted baseline.
2. Relative to the final `R500` anchor confirmation, `R512` repaired:
   - `dlm_ar1V @ tau=0.95 exal rhs_ns`: `FAIL -> WARN`
   - `dlm_constV_smallW @ tau=0.50 exal rhs_ns`: `FAIL -> WARN`
3. `R512` also removed the anchor's final sentinel FAIL entirely:
   - `sentinel_fail_n`: `1 -> 0`
4. Phase 13 again improved decision quality by forcing the local winner to survive rerun and final
   confirmation before promotion.

## 5) What Still Fails

Under the final promoted `R512_r412_pass2_chain1000` result, the remaining FAIL set is now:

| root | grade | failure reason |
|---|---|---|
| `dlm_constV_bigW @ tau=0.05 exal ridge` | `FAIL` | `low_ess; high_autocorrelation; half_chain_drift` |
| `dlm_constV_smallW @ tau=0.95 exal rhs_ns` | `FAIL` | `low_ess; high_autocorrelation; geweke_drift; half_chain_drift` |
| `dlm_constV_smallW @ tau=0.95 exal ridge` | `FAIL` | `half_chain_drift` |

Important nuance:

- `R512` preserved two rhs repairs, but it did not close the hard `bigW ridge` root;
- `R512` also regressed `dlm_constV_smallW @ tau=0.95 exal ridge` from `WARN` under the final
  anchor to `FAIL` under the promoted winner;
- the residual problem is now a very small mixed ridge/rhs cluster, not a broad family-wide
  failure.

## 6) What Worked Best

1. the `R412` neighborhood remained the strongest scientific family;
2. `R512` showed that one extra ridge core pass plus a small keep-size increase is a real stable
   improvement, not just a one-pass win;
3. the clean `R402` control remained useful for benchmarking runtime and sentinel discipline;
4. rerun plus final zero-sentinel confirmation again materially improved decision quality.

## 7) What Clearly Did Not Work

1. treating `R510` as if the Stage-1 local win was already branch-ready;
2. reopening trimmed `R421` descendants as if they were likely promotion-ready;
3. using narrow `R412 + R421` combined descendants as a main repair line;
4. assuming deeper burn-in alone (`R513`) would fix the residual cluster;
5. reopening retired `R84`, `R422`, QR-only, conditioning-only, bridge-only, or heavy-widening
   families.

## 8) Cross-Worktree Lesson

The long static-exAL transfer work is again reinforcing the same operational rule:

1. once a new exact winner is promoted, narrow the next search around that winner;
2. keep the previous anchor and the clean control alive as references;
3. do not reopen dominated families after a promoted exact result exists.

The direct QDESN translation is:

- `R512` should now replace `R412` as the active scientific and practical baseline;
- `R500` should remain the previous-anchor reference control;
- `R402` should remain the clean balanced control;
- the next wave should search only the narrow local neighborhood around `R512`.

## 9) Main Takeaways

1. Phase 13 produced a promotable new baseline: `R512_r412_pass2_chain1000`.
2. The Stage-1 local winner (`R510`) did not replicate and should not be treated as a live lead.
3. The `R421` line and the narrow `R412 + R421` combined line should now be retired as main search
   families.
4. The remaining branch-facing problem is now only three roots wide:
   - `dlm_constV_bigW @ tau=0.05 exal ridge`
   - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
   - `dlm_constV_smallW @ tau=0.95 exal ridge`
5. The next wave should be an exact full-6 residual-resolution matrix rooted in `R512`, not
   another family-reopening or reduced-screen-first search.

## 10) Recommended Next Move

Run a broader but still disciplined exact full-6 residual-resolution matrix around `R512`:

1. use `R512` as the active search anchor;
2. keep `R500` as the previous-anchor control;
3. keep `R402` as the clean balanced control;
4. search only:
   - narrow ridge-local descendants of `R512`,
   - mild rhs-local descendants of `R512`,
   - very small coupled descendants that combine the strongest ridge and mild rhs changes;
5. keep the exact full-6 harness from Stage 1 onward;
6. rerun survivors before any new promotion call;
7. require a real residual-set reduction before any new baseline is promoted again.
