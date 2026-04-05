# Original 288 Realignment Execution

Date: 2026-04-05

The corrected original-288 carry-forward pipeline was implemented and executed.
This replaces the earlier hybrid `291` campaign as the publication-target
recovery view.

## Top-Line Result

- original baseline cells: `288`
- healthy now: `269`
- unresolved now: `19`
- scoreable archived dynamic rescues harvested: `10`
- publication target should now be the corrected original-`288` carry-forward table, not the earlier hybrid `291` bundle

## Block Status

| block | original cells | healthy via promoted selection | healthy via untouched baseline | healthy now | unresolved |
|---|---:|---:|---:|---:|---:|
| `dynamic` |  72 | 12 | 41 |  53 | 19 |
| `static_paper` |  72 | 39 | 33 |  72 |  0 |
| `static_shrink` | 144 | 83 | 61 | 144 |  0 |

## Selection Routing

| selected source type | rows |
|---|---:|
| `baseline_original` | 154 |
| `dynamic_summary_csv` |   9 |
| `hybrid_291_selection` |  43 |
| `static_refresh_compact` |  82 |

## Selection Mode

| selection mode | rows |
|---|---:|
| `baseline_kept` | 135 |
| `promoted_over_fail_baseline` |  49 |
| `promoted_over_healthy_baseline` |  85 |
| `unresolved_baseline_fail` |  19 |

## Acceptance Checks

| check | pass | detail |
|---|---|---|
| `registry_rows_288` | `yes` | rows=288 |
| `registry_unique_keys_288` | `yes` | unique_keys=288 |
| `selection_rows_288` | `yes` | rows=288 |
| `selection_unique_keys_288` | `yes` | unique_keys=288 |
| `registry_block_counts_match` | `yes` | dynamic:72; static_paper:72; static_shrink:144 |
| `baseline_fit_paths_exist` | `yes` | all baseline fit paths present |
| `baseline_signoff_paths_exist` | `yes` | all baseline signoff paths present |
| `selected_fit_paths_exist` | `yes` | all selected fit paths present |
| `selected_evidence_paths_exist` | `yes` | all selected evidence paths present |
| `static_unresolved_zero` | `yes` | static_fail_rows=0 |
| `all_unresolved_dynamic_only` | `yes` | dynamic_fail_rows=19 |

## Remaining Unresolved Dynamic Cells

| family | tau | horizon | model | inference | baseline | selected status |
|---|---|---:|---|---|---|---|
| `gausmix` | `0p05` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p05` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p05` | 5000 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p05` | 5000 | `exdqlm` | `vb` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p25` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p25` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p95` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `gausmix` | `0p95` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p05` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p05` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p05` | 5000 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p05` | 5000 | `exdqlm` | `vb` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p25` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p25` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p95` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `laplace` | `0p95` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `normal` | `0p05` |  500 | `dqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `normal` | `0p05` |  500 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |
| `normal` | `0p05` | 5000 | `exdqlm` | `mcmc` | `FAIL` | `unresolved_baseline_fail` |

## Next-Phase Checklist

1. Freeze the corrected original-`288` carry-forward table as the only publication-target comparison registry.
2. Do not reopen static repair work unless a provenance bug is found; static is fully recovered at `72 / 72` paper and `144 / 144` shrink healthy.
3. Use `tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v1_20260405.csv` as the exact residual repair queue.
4. Start the next dynamic phase by harvesting any remaining candidate evidence for those `19` unresolved keys before launching new compute.
5. Only after that harvest pass, build a dynamic-only residual manifest and repair program.
