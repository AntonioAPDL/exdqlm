# REPORT: QDESN Dynamic Effective-W300 Postdraw Deep-DESN RHS-Long MCMC Wave Setup And Launch

Date: 2026-04-10  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Record the branch-local setup, validation, and live launch of the next deep-DESN residual wave after
the completed `E`-wave reconciliation reduced the challenger fail surface to a tightly concentrated
long-horizon `rhs_ns` MCMC pocket.

This note makes the new rhs-long MCMC wave the current active source of truth for overnight
monitoring on the integration branch.

## 2) Entry State

Source evidence:

- completed prior wave:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- closeout and residual inventory:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave2_closeout_and_wave3_inventory_20260410.md`

Promotions carried forward into the working deep-DESN source:

- stage-local winners:
  - `E410_rhs_long_gausmix_guard320_balanced3200`
  - `E520_rhs_long_general_diag3400`
  - `E620_ridge_mid_diag3000`
- exact-root override:
  - `laplace tau=0.05 fit_size=5000 rhs_ns -> E530_rhs_long_general_guard320_burn3600`

Working source state entering this wave:

- `71 PASS`
- `59 WARN`
- `14 FAIL`
- `36 / 36` root execution `SUCCESS`
- `0 / 36` root execution `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

Residual concentration:

- all `14` remaining FAIL rows are `rhs_ns`, `fit_size=5000`, `mcmc`;
- family split:
  - `gausmix = 6`
  - `laplace = 3`
  - `normal = 5`

## 3) Wave Design

Validated plan:

- plan:
  - `docs/PLAN__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_20260410.md`
- manifest:
  - `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_manifest.yaml`
- wrappers:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`

Stage structure:

- `F1_rhs_long_gausmix_mcmc`
  - `3` roots / `6` target FAIL rows / `4` profiles
- `F2_rhs_long_laplace_exal`
  - `3` roots / `3` target FAIL rows / `4` profiles
- `F3_rhs_long_normal_lower_mcmc`
  - `2` roots / `4` target FAIL rows / `4` profiles
- `F4_rhs_long_normal_upper_exal`
  - `1` root / `1` target FAIL row / `3` profiles

Planned scope:

- `15` challenger profiles
- `35` root-campaigns
- `140` fit executions

## 4) Validation

Committed-state prepare-only validation:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163103__git-ceab523`
- preflight manifest:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163103__git-ceab523/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight_manifest.json`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163103__git-ceab523/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Validated source and stage sizing matched expectations:

- source baseline:
  - `144` fit rows
  - `14` FAIL rows
  - `9` fail roots
  - `0` root FAILs
  - `36` comparison-eligible-any roots
  - `27` comparison-eligible-full roots
- stage sizes:
  - `F1: 3 roots / 6 FAIL rows / 4 profiles`
  - `F2: 3 roots / 3 FAIL rows / 4 profiles`
  - `F3: 2 roots / 4 FAIL rows / 4 profiles`
  - `F4: 1 root / 1 FAIL row / 3 profiles`

## 5) Live Launch

Detached launch from committed state:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523`
- detached session:
  - `qdesn_dynxff_0410_163032`
- launcher metadata:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523/launch/launcher_session.json`
- launcher log:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-rhslongmcmc-20260410-163031__git-ceab523/launch/launcher_stdout.log`

Immediate live health snapshot:

- snapshot time:
  - `2026-04-10 16:30:47 EDT`
- runner stop reason:
  - `RUNNING`
- completed stages:
  - `0 / 4`
- completed profiles:
  - `0 / 15`
- current stage/profile:
  - `F1_rhs_long_gausmix_mcmc / F410_rhs_long_gausmix_guard320_recenter3600`
- detached session live:
  - `TRUE`
- root execution error files:
  - `0`

## 6) Operational Interpretation

This launch stays disciplined:

- it keeps the promoted deep-DESN source as the default;
- it does not reopen solved ridge or short-horizon neighborhoods;
- it spends new compute only on the remaining long-horizon `rhs_ns` MCMC debt;
- it preserves reproducibility with a committed-state manifest, committed-state wrappers, a
  committed-state preflight, and a detached committed-state run tag.

At launch time the branch was clean, space was healthy on `/home`, and there was no conflicting live
QDESN validation session.
