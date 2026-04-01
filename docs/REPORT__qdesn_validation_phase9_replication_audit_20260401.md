# REPORT: QDESN Validation Phase 9 Family Replication Audit (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase9-replication-audit-20260401a__git-e31ec94`

## 1) Purpose

Capture the outcome of the replication-first full-6 audit that followed Phase 8.

This wave asked one branch-critical question:

1. which of the still-plausible recipe families is actually stable enough, on repeated full-6 reruns, to anchor the next local search wave.

The replicated families were:

- exact `R61` reference family;
- exact `R84` rhs-local winner family;
- exact `R68` ridge-signal family;
- exact `R65` ridge-chain family.

## 2) Operational Outcome

Phase 9 was operationally clean end to end.

- `12/12` profiles completed
- `0` timeouts
- `0` runner errors
- all completed profiles had `6/6` root success
- completed profiles stayed finite/domain-safe
- no collapse or unhealthy regressions were introduced

This is a scientific result set, not an orchestration artifact.

## 3) Family-Level Outcome

Replicated family ranking:

| family | median_total_fail_n | min_total_fail_n | max_total_fail_n | median_sentinel_fail_n | zero_sentinel_runs_n | median_runtime_inflation |
|---|---:|---:|---:|---:|---:|---:|
| `r68_ridge_signal` | `4` | `2` | `4` | `0` | `2/3` | `1.1174` |
| `r65_ridge_chain_stepsout` | `4` | `3` | `5` | `0` | `2/3` | `0.8785` |
| `r61_stable_anchor` | `4` | `4` | `5` | `1` | `0/3` | `0.7117` |
| `r84_rhs_blockpass5` | `5` | `4` | `6` | `2` | `0/3` | `0.7982` |

Family-level read:

- `r68` finished as the strongest scientific family because it was the only family to produce a
  replicated `2 FAIL / 0 sentinel FAIL` result and it preserved zero-sentinel behavior in `2/3` reruns;
- `r65` finished as the strongest runtime-balanced ridge fallback because it matched the median fail
  count of `r68` with materially lower runtime inflation;
- `r61` is no longer a clean lead baseline because its replicated median sentinel fail count is `1`;
- `r84` is now a retired lead family because it degraded badly under replication.

## 4) Best Individual Replicates

| profile | family | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---|---:|---:|---:|---:|---:|
| `R122_r68_rep3` | `r68_ridge_signal` | `2` | `0` | `2` | `0.6667` | `1.1113` |
| `R131_r65_rep2` | `r65_ridge_chain_stepsout` | `3` | `0` | `3` | `0.5000` | `0.8785` |
| `R102_r61_rep3` | `r61_stable_anchor` | `3` | `1` | `4` | `0.3333` | `0.7117` |
| `R111_r84_rep2` | `r84_rhs_blockpass5` | `2` | `2` | `4` | `0.3333` | `0.8617` |

Read:

- `R122` is the best single result in the whole audit;
- `R131` is the best balanced ridge-chain result and the best sub-`0.90` runtime profile in the winning neighborhood;
- `R61` still has value as a runtime reference control, but not as a lead scientific anchor;
- the best `R84` replicate still had unacceptable sentinel behavior.

## 5) What Improved

The biggest improvement in Phase 9 was decision quality.

1. the branch now has a real family-level ordering rather than a pile of single-run impressions;
2. the ridge-led direction clearly beat the rhs-led `R84` family under replication;
3. the exact `R68` family produced the best replicated full-6 result observed so far:
   `2 FAIL / 0 sentinel FAIL`;
4. the exact `R65` family confirmed that a lower-cost ridge-led path is still viable.

Root-level improvements under the best `R68` replicate (`R122`):

- `dlm_constV_bigW @ tau=0.05 exal ridge`: `FAIL -> WARN`
- `dlm_constV_smallW @ tau=0.95 exal rhs_ns`: `FAIL -> WARN`
- `dlm_constV_smallW @ tau=0.50 exal rhs_ns`: `FAIL -> WARN`
- `dlm_constV_bigW @ tau=0.95 al rhs_ns`: `FAIL -> WARN`

## 6) What Still Fails

The remaining surface is now narrower and more ridge-dominant than before.

Under the best replicate `R122_r68_rep3`, the residual `FAIL` roots are:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_smallW @ tau=0.95 exal ridge`

Interpretation:

- the smallW ridge root is still the most persistent branch-facing ridge problem;
- the residual rhs-side risk is now mostly a guard-rail stability issue rather than a broad rhs-family failure mode;
- the current next wave should therefore stay ridge-led, with only mild rhs guard descendants layered on top.

## 7) What Worked Best

1. exact `R68`-style ridge pass plus transformed sigma remains the strongest scientific recipe family;
2. exact `R65`-style ridge chain plus step-out remains the strongest balanced fallback;
3. family-level replication was worth the compute because it changed the ordering materially;
4. full-6 evidence is now clearly more trustworthy than local narrow-screen wins by themselves.

## 8) What Clearly Did Not Work

1. treating `R61` as a settled baseline without replication;
2. carrying `R84` forward as a lead family after its Phase-8 local win;
3. reopening broad rhs-led local search before ridge-led family replication finished;
4. choosing the next direction from a single profile instance.

## 9) Main Takeaways

1. Phase 9 did not produce a Gate-B winner, but it did resolve the family ordering.
2. `R68` is now the active scientific lead family.
3. `R65` is now the best runtime-balanced fallback family.
4. `R61` should be kept as a runtime reference control, not as the lead search baseline.
5. `R84` should be retired as a lead candidate family.
6. The next overnight wave should be ridge-led and should search around the replicated `R68/R65`
   neighborhood while protecting the rhs guard rails.

## 10) Recommended Next Move

Run a staged replicated-ridge resolution program:

1. use exact `R68` as the search anchor;
2. keep exact `R65` as the balanced fallback control;
3. keep exact `R61` as the runtime reference control;
4. explore only:
   - `R68` ridge-local descendants,
   - `R68` plus mild rhs-guard descendants,
   - `R65` balanced descendants;
5. filter candidates on a targeted 5-root ridge-resolution plus rhs-guard screen;
6. confirm survivors on the full fixed 6-root harness;
7. rerun the best confirmation survivors exactly once more before any promotion decision.
