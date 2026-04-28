# Refreshed288 Resource-Efficient Launch Modification Plan

Date: 2026-04-28

Target branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`

Target run family: refreshed288 / p90 / full288 validation launches

## Decision Statement

We want future validation launches to be **table-first and plot-summary-first**, not full-fit-first.

The validation study needs:

1. reliable comparison metrics;
2. health gates and MCMC/VB diagnostics;
3. fitted quantile plots with uncertainty bands;
4. static coefficient and variable-selection summaries;
5. reproducibility metadata for reruns;
6. optional debug retention for selected rows.

It does **not** need to retain every posterior draw or every full fit object for every row.

The default target should be `comparison_plus_plot`:

- keep metrics, health, row status, configs, manifests, logs, plot summaries, and static parameter summaries;
- do not retain full fit binaries by default;
- do not retain cached VB-init binaries by default;
- retain raw-ish draw exports only when explicitly requested.

## Why This Change Is Necessary

The current completed run occupies about `614G`; `613G` of this is fit binaries.

Current footprint:

| Artifact Class | Size |
|---|---:|
| full run root | `614G` |
| candidate fit binaries | `612.998G` |
| draw exports | `0.438G` |
| configs + rows + health + metrics | a few MB |
| comparison output CSVs | less than `1M` |

The comparison analysis already runs entirely from lightweight CSV artifacts. The full fit binaries are only needed if we later want raw posterior draws, full object debugging, or plots that were not summarized before pruning.

Therefore, the safe design is:

- extract the useful summaries while the fit is still in memory;
- write compact artifacts;
- retain full fit objects only when a retention mode explicitly asks for them.

## Important Correctness Finding To Fix Together

The dynamic row runner currently prefers `cfg$sim_output_path` when it exists. That path points to the full dynamic root. The manifest also has windowed `series_wide_path` / `true_quantile_grid_path` for `lastTT500` and `lastTT5000`, but those may be bypassed.

Evidence from the completed run:

- dynamic `fit_size=500` and `fit_size=5000` fit objects have nearly identical size;
- dynamic fit objects are about `8-9G` each, consistent with full-root `TT=7000`;
- `build_dynamic_sim_object_refreshed288_p90()` reads `cfg$sim_output_path` before using windowed CSV inputs.

This must be fixed before the next main launch. Otherwise, storage retention improves, but the dynamic case semantics remain wrong or at least ambiguous.

## Non-Goals For The Modification

- Do not change model mathematics.
- Do not change the selected p90 DGP.
- Do not change warmup defaults unless a specific test reveals a required compatibility issue.
- Do not delete current large files automatically.
- Do not remove the ability to retain full fits for debug/archive modes.
- Do not weaken comparison metrics or health gates.

## Target Retention Modes

| Mode | Full Fits | Draw Exports | Plot Summaries | Parameter Summaries | Intended Use |
|---|---:|---:|---:|---:|---|
| `comparison_only` | no | no | no | no | metric-only validation |
| `comparison_plus_plot` | no | no | yes | yes | default future launch mode |
| `comparison_plus_draws` | no | yes | yes | yes | richer posterior follow-up |
| `debug_failures` | selected FAIL/WARN rows only | yes | yes | yes | targeted diagnosis |
| `archive_full` | yes | yes | yes | yes | small smoke/archive only |

Recommended default: `comparison_plus_plot`.

## Required New Artifacts

### Plot Summary

Path:

- `tools/merge_reports/full288_<run_tag>/plot_summaries/row_####_plot_summary.csv`

Purpose:

- fitted quantile plots;
- uncertainty bands;
- coverage plots;
- true-vs-fitted quantile overlays;
- residual plots;
- lightweight metric reproducibility for q-RMSE, coverage, and interval width.

Columns:

