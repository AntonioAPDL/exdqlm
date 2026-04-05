# Comparison-Ready Assembly Execution

Date: 2026-04-05

The comparison-ready assembly pipeline was implemented and executed from the
frozen promoted campaign map. The resulting merged campaign table contains
exactly `291` selected cases.

## Audit Summary

- total selected rows: `291`
- unique case keys: `291`
- selected `FAIL` rows: `0`
- selected `WARN` rows: `83`

## Pool Counts

| pool | expected | observed |
|---|---:|---:|
| `historical_reusable_static` | 216 | 216 |
| `static_refresh_nonfail` |  42 |  42 |
| `static_residual_broad_default` |  21 |  21 |
| `static_local_override` |   9 |   9 |
| `dynamic_historical_reusable` |   2 |   2 |
| `dynamic_local_override` |   1 |   1 |

## Acceptance Checks

| check | pass | detail |
|---|---|---|
| `total_rows_291` | `yes` | rows=291 |
| `unique_case_keys_291` | `yes` | unique_case_keys=291 |
| `selected_pool_counts_match` | `yes` | historical_reusable_static:216; static_refresh_nonfail:42; static_residual_broad_default:21; static_local_override:9; dynamic_historical_reusable:2; dynamic_local_override:1 |
| `selected_fit_paths_exist` | `yes` | all fit paths present |
| `selected_health_paths_exist` | `yes` | all health paths present |
| `provenance_sources_exist` | `yes` | all provenance sources present |
| `zero_selected_fail` | `yes` | fail_rows=0 |
| `all_selected_healthy_true` | `yes` | healthy_false_rows=0 |

## Selected WARN Rows

| case_key | pool | candidate | variant |
|---|---|---|---|
| `dynamic_tail_cppgig_refresh_20260331::15` | `dynamic_local_override` | `row15_slice_exact_20260405` | `row15_slice_exact_20260405` |
| `static_validation::current_rhsns_refresh::83` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::84` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::87` | `static_local_override` | `F085_sub2_s1025_histshort` | `row87fix11_R87_F085_sub2_s1025_histshort_seed2026079087` |
| `static_validation::current_rhsns_refresh::88` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::91` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::95` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::108` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::111` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::112` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::119` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::127` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::131` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::132` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::136` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::139` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::143` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::149` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::157` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::158` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::165` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::166` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::167` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::168` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::173` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::174` | `static_local_override` | `F085_sub2_s105_histshort` | `rowfix9_R174_F085_sub2_s105_histshort_seed2026040474` |
| `static_validation::current_rhsns_refresh::175` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::176` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::181` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::189` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::190` | `static_local_override` | `F0825_sub2_s100_rwlong` | `repairmap7_R190_F0825_sub2_s100_rwlong` |
| `static_validation::current_rhsns_refresh::198` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::215` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::216` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::221` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::222` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::223` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::224` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::237` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::238` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::245` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::246` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::253` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::254` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::261` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::current_rhsns_refresh::262` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::263` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::264` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::269` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::270` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::271` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::272` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::current_rhsns_refresh::277` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhsns_current_20260403` |
| `static_validation::current_rhsns_refresh::286` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::legacy_rhs_refresh::147` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::155` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::157` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::legacy_rhs_refresh::163` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::165` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::legacy_rhs_refresh::167` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::171` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::173` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::legacy_rhs_refresh::175` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::179` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::195` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::197` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhs_legacy_20260403` |
| `static_validation::legacy_rhs_refresh::203` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::205` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::legacy_rhs_refresh::211` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::215` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::219` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::221` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhs_legacy_20260403` |
| `static_validation::legacy_rhs_refresh::223` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::237` | `static_residual_broad_default` | `F085_sub2_s100` | `failband2_F085_sub2_s100` |
| `static_validation::legacy_rhs_refresh::243` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::245` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhs_legacy_20260403` |
| `static_validation::legacy_rhs_refresh::253` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhs_legacy_20260403` |
| `static_validation::legacy_rhs_refresh::263` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::269` | `static_local_override` | `F0845_sub2_s100_histshort` | `repairmap9_R269_F0845_sub2_s100_histshort_seed2026076269` |
| `static_validation::legacy_rhs_refresh::271` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::275` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::283` | `historical_reusable_static` | `historical_base_fit` | `historical_base_fit` |
| `static_validation::legacy_rhs_refresh::285` | `static_refresh_nonfail` | `F080_sub2_s105` | `static_exal_f080_sub2_s105_rhs_legacy_20260403` |
