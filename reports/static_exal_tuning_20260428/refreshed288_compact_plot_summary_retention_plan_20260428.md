# Refreshed288 Compact Plot Summary And Retention Plan

Date: 2026-04-28

Run reviewed: `20260422_p90_full288_baseline_v1`

## Goal

Future validation launches should preserve everything needed for:

1. comparison tables;
2. health checks;
3. fitted-quantile plots with uncertainty bands;
4. static coefficient/variable-selection summaries;
5. reproducibility and targeted reruns;

without retaining every posterior sample or full fit object.

The right target is not just `comparison_only`; it is `comparison_plus_plot`: keep compact tables for metrics and plotting, and treat full fit binaries as optional debug artifacts.

## Current Finding

The current run stores about `613G` of fit binaries, almost entirely from dynamic fits. The comparison analysis itself is less than `1M`, and row-level health/metrics/config/status artifacts are only a few MB.

The current fit binaries are therefore not the canonical validation output. They are oversized intermediate artifacts.

Cleanup manifest prepared:

- `reports/static_exal_tuning_20260428/refreshed288_heavy_binary_cleanup_manifest_20260428.csv`
- `reports/static_exal_tuning_20260428/refreshed288_heavy_binary_cleanup_manifest_summary_20260428.md`

Cleanup manifest result:

| Artifact | Count | Size | Recommended Action |
|---|---:|---:|---|
| Candidate fit binaries | 288 | `612.998G` | Extract plot summaries before delete |
| Draw exports | 288 | `0.438G` | Optional keep/delete after summaries |
| Configs | 288 | tiny | Keep |

No files were deleted.

## Minimal Retained Artifact Contract

### Required Run-Level Artifacts

Keep these permanently:

- full manifest;
- run contract;
- method registry;
- dataset registry;
- manifest-status CSV;
- phase and method summaries;
- comparison outputs;
- health-check reports;
- launch/recovery logs;
- documentation;
- git branch/SHA metadata.

### Required Row-Level Artifacts

Keep these permanently:

- `configs/row_####_run_config.rds`;
- `rows/row_####_status.csv`;
- `health/row_####_health.csv`;
- `metrics/row_####_metrics.csv`;
- new `plot_summaries/row_####_plot_summary.csv`;
- new `parameter_summaries/row_####_parameter_summary.csv` for static rows.

Optional:

- `draws/row_####_draws.rds`, only when we want raw-ish posterior follow-up.
- `fits/**/row_####_*_fit.rds`, only for debug/archive modes.

## Plot Summary Schema

### `plot_summaries/row_####_plot_summary.csv`

This is the key artifact for fitted-quantile plots.

Recommended columns:

| Column | Meaning |
|---|---|
| `row_id`, `case_key` | reproducibility keys |
| `block`, `root_kind`, `family`, `tau`, `tau_label`, `fit_size`, `prior_semantics`, `model`, `inference` | design identifiers |
| `obs_index` | row/time index within the fitted validation window |
| `source_index` | original source index, if available |
| `y` | observed response |
| `q_true` | true target quantile |
| `q_fit_tau` | fitted target quantile from posterior predictive draws |
| `pred_mean` | posterior predictive mean |
| `pred_q025`, `pred_q050`, `pred_q100`, `pred_q250`, `pred_q500`, `pred_q750`, `pred_q900`, `pred_q950`, `pred_q975` | compact posterior predictive bands |
| `ci_width95` | `pred_q975 - pred_q025` |
| `covered95` | whether `y` is inside the 95% band |
| `abs_q_error` | `abs(q_fit_tau - q_true)` |

This supports:

- observed series vs fitted quantile;
- true quantile vs fitted quantile;
- 50/80/90/95% uncertainty bands;
- residual and coverage plots;
- faceting by family/tau/model/inference/sample size;
- recalculating q-RMSE, coverage, and interval width.

It does not preserve exact CRPS recomputation. CRPS should remain stored in `metrics/row_####_metrics.csv`.

### `parameter_summaries/row_####_parameter_summary.csv`

This is mainly for static cases.

Recommended columns:

| Column | Meaning |
|---|---|
| `row_id`, `case_key`, design identifiers | reproducibility keys |
| `parameter_group` | `beta`, `sigma`, `gamma`, or shrinkage parameter |
| `term` | coefficient name |
| `truth` | true coefficient value when available |
| `is_signal` | true signal flag when available |
| `mean`, `median`, `sd`, `q025`, `q500`, `q975` | posterior summary |
| `covered95` | whether truth is inside interval |
| `p_gt_0`, `p_lt_0`, `p_abs_standardized_gt_0p1` | variable-selection summaries |

This supports:

- coefficient interval plots;
- signal/noise separation plots;
- posterior inclusion-style summaries;
- beta RMSE and beta coverage auditing.

## Optional Richer Summary For Future Quantile Synthesis

If we want to synthesize posterior predictive distributions across multiple quantile levels after pruning raw draws, the per-row plot summary may be too thin.

For that use case, add an optional long-format predictive quantile grid:

`predictive_quantile_grid/row_####_predictive_quantile_grid.csv`

Columns:

- `row_id`;
- `obs_index`;
- `source_index`;
- `prob`;
- `value`.

Recommended probabilities:

`0.005, 0.01, 0.025, 0.05, 0.10, 0.20, 0.25, 0.30, 0.40, 0.50, 0.60, 0.70, 0.75, 0.80, 0.90, 0.95, 0.975, 0.99, 0.995`, plus the fitted `tau` if not already present.

This is still small compared with raw draws and can support smoother downstream graphics or approximate distributional comparisons.

## Retention Modes

