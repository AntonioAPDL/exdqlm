# QDESN Tau050 Representative Completion Wave Implementation

Date: 2026-04-20

## Summary

This report records the implementation needed to safely continue the
representative-triad promotion after the original triad wave was interrupted by
campaign-level table collection, not by model-level numerical failure.

The implementation has two goals:

1. harden the collector against empty placeholder CSV payloads
2. create a narrow EXAL ridge completion wave so we can finish the missing
   comparison without rerunning already-successful roots

Reference context:

- [single-root probe launch](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_single_root_probe_program_launch_20260419.md)
- [representative triad launch](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_representative_triad_launch_20260419.md)
- [completion-wave plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_representative_completion_wave_20260420.md)

## Implemented Surface

### Collector and table-writing robustness

- [R/qdesn_static_exdqlm_crossstudy.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_static_exdqlm_crossstudy.R)
  - added safe table reads for zero-byte and placeholder `""` CSV files
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)
  - changed zero-column table writes to create a true empty file instead of a
    placeholder CSV row

### Completion-wave assets

- [completion EXAL ridge grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_ridge_grid.csv)
- [completion tau-only defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_tau_only_defaults.yaml)
- [completion theta-plus-tau defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_theta_tau_defaults.yaml)

### Wrapper integration

- [materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R)
- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

## Verification

Focused tests:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-static-crossstudy-collector|qdesn-dynamic-tau050-single-root-probe-config|qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config|exal-inference-config|exal-mcmc|qdesn-dynamic-failure-repair|qdesn-sigmagam-warmup-validation-export", reporter = "summary")'
```

Materializer regeneration:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R
```

The next step after this implementation layer is clean-SHA `prepare-only`, then
the live two-lane completion launch.
