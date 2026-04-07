# QDESN Dynamic Main Comparison Analysis Preflight

- generated_at: `2026-04-07 16:22:50.646894`
- run_tag: `qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d`
- prepare_only: `FALSE`
- manifest: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis_manifest.yaml`
- defaults: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_defaults.yaml`
- grid: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_grid.csv`

## Source
- source_run_tag: `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`
- source_mode: `prior_fitfail_wave`
- source_label: `Merged Local Baseline After Prior Targeted Wave`
- source_report_root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`

## Reference Surface
- reference_root_dirs: `18`
- reference_fit_rows: `72`
- reference_pair_rows: `36`
- reference_root_rows: `18`

## Grid
- qdesn_root_rows: `36`
- qdesn_root_unique: `36`
- qdesn_fit_rows_expected: `144`

## Authoritative Source State Checks
| metric | expected | actual | matches |
| --- | --- | --- | --- |
| fit_rows | 144 | 144 | TRUE |
| fit_pass_rows | 77 | 77 | TRUE |
| fit_warn_rows | 65 | 65 | TRUE |
| fit_fail_rows | 2 | 2 | TRUE |
| root_rows | 36 | 36 | TRUE |
| root_status_fail_rows | 0 | 0 | TRUE |
| root_compare_any_rows | 36 | 36 | TRUE |
| root_compare_full_rows | 34 | 34 | TRUE |
| local_baseline_rows | 5 | 5 | TRUE |

## Grid Summary
| metric | value |
| --- | --- |
| enabled_roots | 36 |
| unique_dataset_cells | 18 |
| scenarios | dlm_constV_smallW |
| families | gausmix, laplace, normal |
| taus | 0.05, 0.25, 0.95 |
| fit_sizes | 500, 5000 |
| root_kinds | dynamic |
| priors | rhs_ns, ridge |

## Local Baseline Map
| stage_id | local_baseline_profile | recommendation |
| --- | --- | --- |
| R1_gausmix_tt5000_residual | L640_gmix_long_split_diag | USE_L640_gmix_long_split_diag_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R1_gausmix_tt5000_residual |
| R2_gausmix_tt500_residual | L670_gmix_short_diag_mix | USE_L670_gmix_short_diag_mix_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R2_gausmix_tt500_residual |
| R3_ridge_tt5000_singleton_residual | L720_ridge_long_softgamma_plus | USE_L720_ridge_long_softgamma_plus_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R3_ridge_tt5000_singleton_residual |
| R4_rhs_tt5000_residual | L760_rhs_long_vbguard_deep | USE_L760_rhs_long_vbguard_deep_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R4_rhs_tt5000_residual |
| R5_short_horizon_mixed_residual | L770_short_mixed_local_mcmc | USE_L770_short_mixed_local_mcmc_AS_EFFECTIVE_SOURCE_BASELINE_FOR_R5_short_horizon_mixed_residual |

- output_root: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_main_comparison_analysis/qdesn-dynamic-exdqlm-crossstudy-maincmp-20260407-162250__git-b46643d`
