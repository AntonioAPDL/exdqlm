# Post-Run Comparison Note (D3, Full T, 80/20)

Run evaluated:
- `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-231918`

Configuration snapshot:
- Dataset: `dlm_constV_smallW`
- Split: `T_use=5000`, `train_prop=0.80` -> effective `train=3500`, `eval=1000`
- DESN: `D=3`, `n=[300,300,300]`, `n_tilde=[300,300]`, `m=30`, `alpha=[0.2,0.2,0.2]`, `rho=[0.95,0.95,0.95]`
- Online schedule: `C5_W100 = (M=10, K=40, W=100, L_loc=2)`

## Performance comparison

| Run | Runtime (s) | Check Loss | Coverage | Coverage Error | RMSE(q_true) |
|---|---:|---:|---:|---:|---:|
| Offline | 576.219 | 3.610215 | 0.609 | 0.109 | 8.404295 |
| Online C5_W100 | 3661.815 | 3.610215 | 0.609 | 0.109 | 8.404295 |

Observed deltas (online vs offline):
- `delta_check_vs_offline = 0`
- `delta_rmse_qtrue_vs_offline = 1e-6` (numerical tie)

## Stability interpretation

What is good:
- Both runs finished successfully.
- Finite checks and SPD checks reported as `TRUE` for both.
- Predictive metrics are effectively identical in this case.

What is concerning:
- Online diagnostics report nontrivial jitter activity:
  - `n_jitter = 101`
  - `max_jitter_eps_raw = 41855194443062166e5`
- This indicates the online linear algebra path needed frequent/large stabilization, even though final predictive metrics matched offline.

Practical interpretation:
- On this dataset/spec, online currently provides no predictive gain over offline and is much slower (`~6.35x` runtime).
- The current recommendation file selects `C5_W100`, but that choice should be read together with the jitter warning.
- For operational robustness, treat this result as "performance tie with numerical-stability caveat" rather than a strict online win.

## Pointers

- Main report: `docs/ONLINE_VBLD_CASE_STUDY_SMOKE_TUNING.md`
- Summary table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-231918/tables/run_summary_pretty.csv`
- Recommendation: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-231918/tables/recommendation.csv`
- Online traces: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-231918/tables/trace_C5_W100.csv`
- Parameter traces: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-231918/tables/param_trace_all.csv`
