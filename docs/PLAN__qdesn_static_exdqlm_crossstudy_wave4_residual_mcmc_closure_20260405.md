# PLAN: QDESN Static exdqlm Cross-Study Wave 4 Residual MCMC Closure

Date: 2026-04-05  
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

Supersession note:

- Wave 4 Stage 1 completed validly and promoted `G530_ridge_tt100_drift_guard_chain1300`
- the original Wave-4 long-horizon continuation was later superseded because the hard-root
  carry-forward selector matched both priors on `source_root_status_fail_grid.csv`
- see:
  - `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave4_stage1_closeout_and_scope_fix_20260405.md`
  - `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave5_remaining_residual_mcmc_closure_20260405.md`

## 1) Why Wave 4 Exists

Wave 3 materially improved the static cross-study, but it did not finish it.

What is already settled:

- the old `rhs_ns` VB diagnostics-path false-FAIL issue is now closed under the shared baseline;
- `F510_ridge_rescue_reference` is the best completed ridge-local rescue;
- `F610_rhs_tt100_conservative_block` is the best completed rhs `tt=100` rescue;
- `F640_rhs_tt1000_chain1200` is the best completed rhs `tt=1000` rescue.

What is not settled:

- `45` promoted residual fit FAIL rows still remain on successful roots;
- all of those residual fit FAILs are MCMC;
- `41 / 45` are `exal`;
- the original `6` Wave-1 hard-root FAILs were not revalidated inside Wave 3.

Wave 4 therefore starts from the **promoted Wave-3 local-baseline map**, not from the older
Wave-1 source buckets.

## 2) Current Baseline Map

| Scope | Baseline to carry forward |
| --- | --- |
| shared default | `F500_anchor_patched` |
| ridge local slice | `F510_ridge_rescue_reference` |
| rhs local `tt=100` slice | `F610_rhs_tt100_conservative_block` |
| rhs local `tt=1000` slice | `F640_rhs_tt1000_chain1200` |

Hard rule:

- keep the shared baseline as the default;
- use local overrides only on the slices where Wave 3 produced a clear local winner;
- do not reopen a generic “one profile for everything” search.

## 3) Remaining Debt Surface

### 3.1 Promoted residual fit FAIL slices

| Residual slice | Fail rows | Roots | Main pattern |
| --- | ---: | ---: | --- |
| ridge `tt=100` | `3` | `3` | short-horizon drift |
| ridge `tt=1000` | `12` | `12` | mostly ESS/autocorrelation on `exal` |
| rhs `tt=100` | `15` | `12` | short-horizon drift, mostly `exal`, small `al` tail |
| rhs `tt=1000` | `15` | `14` | longer-horizon ESS/autocorrelation, mostly `exal` |

### 3.2 Still-unvalidated hard-root FAIL band

The original Wave-1 hard-root FAIL band must be carried explicitly:

- `static_shrink x laplace x tt=1000 x tau in {0.05, 0.25, 0.95}`
- both priors:
  - `ridge`
  - `rhs_ns`

That adds:

- `3` unresolved ridge hard-root FAILs
- `3` unresolved rhs hard-root FAILs

### 3.3 Effective Wave-4 stage sizes

| Stage | Residual roots | Extra hard-root FAIL roots | Total roots |
| --- | ---: | ---: | ---: |
| ridge `tt=100` drift | `3` | `0` | `3` |
| ridge `tt=1000` ESS + hard roots | `12` | `6` | `18` |
| rhs `tt=100` residual MCMC | `12` | `0` | `12` |
| rhs `tt=1000` residual MCMC + hard roots | `14` | `6` | `20` |

Total targeted roots for Wave 4:

- `53`

Total planned root campaigns with 3 profiles per stage:

- `159`

## 4) What We Will Not Rerun

To protect learning value per unit of compute, Wave 4 will not reopen directions that now look
weak or redundant.

| Direction | Why it is excluded |
| --- | --- |
| another full 72-root relaunch | debt is too narrow now |
| generic shared rescue profile search | Wave 3 showed the slices want different fixes |
| ridge chain-only replay (`F520`-style) | it did not beat `F510` |
| rhs `tt=100` chain-only replay (`F620`-style) | it lost cleanly to `F610` |
| rhs `tt=1000` geometry-only replay (`F630`-style) | it lost to `F640` |

