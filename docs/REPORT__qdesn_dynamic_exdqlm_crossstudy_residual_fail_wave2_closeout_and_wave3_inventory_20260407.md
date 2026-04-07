# REPORT: QDESN Dynamic exdqlm Cross-Study Residual Fail Wave 2 Closeout and Wave 3 Inventory

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Executive Read

The second residual closure wave completed cleanly and produced the strongest validation-state
improvement so far on this branch.

Completed wave:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2`
- source baseline:
  - `qdesn-dynamic-exdqlm-crossstudy-fitfail-20260407-000615__git-54c5009`
- source mode:
  - `prior_fitfail_wave`
- execution:
  - `5/5` stages complete
  - `16/16` challenger profiles complete
  - `56/56` root-campaigns executed

Main decision:

- promote all `5` residual-stage winners into the new effective local baseline map
- treat the new merged state as the active validation baseline for the next overnight wave
- focus only on the final `2` remaining fit-level FAIL rows on `2` roots

## 2) What Improved

Wave-2 promoted winners:

| Residual Stage | Selected Winner | Source FAIL Rows | Winner FAIL Rows | Source FAIL Roots | Winner FAIL Roots |
|---|---|---:|---:|---:|---:|
| `R1_gausmix_tt5000_residual` | `L640_gmix_long_split_diag` | `9` | `0` | `5` | `0` |
| `R2_gausmix_tt500_residual` | `L670_gmix_short_diag_mix` | `5` | `0` | `3` | `0` |
| `R3_ridge_tt5000_singleton_residual` | `L720_ridge_long_softgamma_plus` | `2` | `0` | `1` | `0` |
| `R4_rhs_tt5000_residual` | `L760_rhs_long_vbguard_deep` | `6` | `1` | `4` | `1` |
| `R5_short_horizon_mixed_residual` | `L770_short_mixed_local_mcmc` | `4` | `1` | `4` | `1` |

Net effect of the promoted merged local baseline map:

- prior merged source fail rows:
  - `26`
- current merged fail rows:
  - `2`
- improvement:
  - `-24` rows (`-92.3%`)
- prior merged fail roots:
  - `17`
- current merged fail roots:
  - `2`
- improvement:
  - `-15` roots (`-88.2%`)
- prior merged root-status FAILs:
  - `2`
- current merged root-status FAILs:
  - `0`
- prior merged comparison-eligible-any roots:
  - `16 / 17`
- current merged comparison-eligible-any roots:
  - `17 / 17`
- prior merged comparison-eligible-full roots:
  - `0 / 17`
- current merged comparison-eligible-full roots:
  - `15 / 17`

## 3) What Still Fails

Only `2` fit-level FAIL rows remain in the full dynamic mirrored study, and both are now localized
to rhs-specific `mcmc_exal` rows:

| Remaining Root | Remaining FAIL Row | Signoff Reason | Current Winning Local Profile |
|---|---|---|---|
| `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift; half_chain_drift` | `L760_rhs_long_vbguard_deep` |
| `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift` | `L770_short_mixed_local_mcmc` |

Current residual inventory:

- fit FAIL rows:
  - `2 / 144`
- fail-carrying roots:
  - `2 / 36`
- root-status FAIL roots:
  - `0 / 36`

No outright broken runs remain.

## 4) Which Ideas Worked Best

Best-performing directions from Wave 2:

- `L640_gmix_long_split_diag`
  - fully cleared the long-horizon gausmix residual pocket
  - removed both remaining gausmix root-status failures
- `L670_gmix_short_diag_mix`
  - fully cleared the short-horizon gausmix residual pocket
- `L720_ridge_long_softgamma_plus`
  - fully cleared the singleton long-horizon ridge residual
- `L760_rhs_long_vbguard_deep`
  - strongest long-horizon rhs-specific rescue
  - reduced the rhs long pocket from `6` fail rows to `1`
- `L770_short_mixed_local_mcmc`
  - strongest short-horizon mixed-tail rescue
  - reduced that pocket from `4` fail rows to `1`

Interpretation:

- local tuning is still the right strategy
- the last unresolved issues are no longer broad family-level problems
- the remaining pain is specifically rhs-side `mcmc_exal` drift on `normal`
- both surviving misses sit inside the same local rhs neighborhood, so the final search should stay
  rhs-specific and mcmc-specific

## 5) Which Ideas Did Not Help

Dominated or lower-value directions from Wave 2:

- `R4_rhs_tt5000_residual`
  - `L740_rhs_long_vbguard_local`
    - improved the source, but left `4` fail rows
  - `L750_rhs_long_vbguard_mid`
    - better than `L740`, but still left `3` fail rows
  - both are now dominated by `L760`
- `R5_short_horizon_mixed_residual`
  - `L780_short_mixed_mid_mcmc`
    - failed to improve the source on the primary metric
  - `L790_short_mixed_softgamma_plus`
    - improved the source, but still underperformed `L770`

Low-value directions to exclude from the next wave:

- rerunning `L740`, `L750`, `L780`, or `L790`
- reopening the cleared gausmix pockets
- reopening the cleared ridge singleton
- any new generic search over all priors, families, or horizons

## 6) Promotion Decision

Promotions adopted from Wave 2:

| Residual Stage | Promoted Local Baseline |
|---|---|
| `R1_gausmix_tt5000_residual` | `L640_gmix_long_split_diag` |
| `R2_gausmix_tt500_residual` | `L670_gmix_short_diag_mix` |
| `R3_ridge_tt5000_singleton_residual` | `L720_ridge_long_softgamma_plus` |
| `R4_rhs_tt5000_residual` | `L760_rhs_long_vbguard_deep` |
| `R5_short_horizon_mixed_residual` | `L770_short_mixed_local_mcmc` |

Effective current source state for the next wave:

- broad rerun source:
  - `qdesn-dynamic-exdqlm-crossstudy-full-rerun-20260406-215700__git-288390b`
- Wave-1 carry-forward source:
  - `SOURCE_BASELINE`, `K510`, `K540`, `K550`, `K580`
- Wave-2 promoted overlay:
  - `L640`, `L670`, `L720`, `L760`, `L770`

## 7) Highest-Expected-Value Directions

The final overnight compute should now stay inside only two single-row residual pockets:

1. long-horizon rhs normal lower-tail row
   - root:
     - `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns`
   - remaining fail:
     - `mcmc_exal`
   - current reason:
     - `geweke_drift; half_chain_drift`
   - highest-value search direction:
     - deeper rhs-only chain plus slightly more conservative rhs transformed-block geometry

2. short-horizon rhs normal upper-tail row
   - root:
     - `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns`
   - remaining fail:
     - `mcmc_exal`
   - current reason:
     - `geweke_drift`
   - highest-value search direction:
     - modest rhs-only chain/freeze extension around the `L770` neighborhood

## 8) Reproducibility Assets

Authoritative outputs for Wave 2:

- stage execution table:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2/tables/stage_execution_status.csv`
- promoted local baseline map:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2/tables/local_baseline_map.csv`
- wave summary:
  - `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-residualfail-20260407-025827__git-eed98f2/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`
- stage selection summaries:
  - `.../stages/R4_rhs_tt5000_residual/summary/stage_candidate_selection.md`
  - `.../stages/R5_short_horizon_mixed_residual/summary/stage_candidate_selection.md`

Decision:

- the branch is now ready for a final, highly targeted residual closure wave over only the last two
  remaining fail rows plus their nearby guard roots
