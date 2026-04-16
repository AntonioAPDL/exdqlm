# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Main Comparison Outputs

Date: 2026-04-16
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the comparison-facing pack generated from the completed deep-DESN row-faithful multiseed
replay.

This pack is the correct post-replay comparison artifact because it:

- uses the finished replay outputs only;
- materializes the full 144-row authoritative fit table;
- adds an explicit one-row-per-root representative-case table; and
- makes the remaining fail surface inspectable without pretending the replay closed it.

## 2) Source Definition

Completed replay source:

- source run:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-20260412-124648__git-7144048`
- source mode:
  - `dynamic_campaign`
- source label:
  - `Completed Deep-DESN Row-Faithful Multiseed Replay`
- closeout / failure-audit report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_closeout_and_failure_audit_20260416.md`

Replay contract reminder:

- preserve each row's accepted exact local tuning;
- standardize only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - VB posterior draw export `= 20000`
  - `4` deterministic MCMC seeds

## 3) Completed Comparison Pack

Completed analysis run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500`
- wrapper:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis.R`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis_manifest.yaml`
- summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/summary/qdesn_dynamic_main_comparison_analysis.md`
- representative-case summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/summary/qdesn_dynamic_main_comparison_representative_case_table.md`
- completion metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/launch/completion_metadata.json`

Key tables:

- analysis overview:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/tables/analysis_overview.csv`
- authoritative 144-row case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/tables/authoritative_fit_case_table_readable.csv`
- authoritative 36-row representative-case table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/tables/authoritative_representative_fit_case_table_readable.csv`
- representative selection counts:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/tables/authoritative_representative_fit_selection_counts.csv`
- fail inventory:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/tables/authoritative_fail_inventory.csv`
- QDESN-vs-reference summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-deepdesn-maincmp-20260416-160500/comparison_vs_reference/comparison_summary.md`

## 4) Important Method Note

This replay-specific pack intentionally uses the emitted replay summaries directly instead of
rehydrating every saved fit artifact again.

Why:

- the completed replay already materialized the needed fit metrics in
  `campaign_fit_summary.csv`;
- rehydrating all 144 fit artifacts was unnecessarily slow; and
- the pack only needs those emitted metrics plus the replay-ready signoff tables.

Manifest control:

- `analysis.refresh_fit_metrics: false`

Important metric caveat:

- `forecast_CRPS_mean` is present as a column in the replay outputs but missing on this completed
  replay surface;
- therefore the representative-case selector must not pretend to be CRPS-driven here.

## 5) Representative-Case Selection Rule

Representative selection is now explicit and deterministic, one selected row per root:

1. `PASS > WARN > FAIL`
2. `comparison_eligible = TRUE`
3. `status = SUCCESS`
4. best available metric in order:
   - `forecast_CRPS_mean`
   - otherwise `holdout_qtrue_rmse`
   - otherwise `train_qtrue_rmse`
   - otherwise `runtime_sec`
5. lower `runtime_sec`
6. deterministic tie-breaks

Observed on this replay pack:

- representative rows:
  - `36`
- rows selected on `forecast_CRPS_mean`:
  - `0`
- rows selected on `holdout_qtrue_rmse`:
  - `36`
- representative rows with `comparison_eligible = TRUE`:
  - `36 / 36`

## 6) Full-Study Rolled State

Main pack state:

- fit rows:
  - `144`
- fit signoff:
  - `66 PASS`
  - `44 WARN`
  - `34 FAIL`
- root inventory:
  - `36` total
  - `10` root-status `FAIL`
  - `36 / 36` comparison-eligible-any
  - `17 / 36` comparison-eligible-full

Representative table state:

- representative rows:
  - `26 PASS`
  - `10 WARN`
  - `0 FAIL`
- representative inference/model counts:
  - `PASS / mcmc / al = 3`
  - `PASS / vb / al = 11`
  - `WARN / vb / al = 7`
  - `PASS / vb / exal = 12`
  - `WARN / vb / exal = 3`

Representative interpretation:

- the representative winners are overwhelmingly `VB`;
- only `3` roots select `MCMC`, and all `3` are `al / ridge / fit_size=500 / tau=0.25` across the
  three families;
- no representative root selects an `MCMC exal` row.

## 7) What Now Represents Each Case

High-level representative pattern:

- all `18` `ridge` roots select `PASS` representatives;
- `rhs_ns` roots split into:
  - `8 PASS`
  - `10 WARN`
- by fit size:
  - `500`:
    - `9 PASS`
    - `9 WARN`
  - `5000`:
    - `17 PASS`
    - `1 WARN`

Important representative caution:

- every representative `WARN` row is in `rhs_ns`;
- `9 / 10` representative `WARN` rows are the short `fit_size=500` `rhs_ns` roots;
- the only long-horizon representative `WARN` row is:
  - `gausmix tau=0.95 fit_size=5000 rhs_ns`

Representative `WARN` reasons:

- `vb_converged_false` dominates the short `rhs_ns` `WARN` selections;
- `stable_tail_but_not_certified` appears on the single long-horizon representative `WARN`.

## 8) Remaining FAIL Inventory

Authoritative fail inventory:

- fail rows:
  - `34`
- all fail rows are:
  - `MCMC`

Reason counts:

- `missing_chain_diagnostics`:
  - `15`
- `high_autocorrelation`:
  - `11`
- `high_autocorrelation; geweke_drift`:
  - `6`
- `high_autocorrelation; geweke_drift; half_chain_drift`:
  - `2`

Fail clustering:

- by prior / fit size:
  - `rhs_ns / 500 = 18`
  - `rhs_ns / 5000 = 14`
  - `ridge / 5000 = 2`
- by family / fit size:
  - `gausmix / 500 = 6`
  - `gausmix / 5000 = 6`
  - `laplace / 500 = 6`
  - `laplace / 5000 = 7`
  - `normal / 500 = 6`
  - `normal / 5000 = 3`

Practical read:

- the short-horizon `rhs_ns` pocket is still carrying mixing/drift-type MCMC failures;
- the long-horizon `5000` pocket is where the harder `missing_chain_diagnostics` failures
  concentrate;
- this matches the replay closeout audit: the blocker is still MCMC quality, not root execution.

## 9) Decision Read

What this pack now tells us clearly:

- we do have a clean comparison-facing representative model for every root;
- those representatives are mostly `VB`, not `MCMC`;
- `ridge` remains the cleanest representative prior;
- `rhs_ns` still carries the softness, mostly as `WARN` representatives and `MCMC` fail rows;
- the remaining hard blocker is the long-horizon `fit_size=5000` MCMC pocket, with an additional
  short-horizon `rhs_ns` MCMC mixing pocket.

This means the correct next reconciliation rule is:

1. use the 36-row representative table as the comparison-facing per-case winner table;
2. do not promote a generic MCMC-first interpretation from this replay;
3. treat the remaining unresolved debt as targeted MCMC-lane debt, not as a failure of the replay
   contract itself.

## 10) Recommended Next Move

1. freeze this comparison pack as the branch-local deep-DESN challenger comparison artifact;
2. compare the representative-case table against the previously accepted source row by row;
3. promote only rows that are truly better under the row-faithful replay contract;
4. if more repair work is justified later, target the remaining `MCMC` fail inventory directly
   rather than reopening another generic broad replay.
