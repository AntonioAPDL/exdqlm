# REPORT: QDESN Validation Phase 7 R44 Refinement + Stability Screen (2026-04-01)

Date: 2026-04-01  
Branch: `feature/qdesn-mcmc-alternative`  
Run tag: `qdesn-phase7-r44-refinement-20260401a__git-d3e43f7`

## 1) Purpose

Capture the outcome of the first stability-aware refinement program rooted at the practical Phase 6
carry-forward profile, `R44_r31_ridge_chain900_stepsout`.

This wave asked two questions:

1. can the remaining full-6 fail set be reduced further with disciplined `R44` descendants;
2. do the apparent Stage-1 winners hold up on exact rerun?

## 2) Operational Outcome

Phase 7 was operationally clean end to end.

- `S1_full_six_refinement`: `12/12` profiles complete
- `S2_stability_confirmation`: `4/4` profiles complete
- `0` timeouts
- `0` runner errors
- completed profiles stayed finite/domain-safe
- no collapse or unhealthy regressions were introduced

This is a scientific result set, not an orchestration artifact.

## 3) Stage 1 Outcome

Stage-1 ranking:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R66_r44_ridge_softsigma_stepsout` | `2` | `1` | `3` | `0.5000` | `0.7260` |
| `R60_r31_control` | `2` | `1` | `3` | `0.5000` | `0.8352` |
| `R65_r44_ridge_chain1200_stepsout` | `2` | `1` | `3` | `0.5000` | `0.9368` |
| `R70_r44_rhschain1200freeze100_ridgewide` | `2` | `1` | `3` | `0.5000` | `1.0868` |
| `R68_r44_ridge_pass1_stepsout_chain900` | `3` | `0` | `3` | `0.5000` | `1.0321` |
| `R63_r44_rhs_chain1200_freeze100` | `3` | `0` | `3` | `0.5000` | `1.0831` |

Stage-1 read:

- ridge-led descendants were the strongest initial screen family;
- `R66` looked like the best first-pass winner;
- `R68` and `R63` were the cleanest zero-sentinel descendants;
- the original `R44` anchor (`R61`) looked mediocre in Stage 1, with `4 FAIL`.

## 4) Stage 2 Stability Outcome

Stage-2 rerun ranking:

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | fail_reduction | runtime_inflation |
|---|---:|---:|---:|---:|---:|
| `R61_r44_anchor` | `2` | `0` | `2` | `0.6667` | `0.7038` |
| `R60_r31_control` | `3` | `1` | `4` | `0.3333` | `0.7668` |
| `R65_r44_ridge_chain1200_stepsout` | `3` | `1` | `4` | `0.3333` | `0.8342` |
| `R66_r44_ridge_softsigma_stepsout` | `4` | `1` | `5` | `0.1667` | `0.7230` |

Stage-2 read:

- the apparent Stage-1 winner `R66` did not replicate;
- `R65` also weakened materially on rerun;
- the exact `R44` carry-forward (`R61`) reran best and became the strongest stable result of the wave;
- no candidate met the configured Stage-2 advance rule, so the program stopped correctly.

## 5) New Baseline Outcome

The exact `R44` settings, when rerun in Stage 2 as `R61_r44_anchor`, improved to the best stable
current baseline:

- `total_fail_n = 2`
- `severe_fail_n = 2`
- `sentinel_fail_n = 0`
- `runtime_inflation = 0.7038`

This is better than the previous practical baseline read for the same settings, so the current
operational baseline should now be treated as the exact `R61/R44` configuration, not a new
descendant profile.

## 6) Remaining Fail Set Under The Stable Baseline

Current remaining `FAIL` roots under `R61_r44_anchor`:

1. `dlm_constV_smallW @ tau=0.95 exal rhs_ns`
2. `dlm_constV_smallW @ tau=0.95 exal ridge`

Current guard-rail `WARN` roots:

1. `dlm_ar1V @ tau=0.95 exal rhs_ns`
2. `dlm_constV_bigW @ tau=0.05 exal ridge`
3. `dlm_constV_smallW @ tau=0.50 exal rhs_ns`
4. `dlm_constV_bigW @ tau=0.95 al rhs_ns`

### `constV_smallW @ tau=0.95 exal rhs_ns`

Fail reason:

- `geweke_drift; half_chain_drift`

Key MCMC diagnostics:

- core: `ESS = 20.13`, `ACF1 = 0.9514`, `Geweke = 1.50`, `half_drift = 0.3697`
- rhs: `ESS = 51.37`, `ACF1 = 0.9022`, `Geweke = 3.1018`, `half_drift = 0.8459`

Read:

- the residual problem is rhs-side drift/Geweke, not core ESS;
- this now looks like a narrow rhs local/global stabilization problem.

### `constV_smallW @ tau=0.95 exal ridge`

Fail reason:

- `low_ess; high_autocorrelation; half_chain_drift`

Key MCMC diagnostics:

- `ESS = 3.84`
- `ACF1 = 0.9915`
- `Geweke = 1.09`
- `half_drift = 0.6185`

Read:

- Geweke is already fine;
- the remaining ridge problem is ESS + ACF + half-drift;
- this is now a much cleaner target than the earlier broader ridge cluster.

## 7) What Worked Best

1. stability reruns changed the decision quality materially and should remain part of the program;
2. the exact `R44` settings proved stronger than the first-pass leaderboard suggested;
3. ridge-centered tuning still appears to be the stronger family overall;
4. `R68` remains a credible zero-sentinel ridge signal even though it was not one of the stable rerun winners;
5. `R63` remains a credible rhs-side clean signal, but it is no longer the baseline.

## 8) What Clearly Did Not Work

1. mild rhs-only changes such as `R62` and `R64`;
2. heavy ridge widening such as `R67`;
3. the Stage-1-only `R66` signal as a promotion candidate, because it did not reproduce;
4. expensive combined descendants that did not clearly outperform the stable baseline.

## 9) Main Takeaways

1. Phase 7 materially improved the branch baseline, but through a stability rerun of the existing
   `R44` settings rather than a new promoted descendant.
2. The remaining fail set is now only two `smallW @ tau=0.95 exal` roots, one `rhs_ns` and one `ridge`.
3. The next program should stop treating the problem as a broad full-surface search.
4. The highest-value next step is a focused resolution screen around the two remaining fail roots,
   with explicit guard rails for the current `WARN` roots.
5. The best new overnight program should keep the full-6 harness only for confirmation and stability,
   not for the whole broad search.

## 10) Recommended Next Move

Run a new three-stage program:

1. a targeted `smallW` resolution screen on the two remaining fail roots plus the key guard-rail
   `WARN` roots;
2. a full-6 confirmation screen for the strongest survivors;
3. a final stability rerun of the best confirmation survivors.

That is now the highest-signal, lowest-waste next step.
