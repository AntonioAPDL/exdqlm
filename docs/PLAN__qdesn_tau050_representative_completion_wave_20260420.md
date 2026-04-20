# QDESN Tau050 Representative Completion Wave

Date: 2026-04-20

## Purpose

This plan finishes the interrupted representative-triad promotion wave after the
triad showed a real scientific signal but stopped in the campaign collector
layer rather than in the sampler.

Current evidence:

- all `4 / 4` started triad roots reached root-level `SUCCESS`
- `0 / 4` started triad roots reproduced the numerical latent-`v` crash
- the interrupted triad wave stopped because root-table aggregation attempted to
  parse empty placeholder CSV payloads such as `""`
- the missing scientific comparison is now only the EXAL ridge root under:
  - `tau only`
  - `theta + tau`

## Decision

The next wave should be a minimal two-lane continuation, not a broad rerun.

Run only:

1. `representative_completion_exal_tau_only`
2. `representative_completion_exal_theta_tau`

Both lanes target the same single root:

- `EXAL / laplace / tau 0.50 / fit_size 5000 / ridge`

This keeps the continuation:

- isolated
- reproducible
- cheap
- directly comparable to the already-completed EXAL `rhs_ns` and AL `rhs_ns`
  triad roots

## Why This Is The Best Next Step

This is the highest-signal next move because:

- the sampler signal is already positive on all started triad roots
- the only unresolved promotion question is whether `theta + tau` still beats
  or matches `tau only` on the harder EXAL ridge comparator
- rerunning the full triad would waste compute on roots that already finished
  successfully
- promoting immediately to the broader failed cohort would skip the last missing
  representative EXAL comparison

## Required Code Surface

### Collector robustness

- [R/qdesn_static_exdqlm_crossstudy.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_static_exdqlm_crossstudy.R)
  - skip zero-byte and placeholder table payloads in
    `.qdesn_static_crossstudy_collect_root_tables()`
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)
  - write true empty files for zero-column data frames so future collector reads
    stay stable

### Completion-wave materialization

- [scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R)
  - generate:
    - `qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_ridge_grid.csv`
    - `qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_tau_only_defaults.yaml`
    - `qdesn_dynamic_exdqlm_crossstudy_tau050_representative_completion_exal_theta_tau_defaults.yaml`

### Wrapper phases

- [scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
  - add:
    - `representative_completion_exal_tau_only`
    - `representative_completion_exal_theta_tau`
- [scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
  - add matching healthcheck phases

### Regression coverage

- [tests/testthat/test-qdesn-static-crossstudy-collector.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-static-crossstudy-collector.R)
  - verify placeholder and zero-byte tables are ignored
- [tests/testthat/test-qdesn-dynamic-tau050-single-root-probe-config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat/test-qdesn-dynamic-tau050-single-root-probe-config.R)
  - verify completion-wave defaults and grid generation

## Launch Strategy

Use two parallel lanes with one worker each.

That is the efficient choice because each lane has only one selected root, so
increasing per-lane workers would not create more useful parallelism. Launching
both lanes together still uses multiple cores while keeping the campaign simple.

## Promotion Gate

If `theta + tau` completes the missing EXAL ridge root successfully and remains
at least as clean as `tau only`, then `theta + tau` becomes the preferred
promotion candidate for the broader remaining failed cohort.
