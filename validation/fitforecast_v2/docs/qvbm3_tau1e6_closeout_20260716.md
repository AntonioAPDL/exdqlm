# Q-DESN 500-Observation VB QVBM3 Tau1e-6 Closeout

- generated_at: `2026-07-16 01:25:36.174275`
- worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- branch: `validation/shared-fitforecast-v2-1.0.0`
- head: `f91bcc7ca7c27474ba22a9a30ebc0ea76385f12d`
- stage_prefix: `qvbm3_tau1e6`
- reference_stage: `qvbm3_capacity`
- raw ignored report root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qvbm3_tau1e6/audit/closeout/qvbm3_tau1e6_closeout_20260716__git-f91bcc7`

## Health

| planned_roots | success_roots | non_success_roots | roots_left | pct_done | fit_summary_rows | forecast_lead_files | observed_forecast_lead_rows | expected_forecast_lead_rows | pass_converged | warn_not_converged | rhs_collapse_count |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 66 | 66 | 0 | 0 | 100 | 66 | 66 | 1980 | 1980 | 31 | 35 | 0 |

## Metric Medians

| screen | rows | median_fit_rmse | median_fit_check | median_forecast_mae | median_forecast_check | median_runtime_sec |
|---|---|---|---|---|---|---|
| qvbm3_tau1e6 | 66 | 6.4994 | 1.3664 | 6.3649 | 1.7235 | 38.5450 |
| qvbm3_capacity | 66 | 6.4994 | 1.3664 | 6.3649 | 1.7235 | 39.4835 |

## Cell Group Means

| family | tau | model | mean_fit_rmse | mean_fit_check | mean_forecast_mae | mean_forecast_check | mean_runtime_sec |
|---|---|---|---|---|---|---|---|
| gausmix | 0.05 | al | 8.0086 | 1.1580 | 5.9124 | 1.6423 | 78.6451 |
| laplace | 0.05 | al | 8.3973 | 1.4790 | 5.7292 | 1.9655 | 102.9349 |
| normal | 0.05 | al | 5.0082 | 0.9127 | 9.7902 | 1.3468 | 162.2501 |
| normal | 0.50 | al | 5.5779 | 3.6092 | 8.3617 | 5.7119 | 26.7816 |
| gausmix | 0.05 | exal | 6.7500 | 1.3571 | 4.8273 | 1.5728 | 86.3236 |
| laplace | 0.05 | exal | 8.5851 | 1.6731 | 3.8141 | 1.9178 | 93.1551 |
| normal | 0.05 | exal | 4.5424 | 0.9985 | 8.0473 | 1.2672 | 223.4257 |
| normal | 0.50 | exal | 5.5804 | 3.6100 | 8.4481 | 5.7374 | 30.6940 |

## Ratio Summary Versus Prior QVBM3 Capacity Screen

| metric | cells | median_ratio | min_ratio | max_ratio | cells_better_0p5pct | cells_worse_0p5pct |
|---|---|---|---|---|---|---|
| fit_rmse | 66 | 1 | 1.0000 | 1.0000 | 0 | 0 |
| fit_check | 66 | 1 | 0.9999 | 1.0000 | 0 | 0 |
| forecast_mae | 66 | 1 | 0.9999 | 1.0002 | 0 | 0 |
| forecast_check | 66 | 1 | 0.9999 | 1.0000 | 0 | 0 |

## Ratio Summary Versus Baselines

| reference | cells | cells_beating_all4 | median_worst_ratio | min_worst_ratio | max_worst_ratio |
|---|---|---|---|---|---|
| qvbm1 | 8 | 0 | 1.8555 | 1.0043 | 4.7298 |
| exdqlm_dqlm_vb | 8 | 0 | 3.1483 | 1.6888 | 7.8548 |

## Tau0 Wiring Audit

| source | n_rows | min_rhs_tau0 | max_rhs_tau0 | unique_rhs_tau0 |
|---|---|---|---|---|
| config_profiles | 66 | 0.0000 | 0.0000 | 1e-06 |
| campaign_fit_summary | 66 | 0.0000 | 0.0000 | 1e-06 |
| reference_campaign_fit_summary | 66 | 0.0001 | 0.0003 | 1e-04;3e-04 |

| evidence | path | line_hint | interpretation |
|---|---|---|---|
| grid_row_assigns_screening_rhs_tau0 | R/qdesn_dynamic_exdqlm_crossstudy.R | 1048 | screening profile rhs_tau0 is copied into the generated root/grid row |
| grid_preflight_requires_positive_rhs_tau0 | R/qdesn_dynamic_exdqlm_crossstudy.R | 1170-1175 | rhs_ns rows with non-positive rhs_tau0 are rejected before launch |
| root_spec_validates_positive_rhs_tau0 | R/qdesn_dynamic_exdqlm_crossstudy.R | 1253-1288 | root specs with invalid rhs_tau0 are rejected before fit |
| static_prior_requires_positive_tau0 | R/static_beta_prior.R | 69-72 | beta prior controls reject non-positive tau0 |
| static_rhs_log_prior_uses_ctrl_tau0 | R/static_beta_prior.R | 365 | RHS prior log-density includes log(ctrl$tau0) |

## Storage Audit

| stage_prefix | scanned_roots | heavy_payload_files | heavy_payload_bytes | storage_policy_status |
|---|---|---|---|---|
| qvbm3_tau1e6 | results/qvbm3_tau1e6;reports/qvbm3_tau1e6 | 0 | 0 | PASS_STORAGE_LIGHT |

## Disposition

| stage_prefix | status | scientific_disposition | article_facing | mcmc_handoff | core_reason | recommended_next_step |
|---|---|---|---|---|---|---|
| qvbm3_tau1e6 | COMPLETE | DIAGNOSTIC_NEGATIVE_DO_NOT_PROMOTE | FALSE | FALSE | tau0=1e-06 completed but is effectively identical to qvbm3_capacity and does not clear qvbm1/exdqlm-dqlm all-four gates | close this surface; plan a different mechanism-first screen from qvbm1/frontier designs rather than another tau0-only qvbm3 relaunch |

## Interpretation

- The run is operationally complete: all planned roots succeeded and all rolling-origin lead metric files are present.
- The `rhs_tau0 = 1e-06` value is present in config profiles and campaign fit summaries, while the reference qvbm3 capacity screen records `1e-04`/`3e-04`.
- The code path reads, validates, and passes `rhs_tau0` into the RHS prior; the lack of improvement is therefore treated as empirical negative evidence for this tau0-only rescue, not as proof that the field is ignored.
- The screen is not article-facing and should not be promoted to MCMC.
- The next screen should change model mechanism/feature construction or return to the stronger qvbm1 frontier, rather than relaunching this same high-capacity surface with only smaller tau0.
