# PLAN: QDESN Static exdqlm Cross-Study Wave 6 Stall Recovery

Date: 2026-04-06
Branch: `feature/qdesn-mcmc-alternative`
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Why Wave 6 Exists

Wave 5 produced one valid promotion and then stalled before finishing its first stage.

Settled now:

- `H510_ridge_tt1000_local_control` validly improved the long-horizon ridge slice
- `H520_ridge_tt1000_g530_hybrid_chain1400` was a clear loser
- `H530_ridge_tt1000_g530_hybrid_chain1600` is unresolved because the run died mid-profile
- the effective remaining promoted debt has dropped to:
  - `37` FAIL rows
  - `33` fail roots
  - `3` unresolved root-status FAIL roots

Wave 6 therefore exists to continue from the corrected post-`H510` baseline map, recover from the
Wave-5 stall, and close only the still-unresolved residual MCMC slices.

## 2) Updated Baseline Map

| Scope | Baseline to carry forward |
| --- | --- |
| shared default | `F500_anchor_patched` |
| ridge `tt=100` local | `G530_ridge_tt100_drift_guard_chain1300` |
| ridge `tt=1000` local | `H510_ridge_tt1000_local_control` |
| rhs `tt=100` local | `F610_rhs_tt100_conservative_block` |
| rhs `tt=1000` local | `F640_rhs_tt1000_chain1200` |

Hard rule:

- keep the shared baseline as the default;
- keep local overrides only where a completed result has already beaten the control;
- do not reopen a generic cross-family search;
- do not rerun sourced controls when the residual launcher can compare challengers against the
  carried-forward source metric directly.

## 3) Remaining Debt Surface After `H510`

### 3.1 Current promoted residual FAIL surface

| Residual slice | Fail rows | Roots | Main pattern |
| --- | ---: | ---: | --- |
| ridge `tt=1000` | `7` | `7` | ESS/autocorrelation/drift on `ridge x exal x mcmc` |
| rhs `tt=100` | `15` | `12` | short-horizon drift-heavy rhs MCMC debt |
| rhs `tt=1000` | `15` | `14` | long-horizon ESS/autocorrelation rhs MCMC debt |

### 3.2 Still-unvalidated hard-root FAIL band

Only the rhs half of the original Wave-1 hard-root FAIL band remains unresolved:

- `3` rhs_ns roots
- all in:
  - `static_shrink x laplace x tt=1000`
  - `tau in {0.05, 0.25, 0.95}`

### 3.3 Corrected Wave-6 stage sizes

| Stage | Residual roots | Extra hard-root FAIL roots | Total roots |
| --- | ---: | ---: | ---: |
| ridge `tt=1000` remaining ESS | `7` | `0` | `7` |
| rhs `tt=100` remaining MCMC | `12` | `0` | `12` |
| rhs `tt=1000` remaining MCMC + rhs hard roots | `14` | `3` | `17` |

Total remaining targeted roots:

- `36`

Total planned root campaigns with `2` challenger profiles per stage:

- `72`

## 4) What We Will Not Rerun

| Direction | Why it is excluded |
| --- | --- |
| solved ridge `tt=100` slice | `G530` already closed it cleanly |
| Wave-5 sourced controls `H510/F610/F640` | launcher can score challengers against sourced controls without replaying them |
| `H520` | completed loser on long-horizon ridge |
| whole 72-root relaunch | debt is narrow and local |
| another generic shared-rescue search | remaining slices want different fixes |
| old chain-only rhs replay | already proved weak |

## 5) Candidate Program

### Stage 1: ridge `tt=1000` remaining ESS

Control is carried forward from source:

- `H510_ridge_tt1000_local_control`

Challengers:

| Profile | Why included |
| --- | --- |
| `J530_ridge_tt1000_g530_hybrid_chain1600_retry` | one clean retry of the unresolved `H530` idea, because it stalled before MCMC closeout and is therefore unresolved rather than disproven |
| `J540_ridge_tt1000_control_chain1500` | direct `H510`-geometry deeper-chain hedge; included because the remaining ridge debt is ESS/autocorrelation-heavy and `H520` showed the G530 geometry transplant degraded the long-horizon slice |

### Stage 2: rhs `tt=100` remaining MCMC

Control is carried forward from source:

- `F610_rhs_tt100_conservative_block`

Challengers:

| Profile | Why included |
| --- | --- |
| `J620_rhs_tt100_hybrid_chain1250` | conservative transformed-block geometry plus modest chain extension; still untested because Wave 5 never reached rhs stages |
| `J630_rhs_tt100_drift_guard_plus` | stronger short-horizon rhs drift guard; still untested and directly aligned with the remaining drift-heavy failure pattern |

### Stage 3: rhs `tt=1000` remaining MCMC + rhs hard roots

Control is carried forward from source:

- `F640_rhs_tt1000_chain1200`

Challengers:

| Profile | Why included |
| --- | --- |
| `J650_rhs_tt1000_hybrid_block_chain1400` | long-horizon rhs hybrid that keeps the F640 chain gain while tightening transformed-block geometry |
| `J660_rhs_tt1000_chain1600_focus` | deeper keep-length rhs persistence hedge for the remaining ESS/autocorrelation debt and hard-root revalidation |

## 6) Selection Logic

Wave 6 may promote a challenger only if it clearly improves the current carried-forward control.

Ranking order:

1. lower `root_n_status_fail`
2. lower `target_fit_fail_n`
3. lower `target_root_fail_n`
4. lower `fit_n_fail`
5. higher `root_n_compare_full`
6. lower runtime as tie-break

This keeps the program focused on:

- rescuing remaining root-status FAILs first
- reducing actual residual fit FAILs second
- improving scientific comparison readiness third

## 7) Resource Plan

Server policy:

- keep per-fit threading flat:
  - `threads = 1`
  - `postpred_threads = 1`
- avoid nested parallelism

Chosen launch policy:

- default workers: `6`
- active job workers: `6`
- hard cap: `6`
- launch with `--no-plots`

Why this is the right policy now:

- remaining stages are MCMC-heavy and long-horizon
- source controls are no longer rerun, so challenger-only scheduling already cuts compute
- the worktree is sharing server capacity with other validation jobs

## 8) Outputs Required

Wave 6 must emit:

1. preflight manifest and markdown
2. sourced promoted-state tables from the Wave-5 stalled run with `H510` applied
3. per-stage root lists and challenger metrics
4. per-stage ranking and selection summary against the carried-forward source control
5. updated local baseline recommendations
6. completed-wave summary and manifest

## 9) Acceptance Criteria

Wave 6 is technically successful if:

1. prepare-only passes cleanly;
2. the sourced stage sizes are exactly `7`, `12`, and `17` roots;
3. sourced controls are not rerun inside the stage profile lists;
4. the run completes with no orchestration failure;
5. any promoted challenger beats the carried-forward control under the explicit ranking rules.

Scientific closeout is stronger if:

- remaining root-status FAILs drop below the current `3`-root rhs hard-root band;
- residual fit FAILs drop materially below the current `37`-row surface;
- no new finite/domain regressions appear.

## 10) Execution Sequence

1. close out Wave 5 as stalled and preserve only the valid `H510` promotion;
2. update trackers with the post-`H510` debt counts and baseline map;
3. add the Wave-6 stall-recovery manifest;
4. validate with `--prepare-only`;
5. commit and push cleanly;
6. launch the corrected challenger-only recovery wave.
