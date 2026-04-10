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

## Final Outcome

The repair wave has now completed.

Final wave outcome:

- total candidates: `38`
- healthy candidates: `15`
- unhealthy candidates: `23`
- gate split:
  - `5` `PASS`
  - `10` `WARN`
  - `23` `FAIL`

Comparison against the failed corrected rebuild baseline:

- `15 / 38` candidates improved on the failed rebuild
- `23 / 38` matched the failed rebuild
- `0 / 38` were worse than the failed rebuild

Comparison against the accepted branch at launch time:

- `1 / 38` candidate improved the accepted branch
- `6 / 38` matched the accepted branch
- `31 / 38` remained worse than the accepted branch

Accepted-promotion result after closeout:

- one accepted row was promoted from `WARN` to `PASS`
- accepted baseline advanced from `v7` to `v8`
- accepted health remained `282 / 288`, but the accepted `PASS/WARN` mix improved

Promoted accepted row:

- scenario:
  - `static_shrink::gausmix::0p25::100::rhs::exal::mcmc`
- repair row:
  - `row_0003`
- profile:
  - `crash_rw_none_f085_s1025_long`
- accepted gate change:
  - `WARN -> PASS`

Corrected rhs_ns working-branch result after promotion:

- `70 / 72` corrected `rhs_ns` rows are now healthy
- only `2` corrected rows remain unresolved:
  - `static_shrink::gausmix::0p25::1000::rhs_ns::exal::mcmc`
  - `static_shrink::normal::0p25::1000::rhs_ns::exal::mcmc`

Main technical read:

- what improved:
  - the crash-repair phase found a promotable local fix for the `gausmix / 0p25 / 100`
    row
  - the working corrected `rhs_ns` branch moved from `60 / 72` to `70 / 72`
  - the unresolved static shrinkage pocket shrank from `12` rows to `2`
- what still fails:
  - the two remaining failures are both `tt = 1000`, `tau = 0p25`,
    `rhs_ns / exal / mcmc`
- what worked best:
  - no-VB-init rw crash-removal probes near the documented historical anchors
  - separating crash removal from mixing repair
- what did not help:
  - broad reuse of the rebuild defaults on the hard `tt1000` rows
  - assuming the same corrected corridor would rescue both hard rows without
    deeper, row-specific exploration

Follow-on decision:

- promote the accepted branch to `v8`
- treat the corrected `rhs_ns` working branch as `70 / 72` healthy
- move next into a final-closure lane that targets only the remaining `2` rows
