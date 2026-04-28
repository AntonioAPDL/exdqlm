# Refreshed288 p90 Full288 Comparison Analysis Execution

Date: 2026-04-27

Run tag: `20260422_p90_full288_baseline_v1`

## Execution Summary

The comparison analysis was implemented as a lightweight, reproducible post-run workflow. It uses the finalized manifest status and metric CSVs, and it intentionally does not reread the large `.rds` fit objects.

Commands run:

```bash
Rscript tools/merge_reports/LOCAL_refreshed288_build_comparison_dataset_20260427.R
Rscript tools/merge_reports/LOCAL_refreshed288_build_comparison_tables_20260427.R
Rscript tools/merge_reports/LOCAL_refreshed288_comparison_audit_20260427.R
```

Audit result: all checks passed.

## Main Health Surface

| Slice | Total | Done | PASS | WARN | FAIL | Healthy | Completion |
|---|---:|---:|---:|---:|---:|---:|---:|
| Overall | 288 | 288 | 221 | 34 | 33 | 255 | 100.0% |
| Static | 216 | 216 | 169 | 24 | 23 | 193 | 100.0% |
| Dynamic | 72 | 72 | 52 | 10 | 10 | 62 | 100.0% |

Important distinction: row-level hard errors, metric errors, and numerical-error text are all zero. The 33 FAIL rows are health/quality-gate failures, not failed executions.

## Method Health

| Block | Model | Engine | Total | PASS | WARN | FAIL | Healthy | Median Runtime Sec |
|---|---|---|---:|---:|---:|---:|---:|---:|
| Dynamic | dqlm | mcmc | 18 | 18 | 0 | 0 | 18 | 23480.493 |
| Dynamic | dqlm | vb | 18 | 18 | 0 | 0 | 18 | 4684.878 |
| Dynamic | exdqlm | mcmc | 18 | 6 | 2 | 10 | 8 | 24533.590 |
| Dynamic | exdqlm | vb | 18 | 10 | 8 | 0 | 18 | 5814.740 |
| Static | al | mcmc | 54 | 50 | 4 | 0 | 54 | 278.240 |
| Static | al | vb | 54 | 54 | 0 | 0 | 54 | 0.584 |
| Static | exal | mcmc | 54 | 19 | 12 | 23 | 31 | 1144.534 |
| Static | exal | vb | 54 | 46 | 8 | 0 | 54 | 16.928 |

## Pairwise Gate Comparisons

| Comparison | Pairs | Better A | Better B | Ties | Runtime Pattern |
|---|---:|---:|---:|---:|---|
| Static exal vs al | 108 | exal: 0 | al: 42 | 66 | al faster in 108/108; median exal/al runtime ratio 5.697 |
| Static mcmc vs vb | 108 | mcmc: 1 | vb: 37 | 70 | vb faster in 108/108; median mcmc/vb runtime ratio 235.204 |
| Dynamic exdqlm vs dqlm | 36 | exdqlm: 0 | dqlm: 20 | 16 | dqlm faster in 35/36; median exdqlm/dqlm runtime ratio 1.081 |
| Dynamic mcmc vs vb | 36 | mcmc: 0 | vb: 12 | 24 | vb faster in 36/36; median mcmc/vb runtime ratio 4.806 |

Gate rank order is `PASS > WARN > FAIL > MISSING`.

## Concentration Of FAIL Rows

| Source | FAIL Rows | Notes |
|---|---:|---|
| Static exal MCMC | 23 | Concentrated in exAL MCMC quality gates; execution completed successfully. |
| Dynamic exdqlm MCMC | 10 | Concentrated in exDQLM MCMC quality gates; execution completed successfully. |
| Other methods | 0 | No other method had FAIL gates. |

By tau, the weakest settings were `0p05` and `0p25`: `0p05` had 16 FAIL rows and `0p25` had 15 FAIL rows. The `0p50` slice had only 2 FAIL rows.

## Output Files

Core datasets:

- `tools/merge_reports/LOCAL_refreshed288_comparison_long_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_broad_comparison_table_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_static_scenario_comparison_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_dynamic_scenario_comparison_20260427_20260422_p90_full288_baseline_v1.csv`

Summaries:

- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_block_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_model_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_inference_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_method_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_family_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_tau_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_summary_by_prior_semantics_20260427_20260422_p90_full288_baseline_v1.csv`

Pairwise tables:

- `tools/merge_reports/LOCAL_refreshed288_static_model_pair_comparison_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_static_model_pair_summary_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_static_inference_pair_comparison_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_static_inference_pair_summary_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_dynamic_model_pair_comparison_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_dynamic_model_pair_summary_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_dynamic_inference_pair_comparison_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_dynamic_inference_pair_summary_20260427_20260422_p90_full288_baseline_v1.csv`

Diagnostics and inventories:

- `tools/merge_reports/LOCAL_refreshed288_mcmc_diagnostics_by_method_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_vb_diagnostics_by_method_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_warn_inventory_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_fail_inventory_20260427_20260422_p90_full288_baseline_v1.csv`
- `tools/merge_reports/LOCAL_refreshed288_comparison_audit_20260427_20260422_p90_full288_baseline_v1.csv`

## Audit Checks

The audit enforces:

- `288` comparison rows and `288` unique case keys.
- `288` completed rows, `0` running rows, and `0` not-started rows.
- Final gate counts: `221 PASS`, `34 WARN`, `33 FAIL`.
- Final healthy count: `255`.
- Scenario rows: `54` static and `18` dynamic.
- Pair rows: `108` static model, `108` static inference, `36` dynamic model, `36` dynamic inference.
- Inventories: `34` WARN rows and `33` FAIL rows.
- Row-level hard errors: `0`.
- Row-level metric errors: `0`.
- Row-level numerical error text: `0`.

## Interpretation

The full comparison confirms that the refreshed 0.4.0 validation relaunch is complete and reproducible. The strongest stability is in `al`, `dqlm`, and VB execution. The main follow-up scientific/diagnostic focus should be the quality-gate behavior of `exal` MCMC in static cases and `exdqlm` MCMC in dynamic cases, especially for lower tau settings.
