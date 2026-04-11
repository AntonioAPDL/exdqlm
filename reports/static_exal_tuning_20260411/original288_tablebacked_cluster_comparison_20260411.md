# Original288 Table-Backed Cluster Comparison (2026-04-11)

This note refreshes the cluster-by-cluster comparison after the `static_shrink / rhs -> rhs_ns` correction, using stable validation tables and selected wave metrics rather than stale historical fit-RDS paths.

## Scope

- freeze legacy mixed-prior `static_shrink / rhs` as historical only
- use corrected `rhs_ns` selection for the full `72`-row shrinkage branch
- use accepted `v9` for the broader `288`-row current-state comparison
- compare within inference (`al` vs `exal`, `dqlm` vs `exdqlm`) and within model (`vb` vs `mcmc`)

## Source Rule

- `static_paper`, `static_shrink / ridge`, and non-promoted dynamic rows use native validation tables (`fit_metrics_by_task.csv`, `metrics_summary.csv`, `fit_summary.csv`)
- corrected `static_shrink / rhs_ns` rows use the selected wave metrics CSVs from the rebuild / repair / bridge lanes
- the `3` promoted dynamic restored-closure rows use the selected restored-closure metrics plus direct posterior-width recomputation

## Main Results

- static `mcmc`: `exal` has better primary accuracy in `34 / 54` scenario pairs (`63.0%`)
- static `vb`: `exal` has better primary accuracy in `17 / 36` scenario pairs (`47.2%`)
- dynamic `mcmc`: `exdqlm` has better primary accuracy in `3 / 18` scenario pairs (`16.7%`)
- dynamic `vb`: `exdqlm` has better primary accuracy in `9 / 18` scenario pairs (`50.0%`)

## Static Model Comparison Within Inference

| block | prior_semantics | inference | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|---|---|
| static_paper | paper | mcmc | 12 / 18 | 66.7% | 0 / 18 | 0.0% | -0.243 | 16.90x |
| static_paper | paper | vb | 5 / 12 | 41.7% | 0 / 18 | 0.0% | -0.056 | 83.58x |
| static_shrink | rhs_ns | mcmc | 11 / 18 | 61.1% | 1 / 18 | 5.6% | -0.060 | 11.02x |
| static_shrink | rhs_ns | vb | 6 / 12 | 50.0% | 0 / 18 | 0.0% | -0.012 | 15.97x |
| static_shrink | ridge | mcmc | 11 / 18 | 61.1% | 0 / 18 | 0.0% | -0.108 | 15.09x |
| static_shrink | ridge | vb | 6 / 12 | 50.0% | 0 / 18 | 0.0% | -0.005 | 68.71x |

## Dynamic Model Comparison Within Inference

| inference | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|
| mcmc | 3 / 18 | 16.7% | 1 / 18 | 5.6% | 1282.348 | 2.71x |
| vb | 9 / 18 | 50.0% | 0 / 18 | 0.0% | -31.086 | 3.12x |

## Dynamic Model Comparison By Tau

| inference | tau_label | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|---|
| mcmc | 0p05 | 0 / 6 | 0.0% | 0 / 6 | 0.0% | 1327.326 | 3.34x |
| mcmc | 0p25 | 0 / 6 | 0.0% | 0 / 6 | 0.0% | 1014.210 | 3.10x |
| mcmc | 0p95 | 3 / 6 | 50.0% | 1 / 6 | 16.7% | 1505.509 | 0.53x |
| vb | 0p05 | 3 / 6 | 50.0% | 0 / 6 | 0.0% | 19.221 | 4.05x |
| vb | 0p25 | 0 / 6 | 0.0% | 0 / 6 | 0.0% | 31.770 | NA |
| vb | 0p95 | 6 / 6 | 100.0% | 0 / 6 | 0.0% | -144.248 | 2.26x |

## Algorithm Comparison Within Model

Static:

| block | prior_semantics | model | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|---|---|
| static_paper | paper | al | 15 / 18 | 83.3% | 0 / 18 | 0.0% | -0.060 | 39.74x |
| static_paper | paper | exal | 12 / 12 | 100.0% | 3 / 18 | 16.7% | -0.327 | 4.85x |
| static_shrink | rhs_ns | al | 15 / 18 | 83.3% | 0 / 18 | 0.0% | -0.030 | 8.12x |
| static_shrink | rhs_ns | exal | 11 / 12 | 91.7% | 3 / 18 | 16.7% | -0.090 | 5.02x |
| static_shrink | ridge | al | 13 / 18 | 72.2% | 0 / 18 | 0.0% | -0.036 | 38.43x |
| static_shrink | ridge | exal | 12 / 12 | 100.0% | 2 / 18 | 11.1% | -0.167 | 5.05x |

Dynamic:

| model | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|
| dqlm | 16 / 18 | 88.9% | 0 / 18 | 0.0% | -4.251 | 11.16x |
| exdqlm | 2 / 18 | 11.1% | 0 / 18 | 0.0% | 1309.183 | 7.40x |

## Interpretation

- the corrected current-state comparison supports the intended static conclusion: `exal` is better than `al` overall within `mcmc`, after replacing legacy `rhs` with explicit `rhs_ns`
- the dynamic side remains more mixed and should be interpreted separately from the static `exal` claim
- the strongest corrected static signal remains `mcmc`: all three static `mcmc` clusters now favor `exal` on the current primary-accuracy metric
- the dynamic picture is cluster-dependent: `tau = 0p95` is the main `exdqlm` win region, while `0p05` and `0p25` remain unfavorable in `mcmc`
- within-model algorithm comparisons now show that static `exal` usually benefits from `mcmc` over `vb`, while dynamic `exdqlm` more often favors `vb` on the current primary-accuracy metric
- this pass is reproducible because it no longer depends on missing historical fit-RDS paths for the majority of rows
- the older fit-RDS-based `20260409` comparison outputs should now be treated as superseded for the corrected `rhs_ns` question

## Outputs

- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_tablebacked_metric_long_20260411.csv`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_static_model_pair_comparison_20260411.csv`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_dynamic_model_pair_comparison_20260411.csv`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_static_algorithm_pair_comparison_20260411.csv`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_dynamic_algorithm_pair_comparison_20260411.csv`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_static_model_cluster_summary_20260411.csv`
- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/original288_tablebacked_comparison_20260411/original288_dynamic_model_cluster_summary_20260411.csv`
