# REPORT: QDESN Validation Phase 12 R312 Stabilization Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase12-r312-stabilization-20260403a__git-1af9e79`

## 1) Purpose

Capture the outcome of the first broader exact full-6 stabilization wave rooted in the provisional
`R312` lead from Phase 11.

Phase 12 asked a more targeted question than Phase 11:

1. can a close descendant of `R312` preserve its repaired roots;
2. can a nearby rhs-local alternative improve the residual fail set further;
3. can any of those gains survive rerun and final sentinel confirmation strongly enough for
   promotion.

## 2) Operational Outcome

Phase 12 completed cleanly end to end.

- `15/15` Stage-1 profiles completed
- `2/2` Stage-2 reruns completed
- `1/1` Stage-3 confirmations completed
- `0` timeouts
- `0` runner errors
- all completed profiles had full root success
- no finite, domain, collapse, or unhealthy regressions were introduced

This is a scientific result set, not an orchestration artifact.

## 3) Stage Outcome

### Stage 1: exact full-6 stabilization matrix

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R421_r312_rhsfreeze100_chain1100` | `1` | `1` | `2` | `0.667` | `1.291` | strongest local improver, but too costly for the gate |
| `R412_r312_softsigma_steps70` | `3` | `0` | `3` | `0.500` | `1.094` | best practical Stage-1 survivor |
| `R422_r312_blockpass5` | `3` | `0` | `3` | `0.500` | `1.134` | rhs-only Stage-1 survivor |
| `R402_r65_balanced_control` | `4` | `0` | `4` | `0.333` | `0.944` | best clean control |
| `R400_r312_provisional_anchor` | `4` | `0` | `4` | `0.333` | `1.195` | current anchor |

Read:

- the wave found two real local winners:
  - `R412` as the best balanced practical survivor,
  - `R421` as the highest-upside rhs-local signal;
- `R421` was the strongest raw scientific result in Stage 1, but runtime blocked it;
- `R412` was the best practical survivor because it matched strong fail reduction with `0`
  sentinel FAIL.

### Stage 2: rerun confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R412_r312_softsigma_steps70` | `3` | `0` | `3` | `0.500` | `1.072` | best rerun-confirmed practical result |
| `R400_r312_provisional_anchor` | `3` | `0` | `3` | `0.500` | `1.214` | previous `R312` anchor reran weaker on runtime |
| `R422_r312_blockpass5` | `3` | `1` | `4` | `0.333` | `1.090` | did not hold up cleanly |

Read:

- `R412` held up on rerun and beat the prior `R312` anchor on practical terms;
- `R422` did not hold up well enough to remain a lead idea;
- Phase 12 therefore produced a new provisional search anchor (`R412`), but still not a promoted
  winner.

### Stage 3: final sentinel confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R400_r312_provisional_anchor` | `3` | `1` | `4` | `0.333` | `1.195` | previous anchor remained noisy but better than the candidate |
| `R412_r312_softsigma_steps70` | `4` | `1` | `5` | `0.167` | `1.094` | final confirmation failed |

Read:

- `R412` did not survive final confirmation strongly enough for promotion;
- the final strict `0`-sentinel target remains unmet;
- Phase 12 therefore did not produce a promotable new baseline.

## 4) What Improved

Phase 12 produced two important scientific improvements.

1. `R412_r312_softsigma_steps70` became the new best practical rerun-confirmed local lead.
2. `R421_r312_rhsfreeze100_chain1100` showed that the rhs-local upside is real and much stronger
   than the weaker blockpass-led family.

Most important rerun improvement under `R412`:

- relative to `R400_r312_provisional_anchor`, Stage-2 `R412` repaired
  `dlm_constV_smallW @ tau=0.95 exal rhs_ns` from `FAIL` to `WARN`.

That came at a cost:

- `R412` worsened `dlm_constV_smallW @ tau=0.95 exal ridge` from `WARN` to `FAIL`,
  so the fail count stayed at `3` rather than dropping.

Phase 12 therefore improved the shape of the residual fail set, but did not fully close it.

## 5) What Still Fails

Under the best practical rerun-confirmed profile (`R412` in Stage 2), the remaining FAIL set was:

| root | grade | failure reason |
|---|---|---|
| `dlm_ar1V @ tau=0.95 exal rhs_ns` | `FAIL` | `low_ess; half_chain_drift` |
| `dlm_constV_bigW @ tau=0.05 exal ridge` | `FAIL` | `low_ess; high_autocorrelation; half_chain_drift` |
| `dlm_constV_smallW @ tau=0.95 exal ridge` | `FAIL` | `high_autocorrelation; half_chain_drift` |

Interpretation:

- the best practical residual set is now ridge-heavy plus one rhs `ar1V` root;
- the two `smallW rhs_ns` roots that drove earlier waves are no longer the main blocker under the
  best Phase-12 candidate;
- the next wave should therefore focus on:
  - stabilizing the `R412` ridge repairs,
  - preserving the solved `smallW rhs_ns` behavior,
  - and importing only the useful part of the `R421` rhs-local signal.

## 6) What Worked Best

1. `R412_r312_softsigma_steps70` was the strongest practical/rerun-confirmed candidate;
2. `R421_r312_rhsfreeze100_chain1100` was the strongest high-upside local signal;
3. keeping `R402_r65_balanced_control` as the clean control remained valuable;
4. exact full-6 from Stage 1 plus rerun plus final sentinel confirmation again improved decision
   quality relative to a simpler ladder.

## 7) What Clearly Did Not Work

1. treating `R421` as immediately promotable despite its runtime and sentinel cost;
2. keeping `R422` or blockpass-led descendants as a main line after rerun;
3. trusting the best local Stage-1 result without rerun and final confirmation;
4. reopening retired `R84`, softblock-heavy, QR, conditioning-only, bridge-only, or heavy-widening
   families.

## 8) Cross-Worktree Lesson

The concurrent static-exAL long-run work is reinforcing the same promotion rule:

1. once a new exact-runner lead appears, narrow around it rather than reopening dominated families;
2. keep the prior anchor and the clean control in the wave;
3. require repeated exact-runner confirmation before treating the new lead as promotion-ready.

The direct QDESN translation is:

- `R412` should now replace `R312` as the active scientific search anchor;
- `R421` should be retained as the high-upside rhs reference neighborhood;
- `R402` should remain the clean control;
- the next wave should search only the narrow space between `R412` stability and `R421`
  de-risking.

## 9) Main Takeaways

1. Phase 12 did not produce a promotable new baseline.
2. Phase 12 did produce a new provisional scientific lead: `R412_r312_softsigma_steps70`.
3. `R421_r312_rhsfreeze100_chain1100` is the most informative high-upside rhs-local signal from the
   wave.
4. `R422_r312_blockpass5` should not be carried forward as a lead family.
5. The current residual branch-facing problem is now:
   - one rhs `ar1V` stability root,
   - two ridge ESS/ACF/drift roots,
   - and a final confirmation instability problem.

## 10) Recommended Next Move

Run a narrower but still broad exact full-6 refinement matrix around the new `R412` lead:

1. use `R412` as the new provisional search anchor;
2. keep `R400` as the previous-anchor control;
3. keep `R402` as the clean balanced control;
4. keep `R421` as the high-upside rhs reference;
5. search only:
   - `R412` stability descendants,
   - trimmed `R421` descendants,
   - narrow `R412 + R421` combined descendants,
   - one small `R402` hedge;
6. avoid replaying blockpass-led or retired families;
7. keep exact full-6 from Stage 1 and rerun survivors before any new promotion call.
