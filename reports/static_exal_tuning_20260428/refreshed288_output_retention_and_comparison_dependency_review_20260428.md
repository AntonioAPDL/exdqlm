# Refreshed288 Output Retention And Comparison Dependency Review

Date: 2026-04-28

Run tag reviewed: `20260422_p90_full288_baseline_v1`

## Executive Finding

Yes, it is possible to make future validation launches dramatically more storage-efficient.

The current comparison analysis does not need the full fit `.rds` objects after row-level health and metric extraction has completed. The full fit objects account for almost the entire storage footprint.

Current run footprint:

| Artifact Class | Size |
|---|---:|
| Full run root | `614G` |
| Fit binaries | `613G` |
| VB fit binaries | `307G` |
| MCMC fit binaries | `307G` |
| Draw exports | `450M` |
| Config CSV/RDS + rows + health + metrics | about `4.8M` |
| Comparison-analysis CSV outputs | about `0.8M` |

The current comparison workflow uses:

- `LOCAL_refreshed288_full_manifest_status_20260422_p90_full288_baseline_v1.csv`
- `LOCAL_refreshed288_full_manifest_20260422_p90_full288_baseline_v1.csv`
- row-level `metrics/*.csv`
- row-level `health/*.csv`
- row-level `rows/*.csv`
- manifest/config paths for provenance

It does not read the large fit `.rds` objects.

## Main Storage Driver

Dynamic fit objects dominate storage.

| Block | Model | Engine | Rows | Total Fit Size | Median Per Fit |
|---|---|---|---:|---:|---:|
| Dynamic | dqlm | VB | 18 | `144.29G` | `8210M` |
| Dynamic | dqlm | MCMC | 18 | `144.24G` | `8209M` |
| Dynamic | exdqlm | VB | 18 | `162.07G` | `9224M` |
| Dynamic | exdqlm | MCMC | 18 | `162.02G` | `9220M` |
| Static | all | all | 216 | about `0.39G` | small |

The dynamic objects are huge because package fit objects store posterior state arrays and predictive draws:

- `samp.theta`: state dimension x time x posterior draws
- `samp.post.pred`: time x posterior draws
- plus scale/skewness samples and diagnostics

Approximate lower-bound storage for only `samp.theta` and `samp.post.pred`, assuming state dimension `6` and `20k` draws:

| Time Length | Approx `samp.theta` | Approx `samp.post.pred` | Approx Combined |
|---:|---:|---:|---:|
| `7000` | `6.26G` | `1.04G` | `7.30G` |
| `5000` | `4.47G` | `0.75G` | `5.22G` |
| `500` | `0.45G` | `0.07G` | `0.52G` |

The observed dynamic fit sizes of `8-9G` per row are consistent with storing full `7000`-length dynamic roots plus overhead.

## Important Dynamic-Window Finding

The reviewed dynamic runner appears to prefer the full-root `sim_output.rds` when it exists:

```r
if (!is.null(cfg$sim_output_path) && nzchar(cfg$sim_output_path) && file.exists(cfg$sim_output_path)) {
  sim_obj <- readRDS(cfg$sim_output_path)
  ...
  return(sim_obj)
}
```

The manifest labels dynamic cases as `fit_size = 500` or `fit_size = 5000`, and points `series_wide_path` to `fit_input_lastTT500` or `fit_input_lastTT5000`. However, the config also includes `sim_output_path` at the full dynamic root. At launch time, because that full-root `sim_output.rds` existed, the runner likely used the full `7000`-length simulated root for both `500` and `5000` dynamic cases.

Evidence:

- Dynamic `500` and `5000` fit objects have essentially identical sizes.
- Dynamic fit sizes match the theoretical scale of `TT = 7000`, not `TT = 500`.
- `build_dynamic_sim_object_refreshed288_p90()` reads `cfg$sim_output_path` before falling back to windowed CSV inputs.
- The manifest has distinct `series_wide_path` values for `lastTT500` and `lastTT5000`, but those paths are bypassed when `sim_output_path` is present.

This is separate from retention policy, but it matters. Future launches should fix both:

1. Use the intended dynamic validation window for fitting and metrics.
2. Avoid retaining full dynamic fit binaries unless explicitly requested.

## Current Comparison Dependency Chain

The current pipeline is:

1. Row runner fits model in memory.
2. Row runner writes full fit `.rds`.
3. Row runner computes health from the in-memory fit.
4. Row runner computes metrics from in-memory draws.
5. Row runner writes:
   - `health/row_####_health.csv`
   - `metrics/row_####_metrics.csv`
   - `rows/row_####_status.csv`
   - `draws/row_####_draws.rds`
