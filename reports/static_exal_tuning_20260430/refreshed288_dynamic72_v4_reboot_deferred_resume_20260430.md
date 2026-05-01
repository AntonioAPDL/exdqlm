# Dynamic 72 v4 Reboot Deferred Resume

## Executive Status

The planned server reboot was deferred. It is now expected on `2026-05-01 13:00 PT` (`2026-05-01 16:00 ET`), not immediately on `2026-04-30`.

Because the machine has enough time and resources before the reboot window, the v4 targeted repair smoke should resume now instead of waiting.

## Pre-Resume State

| Item | Value |
| --- | --- |
| Worktree | `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration` |
| Branch | `validation/rerun-after-0.4.0-sync-0p4p0-integration` |
| Resume commit base | `7132f60` |
| Run tag | `20260430_p90_dynamic72_qdesn_comparable_v4_laplace_repair` |
| Reboot-deferred resume time | `2026-04-30 21:03 EDT` |
| Planned reboot time | `2026-05-01 13:00 PT / 16:00 ET` |
| Active row-runner processes before resume | `0` |
| Active tmux validation session before resume | `none` |
| Free disk before resume | about `786G` available on `/home` |
| Available RAM before resume | about `490Gi` |
| Logical cores | `64` |

## Why Resume

Rows `20`, `44`, and `68` were previously marked `failed_runtime` only because we intentionally stopped them for an expected immediate reboot. That was an operational interruption, not a numerical or sampler-health conclusion.

The latest true sampler-health evidence remains:

| Stage | Result |
| --- | --- |
| v2 source-index smoke | Completed operationally; rows `20`, `44`, and `68` failed sigma/gamma sampler-health gates. |
| v3 slice/warmup repair | Completed operationally; rows `20`, `44`, and `68` still failed sigma/gamma sampler-health gates. |
| v4 Laplace-RW repair | Interrupted for reboot before producing usable fit-health metrics. |

## Resume Target

| Row | Case |
| ---: | --- |
| 20 | `dynamic::gausmix::0p50::500::default::exdqlm::mcmc` |
| 44 | `dynamic::laplace::0p50::500::default::exdqlm::mcmc` |
| 68 | `dynamic::normal::0p50::500::default::exdqlm::mcmc` |

## Resume Contract

| Setting | Value |
| --- | --- |
| Proposal | `laplace_rw` |
| Joint sigma/gamma proposal | `TRUE` |
| Burn-in | `10000` |
| Retained MCMC draws | `20000` |
| Laplace refresh interval/start/weight | `10 / 50 / 0.9` |
| sigmagam/theta/latent freeze burn-in | `250 / 250 / 250` |
| latent mode | `u_st_pair` |
| Workers | `3` targeted MCMC workers |
| Threads per worker | `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1` |

## Reproducible Resume Command

The resumed smoke repair is launched in tmux so it survives shell disconnects:

```bash
cd /home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration
tmux new-session -d -s refreshed288_v4_laplace_repair_resume_20260430 \
  "cd /home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration && \
   OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 SMOKE_DYNAMIC_MCMC_WORKERS=3 \
   tools/merge_reports/LOCAL_refreshed288_launch_20260430_dynamic72_qdesn_comparable_laplace_repair_v4.sh smoke-repair \
   > reports/static_exal_tuning_20260430/refreshed288_dynamic72_v4_reboot_deferred_resume_20260430.log 2>&1"
```

## Monitoring Commands

```bash
tmux ls
tmux attach -t refreshed288_v4_laplace_repair_resume_20260430
tail -f reports/static_exal_tuning_20260430/refreshed288_dynamic72_v4_reboot_deferred_resume_20260430.log
tools/merge_reports/LOCAL_refreshed288_launch_20260430_dynamic72_qdesn_comparable_laplace_repair_v4.sh health-smoke
```

## Interpretation Rule

If rows `20`, `44`, and `68` finish and pass or materially improve, review the smoke health before launching the v4 full dynamic repair. If they still fail sampler-health gates, do not silently run the full grid; prepare a documented v5 overlay or decide how to report the exDQLM MCMC TT500 rows.
