# refreshed288 p90 Dynamic MCMC Recovery Relaunch

Date: 2026-04-24

Run tag: `20260422_p90_full288_baseline_v1`

## Why this relaunch exists

The full p90 relaunch completed all VB and static MCMC work, but the dynamic
MCMC tail stopped with no live tmux session or row workers. The live status
surface before this recovery was:

| Dynamic MCMC state | Rows |
|---|---:|
| Completed with `PASS` | 8 |
| Completed with `FAIL` | 3 |
| Stale `running` without live workers | 4 |
| `not_started` | 17 |
| `failed_runtime` | 4 |

The four operational runtime failures were rows `8`, `10`, `12`, and `14`.
They showed R connection read/write errors tied to very large `.rds`
serialization. Disk and memory were checked before this recovery:

| Resource | Pre-recovery read |
|---|---:|
| `/home` free space | `142G` |
| `/home` usage | `84%` |
| available memory | `488G` |

## Recovery policy

This recovery targets dynamic MCMC rows that are not cleanly resolved:

```text
phase == full_dynamic_mcmc
AND (
  status_current in {running, not_started, failed_runtime}
  OR gate_current == FAIL
)
```

That selects `28` rows:

| Retry reason | Rows |
|---|---:|
| `not_started` | 17 |
| `stale_running_without_worker` | 4 |
| `operational_runtime_failure` | 4 |
| `completed_gate_fail` | 3 |

Healthy completed dynamic MCMC rows are not relaunched.

## Important implementation change

For this recovery, MCMC VB warm starts are still used, but the temporary VB-init
fit is kept in memory and is not read from or written to the `vb_init/` cache.

Environment setting:

```bash
REFRESHED288_MCMC_VB_INIT_CACHE=none
```

This avoids reusing corrupt zero-byte or partial VB-init artifacts and avoids
creating new multi-GB VB-init cache files during the recovery.

## Launch command

```bash
tools/merge_reports/LOCAL_refreshed288_relaunch_dynamic_mcmc_recovery_background_20260424_p90_full288.sh \
  --run-tag=20260422_p90_full288_baseline_v1 \
  --manifest-kind=full \
  --workers-dynamic-mcmc=4
```

The wrapper launches with:

```text
--phase-filter=full_dynamic_mcmc
--status-filter=running,not_started,failed_runtime
--outcome-filter=FAIL
--filter-mode=any
--force
REFRESHED288_MCMC_VB_INIT_CACHE=none
```

## Tracking artifacts

Retry-row tracker:

```text
reports/static_exal_tuning_20260424/refreshed288_dynamic_mcmc_recovery_retry_rows_20260424.csv
```

Recovery wrapper:

```text
tools/merge_reports/LOCAL_refreshed288_relaunch_dynamic_mcmc_recovery_background_20260424_p90_full288.sh
```

Selector and runner changes:

```text
tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R
tools/merge_reports/LOCAL_refreshed288_launch_20260422_p90_full288.sh
tools/merge_reports/LOCAL_refreshed288_run_row_20260422_p90_full288.R
```

## Verification before launch

The dry-run selected exactly `28` dynamic MCMC rows and no healthy completed
dynamic MCMC rows. Focused selector tests passed.
