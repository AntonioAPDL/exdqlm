# VB Calibration Resume Evidence, 2026-07-08

## Scope

This directory freezes the completed July 8 VB calibration evidence for the shared Q-DESN + exDQLM/DQLM fit+forecast validation study. It is a diagnostic and candidate-selection evidence package. It is not, by itself, an article-authoritative promotion and it does not authorize MCMC launch.

## Health Check

| Component | Completed | Status | Notes |
| --- | ---: | --- | --- |
| exdqlm_dqlm_vb_calibration_resume | 648/648 | complete | 18 model/family/tau cells; 36 candidates per cell expected |
| qdesn_rhs_vb_fitfirst_followup | 344/344 | complete | signoff PASS=322; WARN=22; campaign_completed=TRUE |
| validation_git_worktree |  | clean_and_pushed_at_materialization_input | source commit in run evidence: 8e7d3a919dcd9b02c63e7096537ba28bddf50bdf |

## Main Diagnosis

- The current exDQLM/DQLM VB calibration resume is complete and suitable for objective-specific candidate selection.
- The current Q-DESN RHS VB fit-first follow-up is complete, with all rows successful but 22 WARN signoffs.
- Q-DESN RHS forecast metrics are often competitive, but the fit-RMSE criterion remains the blocker: no family/tau cell beats all primary baselines.
- MCMC should be launched only after selecting candidates by a declared objective, or after one more targeted Q-DESN fit-RMSE rescue if all-metric dominance is required.
- The disk state is tight: `/data` reported `/dev/md0        916G  835G   35G  97% /data`. Cleanup should be approved separately and limited to completed-run heavy handoff objects.

## Q-DESN Cells Requiring Follow-Up

| Family | Tau | Best forecast-check profile | Forecast check ratio | Fit RMSE ratio |
| --- | ---: | --- | ---: | ---: |
| gausmix | 0.05 | tt500vb_rhsfit1_d2_n15_a0p05_r0p6_m10_lag10_rl0_pw0p02_pin0p2 | 0.963 | 1.760 |
| gausmix | 0.25 | tt500vb_rhsfit1_d2_n15_a0p0015_r0p2_m15_lag15_rl0_pw0p05_pin0p3 | 0.957 | 1.820 |
| gausmix | 0.50 | tt500vb_rhsff_d1_n30_a0p005_r0p25_m15_lag15_rl0_pw0p02_pin0p2 | 0.981 | 1.462 |
| laplace | 0.05 | tt500vb_rhsfit1_d1_n10_a0p005_r0p3_m15_lag15_rl0_pw0p01_pin0p2 | 1.015 | 1.713 |
| laplace | 0.25 | tt500vb_rhsff_d1_n20_a0p0075_r0p3_m15_lag15_rl0_pw0p02_pin0p2 | 0.997 | 1.298 |
| laplace | 0.50 | tt500vb_ftgt_d2_n20_a0p005_r0p25_m30_lag30_rl0_pw0p05_pin0p3 | 0.994 | 1.604 |
| normal | 0.05 | tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | 0.995 | 1.536 |
| normal | 0.25 | tt500vb_rhsff_d1_n20_a0p0075_r0p3_m15_lag15_rl0_pw0p03_pin0p3 | 0.985 | 1.228 |
| normal | 0.50 | tt500vb_ftgt_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3 | 1.017 | 1.403 |

## Recommended Next Move

1. Use this evidence package to choose objective-specific VB winners.
2. If the scientific target is forecast/check-loss dominance, prepare a limited MCMC candidate set from the forecast-check winners.
3. If the scientific target is all-primary-metric dominance, run a targeted Q-DESN fit-RMSE screen before MCMC.
4. Run a read-only storage review, then approve deletion only for completed-run heavy handoff fit objects if MCMC initialization will not require them.

## Generated Files

- Health check: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/validation_health_check.csv`
- exDQLM/DQLM objective winners: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/exdqlm_dqlm_vb_objective_winners.csv`
- exDQLM/DQLM fit-check winners vs baseline: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/exdqlm_dqlm_vb_fitcheck_winners_vs_baseline.csv`
- exDQLM/DQLM pair ratios: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/exdqlm_dqlm_vb_forecastcheck_pair_ratios.csv`
- Q-DESN objective winners: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/qdesn_rhs_vb_objective_winners.csv`
- Q-DESN dominance counts: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/qdesn_rhs_vb_dominance_counts.csv`
- Q-DESN follow-up cells: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/qdesn_rhs_vb_cells_requiring_followup.csv`
- Decision ledger: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/decision_ledger.csv`
- Storage cleanup dry run: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/storage_cleanup_dry_run.csv`
- File manifest: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/file_manifest.csv`

## Active Validation Sessions Observed During Materialization

- None matching the current July 8 validation run tags.

## Reproducibility

- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Commit: `8e7d3a919dcd9b02c63e7096537ba28bddf50bdf`
- Dirty while materializing package: `TRUE`
- Note: this field can be `TRUE` while this script is creating the evidence package; the authoritative run evidence itself points to the validation commit listed above.
- exDQLM/DQLM run root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/runs/20260708_exdqlm_dqlm_vb_calibration_resume__git-8e7d3a9`
- Q-DESN report root: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9/20260708-023545__git-8e7d3a9`
- Baseline table: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv`
