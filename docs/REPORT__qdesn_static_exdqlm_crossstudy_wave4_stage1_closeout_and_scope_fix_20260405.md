# REPORT: QDESN Static exdqlm Cross-Study Wave 4 Stage-1 Closeout And Scope Fix

Date: 2026-04-05  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Outcome

Wave 4 produced one valid completed result before it had to be corrected:

- `G530_ridge_tt100_drift_guard_chain1300` won
  `S1_ridge_tt100_residual_drift`
- that Stage-1 result is valid and should be promoted
- the later Wave-4 long-horizon stages are **not** valid for promotion because a prior-scope
  selector bug contaminated their root sets

## 2) What Improved

Stage-1 corrected the last short-horizon ridge residual slice.

Source promoted-map state on the Stage-1 target set:

- target fit FAIL rows: `3`
- target fail roots: `3`
- compare-full roots: `0 / 3`

Completed Stage-1 ranking:

| profile_id | target_fit_fail_n | target_root_fail_n | root_n_compare_full | fit_n_fail | read |
| --- | ---: | ---: | ---: | ---: | --- |
| `G530_ridge_tt100_drift_guard_chain1300` | `0` | `0` | `3 / 3` | `0` | clear winner |
| `G520_ridge_tt100_drift_guard` | `1` | `1` | `2 / 3` | `1` | improved but not best |
| `G510_ridge_local_baseline` | `2` | `2` | `1 / 3` | `2` | weaker control |

Main Stage-1 lesson:

- the tighter drift guard plus modest keep-length inflation worked cleanly on the
  ridge `tt=100` residuals
- the stronger short-horizon ridge geometry clue is now `G530`, not `F510/G510`

## 3) Updated Residual Debt After Stage 1

After overlaying `G530` on top of the promoted Wave-3 baseline map:

- promoted residual fit FAIL rows: `42`
- promoted residual fail roots: `38`
- `42 / 42` remaining FAIL rows are `mcmc`
- `38 / 42` are `exal`
- `4 / 42` are `al`

What remains open:

- ridge `tt=1000` residual ESS/autocorrelation debt:
  - `12` fail rows
  - `12` roots
- rhs `tt=100` residual MCMC drift debt:
  - `15` fail rows
  - `12` roots
- rhs `tt=1000` residual MCMC ESS/autocorrelation debt:
  - `15` fail rows
  - `14` roots
- unresolved original Wave-1 hard-root FAIL band:
  - `6` roots total
  - `3` ridge
  - `3` rhs_ns

## 4) Scope Bug

The Wave-4 long-horizon stages were defined to carry only the hard-root FAIL triad for their own
prior family.

What the run actually did:

- `S2_ridge_tt1000_residual_ess_plus_hardroots` carried both the `ridge` and `rhs_ns` hard-root
  FAIL triads
- `S4_rhs_tt1000_residual_mcmc_plus_hardroots` also carried both priors

Root cause:

- `.qdesn_static_crossstudy_residual_match_selector()` matched `prior`, but the
  `source_root_status_fail_grid.csv` table stores the prior under `beta_prior_type`
- when the selector requested `prior = ridge` or `prior = rhs_ns`, the filter was silently skipped
  on that table and both prior families were retained

Why this matters:

- the Wave-4 Stage-2 and Stage-4 scopes were wider than intended
- long-horizon stage sizes `18` and `20` were inflated by the cross-prior carry-forward
- those long-horizon results should not be promoted as scenario-local winners

## 5) What Still Holds

Even after the scope fix, these results are still valid:

- shared default:
  - `F500_anchor_patched`
- ridge `tt=100` local baseline:
  - `G530_ridge_tt100_drift_guard_chain1300`
- rhs `tt=100` local baseline:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000` local baseline:
  - `F640_rhs_tt1000_chain1200`

Ideas that clearly did not help:

- broad relaunch of the whole 72-root surface
- generic “one profile for everything” search
- short-horizon ridge control replay without tighter geometry
- chain-only rhs replays
- geometry-only long-horizon rhs replay

## 6) Corrected Next Move

The correct continuation is:

1. keep the valid Stage-1 `G530` promotion;
2. stop the contaminated Wave-4 long-horizon continuation;
3. fix the selector aliasing bug;
4. relaunch only the remaining properly-scoped slices:
   - ridge `tt=1000` residual ESS + ridge hard roots
   - rhs `tt=100` residual MCMC
   - rhs `tt=1000` residual MCMC + rhs hard roots

That corrected follow-on becomes Wave 5.

## 7) Key Evidence

- Stage-1 selection summary:
  - `reports/qdesn_mcmc_validation/static_exdqlm_crossstudy_residual_mcmc_closure_wave/qdesn-static-exdqlm-crossstudy-residualmcmc-20260405d__git-60e8079/stages/S1_ridge_tt100_residual_drift/summary/stage_candidate_selection.md`
- Stage-1 profile metrics:
  - `reports/qdesn_mcmc_validation/static_exdqlm_crossstudy_residual_mcmc_closure_wave/qdesn-static-exdqlm-crossstudy-residualmcmc-20260405d__git-60e8079/stages/S1_ridge_tt100_residual_drift/tables/profile_metrics.csv`
- Current Wave-4 stage root ids showing the contaminated long-horizon scope:
  - `reports/qdesn_mcmc_validation/static_exdqlm_crossstudy_residual_mcmc_closure_wave/qdesn-static-exdqlm-crossstudy-residualmcmc-20260405d__git-60e8079/stages/S2_ridge_tt1000_residual_ess_plus_hardroots/tables/stage_root_ids.csv`
  - `reports/qdesn_mcmc_validation/static_exdqlm_crossstudy_residual_mcmc_closure_wave/qdesn-static-exdqlm-crossstudy-residualmcmc-20260405d__git-60e8079/stages/S4_rhs_tt1000_residual_mcmc_plus_hardroots/tables/stage_root_ids.csv`
