# QDESN Tau050 Single-Root Probe Program Launch

Date: 2026-04-19

## Summary

This report records the live launch of the first-pass structural probe arms
from the single-root crash-recovery program:

- [crash-recovery program plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_crash_recovery_program_20260419.md)
- [implementation report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_single_root_probe_program_implementation_20260419.md)

The launch was performed from committed SHA `b306a22` after:

1. focused tests passed
2. the probe surfaces were materialized into `config/validation`
3. the structural arms passed clean `prepare-only` validation on the same SHA

Only the first three structural arms were launched:

1. `tau only`
2. `theta + tau`
3. `s + tau`

The rescue arm remains prepared but unlaunched.

## Exact Probe Root

All three live arms target the same primary probe root:

- likelihood family: `exal`
- source family: `laplace`
- `tau = 0.50`
- `fit_size = 5000`
- prior: `rhs_ns`
- root id:
  `root__dynamic__dlm_constV_smallW__laplace__tau_0p50__lasttt_5000__qdesn_rhs_ns`

Canonical grid:

- [primary EXAL rhs_ns probe grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_single_root_probe_primary_exal_rhsns_grid.csv)

## Clean-SHA Prepare-Only Validation

The exact launch surface was revalidated on SHA `b306a22` with:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_tau_only --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_theta_tau --prepare-only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_stau --prepare-only
```

Prepare-only run tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_tau_only-20260419-173947__git-b306a22`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_theta_tau-20260419-173959__git-b306a22`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_stau-20260419-174010__git-b306a22`

## Live Launch Commands

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_tau_only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_theta_tau
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase single_root_probe_exal_stau
```

## Live Run Metadata

| Arm | Run tag | tmux session |
|---|---|---|
| `tau only` | `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_tau_only-20260419-174028__git-b306a22` | `qdesn_dynx_0419_174028` |
| `theta + tau` | `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_theta_tau-20260419-174033__git-b306a22` | `qdesn_dynx_0419_174034` |
| `s + tau` | `qdesn-dynamic-exdqlm-crossstudy-tau050-single_root_probe_exal_stau-20260419-174044__git-b306a22` | `qdesn_dynx_0419_174044` |

## Initial Health Snapshot

Snapshot time: `2026-04-19 17:41 EDT`

| Arm | Materialized roots | Running | Success | Fail | Session live |
|---|---:|---:|---:|---:|---|
| `tau only` | `1 / 1` | `1` | `0` | `0` | yes |
| `theta + tau` | `1 / 1` | `1` | `0` | `0` | yes |
| `s + tau` | `1 / 1` | `1` | `0` | `0` | yes |

All three arms started cleanly:

- each arm selected exactly `1` root
- each arm materialized `100%` of its selected roots
- each arm was in `RUNNING` state at the first healthcheck
- no early failures were present at the initial snapshot

## Current Interpretation

This launch is intentionally small and information-dense.

At this point:

- the compute footprint is minimal
- the scientific attribution is clean
- the rescue arm is ready if the first three structural arms do not separate
  clearly

The next decision gate is outcome, not setup:

1. let the three live arms finish
2. compare survival and terminal behavior across:
   - `tau only`
   - `theta + tau`
   - `s + tau`
3. only then decide whether to:
   - promote a winner to the representative triad
   - or activate the prepared `theta + tau + rescue` arm
