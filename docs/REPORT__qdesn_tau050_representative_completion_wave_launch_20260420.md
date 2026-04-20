# QDESN Tau050 Representative Completion Wave Launch

Date: 2026-04-20

## Summary

This report records the live launch of the minimal EXAL ridge completion wave
after:

1. the representative triad showed no renewed numerical crashes on any started
   root
2. the triad was interrupted by a campaign collector bug rather than model
   failure
3. the collector and empty-table write paths were patched and regression tested

Reference context:

- [completion-wave plan](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/PLAN__qdesn_tau050_representative_completion_wave_20260420.md)
- [completion-wave implementation report](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_representative_completion_wave_implementation_20260420.md)
- [representative triad launch](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_tau050_representative_triad_launch_20260419.md)

## Clean Launch SHA

The completion wave launched from:

- `ef66349` — `Fix triad collector and add completion wave`

## Prepare-only Validation

Both lanes passed clean-SHA `prepare-only`.

Prepare-only run tags:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_completion_exal_tau_only-20260420-013328__git-ef66349`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_completion_exal_theta_tau-20260420-013328__git-ef66349`

## Live Launch Commands

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_completion_exal_tau_only
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R --phase representative_completion_exal_theta_tau
```

## Live Run Metadata

| Phase | Spec | Surface | Run tag | tmux |
|---|---|---|---|---|
| `representative_completion_exal_tau_only` | `tau only` | `EXAL / laplace / tau 0.50 / 5000 / ridge` | `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_completion_exal_tau_only-20260420-013345__git-ef66349` | `qdesn_dynx_0420_013345` |
| `representative_completion_exal_theta_tau` | `theta + tau` | `EXAL / laplace / tau 0.50 / 5000 / ridge` | `qdesn-dynamic-exdqlm-crossstudy-tau050-representative_completion_exal_theta_tau-20260420-013345__git-ef66349` | `qdesn_dynx_0420_013346` |

## Resource Use

The continuation uses two cores efficiently by running two independent
single-root lanes in parallel, each with one worker:

- `representative_completion_exal_tau_only`: `1` worker
- `representative_completion_exal_theta_tau`: `1` worker

This is the efficient configuration because each lane has exactly one selected
root, so increasing per-lane workers would not create additional useful
parallelism.

## Initial Health Snapshot

Snapshot time: `2026-04-20 01:33:54 EDT`

| Phase | Selected roots | Materialized | Running | Success | Fail |
|---|---:|---:|---:|---:|---:|
| `representative_completion_exal_tau_only` | 1 | 1 | 1 | 0 | 0 |
| `representative_completion_exal_theta_tau` | 1 | 1 | 1 | 0 | 0 |

High-level startup read:

- both tmux sessions are live
- both lanes materialized cleanly
- no early failures are present
- the missing EXAL ridge comparison is now actively running under both specs

## Immediate Next Step

Let both lanes reach terminal state and compare:

1. crash survival
2. signoff quality
3. runtime
4. holdout quality

If `theta + tau` remains at least as stable as `tau only` and stays cleaner on
runtime and diagnostics, it should become the preferred promotion candidate for
the broader remaining failed cohort.
