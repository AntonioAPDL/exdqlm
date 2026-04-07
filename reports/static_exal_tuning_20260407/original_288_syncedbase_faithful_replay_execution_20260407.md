# Original-288 Synced-Base Faithful Replay Execution

Date: 2026-04-07

## Prelaunch Closeout

The earlier synced-base rerun from `2026-04-06` was explicitly stopped and
deprecated before this relaunch.

Deprecated run:

- tag:
  `original288_syncedbase_rerun_20260406`
- final frozen checkpoint after stop:
  - `286 / 288` rows complete
  - `225 / 288` healthy
  - `61 / 288` fail

Reason for deprecation:

- MCMC replay fidelity was insufficient for scientific comparison against the
  accepted `282 / 288` reference state.

## Faithful Replay Validation

Prepared manifest:

- `tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_manifest_20260407.csv`

Validated stage counts:

- `tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_stage_counts_20260407.csv`

Prelaunch evaluator output:

- `tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_manifest_status_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_phase_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_block_summary_20260407.csv`
- `tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_accepted_compare_20260407.csv`

Validated prelaunch state:

- `282 / 282` rows prepared
- `0` missing inputs
- `0 / 282` complete before launch
- `282 / 282` pending before launch

## Key Fidelity Checks

Confirmed:

1. All original `static_shrink::rhs` rows replay as `rhs_ns`.
2. All MCMC rows have companion VB reference fit paths.
3. Accepted healthy replay excludes the unresolved dynamic tail of `6`.
4. Representative static MCMC rows recover accepted:
   - `laplace_rw`
   - gamma substeps
   - global eta jump settings
   - Laplace refresh settings
5. Representative dynamic MCMC rows recover accepted:
   - proposal family
   - `joint_sample`
   - slice width / max steps when applicable

Smoke-test findings before full launch:

- representative static `rhs -> rhs_ns` MCMC row:
  - completed successfully
  - returned `WARN`
- representative dynamic slice row:
  - no longer failed immediately in argument validation after replay-precedence
    fixes
  - smoke-test artifacts were cleared afterward so the full campaign can start
    from a clean replay state

## Launch Intent

This execution record is for the reference replay campaign only.

Its purpose is to answer:

- how much of the accepted healthy `282` state reproduces faithfully on the
  synced `0.4.0` base

It is not intended to solve the unresolved dynamic repair tail yet.
