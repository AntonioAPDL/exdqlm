# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Final Residual Relaunch

Date: 2026-04-10  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the branch-local relaunch of the deep-DESN final residual wave after the first detached
launch hit a storage outage on `/home`.

This note preserves the first launch as historical evidence while making the newer relaunch the
current live source of truth for overnight monitoring.

Historical note:

- this relaunch is now completed;
- the completion closeout and next-step residual inventory now live in:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave2_closeout_and_wave3_inventory_20260410.md`

## 2) Why The Relaunch Was Needed

The first detached launch was:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-183058__git-26bdaad`
- detached session:
  - `qdesn_dynxff_0409_183058`

That launch did not fail because of the retained tuning plan. It was interrupted by a storage
blocker on `/home`:

- launcher log showed:
  - `No space left on device`
- the detached session later disappeared
- the final residual wave therefore needed a fresh committed-state relaunch after freeing space

The validated plan and manifest stayed the same:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_20260409.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_manifest.yaml`

## 3) Relaunch Metadata

Current live relaunch:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- detached session:
  - `qdesn_dynxff_0409_204957`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3/launch/launcher_stdout.log`

The relaunch continues from the same promoted deep-DESN working source:

- `59 PASS`
- `62 WARN`
- `23 FAIL`
- `35/36 SUCCESS`
- `1/36 FAIL`
- `34/36` comparison-eligible-any
- `26/36` comparison-eligible-full

## 4) Live Relaunch Health Snapshot

Snapshot:

- snapshot time:
  - `2026-04-10 02:24:00 EDT`
- runner stop reason:
  - `RUNNING`
- detached session live:
  - `TRUE`
- completed stages:
  - `1 / 3`
- completed profiles:
  - `5 / 14`
- current stage/profile:
  - `E2_rhs_long_laplace_normal_mcmc / E510_rhs_long_general_balanced3200`

Practical artifact state:

- completed profile campaign summaries:
  - `5 / 14`
- fit summaries on disk:
  - `66 / 196`
- MCMC chain summaries on disk:
  - `28 / 98`
- root error files:
  - `0`

Confirmed completed stage:

- stage:
  - `E1_rhs_long_gausmix_mixed`
- recommendation:
  - `PROMOTE_E410_rhs_long_gausmix_guard320_balanced3200_AS_E1_rhs_long_gausmix_mixed_LOCAL_BASELINE`

## 5) Operational Interpretation

The relaunch is now the correct live monitoring target for the deep-DESN final residual program.

Operationally this means:

- the retained residual-wave plan did survive the infrastructure restart;
- the current live run has already closed `E1` and moved into `E2`;
- the older `...183058__git-26bdaad` run should now be treated as historical launch evidence only,
  not the active overnight state.
