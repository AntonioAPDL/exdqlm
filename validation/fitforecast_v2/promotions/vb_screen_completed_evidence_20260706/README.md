# Completed VB Screening Evidence Freeze

Date: 2026-07-06

## Scope

This freeze records the completed broad VB screens for exDQLM/DQLM and Q-DESN RHS. It is evidence for planning the next refinement, not a final article-authoritative promotion.

## Completed Evidence

- exDQLM/DQLM run root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260704_exdqlm_dqlm_vb_noninferiority_screen__git-65fbf35`
- Q-DESN RHS report root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization/qdesn-tt500-vb-rhs-optimization-full-20260704__git-65fbf35/20260704-091641__git-65fbf35`
- exDQLM/DQLM completed rows: `done=450`
- exDQLM/DQLM storage audit status: `PASS`
- Q-DESN strict ready: `TRUE`

## Diagnostic Interpretation

- exDQLM is competitive around tau = 0.25 and nearly tied around tau = 0.5, but the tau = 0.05 cells remain the targeted exDQLM/DQLM refinement problem.
- Q-DESN RHS VB completed cleanly, but no profile passes all primary dominance checks; fit RMSE is the most common bottleneck.
- Broad MCMC should wait until the refreshed VB evidence identifies stable, balanced candidates.

## exDQLM/DQLM tau = 0.05 Ratios

| Family | exDQLM/DQLM check | exDQLM/DQLM MAE | exDQLM/DQLM fit RMSE |
| --- | ---: | ---: | ---: |
| gausmix | 1.164 | 1.856 | 1.708 |
| laplace | 1.153 | 2.928 | 1.896 |
| normal | 1.037 | 2.110 | 1.157 |

## Q-DESN Cells Requiring Fit-Aware Follow-Up

| Family | Tau | Best profile | Forecast check ratio | Fit RMSE ratio |
| --- | ---: | --- | ---: | ---: |
| gausmix | 0.05 | tt500rhsopt_d1_n40_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 0.977 | 2.310 |
| gausmix | 0.25 | tt500rhsopt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 0.954 | 1.844 |
| gausmix | 0.50 | tt500rhsopt_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 0.982 | 1.659 |
| laplace | 0.05 | tt500rhsopt_d1_n40_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 1.014 | 1.742 |
| laplace | 0.25 | tt500rhsopt_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p05_pin0p5_tau0p0001_s123 | 0.992 | 1.379 |
| laplace | 0.50 | tt500rhsopt_d1_n20_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 0.994 | 1.350 |
| normal | 0.05 | tt500rhsopt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3_tau0p001_s123 | 0.995 | 1.536 |
| normal | 0.25 | tt500rhsopt_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 0.985 | 1.310 |
| normal | 0.50 | tt500rhsopt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3_tau0p0001_s123 | 1.017 | 1.403 |

## Generated Files

- exDQLM/DQLM winners: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_screen_completed_evidence_20260706/exdqlm_dqlm_vb_cell_winners.csv`
- exDQLM/DQLM ratios: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_screen_completed_evidence_20260706/exdqlm_dqlm_vb_cell_ratios.csv`
- Q-DESN best cells: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_screen_completed_evidence_20260706/qdesn_rhs_vb_best_cells_by_forecast_check.csv`
- Q-DESN top profiles: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_screen_completed_evidence_20260706/qdesn_rhs_vb_top_dominance_profiles.csv`
- file manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_screen_completed_evidence_20260706/file_manifest.csv`

## Next Authorized Refinements

1. exDQLM/DQLM VB tau = 0.05 refinement only.
2. Q-DESN RHS VB fit-aware refinement only.
3. No broad MCMC until those VB refinements have completed and been audited.
