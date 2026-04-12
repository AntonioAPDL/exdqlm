# Original288 Exact-Spec Multi-Seed Relaunch Execution (0.4.0)

Date: `2026-04-12`

## Status

This note records the implementation, validation, and staged launch state for
the corrected exact-spec replay relaunch.

## Correctness Rule

This relaunch is valid only because it follows the required replay rule:

- keep each current corrected row on its exact prior accepted/selected spec
- preserve row-local kernel, proposal, adaptation, slice, refresh, init, and
  prior settings
- change only:
  - `n.burn = 5000`
  - `n.mcmc = 20000`
  - stored posterior draws `= 20000`
  - deterministic `4`-seed expansion and reduction

## Validation Checklist

Implementation validation completed:

- syntax/parse checks for:
  - `LOCAL_original288_exactspec_multiseed_helpers_20260412.R`
  - `LOCAL_original288_exactspec_multiseed_prepare_20260412.R`
  - `LOCAL_original288_exactspec_multiseed_run_row_20260412.R`
  - `LOCAL_original288_exactspec_multiseed_evaluate_20260412.R`
  - `LOCAL_original288_exactspec_multiseed_reduce_20260412.R`
  - `LOCAL_original288_exactspec_multiseed_refresh_comparison_20260412.R`
- `bash -n` for:
  - `LOCAL_original288_exactspec_multiseed_launch_20260412.sh`

Prepare validation completed:

- corrected selection rows: `288`
- smoke rows: `48`
- full rows: `1152`
- resolved rows: `288`
- resolution minimum score: `60`
- missing inputs after path hardening: `0`

Cross-path smoke validation:

- static `vb` representative row completed and wrote full artifacts
- static `mcmc` representative row completed and wrote full artifacts
- dynamic `vb` representative row completed and wrote full artifacts
- dynamic `mcmc` representative row:
  - launched cleanly under the exact replay budget
  - sustained long-running compute without an early runtime failure
  - was then superseded by the clean staged-launch prepare reset

Launcher validation completed:

- `bash tools/merge_reports/LOCAL_original288_exactspec_multiseed_launch_20260412.sh --prepare-only=1`
  passed
- `bash tools/merge_reports/LOCAL_original288_exactspec_multiseed_launch_20260412.sh --dry-run=1 --skip-prepare=1`
  passed

## Notes

The first prepare pass exposed two real implementation issues and both were
fixed before launch:

1. nested static source paths were incorrectly treated as missing when the
   original `sim_output.rds` was absent even though the input directory still
   existed
2. post-sort config rewriting collided with old config names and left manifest
   config paths partially stale

Both issues are fixed in the current exact-spec helper and the second prepare
pass completed with `0` missing inputs.

## Launch State

The implementation is validated and ready for staged tmux launch.

This section is updated again after the live exact-spec relaunch is started.
