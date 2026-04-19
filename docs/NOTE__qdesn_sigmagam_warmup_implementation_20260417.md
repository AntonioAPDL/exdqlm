# QDESN Sigmagam Warmup Implementation Note

Date: `2026-04-17`

## Purpose

This note records the implemented `sigmagam` warmup feature on the qdesn
integration branch and clarifies how it should be interpreted relative to the
interrupted refreshed288 pilot run.

## What Is Implemented

The qdesn branch now has an explicit, repo-native control surface for the joint
likelihood-side `gamma/sigma` block:

| surface | controls |
|---|---|
| direct VB | `inference.vb.sigmagam.*` |
| MCMC VB warm start | `inference.mcmc.vb_warm_start_control.sigmagam.*` |
| direct MCMC | `inference.mcmc.sigmagam.*` |

Resolved defaults remain feature-off at the package level:

| context | package-level resolved default |
|---|---|
| VB | `freeze_warmup_iters = 0` |
| MCMC | `freeze_burnin_iters = 0` |

Study defaults are explicit in the refreshed tau-0.50 qdesn YAML:

| context | study default |
|---|---|
| VB | `freeze_warmup_iters = 10`, `force_after_warmup = TRUE`, `postwarmup_damping = 0.5`, `postwarmup_damping_iters = 3`, `min_postwarmup_updates = 1` |
| MCMC VB warm start | same as direct VB unless explicitly overridden |
| MCMC | `freeze_burnin_iters = 50`, `freeze_only_during_burn = TRUE`, `force_after_warmup = TRUE`, `delay_adapt_until_after_warmup = TRUE`, `delay_laplace_refresh_until_after_warmup = TRUE` |

## Package-Side Behavior

Implemented behavior by engine:

| engine | implemented behavior |
|---|---|
| `R/exal_ldvb_engine.R` | freezes the `sigmagam` LD refresh for early iterations, forces the first post-warmup update, supports post-warmup damping, and blocks convergence until the required number of post-warmup updates occurred |
| `R/exal_mcmc_fit.R` | freezes the `sigmagam` update block during early burn iterations, forces the first post-warmup update, and records full-chain traces and summaries |
| `R/exal_inference_config.R` | resolves and normalizes the new VB, MCMC warm-start, and MCMC core controls |
| `R/qdesn_mcmc_validation.R` | exports warmup-aware health fields, extends VB progress traces, and writes `sigmagam_trace.csv` for both VB and MCMC methods |

Important caveat:

- in qdesn MCMC, latent `v` is still sampled before the `sigmagam` block, so
  MCMC-side `sigmagam` warmup is secondary stabilization rather than the first
  rescue lever;
- VB-side `sigmagam` warmup remains the higher-leverage initialization change.

## Export Surfaces

Implemented validation export behavior:

| file | behavior |
|---|---|
| `progress_trace.csv` for VB | now carries `sigmagam_frozen`, `sigmagam_update_reason`, `sigmagam_update_count`, `sigmagam_forced_postwarmup` when available |
| `health_summary.csv` | now carries compact `sigmagam` warmup summary fields for both VB and MCMC |
| `sigmagam_trace.csv` | new method-level export for detailed VB iteration traces and full-chain MCMC burn/keep traces |

## Focused Verification

Focused qdesn tests passed for the implemented feature surfaces:

| file group | coverage |
|---|---|
| `test-exal-inference-config.R` | config normalization and inheritance |
| `test-exal-mcmc.R` | VB and MCMC warmup traces and summaries |
| `test-qdesn-dynamic-tau050-refreshed-main-config.R` | refreshed-main YAML defaults |
| `test-qdesn-sigmagam-warmup-validation-export.R` | validation health, progress, and `sigmagam_trace` export behavior |

## Relationship To Refreshed288

This implementation does **not** retroactively change the interrupted
refreshed288 pilot under:

- `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/full288_refreshed288_paperaligned_20260416`

Interpretation:

| artifact | interpretation |
|---|---|
| interrupted refreshed288 pilot | implicit-default run without explicit `sigmagam` warmup |
| next canonical refreshed288 rerun | should only launch after the intended warmup-enabled package surface is available and verified |

## Summary

The qdesn branch now has the required `sigmagam` warmup control surface,
engine behavior, diagnostics, and exports to support a cleaner future canonical
relaunch. The interrupted refreshed288 pilot should still be preserved as a
separate historical artifact rather than retrofitted in place.