| Column | Meaning |
|---|---|
| `row_id`, `case_key` | row identity |
| `block`, `root_kind`, `family`, `tau`, `tau_label`, `fit_size`, `prior_semantics`, `model`, `inference` | design identity |
| `obs_index` | row index inside validation window |
| `source_index` | original source index if available |
| `y` | observed response |
| `q_true` | true target quantile |
| `q_fit_tau` | fitted quantile at the target tau |
| `pred_mean` | posterior predictive mean |
| `pred_q025`, `pred_q050`, `pred_q100`, `pred_q250`, `pred_q500`, `pred_q750`, `pred_q900`, `pred_q950`, `pred_q975` | compact bands |
| `ci_width95` | 95% interval width |
| `covered95` | observed response inside 95% interval |
| `abs_q_error` | absolute quantile error |

### Static Parameter Summary

Path:

- `tools/merge_reports/full288_<run_tag>/parameter_summaries/row_####_parameter_summary.csv`

Purpose:

- coefficient interval plots;
- variable-selection summaries;
- beta RMSE and coverage auditing;
- static diagnostics after fit pruning.

Columns:

| Column | Meaning |
|---|---|
| row/design identifiers | row and scenario identity |
| `parameter_group` | `beta`, `sigma`, `gamma`, shrinkage parameter |
| `term` | coefficient/parameter name |
| `truth` | true value when known |
| `is_signal` | true signal flag when known |
| `mean`, `median`, `sd`, `q025`, `q500`, `q975` | posterior summaries |
| `covered95` | truth inside 95% interval |
| `p_gt_0`, `p_lt_0`, `p_abs_standardized_gt_0p1` | selection-style summaries |

### Optional Predictive Quantile Grid

Path:

- `tools/merge_reports/full288_<run_tag>/predictive_quantile_grid/row_####_predictive_quantile_grid.csv`

Use this only if we want more flexible posterior predictive plotting or approximate quantile synthesis after pruning raw draws.

Recommended probabilities:

`0.005, 0.01, 0.025, 0.05, 0.10, 0.20, 0.25, 0.30, 0.40, 0.50, 0.60, 0.70, 0.75, 0.80, 0.90, 0.95, 0.975, 0.99, 0.995`, plus the fitted `tau` if not already present.

## Specific Code Targets

### Runner Helper Layer

File:

- `tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R`

Planned changes:

- add `plot_summaries_dir`, `parameter_summaries_dir`, optional `predictive_quantile_grid_dir`;
- add path columns in manifest/config:
  - `plot_summary_path`;
  - `parameter_summary_path`;
  - `predictive_quantile_grid_path`;
  - `retention_mode`;
  - `retain_candidate_fit_binaries`;
  - `retain_draw_binaries`;
  - `retain_vb_init_binaries`;
- add helper functions:
  - `retention_policy_refreshed288()`;
  - `should_retain_fit_refreshed288()`;
  - `should_retain_draws_refreshed288()`;
  - `write_plot_summary_refreshed288()`;
  - `write_parameter_summary_refreshed288()`;
  - `write_retention_audit_row_refreshed288()`.

### Row Runner

File:

- `tools/merge_reports/LOCAL_refreshed288_run_row_20260422_p90_full288.R`

Planned changes:

1. Fix dynamic input construction:
   - use `series_wide_path` and `true_quantile_grid_path` for validation windows;
   - avoid using full-root `sim_output.rds` for row fitting unless explicitly requested;
   - assert `length(sim_obj$y) == fit_size` for dynamic rows.
2. Generate plot summaries in memory:
   - dynamic from `draw_keep`;
   - static from `draw_bundle$draws`;
   - write before any fit pruning/retention decision.
3. Generate static parameter summaries from `beta_draws`, `sigma_draws`, and `gamma_draws`.
4. Replace unconditional `saveRDS(wrapped, cfg$candidate_fit_path)` with retention-aware logic.
5. Replace unconditional draw export with retention-aware logic.
6. Keep MCMC VB init memory-only by default.
7. Add row-status fields:
   - `retention_mode`;
   - `fit_retained`;
   - `draws_retained`;
   - `vb_init_retained`;
   - `plot_summary_retained`;
   - `parameter_summary_retained`.

### Status / Healthcheck Layer

File:

- `tools/merge_reports/LOCAL_refreshed288_evaluate_20260422_p90_full288.R`

Planned changes:

- carry plot-summary and parameter-summary availability into manifest-status;
- add missing-summary counters;
- report retained fit/draw counts and retained GB;
- fail readiness if completed rows lack required lightweight artifacts.

