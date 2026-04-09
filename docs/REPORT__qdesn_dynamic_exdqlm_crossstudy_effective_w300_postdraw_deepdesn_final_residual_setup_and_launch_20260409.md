# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Final Residual Setup And Launch

Date: 2026-04-09  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the committed-state setup, prepare-only validation, and detached overnight launch for the
final residual deep-DESN repair wave.

This wave starts from the promoted **working deep-DESN challenger source** defined in:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave1_closeout_and_wave2_inventory_20260409.md`

Working source entering this wave:

- `59 PASS`
- `62 WARN`
- `23 FAIL`
- `35/36 SUCCESS`
- `1/36 FAIL`
- `34/36` comparison-eligible-any
- `26/36` comparison-eligible-full

## 2) Checked-In Assets

- closeout/inventory report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave1_closeout_and_wave2_inventory_20260409.md`
- final residual plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_20260409.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_manifest.yaml`
- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`

Setup commit:

- `26bdaad`
  - `validation: add deepdesn final residual wave`

## 3) Committed-State Prepare-Only Validation

Prepare-only run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-preflight`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-preflight/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Verified preflight scope:

- source fail rows:
  - `23`
- source fail roots:
  - `10`
- source root FAILs:
  - `1`
- source compare-any:
  - `34/36`
- source compare-full:
  - `26/36`
- verified stage sizes:
  - `E1: 3 roots / 10 target FAIL rows / 5 profiles`
  - `E2: 6 roots / 12 target FAIL rows / 5 profiles`
  - `E3: 1 root / 1 target FAIL row / 4 profiles`
- total challenger profiles:
  - `14`
- planned root-campaigns:
  - `49`
- planned fit executions:
  - `196`

Interpretation:

- the promoted deep-DESN working source is being read correctly from the prior wave plus exact-root
  overrides;
- the residual surface is now exactly the intended `10 + 12 + 1` split;
- the next overnight batch touches only the unresolved long-horizon rhs pocket and the one
  uncovered ridge diagnostics singleton.

## 4) Detached Overnight Launch

Live run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-183058__git-26bdaad`
- detached session:
  - `qdesn_dynxff_0409_183058`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-183058__git-26bdaad/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-183058__git-26bdaad/launch/launcher_stdout.log`

Immediate launch health snapshot:

- snapshot time:
  - `2026-04-09 18:31:09 EDT`
- runner stop reason:
  - `RUNNING`
- current stage:
  - `E1_rhs_long_gausmix_mixed`
- current profile:
  - `E410_rhs_long_gausmix_guard320_balanced3200`
- completed stages:
  - `0 / 3`
- completed profiles:
  - `0 / 14`
- detached session live:
  - `TRUE`

## 5) Operational Read

The new residual wave is live from committed state and has started in the highest-value remaining
gausmix long-horizon rhs pocket.

Operationally this means:

- the branch-local source has already carried forward all currently justified deep-DESN promotions;
- the overnight compute is now focused only on the unresolved residual surface;
- the authoritative simple-DESN zero-FAIL effective-w300 comparison pack remains unchanged while
  this challenger residual wave runs.
