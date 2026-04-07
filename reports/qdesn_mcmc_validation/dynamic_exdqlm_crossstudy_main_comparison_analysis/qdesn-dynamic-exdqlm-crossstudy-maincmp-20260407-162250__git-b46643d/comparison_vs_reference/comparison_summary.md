# QDESN Dynamic Cross-Study vs exdqlm Reference

## Reference Surface
- reference_root_dirs: `18`
- reference_fit_rows: `72`
- reference_pair_rows: `36`

## QDESN Surface
- qdesn_root_rows: `36`
- qdesn_fit_rows: `144`
- qdesn_pair_rows: `72`

## Important Interpretation Note

- This comparison is valid on the shared mirrored dynamic dataset surface.
- The exdqlm side remains the canonical dynamic reference.
- The QDESN side preserves the additional prior axis (`ridge` / `rhs_ns`) explicitly.

## Reference Root Group Summary
| scenario | root_kind | family | tau | fit_size | n_roots | comparison_eligible_any_rate | comparison_eligible_full_rate |
|---|---|---|---|---|---|---|---|
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | 1 | 1 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | 1 | 1 | 0 |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | 1 | 1 | 1 |

## QDESN Root Group Summary
| scenario | root_kind | family | tau | fit_size | prior | n_roots | n_success | n_fail | root_success_rate | root_comparison_eligible_any_rate | root_comparison_eligible_full_rate | method_comparison_eligible_rate_mean | algorithm_pair_comparison_eligible_rate_mean | model_pair_comparison_eligible_rate_mean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 0 | 0.75 | 0.5 | 0.5 |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 0 | 0.75 | 0.5 | 0.5 |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1.00 | 1.0 | 1.0 |

## Reference Pair Group Summary
| scenario | root_kind | family | tau | fit_size | model | n_rows | n_pass | n_warn | n_fail | pass_rate | warn_rate | fail_rate | comparison_eligible_rate | runtime_ratio_mcmc_vs_vb_mean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | exdqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | dqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | exdqlm | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | dqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | exdqlm | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | NA |

## QDESN Pair Group Summary
| scenario | root_kind | family | tau | fit_size | prior | model | n_rows | n_pass | n_warn | n_fail | pass_rate | warn_rate | fail_rate | comparison_eligible_rate | runtime_ratio_mcmc_vs_vb_mean | mae_delta_mcmc_minus_vb_mean |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1.865 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 2.674 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 3.358 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 5.063 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | rhs_ns | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 4.211 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 7.454 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 5.776 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 10.427 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | rhs_ns | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 2.761 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 5.441 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 7.042 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 16.871 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 6.517 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 15.637 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 7.996 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | ridge | exal | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 24.822 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1.970 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 2.600 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 2.784 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 4.999 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.804 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 7.424 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 4.712 | NA |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 9.067 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1.563 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.188 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 3.582 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.930 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.744 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 6.858 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 5.363 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 10.226 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.397 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 5.819 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | ridge | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 6.441 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 15.779 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 6.217 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 15.419 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 8.716 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 20.817 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 2.194 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 2.723 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 3.196 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.900 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.692 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 7.544 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | ridge | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 5.318 | NA |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 10.035 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1.933 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 2.834 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 4.143 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 5.270 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 4.184 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | rhs_ns | exal | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 7.864 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 5.403 | NA |
| dlm_constV_smallW | dynamic | normal | 0.05 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 10.112 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1.952 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.693 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 6.673 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 16.341 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 6.187 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 15.708 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 6.309 | NA |
| dlm_constV_smallW | dynamic | normal | 0.25 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 22.009 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | rhs_ns | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 1.954 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | rhs_ns | exal | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 2.816 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 3.326 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 500 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 4.790 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | rhs_ns | al | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 3.542 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | rhs_ns | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 7.613 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | ridge | al | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 4.910 | NA |
| dlm_constV_smallW | dynamic | normal | 0.95 | 5000 | ridge | exal | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 9.772 | NA |

## QDESN vs Reference Surface Delta
| scenario | root_kind | family | tau | fit_size | prior | n_roots_qdesn | n_success | n_fail | root_success_rate | root_comparison_eligible_any_rate | root_comparison_eligible_full_rate | method_comparison_eligible_rate_mean | algorithm_pair_comparison_eligible_rate_mean | model_pair_comparison_eligible_rate_mean | n_roots_reference | comparison_eligible_any_rate | comparison_eligible_full_rate | comparison_eligible_any_rate_delta | comparison_eligible_full_rate_delta |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.05 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.25 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 |
| dlm_constV_smallW | dynamic | gausmix | 0.95 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.05 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.25 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 500 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | rhs_ns | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
| dlm_constV_smallW | dynamic | laplace | 0.95 | 5000 | ridge | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | 1 |
