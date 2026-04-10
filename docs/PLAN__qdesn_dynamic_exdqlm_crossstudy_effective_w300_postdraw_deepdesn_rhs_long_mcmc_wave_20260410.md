# PLAN: QDESN Dynamic Effective-W300 Postdraw Deep-DESN RHS Long MCMC Wave

Date: 2026-04-10
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Goal

Continue from the completed deep-DESN final residual wave, promote the completed results that
already improved the challenger source, and spend one new overnight batch only on the **remaining**
long-horizon `rhs_ns` MCMC fail surface.

Objectives:

- reduce the working deep-DESN challenger from `14` fit FAIL rows to the smallest possible
  residual;
- keep root-status `FAIL = 0`;
- improve `comparison-eligible-full` beyond the current `27 / 36`;
- avoid re-running solved ridge, short-horizon, or VB-centered neighborhoods.

## 2) Source State For This Wave

Source wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-deepdesn-finalresid-20260409-204957__git-c116dc3`
- report root:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave`
- closeout report:
  - `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_wave2_closeout_and_wave3_inventory_20260410.md`

Completed stage winners carried forward automatically from the source wave:

- `E1_rhs_long_gausmix_mixed -> E410_rhs_long_gausmix_guard320_balanced3200`
- `E2_rhs_long_laplace_normal_mcmc -> E520_rhs_long_general_diag3400`
- `E3_ridge_mid_singleton_mcmc_exal -> E620_ridge_mid_diag3000`

Additional exact-root promotion carried forward before new search:

- `laplace tau=0.05 fit_size=5000 rhs_ns -> E530_rhs_long_general_guard320_burn3600`

Working deep-DESN challenger source entering this wave:

- `71 PASS`
- `59 WARN`
- `14 FAIL`
- `36 / 36` root `SUCCESS`
- `0 / 36` root `FAIL`
- `36 / 36` comparison-eligible-any
- `27 / 36` comparison-eligible-full

## 3) What Is Explicitly Out Of Scope

This wave intentionally does **not** do the following:

- no full `36`-root rerun;
- no ridge search;
- no short-horizon search;
- no VB-centered rescue search;
- no reuse of unchanged weak or redundant profiles:
  - `E420`, `E440`, `E450`,
  - `E540`, `E550`,
  - or the old unsafe `D410` narrow-first profile;
- no change to the deep-DESN architecture itself.

## 4) Residual Search Space

After the justified promotions, the remaining search surface is:

1. `gausmix`, `rhs_ns`, `fit_size = 5000`, `method = mcmc`
- `3` roots
- `6` FAIL rows
- all long-horizon rhs MCMC

2. `laplace`, `rhs_ns`, `fit_size = 5000`, `method = mcmc`
- `3` roots
- `3` FAIL rows
- now entirely `exal`

3. `normal`, `rhs_ns`, `fit_size = 5000`, `method = mcmc`, `tau in {0.05, 0.25}`
- `2` roots
- `4` FAIL rows

4. `normal`, `rhs_ns`, `fit_size = 5000`, `method = mcmc`, `tau = 0.95`
- `1` root
- `1` FAIL row

## 5) Candidate Profiles

### 5.1 Gausmix Profiles

- `F410_rhs_long_gausmix_guard320_recenter3600`
- `F420_rhs_long_gausmix_guard320_burndiag3600`
- `F430_rhs_long_gausmix_guard384_recenter4000`
- `F440_rhs_long_gausmix_guard384_diag4200`

Why these are included:

- the entire retained gausmix ladder in the completed wave tied at the same target FAIL count;
- the next high-value move is therefore to change **geometry**, not just reuse the same guard/depth
  ladder;
- these profiles test recentered slice widths, burn-plus-diagnostics hybrids, and deeper
  transformed block passes.

### 5.2 Laplace Profiles

- `F510_rhs_long_laplace_guard256_recenter3600`
- `F520_rhs_long_laplace_guard320_burndiag3600`
- `F530_rhs_long_laplace_guard320_recenter4000`
- `F540_rhs_long_laplace_guard384_diag4200`

Why these are included:

- after the `E530` exact-root promotion, the remaining laplace debt is now entirely `mcmc_exal`;
- this stage therefore emphasizes exAL-friendly diagnostics and burn geometry, not broad family
  guard escalation.

### 5.3 Normal Lower-Tau Profiles

- `F610_rhs_long_normal_lower_guard256_recenter3600`
- `F620_rhs_long_normal_lower_guard256_burndiag3600`
- `F630_rhs_long_normal_lower_guard320_recenter4000`
- `F640_rhs_long_normal_lower_guard384_diag4200`

Why these are included:

- the completed-wave evidence already separates the lower-tau normal roots from the upper-tau root;
- these profiles keep the search local to the `tau in {0.05, 0.25}` band rather than forcing one
  blended solution across all normal roots.

### 5.4 Normal Upper-Tau Profiles

- `F710_rhs_long_normal_upper_guard256_burndiag3600`
- `F720_rhs_long_normal_upper_guard320_recenter4000`
- `F730_rhs_long_normal_upper_guard384_diag4200`

Why these are included:

- only one upper-tail normal residual remains;
- a tiny stage is enough here;
- this keeps the search compute-efficient while still allowing a different local winner if
  `tau = 0.95` really behaves differently.

## 6) Stage Program

Expected stage plan from the promoted working source:

| Stage | Roots | Source Target FAIL Rows | Profiles | Why |
| --- | ---: | ---: | ---: | --- |
| `F1_rhs_long_gausmix_mcmc` | `3` | `6` | `4` | remaining gausmix long-horizon rhs MCMC pocket |
| `F2_rhs_long_laplace_exal` | `3` | `3` | `4` | remaining laplace long-horizon rhs exAL pocket |
| `F3_rhs_long_normal_lower_mcmc` | `2` | `4` | `4` | remaining normal lower-tau long-horizon rhs MCMC pocket |
| `F4_rhs_long_normal_upper_exal` | `1` | `1` | `3` | remaining normal upper-tail singleton |

Total planned scope:

- challenger profiles:
  - `15`
- planned root-campaigns:
  - `35`
- planned fit executions:
  - `140`

## 7) Compute Design

Runtime controls:

- `default_workers = 6`
- `active_job_workers = 4`
- `hard_cap_workers = 6`

Efficiency rationale:

- the residual is now only `9` roots, so the new wave should be materially smaller than the prior
  residual batch;
- family-splitting increases learning value per unit of compute;
- the normal band is split because the completed evidence already shows different local-best
  behavior between lower and upper tau.

## 8) Promotion Logic

What we want to promote from this wave:

- stage-local winners that reduce target FAIL rows versus the new promoted source;
- exact-root overrides only when they reduce root-level FAIL count without root-status damage;
- improvements that raise comparison readiness, not just raw fit counts.

What we do **not** want to promote automatically:

- any profile that only matches the existing residual without improving it;
- any profile that trades fewer FAIL rows for new root-status FAILs;
- any profile that is just a re-run of already weak or redundant shapes.

## 9) Checked-In Assets

Manifest:

- `config/validation/qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_manifest.yaml`

Wrappers:

- runner:
  - `scripts/run_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
- launcher:
  - `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`
- healthcheck:
  - `scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave.R`

## 10) Recommendation

This is the right next batch if we want targeted progress rather than brute-force breadth.

Launch it from committed state if:

- the promoted source above is encoded in the manifest,
- prepare-only validates the expected `6 + 3 + 4 + 1` residual split,
- and the branch remains clean before launch.
