# REPORT: QDESN Validation Phase 10 Replicated Ridge Resolution (2026-04-02)

Date: 2026-04-02  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase10-ridge-resolution-20260401a__git-227e125`

## 1) Purpose

Capture the outcome of the first ridge-led local search wave that followed the Phase 9
replication audit.

Phase 10 asked one decision-quality question more than a pure tuning question:

1. can a ridge-local or balanced descendant beat the replicated `R68` family strongly enough on a
   focused screen and then hold that advantage on the full branch-facing 6-root harness.

## 2) Operational Outcome

Phase 10 was operationally clean end to end.

- `15/15` Stage-1 profiles completed
- `2/2` Stage-2 profiles completed
- `0` timeouts
- `0` runner errors
- all completed profiles had full root success
- no finite, domain, collapse, or unhealthy regressions were introduced

This is a scientific result set, not an orchestration artifact.

## 3) Stage Outcome

### Stage 1: focused ridge-resolution screen

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R201_r65_balanced_control` | `3` | `0` | `3` | `0.40` | `0.904` | only Stage-1 survivor |
| `R222_r68_pass1_chain1000` | `2` | `1` | `3` | `0.40` | `1.079` | strongest severe improvement, but sentinel fail blocked promotion |
| `R233_r65_rhs_freeze100_pass1` | `3` | `0` | `3` | `0.40` | `1.273` | scientifically interesting, but too costly for the Stage-1 gate |
| `R200_r68_replicated_anchor` | `3` | `1` | `4` | `0.20` | `1.181` | reference control, not a Stage-1 winner |

Read:

- `R201` looked best on the focused 5-root screen because it preserved `0` sentinel FAIL and kept
  runtime below the Stage-1 ceiling;
- `R222` was the strongest ridge-local scientific challenger on severe-fail reduction;
- the focused screen still favored a local `R65` control over the `R68` reference.

### Stage 2: full fixed 6-root confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R200_r68_replicated_anchor` | `3` | `1` | `4` | `0.333` | `1.072` | better full-6 result |
| `R201_r65_balanced_control` | `4` | `1` | `5` | `0.167` | `0.853` | Stage-1 win did not generalize |

Read:

- the Stage-1 `R65` local winner lost to the exact `R68` reference on the real full-6 harness;
- no candidate advanced out of Stage 2;
- Phase 10 therefore did not produce a promotable new baseline.

## 4) What Improved

The most important improvement in Phase 10 was decision quality.

1. the branch now has direct evidence that a focused local screen can mis-rank families relative to
   the branch-facing full-6 harness;
2. the exact `R68` reference family remained stronger than the selected `R65` challenger once both
   were tested on full-6;
3. the `R222` local result showed that ridge-pass plus modest chain increase is still scientifically
   live, but it now needs explicit sentinel protection rather than another blind local sweep.

## 5) What Still Fails

Under the exact full-6 `R68` control rerun (`R200`), the residual FAIL roots were:

1. `dlm_constV_bigW @ tau=0.05 exal ridge`
2. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
3. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
4. `dlm_constV_smallW @ tau=0.95 exal ridge`

Interpretation:

- the branch-facing surface is still ridge-led, but it is not ridge-only;
- the `smallW rhs_ns` roots remain important guard rails;
- the best single `R68` replicate from Phase 9 (`R122`) was still better than this Phase-10 exact
  rerun, so rerun variance remains a real part of the decision surface.

## 6) What Worked Best

1. keeping an exact replicated `R68` control in the wave;
2. forcing the selected local winner through full-6 confirmation instead of promoting it directly;
3. keeping `R65` in the program as a balanced challenger family rather than discarding it entirely;
4. retaining ridge-pass plus modest-chain ideas (`R222`) as live scientific descendants.

## 7) What Clearly Did Not Work

1. trusting the focused 5-root Stage-1 leaderboard as a promotion signal by itself;
2. treating the best local `R65` screen result as if it had already beaten the exact `R68` control;
3. assuming that sentinel-clean local performance would automatically transfer to the full-6 harness;
4. reopening the search space beyond the `R68/R65/R61` neighborhood.

## 8) Cross-Worktree Lesson

The concurrent long-run static-exAL work on
`validation/rerun-after-0.4.0-sync` is now showing the same general operational lesson:

1. keep an exact reference control in every stage;
2. do not promote local winners until they beat the reference on the exact branch-facing harness;
3. use explicit promote sets and staged narrowing to preserve auditability;
4. drop or quarantine pathological lanes rather than letting them block the whole program.

That is the main idea being carried forward into the next QDESN wave.

## 9) Main Takeaways

1. Phase 10 did not promote a new baseline.
2. The exact `R68` family remains the strongest branch-facing reference family.
3. The exact `R65` family remains useful, but its best local result did not transfer to full-6.
4. The next wave should stop using reduced-screen wins as the main promotion gate.
5. The next wave should start on the exact full-6 harness, keep the exact `R68` control present at
   every stage, and rerun survivors before any promotion decision.

## 10) Recommended Next Move

Run an exact full-6 transfer matrix rather than another reduced-screen-first wave:

1. keep exact `R68` as the scientific reference anchor;
2. keep exact `R65` as the balanced challenger control;
3. keep exact `R61` as the runtime reference control;
4. search only close descendants around those three surviving families;
5. require challengers to be not worse than the exact `R68` control before they advance;
6. rerun selected survivors on the same exact full-6 harness before any promotion call.