### Comparison Layer

Files:

- `tools/merge_reports/LOCAL_refreshed288_comparison_helpers_20260427.R`;
- `tools/merge_reports/LOCAL_refreshed288_build_comparison_dataset_20260427.R`;
- `tools/merge_reports/LOCAL_refreshed288_build_comparison_tables_20260427.R`;
- `tools/merge_reports/LOCAL_refreshed288_comparison_audit_20260427.R`.

Planned changes:

- keep comparison independent of full fits;
- optionally include `plot_summary_path` and `parameter_summary_path` in `comparison_long`;
- add audit checks for plot-summary availability when retention mode is `comparison_plus_plot`.

### Cleanup Layer

Prepared script:

- `tools/merge_reports/LOCAL_refreshed288_heavy_binary_cleanup_manifest_20260428.R`

Planned follow-up:

- keep as dry-run by default;
- add explicit `--delete-confirm=<run_tag>` mode only after plot-summary extraction is validated;
- never delete configs, health, metrics, rows, manifests, logs, or docs.

## Testing Plan

### Unit Tests

Add tests for:

- plot-summary quantile computation from a small predictive draw matrix;
- coverage and CI width calculations;
- fitted target quantile calculation for arbitrary `tau`;
- static parameter summary alignment to `coef_truth.csv`;
- retention-policy decisions for all retention modes.

### Integration Smoke Tests

Run a tiny smoke manifest with at least:

- one dynamic `fit_size=500` row;
- one dynamic `fit_size=5000` row;
- one static VB row;
- one static MCMC row;
- one MCMC row using VB init.

Assertions:

- dynamic `fit_size=500` produces exactly `500` plot-summary rows;
- dynamic `fit_size=5000` produces exactly `5000` plot-summary rows;
- no full candidate fit exists under `comparison_plus_plot`;
- no VB-init cache exists under default mode;
- metrics, health, row status, plot summary, and parameter summary exist as expected;
- comparison scripts run without fit binaries.

### Regression Tests

Run existing relevant tests:

- `tests/testthat/test-refreshed288-p90-relaunch-contract.R`;
- `tests/testthat/test-dynamic-p90-canonical-source-contract.R`;
- `tests/testthat/test-quantile-synthesis.R`;
- `tests/testthat/test-diagnostics-metrics.R`;
- `tests/testthat/test-static-diagnostics.R`.

Add a new test file:

- `tests/testthat/test-refreshed288-resource-efficient-retention.R`.

## Cleanup Plan After Implementation

Cleanup should happen only after the following are true:

1. compact plot-summary extraction exists and is tested;
2. comparison scripts regenerate without fit binaries;
3. current-run cleanup manifest is reviewed;
4. user explicitly approves deletion.

Current cleanup candidates:

- candidate fits: `288` files, `612.998G`;
- draw exports: `288` files, `0.438G`.

Current guidance:

- if we want fitted quantile-band plots for this exact run, extract plot summaries first;
- if we only need comparison tables from this run, candidate fits are removable after explicit confirmation;
- because the current dynamic run likely used full-root dynamic inputs, the most scientifically valuable plot summaries should come from the corrected next launch.

## Implementation Sequence

1. Commit and push this planning checkpoint.
2. Patch helper paths, manifest fields, and retention policy helpers.
3. Patch dynamic window construction and add assertions.
4. Patch row runner to write plot and parameter summaries.
5. Patch row runner to enforce retention modes.
6. Patch evaluator and comparison audit for summary availability.
7. Add tests.
8. Run unit tests and smoke tests.
9. Generate a new dry-run cleanup manifest.
10. Only then decide whether to delete current heavy files.

## Success Criteria

The modification is successful when:

- a smoke run completes without retaining full fit binaries in `comparison_plus_plot`;
- all required lightweight artifacts exist;
- dynamic row lengths match declared `fit_size`;
- comparison analysis can be regenerated from lightweight artifacts alone;
- fitted quantile plots can be generated from `plot_summaries`;
- retained output footprint is orders of magnitude smaller than the current `614G` run root;
- debug/archive modes still retain full fits when explicitly requested.
