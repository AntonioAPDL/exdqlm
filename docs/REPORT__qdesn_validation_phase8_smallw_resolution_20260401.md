# REPORT: QDESN Validation Phase 8 SmallW Resolution Screen (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase8-smallw-resolution-20260401a__git-4852ec8`

## 1) Purpose

Capture the outcome of the first post-Phase-7 program built around the stable `R61/R44` baseline.

This wave asked two questions:

1. can the remaining `smallW @ tau=0.95 exal` fail pair be improved with focused local descendants;
2. do those local wins survive the full fixed 6-root confirmation harness.

## 2) Operational Outcome

Phase 8 was operationally clean end to end.

- `S1_smallw_resolution_screen`: `14/14` profiles complete
- `S2_full_six_confirmation`: `2/2` profiles complete
- `0` timeouts
- `0` runner errors
- completed profiles stayed finite/domain-safe
- no collapse or unhealthy regressions were introduced

This is a scientific negative/partial result set, not an orchestration artifact.

## 3) Stage 1 Outcome

Stage-1 ranking:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R84_r61_rhs_freeze100_blockpass5` | `2` | `0` | `2` | `0.6000` | `0.9946` |
| `R93_r61_r63rhs_r68ridge` | `2` | `0` | `2` | `0.6000` | `1.3723` |
| `R83_r61_rhs_freeze100_softblock` | `2` | `1` | `3` | `0.4000` | `0.9752` |
| `R86_r61_rhs_freeze120_blockpass5` | `2` | `1` | `3` | `0.4000` | `1.0845` |
| `R91_r61_rhssoftblock_ridgepass1` | `2` | `1` | `3` | `0.4000` | `1.1908` |
| `R80_r61_stable_anchor` | `3` | `0` | `3` | `0.4000` | `0.9444` |

Stage-1 read:

- the strongest local signal came from the rhs-side family, not the ridge-side family;
- `R84` was the only profile that cleared the Stage-1 gate;
- `R93` matched the fail count improvement, but was too expensive to treat as a survivor;
- ridge-local descendants did not produce a better local screen result than the rhs block-pass profile.

## 4) Stage 2 Full-6 Confirmation Outcome

Stage-2 ranking:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R80_r61_stable_anchor` | `4` | `1` | `5` | `0.1667` | `0.7436` |
| `R84_r61_rhs_freeze100_blockpass5` | `4` | `2` | `6` | `0.0000` | `0.7849` |

Stage-2 read:

- the Stage-1 winner did not hold up on the full fixed 6-root harness;
- `R84` reintroduced sentinel failures and was worse than the anchor on total fail count;
- the program stopped correctly with `no_candidates_advanced_S2_full_six_confirmation`.

## 5) What Improved

Local improvement that appears to be real:

- rhs-local softening plus one extra transformed-block refresh pass can materially improve the
  narrow `smallW` resolution screen;
- this means the remaining `rhs_ns` residual is still repairable with local controls, at least
  on the reduced target set.

## 6) What Still Fails

The full-6 confirmation result says the current branch-level problem is not solved.

Under the Phase-8 full-6 confirmation:

- the `R61` anchor family itself reran worse than the earlier Phase-7 stability result;
- the `R84` rhs-local winner did not generalize and introduced new sentinel failures;
- no profile in this wave was promotable as a new stable baseline.

## 7) What Worked Best

1. the focused 5-root screening idea was scientifically useful;
2. `R84` identified the strongest local rhs-side lead in the current tuning space;
3. the fixed 6-root confirmation stage prevented a false promotion;
4. the branch still benefits from staged screening with explicit confirmation gates.

## 8) What Clearly Did Not Work

1. promoting a local Stage-1 winner without full-6 confirmation;
2. assuming the exact `R61` full-6 result from Phase 7 would reproduce automatically;
3. treating local rhs-side gains as sufficient evidence for a new branch-facing baseline.

## 9) Main Takeaways

1. Phase 8 did not produce a new baseline.
2. The best local winner (`R84`) was a real 5-root signal, but it failed the full-6 confirmation step.
3. The current branch surface is noisier than Phase 7 alone suggested.
4. The next step should be a family-level replication audit on the full fixed 6-root harness.
5. The next program should compare repeated exact reruns of only the still-plausible families:
   the stable `R61` anchor family, the `R84` rhs-local family, and the best ridge-signal families.

## 10) Recommended Next Move

Run a replication-first overnight audit:

1. exact repeated full-6 reruns of the current `R61` reference baseline;
2. exact repeated full-6 reruns of the best rhs-local lead (`R84`);
3. exact repeated full-6 reruns of the best remaining ridge-signal leads (`R68` and `R65`);
4. rank the results at the family level by median fail count, sentinel stability, and runtime.

That is now the highest-signal, lowest-waste next step.
