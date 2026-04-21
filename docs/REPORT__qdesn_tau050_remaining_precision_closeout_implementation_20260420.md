# QDESN Tau050 Remaining Precision Closeout Implementation

Date: `2026-04-20`

## Summary

This implementation packages the final precision-root recovery into a canonical closeout wave:

- promote `ladder_v2` as the single live rescue policy
- keep `eigen_v1` prepared as the explicit fallback
- isolate the final rerun to the exact unresolved AL/EXAL ridge pair

The closeout package is intentionally smaller and more opinionated than the earlier 6-arm code matrix. It exists to turn the winning experiment result into a clean, reproducible promoted rerun.

## Evidence Used For Promotion

The source-of-truth comparison remains the pair-only precision code matrix.

Observed outcomes:

| Phase | Lane | Result |
|---|---|---|
| `remaining_precision_code_al_ladder_v2` | `AL` | `SUCCESS` |
| `remaining_precision_code_al_eigen_v1` | `AL` | `SUCCESS` |
| `remaining_precision_code_exal_ladder_v2` | `EXAL` | `SUCCESS` |
| `remaining_precision_code_exal_eigen_v1` | `EXAL` | `SUCCESS` |
| `remaining_precision_code_al_ladder_v1` | `AL` | `FAIL` |
| `remaining_precision_code_exal_ladder_v1` | `EXAL` | `FAIL` |

Promotion logic:

- `ladder_v1` is ruled out
- `ladder_v2` and `eigen_v1` both work
- `ladder_v2` is promoted because it succeeds without escalating to the stronger eigenvalue-floor fallback
- `eigen_v1` is kept as the prepared escalation path

## Implemented Assets

### Materializer

Added:

- [remaining precision closeout materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout.R)

It generates:

- closeout phase inventory map
- dedicated closeout AL/EXAL grids
- canonical live defaults using `precision_beta = ladder_v2`
- prepared fallback defaults using `precision_beta = eigen_v1`

### Generated config assets

Generated:

- [closeout map](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_map.csv)
- [AL closeout grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_grid.csv)
- [EXAL closeout grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_grid.csv)
- [AL ladder_v2 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_ladder_v2_defaults.yaml)
- [EXAL ladder_v2 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_ladder_v2_defaults.yaml)
- [AL eigen_v1 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_al_eigen_v1_defaults.yaml)
- [EXAL eigen_v1 defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout_exal_eigen_v1_defaults.yaml)

### Launcher wiring

Updated:

- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

New phases:

- `remaining_precision_closeout_al_ladder_v2`
- `remaining_precision_closeout_exal_ladder_v2`
- `remaining_precision_closeout_al_eigen_v1`
- `remaining_precision_closeout_exal_eigen_v1`

The wrappers now support:

- defaults lookup
- grid lookup
- likelihood-family routing
- worker selection
- subset handling
- healthcheck routing
- materializer auto-generation

### Tests

Added:

- [closeout config test](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-remaining-precision-closeout-config.R)

The new test verifies:

- the closeout materializer writes exactly four rows
- the live/fallback role split is correct
- the promoted presets are correct
- resolved configs expose `ladder_v2` and `eigen_v1` exactly as intended

## Validation

Passed during implementation:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_precision_closeout.R
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-remaining-precision-closeout-config|qdesn-fit-mcmc-precision-beta-api|exal-precision-beta-rescue|qdesn-precision-beta-validation-export|exal-inference-config|exal-mcmc", reporter = "summary")'
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_al_ladder_v2 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_exal_ladder_v2 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_al_eigen_v1 --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase remaining_precision_closeout_exal_eigen_v1 --prepare-only
```

Observed validation result:

- materializer completed cleanly
- focused tests passed
- all four closeout phases prepared successfully

## Practical Interpretation

This change moves the project from:

- “we have evidence that some code-level rescue arms work”

to:

- “we now have a canonical, promoted final rerun package using the chosen default policy and a prepared fallback”

That is the right form for final closeout because it keeps the scientific story simple:

1. matrix search found a winner set
2. `ladder_v2` became the promoted default
3. the final rerun is now a tiny canonical closeout instead of another exploratory matrix
