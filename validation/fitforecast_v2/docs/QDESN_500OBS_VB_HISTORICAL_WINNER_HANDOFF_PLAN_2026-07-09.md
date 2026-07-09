# Q-DESN 500-Observation VB Historical-Winner Handoff Plan

## Decision

Build a small current-protocol VB handoff from exact older broad-screen designs that already beat the DQLM/exDQLM VB baseline on all four primary criteria. Do not promote rescue-v2 candidates to MCMC, and do not run MCMC from this handoff until the fresh current-protocol VB run passes the same all-primary dominance gate.

## Evidence Summary

- generated_at: `2026-07-08 23:57:15.708955`
- dominance_summaries: `18`
- all_candidate_rows: `5298`
- historical_all_primary_winners: `517`
- selected_top_per_cell: `5`
- selected_handoff_assignments: `40`
- selected_unique_profiles: `27`
- unresolved_historical_winners: `0`
- selected_profile_conflicts: `0`

## Cell Coverage

| family | tau | historical_all_primary_wins | n_selected |
| --- | --- | --- | --- |
| gausmix | 0.05 | 187 | 5 |
| gausmix | 0.25 | 20 | 5 |
| gausmix | 0.5 | 7 | 5 |
| laplace | 0.05 | 234 | 5 |
| laplace | 0.25 | 28 | 5 |
| laplace | 0.5 | 24 | 5 |
| normal | 0.05 | 3 | 3 |
| normal | 0.25 | 12 | 5 |
| normal | 0.5 | 2 | 2 |

## Best Selected Designs

| family | tau | resolved_screening_profile_id | stage | run_tag | forecast_mae_ratio | forecast_check_ratio | fit_rmse_ratio | max_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gausmix | 0.5 | tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.368 | 0.934 | 0.090 | 0.934 |
| gausmix | 0.25 | tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue | qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628 | 0.480 | 0.942 | 0.103 | 0.942 |
| gausmix | 0.25 | tt500vb_f3_d2_n20_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue | qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628 | 0.418 | 0.945 | 0.102 | 0.945 |
| gausmix | 0.25 | tt500vb_f3_d2_n20_a0p03_r0p5_m15_lag15_rl0_pw0p05_pin0p8 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue | qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628 | 0.560 | 0.946 | 0.106 | 0.946 |
| laplace | 0.25 | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.361 | 0.948 | 0.113 | 0.948 |
| gausmix | 0.25 | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue | qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628 | 0.635 | 0.950 | 0.100 | 0.950 |
| gausmix | 0.25 | tt500vb_f3_d1_n30_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue | qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628 | 0.582 | 0.951 | 0.110 | 0.951 |
| laplace | 0.05 | tt500vb_tref_d1_n40_a0p4_r0p9_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement | qdesn-tt500-vb-targeted-refinement-full-20260626 | 0.392 | 0.957 | 0.318 | 0.957 |
| laplace | 0.05 | tt500vb_ftgt_d1_n40_a0p4_r0p9_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.392 | 0.957 | 0.318 | 0.957 |
| laplace | 0.05 | tt500vb_hcell_d1_n40_a0p4_r0p9_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement | qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627 | 0.392 | 0.957 | 0.318 | 0.957 |
| laplace | 0.05 | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.367 | 0.957 | 0.298 | 0.957 |
| laplace | 0.25 | tt500vb_ftgt_d1_n40_a0p1_r0p7_m30_lag30_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.574 | 0.957 | 0.159 | 0.957 |
| laplace | 0.05 | tt500vb_tref_d2_n30_a0p2_r0p8_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement | qdesn-tt500-vb-targeted-refinement-full-20260626 | 0.382 | 0.958 | 0.308 | 0.958 |
| gausmix | 0.05 | tt500vb_tref_d2_n20_a0p3_r0p85_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement | qdesn-tt500-vb-targeted-refinement-full-20260626 | 0.640 | 0.958 | 0.192 | 0.958 |
| gausmix | 0.05 | tt500vb_dom_d2_n20_a0p3_r0p85_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_dominance | qdesn-tt500-vb-dominance-period90-broad-leadfix-20260626__git-f700322 | 0.640 | 0.958 | 0.192 | 0.958 |
| gausmix | 0.05 | tt500vb_ftgt_d2_n20_a0p3_r0p85_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.640 | 0.958 | 0.192 | 0.958 |
| gausmix | 0.05 | tt500vb_hcell_d2_n20_a0p3_r0p85_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement | qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627 | 0.640 | 0.958 | 0.192 | 0.958 |
| laplace | 0.25 | tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.503 | 0.959 | 0.116 | 0.959 |
| gausmix | 0.5 | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.826 | 0.959 | 0.085 | 0.959 |
| laplace | 0.5 | tt500vb_ftgt_d1_n40_a0p1_r0p7_m30_lag30_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.747 | 0.960 | 0.133 | 0.960 |
| laplace | 0.25 | tt500vb_ftgt_d1_n30_a0p4_r0p9_m30_lag30_rl0_pw0p1_pin0p5 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.502 | 0.960 | 0.174 | 0.960 |
| gausmix | 0.05 | tt500vb_tref_d2_n40_a0p1_r0p7_m90_lag90_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement | qdesn-tt500-vb-targeted-refinement-full-20260626 | 0.648 | 0.961 | 0.187 | 0.961 |
| laplace | 0.25 | tt500vb_ftgt_d1_n30_a0p3_r0p85_m30_lag30_rl0_pw0p1_pin0p5 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.509 | 0.962 | 0.169 | 0.962 |
| laplace | 0.5 | tt500vb_ftgt_d1_n40_a0p2_r0p8_m30_lag30_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.774 | 0.969 | 0.141 | 0.969 |
| normal | 0.25 | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue | qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628 | 0.708 | 0.973 | 0.116 | 0.973 |
| laplace | 0.5 | tt500vb_ftgt_d1_n30_a0p2_r0p8_m30_lag30_rl0_pw0p1_pin0p5 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.744 | 0.973 | 0.136 | 0.973 |
| normal | 0.05 | tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.735 | 0.974 | 0.134 | 0.974 |
| laplace | 0.5 | tt500vb_ftgt_d1_n30_a0p3_r0p85_m30_lag30_rl0_pw0p1_pin0p5 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.781 | 0.976 | 0.142 | 0.976 |
| laplace | 0.5 | tt500vb_ftgt_d1_n50_a0p2_r0p8_m30_lag30_rl0_pw0p05_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted | qdesn-tt500-vb-forecast-targeted-full-20260628 | 0.803 | 0.976 | 0.148 | 0.976 |
| normal | 0.05 | tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3 | qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer | qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631 | 0.797 | 0.977 | 0.134 | 0.977 |

