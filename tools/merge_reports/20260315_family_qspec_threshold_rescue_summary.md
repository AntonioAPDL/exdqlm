# Family-QSpec Threshold Rescue Analysis

## Soft-Failure Metric Surface

| inference | model | count | median ESS sigma | median ESS gamma | median ESS state | max ACF1 gamma | q75 Geweke state | q75 drift gamma |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| mcmc | dqlm | 7 | 1841.23 |  NA | 102.49 |   NA | 14.77 |  NA |
| mcmc | exal | 20 | 23.12 | 3.04 | 70.86 | 0.999 | 0.82 | 1.34 |
| mcmc | exdqlm | 16 | 10.48 | 5.75 | 115.01 | 0.999 | 14.17 | 1.39 |
| vb | exdqlm | 5 |  NA |  NA |  NA |   NA |  NA |  NA |

## Threshold Rescue Scenarios

| scenario | rescued soft rows | rescued pct | ESS min | ACF1 max | Geweke max | drift max |
|---|---:|---:|---:|---:|---:|---:|
| Current recommended policy | 0 | 0.0 | 5 | 0.995 | 5 | 0.75 |
| Moderate MCMC threshold relaxation | 0 | 0.0 | 3 | 0.998 | 7.5 | 1 |
| Aggressive MCMC threshold relaxation | 27 | 56.2 | 1 | 0.999 | 10 | 1.5 |

## Residual Triage Classes

| class | count |
|---|---:|
| aggressive_policy_only_rescue | 27 |
| needs_deeper_chain | 16 |
| needs_model_or_vb_debug | 5 |

## Full Residual Action Plan

| class | count |
|---|---:|
| aggressive_policy_only_rescue | 27 |
| hard_numerical_repair | 6 |
| mixed_debug_and_resample | 21 |
| needs_deeper_chain | 16 |
| needs_model_or_vb_debug | 5 |
