# PLAN: QDESN Dynamic exDQLM Cross-Study Tau050 Refreshed-Main Failed-MCMC Relaunch

Date: 2026-04-17  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Relaunch only the failed MCMC fits from the completed `tau050_refreshed_main` validation run, under
the strengthened warmup policy now implemented on this branch.

Source run:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`

This run is complete and terminal. The relaunch is a new, auditable repair pass rather than a
retrofit of the finished run tree.

## 2) Failure Surface

Terminal outcome from the completed source run:

- `23 / 144` failed fits
- `16 / 36` affected roots
- `9` failed `mcmc_al` fits
- `14` failed `mcmc_exal` fits
- `0` VB failures

All failed fits were hard runtime failures, not merely weak signoff:

- `exal_mcmc_fit::latent_v returned 1 invalid draws after 12 retry batches`
- downstream fit summary symptom:
  - `missing_chain_diagnostics`

## 3) Relaunch Strategy

We do **not** rerun the full 36-root program.

We also do **not** rerun successful VB fits or successful MCMC fits.

Instead, the repair pass is split into two exact failed-fit lanes:

1. `failed_mcmc_al`
   - exact scope: the `9` roots whose `mcmc_al` fit failed
   - methods: `mcmc`
   - likelihoods: `al`
2. `failed_mcmc_exal`
   - exact scope: the `14` roots whose `mcmc_exal` fit failed
   - methods: `mcmc`
   - likelihoods: `exal`

This is more efficient than rerunning all MCMC fits on all `16` failed roots, because `7` roots
failed in both lanes while the remaining `9` failed in only one lane.

## 4) Warmup / Policy Contract

The failed source run still materialized the older policy:

- VB `min_iter_elbo = 20`
- VB tau freeze `10`
- MCMC tau freeze burn-in `400`

The failed-fit relaunch uses the current strengthened defaults in:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml`

Current relaunch policy:

- VB `min_iter_elbo = 80`
- VB `rhs_ns` tau freeze / warmup `50`
- MCMC `rhs_ns` tau freeze burn-in `500`
- VB `sigmagam.freeze_warmup_iters = 10`
- MCMC `sigmagam.freeze_burnin_iters = 50`

## 5) Reproducibility Assets

Checked-in relaunch assets:

- failed-grid materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R`
- exact failed-only grids:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv`
- launch wrapper support:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- healthcheck wrapper support:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`

Regression coverage:

- `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`
- `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-relaunch.R`

## 6) Execution Commands

Regenerate the failed-only grids from the completed source run:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R
```

Prepare-only validation:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --prepare-only \
  --no-plots
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --prepare-only \
  --no-plots
```

Execution:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --no-plots
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --no-plots
```

Healthcheck:

```bash
Rscript scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --run-tag <failed_mcmc_al_run_tag>
```

```bash
Rscript scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --run-tag <failed_mcmc_exal_run_tag>
```

## 7) Guardrails

- No retroactive edits to the completed source run.
- No blind 144-fit relaunch.
- No rerun of successful VB fits.
- No rerun of successful MCMC fits outside the failed lane.
- Keep `--allow-grid-subset` for auditable subset execution.
- Keep the failed-only grids checked in so the relaunch can be repeated from committed state.
