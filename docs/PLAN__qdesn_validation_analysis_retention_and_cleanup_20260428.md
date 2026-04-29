# QDESN Validation Analysis-Retention And Cleanup Tracker

- created_at: 2026-04-28
- worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`
- primary run: `qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13`
- purpose: make future validation launches storage-efficient without losing comparison metrics or fit-overlay uncertainty bands

## Design Goals

- Keep the scientific comparison workflow intact: VB vs MCMC, EXAL vs AL, RHS-NS vs ridge, family/tau/size summaries.
- Keep posterior metric quality: the launch may use many posterior samples, but it should store scalar summaries and compact bands instead of full draw matrices.
- Keep fit-overlay plots reproducible after heavy payload cleanup.
- Keep failure forensics possible by retaining full RDS payloads for failed fits by default.
- Keep cleanup scoped, documented, dry-run-first, and safe around other active validation work.

## Stage 1: Analysis-Retention Implementation

- [x] Add compact train/holdout quantile-path writers.
- [x] Add `retention_profile: analysis` config support.
- [x] Add successful-fit pruning of `models/forecast_objects.rds` after summaries and compact path tables are written.
- [x] Retain full RDS payloads for failed fits by default.
- [x] Write per-fit `manifest/output_retention.json`.
- [x] Add compact path references to `fit_summary_row.csv`.
- [x] Make p90 fit-overlay plotting prefer compact path tables and fall back to legacy RDS.
- [x] Update the p90 n300/m50 defaults with analysis-retention fields.

## Stage 2: Repair And Cleanup Readiness

- [x] Make the saved-output repair script generate compact path tables while legacy RDS files are still available.
- [x] Add `--scope-root` to the heavy-payload cleanup script.
- [x] Preserve dry-run-first behavior.
- [x] Preserve live-session blocking unless explicitly overridden.
- [x] Preserve source datasets, package `.rda`, summaries, manifests, figures, logs, and configs.

## Stage 3: Tests

- [x] Test n300/m50 defaults encode analysis retention.
- [x] Test compact fit paths are written and successful full RDS payloads are pruned.
- [x] Test failed fits retain full RDS payloads by default.
- [x] Test p90 overlay data can be loaded from compact paths without `forecast_objects.rds`.
- [x] Run focused test file after patching.
- [x] Run `git diff --check`.

## Stage 4: Current Run Cleanup Sequence

- [x] Attempt final repair/closeout while current full RDS files still exist; the interrupted pass created the first compact paths, then `scripts/materialize_qdesn_compact_fit_paths_for_run.R` completed the compact artifact layer.
- [x] Confirm compact path tables exist for all current successful fits.
- [x] Confirm closeout overlay figures render from compact paths.
- [x] Run scoped cleanup dry run on the current campaign root.
- [x] Inspect cleanup manifest and expected freed GiB.
- [x] Execute scoped cleanup only after current summaries, compact paths, source data, manifests, and post-cleanup overlay rendering were verified.
- [x] Record observed freed space in the cleanup report.
- [x] Run a global binary dry-run after scoped cleanup to confirm no additional safe `.rds`/`.rda` payloads remain.
- [x] Remove old non-baseline `campaign_progress_trace_long.csv` report traces larger than 10 MB while preserving the official baseline trace.
- [x] Register the cleaned current run as the official baseline for future QDESN spec relaunches.

## Current Cleanup Result

- Final repair root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation/qdesn-dynamic-p90-steepertrend-n300m50-full-20260424-172949__git-366ca13/signoff_repair_final_20260428_191841`.
- Latest closeout root: `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_closeout_analysis/qdesn-dynamic-p90-steepertrend-n300m50-closeout-analysis-20260428-201418__git-f282f63`.
- Compact train path tables: `144 / 144`.
- Compact holdout path tables: `144 / 144`.
- Full `forecast_objects.rds` files remaining in current run: `0`.
- Current run results root after cleanup: about `430 MiB`.
- Cleanup execute manifest: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_scoped_payload_cleanup_execute_20260428/cleanup_summary.md`.
- Post-cleanup zero-payload verification: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_p90_n300m50_postcleanup_zero_verification_20260428/cleanup_summary.md`.
- Global binary dry-run after cleanup: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_validation_global_payload_cleanup_dryrun_20260428/cleanup_summary.md`.
- Old progress-trace cleanup: `reports/qdesn_mcmc_validation/storage_cleanup/qdesn_validation_old_progress_trace_cleanup_20260428/cleanup_summary.md`.
- Deleted payloads: `360`.
- Deleted footprint: `149.69 GiB`.
- Old progress traces deleted: `9`.
- Old progress-trace footprint deleted: `0.39 GiB`.
- Observed free-space delta on `/home`: `149.69 GiB`.
- Post-cleanup overlay verification: `24 / 24` figures successful from compact artifacts.
- Official baseline config: `config/validation/qdesn_dynamic_p90_steepertrend_n300m50_official_baseline.yaml`.
- Official baseline report: `docs/BASELINE__qdesn_dynamic_p90_steepertrend_n300m50_20260428.md`.

## Acceptance Criteria

- Future full validation launches can run with high posterior draw budgets while keeping persistent artifacts compact.
- The main comparison tables do not depend on `forecast_objects.rds`.
- Fit-overlay figures with uncertainty bands do not depend on `forecast_objects.rds`.
- Full RDS files are retained for failed fits unless explicitly configured otherwise.
- Current-run cleanup is scoped to the intended campaign and documented by a generated manifest.
