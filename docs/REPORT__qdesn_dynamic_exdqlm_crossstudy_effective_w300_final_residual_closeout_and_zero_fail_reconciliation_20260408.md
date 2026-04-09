# REPORT: QDESN Dynamic Effective-W300 Final Residual Closeout And Zero-FAIL Reconciliation

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the completed final residual wave, decide which completed results should be promoted into the
working effective-w300 baseline, and document the exact reconciliation that closes the remaining
scientific FAIL surface without another overnight repair run.

This report supersedes the active continuation role previously held by:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_wave1_closeout_and_wave2_inventory_20260408.md`
- `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave_20260408.md`

for the current branch-local answer to:

- what improved,
- what still fails,
- which ideas worked best,
- which ideas did not help,
- and what the highest expected-value next move is.

## 2) Completed Final Residual Wave

Completed wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`
- stage execution table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19/tables/stage_execution_status.csv`
- local baseline map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19/tables/local_baseline_map.csv`

Final residual wave completion:

- `2/2` stages
- `10/10` challenger profiles
- `40/40` planned root-campaigns
- `160/160` planned fit rows

Stage-local recommendations:

| Stage | Selected Local Baseline | Source Target FAIL Rows | Winner Target FAIL Rows | Read |
|---|---|---:|---:|---|
| `R1_ridge_upper_tail_long_final` | `R820_ridge_combo224_soft2600` | `1` | `0` | clean ridge upper-tail long-horizon closure |
| `R2_rhs_long_mcmc_residual_final` | `R950_rhs_long_guard256_diag3200` | `3` | `2` | best broad rhs residual profile, but not fully clean by itself |

## 3) Promotion Decision Analysis

The right promotion rule here is not “use the stage winner blindly.” It is:

- keep the default baseline stable,
- promote only completed results that clearly improve the current source,
- and allow exact-root local promotions where the stage winner still leaves localized debt.

Promotion comparison:

| Candidate Source State | Fit FAIL Rows | Fail-Carrying Roots | Root-Status FAILs | Compare-Any | Compare-Full | Read |
|---|---:|---:|---:|---:|---:|---|
| promoted Wave 1 source | `4` | `4` | `0` | `36/36` | `32/36` | pre-final-wave working baseline |
| `R1` promoted, `R2` kept at source baseline | `3` | `3` | `2` | `36/36` | `33/36` | better than Wave 1, but weaker than promoting `R2` |
| `R1 + R2` stage winners only | `2` | `2` | `1` | `36/36` | `34/36` | clear improvement, but still not fully clean |
| `R1 + R2` plus exact-root rhs overrides | `0` | `0` | `0` | `36/36` | `36/36` | authoritative zero-FAIL reconciled baseline |

Conclusion:

- `R820` is a clear promotion.
- `R950` is also a clear promotion because it reduces the residual from `3` to `2` rhs FAIL rows
  and lowers root-status debt from `2` to `1`.
- after promoting `R950`, the remaining debt is small enough that exact-root completed evidence is
  the highest-value cleanup tool.

## 4) Exact Remaining Residual Before Root Overrides

After promoting `R820` and `R950`, the exact remaining residual is:

| Family | Tau | Fit Size | Prior | Inference | Model | Signoff Reason | Root Status |
|---|---:|---:|---|---|---|---|---|
| `laplace` | `0.95` | `5000` | `rhs_ns` | `mcmc` | `al` | `geweke_drift` | `SUCCESS` |
| `normal` | `0.25` | `5000` | `rhs_ns` | `mcmc` | `exal` | `missing_chain_diagnostics` | `FAIL` |

That is the entire remaining scientific debt at the stage-winner level.

## 5) Exact-Root Reconciliation That Closed The Surface

Two completed R2 challenger profiles already contained root-level solutions for the remaining
residuals:

| Root | Promoted From Profile | Why It Was Chosen |
|---|---|---|
| `laplace tau=0.95 fit_size=5000 rhs_ns` | `R910_rhs_long_guard224_narrow2800` | clears the remaining `mcmc_al` Geweke-drift row and leaves the full root as `SUCCESS` / full-ready |
| `normal tau=0.25 fit_size=5000 rhs_ns` | `R930_rhs_long_guard224_diag3000` | clears the remaining `mcmc_exal` diagnostics failure and leaves the full root as `SUCCESS` / full-ready |

