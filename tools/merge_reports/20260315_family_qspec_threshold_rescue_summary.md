# Family-QSpec Threshold Rescue Analysis

## Soft-Failure Metric Surface

| inference | model | count | median ESS sigma | median ESS gamma | median ESS state | max ACF1 gamma | q75 Geweke state | q75 drift gamma |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| mcmc | dqlm | 18 | 288.52 |  NA | 242.27 |   NA | 12.73 |  NA |
| mcmc | exal | 35 | 20.47 | 3.10 | 59.43 | 0.997 | 1.20 | 1.44 |
| mcmc | exdqlm | 18 | 9.17 | 3.96 | 195.28 | 0.999 | 13.21 | 1.44 |
| vb | exdqlm | 5 |  NA |  NA |  NA |   NA |  NA |  NA |

## Threshold Rescue Scenarios

| scenario | rescued soft rows | rescued pct | ESS min | ACF1 max | Geweke max | drift max |
|---|---:|---:|---:|---:|---:|---:|
| Current recommended policy | 0 | 0.0 | 5 | 0.995 | 5 | 0.75 |
| Moderate MCMC threshold relaxation | 23 | 30.3 | 3 | 0.998 | 7.5 | 1 |
| Aggressive MCMC threshold relaxation | 46 | 60.5 | 1 | 0.999 | 10 | 1.5 |

## Residual Triage Classes

| class | count |
|---|---:|
| aggressive_policy_only_rescue | 23 |
| needs_deeper_chain | 25 |
| needs_model_or_vb_debug | 5 |
| threshold_only_rescue_moderate | 23 |

## Full Residual Action Plan

| class | count |
|---|---:|
| aggressive_policy_only_rescue | 23 |
| hard_numerical_repair | 4 |
| mixed_debug_and_resample | 20 |
| needs_deeper_chain | 25 |
| needs_model_or_vb_debug | 5 |
| threshold_only_rescue_moderate | 23 |
