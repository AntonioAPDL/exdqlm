# REPORT: QDESN Static exdqlm Cross-Study Wave 7 Supervised Relaunch Closeout

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Executive Summary

Wave 7 completed the residual-closure scope cleanly under the detached supervised launcher.

This matters for two separate reasons:

1. the operational launcher defect identified after Waves 5 and 6 did not recur;
2. the scientific baseline map improved again on the long-horizon residual slices.

Wave 7 therefore closes the launcher-root-cause thread for this branch path and leaves the
cross-study program in a simpler state:

- all remaining source hard-root FAILs now have successful local-baseline reruns;
- the root-status FAIL surface is now `0`;
- the remaining debt is entirely successful-surface MCMC signoff quality.

## 2) Stage Results

| Stage | Control | Winner | Decision | Main Read |
| --- | --- | --- | --- | --- |
| `S1_ridge_tt1000_remaining_ess_plus_ridge_hardroots` | `H510_ridge_tt1000_local_control` | `J530_ridge_tt1000_g530_hybrid_chain1600_retry` | `PROMOTE` | Clean retry of the previously stalled `H530` idea beat the carried-forward `H510` local baseline on the remaining ridge `tt=1000` slice. |
| `S2_rhs_tt100_remaining_mcmc` | `F610_rhs_tt100_conservative_block` | `F610_rhs_tt100_conservative_block` | `KEEP` | Neither rhs short-horizon challenger beat the carried-forward `F610` local baseline. |
| `S3_rhs_tt1000_remaining_mcmc_plus_rhs_hardroots` | `F640_rhs_tt1000_chain1200` | `J660_rhs_tt1000_chain1600_focus` | `PROMOTE` | Deeper long-horizon rhs persistence revalidated the remaining hard-root band and won the stage. |

## 3) What Improved

### 3.1 Operational improvement

- Wave 7 completed under detached supervision with `completed_requested_scope`;
- the Wave-5/Wave-6 orphaned-launcher pattern did not recur;
- the detached launcher path is therefore treated as the correct runner mode for any future
  residual follow-up.

### 3.2 Scientific improvement

- ridge `tt=1000` residual slice:
  - target fit FAIL rows: `7 -> 6`
  - target fail roots: `7 -> 6`
  - compare-full roots: `0 -> 1`
  - promoted local baseline:
    - `J530_ridge_tt1000_g530_hybrid_chain1600_retry`
- rhs `tt=1000` residual slice:
  - root-status FAIL roots: `3 -> 0`
  - all remaining original hard-root FAILs were revalidated to `SUCCESS`
  - promoted local baseline:
    - `J660_rhs_tt1000_chain1600_focus`
- rhs `tt=100` residual slice:
  - no challenger beat `F610_rhs_tt100_conservative_block`
  - this is still useful information because it retires two more challenger ideas

## 4) What Did Not Help

- `J540_ridge_tt1000_control_chain1500`
  - direct deeper-chain `H510` hedge did not beat `J530`
- `J620_rhs_tt100_hybrid_chain1250`
  - did not beat the carried-forward `F610` baseline
- `J630_rhs_tt100_drift_guard_plus`
  - improved one rhs short-horizon comparison dimension, but not enough to justify promotion over
    `F610`
- `J650_rhs_tt1000_hybrid_block_chain1400`
  - lost to `J660` on the long-horizon rhs slice

These profiles should be treated as tested non-winners, not as live lead candidates.

## 5) Updated Baseline Map

- shared default:
  - `F500_anchor_patched`
- ridge `tt=100` local baseline:
  - `G530_ridge_tt100_drift_guard_chain1300`
- ridge `tt=1000` local baseline:
  - `J530_ridge_tt1000_g530_hybrid_chain1600_retry`
- rhs `tt=100` local baseline:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000` local baseline:
  - `J660_rhs_tt1000_chain1600_focus`

## 6) Remaining Debt After Wave 7

The remaining debt is now entirely comparison-facing MCMC signoff debt on successful roots:

- promoted fit FAIL rows on successful roots:
  - `38`
- affected successful roots:
  - `32`
- method split:
  - `38 / 38` are `mcmc`
- likelihood split:
  - `31 / 38` are `exal`
  - `7 / 38` are `al`
- root-status FAIL roots:
  - `0`

Slice split under the updated local-baseline map:

- ridge `tt=1000`:
  - `6` FAIL rows on `6` successful roots
- rhs `tt=100`:
  - `15` FAIL rows on `12` successful roots
- rhs `tt=1000`:
  - `17` FAIL rows on `14` successful roots

## 7) Interpretation

The cross-study program has crossed an important boundary:

- the remaining problem is no longer root execution or launcher survival;
- the remaining problem is no longer the old rhs VB diagnostics-path issue;
- the remaining problem is no longer the unresolved Wave-1 hard-root FAIL band.

The remaining problem is now one narrower question:

> Can the remaining `38` successful-surface MCMC signoff FAIL rows be reduced to `WARN/PASS`
> cleanly enough that the final cross-study comparison surface becomes healthy-comparable?

## 8) Correct Move-Forward Recommendation

Do not reopen another root-status recovery wave.

Do not rerun broad controls that are already established.

Do not search for one generic tuning profile that solves every remaining row.

The correct next step is a final comparison-health closure pass that:

1. starts from the updated local-baseline map above;
2. targets only the `38` remaining successful-surface MCMC FAIL rows;
3. keeps the shared default and all winning local baselines fixed unless a challenger clearly
   improves the specific remaining slice;
4. treats the program as comparison-health closure, not root-status repair.
