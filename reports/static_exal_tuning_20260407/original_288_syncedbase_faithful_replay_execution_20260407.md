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

## Final Outcome

Final replay outcome:

- `282 / 282` complete
- `154 PASS`
- `44 WARN`
- `84 FAIL`
- `198 / 282` healthy

Accepted-reference comparison:

- `155` matched accepted status
- `31` were better than accepted
- `96` were worse than accepted

Improvement handling:

- all `31` strict improvements were promoted into accepted `v5`
- accepted publication-target status therefore remains:
  - `282 / 288` healthy
  - `6 / 288` unresolved
- but with a stronger accepted pass/warn composition than `v4`

## What Worked Best

- strict replay of accepted healthy rows only
- forcing original `static_shrink::rhs` rows to replay as `rhs_ns`
- using accepted-reference fit paths and accepted companion VB fit paths
- replay-precedence fixes for dynamic `proposal`, `joint_sample`, slice, and
  refresh controls
- stopping the earlier broad synced-base rerun and restarting from a cleaner
  reference-fidelity frame

## What Did Not Help

- the deprecated broad synced-base rerun from `2026-04-06`
- treating baseline-kept MCMC rows like fresh runs
- leaving `rhs` / `rhs_ns` policy implicit
- using the faithful replay itself as a generic residual search program

## Main Failure Pattern

The replay finished with a sharply structured residual failure queue:

- `54` static `al :: mcmc` rows failed at runtime with the same proposal
  resolution error
- `27` static `exal :: mcmc` rows completed but remained unhealthy
- `3` dynamic `exdqlm :: mcmc` rows completed but remained unhealthy

This means the next highest-value move is not a broad rerun. It is a targeted
residual repair program that separates:

1. static `al` replay bug-fix reruns
2. static `exal` exact accepted replay reruns
3. dynamic `exdqlm` exact accepted replay reruns

That next phase is documented in:

- `reports/static_exal_tuning_20260407/original_288_syncedbase_residual_repair_program_20260407.md`
