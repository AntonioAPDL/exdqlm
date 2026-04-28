# Refreshed288 Heavy Binary Cleanup Manifest Summary

Date: 2026-04-28

Run root: `tools/merge_reports/full288_refreshed288_20260422_p90_full288_baseline_v1`

Manifest CSV: `reports/static_exal_tuning_20260428/refreshed288_heavy_binary_cleanup_manifest_20260428.csv`

## Summary

| Artifact | Recommended Action | Count | Size GB |
|---|---|---:|---:|
| `candidate_fit` | `extract_plot_summary_before_delete` | 288 | 612.998 |
| `draw_export` | `optional_keep_or_delete_after_plot_summary` | 288 | 0.438 |
| `config` | `keep` | 288 | 0.000 |

## Interpretation

- `candidate_fit` artifacts are not required by the current comparison analysis once row-level `health`, `metrics`, and `rows` CSVs are written.
- Because fitted-quantile plotting needs compact per-observation summaries, the safe cleanup path is to extract `plot_summaries/row_####_plot_summary.csv` first, then delete candidate fits.
- `draw_export` artifacts are optional for the current comparison tables. Static draw exports are useful only if we want posterior parameter samples beyond compact summaries.
- `config` artifacts are intentionally marked `keep` because they are small and carry reproducibility metadata.

No files were deleted by this manifest script.
