# PLAN: QDESN Dynamic Effective-W300 Final Residual Wave

Date: 2026-04-08  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Objective

Run one final, tightly targeted scientific closure wave starting from the promoted Wave 1 local
baseline and try to remove the last `4` long-horizon MCMC FAIL rows.

This wave is intentionally small and local:

- it does **not** reopen the repaired broad effective-w300 rerun,
- it does **not** rerun the already-clean short-horizon or ridge-VB bands,
- it does **not** search for one generic profile across the whole study.

## 2) Source Baseline For This Wave

Use:

- source mode:
  - `prior_fitfail_wave`
- source run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-fitfail-20260408-040402__git-8005f87`
- source report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave`

Meaning:

- the source automatically inherits the completed Wave 1 local baseline map,
- so the next wave begins from the promoted working validation source, not from the older repaired
  effective-w300 comparison pack.

Expected source state:

- `144` fit rows
- `4` FAIL rows
- `4` fail-carrying roots
- `36/36` comparison-eligible-any
- `32/36` comparison-eligible-full

## 3) Exclusion Rules

Do **not** spend compute on:

- `W1_ridge_lower_tail_short`
- `W2_ridge_lower_tail_long`
- `W3_ridge_upper_tail_short`
- `W5_rhs_short_exal_drift`
- `N920_rhs_long_guard192_narrow2400`
- pure ridge VB-only profiles for the residual ridge long stage

Reason:

- those areas are either already clean or clearly dominated by better completed candidates.

## 4) Stage Design

### Stage R1: Ridge Upper-Tail Long Final

Scope:

- guard roots:
  - `root__dynamic__dlm_constV_smallW__gausmix__tau_0p95__lasttt_5000__qdesn_ridge`
  - `root__dynamic__dlm_constV_smallW__laplace__tau_0p95__lasttt_5000__qdesn_ridge`
  - `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_5000__qdesn_ridge`
- targeted fail row:
  - `laplace / tau=0.95 / 5000 / ridge / mcmc / exal`

Why this stage exists:

- the ridge residual is now a single `mcmc_exal` drift row,
- the current best working local baseline is already `N750_ridge_tail_combo2200`,
- so the remaining value is in deeper / slightly softer ridge MCMC combo variants only.

Profiles:

| Profile | Why it is included |
|---|---|
| `R810_ridge_combo192_soft2600` | smallest clean extension of `N750`: same VB guard, deeper softer MCMC |
| `R820_ridge_combo224_soft2600` | tests whether a modestly stronger ridge VB guard still helps the last drift row without reopening old VB-only debt |
| `R830_ridge_combo224_soft2800` | deeper chain hedge if the residual row is still under-mixed |
| `R840_ridge_combo224_diag2600` | narrower / more diagnostic ridge MCMC geometry aimed directly at the Geweke failure |
| `R850_ridge_combo256_diag3000` | strongest ridge final hedge with deeper chain and strongest retained VB guard |

### Stage R2: RHS Long-Horizon MCMC Residual Final

Scope:

- guard roots:
  - `root__dynamic__dlm_constV_smallW__gausmix__tau_0p05__lasttt_5000__qdesn_rhs_ns`
  - `root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns`
  - `root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_rhs_ns`
  - `root__dynamic__dlm_constV_smallW__laplace__tau_0p95__lasttt_5000__qdesn_rhs_ns`
  - `root__dynamic__dlm_constV_smallW__normal__tau_0p25__lasttt_5000__qdesn_rhs_ns`
- targeted fail rows:
  - `gausmix / tau=0.05 / 5000 / rhs_ns / mcmc / exal`
  - `gausmix / tau=0.25 / 5000 / rhs_ns / mcmc / exal`
  - `laplace / tau=0.95 / 5000 / rhs_ns / mcmc / al`

Why this stage exists:

- the current working local baseline is already `N930_rhs_long_guard224_burnheavy2600`,
- the residual rhs debt is now MCMC-only,
- and the remaining rows split into:
  - two missing-diagnostics exAL rows,
  - one Geweke-drift AL row.

Profiles:

| Profile | Why it is included |
|---|---|
| `R910_rhs_long_guard224_narrow2800` | first clean extension of `N930`: deeper chain plus narrower transformed-block geometry |
| `R920_rhs_long_guard224_balanced3000` | balanced depth/geometry hedge if the residual pocket is partly under-mixed and partly geometric |
| `R930_rhs_long_guard224_diag3000` | stronger diagnostics-oriented rhs geometry for the missing-diagnostics rows |
| `R940_rhs_long_guard224_burnheavy3200` | longest same-neighborhood chain to test whether the remaining debt is still warmup-limited |
| `R950_rhs_long_guard256_diag3200` | strongest retained rhs hedge with one stronger VB guard plus deepest diagnostic chain |

## 5) Compute Budget

Expected scope:

- stages:
  - `2`
- challenger profiles:
  - `10`
- root-campaigns:
  - `40`
- fit rows:
  - `160`

Runtime stance:

- default workers:
  - `6`
- active job workers:
  - `4`
- hard cap:
  - `6`

Why this is efficient:

- compute is spent only on the `8` roots that still matter as targets or guards,
- no healthy short-horizon bands are rerun,
- no clearly weak prior neighborhoods are repeated.

## 6) Selection Rule

Per stage:

- primary metric:
  - `target_fit_fail_n`
- supporting reads:
  - total fit FAILs on the guard set
  - comparison-ready root counts
  - root-status failures

Promotion rule:

- promote only if a completed profile clearly improves on the current working local baseline for
  that stage;
- otherwise keep the Wave 1 promoted local baseline.

## 7) Reproducibility Requirements

Implementation requirements for this wave:

1. use the generic fit-fail closure machinery already on branch
2. express the new wave entirely through:
   - one manifest
   - one run wrapper
   - one launch wrapper
   - one healthcheck wrapper
3. validate with prepare-only before launching
4. record the launch and resulting source-of-truth update in the branch docs
5. keep the branch clean and pushed after each checkpoint

## 8) Success Criteria

Primary:

- reduce the current promoted source from `4` FAIL rows to as close to `0` as possible

Secondary:

- preserve `0` root execution FAILs
- preserve `36/36` comparison-eligible-any
- improve `32/36` comparison-eligible-full if possible

Decision threshold:

- if a profile only rotates the fail surface or worsens guard roots, do not promote it
- if a profile clears the targeted row(s) and keeps the guard set stable, promote it

## 9) Prepare-Only Check

Prepare-only has already passed for this plan.

Verified preflight:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162510__git-537a3cb`
- markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave/qdesn-dynamic-exdqlm-crossstudy-effectivew300-finalresid-20260408-162510__git-537a3cb/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Verified source baseline:

- `144` fit rows
- `4` FAIL rows
- `4` fail-carrying roots
- `36/36` comparison-eligible-any
- `32/36` comparison-eligible-full

Verified stage plan:

- `R1_ridge_upper_tail_long_final`:
  - `3` guard roots
  - `1` targeted FAIL row
  - `5` challenger profiles
- `R2_rhs_long_mcmc_residual_final`:
  - `5` guard roots
  - `3` targeted FAIL rows
  - `5` challenger profiles
