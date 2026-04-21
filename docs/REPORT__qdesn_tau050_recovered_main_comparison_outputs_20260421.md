## QDESN Tau050 Recovered Main Comparison Outputs

Date: `2026-04-21`  
Status: canonical recovered-source 144-case main-comparison rerun completed from clean implementation SHA `86be927`

## Canonical Run

- implementation commit: `86be927`
- source run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`
- recovered comparison run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-recovered-maincmp-20260421-024204__git-86be927`
- analysis root:
  - [recovered main comparison analysis root](../reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-recovered-maincmp-20260421-024204__git-86be927)
- primary outputs:
  - [main analysis summary](../reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-recovered-maincmp-20260421-024204__git-86be927/summary/qdesn_dynamic_main_comparison_analysis.md)
  - [QDESN vs reference comparison summary](../reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-tau050-recovered-maincmp-20260421-024204__git-86be927/comparison_vs_reference/comparison_summary.md)

## Purpose

This rerun rebuilds the authoritative tau050 `144`-fit validation surface after the failed-run
recovery program. The original source campaign contained `23` hard MCMC runtime crashes. Those
failures have now been overlaid from the completed repair waves, so the main-comparison pack can be
read as the recovered source state rather than the original crash-contaminated source state.

## Recovered Source State

| Metric | Value |
|---|---:|
| fit rows | 144 |
| fit `PASS` | 77 |
| fit `WARN` | 27 |
| fit `FAIL` | 40 |
| fit runtime `FAIL` | 0 |
| root rows | 36 |
| root-status `FAIL` | 0 |
| roots with any comparison-eligible path | 33 |
| roots with full comparison-eligible path | 15 |
| representative-case rows | 36 |
| representative `PASS` | 33 |
| representative `WARN` | 3 |
| representative `FAIL` | 0 |
| recovered override rows | 23 |

## Main Read

The most important transition is:

- the tau050 study no longer has a runtime-failure problem
- it now has a signoff-quality and comparison-readiness problem

That is a much better place to be. The repaired surface is operationally complete, but not every
fit is equally strong for study-facing comparison.

## Fit-Level Patterns

### By inference

| Inference | Rows | PASS | WARN | FAIL | PASS+WARN | Comparison-eligible rate |
|---|---:|---:|---:|---:|---:|---:|
| `mcmc` | 72 | 21 | 16 | 35 | 37 | 51.4% |
| `vb` | 72 | 56 | 11 | 5 | 67 | 93.1% |

### By model

| Model | Rows | PASS | WARN | FAIL | PASS+WARN | Comparison-eligible rate |
|---|---:|---:|---:|---:|---:|---:|
| `al` | 72 | 46 | 9 | 17 | 55 | 76.4% |
| `exal` | 72 | 31 | 18 | 23 | 49 | 68.1% |

### Remaining `FAIL` rows

| Slice | Count |
|---|---:|
| total remaining signoff `FAIL` rows | 40 |
| `mcmc` | 35 |
| `vb` | 5 |
| `al` | 17 |
| `exal` | 23 |
| `rhs_ns` | 37 |
| `ridge` | 3 |

Remaining failure reasons are dominated by:

| Signoff reason fragment | Count |
|---|---:|
| `high_autocorrelation` | 35 |
| `geweke_drift` | 12 |
| `half_chain_drift` | 6 |
| `core_parameter_tail_unstable` | 5 |

Interpretation:

- the remaining weak surface is overwhelmingly an `mcmc` signoff issue
- it is also overwhelmingly concentrated in the `rhs_ns` prior
- the small non-MCMC remainder is limited to `vb exal` tail-instability cases

## Root-Level Comparison Readiness

### By prior

| Prior | Roots | Any comparison-eligible | Full comparison-eligible |
|---|---:|---:|---:|
| `rhs_ns` | 18 | 15 | 0 |
| `ridge` | 18 | 18 | 15 |

Interpretation:

- `ridge` is the comparison-ready surface
- `rhs_ns` remains valuable as a diagnostic / stress prior, but it is not the clean primary
  study-facing comparison surface

## Representative Surface

Representative selection is now very clean:

| Representative slice | Count |
|---|---:|
| total representative rows | 36 |
| `PASS` | 33 |
| `WARN` | 3 |
| `FAIL` | 0 |
| `vb` | 36 |
| `al` | 24 |
| `exal` | 12 |

Representative selection counts:

| Signoff | Inference | Model | Selected |
|---|---|---|---:|
| `PASS` | `vb` | `al` | 21 |
| `WARN` | `vb` | `al` | 3 |
| `PASS` | `vb` | `exal` | 12 |

Interpretation:

- the canonical representative layer is now entirely `vb`
- that is not a bug; it reflects the actual strongest recovered study-facing surface
- if we want one clean main table for the recovered tau050 study, the representative layer is the
  most defensible one

## Reference Comparison Read

The comparison-vs-reference pack completed successfully, but it carries one important contract
limitation:

- the mirrored dynamic reference inventory still uses `tau in {0.05, 0.25, 0.95}`
- the recovered tau050 QDESN surface uses `tau in {0.05, 0.25, 0.50}`

So:

- shared-surface comparison is valid where the contracts align
- tau `0.50` QDESN rows do not have like-for-like mirrored reference deltas in the current pack
- those rows should be treated as descriptive QDESN results unless the mirrored reference is rerun
  under the tau050 contract

## Outcome

This recovered comparison pack is now the authoritative tau050 post-recovery study surface.

The repair program succeeded at the operational level:

- `23 / 23` original hard runtime crashes are now recovered
- `0 / 144` fits remain runtime `FAIL`
- `0 / 36` roots remain root-status `FAIL`

The remaining work is scientific interpretation and presentation, not crash repair.
