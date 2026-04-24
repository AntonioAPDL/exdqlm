# Refreshed288 Dynamic MCMC Optimized Resume

Generated: `2026-04-23`

## Why this intervention was made

The original full relaunch was using the phase-level worker contract frozen in the
baseline launcher:

- `workers_static_vb = 8`
- `workers_dynamic_vb = 6`
- `workers_static_mcmc = 4`
- `workers_dynamic_mcmc = 3`

By the time the study reached the final dynamic MCMC tail, the machine still had
substantial headroom (`64` logical CPUs), but only `3` single-threaded row
workers were active. The row runner is already resume-safe because completed rows
with existing `candidate_fit_path` artifacts are skipped when `--force` is not
used, so the efficient move was a **controlled stop and selective relaunch of the
unfinished tail**, not a full restart.

## Freeze point before optimized resume

The stalled tail was frozen at:

- run tag: `20260422_p90_full288_baseline_v1`
- manifest kind: `full`
- status summary after controlled stop:
  - `completed = 258`
  - `running = 0`
  - `not_started = 30`
  - `pass = 199`
  - `warn = 32`
  - `fail = 27`

This freeze point was produced with:

```bash
tools/merge_reports/LOCAL_refreshed288_stop_20260423_p90_full288.sh \
  --run-tag=20260422_p90_full288_baseline_v1 \
  --manifest-kind=full \
  --execute=true \
  --refresh-status=true
```

## What was implemented

### 1. Safer status I/O

Shared helpers now use atomic CSV writes and tolerant CSV reads:

- `write_csv_atomic_refreshed288()`
- `safe_read_csv_refreshed288()`

These were wired into:

- row status writes
- runtime-failure health/metrics writes
- evaluate/status summary writes

This hardens the monitoring path against transient empty-read races during live
health checks.

### 2. Phase/status-aware row selection

The launcher now supports selecting rows by:

- `--phase-filter=...`
- `--status-filter=...`

The selector is backed by:

- `select_row_ids_for_launch_refreshed288()`

This makes it possible to relaunch only:

- a chosen phase
- and only rows in statuses such as `running,not_started`

without touching already completed work.

### 3. Controlled stop helper

Added:

- [LOCAL_refreshed288_stop_20260423_p90_full288.sh](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_stop_20260423_p90_full288.sh)

This helper:

- stops the active tmux session
- kills matching launcher/row-worker processes for the selected run tag
- refreshes the status, phase, and method summaries afterward

### 4. Dedicated dynamic-MCMC resume wrapper

Added:

- [LOCAL_refreshed288_resume_dynamic_mcmc_background_20260423_p90_full288.sh](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_resume_dynamic_mcmc_background_20260423_p90_full288.sh)

This wrapper pins the optimized tail relaunch to:

- same run tag
- same manifest
- `--no-prepare`
- `--phase-filter=full_dynamic_mcmc`
- `--status-filter=running,not_started`
- `workers_dynamic_mcmc = 8`

It writes to a dedicated resume log instead of reusing the original `tee`-based
launcher log.

## Optimized relaunch command

The dynamic MCMC tail was restarted with:

```bash
tools/merge_reports/LOCAL_refreshed288_resume_dynamic_mcmc_background_20260423_p90_full288.sh \
  --run-tag=20260422_p90_full288_baseline_v1 \
  --manifest-kind=full \
  --workers-dynamic-mcmc=8
```

Resulting session:

- `refreshed288_20260422_p90_full288_baseline_v1_resume_dynamic_mcmc`

Resulting log:

- [refreshed288_p90_full288_resume_dynamic_mcmc_20260423_20260422_p90_full288_baseline_v1.log](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/reports/static_exal_tuning_20260422/refreshed288_p90_full288_resume_dynamic_mcmc_20260423_20260422_p90_full288_baseline_v1.log)

## First verification after resume

The first post-resume healthcheck confirmed the tail was relaunched with higher
effective concurrency:

- `completed = 259`
- `running = 7`
- `not_started = 22`
- `pct_completed = 89.9`
- `pct_active_or_done = 92.4`

This is the expected shape for a pending-only dynamic-MCMC relaunch:

- previously completed rows remain preserved
- interrupted/pending rows are resumed
- the unfinished block shrinks without restarting the full study

## Validation performed

- dry-run of the new selector path:
  - `full_dynamic_mcmc`
  - `status_filter = running,not_started`
  - selected `30` rows from the freeze point
- shell syntax check on:
  - launcher
  - background wrapper
  - stop helper
  - resume helper
- regression test:
  - `tests/testthat/test-refreshed288-resume-selector.R`
- live healthcheck after resume to confirm:
  - session alive
  - pending-only tail relaunch
  - active row workers resumed

## Operational interpretation

This was **not** a full restart. It was a controlled optimization of the final
unfinished block:

- preserve completed work
- stop a low-concurrency tail
- resume only unfinished dynamic MCMC rows
- raise dynamic-MCMC worker count from `3` to `8`

That keeps the run reproducible while using materially more available compute.
