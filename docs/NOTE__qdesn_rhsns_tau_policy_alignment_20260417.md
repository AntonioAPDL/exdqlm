# QDESN RHS-NS Tau Policy Alignment

Date: 2026-04-17

## Purpose

This note records the forward tau-freeze policy for the canonical QDESN refreshed-main validation lane and keeps it separate from the settings that were already baked into the live April 16, 2026 relaunch artifacts.

The active policy from this point forward is:

- Do not use raw `rhs` in the refreshed-main validation lane.
- Use `rhs_ns` whenever the shrinkage prior lane is active.
- Use `freeze_tau_iters = 50` and `freeze_tau_warmup_iters = 50` for VB and for the LDVB warm start that seeds MCMC.
- Use `min_iter_elbo = 80` for direct VB and for the LDVB warm start that seeds MCMC.
- Use `freeze_tau_burnin_iters = 500` for MCMC.

## Historical April 16 Live Run

The currently running refreshed-main relaunch was launched before this alignment was made explicit. The materialized run artifacts show:

- `min_iter_elbo = 20`
- VB `freeze_tau_iters = 10`
- VB `freeze_tau_warmup_iters = 10`
- `rhs_ns` MCMC `freeze_tau_burnin_iters = 400`
- ridge/base MCMC fallback `freeze_tau_burnin_iters = 250`

Example artifact evidence:

- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674/roots/root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_500__qdesn_rhs_ns/fits/mcmc_exal/fit_request.json`
- `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674/20260416-212707__git-15fe674/roots/root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_500__qdesn_rhs_ns/fits/vb_exal/fit_request.json`

This note does not rewrite those historical artifacts. It documents the stronger forward policy for subsequent runs and relaunches.

## Code Alignment Made On 2026-04-17

The forward policy is now wired in three places:

1. Refreshed-main defaults

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`
- Updated to `VB min_iter_elbo = 80`
- Updated to `VB freeze_tau_iters = 50`
- Updated to `VB freeze_tau_warmup_iters = 50`
- Updated to `MCMC freeze_tau_burnin_iters = 500`
- Updated the MCMC LDVB warm-start block to `min_iter_elbo = 80` and `freeze_tau_* = 50`

2. Active `rhs_ns` prior object

- `R/qdesn_rhs_ns_prior.R`
- Added explicit `freeze_tau_iters`, `freeze_tau_warmup_iters`, and `force_tau_after_warmup` controls
- Added warmup-state bookkeeping so the `rhs_ns` VB prior object can actually hold `tau` fixed during warmup and perform the first post-warmup update in a controlled way

3. VB config-to-prior wiring

- `R/priors_beta.R`
- `R/exal_inference_config.R`
- The active exAL/QDESN VB path previously carried tau-freeze settings in the generic `vb.rhs` block, but the `rhs_ns` prior object did not automatically receive them.
- The resolver now threads the relevant tau-freeze controls into the active `rhs_ns` prior object so the configured VB warmup is operational rather than merely present in YAML.

## Tests Added Or Updated

The following tests now pin this behavior:

- `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`
- `tests/testthat/test-exal-inference-config.R`
- `tests/testthat/test-qdesn-prior-defaults.R`

These tests cover:

- the refreshed-main defaults resolving to `50 / 80 / 500`
- the exAL inference resolver passing VB tau-freeze controls into the `rhs_ns` prior object
- the active `rhs_ns` prior object actually freezing `tau` through warmup before the first forced post-warmup update

## Gamma/Sigma Warmup Investigation

This note intentionally does not implement `gamma/sigma` warmup yet. The clean insertion points are:

### VB

Main site:

- `R/exal_ldvb_engine.R`

Current behavior:

- `q(sigma, gamma)` is updated jointly every VB iteration through the Laplace-Delta block around `find_mode_ld()`.

Recommended future design:

- add a dedicated `vb$sigmagam` control block
- support `freeze_warmup_iters`
- during warmup, skip the joint `find_mode_ld()` refresh and carry the current `qsiggam` state forward
- record a `sigmagam_frozen` trace and a post-warmup first-update flag in diagnostics

Why VB is the highest-leverage place:

- the MCMC chain initializes from the LDVB warm start, so VB-side stabilization changes the startup state that MCMC inherits

### MCMC

Main site:

- `R/exal_mcmc_fit.R`

Current behavior:

- `sigma/gamma` are updated in the core slice step via `update_sigma_gamma_once()`
- the latent-`v` draw occurs earlier in the iteration than the `sigma/gamma` update

Recommended future design:

- add `mcmc$sigmagam.freeze_burnin_iters`
- skip the `sigma/gamma` core update while frozen
- add a `sigmagam_frozen_trace` alongside existing tau-freeze diagnostics

Important caveat:

- MCMC-side `sigma/gamma` freezing alone does not change the first latent-`v` draw, because `latent_v` is sampled before the core `sigma/gamma` update in each MCMC iteration
- for startup stability, VB-side `sigma/gamma` warmup is likely to matter more than MCMC-side freezing

## Reproducibility Guidance

When relaunching this lane after 2026-04-17, keep this note with the launch report and preserve:

- the defaults YAML used for the run
- the git commit at launch time
- the run tag and tmux session
- the generated `fit_request.json` artifacts under each root

That combination is the authoritative record of what settings were actually used in a given run.
