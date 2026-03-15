# Family-QSpec Post-Repair Delta

## Aggregate Delta

| metric | before | after | delta |
|---|---:|---:|---:|
| method_fit_pass_count | 93 | 93 | +0 |
| method_fit_warn_count | 95 | 95 | +0 |
| method_fit_fail_count | 100 | 100 | +0 |
| method_fit_eligible_count | 188 | 188 | +0 |
| method_fit_certified_count | 93 | 93 | +0 |
| algorithm_pair_eligible_count | 64 | 64 | +0 |
| model_pair_eligible_count | 62 | 62 | +0 |
| root_full_eligible_count | 10 | 10 | +0 |
| root_any_eligible_count | 67 | 67 | +0 |
| unhealthy_target_count | 100 | 100 | +0 |

## Reason Delta

| reason | before | after | delta |
|---|---:|---:|---:|
| geweke_drift | 50 | 50 | +0 |
| low_ess | 44 | 45 | +1 |
| half_chain_drift | 40 | 42 | +2 |
| non_finite_fit | 24 | 24 | +0 |
| ld_unstable | 23 | 23 | +0 |
| vb_converged_false | 23 | 23 | +0 |
| high_autocorrelation | 21 | 22 | +1 |
| elbo_tail_unstable | 18 | 18 | +0 |
| missing_elbo_trace | 18 | 18 | +0 |
| core_parameter_tail_unstable | 5 | 5 | +0 |

## Residual Failure Buckets

| bucket | count |
|---|---:|
| soft_only | 76 |
| mixed | 20 |
| hard_only | 4 |

## Residual Bucket By Model

| inference | model | bucket | count |
|---|---|---|---:|
| mcmc | dqlm | soft_only | 18 |
| mcmc | exal | hard_only | 4 |
| mcmc | exal | mixed | 2 |
| mcmc | exal | soft_only | 35 |
| mcmc | exdqlm | soft_only | 18 |
| vb | exal | mixed | 18 |
| vb | exdqlm | soft_only | 5 |

## Row-Level Change Classes

| class | count |
|---|---:|
| unchanged | 97 |
| changed | 3 |
