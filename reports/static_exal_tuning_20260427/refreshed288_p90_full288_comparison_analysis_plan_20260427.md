# Refreshed288 p90 Full288 Comparison Analysis Plan

Date: 2026-04-27

Run tag: `20260422_p90_full288_baseline_v1`

## Purpose

Build the complete post-run comparison surface for the refreshed 0.4.0 validation study without rereading the large fit objects. The analysis is intentionally based on the finalized manifest status table and per-row metric summaries that were already produced during the relaunch.

## Inputs

- `tools/merge_reports/LOCAL_refreshed288_full_manifest_status_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_full_manifest_20260422_p90_full288_baseline_v1.csv`

The status table is the authoritative lightweight source for gates, health flags, runtime, and metrics. The manifest is used only to attach reproducibility paths such as configs, health CSVs, metrics CSVs, draw paths, and fit paths.

## Scope

- Full run size: `288` rows.
- Static rows: `216`.
- Dynamic rows: `72`.
- Scenario-wide tables: `54` static scenarios and `18` dynamic scenarios.
- Pairwise comparison tables: `108` static model pairs, `108` static inference pairs, `36` dynamic model pairs, and `36` dynamic inference pairs.

## Method

1. Build a canonical `comparison_long` dataset with one row per run case.
2. Generate compact summary tables by block, model, inference, method, family, tau, and prior semantics.
3. Generate broad scenario tables that align all method outputs within each scenario.
4. Generate model and inference pair comparisons:
   - static `exal` vs `al`;
   - static `mcmc` vs `vb`;
   - dynamic `exdqlm` vs `dqlm`;
   - dynamic `mcmc` vs `vb`.
5. Generate MCMC and VB diagnostics by method.
6. Generate explicit WARN and FAIL inventories.
7. Run an audit that enforces row counts, final health/gate counts, zero row-level runtime errors, zero metric errors, and zero row-level numerical errors.

## Scripts

- `tools/merge_reports/LOCAL_refreshed288_comparison_helpers_20260427.R`
- `tools/merge_reports/LOCAL_refreshed288_build_comparison_dataset_20260427.R`
- `tools/merge_reports/LOCAL_refreshed288_build_comparison_tables_20260427.R`
- `tools/merge_reports/LOCAL_refreshed288_comparison_audit_20260427.R`

## Reproducibility Commands

```bash
Rscript tools/merge_reports/LOCAL_refreshed288_build_comparison_dataset_20260427.R
Rscript tools/merge_reports/LOCAL_refreshed288_build_comparison_tables_20260427.R
Rscript tools/merge_reports/LOCAL_refreshed288_comparison_audit_20260427.R
```

## Design Notes

- The analysis does not read `.rds` fit objects.
- The analysis preserves candidate fit paths and row-level health/metric paths for traceability.
- Gate comparison ranks are ordered as `PASS > WARN > FAIL > MISSING`.
- Numerical failure reporting is based on row-level `error_current` and `metric_error`; the completed relaunch currently has no row-level hard errors or metric errors.
