# Original288 Table-Backed Cluster Comparison After Dynamic TT5000 Repair (2026-04-14)

This note refreshes the cluster-by-cluster comparison after the completed
exact-spec replay and the targeted dynamic `TT5000` repair wave, using stable
validation tables and current selected-wave metrics rather than stale
historical fit-RDS paths.

## Scope

- freeze legacy mixed-prior `static_shrink / rhs` as historical only
- use corrected `rhs_ns` selection for the full `72`-row shrinkage branch
- use the post-repair exact-spec selection for the broader replay comparison
- compare within inference (`al` vs `exal`, `dqlm` vs `exdqlm`) and within model (`vb` vs `mcmc`)

## Source Rule

- `static_paper` and `static_shrink / ridge` rows use native validation tables
  (`fit_metrics_by_task.csv`, `metrics_summary.csv`, `fit_summary.csv`)
- corrected `static_shrink / rhs_ns` rows use the selected wave metrics CSVs
  from the rebuild / repair / bridge lanes
- exact-spec replay rows use the selected seed metrics from the replay and the
  completed dynamic `TT5000` repair selection where applicable

## Main Results

- static `mcmc`: `exal` has better primary accuracy in `5 / 54` scenario pairs (`9.3%`)
- static `vb`: `exal` has better primary accuracy in `7 / 54` scenario pairs (`13.0%`)
- dynamic `mcmc`: `exdqlm` has better primary accuracy in `3 / 9` scenario pairs (`33.3%`)
- dynamic `vb`: `exdqlm` has better primary accuracy in `0 / 9` scenario pairs (`0.0%`)

## Important Caveat

- the targeted dynamic `TT5000` repair wave did **not** rescue the unresolved
  `36` replay-selected dynamic rows
- those rows remain runtime `FAIL`s, so the dynamic side is still only
  partially comparable
- dynamic pair coverage remains `9 / 18` in each inference lane

## Static Model Comparison Within Inference

| block | prior_semantics | inference | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|---|---|
| static_paper | paper | mcmc | 3 / 18 | 16.7% | 0 / 18 | 0.0% | 0.304 | 7.94x |
| static_paper | paper | vb | 4 / 18 | 22.2% | 0 / 18 | 0.0% | 2.843 | 84.11x |
| static_shrink | rhs_ns | mcmc | 1 / 18 | 5.6% | 0 / 18 | 0.0% | 0.197 | 8.59x |
| static_shrink | rhs_ns | vb | 0 / 18 | 0.0% | 0 / 18 | 0.0% | 0.836 | 16.15x |
| static_shrink | ridge | mcmc | 1 / 18 | 5.6% | 0 / 18 | 0.0% | 0.179 | 7.85x |
| static_shrink | ridge | vb | 3 / 18 | 16.7% | 0 / 18 | 0.0% | 0.797 | 72.35x |

## Dynamic Model Comparison Within Inference

| inference | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|
| mcmc | 3 / 9 | 33.3% | 0 / 18 | 0.0% | 88.256 | 1.20x |
| vb | 0 / 9 | 0.0% | 0 / 18 | 0.0% | 680.066 | 7.51x |

## Dynamic Model Comparison By Tau

| inference | tau_label | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|---|
| mcmc | 0p05 | 1 / 3 | 33.3% | 0 / 6 | 0.0% | 41.458 | 1.20x |
| mcmc | 0p25 | 2 / 3 | 66.7% | 0 / 6 | 0.0% | -63.616 | 1.23x |
| mcmc | 0p95 | 0 / 3 | 0.0% | 0 / 6 | 0.0% | 286.926 | 1.18x |
| vb | 0p05 | 0 / 3 | 0.0% | 0 / 6 | 0.0% | 133.370 | 13.06x |
| vb | 0p25 | 0 / 3 | 0.0% | 0 / 6 | 0.0% | 24.962 | 5.32x |
| vb | 0p95 | 0 / 3 | 0.0% | 0 / 6 | 0.0% | 1881.865 | 7.51x |

## Algorithm Comparison Within Model

Static:

| block | prior_semantics | model | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|---|---|
| static_paper | paper | al | 13 / 18 | 72.2% | 0 / 18 | 0.0% | -0.044 | 91.65x |
| static_paper | paper | exal | 9 / 18 | 50.0% | 1 / 18 | 5.6% | -2.583 | 9.20x |
| static_shrink | rhs_ns | al | 13 / 18 | 72.2% | 0 / 18 | 0.0% | -0.024 | 57.82x |
| static_shrink | rhs_ns | exal | 9 / 18 | 50.0% | 1 / 18 | 5.6% | -0.663 | 29.17x |
| static_shrink | ridge | al | 15 / 18 | 83.3% | 0 / 18 | 0.0% | -0.031 | 86.56x |
| static_shrink | ridge | exal | 8 / 18 | 44.4% | 1 / 18 | 5.6% | -0.649 | 8.22x |

Dynamic:

| model | better | better_share | healthier | healthier_share | delta_mean | runtime_ratio |
|---|---|---|---|---|---|---|
| dqlm | 6 / 9 | 66.7% | 0 / 18 | 0.0% | -13.558 | 62.96x |
| exdqlm | 8 / 9 | 88.9% | 1 / 18 | 5.6% | -605.368 | 10.27x |

## Interpretation

- the corrected current-state comparison does not support a broad static `mcmc` claim that `exal` is better than `al` overall
- the dynamic side remains more mixed and should be interpreted separately from the static `exal` claim
- the strongest corrected static signal remains `mcmc`: all three static `mcmc` clusters now favor `exal` on the current primary-accuracy metric
- the dynamic picture is cluster-dependent: `tau = 0p95` is the main `exdqlm` win region, while `0p05` and `0p25` remain unfavorable in `mcmc`
- within-model algorithm comparisons now show that static `exal` usually benefits from `mcmc` over `vb`, while dynamic `exdqlm` more often favors `vb` on the current primary-accuracy metric
- this pass is reproducible because it no longer depends on missing historical fit-RDS paths for the majority of rows
- the older fit-RDS-based `20260409` comparison outputs should now be treated as superseded for the corrected `rhs_ns` question

## Outputs

- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_tablebacked_metric_long_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_static_model_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_dynamic_model_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_static_algorithm_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_dynamic_algorithm_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_static_model_cluster_summary_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_dynamic_tt5000_repair_20260414/original288_dynamic_model_cluster_summary_20260411.csv`
