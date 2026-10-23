# Completed standardized C1 evidence

The report and all three new 471-origin comparisons are complete. See
[../RESULTS.md](../RESULTS.md) for scores, exact priors, diagnostics, costs and
limitations. The original comparison remains unchanged in `rhs_comparison`.

- `AutoDESN_Standardized_RHS_C1_Report.pdf`: nine rendered and visually checked pages.
- `pooled_metrics.csv`, `horizon_metrics.csv`: all six model/reference summaries.
- `independent_diagnostics.csv`: actual monitored-parameter and model-indicator checks.
- `mcmc_budget_sensitivity.csv`: every completed budget, including failed attempts.
- `mc_sensitivity_summary.csv`: predictive-budget results on three fixed origins.
- `execution_status.json`: actual completion and release-check status.
- `*_forecast_checkpoint.rds`: 384 joint posterior draws per new model and required reservoir templates. Full latent-state paths are reconstructed, not substituted with predictive means.
- `frozen_feature_geometry.rds`: all 428 training-column transforms and masks.
- `Standardized_C1_numeric_evidence.zip.part-*`: 241 numeric/log/control files split into 18 parts, with all monitored scalar traces and complete primary score tables.

From a fresh checkout, restore and verify the numeric evidence:

```bash
python validation/autodesn/standardized_rhs/evidence/restore_evidence.py
python validation/autodesn/standardized_rhs/analysis.py --data validation/autodesn/standardized_rhs/evidence/restored
```

Restoration checks each part, the complete archive and every internal SHA256,
then validates gzip streams through EOF. The restored analysis was executed
successfully and reproduces the committed summary CSVs byte for byte. The
archive excludes unpublished exporter temporaries, huge inference designs and
full per-iteration coefficient vectors. Scripts and seeds rebuild those;
compact checkpoints preserve every joint draw used for primary forecasts and
predictive sensitivity. `deliverable_manifest.json` verifies the separate PDF
and RDS deliverables. No numerical job remains running in the background.

The work remains a draft PR because the package has inherited repository-wide
check failures documented in the report. Focused statistical and software
checks pass; they do not prove convergence. The large C1 fits separately passed
the declared parameter and architecture screens and independent rank/ESS
checks. One previously examined C1 series cannot establish general superiority.
