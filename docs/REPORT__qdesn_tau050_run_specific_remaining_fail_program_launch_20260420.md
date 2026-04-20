# QDESN Tau050 Run-Specific Remaining-Fail Program Launch

Date: 2026-04-20

## Summary

This report records the live launch of the run-specific remaining-fail relaunch
program from clean implementation SHA `dbafa6a`.

Reference notes:

- [run-specific program plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_run_specific_remaining_fail_program_20260420.md)
- [implementation report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_run_specific_remaining_fail_program_implementation_20260420.md)

## Clean-SHA Prepare-Only Validation

The following phases passed `prepare-only` from `dbafa6a`:

| Phase | Run tag |
|---|---|
| `remaining_hard_fail_latent_v_al` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_al-20260420-030519__git-dbafa6a` |
| `remaining_hard_fail_latent_v_exal` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_exal-20260420-030530__git-dbafa6a` |
| `remaining_hard_fail_exal_ridge_precision_v1` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_exal_ridge_precision_v1-20260420-030545__git-dbafa6a` |
| `remaining_hard_fail_exal_ridge_precision_v2` | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_exal_ridge_precision_v2-20260420-030557__git-dbafa6a` |

## Live Launches

Launched live:

1. `remaining_hard_fail_latent_v_al`
2. `remaining_hard_fail_latent_v_exal`
3. `remaining_hard_fail_exal_ridge_precision_v1`

Prepared but not launched:

4. `remaining_hard_fail_exal_ridge_precision_v2`

## Live Run Metadata

| Phase | Spec family | Selected roots | Workers | Run tag | tmux |
|---|---|---:|---:|---|---|
| `remaining_hard_fail_latent_v_al` | `tau_theta_rescue_v1` | 7 | 3 | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_al-20260420-030610__git-dbafa6a` | `qdesn_dynx_0420_030611` |
| `remaining_hard_fail_latent_v_exal` | `tau_theta_rescue_v1` | 5 | 2 | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_latent_v_exal-20260420-030619__git-dbafa6a` | `qdesn_dynx_0420_030619` |
| `remaining_hard_fail_exal_ridge_precision_v1` | `tau_theta_precision_exal_v1` | 3 | 2 | `qdesn-dynamic-exdqlm-crossstudy-tau050-remaining_hard_fail_exal_ridge_precision_v1-20260420-030633__git-dbafa6a` | `qdesn_dynx_0420_030634` |

## Resource Use

The relaunch uses `7` workers total across `3` concurrent tmux lanes:

- AL latent-`v` cluster: `3`
- EXAL latent-`v` cluster: `2`
- EXAL ridge precision cluster: `2`

This is the chosen balance between:

- keeping the wave meaningfully parallel
- separating the two numerical mechanisms
- avoiding another overly broad single-campaign launch

## Initial Health Snapshot

Snapshot time: `2026-04-20 03:06:52 EDT`

| Phase | Selected | Materialized | Running | Success | Fail | Started % |
|---|---:|---:|---:|---:|---:|---:|
| `remaining_hard_fail_latent_v_al` | 7 | 3 | 3 | 0 | 0 | 42.9% |
| `remaining_hard_fail_latent_v_exal` | 5 | 2 | 2 | 0 | 0 | 40.0% |
| `remaining_hard_fail_exal_ridge_precision_v1` | 3 | 2 | 2 | 0 | 0 | 66.7% |
| Overall | 15 | 7 | 7 | 0 | 0 | 46.7% |

High-level startup read:

- all three tmux sessions are live
- all three phases have begun materializing roots
- there are no early failures yet
- the latent-`v` and EXAL ridge mechanisms are now being tested under separate,
  run-specific specs

## Immediate Next Step

Monitor the three live lanes and compare:

1. hard-crash survival
2. failure family by cluster
3. signoff quality among completed runs
4. whether the EXAL ridge pocket stays on `v1` or requires promotion to `v2`
