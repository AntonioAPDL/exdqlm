# Family-QSpec Post-Repair Delta

## Aggregate Delta

| metric | before | after | delta |
|---|---:|---:|---:|
| method_fit_pass_count | 93 | 93 | +0 |
| method_fit_warn_count | 118 | 119 | +1 |
| method_fit_fail_count | 77 | 76 | -1 |
| method_fit_eligible_count | 211 | 212 | +1 |
| method_fit_certified_count | 93 | 93 | +0 |
| algorithm_pair_eligible_count | 86 | 86 | +0 |
| model_pair_eligible_count | 74 | 75 | +1 |
| root_full_eligible_count | 21 | 21 | +0 |
| root_any_eligible_count | 69 | 69 | +0 |
| unhealthy_target_count | 77 | 76 | -1 |

## Reason Delta

| reason | before | after | delta |
|---|---:|---:|---:|
| non_finite_fit | 24 | 27 | +3 |
| half_chain_drift | 37 | 25 | -12 |
| geweke_drift | 27 | 23 | -4 |
| ld_unstable | 23 | 23 | +0 |
| vb_converged_false | 23 | 23 | +0 |
| elbo_tail_unstable | 18 | 18 | +0 |
| missing_elbo_trace | 18 | 18 | +0 |
| low_ess | 26 | 17 | -9 |
| high_autocorrelation | 11 | 13 | +2 |
| core_parameter_tail_unstable | 5 | 5 | +0 |

## Residual Failure Buckets

| bucket | count |
|---|---:|
| soft_only | 49 |
| mixed | 21 |
| hard_only | 6 |

## Residual Bucket By Model

| inference | model | bucket | count |
|---|---|---|---:|
| mcmc | dqlm | soft_only | 7 |
| mcmc | exal | hard_only | 6 |
| mcmc | exal | mixed | 3 |
| mcmc | exal | soft_only | 21 |
| mcmc | exdqlm | soft_only | 16 |
| vb | exal | mixed | 18 |
| vb | exdqlm | soft_only | 5 |

## Row-Level Change Classes

| class | count |
|---|---:|
| unchanged | 63 |
| changed | 13 |
| resolved | 1 |
