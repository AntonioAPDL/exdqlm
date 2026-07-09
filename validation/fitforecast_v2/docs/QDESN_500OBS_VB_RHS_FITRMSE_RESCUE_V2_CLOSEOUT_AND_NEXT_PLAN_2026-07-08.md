# Q-DESN 500-Observation VB Screen History Audit and Rescue-v2 Closeout

## Decision

Close `qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d` as a technically successful diagnostic screen, but do not promote its candidates to MCMC and do not update article tables from this run.

The screen completed cleanly and is reproducible. Scientifically, it did not solve the remaining Q-DESN RHS bottleneck: no candidate-cell row beat the DQLM/exDQLM VB baseline on fit RMSE, and no profile passed all primary dominance criteria.

## Current Rescue-v2 Evidence

- Report root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d`
- Dominance cells: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d/tables/qdesn_tt500_vb_dominance_cell_summary.csv`
- Profile ranking: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d/tables/qdesn_tt500_vb_dominance_profile_ranking.csv`
- Strict audit: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d/audit/tables/qdesn_tt500_vb_screen_audit_summary.csv`
- Expected roots: `172`
- Observed roots: `172`
- Success roots: `172`
- Failed roots: `0`
- Strict ready: `TRUE`
- Forbidden final binary payloads: `0` files / `0` bytes

## Rescue-v2 Dominance Counts

| Criterion | Count |
|---|---:|
| Candidate-cell rows | 98 |
| Profiles ranked | 66 |
| Profiles with dominance_pass | 0 |
| Beat forecast MAE baseline | 44 |
| Beat forecast check-loss baseline | 38 |
| Beat fit RMSE baseline | 0 |
| Beat fit check-loss baseline | 7 |
| Beat all primary baselines | 0 |

## Best Rescue-v2 Cell Rows

| Family | Tau | Best profile | Forecast MAE ratio | Forecast check ratio | Fit RMSE ratio | Fit check ratio | Max ratio |
|---|---:|---|---:|---:|---:|---:|---:|
| gausmix | 0.05 | `tt500vb_ftgt_d3_n10_a0p05_r0p6_m10_lag10_rl0_pw0p005_pin0p1` | 0.656 | 0.976 | 1.743 | 1.052 | 1.743 |
| gausmix | 0.25 | `tt500vb_ftgt_d2_n15_a0p0015_r0p2_m15_lag15_rl0_pw0p03_pin0p3` | 0.488 | 0.957 | 1.820 | 1.027 | 1.820 |
| gausmix | 0.50 | `tt500vb_ftgt_d3_n10_a0p0015_r0p2_m15_lag15_rl0_pw0p005_pin0p1` | 1.245 | 1.007 | 1.431 | 1.033 | 1.431 |
| laplace | 0.05 | `tt500vb_ftgt_d2_n20_a0p005_r0p25_m15_lag15_rl0_pw0p05_pin0p5` | 1.031 | 1.019 | 1.697 | 1.049 | 1.697 |
| laplace | 0.25 | `tt500vb_ftgt_d1_n15_a0p0015_r0p2_m15_lag15_rl0_pw0p01_pin0p2` | 0.854 | 0.999 | 1.272 | 1.035 | 1.272 |
| laplace | 0.50 | `tt500vb_rhsfit1_d1_n10_a0p00075_r0p1_m15_lag15_rl0_pw0p005_pin0p1` | 1.025 | 1.003 | 1.272 | 1.037 | 1.272 |
| normal | 0.05 | `tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1.455 | 0.995 | 1.536 | 1.030 | 1.536 |
| normal | 0.25 | `tt500vb_ftgt_d1_n15_a0p0015_r0p2_m15_lag15_rl0_pw0p005_pin0p1` | 1.006 | 0.993 | 1.213 | 1.015 | 1.213 |
| normal | 0.50 | `tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3` | 1.908 | 1.017 | 1.403 | 1.000 | 1.908 |

## Historical Screen Diagnosis

The full history separates into two regimes:

- Older broad/non-current screens contain some candidate-cell rows that beat all four baseline criteria. These screens used wider search surfaces and some cells reached strong dominance, but they are not the current RHS rescue line and should not be blindly promoted without a fresh protocol-specific handoff.
- The recent RHS-focused line from July 4 onward is technically clean but has not produced a fit-RMSE win against the DQLM/exDQLM VB baseline. Rescue-v2 is the cleanest evidence for that failure mode.

### Recent RHS-Line Summary

| Stage | Run tag | Cells | Beat all | Beat fit RMSE | Min fit RMSE ratio | Min forecast MAE ratio |
|---|---|---:|---:|---:|---:|---:|
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization` | `qdesn-tt500-vb-rhs-optimization-full-20260704__git-65fbf35` | 432 | 0 | 0 | 1.224 | 0.440 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement` | `qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727` | 276 | 0 | 0 | 1.224 | 0.440 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad` | `qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c` | 1188 | 0 | 0 | 1.224 | 0.440 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue` | `qdesn-vb-rhs-fitforecast-rescue-20260707-144646__git-438a156` | 276 | 0 | 0 | 1.222 | 0.403 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup` | `qdesn-vb-rhs-fitfirst-followup-full-20260707-190614__git-17cf71b` | 104 | 0 | 0 | 1.213 | 0.477 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup` | `qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9` | 103 | 0 | 0 | 1.213 | 0.485 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue` | `qdesn-vb-rhs-fitrmse-rescue-full-20260708__git-c23e042` | 103 | 0 | 0 | 1.213 | 0.485 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement` | `qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0` | 276 | 0 | 0 | 1.213 | 0.488 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2` | `qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d` | 98 | 0 | 0 | 1.213 | 0.485 |

