# Q-DESN 500-Observation VB RHS Fit-RMSE Rescue v2

## Scope

This document defines the next validation-only Q-DESN RHS VB calibration screen for the shared Q-DESN + exDQLM/DQLM fit+forecast benchmark. It does not alter article logic and does not promote any new MCMC run.

## Source Evidence

- Worktree: `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`
- Branch: `validation/shared-fitforecast-v2-1.0.0`
- Source commit: `93cbef0`
- Completed run tag: `qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0`
- Report root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement/qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0/20260708-171753__git-93cbef0`
- Result root:
  `/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement/qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0/20260708-171753__git-93cbef0`
- Frozen VB baseline:
  `validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv`

The source run is technically valid: 276/276 roots succeeded, 552/552 VB fits succeeded, rolling-origin forecast outputs were present, storage-light audit passed, and the strict audit reported `strict_ready=TRUE`.

## Diagnosis

The current fit-aware screen is a good diagnostic screen, but it is not promotion-ready. Across the dominance table:

- 52 candidate-cell rows beat the VB baseline on rolling forecast MAE.
- 35 candidate-cell rows beat the VB baseline on rolling forecast check loss.
- 137 candidate-cell rows beat the VB baseline on fit check loss.
- 0 candidate-cell rows beat the VB baseline on fit RMSE.
- 0 of 9 family x tau cells had any candidate beating all primary metrics.

The dominant bottleneck is fit RMSE in 8 of 9 cells. The normal tau 0.50 cell is additionally forecast-MAE limited after fit improves.

## Scientific Decision

Do not promote the current RHS candidates to MCMC. MCMC should be launched only after a VB screen identifies cell-level candidates that clear fit RMSE against the frozen DQLM/exDQLM VB baseline while preserving rolling-origin forecast check loss and forecast MAE.

The v2 screen is therefore a fit-RMSE rescue, not a broad exploratory replacement. It should:

- keep the same frozen source registry and rolling-origin forecast contract;
- use compact reservoirs and bounded p/n;
- include AL and exAL for every selected root;
- prioritize smaller memory/readout settings, low-alpha/low-rho anchors, and RHS tau0 robustness;
- exclude the previously unstable `tau0 = 3e-5` surface;
- remain storage-light and failure-explicit;
- run prepare and smoke before any full launch.

## New Stage

- Stage file: `qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2`
- Stage name: `rhs_fitrmse_rescue_v2`
- Run tag prefix: `qdesn-vb-rhs-fitrmse-rescue-v2`
- Materializer:
  `scripts/materialize_qdesn_tt500_vb_rhs_fitfirst_followup.R`
- Orchestrator:
  `scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R`

The orchestrator is parameterized so this v2 stage is explicit and does not overwrite the previous fit-first follow-up stage.

## Implemented State

Implemented on July 8, 2026.

Generated config bundle:

- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_profiles.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_cell_assignments.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_defaults.yaml`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_grid.csv`
- `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_materialization_manifest.json`

Materialization evidence:

- Orchestrator root:
  `reports/qdesn_mcmc_validation/qdesn_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs_fitrmse_rescue_v2-orchestrator-20260708-204224__git-93cbef0`
- Materialization manifest:
  `config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2_materialization_manifest.json`
- Profiles: 113
- Selected roots: 172
- Expected VB fits with AL and exAL: 344
- Target cells:
  `gausmix:0.25`, `gausmix:0.05`, `laplace:0.05`, `normal:0.05`, `gausmix:0.50`, `normal:0.50`, `laplace:0.50`, `normal:0.25`, `laplace:0.25`

Prepare and smoke evidence:

- Orchestrator root:
  `reports/qdesn_mcmc_validation/qdesn_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs_fitrmse_rescue_v2-orchestrator-20260708-204545__git-93cbef0`
- Orchestrator manifest:
  `reports/qdesn_mcmc_validation/qdesn_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs_fitrmse_rescue_v2-orchestrator-20260708-204545__git-93cbef0/manifest/orchestrator_manifest.json`
- Run tag:
  `qdesn-vb-rhs_fitrmse_rescue_v2-20260708-204545__git-93cbef0`
- Prepare status: 0
- Smoke status: 0
- Full status: not run
- Launch approved: false

Validation checks run:

- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-forecast-targeted-screen.R')"`: 36/36 passed.
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-rhs-fitforecast-rescue.R')"`: 17/17 passed.
- `Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-qdesn-tt500-vb-rhs-fitfirst-followup.R')"`: 23/23 passed.
- V2 config audit: 172 grid rows, all stage labels are `vb_rhs_fitrmse_rescue_v2`, no active `/home/jaguir26/local/src` paths, no Article-Q-DESN paths, train window 8501:9000, forecast window 9001:10000.
- Storage-light audit for v2 prepare/smoke paths: 0 `.rds`, `.rda`, or `.RData` payloads.

## Implementation Commands

Materialize only:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2 \
  --stage-name rhs_fitrmse_rescue_v2 \
  --stage-desc "Q-DESN 500-observation VB RHS fit-RMSE rescue v2 from the completed current fit-aware screen." \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement/qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0/20260708-171753__git-93cbef0 \
  --fit-summary reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement/qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0/20260708-171753__git-93cbef0/tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv \
  --baseline validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv \
  --base-defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement_defaults.yaml \
  --workers 20 \
  --max-profiles-per-cell 24 \
  --max-p-over-n 0.30 \
  --materialize-only
```

Prepare and smoke:

```bash
Rscript scripts/orchestrate_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2 \
  --stage-name rhs_fitrmse_rescue_v2 \
  --stage-desc "Q-DESN 500-observation VB RHS fit-RMSE rescue v2 from the completed current fit-aware screen." \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement/qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0/20260708-171753__git-93cbef0 \
  --fit-summary reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement/qdesn-vb-rhs-current-fitaware-full-20260708__git-93cbef0/20260708-171753__git-93cbef0/tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv \
  --baseline validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv \
  --base-defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement_defaults.yaml \
  --workers 20 \
  --max-profiles-per-cell 24 \
  --max-p-over-n 0.30 \
  --smoke
```

Full launch is gated and requires both `--full` and `--launch-approved`.

## Promotion Criteria

After a full v2 VB screen, run:

```bash
Rscript scripts/rank_qdesn_tt500_vb_screen.R --report-root <run_root> --top-n 40
Rscript scripts/rank_qdesn_tt500_vb_dominance_screen.R --report-root <run_root> --baseline validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv --top-n 40
Rscript scripts/audit_qdesn_tt500_vb_dominance_screening.R --report-root <run_root> --results-root <result_root> --expected-roots <expected_roots> --strict --require-rankings --allow-failed-candidates
```

Promote to MCMC only if the strict audit passes and at least one candidate per family x tau cell clears fit RMSE, fit check, forecast MAE, and forecast check loss against the frozen VB baseline.
