# QDESN Dynamic exdqlm Cross-Study Main Comparison Analysis

- generated_at: `2026-04-07 16:22:54.091634`
- source_run_tag: `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`
- source_mode: `prior_fitfail_wave`
- source_label: `Merged Local Baseline After Prior Targeted Wave`
- final_wave_evidence_run_tag: `qdesn-dynamic-exdqlm-crossstudy-finalfail-20260407-133928__git-512e982`

## Authoritative Local Baseline Map
| stage_id | local_baseline_profile | recommendation |
|---|---|---|
| R1_gausmix_tt5000_residual | L640_gmix_long_split_diag | USE_L640_gmix_long_split_diag_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R1_gausmix_tt5000_residual |
| R2_gausmix_tt500_residual | L670_gmix_short_diag_mix | USE_L670_gmix_short_diag_mix_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R2_gausmix_tt500_residual |
| R3_ridge_tt5000_singleton_residual | L720_ridge_long_softgamma_plus | USE_L720_ridge_long_softgamma_plus_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R3_ridge_tt5000_singleton_residual |
| R4_rhs_tt5000_residual | L760_rhs_long_vbguard_deep | USE_L760_rhs_long_vbguard_deep_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R4_rhs_tt5000_residual |
| R5_short_horizon_mixed_residual | L770_short_mixed_local_mcmc | USE_L770_short_mixed_local_mcmc_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R5_short_horizon_mixed_residual |

## Full-Study Overview
| metric | value |
|---|---|
| fit_rows_total | 144 |
| fit_pass_n | 77 |
| fit_warn_n | 65 |
| fit_fail_n | 2 |
| root_total | 36 |
| root_status_fail_n | 0 |
| root_compare_any_n | 36 |
| root_compare_full_n | 34 |

## Root Readiness
- comparison_eligible_any_roots: `36 / 36`
- comparison_eligible_full_roots: `34 / 36`
- root_status_fail_n: `0`

## Fit Signoff By Prior
| prior | n_rows | n_pass | n_warn | n_fail | pass_rate | warn_rate | fail_rate | comparison_eligible_rate | runtime_sec_mean | runtime_sec_median | runtime_sec_p90 | runtime_sec_total | holdout_mae_mean | holdout_mae_median | holdout_mae_p90 | holdout_rmse_mean | holdout_rmse_median | holdout_rmse_p90 | train_mae_mean | train_mae_median | train_mae_p90 | train_rmse_mean | train_rmse_median | train_rmse_p90 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rhs_ns | 72 | 24 | 46 | 2 | 0.333 | 0.639 | 0.028 | 0.972 | 12.329 | 5.915 | 41.608 | 887.685 | 136.063 | 9.975 | 118.774 | 136.063 | 9.975 | 118.774 | NA | NA | NA | NA | NA | NA |
| ridge | 72 | 53 | 19 | 0 | 0.736 | 0.264 | 0.000 | 1.000 | 12.185 | 5.093 | 47.960 | 877.331 | 155.824 | 24.719 | 226.942 | 155.824 | 24.719 | 226.942 | NA | NA | NA | NA | NA | NA |

## Fit Signoff / Runtime By Inference + Model
| inference | model | n_rows | n_pass | n_warn | n_fail | pass_rate | warn_rate | fail_rate | comparison_eligible_rate | runtime_sec_mean | runtime_sec_median | runtime_sec_p90 | runtime_sec_total | holdout_mae_mean | holdout_mae_median | holdout_mae_p90 | holdout_rmse_mean | holdout_rmse_median | holdout_rmse_p90 | train_mae_mean | train_mae_median | train_mae_p90 | train_rmse_mean | train_rmse_median | train_rmse_p90 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mcmc | al | 36 | 23 | 13 | 0 | 0.639 | 0.361 | 0.000 | 1.000 | 11.789 | 12.251 | 18.678 | 424.397 | 72.861 | 50.962 | 159.926 | 72.861 | 50.962 | 159.926 | NA | NA | NA | NA | NA | NA |
| mcmc | exal | 36 | 1 | 33 | 2 | 0.028 | 0.917 | 0.056 | 0.944 | 30.502 | 26.222 | 51.454 | 1098.054 | 42.434 | 26.663 | 78.902 | 42.434 | 26.663 | 78.902 | NA | NA | NA | NA | NA | NA |
| vb | al | 36 | 29 | 7 | 0 | 0.806 | 0.194 | 0.000 | 1.000 | 2.831 | 2.947 | 4.545 | 101.931 | 7.165 | 5.441 | 14.627 | 7.165 | 5.441 | 14.627 | NA | NA | NA | NA | NA | NA |
| vb | exal | 36 | 24 | 12 | 0 | 0.667 | 0.333 | 0.000 | 1.000 | 3.906 | 4.071 | 5.996 | 140.634 | 461.313 | 10.514 | 2233.827 | 461.313 | 10.514 | 2233.827 | NA | NA | NA | NA | NA | NA |

