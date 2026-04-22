# Refreshed288 0.4.0 Sync and Backport Execution

Date: 2026-04-21  
Validation branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`  
Backport branch: `integration/0.4.0-validation-warmup-backport`

## Why we stopped the active recovery lane

We stopped the live staged `exdqlm` `TT5000` recovery confirmation before the next dataset-refresh cycle because:

1. the recovery program was blocked on a single long-running production confirmation row,
2. the next planned work changes the dynamic datasets, which would make further compute on the current dataset low-value, and
3. we needed to re-align the validation code with the latest upstream `0.4.0` package state before starting that new dataset cycle.

The stopped recovery state is frozen in:

- [refreshed288_exdqlm_tt5000_recovery_stop_freeze_and_0p4p0_sync_handoff_20260421.md](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260421/refreshed288_exdqlm_tt5000_recovery_stop_freeze_and_0p4p0_sync_handoff_20260421.md)

## What was done on the validation branch

The validation branch was brought to a clean frozen checkpoint, then synced forward to the latest remote `0.4.0`.

- freeze-stop commit: `f0199a5`
- merge latest `origin/cransub/0.4.0`: `77a08e1`
- post-merge VB trace normalization fix: `60fb881`

Latest upstream `0.4.0` synced into validation branch at execution time:

- upstream branch: `origin/cransub/0.4.0`
- upstream SHA: `dc032e6`

Validation-branch verification that passed after the sync:

- `pkgload::load_all('.', quiet = TRUE)`
- `tests/testthat/test-mcmc-dynamic-strict-parity.R`
- `tests/testthat/test-vb-mcmc-convergence-controls.R`

## What was backported onto fresh 0.4.0

A fresh worktree and branch were created directly from the current remote `0.4.0` state:

- worktree: `/home/jaguir26/local/src/exdqlm__wt__0p4p0_validation_warmup_backport`
- branch: `integration/0.4.0-validation-warmup-backport`

Selected reusable package-level updates from the validation study were then ported onto that branch, including:

- dynamic MCMC warmup and freeze controls,
- VB and LDVB stabilization controls,
- latent-state warmup controls,
- numerical-stability hardening in shared utilities,
- strict-backend test coverage and regression tests,
- API-aligned test updates for the current `0.4.0` static naming.

Backport branch result:

- backport commit: `54fb296`
- remote branch: `origin/integration/0.4.0-validation-warmup-backport`

Focused backport verification that passed:

- `pkgload::load_all('.', quiet = TRUE)`
- `tests/testthat/test-vb-mcmc-convergence-controls.R`
- `tests/testthat/test-mcmc-dynamic-strict-parity.R`
- `tests/testthat/test-static-diagnostics.R`
- `tests/testthat/test-crps-helper-regression.R`
- `tests/testthat/test-dlm-df-smoother-regression.R`

## Final state

At the end of this execution:

1. the active recovery run was stopped and documented,
2. the validation branch was clean, synced with the latest `0.4.0`, committed, and pushed,
3. a fresh `0.4.0`-based backport branch was created, verified, committed, and pushed, and
4. both branches were left in a clean state for the next dataset-refresh phase.