| Mode | Full Fits | Draw Exports | Plot Summaries | Use |
|---|---:|---:|---:|---|
| `comparison_only` | no | no | no | metrics/health/comparison only |
| `comparison_plus_plot` | no | no | yes | recommended default |
| `comparison_plus_draws` | no | yes | yes | richer posterior follow-up |
| `debug_failures` | FAIL/WARN or selected rows only | yes | yes | targeted diagnosis |
| `archive_full` | yes | yes | yes | rare small archive/smoke only |

Recommended default: `comparison_plus_plot`.

## Runner Modification Plan

### 1. Add New Output Directories

Add to `paths_refreshed288()`:

- `plot_summaries_dir`;
- `parameter_summaries_dir`;
- optional `predictive_quantile_grid_dir`;
- optional `retention_audit_dir`.

Add paths to manifest/config rows:

- `plot_summary_path`;
- `parameter_summary_path`;
- `predictive_quantile_grid_path`;
- `retention_mode`.

### 2. Fix Dynamic Window Inputs

Dynamic validation rows must use the intended `series_wide_path` and `true_quantile_grid_path` window.

Current risk:

- `build_dynamic_sim_object_refreshed288_p90()` prefers full-root `sim_output.rds`;
- this likely caused `fit_size=500` and `fit_size=5000` dynamic rows to use the same full root;
- dynamic `500` and `5000` fit binaries are nearly identical in size.

Required fix:

- for validation fitting, build `sim_obj` from the row's windowed CSVs;
- use `sim_output.rds` only for source provenance or explicit full-root diagnostics;
- audit that `nrow(plot_summary) == fit_size` for dynamic rows.

### 3. Generate Plot Summaries In Memory

Dynamic rows:

- use `draw_keep <- fit_obj$samp.post.pred[, selected_indices]`;
- compute row-wise quantiles and fitted target quantile;
- write `plot_summary_path`;
- write optional predictive quantile grid if requested.

Static rows:

- use `draw_bundle$draws`, `draw_bundle$beta_draws`, `sigma_draws`, `gamma_draws`;
- compute observation-level plot summary;
- compute parameter summary;
- write both before any pruning.

### 4. Enforce Retention Before Writing Full Fits

Current runner writes:

```r
saveRDS(wrapped, cfg$candidate_fit_path)
```

unconditionally.

Change to:

- compute health, metrics, plot summaries, and parameter summaries first;
- save full fit only when retention policy says yes;
- save draw export only when retention policy says yes;
- write `fit_retained`, `draws_retained`, and `plot_summary_retained` in row status.

Important: do not write full fit and then delete it unless needed for simplicity. The best storage behavior is not to write it in the first place.

### 5. Add Retention Audits

Add a post-row audit:

- metrics exists;
- health exists;
- row status exists;
- plot summary exists for completed rows;
- dynamic plot summary row count equals intended `fit_size`;
- no candidate fit exists in `comparison_plus_plot` mode unless the row is marked debug-retained.

Add a run-level audit:

- all completed rows have metrics and health;
- all completed rows have plot summaries;
- comparison analysis regenerates without fit binaries;
- expected retained footprint is below a configured threshold.

## Test Plan

| Test | Purpose |
|---|---|
| Unit test plot-summary builder on small matrix | Verify quantiles, coverage, q-RMSE components, and CI width. |
| Unit test static parameter-summary builder | Verify beta truth alignment, coverage, signal flags, and interval summaries. |
| Dynamic window test | Ensure `fit_size=500` produces exactly `500` plot rows and does not use full root. |
| Retention-mode smoke test | Run tiny static/dynamic rows under `comparison_plus_plot`; assert no full fit is retained. |
| Archive mode smoke test | Run tiny row under `archive_full`; assert full fit is retained. |
| Comparison regeneration test | Delete/withhold fit binaries in a test run and rerun comparison scripts successfully. |
| Cleanup dry-run test | Cleanup manifest reports delete candidates but deletes nothing without explicit flag. |
| Failure/debug retention test | In `debug_failures`, retain full fit only for FAIL/WARN or selected rows. |

## Cleanup Plan For Current Repo

Safe staged cleanup sequence:

1. Keep the existing comparison outputs and docs.
2. Keep `configs`, `rows`, `health`, `metrics`, manifests, registries, and logs.
3. Decide whether current-run fitted-quantile plots are needed.
4. If yes, extract `plot_summaries` from current fits one row at a time, then prune fits.
5. If no, candidate fits can be deleted for comparison purposes after explicit confirmation.
6. Keep or delete `draws` based on whether static posterior parameter samples are still needed.

Current heavy cleanup candidates:

- `candidate_fit`: `288` files, `612.998G`.
- `draw_export`: `288` files, `0.438G`.

Important caution: if we delete current dynamic fit binaries before extracting plot summaries, we cannot later make fitted dynamic quantile-band plots from this run. We can still make comparison tables because those depend on the metric/status CSVs.

## Recommended Decision

For future launches, use `comparison_plus_plot` as the default.

For the current run, the cleanest path is:

1. implement compact plot-summary extraction in the row runner;
2. decide whether to extract plot summaries from the already-completed current fits;
3. if yes, run a careful one-row-at-a-time extraction/prune workflow;
4. if no, delete candidate fit binaries after explicit confirmation and keep only comparison-ready artifacts.

Because the current dynamic run likely used full-root dynamic inputs rather than true `500`/`5000` windows, I would not spend too much effort preserving dynamic plots from this run unless we specifically need them as a diagnostic of this exact launch. The next corrected run should generate compact plot summaries directly and avoid full-fit retention from the start.