### Older Broad Screens With All-Criterion Wins

| Stage | Run tag | Cells | Beat all | Min fit RMSE ratio | Min forecast MAE ratio |
|---|---|---:|---:|---:|---:|
| `qdesn_dynamic_fitforecast_v2_tt500_vb_dominance` | `qdesn-tt500-vb-dominance-period90-broad-leadfix-20260626__git-f700322` | 648 | 122 | 0.163 | 0.382 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement` | `qdesn-tt500-vb-targeted-refinement-full-20260626` | 1080 | 218 | 0.168 | 0.382 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement` | `qdesn-tt500-vb-hardcell-forecast-refinement-full-20260627` | 324 | 67 | 0.169 | 0.382 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted` | `qdesn-tt500-vb-forecast-targeted-full-20260628` | 208 | 63 | 0.119 | 0.392 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue` | `qdesn-tt500-vb-stage3-forecast-bias-rescue-full-20260628` | 144 | 34 | 0.097 | 0.418 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer` | `qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631` | 12 | 9 | 0.085 | 0.361 |
| `qdesn_dynamic_fitforecast_v2_tt500_vb_stage4b_gausmix005_pinball_refinement` | `qdesn-tt500-vb-stage4b-gausmix005-pinball-full-20260629__git-52a1821` | 24 | 4 | 0.162 | 0.595 |

## Article Integration Decision

Do not update the Article-Q-DESN Version-2 tables from rescue-v2. The authoritative article table bundle already points to pinned final TT500 validation assets, and rescue-v2 does not dominate those assets or the DQLM/exDQLM VB baseline.

- Article root audited: `/data/jaguir26/local/src/Article-Q-DESN---Version-2`
- Article remote: `https://github.com/AntonioAPDL/Article-Q-DESN---Version-2.git`
- Article HEAD: `4cb0658e310ddc5f869d1481efef203ed9d46c86`
- Article origin/main: `4cb0658e310ddc5f869d1481efef203ed9d46c86`
- Article status: `## main...origin/main`

## Recommended Next Calibration Plan

1. Treat rescue-v2 as closed evidence, not as a launch queue.
2. Do not run MCMC from rescue-v2 candidates.
3. Mine the older broad screens with all-criterion wins to recover their exact cell-level designs, but require a new protocol-specific handoff before promotion.
4. If another Q-DESN RHS calibration is desired, build a small targeted VB handoff around the older all-criterion cells, constrained to the current frozen registry, rolling-origin contract, storage-light policy, and current article-facing metrics.
5. Promote to MCMC only after a fresh VB handoff produces at least one candidate per target cell that clears fit RMSE, fit check loss, forecast MAE, and forecast check loss against the frozen DQLM/exDQLM VB baseline.

## Generated Artifacts

- History audit CSV: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_screen_history_audit_20260708.csv`
- Historical best-cell CSV: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_screen_history_best_cells_20260708.csv`
- Rescue-v2 best-cell CSV: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/qdesn_tt500_vb_rhs_fitrmse_rescue_v2_best_cells_20260708.csv`

## Reproduction Command

```bash
Rscript scripts/audit_qdesn_tt500_vb_screen_history.R \
  --current-report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d \
  --article-root /data/jaguir26/local/src/Article-Q-DESN---Version-2 \
  --out-dir validation/fitforecast_v2/docs
```
