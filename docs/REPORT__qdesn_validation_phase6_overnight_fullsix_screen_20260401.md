# REPORT: QDESN Validation Phase 6 Overnight Full-6 Screen (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase6-overnight-fullsix-20260331a__git-fc1f331`

## 1) Purpose

Capture the outcome of the first broad overnight screen built entirely around `R31` descendants.

This wave asked one concrete question:

- can we remove the final `FAIL` rows on the fixed 6-root harness by pushing the remaining rhs and ridge
  tuning space around `R31_r18_rhsns_pass2`, without reopening dead family branches?

## 2) Operational Outcome

The run was operationally healthy.

- `12/12` profiles completed;
- `0` timeouts;
- `0` runner errors;
- all profiles had `6/6` successful roots;
- no finite/domain/collapse/unhealthy regressions;
- stage gating stopped correctly at the end of the requested scope.

This is a real scientific result set, not an orchestration artifact.

## 3) Main Ranking Outcome

Stage result:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R51_r31_rhssoft_ridgepass1_chain1200` | `2` | `2` | `4` | `0.3333` | `1.5507` |
| `R44_r31_ridge_chain900_stepsout` | `3` | `0` | `3` | `0.5000` | `0.7060` |
| `R45_r31_ridge_chain1200_softsigma` | `3` | `1` | `4` | `0.3333` | `0.9064` |
| `R47_r31_ridge_pass1_chain1200_softsigma` | `3` | `1` | `4` | `0.3333` | `1.0327` |

The nominal rank-1 profile was `R51`, but that is not the right practical carry-forward.

## 4) What Actually Worked Best

### Practical winner: `R44_r31_ridge_chain900_stepsout`

Why `R44` matters:

- it reduced the full fixed 6-root harness from `4 FAIL -> 3 FAIL` on the Phase 6 rerun baseline;
- it kept `sentinel_fail_n = 0`;
- it had much lower runtime than the heavier combined families;
- it confirmed that the strongest current carry-forward direction is ridge-centered, not rhs-centered.

The practical read is:

- moderate ridge chain extension plus wider step-out budgets is the best working family right now.

### Stress signal: `R51_r31_rhssoft_ridgepass1_chain1200`

Why `R51` still matters:

- it reduced the severe quartet more than any other candidate;
- it showed that the ridge pair can be pushed farther toward `WARN`;
- but it did so by reintroducing `2` sentinel FAILs and driving runtime much higher.

So `R51` is a useful scientific clue, not the next operational baseline.

## 5) Exact Remaining Fail Set Under `R44`

Current `R44` fail roots:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_smallW @ tau=0.95 exal ridge`

### `ar1V exal rhs_ns`

Current fail reason:

- `geweke_drift; half_chain_drift`

Key metrics:

- `ESS = 14.28`
- `ACF1 = 0.9718`
- `Geweke = 3.2331`
- `half_drift = 0.5567`

Read:

- this root is close to `WARN`;
- it now looks like a mild rhs drift/geweke stabilization problem, not a broad rhs pathology.

### `constV_bigW exal ridge`

Current fail reason:

- `low_ess; high_autocorrelation; half_chain_drift`

Key metrics:

- `ESS = 7.90`
- `ACF1 = 0.9826`
- `Geweke = 1.5390`
- `half_drift = 0.6298`

Read:

- Geweke is already fine;
- this root now looks like an ESS + drift ridge-core problem.

### `constV_smallW exal ridge`

Current fail reason:

- `low_ess; high_autocorrelation; half_chain_drift`

Key metrics:

- `ESS = 5.90`
- `ACF1 = 0.9870`
- `Geweke = 2.0838`
- `half_drift = 0.5042`

Read:

- this root is extremely close to `WARN` on half-drift;
- the main remaining problem is still ESS plus ACF.

## 6) What Phase 6 Clarified

1. The best next baseline is no longer `R31`; it is `R44`.
2. Ridge-focused refinement is currently the highest-value tuning direction.
3. Aggressive combined tuning can improve the severe quartet, but it is currently too unstable on sentinels.
4. Mild rhs-only stabilization was not enough by itself.
5. The current blocker set is now mechanically cleaner:
   - one near-threshold rhs drift root;
   - two ridge ESS + drift roots.

## 7) Important Caution: Stability

The exact `R31` carry-forward baseline did not reproduce perfectly across waves.

Phase 5 full-6 result:

- `R31`: `3 FAIL`

Phase 6 rerun baseline (`R40`, exact `R31` settings):

- `4 FAIL`

Interpretation:

- single-run rankings are informative, but not perfect;
- the next wave should explicitly include a stability confirmation stage for the best survivors.

## 8) Main Takeaways

1. Phase 6 was scientifically useful even though no candidate advanced automatically.
2. `R44_r31_ridge_chain900_stepsout` is the new practical carry-forward profile.
3. The remaining problem is now ridge-dominant, with one narrow rhs drift residual.
4. The next experiment program should be `R44`-centered, not `R31`-centered.
5. The next wave should include a rerun/stability stage for the top survivors.

## 9) Recommended Next Move

Run one new `R44`-centered refinement program with two stages:

1. a broad full-6 screen around:
   - mild rhs drift stabilization on top of `R44`
   - ridge ESS + half-drift refinement on top of `R44`
   - a few combined descendants
2. a stability rerun of the top Stage-1 survivors on the same full-6 harness

That is now the highest-signal, lowest-waste next step.