## 5) Candidate Program

### Stage 1: Ridge `tt=100` residual drift

| Profile | Why included |
| --- | --- |
| `G510_ridge_local_baseline` | control; current best ridge-local baseline |
| `G520_ridge_tt100_drift_guard` | tighter F510 geometry for the 3 drift-heavy short-horizon ridge failures |
| `G530_ridge_tt100_drift_guard_chain1300` | same geometry-first idea with only modest keep-length inflation |

### Stage 2: Ridge `tt=1000` residual ESS + hard roots

| Profile | Why included |
| --- | --- |
| `G510_ridge_local_baseline` | control |
| `G540_ridge_tt1000_hybrid_chain1400` | F510 geometry plus moderate chain extension for the longer-horizon ESS/autocorrelation slice |
| `G550_ridge_tt1000_hybrid_chain1600` | heavier persistence hedge for the same long-horizon ridge slice |

### Stage 3: RHS `tt=100` residual MCMC

| Profile | Why included |
| --- | --- |
| `G610_rhs_tt100_local_baseline` | control; current best rhs short-horizon local baseline |
| `G620_rhs_tt100_hybrid_chain1250` | conservative block geometry plus moderate chain extension |
| `G630_rhs_tt100_drift_guard_plus` | stronger drift-focused rhs geometry without reopening the chain-only loser |

### Stage 4: RHS `tt=1000` residual MCMC + hard roots

| Profile | Why included |
| --- | --- |
| `G640_rhs_tt1000_local_baseline` | control; current best rhs long-horizon local baseline |
| `G650_rhs_tt1000_hybrid_block_chain1400` | combines the F640 chain gain with the tighter F630-style transformed block |
| `G660_rhs_tt1000_chain1600_focus` | tests whether the remaining long-horizon rhs debt is mainly persistence/ESS |

## 6) Selection Logic

Wave 4 is allowed to promote a challenger only if it clearly improves the current local control.

Ranking order:

1. lower `root_n_status_fail`
2. lower `target_fit_fail_n`
3. lower `target_root_fail_n`
4. lower `fit_n_fail`
5. higher `root_n_compare_full`
6. lower runtime as a tie-break

This means:

- rescuing a hard-root FAIL outranks shaving a few fit FAILs;
- fit-level cleanup still matters once root execution is stable;
- a challenger that is merely different but not better does not get promoted.

## 7) Resource Plan

Server policy:

- machine: `64` logical CPUs, large memory headroom
- keep per-fit threading flat:
  - `threads = 1`
  - `postpred_threads = 1`
- avoid nested parallelism

Chosen campaign policy:

- default workers: `8`
- fallback workers if other QDESN jobs are active: `6`
- hard cap: `8`
- launch with `--no-plots`

Why `8` workers is the right default:

- Wave 3 already ran stably at `8` workers on this server;
- Wave 4 is only `141` root campaigns and is more targeted than Wave 3;
- the remaining `tt=1000` rhs/ridge stages are heavy enough that pushing wider adds little value.

## 8) Outputs Required

Wave 4 must emit:

1. preflight manifest and markdown
2. promoted-source tables:
   - fit summary
   - fail summary
   - root summary
   - root-status table
3. per-stage root lists and profile metrics
4. per-stage ranking and selection summary
5. updated local baseline recommendations
6. completed-wave manifest and summary

## 9) Acceptance Criteria

Wave 4 is considered technically successful if:

1. prepare-only passes cleanly;
2. all stage grids materialize correctly from the promoted baseline map;
3. the run completes with no orchestration failure;
4. any promoted challenger beats the stage control on the explicit ranking rules;
5. the hard-root FAIL band is revalidated rather than left implied.

Scientific closeout is stronger if:

- root-status FAILs go to `0` on the targeted hard-root band;
- residual fit FAILs are reduced materially below the current promoted-map level;
- no new finite/domain regressions are introduced.

## 10) Execution Sequence

1. update the cross-study tracker and the higher-level trackers with the Wave-3 closeout and the
   new residual debt definition;
2. add the Wave-3 closeout report and the Wave-4 plan;
3. add the Wave-4 residual-closure manifest and launch/healthcheck scripts;
4. validate with `--prepare-only`;
5. commit and push cleanly;
6. launch the overnight run only after the preflight is clean.
