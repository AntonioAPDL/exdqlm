# QDESN Tau050 Relaunch Plan After Storage Cleanup

Date: 2026-04-19

## Current State

- Storage cleanup is complete.
- `/home` now has about `429G` free instead of `89G`.
- There is no active tmux validation launch left to stop.
- The latest broad `v3` matrix should not be treated as a clean scientific result because it was contaminated by storage exhaustion, and the `AL` side also hit a post-fit reference-compare merge failure.

Cleanup evidence is documented in [REPORT__qdesn_validation_storage_cleanup_20260419.md](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/docs/REPORT__qdesn_validation_storage_cleanup_20260419.md).

## Relaunch Principle

Do **not** relaunch immediately from the current code state. The next relaunch should happen only after the next code patch set is in place and tested.

## Required Patch Set Before Relaunch

### 1. Add latent `s` freeze / warmup

This is the next intended modeling change. The goal is to add an `s`-latent freeze schedule analogous to the current `u`-latent warmup logic so early and mid-burn instability is handled more coherently.

Primary files to modify:

- [R/exal_inference_config.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_inference_config.R)
- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)
- the next relaunch defaults YAML for the chosen rerun surface
- corresponding test files under [tests/testthat](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/tests/testthat)

### 2. Fix or gate the AL reference-compare merge path

The AL side has a distinct post-fit failure in the reference-compare writer. That should be fixed before we interpret any new AL rerun.

Primary file:

- [R/qdesn_dynamic_exdqlm_crossstudy.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_dynamic_exdqlm_crossstudy.R)

Focus area:

- `qdesn_dynamic_crossstudy_write_reference_compare()`
- the merge step that previously raised `fix.by(by.x, x): 'by' must specify uniquely valid columns`

### 3. Keep failed-fit persistence strong

The relaunch should continue to preserve root-level failure payloads cleanly so hard failures are diagnosable even when the run is interrupted.

Primary files:

- [R/exal_mcmc_fit.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/exal_mcmc_fit.R)
- [R/qdesn_mcmc_validation.R](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/R/qdesn_mcmc_validation.R)

## Recommended Relaunch Shape

Because the last broad matrix was contaminated, the next relaunch should be a **clean canary rerun first**, not another immediate broad residual wave.

### Stage 1. Clean canary

Rerun a compact canary after the `s`-freeze patch set lands:

- hardest `AL` cases
- hardest `EXAL` cases
- especially `gausmix` and `tau = 0.50`
- include at least one `normal` comparator case

Goal:

- separate genuine scientific behavior from the prior infrastructure contamination
- verify that AL is no longer failing in post-fit comparison/export

### Stage 2. Expand only if canary is clean

If the canary is scientifically interpretable and materially better:

- relaunch the remaining unresolved surface
- keep the run split by lane and arm so healthchecks remain readable

If the canary is still bad:

- stop before a full rerun
- investigate that smaller clean cohort rather than scaling a failing surface

## Operational Checklist

### Pre-launch

- [ ] Confirm `/home` free space remains above `300G`
- [ ] Confirm `tmux ls` is empty or only contains intentionally unrelated sessions
- [ ] Confirm the worktree is clean or intentionally documented
- [ ] Confirm the latent `s` freeze patch set is committed
- [ ] Confirm the AL reference-compare fix or gate is committed
- [ ] Run the targeted tests for the new controls and relaunch surface
- [ ] Run prepare-only for the chosen relaunch phases

### Launch

- [ ] Launch the clean canary first
- [ ] Record the run tags and tmux session names in a launch report
- [ ] Run an early healthcheck before scaling

### Post-launch

- [ ] If the canary is good, launch the remaining unresolved cohort
- [ ] If the canary is bad, stop expansion and do a focused postmortem
- [ ] After terminal completion, prune large forecast binaries again with [cleanup_qdesn_validation_storage.sh](/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/scripts/cleanup_qdesn_validation_storage.sh)

## Storage Guardrail

The new cleanup script should become part of the standard workflow:

- dry-run before large relaunches
- execute after terminal waves to keep the result surface slim
- preserve reports, manifests, and logs while pruning giant forecast binaries

That keeps future reruns reproducible without letting storage pressure silently distort the scientific read again.
