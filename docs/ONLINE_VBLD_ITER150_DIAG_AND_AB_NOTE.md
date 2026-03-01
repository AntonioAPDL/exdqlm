# Online VB-LD Iter150 Diagnosis + Controlled A/B Note

Date: 2026-02-24

## Scope executed
1. Generated full diagnostics visual pack for the completed RHS iter150 run.
2. Performed rigorous collapse diagnostics on RHS iter150 outputs (series + trace).
3. Chosen axis for next iteration: **prior behavior**. Ran controlled A/B (offline vs online C5_W100) with **ridge** prior, keeping data/split/DESN/schedule fixed.

## Runs analyzed
- RHS iter150 run:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-143055`
- Ridge A/B iter150 run:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-155309`

## Step 1: Full diagnostics pack status
- RHS iter150 full pack (01..07) generated:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-143055/figs/diagnostics_visual_pack_20260224-155211`
- Ridge A/B full pack (01..07) generated:
  - `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-155309/figs/diagnostics_visual_pack_20260224-155603`

## Step 2: Rigorous collapse diagnosis (RHS iter150)
Evidence table:
- `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-143055/tables/degeneracy_diagnostic_summary.csv`

Key findings:
- `qhat` magnitude is numerically near-zero for all runs (`~1e-291`), with effectively zero variance in practical scale.
- Offline and online metrics are identical to machine precision in `run_summary.csv`.
- Online update machinery is active (`rhs_refreshes=11`, `sigmagam_refreshes=3`, trace rows present), so this is not an execution-path skip.
- Conclusion: RHS setup in this case-study configuration is in a **collapse regime** (degenerate predictive scale), making schedule comparisons non-informative.

## Step 3: Controlled A/B on selected axis (prior behavior)
Config used:
- `config/online_vbld/case_study_dlm_constV_smallW_ab_ridge_iter150.yaml`
- Differences vs RHS iter150:
  - `vb.beta_prior_type: ridge`
  - schedule grid reduced to one online candidate (`C5_W100`) for strict A/B.

Run summary:
- `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-155309/tables/run_summary.csv`

A/B outcome:
- Offline (ridge): `check_loss=4.8595`, `coverage_error=0.0357`, `rmse_qtrue=11.8057`.
- Online C5_W100 (ridge): `check_loss=4.7415`, `coverage_error=0.0500`, `rmse_qtrue=11.9020`.
- `qhat` is no longer collapsed (SD ~15.6; large dynamic range).
- Online deviates materially from offline (`max_abs_qhat_diff_vs_offline ~ 6.90`).

Cross-run comparison file:
- `results/online_vbld/case_study/dlm_constV_smallW/runs/diagnostic_compare_rhs_vs_ridge_ab.csv`

Interpretation:
- The collapse is associated with RHS behavior in this setup, not with online scheduling mechanics alone.
- Online VB-LD path is functioning and can change predictions when baseline is not degenerate.

## Decision and next-step gate
Decision:
- Continue next iteration on the **RHS prior calibration axis** before additional schedule tuning.

Gate to proceed with schedule tuning under RHS:
- Require non-collapsed offline RHS baseline (e.g., practical `qhat` variance and non-pathological scale) on the same case-study split.

Recommended next execution order:
1. RHS offline-only calibration sweep (small, targeted) to remove collapse.
2. Once baseline is non-collapsed, rerun A/B offline vs online (single schedule).
3. Then rerun schedule grid tuning (`M,K,W,L_loc`) with acceptance gate.

## Commands used
```bash
Rscript scripts/online_vbld_make_diagnostics_pack.R results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-143055
Rscript scripts/online_vbld_case_study_smoke_tuning.R --config config/online_vbld/case_study_dlm_constV_smallW_ab_ridge_iter150.yaml --out_root results/online_vbld/case_study
Rscript scripts/online_vbld_make_diagnostics_pack.R results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-155309
```
