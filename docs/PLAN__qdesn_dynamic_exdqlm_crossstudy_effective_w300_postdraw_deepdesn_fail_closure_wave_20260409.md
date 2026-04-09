# PLAN: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Fail Closure Wave

Date: 2026-04-09  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Goal

Continue from the completed broad deep-DESN rerun and spend overnight compute **only** on the
remaining high-value scientific fail surface.

Objectives:

- reduce the current `69` fit FAIL rows;
- repair the `2` root-status FAILs;
- improve root comparison readiness beyond the current `30/36 any` and `5/36 full`;
- keep the current simple-DESN zero-FAIL pack authoritative until a local deep-DESN winner is
  clearly strong enough to promote.

## 2) Source State

Source campaign:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-full-20260408-211621__git-8527b4a`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation`

Current source state:

- `144` fit rows
- `27 PASS`
- `48 WARN`
- `69 FAIL`
- `34/36 SUCCESS`
- `2/36 FAIL`
- `30/36` comparison-eligible-any
- `5/36` comparison-eligible-full

Promotion rule for this wave:

- keep the completed deep-DESN broad run as the default source;
- do **not** promote fit-level-only local wins into the authoritative branch baseline;
- promote only challenger profiles that clearly beat the deep-DESN source on their full guard set.

No whole-root promotion is made **before** this wave:

- whole-root deep-DESN promotions against the current authoritative simple-DESN source:
  - `0`
- fit-level deep-DESN improvements observed but not promotable:
  - `18` rows on `11` roots
  - all in `rhs_ns / vb`

## 3) What Is Explicitly Out Of Scope

This wave intentionally does **not** do the following:

- no new broad full rerun;
- no search for a single global tuning recipe;
- no retuning of rows that are already clearly healthy;
- no alternative DESN architectures;
- no decomposition-input redesign;
- no re-testing of older simple-DESN schedules that were already weak or irrelevant to the current
  deep-DESN mechanisms.

## 4) Retained Search Space

The retained search space is organized around the four repeat mechanisms from the source closeout:

1. `ridge / vb / tau=0.05`
- deep-DESN ridge lower-tail VB stabilization

2. `ridge / tau=0.95`
- coupled deep-DESN ridge upper-tail VB + MCMC stabilization

3. `rhs_ns / mcmc / fit_size=500`
- deep-DESN short-horizon rhs_ns MCMC stabilization

4. `rhs_ns / fit_size=5000`
- deep-DESN long-horizon rhs_ns mixed stabilization

## 5) Profiles

### 5.1 Ridge Lower-Tail VB Profiles

- `D110_ridge_lower_vb320`
  - cheapest ridge lower-tail guard
- `D120_ridge_lower_vb384`
  - mid-intensity ridge lower-tail guard
- `D130_ridge_lower_vb448`
  - stronger long-horizon ridge lower-tail guard
- `D140_ridge_lower_vb512`
  - strongest retained ridge lower-tail guard

Why these are included:

- the lower-tail ridge debt is entirely VB-side;
- the fail reason is highly uniform;
- this is the cheapest place to learn whether the deep-DESN ridge lower-tail rows are simply
  under-budgeted in VB.

### 5.2 Ridge Upper-Tail Mixed Profiles

- `D210_ridge_upper_combo320_soft3000`
- `D220_ridge_upper_combo384_soft3200`
- `D230_ridge_upper_combo384_diag3200`
- `D240_ridge_upper_combo448_diag3400`
- `D250_ridge_upper_combo512_diag3400`

Why these are included:

- the upper-tail ridge debt is mixed:
  - widespread ridge VB core-tail FAILs
  - plus a small ridge MCMC diagnostic pocket
- this neighborhood already showed value in the earlier simple-DESN repair cycle, so the retained
  profiles extend that idea rather than starting a new generic search.

### 5.3 RHS Short-Horizon MCMC Profiles

