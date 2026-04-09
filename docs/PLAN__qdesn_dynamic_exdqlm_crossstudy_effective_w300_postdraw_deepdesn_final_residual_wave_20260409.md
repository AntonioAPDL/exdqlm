# PLAN: QDESN Dynamic Effective-W300 Postdraw Deep-DESN Final Residual Wave

Date: 2026-04-09  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Goal

Continue from the completed deep-DESN fail-closure wave, carry forward only the completed results
that clearly improved the deep-DESN challenger source, and spend one new overnight batch only on
the **remaining** high-value residual surface.

Objectives:

- reduce the current working deep-DESN residual from `23` fit FAIL rows and `1` root-status FAIL;
- close the long-horizon `rhs_ns` pocket at `fit_size = 5000`;
- repair the single uncovered ridge `mcmc_exal` diagnostics row;
- keep the branch-authoritative simple-DESN zero-FAIL comparison pack unchanged while this
  challenger residual wave runs.

## 2) Source State For This Wave

Source wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-fitfail-20260409-010419__git-36c7c9e`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave`
- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave1_closeout_and_wave2_inventory_20260409.md`

Promoted stage winners carried forward as the effective deep-DESN working source:

- `D1_ridge_lower_tail_vb -> D120_ridge_lower_vb384`
- `D2_ridge_upper_tail_mixed -> D250_ridge_upper_combo512_diag3400`
- `D3_rhs_short_mcmc -> D330_rhs_short_balanced3000`
- `D4_rhs_long_mixed -> SOURCE_BASELINE`

Exact-root promotions carried forward before new search:

- `gausmix tau=0.05 fit_size=500 rhs_ns -> D310_rhs_short_drift2600`
- `gausmix tau=0.05 fit_size=5000 ridge -> D140_ridge_lower_vb512`
- `laplace tau=0.05 fit_size=5000 ridge -> D140_ridge_lower_vb512`

Working deep-DESN challenger source entering this wave:

- `59 PASS`
- `62 WARN`
- `23 FAIL`
- `35/36 SUCCESS`
- `1/36 FAIL`
- `34/36` comparison-eligible-any
- `26/36` comparison-eligible-full

## 3) What Is Explicitly Out Of Scope

This wave intentionally does **not** do the following:

- no full `36`-root rerun;
- no rerun of solved `D1`, `D2`, or `D3` neighborhoods;
- no reuse of `D410_rhs_long_guard256_narrow3000`;
- no search for one generic deep-DESN rescue profile;
- no change to the shared deep-DESN architecture itself;
- no promotion of deep-DESN results into the authoritative branch baseline before the challenger
  residual surface is reevaluated.

## 4) Retained Search Space

The remaining search space is now tightly concentrated:

1. `rhs_ns`, `fit_size=5000`, `family=gausmix`
- `3` roots
- `10` FAIL rows
- includes the only remaining root-status FAIL
- mixed mechanism:
  - long-horizon MCMC drift
  - missing diagnostics
  - small surviving VB tail pocket

2. `rhs_ns`, `fit_size=5000`, `family in {laplace, normal}`
- `6` roots
- `12` FAIL rows
- mostly long-horizon MCMC drift
- no remaining root-status FAILs

3. uncovered ridge singleton
- `1` root
- `1` FAIL row
- exact case:
  - `normal tau=0.25 fit_size=500 ridge mcmc_exal`

## 5) Profiles

### 5.1 Gausmix Long-Horizon Mixed Profiles

- `E410_rhs_long_gausmix_guard320_balanced3200`
- `E420_rhs_long_gausmix_guard320_diag3400`
- `E430_rhs_long_gausmix_guard384_diag3600`
- `E440_rhs_long_gausmix_guard384_burn3800`
- `E450_rhs_long_gausmix_guard448_diag4000`

Why these are included:

- gausmix is the only remaining long-horizon rhs family with both:
  - the last root-status FAIL,
  - and surviving VB tail instability;
- `D410` already told us that narrow-first geometry is unsafe here;
- this retained set therefore moves toward:
  - stronger rhs VB guards,
  - safer balanced/diagnostic chains,
  - and heavier burn only after the safer balanced profiles.

### 5.2 Laplace/Normal Long-Horizon RHS MCMC Profiles

- `E510_rhs_long_general_balanced3200`
- `E520_rhs_long_general_diag3400`
- `E530_rhs_long_general_guard320_burn3600`
- `E540_rhs_long_general_guard320_diag3800`
- `E550_rhs_long_general_guard384_diag4000`

Why these are included:

- outside gausmix, the remaining long-horizon rhs debt is overwhelmingly MCMC drift rather than VB
  tail instability;
- this stage therefore emphasizes:
  - safer long chains,
  - stronger diagnostics,
  - and only moderate rhs VB strengthening.

### 5.3 Ridge Singleton Profiles

- `E610_ridge_mid_soft2800`
- `E620_ridge_mid_diag3000`
- `E630_ridge_mid_diag3200`
- `E640_ridge_mid_diag3400`

Why these are included:

- the uncovered ridge residual is just one short-horizon `mcmc_exal` diagnostics row;
- this is a poor target for a broad wave;
- the right continuation is a small singleton stage with progressively safer ridge MCMC
  diagnostics and **no** unnecessary VB perturbation.

## 6) Stage Program

Expected stage plan from the promoted deep-DESN working source:

| Stage | Roots | Source Target FAIL Rows | Profiles | Why |
| --- | ---: | ---: | ---: | --- |
| `E1_rhs_long_gausmix_mixed` | `3` | `10` | `5` | remaining gausmix long-horizon rhs pocket plus the only root-status FAIL |
| `E2_rhs_long_laplace_normal_mcmc` | `6` | `12` | `5` | remaining laplace/normal long-horizon rhs MCMC debt |
| `E3_ridge_mid_singleton_mcmc_exal` | `1` | `1` | `4` | uncovered short-horizon ridge diagnostics singleton |

Total planned scope:

- challenger profiles:
  - `14`
- planned root-campaigns:
  - `49`
- planned fit executions:
  - `196`

## 7) Compute Design

Runtime controls:

- `default_workers = 6`
- `active_job_workers = 4`
- `hard_cap_workers = 6`

Efficiency rationale:

- the long-horizon rhs pocket is still the dominant unresolved cost center, so it gets most of the
  retained budget;
- splitting the long-horizon rhs band into gausmix and laplace/normal stages increases learning
  value per unit of compute by allowing different local winners;
- the singleton ridge stage is intentionally tiny, because it is one diagnostics row rather than a
  broad family problem.

## 8) Expected Promotion Logic

What we want to promote from this wave:

- stage-local winners that:
  - reduce target FAIL rows versus the promoted working source,
  - do not reintroduce root-status FAILs,
  - and improve root comparison readiness.

What we are **not** planning to promote automatically:

- any new broad global deep-DESN baseline;
- any profile that clears one row but damages the guard set;
- any long-horizon rhs profile that repeats the `D410` failure pattern.

## 9) Checked-In Assets

Manifest:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave_manifest.yaml`

Wrappers:

- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave.R`

## 10) Recommendation

This wave is broad enough to learn across the true residual surface, but disciplined enough to stay
compute-rational.

It should be launched from committed state if:

- the source promotions above are encoded in the manifest,
- the prepare-only stage plan matches the expected `10 + 12 + 1` residual surface,
- and the branch remains clean before launch.
