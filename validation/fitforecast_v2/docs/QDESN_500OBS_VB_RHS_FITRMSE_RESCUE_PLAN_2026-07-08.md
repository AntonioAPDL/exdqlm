# Q-DESN 500-Observation VB RHS Fit-RMSE Rescue Plan

Date: 2026-07-08

## Scope

This note is restricted to the shared Q-DESN plus exDQLM/DQLM fit+forecast validation worktree:

`/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0`

It does not modify Article-Q-DESN, PriceFM, GloFAS, joint-QVP, or any other active project.

## Current Evidence

The frozen VB calibration resume evidence is:

`validation/fitforecast_v2/promotions/vb_calibration_resume_evidence_20260708/`

The evidence confirms:

- exDQLM/DQLM VB calibration resume: 648/648 complete.
- Q-DESN RHS VB fit-first follow-up: 344/344 complete.
- No Q-DESN RHS family/tau cell is yet all-primary dominant.
- The main remaining bottleneck is fit RMSE, not run completion.

The Q-DESN cells requiring follow-up are the nine family/tau combinations for `normal`, `laplace`, and `gausmix` at tau `0.05`, `0.25`, and `0.50`.

## Storage Cleanup

A conservative cleanup removed only old validation-owned heavy payloads from legacy run directories under:

`validation/fitforecast_v2/runs/`

The cleanup explicitly did not remove current July 8 exDQLM/DQLM handoff files, source files, promoted outputs, logs, manifests, tables, or reproducibility metadata.

Cleanup evidence:

- Manifest: `validation/fitforecast_v2/local_trackers/storage_cleanup_20260708/legacy_heavy_payload_delete_manifest.csv`
- Summary: `validation/fitforecast_v2/local_trackers/storage_cleanup_20260708/legacy_heavy_payload_cleanup_summary.txt`

## Rescue Stage

New stage file stem:

`qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue`

Purpose:

- Run a compact VB-only screen for Q-DESN RHS AL and exAL.
- Prioritize lower fit RMSE while retaining the same rolling-origin forecast protocol.
- Keep the stage separate from previous completed fit-first evidence.
- Avoid MCMC until the VB winner is strong enough to promote.

Default materialization inputs:

- Source report root:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9/20260708-023545__git-8e7d3a9`
- Source fit+forecast summary:
  `reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9/20260708-023545__git-8e7d3a9/tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv`
- Current validation baseline:
  `validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv`

## Guardrails

- VB-only.
- Q-DESN RHS only.
- Fit size 500 only.
- Family/tau targeted to the nine unresolved validation cells.
- No Article-Q-DESN modifications.
- No MCMC launch from this stage without a separate promotion decision.
- Full launch output remains storage-light: scalar metrics, compact summaries, configs, manifests, logs, and status files.

## Commands

Materialize the stage:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/materialize_qdesn_tt500_vb_rhs_fitfirst_followup.R \
  --stage-file qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue \
  --stage-name rhs_fitrmse_rescue \
  --stage-desc "Q-DESN 500-observation VB RHS fit-RMSE rescue screen over unresolved dominance cells." \
  --report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9/20260708-023545__git-8e7d3a9 \
  --fit-summary reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup/qdesn-vb-rhs-fitfirst-resume-full-20260708__git-8e7d3a9/20260708-023545__git-8e7d3a9/tables/qdesn_tt500_vb_screen_fit_forecast_summary.csv \
  --baseline validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv \
  --base-defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup_defaults.yaml \
  --workers 20 \
  --max-profiles-per-cell 32 \
  --max-p-over-n 0.35 \
  --screening-wave rhs_fitrmse_rescue_2026_07_08
```

Run the stage after materialization and preflight checks:

```sh
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
  --defaults config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_defaults.yaml \
  --grid config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_grid.csv \
  --batch full \
  --methods vb \
  --likelihoods al,exal \
  --fit-sizes 500 \
  --priors rhs_ns \
  --allow-grid-subset \
  --workers 20 \
  --scheduler load_balanced \
  --run-tag qdesn-vb-rhs-fitrmse-rescue-full-20260708
```

## Promotion Rule

Do not promote this stage as article-facing evidence unless it improves the unresolved Q-DESN RHS cells against current best DQLM/exDQLM VB baselines under the shared validation protocol. A later MCMC launch should use only a documented VB winner or small family/tau-specific winner set.
