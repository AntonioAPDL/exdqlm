# Q-DESN 500-Observation VB RHS Current Fit-Aware Refinement Plan

Date: 2026-07-08

## Scope

This plan belongs only to the shared Q-DESN plus exDQLM/DQLM validation worktree:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

It does not touch Article-Q-DESN, PriceFM, GloFAS, joint-QVP, or any unrelated project.

## Evidence Being Used

The immediate input is the completed Q-DESN RHS fit-RMSE rescue screen:

`reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue/qdesn-vb-rhs-fitrmse-rescue-full-20260708__git-c23e042/20260708-135526__git-c23e042`

Key evidence files:

- `tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- `tables/qdesn_tt500_vb_dominance_cell_summary.csv`
- `tables/qdesn_tt500_vb_dominance_profile_ranking.csv`
- `audit/tables/qdesn_tt500_vb_screen_audit_summary.csv`

The strict audit passed:

- expected roots: 172
- observed roots: 172
- successes: 172
- failures: 0
- lead metrics: pass
- rolling paths: pass
- storage-light policy: pass
- forbidden binary payloads: 0

## Diagnosis

The completed rescue screen is mechanically clean but not scientifically promotable.

No Q-DESN RHS profile beat all current DQLM/exDQLM VB primary baselines. The limiting metric is fit RMSE in every family/tau cell. Several forecast metrics are competitive or better, so the failure mode is not a broken forecast launcher; it is a fit-recovery/calibration bottleneck.

Best remaining worst ratios from the completed rescue:

| family | tau | best remaining worst ratio | primary bottleneck |
|---|---:|---:|---|
| gausmix | 0.05 | 1.743 | fit RMSE |
| gausmix | 0.25 | 1.820 | fit RMSE |
| gausmix | 0.50 | 1.431 | fit RMSE |
| laplace | 0.05 | 1.697 | fit RMSE |
| laplace | 0.25 | 1.272 | fit RMSE |
| laplace | 0.50 | 1.272 | fit RMSE |
| normal | 0.05 | 1.536 | fit RMSE |
| normal | 0.25 | 1.213 | fit RMSE |
| normal | 0.50 | 1.908 | forecast MAE and fit RMSE |

## Decision

Do not launch Q-DESN RHS MCMC from the completed fit-RMSE rescue. The next step is a VB-only current-evidence fit-aware refinement screen.

This stage intentionally:

- reuses the tested fit-aware materialization machinery;
- creates a new stage namespace, so older July 6 configs are not overwritten;
- targets the nine unresolved family/tau cells;
- keeps the run VB-only and RHS-only;
- uses current July 8 rescue outputs as the evidence source;
- remains screening-only until a separate promotion decision.

## Stage

Stage file stem:

`qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement`

Run tag:

`qdesn-vb-rhs-current-fitaware-full-20260708`

Default materialization settings:

- workers: 20
- max p/n: 0.35
- priors: `rhs_ns`
- methods: `vb`
- likelihoods: `al,exal`
- fit size: 500
- rolling-origin protocol: unchanged

## Commands

Materialize:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/materialize_qdesn_tt500_vb_rhs_fitaware_refinement.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement \
  --stage-name rhs_current_fitaware_refinement \
  --stage-desc "Q-DESN 500-observation VB RHS current-evidence fit-aware refinement over unresolved fit-RMSE cells." \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue/qdesn-vb-rhs-fitrmse-rescue-full-20260708__git-c23e042/20260708-135526__git-c23e042 \
  --cell-summary reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue/qdesn-vb-rhs-fitrmse-rescue-full-20260708__git-c23e042/20260708-135526__git-c23e042/tables/qdesn_tt500_vb_dominance_cell_summary.csv \
  --source-profiles config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_profiles.csv \
  --base-defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_defaults.yaml \
  --workers 20 \
  --max-p-over-n 0.35 \
  --screening-wave rhs_current_fitaware_2026_07_08
```

Prepare/smoke before full:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement_grid.csv \
  --batch smoke \
  --methods vb \
  --likelihoods al,exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --allow-grid-subset \
  --workers 1 \
  --scheduler sequential \
  --run-tag qdesn-vb-rhs-current-fitaware-smoke-20260708
```

Full launch, after materialize and smoke pass:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_current_fitaware_refinement_grid.csv \
  --batch full \
  --methods vb \
  --likelihoods al,exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --allow-grid-subset \
  --workers 20 \
  --scheduler load_balanced \
  --run-tag qdesn-vb-rhs-current-fitaware-full-20260708
```

## Promotion Rule

This stage is diagnostic until post-run ranking and strict audit pass. It may only feed a future MCMC launch if at least one family/tau-specific candidate materially improves the fit-RMSE ratios without damaging forecast check performance.

If no cell reaches near-parity with the best DQLM/exDQLM VB baseline, the next action should not be MCMC; it should be a model-specification audit of RHS shrinkage, feature scaling, readout target construction, and whether the Q-DESN fit metric is being compared on exactly the same target object as DQLM/exDQLM.
