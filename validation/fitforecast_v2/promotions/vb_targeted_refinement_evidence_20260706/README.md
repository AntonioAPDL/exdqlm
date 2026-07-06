# Targeted VB Refinement Evidence Freeze

Date: 2026-07-06

## Scope

This directory freezes the latest targeted VB refinement evidence for planning the next validation screen. It is diagnostic evidence, not an article-authoritative replacement table.

## Evidence Roots

- exDQLM/DQLM tau = 0.05 refinement: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260706_exdqlm_dqlm_vb_tau005_refinement__git-0d22ebc`
- Q-DESN RHS fit-aware refinement: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement/qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727/20260706-024112__git-0d22ebc`
- exDQLM/DQLM status counts: `done=120`
- exDQLM/DQLM storage audit status: `PASS`
- Q-DESN strict-ready flags: `TRUE`

## Decision Summary

- exDQLM/DQLM tau = 0.05 still needs calibration: exDQLM remains worse than DQLM in at least one primary metric in each tau = 0.05 family.
- Q-DESN RHS fit-aware refinement improved forecast/check behavior, but fit RMSE remains the active bottleneck; no Q-DESN RHS profile cleanly dominates all primary VB baselines.
- The next Q-DESN screen should be fit-balanced and period-aware rather than only forecast-targeted.
- Internal legacy column names may use `pinball`; manuscript-facing language should call the metric check loss.

## exDQLM/DQLM tau = 0.05 Ratios

| Family | exDQLM/DQLM check | exDQLM/DQLM MAE | exDQLM/DQLM fit RMSE |
| --- | ---: | ---: | ---: |
| gausmix | 1.155 | 1.882 | 2.112 |
| laplace | 1.153 | 3.166 | 1.892 |
| normal | 1.028 | 1.970 | 1.203 |

## Q-DESN RHS Cells Still Failing At Least One Primary Metric

| Family | Tau | Best check-loss profile | Check ratio | Forecast MAE ratio | Fit RMSE ratio |
| --- | ---: | --- | ---: | ---: | ---: |
| gausmix | 0.05 | tt500vb_ftgt_d1_n50_a0p2_r0p8_m30_lag30_rl0_pw0p05_pin0p3 | 0.974 | 0.751 | 2.416 |
| gausmix | 0.25 | tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3 | 0.954 | 0.440 | 1.844 |
| gausmix | 0.50 | tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3 | 0.990 | 0.776 | 1.454 |
| laplace | 0.05 | tt500vb_ftgt_d1_n40_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3 | 1.018 | 1.015 | 1.705 |
| laplace | 0.25 | tt500vb_ftgt_d1_n40_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3 | 0.996 | 0.792 | 1.291 |
| laplace | 0.50 | tt500vb_ftgt_d2_n20_a0p005_r0p25_m30_lag30_rl0_pw0p05_pin0p3 | 0.994 | 0.995 | 1.604 |
| normal | 0.05 | tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | 0.995 | 1.455 | 1.536 |
| normal | 0.25 | tt500vb_ftgt_d1_n20_a0p005_r0p25_m15_lag15_rl0_pw0p03_pin0p3 | 0.987 | 0.905 | 1.224 |
| normal | 0.50 | tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | 1.017 | 1.908 | 1.403 |

## Generated Files

- promotion ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_targeted_refinement_evidence_20260706/promotion_decision_ledger.csv`
- exDQLM/DQLM ratios: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_targeted_refinement_evidence_20260706/exdqlm_dqlm_tau005_vb_cell_ratios.csv`
- Q-DESN best check-loss cells: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_targeted_refinement_evidence_20260706/qdesn_rhs_fitaware_vb_best_cells_by_check_loss.csv`
- Q-DESN best fit-RMSE cells: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_targeted_refinement_evidence_20260706/qdesn_rhs_fitaware_vb_best_cells_by_fit_rmse.csv`
- file manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_targeted_refinement_evidence_20260706/file_manifest.csv`

## Next Authorized Screening

1. Run a Q-DESN RHS VB fit-balanced broad screen with period-aware readout memory.
2. Continue exDQLM/DQLM VB calibration separately before any broad MCMC promotion.
3. Do not promote these diagnostic rows as final article evidence without an explicit freeze/signoff.
