# Original-288 Synced-Base Residual Repair Execution

Date: 2026-04-07

## Prelaunch Validation

Prepared residual manifest:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_20260407.csv`

Prepared residual fail inventory:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_fail_inventory_20260407.csv`

Prepared stage counts:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_stage_counts_20260407.csv`

Prelaunch evaluator outputs:

- `tools/merge_reports/LOCAL_original288_syncedbase_residual_manifest_status_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_phase_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_block_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_residual_accepted_compare_20260407.csv`

Validated prelaunch state:

- `84 / 84` residual rows prepared
- `0` missing inputs
- `0 / 84` complete before launch
- `84 / 84` pending before launch
- `bash -n` passed for launch / supervisor / monitor scripts
- launcher `--prepare-only=1` passed
- launcher `--dry-run=1 --skip-prepare=1` passed

Validated lane split:

- `54` static `al :: mcmc` bug-fix reruns
- `27` static `exal :: mcmc` exact replay reruns
- `3` dynamic `exdqlm :: mcmc` exact replay reruns

## Corrective Changes Included In This Launch

Included fixes:

1. accepted MCMC replay precedence now treats `NA` accepted values as missing
   rather than valid overrides
2. the faithful replay prepare path now materializes selected-fit-derived
   config fields and selected seeds correctly
3. residual prepare uses accepted reference fit paths directly for every
   rerun row
4. residual lane construction now includes runtime-invalid static `al` rows,
   not only completed unhealthy rows

## Launch Intent

This execution is intended to answer:

- how much of the faithful-replay residual queue disappears once the replay bug
  is fixed and the failed rows are rerun under corrected exact replay

It is not intended to reopen the unresolved accepted tail of `6` dynamic rows
yet.

## Live Launch Checkpoint

Launch sessions used:

- tmux supervisor:
  `original288-syncedbase-residual-repair-20260407`
- tmux monitor:
  `original288-syncedbase-residual-repair-monitor-20260407`

## Final Outcome

Residual repair completed with:

- `84 / 84` complete
- `55 PASS`
- `10 WARN`
- `19 FAIL`
- `65 / 84` healthy

Accepted-reference comparison:

- `60` matched accepted status
- `1` was better than accepted
- `23` were worse than accepted

Strict improvement promoted into accepted `v6`:

- `static_shrink::laplace::0p25::1000::rhs::exal::mcmc`
  - accepted:
    `WARN`
  - residual repair result:
    `PASS`

Accepted publication-target state after the promotion:

- `282 / 288` healthy
- `227 PASS`
- `55 WARN`
- `6 FAIL`

## Phase Results

| phase | rows | PASS | WARN | FAIL | healthy |
|---|---:|---:|---:|---:|---:|
| `phase1_static_al_mcmc_bugfix` | `54` | `52` | `2` | `0` | `54` |
| `phase2_static_exal_mcmc_exact` | `27` | `3` | `8` | `16` | `11` |
| `phase3_dynamic_exdqlm_mcmc_exact` | `3` | `0` | `0` | `3` | `0` |

## What Improved

1. the static `al :: mcmc` replay bug was confirmed and effectively repaired:
   `54 / 54` reruns are now non-`FAIL`
2. one strict static `exal :: mcmc` improvement was strong enough to promote
   into accepted `v6`
3. the remaining synced-base regression queue is now much smaller and more
   interpretable than the earlier `84`-row residual bundle

## What Still Fails

The remaining synced-base fail queue after this residual repair program is:

- `16` static `exal :: mcmc` rows
- `3` dynamic `exdqlm :: mcmc` rows

In addition, `4` rows remain non-failing but downgraded from accepted `PASS`
to current `WARN` and should be treated as stability-review cases.

## Which Ideas Worked Best

1. fixing the shared proposal-resolution replay bug before rerunning static
   `al :: mcmc`
2. replaying from accepted-reference fit paths
3. keeping original `static_shrink::rhs` rows on `rhs_ns`
4. separating runtime-invalid bugs from genuine mixing-quality failures

## Which Ideas Did Not Help

1. pure exact replay alone for the full static `exal :: mcmc` residual set
2. pure exact replay alone for the `3` dynamic `exdqlm :: mcmc` residual rows
3. reopening the unresolved accepted dynamic tail before clarifying the
   synced-base replay regressions

## Next Step

The next highest-value move is now a targeted follow-up lane, not another broad
rerun. That follow-up should:

1. target the `16` static `exal :: mcmc` fail rows with local same-scenario
   profiles
2. target the `3` dynamic `exdqlm :: mcmc` fail rows with exact-kernel
   longer-budget reruns
3. include the `4` PASS-to-WARN rows as a small stability-review lane
4. keep the accepted unresolved dynamic tail of `6` explicitly deferred

That next phase is documented in:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_targeted_followup_program_20260407.md`