- `D310_rhs_short_drift2600`
- `D320_rhs_short_narrow2800`
- `D330_rhs_short_balanced3000`
- `D340_rhs_short_diag3200`

Why these are included:

- every short-horizon rhs_ns MCMC row is failing under the current deep-DESN source;
- the corresponding VB rows are already usable, so changing VB here would waste compute;
- this stage is a clean warmup/geometry search only.

### 5.4 RHS Long-Horizon Mixed Profiles

- `D410_rhs_long_guard256_narrow3000`
- `D420_rhs_long_guard256_balanced3200`
- `D430_rhs_long_guard256_diag3200`
- `D440_rhs_long_guard320_burnheavy3400`
- `D450_rhs_long_guard320_diag3600`

Why these are included:

- the long-horizon rhs_ns band is the largest remaining cluster and contains both root FAILs;
- it mixes ordinary drift rows, missing-diagnostics rows, and a small `gausmix` VB tail pocket;
- the retained profiles therefore combine deeper rhs VB guards with progressively stronger long
  MCMC schedules.

## 6) Stage Program

Preflight-verified prepare-only run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010359__git-36c7c9e`
- preflight markdown:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010359__git-36c7c9e/launch/qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_preflight.md`

Verified stage plan:

| Stage | Roots | Source Target FAIL Rows | Profiles | Why |
| --- | ---: | ---: | ---: | --- |
| `D1_ridge_lower_tail_vb` | `6` | `12` | `4` | pure ridge lower-tail VB debt |
| `D2_ridge_upper_tail_mixed` | `6` | `16` | `5` | coupled ridge upper-tail VB + MCMC debt |
| `D3_rhs_short_mcmc` | `9` | `18` | `4` | pure rhs_ns short-horizon MCMC debt |
| `D4_rhs_long_mixed` | `9` | `22` | `5` | broad rhs_ns long-horizon mixed debt |

Total planned scope:

- challenger profiles:
  - `18`
- planned root-campaigns:
  - `135`
- planned fit executions:
  - `540`

Committed-state launch:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- detached session:
  - `qdesn_dynxff_0409_010421`
- launch report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_setup_and_launch_20260409.md`

## 7) Compute Design

Runtime controls:

- `default_workers = 6`
- `active_job_workers = 4`
- `hard_cap_workers = 6`

Approximate source-side stage cost:

| Stage | Roots | Median Source Root Runtime | Mean Source Root Runtime | Why It Matters |
| --- | ---: | ---: | ---: | --- |
| `D1` | `6` | `993.6s` | `1043.6s` | moderate ridge-VB-only repair stage |
| `D2` | `6` | `854.4s` | `956.8s` | moderate ridge mixed stage |
| `D3` | `9` | `499.3s` | `495.2s` | cheapest broad learning stage |
| `D4` | `9` | `1541.1s` | `1776.1s` | most expensive but highest-value residual stage |

Efficiency rationale:

- the cheaper `D3` and the moderate ridge stages create learning value early;
- the expensive `D4` stage is retained because it contains both current root FAILs and the largest
  remaining deep-DESN debt band;
- no stage touches rows outside the retained fail mechanisms.

## 8) Expected Promotion Logic

What we hope to promote from this wave:

- stage-local winners that:
  - eliminate or materially reduce target FAIL rows,
  - do not introduce new guard-set damage,
  - and improve root comparison eligibility relative to source.

What we are **not** planning to promote automatically:

- any broad global deep-DESN baseline,
- any fit-level-only local win that lacks whole-root guard-set strength,
- any challenger that clears the target row but worsens the surrounding guard set.

## 9) Checked-In Assets

Manifest:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave_manifest.yaml`

Wrappers:

- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave.R`

## 10) Recommendation

This wave is broad enough to learn meaningfully, but disciplined enough to remain compute-rational.

It should be launched from committed state if:

- the branch docs reference the completed deep-DESN source run correctly,
- the preflight above remains valid, and
- the branch is clean before launch.
