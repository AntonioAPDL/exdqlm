# PLAN: QDESN Static exdqlm Cross-Study Wave 5 Remaining Residual MCMC Closure

Date: 2026-04-05  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Why Wave 5 Exists

Wave 4 produced one valid improvement and one important correction.

Settled now:

- `G530_ridge_tt100_drift_guard_chain1300` solved the ridge `tt=100` residual slice
- the residual promoted-map FAIL surface fell from `45` rows on `41` roots to `42` rows on
  `38` roots
- the old `rhs_ns` VB diagnostics-path false-FAIL issue is still closed under the shared baseline

Also settled:

- Wave-4 long-horizon stages were contaminated by a prior-scope selector bug
- those long-horizon results should not be used for promotion

Wave 5 therefore exists to do the **remaining** residual MCMC closure on the corrected scope,
starting from the Stage-1-improved baseline map.

## 2) Updated Baseline Map

| Scope | Baseline to carry forward |
| --- | --- |
| shared default | `F500_anchor_patched` |
| ridge `tt=100` local | `G530_ridge_tt100_drift_guard_chain1300` |
| ridge `tt=1000` local control | `F510_ridge_rescue_reference` |
| rhs `tt=100` local | `F610_rhs_tt100_conservative_block` |
| rhs `tt=1000` local | `F640_rhs_tt1000_chain1200` |

Hard rule:

- keep the shared baseline as the default;
- keep local overrides only on slices where a completed result has already beaten the control;
- do not reopen a generic cross-family search.

## 3) Remaining Debt Surface

### 3.1 Current promoted residual FAIL surface

| Residual slice | Fail rows | Roots | Main pattern |
| --- | ---: | ---: | --- |
| ridge `tt=1000` | `12` | `12` | ESS/autocorrelation on `exal` |
| rhs `tt=100` | `15` | `12` | short-horizon drift, mostly `exal` |
| rhs `tt=1000` | `15` | `14` | ESS/autocorrelation, mostly `exal` |

### 3.2 Still-unvalidated hard-root FAIL band

The original Wave-1 hard-root FAIL band still has to be revalidated cleanly:

- `3` ridge roots
- `3` rhs_ns roots
- all in:
  - `static_shrink x laplace x tt=1000`
  - `tau in {0.05, 0.25, 0.95}`

### 3.3 Corrected stage sizes

| Stage | Residual roots | Extra hard-root FAIL roots | Total roots |
| --- | ---: | ---: | ---: |
| ridge `tt=1000` remaining ESS + ridge hard roots | `12` | `3` | `15` |
| rhs `tt=100` remaining MCMC | `12` | `0` | `12` |
| rhs `tt=1000` remaining MCMC + rhs hard roots | `14` | `3` | `17` |

Total remaining targeted roots:

- `44`

Total planned root campaigns with `3` profiles per stage:

- `132`

## 4) What We Will Not Rerun

| Direction | Why it is excluded |
| --- | --- |
| the solved ridge `tt=100` slice | `G530` already closed it cleanly |
| another 72-root relaunch | debt is narrow and local now |
| another generic shared-rescue search | remaining slices want different fixes |
| old F510-only long-horizon challenger family | Stage 1 says the tighter G530 geometry is now the stronger ridge clue |
| rhs chain-only replay | already proved weak |
| rhs geometry-only long-horizon replay | already lost to `F640` |

## 5) Candidate Program

### Stage 1: ridge `tt=1000` remaining ESS + ridge hard roots

| Profile | Why included |
| --- | --- |
| `H510_ridge_tt1000_local_control` | control; current long-horizon ridge local control |
| `H520_ridge_tt1000_g530_hybrid_chain1400` | carries the Stage-1-winning G530 geometry into the long-horizon ridge slice with moderate chain extension |
| `H530_ridge_tt1000_g530_hybrid_chain1600` | same geometry family with a deeper long-horizon persistence hedge |

### Stage 2: rhs `tt=100` remaining MCMC

| Profile | Why included |
| --- | --- |
| `H610_rhs_tt100_local_control` | control; current best rhs short-horizon local baseline |
| `H620_rhs_tt100_hybrid_chain1250` | conservative transformed-block geometry plus modest chain extension |
| `H630_rhs_tt100_drift_guard_plus` | stronger drift-focused rhs geometry without reopening the old chain-only loser |

### Stage 3: rhs `tt=1000` remaining MCMC + rhs hard roots

| Profile | Why included |
| --- | --- |
| `H640_rhs_tt1000_local_control` | control; current best rhs long-horizon local baseline |
| `H650_rhs_tt1000_hybrid_block_chain1400` | combines the F640 chain gain with tighter transformed-block geometry |
| `H660_rhs_tt1000_chain1600_focus` | pushes keep length further because the remaining rhs `tt=1000` debt is persistence-heavy |

## 6) Selection Logic

Wave 5 may promote a challenger only if it clearly improves the current local control.

Ranking order:

1. lower `root_n_status_fail`
2. lower `target_fit_fail_n`
3. lower `target_root_fail_n`
4. lower `fit_n_fail`
5. higher `root_n_compare_full`
6. lower runtime as tie-break

This keeps the program focused on:

- rescuing root-level hard FAILs first
- reducing actual residual fit FAILs second
- improving scientific comparison readiness third

## 7) Resource Plan

Server policy:

- machine: `64` logical CPUs with large memory headroom
- keep per-fit threading flat:
  - `threads = 1`
  - `postpred_threads = 1`
- avoid nested parallelism

Chosen launch policy:

- default workers: `8`
- fallback workers if other QDESN jobs are active: `6`
- hard cap: `8`
- launch with `--no-plots`

Why this is still the right policy:

- Wave 4 already ran stably at `8` workers before the scope bug was found
- Wave 5 is smaller than the original Wave-4 design
- the remaining `tt=1000` stages are heavy enough that wider launch gives little extra value

## 8) Outputs Required

Wave 5 must emit:

1. preflight manifest and markdown
2. corrected promoted-source tables
3. per-stage root lists and profile metrics
4. per-stage ranking and selection summary
5. updated local baseline recommendations
6. completed-wave summary and manifest

## 9) Acceptance Criteria

Wave 5 is technically successful if:

1. prepare-only passes cleanly;
2. the corrected stage sizes are exactly `15`, `12`, and `17` roots;
3. the run completes with no orchestration failure;
4. any promoted challenger beats the stage control under the explicit ranking rules;
5. the long-horizon hard-root carry-forward is prior-correct and not cross-contaminated.

Scientific closeout is stronger if:

- root-status FAILs go to `0` on the remaining hard-root band;
- residual fit FAILs drop materially below the current `42`-row surface;
- no new finite/domain regressions appear.

## 10) Execution Sequence

1. close out the valid Wave-4 Stage-1 result and document the scope bug;
2. patch the selector aliasing bug;
3. update the trackers with the new `G530` promotion and the corrected remaining debt definition;
4. add the corrected Wave-5 manifest;
5. validate with `--prepare-only`;
6. commit and push cleanly;
7. launch the corrected remaining-residual wave.
