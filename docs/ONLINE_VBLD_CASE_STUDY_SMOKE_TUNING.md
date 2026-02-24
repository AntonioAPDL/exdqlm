# ONLINE VB-LD Case Study Smoke + Schedule Tuning

Generated: 2026-02-24 12:59:39 PST

## Scope
- Single-quantile case study for online VB-LD scheduling.
- Dataset and optimal DESN spec locked from model-selection evidence.
- Offline behavior preserved; online is evaluated as additional feature.

## Case-Study Lock (Evidence)
- Dataset slug: `dlm_constV_smallW`
- Dataset path: `/data/muscat_data/jaguir26/exdqlm/results/sim_suite_dlm/series/dlm_constV_smallW/series_long.csv`
- Optimal candidate id: `1b193fada082764ac49e627c928e9434`
- Optimal spec source: `config/model_selection/specs/modelsel_sim_big_pragmatic_refined_d2probe.yaml`
- Model-selection records: `docs/model_selection_optimal_records.md`
- Locked architecture: `D=1, n=650, m=60, alpha=0.35, rho=0.88`
- Target quantile used for tuning: `p0=0.50`

## Commands Used
```bash
Rscript scripts/online_vbld_case_study_smoke_tuning.R --config config/online_vbld/case_study_dlm_constV_smallW_trace_diag.yaml --out_root results/online_vbld/case_study
```

## Smoke Checks (Pipeline Mode Toggle)

| smoke_label | vb.online.enabled | status | runtime_sec | notes |
|---|---:|---|---:|---|
| offline | FALSE | skipped | NA | smoke disabled in config |
| online_default | TRUE | skipped | NA | smoke disabled in config |

## Schedule Results

| run | mode | status | runtime_sec | check_loss | coverage_error | rmse_qtrue | finite_ok | spd_ok | chol_fail | jitter |
|---|---|---|---:|---:|---:|---:|---|---|---:|---:|
| offline | offline | success | 136.37 | 3.0866 | 0.0786 | 7.7029 | TRUE | TRUE | NA | NA |
| C5_W100 | online | success | 344.17 | 3.3337 | 0.1429 | 8.3624 | TRUE | TRUE | NA | 122 |
| C5_L3 | online | success | 316.59 | 3.3341 | 0.1429 | 8.3634 | TRUE | TRUE | NA | 122 |
| online_default | online | success | 344.17 | 3.3337 | 0.1429 | 8.3624 | TRUE | TRUE | NA | 122 |

## Recommendation
- Recommended `vb.online.enabled`: `false`
- Recommended default schedule: `offline`
- Safer fallback schedule: `C5_L3`
- Best online candidate before acceptance gate: `C5_W100`
- Acceptance gate enabled: `true`
- Acceptance gate triggered: `true`
- Gate thresholds: `delta_check <= 0.020000`, `delta_coverage_error <= 0.020000`
- Jitter stability cap used in selection: `max_jitter_eps <= 1.000e+50`
- Gate reason: `online_vs_offline gate triggered (delta_check=0.247135 > 0.020000, delta_cov_err=0.064286 > 0.020000)`

Decision rule:
- Primary: best predictive check-loss (with RMSE to true quantile as secondary when available).
- Constraints: successful run, finite/SPD health, acceptable coverage error, jitter sanity, and runtime sanity.
- Acceptance gate: keep `vb.online.enabled=false` when the recommended online candidate is worse than offline on both check-loss and coverage-error thresholds.

## Artifacts
- Run directory: `/data/muscat_data/jaguir26/exdqlm/results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600`
- Summary table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/tables/run_summary.csv`
- Smoke table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/tables/smoke_summary.csv`
- Config diffs: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/tables/config_diffs.csv`
- Overlay plot: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/figs/offline_vs_online_overlay_eval.png`
- Rolling plot: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/figs/rolling_check_loss_error.png`
- Pareto plot: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/figs/runtime_vs_performance_pareto.png`
- Heatmap: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/figs/schedule_grid_heatmap.png`
- Drift summary table: `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/tables/diagnostic_drift_summary.csv`
- Online trace tables (if enabled): `results/online_vbld/case_study/dlm_constV_smallW/runs/online_vbld_case_study__20260224-124600/tables/trace_<run>.csv`

## Assumptions
- Single quantile (`p0=0.50`) was used for schedule tuning.
- The model-selection optimal candidate id was reconstructed from stage-1 candidate grid and matched exactly.
- Ground-truth quantile was extracted from the simulation long file at nearest available `p` per time (exact `p=0.50` present).

## Policy Freeze (Current)
- Keep operational default as offline: `vb.online.enabled=false`.
- If online is explicitly enabled for controlled experiments, use `C5_W100` as the primary fallback profile.
- Secondary fallback profile for robustness checks: `C5_L3`.
- Promotion of online mode remains blocked until it clears the acceptance gate against offline on this case study.
