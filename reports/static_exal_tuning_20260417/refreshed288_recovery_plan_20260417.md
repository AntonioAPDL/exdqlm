# Refreshed288 Recovery Plan

Generated: `2026-04-17 EDT`

## Situation

The refreshed `288` relaunch did pass the smoke gate and enter the real full run.

The stoppage happened during `full_static_vb`, after substantial progress:

| scope | total | completed | stale running | pending | pass | warn | fail |
|---|---:|---:|---:|---:|---:|---:|---:|
| `full_static_vb` | 108 | 76 | 8 | 24 | 74 | 2 | 0 |
| full `288` run | 288 | 76 | 8 | 204 | 74 | 2 | 0 |

There are no live refreshed288 workers now.

The newest row artifact is `2026-04-17 02:14:38 EDT`, so the run is currently stopped.

## What To Preserve

Keep the existing partial full-run state intact under:

`tools/merge_reports/full288_refreshed288_paperaligned_20260416`

Preserve all of these:

- completed row status files
- completed health and metrics CSVs
- completed draw exports
- all existing VB fit RDS files
- the full manifest and registries

Do not delete the run root.

Do not call the prepare script again.

Important:

- [LOCAL_refreshed288_prepare_20260416.R](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_prepare_20260416.R) unconditionally removes the run root with `unlink(..., recursive = TRUE)`.
- Any relaunch or recovery must therefore use the existing full manifest with `--no-prepare` semantics.

## What Happened

The `8` stranded rows are:

- `217`, `219`, `221`, `223`
- `233`, `235`, `237`, `239`

They are all:

- `full_static_vb`
- `static_shrink`
- `laplace`
- `fit_size = 1000`
- `tau = 0.25` or `0.50`

Those rows all wrote candidate VB fit files, but none wrote:

- `health/*.csv`
- `metrics/*.csv`
- `draws/*.rds`

So the stop happened after fit creation and before post-fit export/gating completed.

The strongest operational interpretation is:

1. the full run was active,
2. those `8` long rows were the in-flight batch,
3. the supervising PTY session disappeared,
4. the worker batch died externally,
5. the row files were left stale at `status = running`.

There is no evidence of a system-wide OOM event.

## Why Resume Is Safer Than Reset

Resume is the right first move because:

- the full run already has `76` completed rows worth preserving
- the `8` stranded rows already have VB fit files
- rerunning those rows without `--force` should reuse the fit objects and continue from post-fit export/gating

Only if a stranded row fails again should we escalate to a forced per-row refit.

## Safe Recovery Strategy

Use a detached recovery runner, not an interactive PTY.

Use lower concurrency for the remaining `full_static_vb` work:

| phase | recommended workers |
|---|---:|
| `full_static_vb` | `2` |
| `full_dynamic_vb` | `4` |
| `full_static_mcmc` | `4` |
| `full_dynamic_mcmc` | `3` |

Reason:

- the stalled `laplace TT1000` static VB post-fit path is materially heavier than the earlier completed static VB rows
- lower concurrency reduces the chance of another externally interrupted or overloaded batch

## Recovery Script

Use:

[LOCAL_refreshed288_resume_from_state_20260417.sh](/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration/tools/merge_reports/LOCAL_refreshed288_resume_from_state_20260417.sh)

This script:

- never calls prepare
- reads the existing full manifest
- selects only rows currently marked `running` or `not_started`
- resumes phase by phase from the current state
- refreshes evaluate/report outputs after each resumed phase

Default phase range:

- `full_static_vb`
- `full_dynamic_vb`
- `full_static_mcmc`
- `full_dynamic_mcmc`

Default status filter:

- `running,not_started`

## Exact Recovery Commands

### 1. Audit the recovery selection

```bash
tools/merge_reports/LOCAL_refreshed288_resume_from_state_20260417.sh dry-run
```

### 2. Resume only the interrupted static VB phase first

```bash
tmux new-session -d -s refreshed288_recover_static_vb \
  "cd /home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration && \
   tools/merge_reports/LOCAL_refreshed288_resume_from_state_20260417.sh launch --to-phase=full_static_vb \
   > reports/static_exal_tuning_20260417/refreshed288_recover_static_vb_20260417.log 2>&1"
```

This is the recommended first move.

It will pick up:

- the `8` stale `running` rows
- the `24` remaining `not_started` rows in `full_static_vb`

without re-preparing the run.

### 3. If static VB finishes cleanly, resume the remaining phases

```bash
tmux new-session -d -s refreshed288_recover_tail \
  "cd /home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration && \
   tools/merge_reports/LOCAL_refreshed288_resume_from_state_20260417.sh launch --from-phase=full_dynamic_vb \
   > reports/static_exal_tuning_20260417/refreshed288_recover_tail_20260417.log 2>&1"
```

### 4. If one of the `8` stranded rows fails again

Do not reset the whole phase.

Instead rerun only that row with force:

```bash
Rscript tools/merge_reports/LOCAL_refreshed288_run_row_20260416.R \
  --manifest=tools/merge_reports/LOCAL_refreshed288_full_manifest_20260416.csv \
  --row_id=<row_id> \
  --force
```

Then refresh status:

```bash
Rscript tools/merge_reports/LOCAL_refreshed288_evaluate_20260416.R \
  --manifest=tools/merge_reports/LOCAL_refreshed288_full_manifest_20260416.csv

Rscript tools/merge_reports/LOCAL_refreshed288_refresh_comparison_20260416.R \
  --manifest=tools/merge_reports/LOCAL_refreshed288_full_manifest_20260416.csv
```

## What Not To Do

Do not do any of these:

- `Rscript tools/merge_reports/LOCAL_refreshed288_prepare_20260416.R`
- `tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh launch --manifest-kind=full`
- anything that recreates the run root before we decide to abandon the current partial full run

Those paths would wipe the preserved partial state.

## Recommendation

The safest path forward is:

1. preserve the current full run,
2. resume `full_static_vb` only,
3. verify that the stalled `laplace TT1000` rows finalize correctly,
4. then resume the remaining full phases from state.

That gives the highest chance of recovering the current canonical run without losing the `76` rows already completed.
