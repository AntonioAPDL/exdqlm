# REPORT: QDESN Validation Phase 11 Exact Full-Six Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase11-exact-fullsix-20260402a__git-5b72d20`

## 1) Purpose

Capture the outcome of the first QDESN wave that used the exact full fixed 6-root harness from
Stage 1 onward and then reran survivors before any promotion decision.

Phase 11 was designed to answer a tighter question than Phase 10:

1. can a challenger from the surviving `R68/R65/R61` neighborhood beat the exact `R68` control on
   the real branch-facing harness;
2. if so, does that exact improvement survive an immediate rerun confirmation step.

## 2) Operational Outcome

Phase 11 completed cleanly end to end.

- `14/14` Stage-1 profiles completed
- `6/6` Stage-2 profiles completed
- `0` timeouts
- `0` runner errors
- all completed profiles had full root success
- no finite, domain, collapse, or unhealthy regressions were introduced

This is a scientific result set, not an orchestration artifact.

## 3) Stage Outcome

### Stage 1: exact full-6 matrix

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R323_r65_pass1_stepsout_chain1100` | `2` | `1` | `3` | `0.500` | `1.072` | best local Stage-1 winner |
| `R301_r65_balanced_control` | `3` | `1` | `4` | `0.333` | `0.972` | strongest balanced control |
| `R312_r68_pass1_chain950` | `3` | `1` | `4` | `0.333` | `1.129` | strongest pure `R68` descendant |
| `R302_r61_runtime_reference` | `4` | `0` | `4` | `0.333` | `0.932` | cheapest reference, but not a leading scientific result |

Read:

- Stage 1 again showed that multiple profiles can look viable on one exact pass;
- the strongest local winner was still a `R65` descendant;
- the best `R68` descendant entering rerun confirmation was `R312_r68_pass1_chain950`.

### Stage 2: rerun confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation | read |
|---|---:|---:|---:|---:|---:|---|
| `R312_r68_pass1_chain950` | `2` | `1` | `3` | `0.500` | `1.095` | best rerun result and new active scientific lead |
| `R301_r65_balanced_control` | `4` | `0` | `4` | `0.333` | `0.824` | best clean control, but not the lowest fail count |
| `R300_r68_exact_anchor` | `4` | `1` | `5` | `0.167` | `1.105` | old exact reference, now clearly weaker than `R312` |
| `R323_r65_pass1_stepsout_chain1100` | `4` | `1` | `5` | `0.167` | `1.033` | Stage-1 winner did not hold on rerun |

Read:

- Phase 11 did not produce a promotable new baseline because no Stage-2 profile achieved the
  stricter rerun gate;
- however, `R312_r68_pass1_chain950` clearly outperformed the old exact `R68` anchor on the same
  rerun harness;
- that makes `R312` the new provisional scientific lead for further search, even though it is not
  yet promotion-ready.

## 4) What Improved

The biggest Phase-11 improvement was not only decision quality, but also branch-facing scientific
localization.

1. `R312_r68_pass1_chain950` improved the exact rerun result from the old `R68` anchor’s
   `5 FAIL / 1 sentinel FAIL` to `3 FAIL / 1 sentinel FAIL`.
2. Relative to `R300_r68_exact_anchor`, `R312` repaired two previously failing roots:
   - `dlm_ar1V @ tau=0.95 exal rhs_ns`: `FAIL -> WARN`
   - `dlm_constV_smallW @ tau=0.95 exal ridge`: `FAIL -> WARN`
3. Phase 11 also confirmed that exact full-6 Stage 1 is a better first filter than the older
   reduced-screen-first approach, but rerun confirmation still changes the ordering materially.

## 5) What Still Fails

Under the best rerun-confirmed Phase-11 profile (`R312_r68_pass1_chain950`), the remaining FAIL
set is now narrow and concrete:

| root | grade | failure reason |
|---|---|---|
| `dlm_constV_bigW @ tau=0.05 exal ridge` | `FAIL` | `geweke_drift; half_chain_drift` |
| `dlm_constV_smallW @ tau=0.50 exal rhs_ns` | `FAIL` | `geweke_drift` |
| `dlm_constV_smallW @ tau=0.95 exal rhs_ns` | `FAIL` | `low_ess; high_autocorrelation` |
| `dlm_ar1V @ tau=0.95 exal rhs_ns` | `WARN` | `chain_marginal_but_usable` |
| `dlm_constV_bigW @ tau=0.95 al rhs_ns` | `WARN` | `chain_marginal_but_usable` |
| `dlm_constV_smallW @ tau=0.95 exal ridge` | `WARN` | `chain_marginal_but_usable` |

Interpretation:

- the branch-facing problem is now a three-root residual set, not a diffuse family-wide failure;
- the remaining ridge problem is concentrated on the hard `bigW @ tau = 0.05` drift root;
- the remaining `rhs_ns` problem has split into one drift root (`smallW @ tau = 0.50`) and one
  ESS/ACF root (`smallW @ tau = 0.95`).

## 6) What Worked Best

1. the `R68` family remains the strongest scientific neighborhood;
2. the modest `R312` move, not the more aggressive guarded or local-winning families, produced the
   best rerun-confirmed result;
3. keeping `R301_r65_balanced_control` in the wave was valuable because it stayed the cleanest
   `0`-sentinel control;
4. exact full-6 screening plus rerun confirmation produced a better decision than either a reduced
   screen alone or a single exact pass alone.

## 7) What Clearly Did Not Work

1. treating the Stage-1 local winner (`R323`) as if it were already branch-ready;
2. expecting `R65` local wins to transfer automatically to the exact rerun harness;
3. using heavier guarded `R68` descendants with rhs freeze plus softblock as the main repair line;
4. reopening dead `R84`, bridge-only, QR-only, conditioning-only, or heavy-widening families.

## 8) Cross-Worktree Lesson

The concurrent long static-exAL validation work is now reinforcing the same operational rule:

- the old tuning leader (`C060_110_sub2`) lost its privileged baseline status only after an
  exact-runner transfer matrix and rerun-confirmed neighborhood search;
- the current best transfer lead (`F080_sub2_s100`) was adopted as the next search anchor even
  though it still was not exact-ready;
- the next wave there narrowed around the new lead rather than reopening dominated families.

The direct QDESN translation is:

1. treat `R312` as the new active scientific search anchor because it beat the old exact `R68`
   reference on rerun;
2. do not promote it as a final winner yet;
3. search only the remaining exact neighborhood around `R312`, with `R68/R65/R61` kept as
   reference controls.

## 9) Main Takeaways

1. Phase 11 did not produce a promotable new baseline.
2. Phase 11 did produce a new provisional scientific lead: `R312_r68_pass1_chain950`.
3. `R301_r65_balanced_control` remains the most useful clean control because it preserves
   `0` sentinel FAIL on rerun.
4. The remaining branch-facing fail set is now three roots:
   - `dlm_constV_bigW @ tau=0.05 exal ridge`
   - `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
   - `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
5. The next wave should be an exact full-6 stabilization matrix rooted in `R312`, not another
   reduced or family-reopening search.

## 10) Recommended Next Move

Run a broader but still disciplined exact full-6 stabilization matrix around `R312`:

1. use `R312` as the active scientific search anchor;
2. keep `R68`, `R65`, and `R61` in the wave as reference controls;
3. search only still-live local levers:
   - mild ridge stabilization around the hard `bigW` drift root,
   - mild rhs stabilization without replaying the weak softblock-heavy family,
   - very small balanced `R301` hedges;
4. keep the exact full-6 harness from Stage 1 onward;
5. rerun survivors before any promotion decision;
6. reserve the final strict gate for candidates that both preserve `R312`’s gains and remove the
   remaining sentinel problem.
