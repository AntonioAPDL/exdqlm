# Original-288 Static Shrink RHS_NS exAL MCMC Repair Execution

Date: `2026-04-10`

## Purpose

This wave continues from the corrected `static_shrink_rhsns_rebuild_20260409`
branch state and targets only the remaining unresolved rows:

- `12` rows
- all in `static_shrink / rhs_ns / exal / mcmc`

Accepted-baseline decision before launch:

- accepted `v7` stays unchanged before this run
- no completed result is promoted yet because the corrected `rhs_ns` branch is
  still incomplete

## Validation Checklist

- prepare row count: `38`
- missing inputs: `0`
- `bash -n`: `passed`
- `--prepare-only`: `passed`
- `--dry-run`: `passed`

Smoke validation before full launch:

- row `1` / base row `42`
  - scenario: `gausmix / 0p25 / 100`
  - profile: `crash_rw_none_f0825_s100`
  - result: `WARN`
  - read: healthy, matches the accepted legacy gate, and improves the failed
    corrected rebuild row
- row `21` / base row `38`
  - scenario: `gausmix / 0p05 / 100`
  - profile: `mix_rw_refresh_f080_s105`
  - result: `WARN`
  - read: healthy, improves the failed corrected rebuild row, but is still
    weaker than the accepted legacy `PASS`

## Launch State

- commit: `9bf5c79`
- branch: `validation/rerun-after-0.4.0-sync-0p4p0-integration`
- supervisor session:
  - `original288-static-shrink-rhsns-exal-mcmc-repair-20260410`
- monitor session:
  - `original288-static-shrink-rhsns-exal-mcmc-repair-monitor-20260410`
- startup summary:
  - launch mode: full overnight run
  - worker cap: `4` MCMC workers
  - active phase at startup:
    `phase1_static_shrink_rhsns_exal_mcmc_crash_repair`
  - prelaunch summary: `0 / 38` done
  - immediate live-process read after launch: `5` tagged row-runner processes
    visible on the host
