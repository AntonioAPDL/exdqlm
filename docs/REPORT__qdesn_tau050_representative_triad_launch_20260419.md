# QDESN Tau050 Representative Triad Launch

Date: 2026-04-19

## Summary

This report records the representative-triad promotion wave launched after the
single-root probe showed that the primary hard crash root was recoverable under
all three structural arms, with `theta + tau` emerging as the preferred next
candidate.

Reference context:

- [single-root implementation report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_single_root_probe_program_implementation_20260419.md)
- [single-root launch report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_single_root_probe_program_launch_20260419.md)
- [crash-recovery program plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_crash_recovery_program_20260419.md)

The triad compares two specs:

1. `tau only`
2. `theta + tau`

across the representative three-root surface:

1. `EXAL / laplace / tau 0.50 / 5000 / rhs_ns`
2. `EXAL / laplace / tau 0.50 / 5000 / ridge`
3. `AL / laplace / tau 0.50 / 5000 / rhs_ns`

## Implementation Surface

The triad promotion was implemented and pinned at commit:

- `df6d202` — `Implement tau050 representative triad promotion`

Key files:

- [triad tau-only defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_tau_only_defaults.yaml)
- [triad theta-plus-tau defaults](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_representative_triad_theta_tau_defaults.yaml)
- [triad EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_triad_exal_grid.csv)
- [triad AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_triad_al_grid.csv)
- [materializer](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_grids.R)
- [launch wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)
- [healthcheck wrapper](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R)

## Validation Before Launch

Focused tests passed before the live launch:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-single-root-probe-config|qdesn-dynamic-tau050-failed-mcmc-thetafreeze-config|exal-inference-config|exal-mcmc|qdesn-dynamic-failure-repair|qdesn-sigmagam-warmup-validation-export", reporter = "summary")'
```

Clean-SHA `prepare-only` validation passed for all four triad phases on
`df6d202`:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_exal_tau_only --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_exal_theta_tau --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_al_tau_only --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_al_theta_tau --prepare-only
```

Prepare-only run tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_exal_tau_only-20260419-204619__git-df6d202`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_exal_theta_tau-20260419-204619__git-df6d202`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_al_tau_only-20260419-204636__git-df6d202`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_al_theta_tau-20260419-204636__git-df6d202`

## Live Launch Commands

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_exal_tau_only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_exal_theta_tau
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_al_tau_only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_triad_al_theta_tau
```

## Live Run Metadata

| Phase | Spec | Surface | Run tag | tmux |
|---|---|---|---|---|
| `representative_triad_exal_tau_only` | `tau only` | `EXAL` triad pair | `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_exal_tau_only-20260419-204650__git-df6d202` | `qdesn_dynx_0419_204650` |
| `representative_triad_exal_theta_tau` | `theta + tau` | `EXAL` triad pair | `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_exal_theta_tau-20260419-204701__git-df6d202` | `qdesn_dynx_0419_204701` |
| `representative_triad_al_tau_only` | `tau only` | `AL` comparator | `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_al_tau_only-20260419-204710__git-df6d202` | `qdesn_dynx_0419_204711` |
| `representative_triad_al_theta_tau` | `theta + tau` | `AL` comparator | `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_triad_al_theta_tau-20260419-204717__git-df6d202` | `qdesn_dynx_0419_204718` |

## Initial Health Snapshot

Snapshot time: `2026-04-19 20:47 EDT`

| Phase | Selected roots | Materialized | Running | Success | Fail |
|---|---:|---:|---:|---:|---:|
| `representative_triad_exal_tau_only` | 2 | 1 | 1 | 0 | 0 |
| `representative_triad_exal_theta_tau` | 2 | 1 | 1 | 0 | 0 |
| `representative_triad_al_tau_only` | 1 | 1 | 1 | 0 | 0 |
| `representative_triad_al_theta_tau` | 1 | 1 | 1 | 0 | 0 |

High-level startup read:

- all four tmux sessions are live
- all four phases started cleanly
- no early failures are present
- both EXAL phases are halfway through materialization because each has two
  selected roots
- both AL phases have fully materialized their one selected root and are
  running

## Immediate Next Step

Let the four triad phases run to terminal state and compare:

1. crash survival
2. signoff quality
3. runtime
4. residual mixing diagnostics

If `theta + tau` stays at least as stable as `tau only` while remaining cleaner
on signoff and runtime, it should become the leading candidate for promotion to
the broader remaining-failed cohort.
