# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Fail Closure Setup And Launch

Date: 2026-04-09  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the committed-state setup, prepare-only validation, and detached overnight launch for the
targeted deep-DESN fail-closure wave.

This wave starts from the completed broad deep-DESN challenger source:

- source run:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a`
- source state:
  - `27 PASS`
  - `48 WARN`
  - `69 FAIL`
  - `34/36 SUCCESS`
  - `2/36 FAIL`
  - `30/36` comparison-eligible-any
  - `5/36` comparison-eligible-full

## 2) Checked-In Assets

- fail-surface report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_deepdesn_closeout_and_fail_surface_20260409.md`
- wave plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_20260409.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`

Setup commit:

- `36c7c9e`
  - `validation: add deepdesn fail closure wave`

## 3) Committed-State Prepare-Only Validation

Prepare-only run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010359__git-36c7c9e`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010359__git-36c7c9e/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Verified preflight scope:

- source fail rows:
  - `69`
- source fail roots:
  - `31`
- source root FAILs:
  - `2`
- stage sizes:
  - `D1: 6 roots / 12 target FAIL rows / 4 profiles`
  - `D2: 6 roots / 16 target FAIL rows / 5 profiles`
  - `D3: 9 roots / 18 target FAIL rows / 4 profiles`
  - `D4: 9 roots / 22 target FAIL rows / 5 profiles`
- total challenger profiles:
  - `18`
- planned root-campaigns:
  - `135`
- planned fit executions:
  - `540`

Interpretation:

- the retained search space is focused, stageable, and aligned with the actual deep-DESN fail
  surface;
- no whole-root promotion is made before this localized repair wave;
- the simple-DESN effective-w300 zero-FAIL comparison pack remains authoritative while this
  challenger repair wave runs.

## 4) Detached Overnight Launch

Live run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- detached session:
  - `qdesn_dynxff_0409_010421`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e/launch/launcher_stdout.log`

Immediate launch health snapshot:

- snapshot time:
  - `2026-04-09 01:07:45`
- runner stop reason:
  - `RUNNING`
- current stage:
  - `D1_ridge_lower_tail_vb`
- current profile:
  - `D110_ridge_lower_vb320`
- completed stages:
  - `0 / 4`
- completed profiles:
  - `0 / 18`
- stage status rows:
  - `0`
- local baseline rows:
  - `0`
- detached session live:
  - `TRUE`

## 5) Operational Read

The launcher, worker processes, and detached session are all live. The run is in the very first
stage/profile, so it is normal that no stage-summary tables or local baseline rows exist yet.

At this point:

- the branch-local documentation reflects the committed-state prepare-only validation;
- the live deep-DESN fail-closure wave is running from checked-in code;
- the branch can continue to use the effective-w300 simple-DESN zero-FAIL pack as the authoritative
  comparison baseline until repair-wave results are ready for promotion review.
