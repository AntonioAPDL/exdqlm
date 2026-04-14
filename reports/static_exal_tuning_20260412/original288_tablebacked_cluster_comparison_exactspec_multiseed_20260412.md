# Original288 Table-Backed Cluster Comparison (Exact-Spec Replay, 2026-04-14)

This note refreshes the fit-performance comparison after the completed exact-spec multiseed replay. It reuses the recent table-backed comparison framework, but now evaluates the replay-selected winners rather than the earlier accepted `v9` snapshot.

## Scope

- start from the corrected `rhs_ns` comparison selection (`288` rows)
- preserve each row's prior winning local spec and replay under the standardized exact-spec controls
- select one winner per row from the deterministic `4`-seed replay
- compare within inference (`al` vs `exal`, `dqlm` vs `exdqlm`) and within model (`vb` vs `mcmc`) on fit-performance metrics

## Replay Rule

- preserve row-local kernels, proposals, joint/non-joint choices, adapt/no-adapt settings, refresh cadence, widths, and initialization strategy
- change only `n.burn = 5000`, `n.mcmc = 20000`, stored posterior draws `= 20000`, and the deterministic `4`-seed selection rule

## Data Quality

- selected rows: `288`
- metric rows built: `288`
- metric extraction errors: `36`
- static model pairs: `108`
- dynamic model pairs: `36`

| metric_error | count | share_of_rows |
|---|---|---|
| system is computationally singular: reciprocal condition number = 1.73213e-50 | 36 | 12.5% |

## Main Results

- static `mcmc`: `exal` has better primary accuracy in `5 / 54` scenario pairs (`9.3%`)
- static `vb`: `exal` has better primary accuracy in `7 / 54` scenario pairs (`13.0%`)
- dynamic `mcmc`: `exdqlm` has better primary accuracy in `3 / 9` comparable scenario pairs (`33.3%`)
- dynamic `vb`: `exdqlm` has better primary accuracy in `0 / 9` comparable scenario pairs (`0.0%`)

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

- this exact-spec replay does **not** support the older static claim that `exal` is better than `al` overall within `mcmc` on the current primary-accuracy metric
- the static side is broadly unfavorable for `exal` in this replay: `5 / 54` better pairs in `mcmc` and `7 / 54` in `vb`
- the dynamic side is only partially comparable because `36` replay rows failed metric extraction with the same computationally singular error, leaving `9 / 18` comparable model pairs in each dynamic inference lane
- within the comparable dynamic `mcmc` pairs, `exdqlm` is mixed but not hopeless (`3 / 9` better), with the strongest pocket at `tau = 0p25`
- dynamic `vb` is unfavorable on the current primary-accuracy metric in this replay (`0 / 9` better pairs)
- within-model inference comparisons now lean toward `mcmc` more than the older accepted-state comparison did: dynamic `exdqlm` has `8 / 9` available pairs where `mcmc` beats `vb` on the current primary-accuracy metric
- this pass is reproducible and directly tied to the completed exact-spec replay outputs rather than a mixed accepted-state carryforward snapshot

## Outputs

- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_tablebacked_metric_long_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_static_model_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_dynamic_model_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_static_algorithm_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_dynamic_algorithm_pair_comparison_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_static_model_cluster_summary_20260411.csv`
- `tools/merge_reports/original288_tablebacked_comparison_exactspec_multiseed_20260412/original288_dynamic_model_cluster_summary_20260411.csv`