6. Status evaluator combines row CSVs and metric CSVs into:
   - `LOCAL_refreshed288_full_manifest_status_*.csv`
7. Comparison scripts build:
   - `comparison_long`
   - broad table
   - scenario tables
   - pairwise tables
   - diagnostics
   - warn/fail inventories
   - audit

The comparison scripts only need lightweight tables after step 5/6.

## What Can Be Dropped After Each Row

Safe to drop after row health/metrics have been written:

- `fits/vb/*.rds`
- `fits/mcmc/*.rds`
- `vb_init/**/*.rds`, if VB init is only used in memory for MCMC initialization

Usually safe to drop or make optional:

- `draws/*.rds`

The current dynamic draw exports are tiny because they store only a draw-selection contract, not the full predictive matrix. Static draw exports store `20k` parameter draws and total about `450M`. They are useful for secondary diagnostics but are not required by the current comparison tables.

Must keep for reproducible comparison:

- full manifest
- run contract
- method registry
- row configs
- row status CSVs
- health CSVs
- metrics CSVs
- final manifest-status CSV
- comparison outputs
- launch/recovery logs
- exact git SHA and branch metadata
- dataset registry and dataset generation metadata

## Recommended Future Retention Modes

| Mode | Keep Full Fits? | Keep Draw Exports? | Intended Use |
|---|---:|---:|---|
| `comparison_only` | No | No or static-only optional | Main overnight validation mode. |
| `comparison_plus_draws` | No | Yes | Enables lightweight posterior follow-up without giant fits. |
| `debug_failures` | Only FAIL/WARN rows or selected rows | Yes | Retains enough to diagnose failures. |
| `archive_full` | Yes | Yes | Rare, for a small smoke set or publication archive only. |

Recommended default: `comparison_plus_draws` or `comparison_only`.

## Implementation Recommendation

The row runner should enforce retention after successful metric extraction:

1. Fit in memory.
2. Compute health and metrics in memory.
3. Write `health`, `metrics`, and `row_status`.
4. Write draw export only if `retain_draw_binaries = TRUE` or retention mode allows it.
5. Write full fit only if `retain_candidate_fit_binaries = TRUE`.
6. Always avoid writing cached VB-init fits unless explicitly enabled.

Current row status already includes:

- `retain_candidate_fit_binaries`
- `retain_vb_init_binaries`
- `retain_draw_binaries`

But the current runner writes `saveRDS(wrapped, cfg$candidate_fit_path)` unconditionally. That is the main implementation gap.

## Expected Storage Savings

If future runs keep only configs, rows, health, metrics, logs, manifests, reports, and comparison outputs:

- Expected retained size for the current 288-row surface would be well under `1G`.
- If static draw exports are retained, expected size is still roughly under `1G`.
- This would avoid retaining about `613G` of full fit binaries for this run.

The biggest win is not compression; it is not writing full dynamic fit binaries by default.

## Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Cannot recompute a new metric from a pruned fit | Keep row configs, seeds, dataset registry, package SHA, and optionally draw summaries. Rerun selected rows if needed. |
| Hard to debug numerical failures without full fit | Retain full fits only for FAIL/WARN rows or a targeted debug subset. |
| Losing posterior draws needed for plots | Store compact draw exports or precomputed quantile summaries instead of full fit objects. |
| Dynamic sample-size labels not actually matching windows | Fix dynamic input builder to construct `sim_obj` from `series_wide_path` / `true_quantile_grid_path` for each validation window. |

## Recommended Next Work

1. Patch the dynamic runner so `fit_size=500` and `fit_size=5000` use their windowed inputs, not the full-root `sim_output.rds`.
2. Add a retention policy to the run contract and method registry.
3. Enforce retention in the row runner.
4. Add a post-row audit that fails if a full fit exists when retention mode says it should not.
5. Add a comparison-readiness audit that confirms all metrics/health/status rows exist before pruning.
6. Run a small smoke set in `comparison_only` mode and verify the full comparison analysis can be regenerated from lightweight artifacts alone.

## Bottom Line

The future validation study can be made much more resource-efficient. The comparison analysis only needs compact health and metric tables after row completion. The current `614G` footprint is almost entirely avoidable for routine validation runs.

The more important engineering move is to make the row runner table-first: treat full fit objects as optional debug artifacts, not the canonical validation output.
