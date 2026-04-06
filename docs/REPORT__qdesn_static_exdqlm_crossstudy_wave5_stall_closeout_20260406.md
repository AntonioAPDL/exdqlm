# REPORT: QDESN Static exdqlm Cross-Study Wave 5 Stall Closeout

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Why This Closeout Exists

Wave 5 was the corrected remaining-residual closure wave after the Wave-4 long-horizon
prior-scope bug. It produced valid completed evidence on the ridge `tt=1000` slice, then stalled
mid-profile during `H530`.

This memo closes Wave 5 out cleanly so the branch can continue from the completed evidence rather
than treating the stalled run as live.

## 2) Operational Outcome

Run tag:

- `qdesn-static-exdqlm-crossstudy-wave5-20260405b__git-f2f39d8`

Wave-5 execution outcome:

- `H510_ridge_tt1000_local_control`: completed
- `H520_ridge_tt1000_g530_hybrid_chain1400`: completed
- `H530_ridge_tt1000_g530_hybrid_chain1600`: stalled after partial VB output
- no Wave-5 worker or master process remained alive after the stall
- the runner ledger was left stale and has been closed out as:
  - `stop_reason = stalled_after_partial_stage1_h530`

Wave-5 completed evidence is therefore valid only for the two finished Stage-1 profiles.

## 3) What Improved

### 3.1 Stage-1 ridge `tt=1000` result

The carried-forward promoted baseline entering Wave 5 had the following Stage-1 target-slice debt:

| Slice state | Fit FAIL rows | Fail roots | Root-status FAIL roots | Compare-any roots | Compare-full roots |
| --- | ---: | ---: | ---: | ---: | ---: |
| promoted source baseline map | `12` | `12` | `3` | `12 / 15` | `0 / 15` |
| `H510_ridge_tt1000_local_control` | `7` | `7` | `0` | `15 / 15` | `8 / 15` |
| `H520_ridge_tt1000_g530_hybrid_chain1400` | `12` | `12` | `0` | `15 / 15` | `3 / 15` |

Valid improvement:

- `H510` reduced Stage-1 fit FAIL rows from `12` to `7`
- `H510` reduced Stage-1 fail roots from `12` to `7`
- `H510` reduced Stage-1 root-status FAIL roots from `3` to `0`
- `H510` increased Stage-1 compare-full roots from `0 / 15` to `8 / 15`

### 3.2 Effective post-`H510` global debt surface

After overlaying the completed `H510` campaign on top of the carried-forward promoted map:

| Surface | Before Wave 5 | After valid `H510` promotion |
| --- | ---: | ---: |
| fit FAIL rows | `42` | `37` |
| fail roots | `38` | `33` |
| root-status FAIL roots | `6` | `3` |
| compare-any roots | `66` | `69` |
| compare-full roots | `28` | `36` |

The remaining root-status FAIL roots are now only:

- `root__static_shrink__laplace__tau_0p05__tt_1000__qdesn_rhs_ns`
- `root__static_shrink__laplace__tau_0p25__tt_1000__qdesn_rhs_ns`
- `root__static_shrink__laplace__tau_0p95__tt_1000__qdesn_rhs_ns`

## 4) What Still Fails

Remaining promoted residual FAIL surface after valid Wave-5 carry-forward:

| Residual slice | Fail rows | Roots | Main pattern |
| --- | ---: | ---: | --- |
| ridge `tt=1000` | `7` | `7` | long-horizon `ridge x exal x mcmc` ESS/autocorrelation/drift debt |
| rhs `tt=100` | `15` | `12` | short-horizon rhs drift-heavy MCMC debt |
| rhs `tt=1000` | `15` | `14` | long-horizon rhs ESS/autocorrelation MCMC debt |
| unresolved hard-root FAIL band | `3` | `3` | rhs `static_shrink x laplace x tt=1000` only |

All remaining fit FAIL rows are still:

- `37 / 37` `mcmc`
- `33 / 37` `exal`
- `4 / 37` `al`

## 5) Which Ideas Worked Best

Best completed ideas from Wave 5:

| Idea | Read |
| --- | --- |
| `H510_ridge_tt1000_local_control` | best completed long-horizon ridge option; directly improved both fail counts and comparison readiness |
| carry-forward direct-control geometry on ridge `tt=1000` | still stronger than the first G530-derived long-horizon transplant |
| promoting only completed evidence after a stall | preserved real scientific progress without over-claiming partial results |

## 6) Which Ideas Did Not Help

Weak or losing ideas now retired:

| Idea | Why it should not be favored |
| --- | --- |
| `H520_ridge_tt1000_g530_hybrid_chain1400` | did not reduce fail rows at all and cut compare-full roots from `8` to `3` vs `H510` |
| treating Wave 5 as still live | no worker/master process remained, so continued waiting had no value |
| reopening a generic broad search | residual debt is already narrow and slice-specific |

## 7) Which Directions Now Have Highest Expected Value

The highest-value next directions are now narrower:

1. retry the unresolved `H530` long-horizon ridge idea once, because it stalled before the MCMC
   side completed and therefore remains unresolved rather than disproven;
2. test one direct `H510`-geometry deeper-chain ridge challenger, because the surviving remaining
   ridge failures are ESS/autocorrelation/drift style and `H520` showed the geometry transplant
   away from `H510` was harmful;
3. carry the untested rhs short-horizon challengers (`H620/H630`) forward against the promoted
   rhs `tt=100` baseline without rerunning the control;
4. carry the untested rhs long-horizon challengers (`H650/H660`) forward against the promoted rhs
   `tt=1000` baseline while also revalidating the remaining `3` rhs hard-root FAILs;
5. do not rerun solved slices or known losers.

## 8) Promotion Decision

Wave 5 should promote only one result:

| Slice | Promotion decision |
| --- | --- |
| ridge `tt=1000` | promote `H510_ridge_tt1000_local_control` as the new local baseline |
| ridge `tt=1000` G530 transplant | do not promote `H520` |
| ridge `tt=1000` deeper G530 transplant | keep `H530` unresolved; do not promote |

Updated baseline map after Wave 5 stall closeout:

- shared default:
  - `F500_anchor_patched`
- ridge `tt=100` local:
  - `G530_ridge_tt100_drift_guard_chain1300`
- ridge `tt=1000` local:
  - `H510_ridge_tt1000_local_control`
- rhs `tt=100` local:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000` local:
  - `F640_rhs_tt1000_chain1200`

## 9) Next Move

The correct follow-on is a Wave-6 stall-recovery continuation:

- carry forward the updated baseline map with `H510` promoted;
- start from the reduced remaining residual surface:
  - `37` fail rows
  - `33` fail roots
  - `3` unresolved root-status FAIL roots
- do not rerun sourced controls;
- run only the remaining unresolved challengers and one new direct-control ridge long-horizon
  hedge.
