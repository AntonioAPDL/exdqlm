# Refreshed288 Storage Cleanup And Runtimefail Freeze

Generated: `2026-04-19 02:12:00 EDT`

## Purpose

This note freezes the interrupted `runtimefail_v1` rerun and records the storage cleanup performed before the next relaunch planning cycle.

The cleanup goal was:

1. stop the current crash-only rerun safely,
2. preserve the lightweight reproducibility artifacts,
3. remove only large generated fit/draw/init artifacts from old runs,
4. restore enough free disk space for the next instrumented relaunch.

## Current Run Freeze

The active crash-only rerun was stopped before cleanup:

- run tag: `refreshed288_paperaligned_20260418_runtimefail_v1`
- reason for freeze:
  - `0` rescued rows among terminal rows at freeze time
  - disk exhaustion had begun to corrupt run outputs
  - `/home` had reached `100%` usage and produced `No space left on device`

The run root remains present:

- `tools/merge_reports/full288_refreshed288_paperaligned_20260418_runtimefail_v1`

Preserved in that run root:

- `configs/`
- `rows/`
- `health/`
- `metrics/`
- `logs/`

Removed from that run root:

- `vb_init/`
- `fits/`
- `draws/`

## Cleanup Boundary

The cleanup intentionally removed only heavyweight generated artifacts:

- `fits/`
- `vb_init/`
- `draws/`

The following were preserved:

- manifests
- method registries
- configs
- row status CSVs
- health CSVs
- metrics CSVs
- logs
- reports and investigation notes

## Deleted Targets

### Refreshed288 runs

| path | size before deletion |
|---|---:|
| `tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1/fits` | `84,309,499,804` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1/vb_init` | `3,691,917,393` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1/draws` | `470,133,389` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260418_runtimefail_v1/vb_init` | `6,691,055,262` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260418_runtimefail_v1/fits` | `12,288` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260418_runtimefail_v1/draws` | `4,096` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260416/draws` | `155,465,265` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260416/fits` | `11,868,136` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260416/vb_init` | `12,288` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260417_bridge_pilot_v1/draws` | `23,819,602` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260417_bridge_pilot_v1/fits` | `2,085,489` bytes |
| `tools/merge_reports/full288_refreshed288_paperaligned_20260417_bridge_pilot_v1/vb_init` | `12,288` bytes |

### Older original288 generated artifacts

| path | size before deletion |
|---|---:|
| `tools/merge_reports/full288_original288_dynamic_tt5000_postfix_smoke_20260415/fits` | `100,060,147` bytes |
| `tools/merge_reports/full288_original288_dynamic_tt5000_postfix_smoke_20260415/draws` | `36,787` bytes |
| `tools/merge_reports/full288_original288_dynamic_tt5000_postfix_repair_20260415/draws` | `2,731,601` bytes |
| `tools/merge_reports/full288_original288_dynamic_tt5000_exactspec_repair_20260414/draws` | `4,096` bytes |
| `tools/merge_reports/full288_original288_exactspec_multiseed_relaunch_20260412/draws` | `4,096` bytes |

## Cleanup Result

| Metric | Value |
|---|---:|
| total deleted bytes | `95,458,722,027` |
| total deleted GiB | `88.90` |
| filesystem free space after cleanup | `89G` |
| filesystem usage after cleanup | `90%` |

## Post-Cleanup Readiness

After cleanup:

- the disk is healthy enough for a new controlled relaunch,
- the failed `runtimefail_v1` lane is frozen as diagnostic evidence,
- the canonical run keeps its lightweight reproducibility surface,
- future relaunch work should start from the preserved manifests, configs, rows, metrics, logs, and reports, not from the deleted heavy fit objects.

## Next Step

The next step should be a new relaunch plan built on:

1. the frozen canonical study documentation,
2. the frozen `runtimefail_v1` evidence,
3. the new exDQLM LDVB state-path instrumentation,
4. and the forthcoming `s`-latent freeze/warmup design the user requested for the next iteration.
