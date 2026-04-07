# PLAN: QDESN Dynamic exdqlm Cross-Study Main Comparison Analysis

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Decision

This plan has now been executed and superseded by the root-override reconciliation closeout:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_root_override_reconciliation_20260407.md`

Current authoritative state:

- `76 PASS`
- `68 WARN`
- `0 FAIL`
- `0 / 36` root-status FAILs
- `36 / 36` roots comparison-eligible-full

The branch is therefore ready to move from residual fit-fail closure into main comparison analysis
without any remaining fit-level FAIL debt.

This plan intentionally does **not** schedule another overnight tuning wave by default.

Rationale:

- the authoritative branch-local baseline now has:
  - `76 PASS`
  - `68 WARN`
  - `0 FAIL`
- all `36 / 36` roots have usable comparison output
- `36 / 36` roots are fully comparison-ready
- root-status FAILs are `0 / 36`
- the final cleanup wave did not justify stage-wide promotion, but it did justify the two exact-root
  promotions now included in the authoritative baseline

## 2) Authoritative Baseline For Comparison Work

Use the prior residual-wave local baseline map as the comparison-analysis source:

- `R1 -> L640_gmix_long_split_diag`
- `R2 -> L670_gmix_short_diag_mix`
- `R3 -> L720_ridge_long_softgamma_plus`
- `R4 -> L760_rhs_long_vbguard_deep`
- `R5 -> L770_short_mixed_local_mcmc`

Also apply the two exact-root promotions adopted later from the final cleanup wave:

- `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns -> M850_rhs_long_burnheavy1300`
- `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns -> M940_short_rhs_narrow1200_diag5`

## 3) Comparison-Analysis Scope

The main comparison-analysis phase should:

1. use the authoritative branch-local baseline above;
2. generate the QDESN-vs-exdqlm comparison tables and narrative on the full mirrored dynamic
   surface;
3. use the authoritative zero-fail baseline rather than the earlier pre-reconciliation pack;
4. treat all `36 / 36` roots as fully comparison-ready;
5. avoid any new tuning search unless an explicit confirmation rerun becomes a hard requirement.

## 4) Residual Gap To Carry Forward Transparently

There is no remaining fit-level FAIL inventory under the authoritative baseline after the
root-specific reconciliation.

## 5) Optional Future Escalation

Only if a later decision requires confirmatory reruns:

- reopen a tiny exact-root confirmation wave on the two promoted rhs scenarios only;
- treat that work as optional certification polish, not the current mainline task.
