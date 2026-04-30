# Dynamic 72 v4 Reboot Stop Handoff

## Executive Status

The active v4 targeted repair smoke was intentionally stopped because the server needs to reboot.

This is not a numerical crash and not a sampler-health conclusion. Rows `20`, `44`, and `68` were running under the v4 Laplace-RW repair overlay when the stop was requested. They have been marked as `failed_runtime` with the explicit reason `manual_stop_for_server_reboot_20260430` so future health checks do not mistake the interruption for an organic model failure.

## Current Branch State

| Item | Value |
| --- | --- |
| Worktree | `/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration` |
| Branch | `validation/rerun-after-0.4.0-sync-0p4p0-integration` |
| Last pushed base before this handoff work | `ae94893` |
| Active dynamic scenario | `dlm_constV_p90_m0amp_highnoise_steepertrend_v1` |
| Corrected source-index model origin | Implemented and preserved |
| Q-DESN window verification | `18/18 PASS` |

## What Happened Before The Reboot Stop

| Stage | Run Tag | Result | Interpretation |
| --- | --- | --- | --- |
| v2 source-index smoke | `20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin` | 24/24 dynamic smoke rows completed, no runtime crashes | Corrected time-origin fix worked operationally; TT5000 rows no longer stalled/stopped. |
| v2 sampler health | same | Rows `20`, `44`, `68` failed; rows `47`, `72` warned | Remaining issue is exDQLM MCMC sigma/gamma mixing, concentrated in `TT500` smoke rows. |
| v3 slice/warmup repair | `20260430_p90_dynamic72_qdesn_comparable_v3_repair` | Rows `20`, `44`, `68` completed without runtime crashes but all still failed | More burn-in + wider slice + theta/latent/sigmagam warmup was insufficient. |
| v4 Laplace-RW repair | `20260430_p90_dynamic72_qdesn_comparable_v4_laplace_repair` | Rows `20`, `44`, `68` were intentionally stopped after about `691` seconds | Server reboot stop only; no numerical conclusion from v4 yet. |

## v4 Repair Contract

| Setting | Value |
| --- | --- |
| Target rows | `dynamic + exdqlm + mcmc + TT500` |
| Smoke rows | `20`, `44`, `68` |
| Full manifest rows affected | `9` rows: all families x taus for `TT500 exdqlm mcmc` |
| MCMC burn-in | `10000` |
| Retained MCMC draws | `20000` |
| Proposal | `laplace_rw` |
| Joint sigma/gamma proposal | `TRUE` |
| Laplace refresh interval/start/weight | `10 / 50 / 0.9` |
| sigmagam freeze burn-in | `250` |
| theta freeze burn-in | `250` |
| latent freeze burn-in | `250` |
| latent mode | `u_st_pair` |
| Threading | `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1` |

## Rows Marked For Reboot Stop

| Row | Case | Status After Stop | Reason |
| ---: | --- | --- | --- |
| 20 | `dynamic::gausmix::0p50::500::default::exdqlm::mcmc` | `failed_runtime` | `manual_stop_for_server_reboot_20260430` |
| 44 | `dynamic::laplace::0p50::500::default::exdqlm::mcmc` | `failed_runtime` | `manual_stop_for_server_reboot_20260430` |
| 68 | `dynamic::normal::0p50::500::default::exdqlm::mcmc` | `failed_runtime` | `manual_stop_for_server_reboot_20260430` |

## Post-Reboot Restart

After reboot, resume with:

```bash
cd /home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration
git pull --ff-only
tools/merge_reports/LOCAL_refreshed288_launch_20260430_dynamic72_qdesn_comparable_laplace_repair_v4.sh health-smoke
tools/merge_reports/LOCAL_refreshed288_launch_20260430_dynamic72_qdesn_comparable_laplace_repair_v4.sh smoke-repair
```

The `smoke-repair` action force-runs only rows `20`, `44`, and `68` from the v4 smoke manifest, using three single-threaded workers by default.

## Full Dynamic Relaunch Gate

Do not launch the full dynamic 72 until the v4 targeted smoke repair is reviewed.

If v4 rows pass or are at least materially improved, the next command for the full dynamic-only launch is:

```bash
tools/merge_reports/LOCAL_refreshed288_launch_20260430_dynamic72_qdesn_comparable_laplace_repair_v4.sh full
```

If v4 rows still fail, do not silently launch full. Create a v5 overlay or decide whether the article table should retain exDQLM MCMC rows with explicit sampler-health warnings.

## Important Interpretation

The current `failed_runtime` entries for v4 are operational reboot-stop markers. They are not numerical failures. The latest true numerical/sampler-health evidence remains:

- v2: source-index smoke finished but rows `20`, `44`, and `68` failed sigma/gamma gates.
- v3: first repair completed but rows `20`, `44`, and `68` still failed sigma/gamma gates.
- v4: stronger Laplace-RW repair started but was interrupted for reboot before any health metrics could be produced.
