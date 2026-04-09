# REPORT: QDESN Dynamic Effective-W300 Main Comparison Outputs

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the authoritative effective-w300 comparison-analysis pack after:

- the broad effective-w300 rerun,
- the execution-failure repair and failed-root relaunch,
- the scientific fail-closure wave,
- the final residual wave, and
- the exact-root rhs reconciliation that closes the last residual FAIL rows.

This report is now the current comparison-facing handoff for the effective-w300 study.

## 2) Authoritative Source Definition

Authoritative zero-fail source state:

- source run:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162642__git-5ed0d19`
- source mode:
  - `prior_fitfail_wave`
- selected stage-local baselines:
  - `R1 -> R820_ridge_combo224_soft2600`
  - `R2 -> R950_rhs_long_guard256_diag3200`
- exact-root overrides:
  - `laplace tau=0.95 fit_size=5000 rhs_ns -> R910_rhs_long_guard224_narrow2800`
  - `normal tau=0.25 fit_size=5000 rhs_ns -> R930_rhs_long_guard224_diag3000`

Reconciliation assets:

- reconciliation report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_final_residual_closeout_and_zero_fail_reconciliation_20260408.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis_manifest.yaml`
- wrapper:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis.R`

## 3) Authoritative Effective-W300 Comparison Pack

Completed comparison-analysis run:

- analysis commit:
  - `cc6f0f5`
- prepare-only run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200845__git-cc6f0f5`
- authoritative run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/summary/qdesn_dynamic_main_comparison_analysis.md`
- completion metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/launch/completion_metadata.json`

Key tables:

- analysis overview:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/analysis_overview.csv`
- 144-row case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_fit_case_table_readable.csv`
- authoritative local baseline map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_local_baseline_map.csv`
- authoritative root override map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_root_override_map.csv`
- root inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_root_inventory.csv`
- fit FAIL inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/tables/authoritative_fail_inventory.csv`
- QDESN-vs-reference summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-200857__git-cc6f0f5/comparison_vs_reference/comparison_summary.md`

## 4) Rolled Comparison State

Rolled counts from the authoritative reconciled effective-w300 source:

- fit rows:
  - `144`
- fit signoff:
  - `68 PASS`
  - `76 WARN`
  - `0 FAIL`
- root execution:
  - `36/36` completed
  - `0/36` root-status FAILs
- root readiness:
  - `36/36` comparison-eligible-any
  - `36/36` comparison-eligible-full

Meaning:

- the execution-failure pocket is closed,
- the scientific fail surface is also closed under the reconciled effective-w300 baseline, and
- the study is now fully ready for comparison interpretation without another repair wave.

## 5) Metric Framing

Primary validation metrics in this pack:

- train/fitted-path oracle quantile recovery against `q_true`:
  - `train_qtrue_mae`
  - `train_qtrue_rmse`
  - `train_qtrue_bias`
  - `train_qtrue_corr`
  - `train_qtrue_median_ae`
  - `train_qtrue_p90_ae`
- train/fitted-path quantile calibration against `y`:
  - `train_pinball_tau`
  - `train_coverage`
  - `train_coverage_minus_tau`
  - `train_coverage_error`
- runtime:
  - `runtime_sec`
  - `runtime_sec_per_1k_eval`
  - `runtime_sec_per_1k_train_eval`

Interpretation rule:

- the train/fitted path is the primary window because the effective-w300 defaults still use
  `holdout_n = 1`
- holdout metrics remain available, but they are secondary/descriptive

## 6) Important Interpretation Notes

- This is now the correct post-repair, post-reconciliation comparison-facing artifact for the
  effective-w300 study.
- The pack is zero-FAIL because the last rhs residuals were closed by promoting completed exact-root
  challenger evidence, not by running another broad rerun.
- QDESN-vs-reference readiness and signoff comparisons remain useful on the mirrored dynamic surface.
- Because the effective-w300 contract changes the source-window semantics relative to the older
  mirrored reference surface, QDESN-vs-reference deltas on this pack should be treated as
  descriptive rather than strict like-for-like comparisons unless the reference is rerun under the
  same source-window contract.

## 7) Recommended Next Move

The next move on this branch is now explicit:

1. treat this reconciled effective-w300 pack as the authoritative source of truth,
2. stop launching further repair compute by default,
3. use the refreshed case tables and compact summaries for the main comparison narrative,
4. reopen validation only if a later confirmation rerun or sensitivity check is specifically desired.
