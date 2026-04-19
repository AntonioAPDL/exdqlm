# QDESN Tau050 Failed-MCMC S-Freeze Implementation And Launch

Date: 2026-04-19  
Repo: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`  
Code launch commit: `e44a56a` (`Add latent-s freeze to tau050 failed MCMC relaunch`)

## Scope

This update implements a dedicated crash-only relaunch lane for the original
`23` hard numerical MCMC failures from the April 16, 2026 `tau050_refreshed_main`
source campaign. The new lane keeps the strengthened tau, sigma/gamma, and
latent-`v` warmup contract and adds a direct MCMC latent-`s` freeze /
sparse-update schedule to stabilize the latent state on both sides of the
fragile `latent_v` draw.

The authoritative crash-only grids remain:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv`
- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv`

The dedicated relaunch defaults surface is:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_defaults.yaml`

## Implementation

Primary code changes:

- `R/exal_inference_config.R`
  - added normalized `mcmc_control$latent_s` support
  - introduced `.exal_normalize_mcmc_latent_s_cfg()`
- `R/exal_mcmc_fit.R`
  - added latent-`s` schedule parsing
  - added hard-freeze / sparse-update / forced-thaw scheduling
  - added latent-`s` traces, counters, diagnostics, and failure payload context
- `R/qdesn_mcmc_validation.R`
  - exported latent-`s` health summary fields
  - exposed latent-`s` trace columns on the full-chain MCMC latent trace path
- `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
  - added `failed_mcmc_al_sfreeze`
  - added `failed_mcmc_exal_sfreeze`
- `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
  - added matching healthcheck phases

Primary test coverage:

- `tests/testthat/test-exal-inference-config.R`
- `tests/testthat/test-exal-mcmc.R`
- `tests/testthat/test-qdesn-sigmagam-warmup-validation-export.R`
- `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-sfreeze-config.R`

## Effective Warmup Contract

The `sfreeze` relaunch keeps the strengthened baseline already in the branch:

- VB `max_iter = 500`
- VB `min_iter_elbo = 80`
- VB sigma/gamma warmup `freeze_warmup_iters = 20`
- VB sigma/gamma damping `0.35` for `10` iterations
- VB sigma/gamma `min_postwarmup_updates = 3`
- MCMC RHS tau freeze burn-in `500`
- MCMC sigma/gamma freeze burn-in `500`
- MCMC latent-`v` warmup:
  - `freeze_burnin_iters = 50`
  - `sparse_update_every = 10`
  - `sparse_update_until_iter = 500`
  - `force_first_postwarmup_update = true`

New latent-`s` policy:

- `enabled = true`
- `freeze_burnin_iters = 50`
- `freeze_only_during_burn = true`
- `sparse_update_every = 10`
- `sparse_update_until_iter = 500`
- `force_first_postwarmup_update = true`
- `trace = true`

## Validation

Targeted test command:

```bash
Rscript -e 'testthat::test_local(filter = "exal-inference-config|exal-mcmc|qdesn-sigmagam-warmup-validation-export|qdesn-dynamic-tau050-failed-mcmc-sfreeze-config|qdesn-dynamic-tau050-failed-mcmc-relaunch", reporter = "summary")'
```

Outcome:

- passed cleanly after aligning the latent-`s` export test with the existing
  full-chain MCMC trace contract

Prepare-only validation from committed SHA `e44a56a`:

- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_sfreeze-20260419-031728__git-e44a56a`
- `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_sfreeze-20260419-031728__git-e44a56a`

Operational note:

- a parallel preflight attempt exposed the known shared source-materialization
  race, so the final live launch was done sequentially to keep startup clean
  and resource usage controlled

## Live Launch

Background launch commands:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al_sfreeze \
  --no-plots
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal_sfreeze \
  --no-plots
```

Live runs:

- AL lane
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_al_sfreeze-20260419-031755__git-e44a56a`
  - tmux: `qdesn_dynx_0419_031756`
- EXAL lane
  - run tag: `qdesn-dynamic-exdqlm-crossstudy-tau050-failed_mcmc_exal_sfreeze-20260419-031810__git-e44a56a`
  - tmux: `qdesn_dynx_0419_031810`

## Immediate Health Snapshot

Snapshot time: `2026-04-19 03:18 EDT`

| Lane | Selected roots | Materialized | Running | Success | Fail | Session live |
|---|---:|---:|---:|---:|---:|---|
| `failed_mcmc_al_sfreeze` | 9 | 2 | 2 | 0 | 0 | yes |
| `failed_mcmc_exal_sfreeze` | 14 | 2 | 2 | 0 | 0 | yes |

High-level read:

- both crash-only relaunch lanes are live
- both are running under tmux from committed SHA `e44a56a`
- both started with `2` workers, matching the efficiency / storage-safety plan
- no early failures were present in the first immediate health snapshot

## Reproducibility

- code commit used for the live relaunch: `e44a56a`
- branch pushed before launch: `origin/feature/qdesn-mcmc-alternative-0p4p0-integration`
- preflight and live run tags are captured under:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation`
  - `results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_failed_mcmc_sfreeze_validation`
- the relaunch intentionally targets the original `23` source-run numerical
  crashes and does not redefine the repair surface from later experimental waves
