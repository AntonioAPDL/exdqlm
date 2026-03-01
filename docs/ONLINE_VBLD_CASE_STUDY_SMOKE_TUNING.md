# ONLINE VB-LD Case Study Smoke + Schedule Tuning

Generated: 2026-02-27 02:08:04 PST

## Scope
- Single-quantile case study for online VB-LD scheduling.
- Dataset and optimal DESN spec locked from model-selection evidence.
- Offline behavior preserved; online is evaluated as additional feature.

## Case-Study Lock (Evidence)
- Dataset slug: `dlm_constV_smallW`
- Dataset path: `/data/muscat_data/jaguir26/exdqlm/results/sim_suite_dlm/series/dlm_constV_smallW/series_long.csv`
- Optimal candidate id: `113d66b36bd458787b07151663b8dcc1`
- Optimal spec source: `config/model_selection/specs/modelsel_sim_big_pragmatic.yaml`
- Model-selection records: `docs/model_selection_optimal_records.md`
- Locked architecture: `D=3, n=300,300,300, m=30, alpha=0.2,0.2,0.2, rho=0.95,0.95,0.95`
- Target quantile used for tuning: `p0=0.50`

## Commands Used
```bash
Rscript scripts/online_vbld_case_study_smoke_tuning.R --config config/online_vbld/case_study_dlm_constV_smallW_compact_paramdiag_rhs_onlineenabled.yaml --out_root results/online_vbld/case_study
```

## Smoke Checks (Pipeline Mode Toggle)

| smoke_label | vb.online.enabled | status | runtime_sec | notes |
|---|---:|---|---:|---|
| offline | FALSE | skipped | NA | smoke disabled in config |
| online_default | TRUE | skipped | NA | smoke disabled in config |

## Schedule Results

| run | mode | status | runtime_sec | check_loss | coverage_error | rmse_qtrue | finite_ok | spd_ok | chol_fail | jitter |
|---|---|---|---:|---:|---:|---:|---|---|---:|---:|
| offline | offline | success | 632.36 | 3.6102 | 0.1090 | 8.4043 | TRUE | TRUE | NA | NA |
| C5_W100 | online | success | 3916.41 | 3.6102 | 0.1090 | 8.4043 | TRUE | TRUE | NA | 101 |
| online_default | online | success | 3916.41 | 3.6102 | 0.1090 | 8.4043 | TRUE | TRUE | NA | 101 |

## Recommendation
- Recommended `vb.online.enabled`: `true`
- Recommended default schedule: `C5_W100`
- Safer fallback schedule: `C5_W100`
- Best online candidate before acceptance gate: `C5_W100`
- Acceptance gate enabled: `true`
- Acceptance gate triggered: `false`
- Gate thresholds: `delta_check <= 0.020000`, `delta_coverage_error <= 0.020000`
- Jitter stability cap used in selection: `max_jitter_eps <= 1.000e+50`
- Gate reason: `NA`

Decision rule:
- Primary: best predictive check-loss (with RMSE to true quantile as secondary when available).
- Constraints: successful run, finite/SPD health, acceptable coverage error, jitter sanity, and runtime sanity.
- Acceptance gate: keep `vb.online.enabled=false` when the recommended online candidate is worse than offline on both check-loss and coverage-error thresholds.

## Artifacts
- Run directory: `/data/muscat_data/jaguir26/exdqlm/results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757`
- Summary table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/run_summary.csv`
- Smoke table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/smoke_summary.csv`
- Config diffs: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/config_diffs.csv`
- Overlay plot: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/figs/offline_vs_online_overlay_eval.png`
- Rolling plot: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/figs/rolling_check_loss_error.png`
- Pareto plot: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/figs/runtime_vs_performance_pareto.png`
- Heatmap: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/figs/schedule_grid_heatmap.png`
- Drift summary table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/diagnostic_drift_summary.csv`
- Online trace tables (if enabled): `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/trace_<run>.csv`
- Parameter trace tables: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/param_trace_<run>.csv`
- Combined parameter traces: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260227-004757/tables/param_trace_all.csv`

## Assumptions
- Single quantile (`p0=0.50`) was used for schedule tuning.
- The model-selection optimal candidate id was reconstructed from stage-1 candidate grid and matched exactly.
- Ground-truth quantile was extracted from the simulation long file at nearest available `p` per time (exact `p=0.50` present).