## Gates

1. The selected profiles must resolve to committed profile rows with no selected design conflicts.
2. The materialized handoff must use the current frozen source registry and rolling-origin protocol.
3. The first compute stage is VB-only under `exal` + `rhs_ns`, matching the older winning evidence.
4. MCMC promotion requires a fresh current-protocol dominance table with all four primary ratios below 1 for the target cell.
5. Article tables must not change from this diagnostic handoff unless the handoff completes, strict audit passes, and promotion evidence is explicitly frozen.

## Output Artifacts

- ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_handoff_ledger_20260709.csv`
- selected_designs: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_handoff_selected_designs_20260709.csv`
- profile_resolution_audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_profile_resolution_audit_20260709.csv`
- profile_conflicts: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_profile_conflicts_20260709.csv`
- cell_coverage: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_cell_coverage_20260709.csv`
- stage_summary: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_stage_summary_20260709.csv`
- unresolved_profiles: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_historical_winner_unresolved_profiles_20260709.csv`

## Current-Protocol Materialization

- profiles: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff_profiles.csv`
- assignments: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff_cell_assignments.csv`
- defaults: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff_defaults.yaml`
- grid: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff_grid.csv`
- materialization_manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff_materialization_manifest.json`
- expected current-protocol roots: `40`
- likelihood: `exal`
- prior: `rhs_ns`
- rolling-origin stride: `30`

## Prepare/Smoke Evidence

Prepare-only command:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_historical_winner_handoff.R \
  --skip-mine --skip-materialize --prepare-only --workers 20 --likelihoods exal --stamp 20260709 \
  --run-tag qdesn-vb-historical-winner-handoff-prepare-20260709__git-b1980bd \
  --orchestrator-tag qdesn-vb-historical-winner-handoff-prepare-orchestrator-20260709__git-b1980bd
```

Smoke command:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_historical_winner_handoff.R \
  --skip-mine --skip-materialize --smoke --workers 20 --likelihoods exal --stamp 20260709 \
  --run-tag qdesn-vb-historical-winner-handoff-smoke-20260709__git-b1980bd \
  --orchestrator-tag qdesn-vb-historical-winner-handoff-smoke-orchestrator-20260709__git-b1980bd
```

Smoke health evidence:

- orchestrator manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_tt500_vb_historical_winner_handoff/qdesn-vb-historical-winner-handoff-smoke-orchestrator-20260709__git-b1980bd/manifest/orchestrator_manifest.json`
- healthcheck: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_historical_winner_handoff/qdesn-vb-historical-winner-handoff-smoke-20260709__git-b1980bd-smoke/launch/qdesn_dynamic_exdqlm_crossstudy_healthcheck.md`
- root status: `SUCCESS=1`, `RUNNING=0`, `FAIL=0`
- index alignment: `PASS=1`
- retained heavy artifacts: `0`
- forecast horizon summary rows: `2`
- fit signoff: `FAIL=1`, expected for smoke because the smoke launcher uses intentionally tiny VB iteration controls to validate wiring rather than scientific convergence.

## Next Gate

Launch the full current-protocol VB handoff only after confirming the committed clean git SHA. The full launch must use both `--full` and `--launch-approved`; this stage still does not run MCMC.

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_historical_winner_handoff.R \
  --skip-mine --skip-materialize --full --launch-approved --workers 20 --likelihoods exal --stamp 20260709 \
  --run-tag qdesn-vb-historical-winner-handoff-full-20260709__git-<SHORT_SHA> \
  --orchestrator-tag qdesn-vb-historical-winner-handoff-full-orchestrator-20260709__git-<SHORT_SHA>
```

Promote any design to MCMC only after the full VB handoff produces a fresh current-protocol dominance audit showing all-primary wins for the relevant family/quantile cells.
