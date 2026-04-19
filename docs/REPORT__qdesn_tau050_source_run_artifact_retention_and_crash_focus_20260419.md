# QDESN Tau050 Source Run Artifact Retention And Crash Focus

Date: 2026-04-19

## Scope

This note records the current post-cleanup state of the canonical 144-fit `tau050` source campaign:

- [source run root](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674)

The purpose is to make the retained artifact surface explicit before the next relaunch planning step.

## Source-Run Terminal Status

| Bucket | Count | Percent |
|---|---:|---:|
| Total fits | 144 | 100.0% |
| `SUCCESS` | 121 | 84.0% |
| `FAIL` | 23 | 16.0% |
| `PASS` signoff | 71 | 49.3% |
| `WARN` signoff | 24 | 16.7% |
| `FAIL` signoff | 49 | 34.0% |

Interpretation:

- `PASS + WARN = 95` is the currently acceptable / usable surface.
- `23` fits are the hard terminal failures.
- the remaining `26` fits with `SUCCESS` + signoff `FAIL` are completed-but-poor-diagnostics, not hard crashes.

## Retained `.rds` State After Cleanup

The cleanup removed large `forecast_objects.rds` files, but it did **not** wipe all `.rds` from the source run.

For the `95` acceptable `PASS` or `WARN` fits:

| Check | Count |
|---|---:|
| `PASS/WARN` fits | 95 |
| still have at least one `.rds` | 95 |
| still have `timing_summary.rds` | 95 |
| still have `rhs_trace.rds` | 67 |
| still have `forecast_objects.rds` | 0 |

This means the acceptable fit surface still preserves lightweight `.rds` sidecars needed for timing and RHS tracing, while the large forecast-object binaries are gone.

## Current Crash Focus

The repair focus remains the hard numerical-failure surface:

| Check | Count |
|---|---:|
| hard failed fits | 23 |
| failed VB fits | 0 |
| failed MCMC fits | 23 |

All hard failures remain MCMC-side numerical crashes in the same family already under investigation.

Representative source-run failure log:

- [mcmc_exal latent-v failure log](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674/roots/root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_500__qdesn_rhs_ns/fits/mcmc_exal/logs/pipeline_stdout.log)

Observed fatal signature:

- `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`

## Relaunch Surface

The exact preserved relaunch manifolds for the original 23 numerical crashes already exist in:

- [failed MCMC AL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv)
- [failed MCMC EXAL grid](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv)

These remain the right reproducible starting point for a fresh 23-fit crash-only relaunch once the latent `s` freeze design is finalized and implemented.

## Bottom Line

- The source run is still fully reconstructable at the summary/manifold level.
- The acceptable `PASS/WARN` fit surface still has retained `.rds` sidecars.
- The large `forecast_objects.rds` binaries were pruned.
- The relaunch target is still the same `23` hard numerical MCMC failures.
