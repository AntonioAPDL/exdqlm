# Original288 Dynamic TT5000 Post-Fix Repair Execution

## Status

This note records the validation state for the fresh post-fix dynamic `TT5000`
repair rerun.

## Validation Checklist

Implemented and validated:

- package fixes synced into the validation checkout:
  - `R/utils.R`
  - `R/exdqlmISVB.R`
  - `R/exdqlmLDVB.R`
  - `R/exdqlmMCMC.R`
- targeted validation-package tests passed:
  - `test-dlm-df-smoother-regression.R`
  - `test-dynamic-dqlm-mcmc-regression.R`
  - `test-mcmc-dynamic-strict-parity.R`
  - `test-crps-helper-regression.R`
- rerun stack validation passed:
  - `bash -n` on launcher
  - prepare
  - `--prepare-only=1`
  - `--dry-run=1 --skip-prepare=1`

## Post-Fix Smoke Read

Representative isolated smoke was run through the validation runner stack.

Observed so far:

- `dynamic::gausmix::0p05::5000::default::dqlm::vb`
  - completed cleanly
  - `status = done`
  - `gate_overall = WARN`
  - runtime about `273s`
- representative MCMC rows stayed active for extended wall-clock time at full
  CPU without reproducing the old immediate startup failures
- the first smoke attempt exposed a separate metrics-layer hole:
  missing internal `CRPS` helper
- that helper was added and regression-tested, then the smoke was restarted

Interpretation:

- the old immediate singular/non-finite crash path is no longer the first
  failure mode we see in the validation runner
- the runner/package integration is materially healthier than the pre-fix state
- this is enough evidence to move into the fresh narrow rerun

## Launch Rule

Proceed with the fresh post-fix rerun instead of reviving the failed
`2026-04-14` output tree.

If new failures appear, treat them as post-fix rerun evidence, not as
continuations of the old lane.
