# REPORT: QDESN Validation Phase 15 R512 Sentinel Crossover Matrix (2026-04-03)

Date: 2026-04-03  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Scope

Phase 15 was the last exploratory wave inside the promoted `R512` neighborhood.

Its purpose was deliberately narrow:

1. hold `R512_r412_pass2_chain1000` fixed as the active baseline;
2. test only crossovers of the surviving Phase-14 local signals;
3. require rerun confirmation before any promotion;
4. require final residual confirmation before any new baseline call.

This was not a family reopening wave. It was a last crossover audit inside the
surviving `R512/R612/R622/R616/R402` neighborhood.

## 2) Run Summary

- run tag:
  `qdesn-phase15-r512-sentinel-crossover-20260403a__git-bbbf2ca`
- final summary:
  `reports/qdesn_mcmc_validation/qdesn_validation_phase15_r512_sentinel_crossover_matrix/qdesn-phase15-r512-sentinel-crossover-20260403a__git-bbbf2ca/summary/family_b_screen_results.md`
- stop reason:
  `no_candidates_advanced_S3_final_residual_confirmation`
- operational outcome:
  `0` timeouts, `0` runner errors, no finite/domain/collapse regressions

Stage progression:

| stage | progress | outcome |
|---|---:|---|
| `S1_exact_fullsix_sentinel_crossover` | `15/15` | `6` candidates advanced |
| `S2_zero_sentinel_rerun_confirmation` | `7/7` | `1` candidate advanced |
| `S3_final_residual_confirmation` | `2/2` | `0` candidates advanced |

## 3) Main Results

### Stage-1 local read

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | read |
|---|---:|---:|---:|---:|---|
| `R704_r616_sentinel_reference` | `1` | `1` | `2` | `1.092` | best raw Stage-1 result |
| `R731_r402_softgamma_steps70_rhssoft_freeze90` | `3` | `0` | `3` | `0.889` | best practical Stage-1 result |
| `R701_r402_balanced_control` | `3` | `0` | `3` | `0.988` | strongest clean control |
| `R723_r512_softgamma_steps75_rhssoft_freeze90` | `2` | `1` | `3` | `1.076` | strongest crossover descendant on raw fail count after `R704` |
| `R702_r612_ridge_reference` | `2` | `1` | `3` | `1.233` | strongest ridge-led scientific signal |

### Stage-2 rerun confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | outcome |
|---|---:|---:|---:|---:|---|
| `R702_r612_ridge_reference` | `2` | `0` | `2` | `1.101` | only rerun-confirmed survivor |
| `R700_r512_anchor_control` | `3` | `0` | `3` | `1.135` | clean rerun anchor, but weaker |
| `R723_r512_softgamma_steps75_rhssoft_freeze90` | `2` | `1` | `3` | `1.091` | local signal remained sentinel-risky |
| `R701_r402_balanced_control` | `4` | `0` | `4` | `0.884` | cheap and clean, but too weak |
| `R704_r616_sentinel_reference` | `3` | `1` | `4` | `1.126` | Stage-1 raw winner did not hold |

### Stage-3 final residual confirmation

| profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation | gate |
|---|---:|---:|---:|---:|---|
| `R702_r612_ridge_reference` | `2` | `1` | `3` | `1.104` | `FALSE` |
| `R700_r512_anchor_control` | `4` | `0` | `4` | `1.137` | `FALSE` |

## 4) What Improved

1. Phase 15 proved that the surviving local search space is real enough to
   produce a rerun-confirmed `2 FAIL / 0 sentinel FAIL` candidate at Stage 2.
2. The strongest surviving signal from the wave was ridge-led, not broad
   crossover-led: `R702_r612_ridge_reference`.
3. The wave also showed that a clean balanced control (`R701`) remained useful
   for final comparison discipline even though it was not competitive enough to
   win.

## 5) What Still Failed

1. No candidate survived final residual confirmation strongly enough to replace
   `R512`.
2. The best Stage-2 winner (`R702`) regressed at Stage 3 and reintroduced a
   sentinel FAIL.
3. The broader crossover descendants did not deliver a stable improvement over
   `R512`.

## 6) What Worked Best

| idea | read |
|---|---|
| ridge-led rescue carried from `R612` | strongest real scientific signal in the wave |
| zero-sentinel rerun gate | correctly blocked overinterpreting noisy local wins |
| clean-control carry-forward (`R402`) | remained useful as a discipline anchor |

## 7) What Clearly Did Not Work

| idea | why it is now retired |
|---|---|
| raw Stage-1 ranking alone | `R704` looked best locally and still failed final confirmation |
| broader crossover hedges as the main answer | they did not beat the ridge-led signal or the baseline cleanly |
| another promotion from Phase 15 | not justified by final confirmation evidence |

## 8) Current Baseline Decision

Phase 15 is a non-promoting wave.

The baseline remains:

| role | profile | severe_fail_n | sentinel_fail_n | total_fail_n | runtime_inflation |
|---|---|---:|---:|---:|---:|
| active baseline | `R512_r412_pass2_chain1000` | `3` | `0` | `3` | `1.106` |
| best non-promoted local signal from Phase 15 | `R702_r612_ridge_reference` | `2` | `1` | `3` | `1.104` |

## 9) Practical Decision

Phase 15 closed the exploratory loop.

The next step should not be another search wave. The right move is one final
frozen certification rerun of the full dynamic matrix using `R512`, followed by
baseline-vs-`R512` comparison reporting.

That is the cleanest way to finish the QDESN validation sequence without
reopening exploratory tuning.
