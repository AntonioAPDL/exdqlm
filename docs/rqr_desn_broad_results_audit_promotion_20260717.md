# RQR-DESN Broad Results Audit And Promotion

Date: 2026-07-17

Status: package-side audit implementation. This does not authorize article
updates.

## Purpose

The results-audit pass converts a completed RQR-DESN broad simulation run into
decision artifacts:

- preflight gates for run completeness and model-contract health;
- paired model-versus-baseline deltas;
- calibration-aware MCMC winner map;
- coverage calibration summaries and flags;
- MCMC diagnostic summaries;
- VB sidecar caveats;
- stage-specific article-claim guardrails;
- targeted-confirmation candidate grid;
- recommendation about whether to proceed to targeted confirmation.

## Main Script

```text
scripts/audit_rqr_desn_broad_results_promotion.R
```

Example command:

```bash
/data/jaguir26/local/opt/R/4.6.0/bin/Rscript \
  scripts/audit_rqr_desn_broad_results_promotion.R \
  --run-dir reports/rqr_desn_broad_simulation/rqr_desn_broad_run_20260716-232550_git_3280ad377f99 \
  --output-dir reports/rqr_desn_broad_simulation/results_audit_promotion_20260717
```

The output directory is under `reports/rqr_desn_broad_simulation/`, which is
ignored by git.

## Interpretation Contract

The audit keeps the broad-run contract intact:

- the estimand is a central prediction interval;
- MCMC is the primary evidence lane;
- VB remains sidecar evidence unless separately calibrated;
- no response likelihood is claimed;
- no response predictive samples are generated;
- dynamic cases are teacher-forced DESN interval forecasts, not recursive
  response simulations;
- broad-run evidence can recommend targeted confirmation, but it does not by
  itself promote article text.

## Winner Rule

The audit uses interval score as the primary scoring target, but applies coverage
calibration as a selection constraint:

- green: absolute nominal coverage error <= 0.05;
- yellow: > 0.05 and <= 0.075;
- orange: > 0.075 and <= 0.10;
- red: > 0.10.

For each `stage_id x family_id x coverage_level` cell, the winner is the lowest
interval-score MCMC row among green/yellow candidates. If no green/yellow row is
available, the lowest-score row is selected and flagged for calibration repair or
confirmation.

## Key Outputs

```text
audit_preflight.csv
paired_model_baseline_deltas.csv
paired_delta_summary.csv
model_candidate_summary.csv
baseline_summary.csv
winner_map.csv
winner_map_calibration_notes.csv
coverage_calibration_by_replicate.csv
coverage_calibration_summary.csv
coverage_calibration_flags.csv
mcmc_diagnostic_summary.csv
mcmc_diagnostic_flags.csv
vb_sidecar_summary.csv
vb_vs_mcmc_delta.csv
vb_caveat_notes.md
stage_specific_claim_contract.csv
article_claim_guardrails.md
targeted_confirmation_candidate_grid.csv
promotion_recommendation.md
promotion_recommendation.json
audit_metadata.json
audit_input_hashes.csv
```

## Current Completed Run

The completed broad run audited by the first pass is:

```text
reports/rqr_desn_broad_simulation/rqr_desn_broad_run_20260716-232550_git_3280ad377f99
```

The audit output is:

```text
reports/rqr_desn_broad_simulation/results_audit_promotion_20260717
```

The first completed audit produced:

- 12 MCMC winner cells;
- 8 green and 4 yellow winner calibration labels;
- 0 MCMC diagnostic flags;
- recommendation: `promote_to_targeted_confirmation`;
- `article_update_allowed: FALSE`.

## Next Step

Use `targeted_confirmation_candidate_grid.csv` to freeze a smaller confirmation
run. Only after that targeted confirmation closes cleanly should RQR-DESN be
introduced in the article or supplement.
