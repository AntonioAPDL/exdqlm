# REPORT: QDESN Dynamic exDQLM Cross-Study Tau050 Refreshed-Main Failed-MCMC Relaunch Prepare-Only

Date: 2026-04-17  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Scope

This report validates the failed-only relaunch package prepared after the completed
`tau050_refreshed_main` run finished with `23` failed MCMC fits.

Validated relaunch lanes:

1. `failed_mcmc_al`
2. `failed_mcmc_exal`

No live compute relaunch was started in this step. This was a prepare-only validation pass.

## 2) Checked-In Assets

Added / updated:

- failed-grid materializer:
  - `scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R`
- exact failed-only grids:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv`
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv`
- wrapper phase support:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R`
- regression tests:
  - `tests/testthat/test-qdesn-dynamic-tau050-refreshed-main-config.R`
  - `tests/testthat/test-qdesn-dynamic-tau050-failed-mcmc-relaunch.R`

## 3) Grid Materialization

Regenerated from the completed source run:

- source run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-full-20260416-212700__git-15fe674`
- failed fits recovered:
  - `23`
- failed `mcmc_al` roots:
  - `9`
- failed `mcmc_exal` roots:
  - `14`
- overlap roots:
  - `7`

## 4) Prepare-Only Commands

Validated with:

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --prepare-only \
  --no-plots \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-prepare-20260417-213915__git-c6f8955
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --prepare-only \
  --no-plots \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-prepare-20260417-213915__git-c6f8955
```

## 5) Prepare-Only Outcome

### `failed_mcmc_al`

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-prepare-20260417-213915__git-c6f8955`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-prepare-20260417-213915__git-c6f8955/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- methods per root:
  - `mcmc`
- likelihoods per root:
  - `al`
- requested fits per root:
  - `1`
- selected roots:
  - `9`
- fit sizes:
  - `5000`

### `failed_mcmc_exal`

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-prepare-20260417-213915__git-c6f8955`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-prepare-20260417-213915__git-c6f8955/launch/qdesn_dynamic_exdqlm_crossstudy_preflight.md`
- methods per root:
  - `mcmc`
- likelihoods per root:
  - `exal`
- requested fits per root:
  - `1`
- selected roots:
  - `14`
- fit sizes:
  - `500, 5000`

## 6) Regression Checks

Validated with:

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-refreshed-main-config|qdesn-dynamic-tau050-failed-mcmc-relaunch", reporter = "summary")'
```

Outcome:

- passed

## 7) Interpretation

The failed-only relaunch package is ready.

What is now true:

- the failed MCMC surface is isolated into exact rerun lanes;
- the relaunch is wired to the stronger warmup policy now present on this branch;
- the rerun can be launched from committed paths without rerunning the whole 144-fit campaign;
- prepare-only validation is clean for both failed lanes.

What was not done in this step:

- no long-running relaunch was started;
- no new result interpretation was produced yet.
