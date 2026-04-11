# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Normalized Multiseed Implementation And Preflight

Date: 2026-04-11
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Implement the normalized multiseed relaunch design from the updated plan and verify that the new
campaign surface is launch-ready at the code, config, wrapper, and preflight levels before any big
relaunch is started.

This report covers:

- D1 seed plumbing
- D2 seed selection
- D3 normalized posterior / burn-in contract
- D4 storage-safe non-winner handling
- canary and full `prepare-only` validation

## 2) Chosen Architecture

The implemented architecture is a **full root-level rerun**, not another residual-stage wave.

Per root:

- `vb_al` runs once
- `vb_exal` runs once
- `mcmc_al` runs with `4` deterministic seed replicates
- `mcmc_exal` runs with `4` deterministic seed replicates

Per MCMC method:

- seed replicates are written under:
  - `fits/mcmc_<family>/seeds/seed_01`
  - `fits/mcmc_<family>/seeds/seed_02`
  - `fits/mcmc_<family>/seeds/seed_03`
  - `fits/mcmc_<family>/seeds/seed_04`
- the winning seed is selected by:
  - `PASS > WARN > FAIL`
  - then lower `forecast_CRPS_mean`
  - then lower runtime
  - then lower seed replicate id
- the selected seed is promoted into the canonical:
  - `fits/mcmc_<family>`

Parallelism contract:

- outer campaign workers:
  - `1`
- inner seed workers:
  - `4`

This matches the user-requested “run 4 different random seeds in parallel if possible” contract
without multiplying outer and inner parallelism at the same time.

## 3) Implemented Code Changes

Core runner changes:

- `R/qdesn_static_exdqlm_crossstudy.R`
  - explicit DESN seed injection
  - explicit synthesis seed injection
  - explicit MCMC RNG / seed / VB warm-start plumbing
  - `forecast_CRPS_mean` and related metrics added to fit-summary rows
  - optional `method_dir` override for seed-replicate execution
- `R/qdesn_dynamic_exdqlm_crossstudy.R`
  - multiseed config helper
  - deterministic seed-bundle generation
  - seed-metric table builder
  - exact ranking helper for best-seed selection
  - selected-seed promotion into canonical `fits/mcmc_*`
  - non-winning heavy-artifact pruning
  - root-level and campaign-level seed-selection table collection
  - staged-source inventory reuse when already materialized
  - relaxed reference inventory parsing when raw reference `sim_output.rds` files are absent

Generic runner / observability changes:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`
  - preflight manifests now record:
    - normalized posterior contract
    - multiseed policy
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R`
  - now reports:
    - `campaign_mcmc_seed_selection.csv` row counts
    - `campaign_mcmc_seed_winners.csv` row counts

## 4) New Checked-In Assets

Defaults:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_defaults.yaml`

Canary grid:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_grid.csv`

Canary grid materializer:

- `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_grid.R`

Full wrappers:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation.R`

Canary wrappers:

- `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_canary_validation.R`

## 5) Normalized Contract

Normalized VB contract:

- `metrics.posterior_metric_draws = 20000`
- `pipeline.sampling.nd_draws = 20000`
- `pipeline.synthesis.n_samp = 20000`

Normalized MCMC contract:

- `n_burn = 5000`
- `n_mcmc = 20000`
- `thin = 1`
- `store_latent_draws = false`
- `store_rhs_draws = false`

Multiseed contract:

- `enabled = true`
- `mcmc_seed_reps = 4`
- `parallel_seed_workers = 4`
- `selection_metric = forecast_CRPS_mean`
- `prune_nonwinning_heavy_outputs = true`

## 6) Canary Scope

Checked-in canary scope:

- `6` roots
- both priors:
  - `ridge`
  - `rhs_ns`
- both fit windows:
  - `500`
  - `5000`
- all three source families:
  - `gausmix`
  - `laplace`
  - `normal`

Representative canary roots:

- `gausmix tau=0.05 fit_size=500 ridge`
- `normal tau=0.25 fit_size=500 rhs_ns`
- `normal tau=0.95 fit_size=5000 ridge`
- `gausmix tau=0.05 fit_size=5000 rhs_ns`
- `laplace tau=0.25 fit_size=5000 rhs_ns`
- `normal tau=0.05 fit_size=5000 rhs_ns`

## 7) Validation Evidence

Code-load checks:

- `pkgload::load_all(...)`
  - passes

Helper checks:

- normalized defaults load correctly
- multiseed config exposes `4` seed replicates and `4` seed workers
- normalized posterior-draw / MCMC burn-in values resolve correctly
- seed overrides reach:
  - `cfg$desn$seed`
  - `cfg$synthesis$seed`
  - `cfg$inference$mcmc$control$seed`
  - `cfg$inference$mcmc$control$rng_seed`
  - `cfg$inference$mcmc$vb_warm_start_seed`
- ranking helper selects:
  - better grade before better CRPS
  - then better CRPS within grade

Source / reference smoothness checks:

- staged materialized inventory reuse:
  - passes
- reference inventory parsing with missing raw `sim_output.rds`:
  - passes

Committed-state `prepare-only` runs:

- canary:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-preflight-20260411`
  - passes
- full:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-full-preflight-20260411`
  - passes

Preflight outputs:

- canary manifest:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-canary-preflight-20260411/launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json`
- full manifest:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation/qdesn-dynamic-exdqlm-crossstudy-deepdesn-normseed-full-preflight-20260411/launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json`

## 8) Important Smoothness Fixes

Two changes were necessary to keep this relaunch smooth on the current branch state:

1. staged source reuse
- the effective-w300 staged source inventory already exists under the QDESN repo;
- the dynamic materialization layer now reuses that inventory when present instead of requiring the
  original full-source `sim_output.rds` files every time.

2. reference raw-file tolerance
- the reference comparison surface still has the needed summary tables;
- some raw `sim_output.rds` files under the reference fit-input roots are no longer present;
- reference inventory parsing now treats those raw paths as optional instead of fatal.

These are not scientific contract changes. They are reproducibility / operational continuity fixes.

## 9) Launch Readiness

Current read:

- D1 through D4 are implemented
- canary and full `prepare-only` validation both pass
- the normalized multiseed relaunch surface is now launch-ready from a committed state

Not yet done in this report:

- no canary execution run was launched here
- no full normalized multiseed campaign was launched here

That separation is intentional so launch remains a deliberate decision after the implementation
state is committed and tracked.
