# REPORT: QDESN Dynamic exdqlm Cross-Study Final-Fail Wave Closeout And Comparison Readiness

Date: 2026-04-07  
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`  
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## Status Note

This report is still the correct historical closeout for the **stage-wide** final-fail wave, but it
is no longer the current source of truth for the branch-local baseline.

For the current authoritative branch state, use:

- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_root_override_reconciliation_20260407.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_main_comparison_outputs_20260407.md`
- `docs/TRACK__qdesn_0p4p0_integration_handoff_20260406.md`

Current authoritative state after exact-root reconciliation:

- `76 PASS`
- `68 WARN`
- `0 FAIL`
- `0 / 36` root-status FAILs
- `36 / 36` comparison-eligible-full roots

## 1) Executive Read

The final rhs-only cleanup wave completed cleanly and produced useful stage-local evidence, but it
did **not** justify a further global baseline promotion.

The authoritative branch-local comparison baseline therefore remains the prior residual-wave map:

- `R1 -> L640_gmix_long_split_diag`
- `R2 -> L670_gmix_short_diag_mix`
- `R3 -> L720_ridge_long_softgamma_plus`
- `R4 -> L760_rhs_long_vbguard_deep`
- `R5 -> L770_short_mixed_local_mcmc`

That authoritative baseline is now strong enough to move forward into main comparison analysis,
with a very small documented residual fail band still present.

## 2) Final-Wave Execution Status

Completed run:

- run tag:
  - `qdesn-dynamic-exdqlm-crossstudy-finalfail-20260407-133928__git-512e982`
- stop reason:
  - `completed_requested_scope`
- execution:
  - `2/2` stages complete
  - `10/10` profiles complete
  - `40/40` root-campaigns executed

Wave-generated stage-local winners:

- `F1 -> M850_rhs_long_burnheavy1300`
- `F2 -> M940_short_rhs_narrow1200_diag5`

Authoritative wave summary:

- `reports/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_final_fail_closure_wave/qdesn-dynamic-exdqlm-crossstudy-finalfail-20260407-133928__git-512e982/summary/qdesn_dynamic_crossstudy_fit_fail_closure_results.md`

## 3) Why The Final-Wave Winners Were Not Promoted

The final wave was designed to optimize the exact last rhs fail rows plus a small guard set.
That was useful and scientifically valid.

However, branch-local promotion must be judged against the **full mirrored 36-root study**, not
only the targeted stage pocket.

I reconciled the wave outputs against the source effective baseline using:

- source full-study summaries from the final-wave tables:
  - `tables/source_fit_summary.csv`
  - `tables/source_root_signoff_summary.csv`
- stage root scopes:
  - `stages/F1_rhs_long_normal_tail_final/tables/stage_root_ids.csv`
  - `stages/F2_rhs_short_normal_tail_final/tables/stage_root_ids.csv`
- candidate campaign summaries for the recommended winners:
  - `M850 ... /tables/campaign_fit_summary.csv`
  - `M850 ... /tables/campaign_root_signoff_summary.csv`
  - `M940 ... /tables/campaign_fit_summary.csv`
  - `M940 ... /tables/campaign_root_signoff_summary.csv`

Reconciled global result:

| State | PASS | WARN | FAIL | Fail Roots | Root-Status FAILs | Compare-Any Roots | Compare-Full Roots |
|---|---:|---:|---:|---:|---:|---:|---:|
| Source effective baseline before final wave | `77` | `65` | `2` | `2` | `0` | `36 / 36` | `34 / 36` |
| Apply `M850` only | `77` | `65` | `2` | `2` | `0` | `36 / 36` | `34 / 36` |
| Apply `M940` only | `76` | `65` | `3` | `2` | `0` | `36 / 36` | `34 / 36` |
| Apply both `M850` and `M940` | `76` | `65` | `3` | `2` | `0` | `36 / 36` | `34 / 36` |

Interpretation:

- `M850` is useful evidence, but globally neutral rather than better.
- `M940` improves the exact targeted row inside `F2`, but worsens the full-study FAIL count.
- therefore neither final-wave stage winner is a clear global promotion over the prior branch-local
  effective baseline.

## 4) Authoritative Current Validation State

The authoritative branch-local baseline remains the prior residual-wave map:

- `L640_gmix_long_split_diag`
- `L670_gmix_short_diag_mix`
- `L720_ridge_long_softgamma_plus`
- `L760_rhs_long_vbguard_deep`
- `L770_short_mixed_local_mcmc`

Current full-study comparison-readiness state under that baseline:

- fit signoff mix:
  - `77 PASS`
  - `65 WARN`
  - `2 FAIL`
- fail-carrying roots:
  - `2 / 36`
- root-status FAILs:
  - `0 / 36`
- roots with any usable comparison:
  - `36 / 36`
- fully comparison-ready roots:
  - `34 / 36`

Exact remaining documented FAIL rows:

| Root | Method Row | Reason |
|---|---|---|
| `root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift; half_chain_drift` |
| `root__dynamic__dlm_constV_smallW__normal__tau_0p95__lasttt_500__qdesn_rhs_ns` | `mcmc_exal` | `geweke_drift` |

## 5) What Improved And What Did Not

What improved:

- the exact rhs-specific target rows in `F1` and `F2` were shown to be locally movable;
- the final wave completed cleanly and added no root-status FAILs;
- the branch now has stronger evidence that the remaining gaps are tiny and tightly localized.

What did not improve enough:

- the final-wave recommendations do not reduce the full-study FAIL count below `2`;
- `F2` specifically introduces a broader global tradeoff that makes it unsuitable for baseline
  promotion.

## 6) Recommendation

The correct next phase is now:

- move to main comparison analysis on the authoritative baseline from the prior residual wave;
- keep the final-wave outputs as documented supporting evidence, not promoted defaults;
- treat the remaining `2 / 144` fit FAIL rows as a small documented residual gap;
- defer any extra micro-wave unless a strict zero-FAIL certification is later required.
