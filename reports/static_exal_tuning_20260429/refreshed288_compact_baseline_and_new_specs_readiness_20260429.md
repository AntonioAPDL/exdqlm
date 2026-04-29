# Refreshed288 Compact Baseline And New-Spec Launch Readiness

Date: 2026-04-29

Branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`

## Decision

The retained baseline anchor for future validation comparisons is:

- run tag: `20260422_p90_full288_baseline_v1`
- run root: `tools/merge_reports/full288_refreshed288_20260422_p90_full288_baseline_v1`
- role: historical p90 full-288 baseline and comparison anchor

Future validation launches should not repeat the old full-fit retention pattern. The default forward path is:

- retention mode: `comparison_plus_plot`
- keep: configs, row status, health, metrics, comparison tables, plot summaries, static parameter summaries, logs, manifests, and docs
- do not keep by default: full fit binaries, raw posterior draw exports, cached MCMC VB-init fits
- keep MCMC VB initialization behavior, but use memory-only VB-init unless explicitly debugging

## Why

The previous full run produced a valid comparison surface, but its full fit binaries were oversized intermediate artifacts. The comparison analysis already runs from lightweight CSVs, and fitted-quantile plots can be supported by compact per-observation summaries rather than every posterior draw.

The new baseline retention contract preserves what we need for:

- MCMC vs VB comparisons
- exAL/exDQLM vs AL/DQLM comparisons
- family, quantile, and sample-size summaries
- fitted quantile plots with uncertainty bands
- static coefficient and variable-selection summaries
- reproducible reruns and health checks

## Implemented Changes

New/updated implementation targets:

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_run_row_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_evaluate_20260422_p90_full288.R`
- `tools/merge_reports/LOCAL_refreshed288_heavy_binary_cleanup_manifest_20260428.R`
- `tools/merge_reports/LOCAL_refreshed288_extract_lightweight_summaries_20260428.R`
- `tests/testthat/test-refreshed288-lightweight-retention.R`

Main behavior changes:

- Added `plot_summaries`, `parameter_summaries`, `predictive_quantile_grid`, and `retention_audit` run directories.
- Added retention modes: `comparison_only`, `comparison_plus_plot`, `comparison_plus_draws`, `debug_failures`, and `archive_full`.
- Made `comparison_plus_plot` the default future-launch mode.
- Added compact plot-summary builders for fitted quantiles, posterior predictive bands, coverage, interval width, and absolute quantile error.
- Added static parameter-summary builders for beta, sigma, and gamma posterior summaries.
- Fixed future dynamic-row construction to prefer windowed `series_wide_path` and `true_quantile_grid_path`, with a hard assertion that dynamic row length equals intended `fit_size`.
- Changed MCMC VB-init caching default to memory-only.
- Made candidate fit and draw export writing retention-aware instead of unconditional.
- Added evaluator columns for retained fits/draws and missing lightweight summaries.
- Added cleanup deletion mode guarded by explicit confirmation.
- Added a resumable old-run extractor that writes lightweight summaries before deleting fit binaries.

## Current Cleanup Status

The old baseline cleanup is intentionally resumable and row-audited. It writes:

- `tools/merge_reports/full288_refreshed288_20260422_p90_full288_baseline_v1/retention_audit/lightweight_summary_extraction_full_deletefits_20260428.csv`

Important safety rules:

- a fit binary is deleted only after the required lightweight summary exists;
- dynamic rows require a plot summary;
- static rows require both a plot summary and a parameter summary;
- rows already summarized and deleted are recorded as `skipped_existing_summary` on resume;
- missing fit with missing summary is recorded as `missing_fit`, not silently ignored.

Observed cleanup status during this checkpoint:

- no extraction errors observed;
- dynamic full-fit binaries were reduced from the original hundreds of GB to compact plot summaries;
- no `.rds` / `.rda` file larger than `100M` remained in the repo at the audit point;
- free disk was restored to a safe range for new compact launches.

## New-Spec Launch Readiness

We are ready to prepare a new validation launch under new specs, with one important distinction:

- the current p90 full-288 run is the retained baseline/comparison anchor;
- the next launch should be a fresh run tag and should be treated as the improved publication-quality validation candidate.

Recommended next run tag:

- `20260429_p90_full288_compact_v2`

Recommended default contract:

- dynamic dataset: `dlm_constV_p90_m0amp_highnoise_steepertrend_v1`, unless the next task intentionally changes the DGP again
- dynamic fit sizes: `500`, `5000`, enforced from windowed CSV inputs
- static fit sizes: keep current paper/shrink contracts unless explicitly revised
- VB: `LDVB`, `max_iter = 300`, `min_iter_elbo = 80`, `n_samp_xi = 1000`
- MCMC: `slice`, `init_from_vb = TRUE`, `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`
- posterior draw scale: `20000` for MCMC/VB metric and synthesis surfaces
- warmups: automatic rhs/rhs_ns tau warmup plus light exAL sigma/gamma warmup
- retention: `comparison_plus_plot`

## Launch Gate For The Next Study

Before launching the full new-spec run:

1. Regenerate manifests/configs under the new run tag.
2. Confirm dynamic `fit_size=500` rows produce exactly 500 fitted observations.
3. Confirm dynamic `fit_size=5000` rows produce exactly 5000 fitted observations.
4. Run a smoke manifest spanning dynamic/static, VB/MCMC, baseline/exAL, low/mid/high quantiles.
5. Verify every completed smoke row has health, metrics, row status, plot summary, and static parameter summary when applicable.
6. Verify no full fit binary is written under `comparison_plus_plot`.
7. Only then launch the full 288 grid.

## Cleanup Policy Going Forward

Keep these as official baseline artifacts:

- current baseline lightweight run root;
- comparison CSVs and reports;
- configs, row status, health, metrics;
- compact plot and parameter summaries;
- manifests, logs, and docs.

Safe to remove after summary extraction:

- old full fit binaries;
- old cached VB-init binaries;
- old raw draw exports if not needed for a specific posterior-draw investigation.

Do not remove:

- configs;
- metrics;
- health;
- row status;
- comparison tables;
- compact summaries;
- launch/recovery logs;
- tracker docs.