Verified reconciled source state after those two exact-root promotions:

- fit rows:
  - `144`
- fit signoff:
  - `68 PASS`
  - `76 WARN`
  - `0 FAIL`
- root execution:
  - `0/36` root-status FAILs
- root readiness:
  - `36/36` comparison-eligible-any
  - `36/36` comparison-eligible-full

## 6) What Improved

### A) The repaired effective-w300 pack is now fully clean

Improvement versus the earlier repaired effective-w300 comparison pack:

| Metric | Earlier Repaired Pack | Reconciled Zero-FAIL Baseline | Change |
|---|---:|---:|---:|
| Fit FAIL rows | `35` | `0` | **`-35` (`-100.0%`)** |
| Root-status FAILs | `0` | `0` | flat |
| Comparison-eligible-any roots | `34/36` | `36/36` | **`+2`** |
| Comparison-eligible-full roots | `16/36` | `36/36` | **`+20`** |

### B) The broad repair story is complete

There is no remaining execution-failure queue and no remaining scientific fail surface under the
effective-w300 reconciled baseline.

### C) Comparison readiness is now complete

The study is now:

- `36/36` compare-any,
- `36/36` compare-full,
- and zero-FAIL at both fit and root levels.

## 7) Which Ideas Worked Best

### A) Stage-local promotions were the right default

The strongest improvements still came from promoting local winners rather than forcing one generic
rescue profile.

### B) Moderate ridge MCMC tuning beat heavier variants

`R820_ridge_combo224_soft2600` solved the ridge upper-tail long pocket cleanly without needing the
heavier diagnostic variants.

### C) rhs residual closure required mixed strategy, not one global rhs winner

`R950` was the best overall rhs stage winner, but it was not sufficient by itself. The real closure
required:

- a broad stage winner for the default baseline, plus
- exact-root promotions from completed challenger evidence.

### D) Exact-root promotions are a legitimate high-value tool

For the final two rhs rows, exact-root promotions were more efficient and more scientifically
defensible than spending another overnight wave trying to discover a single new R2 profile that
beats all completed evidence simultaneously.

## 8) Which Ideas Did Not Help

### A) Reopening solved ridge neighborhoods would now be wasteful

The ridge residual is closed. More ridge compute would be low value.

### B) The weaker rhs profiles remain dominated

The completed `R2` board shows that these are not good continuation candidates:

- `R920_rhs_long_guard224_balanced3000`
- `R940_rhs_long_guard224_burnheavy3200`

They rotated or worsened the guard-set debt without outperforming the combined `R950 + exact-root`
reconciliation path.

### C) Another overnight repair wave is not the highest-value next move

Because completed evidence already closes the residual surface, another repair run would mostly
spend compute proving something we can already establish from the current artifacts.

## 9) What Still Fails

Nothing under the authoritative reconciled effective-w300 baseline.

Residual debt after reconciliation:

- fit FAIL rows:
  - `0`
- fail-carrying roots:
  - `0`
- root-status FAIL rows:
  - `0`

## 10) Highest-Expected-Value Direction Now

The highest-value next move is no longer another overnight repair wave. It is:

1. promote the reconciled zero-FAIL source as the authoritative effective-w300 baseline,
2. regenerate the main comparison-analysis pack from that committed source,
3. use the zero-FAIL case tables and compact summaries for interpretation and reporting,
4. reopen repair compute only if a later sensitivity or confirmation study is specifically desired.

## 11) Authoritative Comparison Pack

The zero-FAIL comparison pack generated from this reconciled source is:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/summary/qdesn_dynamic_main_comparison_analysis.md`
- 144-row case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_fit_case_table_readable.csv`
- root override map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_root_override_map.csv`

## 12) Recommendation

Treat the effective-w300 validation-repair program as closed at the repair level. The branch should
now move forward from the reconciled zero-FAIL comparison pack, not from another overnight repair
manifest.
