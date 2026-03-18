# Family-QSpec Post-Repair Delta

## Aggregate Delta

| metric | before | after | delta |
|---|---:|---:|---:|
| method_fit_pass_count | 93 | 93 | +0 |
| method_fit_warn_count | 119 | 127 | +8 |
| method_fit_fail_count | 76 | 68 | -8 |
| method_fit_eligible_count | 212 | 220 | +8 |
| method_fit_certified_count | 93 | 93 | +0 |
| algorithm_pair_eligible_count | 86 | 88 | +2 |
| model_pair_eligible_count | 75 | 83 | +8 |
| root_full_eligible_count | 21 | 23 | +2 |
| root_any_eligible_count | 69 | 72 | +3 |
| unhealthy_target_count | 76 | 68 | -8 |

## Reason Delta

| reason | before | after | delta |
|---|---:|---:|---:|
| half_chain_drift | 25 | 25 | +0 |
| non_finite_fit | 27 | 21 | -6 |
| geweke_drift | 22 | 21 | -1 |
| ld_unstable | 23 | 20 | -3 |
| vb_converged_false | 23 | 20 | -3 |
| elbo_tail_unstable | 18 | 18 | +0 |
| missing_elbo_trace | 18 | 18 | +0 |
| low_ess | 15 | 18 | +3 |
| high_autocorrelation | 11 | 8 | -3 |
| core_parameter_tail_unstable | 5 | 2 | -3 |

## Residual Failure Buckets

| bucket | count |
|---|---:|
| soft_only | 47 |
| mixed | 21 |

## Residual Bucket By Model

| inference | model | bucket | count |
|---|---|---|---:|
| mcmc | dqlm | soft_only | 7 |
| mcmc | exal | mixed | 3 |
| mcmc | exal | soft_only | 22 |
| mcmc | exdqlm | soft_only | 16 |
| vb | exal | mixed | 18 |
| vb | exdqlm | soft_only | 2 |

## Row-Level Change Classes

| class | count |
|---|---:|
| unchanged | 60 |
| changed | 8 |
| resolved | 8 |
