# QDESN Tau050 Recovered Main Comparison Implementation

Date: `2026-04-21`  
Status: implementation package for the recovered 144-fit tau050 main-comparison rerun

## Purpose

The failed-run recovery is now complete (`23 / 23` original hard MCMC crashes recovered), so the
next correct step is to go back to the authoritative `144`-fit tau050 validation study and rebuild
the main comparison pack from the recovered source surface instead of the original crash-
contaminated source run.

This implementation package makes that rerun reproducible and phase-addressable.

## What Was Added

### 1. Recovered-source override support

The dynamic source-state merge path now supports explicit per-fit override files through:

- `fit_summary_path`
- `root_summary_path`

This matters because the recovered tau050 source surface is not stored in a single prior-wave pack.
It is spread across:

- the `sfreeze` wave,
- the run-specific remaining-hard-fail relaunch,
- the canonical precision closeout rerun.

The source-state overlay logic can now pull repaired fit rows directly from those root-local
summary files.

Primary file:

- [R/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R)

### 2. Merged root-summary recomputation

After fit-level overrides are layered in, the dynamic source-state collector now recomputes the
merged root-level summary from the final overlaid fit surface.

That avoids a subtle inconsistency where multiple successful fit-level repairs for the same root
could be merged into `fit_summary` while `root_summary` still reflected only one intermediate wave.

This is the key enabling fix for a clean recovered 144-fit comparison source.

### 3. Main-comparison override-map support

The generic dynamic main-comparison runner now accepts a manifest field:

- `source.root_profile_overrides_csv`

That CSV is resolved into the same override-list structure used by the source-state collector.

Primary files:

- [R/qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R)
- [scripts/run_qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R)

### 4. Manifest-level reference-contract override

The generic comparison runner now also supports:

- `reference_contract_override`

This was needed because the mirrored dynamic reference inventory remains keyed on:

- `0.05`
- `0.25`
- `0.95`

while the recovered tau050 QDESN source surface includes:

- `0.05`
- `0.25`
- `0.50`

The grid/source contract and the reference validation contract can now be kept separate without
forking the whole defaults file.

### 5. Tau050-specific recovered comparison package

Added:

- [override materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_overrides.R)
- [wrapper runner](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/run_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis.R)
- [manifest](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis_manifest.yaml)
- [override map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_root_override_map.csv)
- [focused regression test](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-recovered-main-comparison-config.R)

## Recovery Surface Used

The override map reconstructs the recovered source state by selecting successful repaired fit rows
from these completed waves:

- `failed_mcmc_al_sfreeze`
- `failed_mcmc_exal_sfreeze`
- `remaining_hard_fail_latent_v_al`
- `remaining_hard_fail_latent_v_exal`
- `remaining_hard_fail_exal_ridge_precision_v1`
- `remaining_precision_closeout_al_ladder_v2`
- `remaining_precision_closeout_exal_ladder_v2`

The materialized override map currently covers:

- `23 / 23` original source `status == FAIL` fit rows

## Verification

Focused validation passed:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-recovered-main-comparison-config", reporter = "summary")'
```

The integration-style test confirms that the reconstructed tau050 recovered source state has:

- `144` fit rows
- `0` fit rows with `status == FAIL`
- `0` root rows with `root_status == FAIL`
- `23` explicit override rows in the source merge inventory

## Read

This implementation package does not change the scientific outcome by itself. Its job is to make
the recovered 144-fit tau050 comparison pack reproducible, auditable, and compatible with the
existing dynamic main-comparison workflow.
