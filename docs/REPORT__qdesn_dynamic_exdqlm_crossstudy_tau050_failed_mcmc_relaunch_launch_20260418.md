# REPORT: QDESN Dynamic exDQLM Cross-Study Tau050 Failed-MCMC Relaunch Launch

Date: 2026-04-18  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Launch Decision

The completed source run remained:

- `121 / 144` successful fits
- `23 / 144` failed fits
- `9` failed `mcmc_al` fits
- `14` failed `mcmc_exal` fits

The failed-only relaunch package had already been implemented and prepare-only validated on
2026-04-17. On 2026-04-18, the package was revalidated from the current workspace state and then
launched live.

## 2) Pre-Launch Validation

Validated immediately before launch:

```bash
Rscript scripts/materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_grids.R
```

```bash
Rscript -e 'testthat::test_local(filter = "qdesn-dynamic-tau050-refreshed-main-config|qdesn-dynamic-tau050-failed-mcmc-relaunch", reporter = "summary")'
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --prepare-only \
  --no-plots \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-prepare-20260418-021532__git-c6f8955
```

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --prepare-only \
  --no-plots \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-prepare-20260418-021532__git-c6f8955
```

Outcome:

- all checks passed

Important operational note:

- when the two prepare-only phases were first run in parallel on 2026-04-18, the `failed_mcmc_exal`
  pass briefly hit a transient source-materialization path race
- rerunning `failed_mcmc_exal` sequentially succeeded
- live launches were therefore executed sequentially rather than concurrently at kickoff

## 3) Live Launch Commands

### `failed_mcmc_al`

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_al \
  --no-plots \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955
```

### `failed_mcmc_exal`

```bash
Rscript scripts/launch_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation.R \
  --phase failed_mcmc_exal \
  --no-plots \
  --run-tag qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955
```

## 4) Launched Run Tags

### `failed_mcmc_al`

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955`
- tmux session:
  - `qdesn_dynx_0418_021718`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-al-launch-20260418-021532__git-c6f8955/launch/launcher_stdout.log`

### `failed_mcmc_exal`

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955`
- tmux session:
  - `qdesn_dynx_0418_021750`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation/qdesn-dynamic-exdqlm-crossstudy-tau050-failed-mcmc-exal-launch-20260418-021532__git-c6f8955/launch/launcher_stdout.log`

## 5) Immediate Post-Launch Health

### `failed_mcmc_al`

Immediate health snapshot:

- snapshot time:
  - `2026-04-18 02:18:19 EDT`
- selected roots:
  - `9`
- materialized roots:
  - `3 / 9`
- running roots:
  - `3 / 9`
- success roots:
  - `0 / 9`
- fail roots:
  - `0 / 9`
- launcher session live:
  - `TRUE`

### `failed_mcmc_exal`

Immediate health snapshot:

- snapshot time:
  - `2026-04-18 02:18:19 EDT`
- selected roots:
  - `14`
- materialized roots:
  - `3 / 14`
- running roots:
  - `3 / 14`
- success roots:
  - `0 / 14`
- fail roots:
  - `0 / 14`
- launcher session live:
  - `TRUE`

## 6) Process Evidence

At launch confirmation:

- `failed_mcmc_al` runner process was live
- `failed_mcmc_al` had `3` hot `pipeline_real_main.R` workers
- `failed_mcmc_exal` runner process was live
- `failed_mcmc_exal` had `3` hot `pipeline_real_main.R` workers

This confirms both relaunch lanes moved past preflight and into actual execution.

## 7) Reproducibility Snapshot

These launches were started from a dirty worktree rather than a new commit.

To preserve provenance, each launched run includes:

- `launch/worktree_status.txt`
- `launch/worktree_diff_stat.txt`
- `launch/worktree.diff`

This keeps the exact local launch surface auditable even without a fresh launch commit.

## 8) Current Interpretation

What is now true:

- the failed-only relaunch is no longer just planned
- both failed-only lanes are live
- both lanes have active worker pools
- both lanes have already begun materializing roots

What is not yet known:

- whether the stronger warmup policy recovers the previously failing fits
- whether the old `latent_v` numerical crash family is eliminated, reduced, or unchanged

That answer now depends on ongoing runtime outcome rather than setup work.
