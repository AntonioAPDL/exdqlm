# REPORT: QDESN Dynamic Effective-W300 Main Comparison Outputs

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the authoritative effective-w300 comparison-analysis pack after:

- the broad effective-w300 posterior-draw rerun completed,
- the localized implementation failure pocket was repaired,
- the `6` failed roots were rerun successfully, and
- those repaired roots were reconciled back into the effective-w300 source state.

This report is the current branch-local comparison-analysis handoff for the effective-w300 study.

## 2) Authoritative Source Definition

Authoritative repaired source state:

- broad source run:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260407-233147__git-cdfd1a9`
- repaired failed-root relaunch:
  - `qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-20260408-012443__git-bcdb438`
- reconciliation method:
  - use the broad effective-w300 campaign as the source state
  - replace the original `6` execution-failure roots with the repaired relaunch outputs

Reconciliation assets:

- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis_manifest.yaml`
- wrapper:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis.R`
- reusable source-state support:
  - `R/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R`

## 3) Authoritative Effective-W300 Comparison Pack

Completed comparison-analysis run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/summary/qdesn_dynamic_main_comparison_analysis.md`
- completion metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/launch/completion_metadata.json`

Key tables:

- analysis overview:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/analysis_overview.csv`
- 144-row case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fit_case_table_readable.csv`
- inference compact table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fit_inference_compact.csv`
- method-model compact table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fit_method_model_compact.csv`
- VB-vs-MCMC compact table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_pair_axis_compact.csv`
- EXAL-vs-AL compact table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_model_axis_compact.csv`
- root inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_root_inventory.csv`
- remaining fit-level FAIL inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-effectivew300-maincmp-20260408-015614__git-554809e/tables/authoritative_fail_inventory.csv`

## 4) Rolled Comparison State

Rolled counts from the repaired effective-w300 source state:

- fit rows:
  - `144`
- fit signoff:
  - `40 PASS`
  - `69 WARN`
  - `35 FAIL`
- root execution:
  - `36/36` completed
  - `0/36` root-status FAILs
- root readiness:
  - `34/36` comparison-eligible-any
  - `16/36` comparison-eligible-full

Meaning:

- the execution-failure pocket is closed
- the remaining debt is now purely scientific signoff debt
- the repaired effective-w300 surface is suitable for full comparison analysis and table generation

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

- This pack is the correct post-repair comparison-facing artifact for the effective-w300 study.
- It is not a zero-FAIL pack; it is a repaired broad-study pack with closed execution debt and
  remaining scientific `FAIL` rows.
- QDESN-vs-reference readiness and signoff comparisons remain useful on the mirrored dynamic
  surface.
- Because the effective-w300 contract changes the source-window semantics relative to the older
  mirrored reference surface, QDESN-vs-reference deltas on this pack should be treated as
  descriptive rather than strict like-for-like comparisons unless the reference is rerun under the
  same source-window contract.

## 7) Recommended Next Move

The next move on this branch is now explicit:

1. keep this repaired effective-w300 pack as the authoritative source baseline,
2. use the fail inventory to drive a targeted scientific fail-closure wave rather than another
   broad rerun,
3. treat the remaining fail surface as three local mechanism families:
   - ridge VB tail instability,
   - rhs_ns mcmc_exal drift,
   - rhs_ns vb_exal rhs tail instability,
4. avoid reopening the closed execution-failure repair loop unless a new implementation bug is
   discovered,
5. use the following next-wave docs as the current continuation point:
   - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_surface_and_repair_plan_20260408.md`
   - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave_20260408.md`
