# PLAN: QDESN Dynamic exdqlm Cross-Study Main Comparison Analysis

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Decision

The branch is ready to move from residual fit-fail closure into main comparison analysis.

This plan intentionally does **not** schedule another overnight tuning wave by default.

Rationale:

- the authoritative branch-local baseline now has:
  - `77 PASS`
  - `65 WARN`
  - `2 FAIL`
- all `36 / 36` roots have usable comparison output
- `34 / 36` roots are fully comparison-ready
- root-status FAILs are `0 / 36`
- the final cleanup wave added useful evidence but did not yield a clear full-study baseline
  improvement over the current residual-wave baseline

## 2) Authoritative Baseline For Comparison Work

Use the prior residual-wave local baseline map as the comparison-analysis source:

- `R1 -> L640_gmix_long_split_diag`
- `R2 -> L670_gmix_short_diag_mix`
- `R3 -> L720_ridge_long_softgamma_plus`
- `R4 -> L760_rhs_long_vbguard_deep`
- `R5 -> L770_short_mixed_local_mcmc`

Do **not** silently substitute:

- `M850_rhs_long_burnheavy1300`
- `M940_short_rhs_narrow1200_diag5`

Those final-wave winners remain documented evidence only unless a later decision explicitly adopts
them.

## 3) Comparison-Analysis Scope

The main comparison-analysis phase should:

1. use the authoritative branch-local baseline above;
2. generate the QDESN-vs-exdqlm comparison tables and narrative on the full mirrored dynamic
   surface;
3. keep the two residual fit FAIL rows explicitly documented as a small gap;
4. separate:
   - fully comparison-ready roots (`34 / 36`)
   - usable-but-incomplete roots (`2 / 36`)
5. avoid any new tuning search unless the remaining `2 / 144` FAIL rows become a hard blocker.

## 4) Residual Gap To Carry Forward Transparently

The remaining documented fit-level FAIL rows under the authoritative baseline are:

| Root | Method Row | Reason |
|---|---|---|
| `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift; half_chain_drift` |
| `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift` |

## 5) Optional Future Escalation

Only if a later decision requires zero fit-level FAIL rows:

- reopen a tiny micro-wave on the exact `2` remaining rows only;
- treat that work as optional certification polish, not the current mainline task.
