# Original288 V7 Metric Comparison

Date: 2026-04-09

This note summarizes the broader metric-comparison layer for the accepted
`original288 / v7` carryforward selection. Unlike the earlier comparison bundle,
this layer focuses on fit/performance metrics rather than only the
`PASS / WARN / FAIL` health gates.

## Inputs

- Selection:
  `tools/merge_reports/LOCAL_original288_carryforward_selection_v7_20260407.csv`
- Metric extractor:
  `tools/merge_reports/LOCAL_original288_metric_comparison_20260409.R`
- Outputs:
  `tools/merge_reports/original288_metric_comparison_20260409/`

## Coverage

- Selected rows processed: `288 / 288`
- Static rows: `216`
- Dynamic rows: `72`
- Metric extraction hard-fail rows: `0`

Important caveat for the static broader layer:
- `CIE` is only defined for the paper-style static block, not for the shrinkage
  blocks.
- Some VB `q_rmse` comparisons are only partially available; the summary tables
  include explicit `*_available_n` counts for that reason.

## Broader Static Summary

Matched AL vs exAL pairs:
- total static matched pairs: `108`
- available `q_rmse` pairs: `90`
- available `CIE` pairs: `36`
- available `beta_rmse` pairs: `108`
- available `beta_coverage_gap` pairs: `108`

Overall static win counts for exAL:

| Metric | exAL better | Available |
|---|---:|---:|
| `q_rmse` | `53` | `90` |
| `CIE` | `25` | `36` |
| `beta_rmse_mean` | `74` | `108` |
| `beta_coverage_gap` | `68` | `108` |

Main static read:
- `exal` looks **better overall on fit metrics**, especially for MCMC.
- The strongest and cleanest advantage is in the paper-style MCMC block.
- Static VB is more mixed: coverage often improves, but `q_rmse` and
  `beta_rmse` do not dominate as cleanly as in MCMC.

By block / prior / inference:

| Block | Prior | Inference | Main read |
|---|---|---|---|
| `static_paper` | `paper` | `mcmc` | strongest exAL win: better median `q_rmse`, `CIE`, `beta_rmse`, and coverage gap |
| `static_paper` | `paper` | `vb` | mixed: coverage improves strongly, but `q_rmse` / `beta_rmse` are not uniformly better |
| `static_shrink` | `rhs` | `mcmc` | exAL modestly better on `q_rmse`, `beta_rmse`, and coverage gap |
| `static_shrink` | `rhs` | `vb` | near tie on `q_rmse`, slight loss on `beta_rmse`, small coverage improvement |
| `static_shrink` | `ridge` | `mcmc` | exAL clearly better on `q_rmse`, `beta_rmse`, and coverage gap |
| `static_shrink` | `ridge` | `vb` | exAL better on `q_rmse` and coverage gap, roughly flat-to-worse on `beta_rmse` |

Notable static wins for exAL:
- `static_paper / laplace / tau 0.05 / TT100 / mcmc`
- `static_paper / laplace / tau 0.95 / TT100 / vb`
- `static_shrink / ridge / laplace / tau 0.95 / TT100 / mcmc`

Static caution:
- exAL is still much slower in the broader accepted study, with median
  runtime ratios ranging from about `2.3x` to `83.6x` depending on block and
  inference.

## Broader Dynamic Summary

Matched DQLM vs exDQLM pairs:
- total dynamic matched pairs: `36`
- all five dynamic metrics available for all `36`

Overall dynamic win counts for exDQLM:

| Metric | exDQLM better | Available |
|---|---:|---:|
| `q_rmse` | `10` | `36` |
| `pplc` | `25` | `36` |
| `crps` | `18` | `36` |
| `interval_score_mean` | `15` | `36` |
| `coverage95_gap` | `19` | `36` |

Main dynamic read:
- Dynamic is **mixed and metric-dependent**.
- `exdqlm` looks better more often on tail-loss style metrics (`pplc`, often
  `crps`) than on point-path `q_rmse`.
- The dynamic MCMC comparison is especially discordant: some of the largest
  exDQLM wins on `pplc` / `crps` occur in the same scenarios where exDQLM loses
  badly on `q_rmse`.
- Dynamic VB is even more polarized:
  - strong `pplc` improvement (`18 / 18`)
  - some `crps` improvement (`12 / 18`)
  - much worse calibration / coverage in many scenarios

By inference:

| Inference | Main read |
|---|---|
| `mcmc` | exDQLM usually loses on `q_rmse`, but often improves `coverage95_gap` and sometimes `interval_score`; some extreme 0.95-tail cases drive very large `pplc` / `crps` gains |
| `vb` | exDQLM wins decisively on `pplc`, is mixed on `q_rmse` and `crps`, and often loses badly on `coverage95_gap` / interval score |

Notable dynamic discordance:
- `mcmc / gausmix / tau 0.95 / TT500`
- `mcmc / laplace / tau 0.95 / TT500`
- `mcmc / normal / tau 0.95 / TT500`

These cases show:
- much worse `q_rmse` for exDQLM
- but much better `pplc`, `crps`, interval score, and coverage gap

That pattern suggests the dynamic comparison should not be reduced to one
winner-take-all metric.

## Main Takeaways

1. The broader metric layer is materially more favorable to `exal` than the
   earlier gate-based broader comparison.
2. Static MCMC is now the clearest broad-study success story for `exal`.
3. Static VB is mixed but still often favorable on coverage-oriented metrics.
4. Dynamic `exdqlm` is not a simple overall winner:
   it helps on some predictive-loss metrics, but the tradeoffs with `q_rmse`
   and calibration can be large.
5. The paper-aligned benchmark and the broader static metric layer now point in
   the same qualitative direction:
   the scientific fit-performance story for static exAL is better than the
   old health-gate story made it look.