## VB vs MCMC Pair Summary
| prior | model | fit_size | n_rows | n_pass | n_warn | n_fail | pass_rate | warn_rate | fail_rate | comparison_eligible_rate | runtime_ratio_mcmc_vs_vb_mean | runtime_ratio_mcmc_vs_vb_median | runtime_ratio_mcmc_vs_vb_p90 | mae_delta_mcmc_minus_vb_mean | mae_delta_mcmc_minus_vb_median | mae_delta_mcmc_minus_vb_p90 | rmse_delta_mcmc_minus_vb_mean | rmse_delta_mcmc_minus_vb_median | rmse_delta_mcmc_minus_vb_p90 | bias_delta_mcmc_minus_vb_mean | bias_delta_mcmc_minus_vb_median | bias_delta_mcmc_minus_vb_p90 | corr_delta_mcmc_minus_vb_mean | corr_delta_mcmc_minus_vb_median | corr_delta_mcmc_minus_vb_p90 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rhs_ns | al | 500 | 9 | 2 | 7 | 0 | 0.222 | 0.778 | 0.000 | 1.000 | 2.177 | 1.954 | 2.889 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| rhs_ns | al | 5000 | 9 | 1 | 8 | 0 | 0.111 | 0.889 | 0.000 | 1.000 | 4.678 | 4.184 | 6.277 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| rhs_ns | exal | 500 | 9 | 0 | 8 | 1 | 0.000 | 0.889 | 0.111 | 0.889 | 3.532 | 2.834 | 5.517 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| rhs_ns | exal | 5000 | 9 | 0 | 8 | 1 | 0.000 | 0.889 | 0.111 | 0.889 | 10.169 | 7.613 | 15.651 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| ridge | al | 500 | 9 | 8 | 1 | 0 | 0.889 | 0.111 | 0.000 | 1.000 | 4.505 | 3.582 | 6.747 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| ridge | al | 5000 | 9 | 8 | 1 | 0 | 0.889 | 0.111 | 0.000 | 1.000 | 6.056 | 5.403 | 8.140 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| ridge | exal | 500 | 9 | 0 | 9 | 0 | 0.000 | 1.000 | 0.000 | 1.000 | 8.549 | 5.063 | 16.447 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |
| ridge | exal | 5000 | 9 | 1 | 8 | 0 | 0.111 | 0.889 | 0.000 | 1.000 | 14.143 | 10.226 | 22.572 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA |

