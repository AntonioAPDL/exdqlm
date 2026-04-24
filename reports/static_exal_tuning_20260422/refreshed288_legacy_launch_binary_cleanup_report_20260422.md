# Legacy validation launch binary cleanup

Generated: `2026-04-22 20:34:27 EDT`

## Important correction

- Old validation launch roots in this repo are **not** storing `.rda` outputs in practice.
- They are overwhelmingly storing **`.rds` binary launch artifacts** such as run configs, fitted objects, VB-init objects, and draw bundles.
- The only `.rda` files currently present in the repo are package data files under `data/`, and they are **out of scope** for launch cleanup.

## Cleanup policy

- Protect the current active updated-0.4.0 relaunch root.
- Default cleanup scope: legacy `refreshed288` launch roots plus the `20260422` preflight root.
- Optional extended scope: older `original288` launch roots.
- Delete **binary launch artifacts only** (`.rds`, `.rda`, `.RData`) under legacy launch roots.
- Preserve CSV/log/txt audit material unless a later manual archive pass says otherwise.

## Inventory summary

- Launch-root `.rds` count found: `3216`
- Launch-root `.rda` / `.RData` count found: `0`
- Default refreshed288 cleanup scope: `0` binary files, `0.0 B` reclaimable
- Optional original288 extension: `2662` binary files, `3.9 MB` additional reclaimable

## Protected roots

| Root | Binary files | Binary size | Notes |
|---|---:|---:|---|
| `full288_refreshed288_20260422_p90_full288_baseline_v1` | `554` | `212.4 GB` | Current updated-0.4.0 p90 full relaunch root; never touch during cleanup. |

## Default cleanup candidates (`refreshed288` scope)

| Root | Binary files | Binary size | Configs | Fits | VB init | Draws | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| `full288_refreshed288_paperaligned_20260416` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260417_bridge_pilot_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260417_canonical_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260418_runtimefail_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260419_numcrash_stsfreeze_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260419_numcrash_thetafreeze_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260419_row8_cppprobe_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_paperaligned_20260420_exdqlm_tt5000_recovery_v1` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Legacy refreshed288 validation-study launch root from before the current p90 relaunch. |
| `full288_refreshed288_preflight_20260422` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Prelaunch preflight binaries for the current relaunch; safe candidate after readiness is established. |

## Optional extended cleanup candidates (`all_validation` adds these)

| Root | Binary files | Binary size | Configs | Fits | VB init | Draws | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| `full288_original288_dynamic_tt5000_exactspec_repair_20260414` | `144` | `189.2 KB` | `144` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_dynamic_tt5000_postfix_repair_20260415` | `384` | `351.3 KB` | `384` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_dynamic_tt5000_postfix_smoke_20260415` | `11` | `12.9 KB` | `11` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_exactspec_multiseed_relaunch_20260412` | `1200` | `2.0 MB` | `1200` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_static_shrink_rhsns_exal_mcmc_final_closure_20260410` | `18` | `28.0 KB` | `18` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_static_shrink_rhsns_exal_mcmc_gausmix_lastmile_20260410` | `28` | `43.8 KB` | `28` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_20260410` | `24` | `38.3 KB` | `24` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_static_shrink_rhsns_exal_mcmc_repair_20260410` | `38` | `56.8 KB` | `38` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_static_shrink_rhsns_rebuild_20260409` | `72` | `89.4 KB` | `72` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_dynamic_closure_20260407` | `12` | `11.4 KB` | `12` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_dynamic_final_closure_20260410` | `0` | `0.0 B` | `0` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_dynamic_restored_closure_20260410` | `36` | `287.1 KB` | `24` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_dynamic_tail6_localmix_20260408` | `6` | `5.8 KB` | `6` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_dynamic_tail6_refine_20260407` | `6` | `5.8 KB` | `6` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_faithful_replay_20260407` | `282` | `318.9 KB` | `282` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_rerun_20260406` | `288` | `351.5 KB` | `288` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_residual_repair_20260407` | `84` | `119.0 KB` | `84` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |
| `full288_original288_syncedbase_targeted_followup_20260407` | `29` | `44.4 KB` | `29` | `0` | `0` | `0` | Older original288 validation launch root; optional extended cleanup beyond refreshed288. |

## Usage

Inventory / dry-run:

```bash
Rscript scripts/manage_legacy_validation_launch_binaries_20260422.R --mode=inventory --scope=refreshed288
```

Execute default cleanup:

```bash
Rscript scripts/manage_legacy_validation_launch_binaries_20260422.R --mode=delete --scope=refreshed288 --execute=true
```

Execute default + original288 cleanup:

```bash
Rscript scripts/manage_legacy_validation_launch_binaries_20260422.R --mode=delete --scope=all_validation --execute=true
```

## Last delete summary

- Deleted files: `991`
- Reclaimed size: `41.7 GB`