## QDESN vs Reference Runtime / Readiness Delta
| inference | canonical_model | fit_size | prior | model_qdesn | n_rows_qdesn | n_pass_qdesn | n_warn_qdesn | n_fail_qdesn | pass_rate_qdesn | warn_rate_qdesn | fail_rate_qdesn | comparison_eligible_rate_qdesn | runtime_sec_mean_qdesn | runtime_sec_median_qdesn | runtime_sec_p90_qdesn | runtime_sec_total_qdesn | fit_runtime_seconds_mean | fit_runtime_seconds_median | fit_runtime_seconds_p90 | holdout_mae_mean | holdout_mae_median | holdout_mae_p90 | holdout_rmse_mean | holdout_rmse_median | holdout_rmse_p90 | holdout_bias_mean | holdout_bias_median | holdout_bias_p90 | holdout_corr_mean | holdout_corr_median | holdout_corr_p90 | train_mae_mean | train_mae_median | train_mae_p90 | train_rmse_mean | train_rmse_median | train_rmse_p90 | train_bias_mean | train_bias_median | train_bias_p90 | train_corr_mean | train_corr_median | train_corr_p90 | model_reference | n_rows_reference | n_pass_reference | n_warn_reference | n_fail_reference | pass_rate_reference | warn_rate_reference | fail_rate_reference | comparison_eligible_rate_reference | runtime_sec_mean_reference | runtime_sec_median_reference | runtime_sec_p90_reference | runtime_sec_total_reference | pass_rate_delta_qdesn_minus_reference | warn_rate_delta_qdesn_minus_reference | fail_rate_delta_qdesn_minus_reference | comparison_eligible_rate_delta_qdesn_minus_reference | runtime_sec_mean_delta_qdesn_minus_reference | runtime_sec_median_delta_qdesn_minus_reference | runtime_sec_p90_delta_qdesn_minus_reference | runtime_sec_mean_ratio_qdesn_vs_reference |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mcmc | al | 500 | rhs_ns | al | 9 | 2 | 7 | 0 | 0.222 | 0.778 | 0.000 | 1.000 | 6.124 | 5.950 | 6.557 | 55.114 | 6.124 | 5.950 | 6.557 | 15.371 | 10.704 | 28.394 | 15.371 | 10.704 | 28.394 | -4.909 | -6.312 | 13.721 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 0 | 2 | 7 | 0.000 | 0.222 | 0.778 | 0.222 | NA | NA | NA | NA | 0.222 | 0.556 | -0.778 | 0.778 | NA | NA | NA | NA |
| mcmc | al | 500 | ridge | al | 9 | 8 | 1 | 0 | 0.889 | 0.111 | 0.000 | 1.000 | 5.168 | 5.089 | 5.488 | 46.510 | 5.168 | 5.089 | 5.488 | 53.460 | 60.693 | 90.932 | 53.460 | 60.693 | 90.932 | -2.575 | -14.516 | 79.398 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 0 | 2 | 7 | 0.000 | 0.222 | 0.778 | 0.222 | NA | NA | NA | NA | 0.889 | -0.111 | -0.778 | 0.778 | NA | NA | NA | NA |
| mcmc | al | 5000 | rhs_ns | al | 9 | 5 | 4 | 0 | 0.556 | 0.444 | 0.000 | 1.000 | 18.238 | 18.235 | 18.835 | 164.145 | 18.238 | 18.235 | 18.835 | 79.280 | 84.550 | 128.612 | 79.280 | 84.550 | 128.612 | 9.470 | -29.507 | 128.612 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 0 | 9 | 0 | 0.000 | 1.000 | 0.000 | 1.000 | NA | NA | NA | NA | 0.556 | -0.556 | 0.000 | 0.000 | NA | NA | NA | NA |
| mcmc | al | 5000 | ridge | al | 9 | 8 | 1 | 0 | 0.889 | 0.111 | 0.000 | 1.000 | 17.625 | 17.811 | 18.247 | 158.628 | 17.625 | 17.811 | 18.247 | 143.333 | 140.207 | 266.311 | 143.333 | 140.207 | 266.311 | -27.654 | -22.528 | 177.952 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 0 | 9 | 0 | 0.000 | 1.000 | 0.000 | 1.000 | NA | NA | NA | NA | 0.889 | -0.889 | 0.000 | 0.000 | NA | NA | NA | NA |
| mcmc | exal | 500 | rhs_ns | exal | 9 | 0 | 8 | 1 | 0.000 | 0.889 | 0.111 | 0.889 | 13.175 | 13.152 | 13.795 | 118.577 | 13.175 | 13.152 | 13.795 | 12.260 | 12.518 | 21.922 | 12.260 | 12.518 | 21.922 | -3.763 | -3.818 | 15.159 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 0 | 9 | 0.000 | 0.000 | 1.000 | 0.000 | NA | NA | NA | NA | 0.000 | 0.889 | -0.889 | 0.889 | NA | NA | NA | NA |
| mcmc | exal | 500 | ridge | exal | 9 | 0 | 9 | 0 | 0.000 | 1.000 | 0.000 | 1.000 | 13.913 | 14.444 | 14.952 | 125.219 | 13.913 | 14.444 | 14.952 | 35.979 | 27.323 | 67.264 | 35.979 | 27.323 | 67.264 | 0.472 | -20.665 | 67.264 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 0 | 9 | 0.000 | 0.000 | 1.000 | 0.000 | NA | NA | NA | NA | 0.000 | 1.000 | -1.000 | 1.000 | NA | NA | NA | NA |
| mcmc | exal | 5000 | rhs_ns | exal | 9 | 0 | 8 | 1 | 0.000 | 0.889 | 0.111 | 0.889 | 45.017 | 44.406 | 47.876 | 405.157 | 45.017 | 44.406 | 47.876 | 38.235 | 33.538 | 72.976 | 38.235 | 33.538 | 72.976 | 1.555 | -11.387 | 56.593 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 2 | 7 | 0.000 | 0.222 | 0.778 | 0.222 | NA | NA | NA | NA | 0.000 | 0.667 | -0.667 | 0.667 | NA | NA | NA | NA |
| mcmc | exal | 5000 | ridge | exal | 9 | 1 | 8 | 0 | 0.111 | 0.889 | 0.000 | 1.000 | 49.900 | 49.969 | 53.565 | 449.101 | 49.900 | 49.969 | 53.565 | 83.262 | 63.392 | 146.473 | 83.262 | 63.392 | 146.473 | -48.177 | -28.146 | 62.808 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 2 | 7 | 0.000 | 0.222 | 0.778 | 0.222 | NA | NA | NA | NA | 0.111 | 0.667 | -0.778 | 0.778 | NA | NA | NA | NA |
| vb | al | 500 | rhs_ns | al | 9 | 7 | 2 | 0 | 0.778 | 0.222 | 0.000 | 1.000 | 2.907 | 2.910 | 3.318 | 26.159 | 2.907 | 2.910 | 3.318 | 4.552 | 4.282 | 7.894 | 4.552 | 4.282 | 7.894 | -0.616 | -1.483 | 5.055 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 8 | 1 | 0 | 0.889 | 0.111 | 0.000 | 1.000 | NA | NA | NA | NA | -0.111 | 0.111 | 0.000 | 0.000 | NA | NA | NA | NA |
| vb | al | 500 | ridge | al | 9 | 9 | 0 | 0 | 1.000 | 0.000 | 0.000 | 1.000 | 1.285 | 1.489 | 1.629 | 11.564 | 1.285 | 1.489 | 1.629 | 7.429 | 7.871 | 10.775 | 7.429 | 7.871 | 10.775 | -3.162 | -5.821 | 6.312 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 8 | 1 | 0 | 0.889 | 0.111 | 0.000 | 1.000 | NA | NA | NA | NA | 0.111 | -0.111 | 0.000 | 0.000 | NA | NA | NA | NA |
| vb | al | 5000 | rhs_ns | al | 9 | 4 | 5 | 0 | 0.444 | 0.556 | 0.000 | 1.000 | 4.102 | 4.442 | 4.822 | 36.917 | 4.102 | 4.442 | 4.822 | 4.736 | 3.865 | 9.310 | 4.736 | 3.865 | 9.310 | -0.718 | -0.967 | 5.208 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 3 | 6 | 0 | 0.333 | 0.667 | 0.000 | 1.000 | NA | NA | NA | NA | 0.111 | -0.111 | 0.000 | 0.000 | NA | NA | NA | NA |
| vb | al | 5000 | ridge | al | 9 | 9 | 0 | 0 | 1.000 | 0.000 | 0.000 | 1.000 | 3.032 | 3.135 | 3.840 | 27.291 | 3.032 | 3.135 | 3.840 | 11.944 | 14.487 | 23.953 | 11.944 | 14.487 | 23.953 | -7.357 | -5.073 | 7.320 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | dqlm | 9 | 3 | 6 | 0 | 0.333 | 0.667 | 0.000 | 1.000 | NA | NA | NA | NA | 0.667 | -0.667 | 0.000 | 0.000 | NA | NA | NA | NA |
| vb | exal | 500 | rhs_ns | exal | 9 | 2 | 7 | 0 | 0.222 | 0.778 | 0.000 | 1.000 | 4.063 | 4.566 | 4.847 | 36.566 | 4.063 | 4.566 | 4.847 | 95.274 | 7.972 | 278.182 | 95.274 | 7.972 | 278.182 | -92.078 | -4.360 | 4.855 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 9 | 0 | 0.000 | 1.000 | 0.000 | 1.000 | NA | NA | NA | NA | 0.222 | -0.222 | 0.000 | 0.000 | NA | NA | NA | NA |
| vb | exal | 500 | ridge | exal | 9 | 9 | 0 | 0 | 1.000 | 0.000 | 0.000 | 1.000 | 2.376 | 2.897 | 3.576 | 21.380 | 2.376 | 2.897 | 3.576 | 88.344 | 10.552 | 250.509 | 88.344 | 10.552 | 250.509 | -83.902 | -10.552 | 7.314 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 9 | 0 | 0.000 | 1.000 | 0.000 | 1.000 | NA | NA | NA | NA | 1.000 | -1.000 | 0.000 | 0.000 | NA | NA | NA | NA |
| vb | exal | 5000 | rhs_ns | exal | 9 | 4 | 5 | 0 | 0.444 | 0.556 | 0.000 | 1.000 | 5.006 | 5.842 | 6.353 | 45.050 | 5.006 | 5.842 | 6.353 | 838.793 | 9.369 | 2933.642 | 838.793 | 9.369 | 2933.642 | -834.867 | -8.927 | 6.850 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 7 | 2 | 0.000 | 0.778 | 0.222 | 0.778 | NA | NA | NA | NA | 0.444 | -0.222 | -0.222 | 0.222 | NA | NA | NA | NA |
| vb | exal | 5000 | ridge | exal | 9 | 9 | 0 | 0 | 1.000 | 0.000 | 0.000 | 1.000 | 4.182 | 5.177 | 5.484 | 37.638 | 4.182 | 5.177 | 5.484 | 822.839 | 19.853 | 2866.985 | 822.839 | 19.853 | 2866.985 | -816.788 | -16.829 | 9.871 | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | NA | exdqlm | 9 | 0 | 7 | 2 | 0.000 | 0.778 | 0.222 | 0.778 | NA | NA | NA | NA | 1.000 | -0.778 | -0.222 | 0.222 | NA | NA | NA | NA |

## Prior Head-To-Head Winner Counts
| preferred_prior | Freq |
|---|---|
| rhs_ns | 55 |
| ridge | 17 |

## Remaining Documented FAIL Rows
| root_id | family | tau | fit_size | prior | inference | model | signoff_reason |
|---|---|---|---|---|---|---|---|
| root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns | normal | 0.05 | 5000 | rhs_ns | mcmc | exal | geweke_drift; half_chain_drift |
| root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns | normal | 0.95 | 500 | rhs_ns | mcmc | exal | geweke_drift |

## Important Interpretation Notes
- Signoff/readiness deltas are directly comparable against the exdqlm reference on the mirrored dynamic surface once the model labels are normalized (`al <-> dqlm`, `exal <-> exdqlm`).
- Runtime is summarized in detail for QDESN. Reference-runtime deltas are only meaningful where the reference inventory has non-missing runtime values; some mirrored reference summaries leave runtime blank.
- Forecast fit-performance metrics (`train_*`, `holdout_*`) are summarized for the QDESN side only.
- The reference-side summary inventory on this surface does not expose matching forecast metric columns, so direct forecast-metric deltas vs exdqlm are not reported here.

- comparison_root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d/comparison_vs_reference`
