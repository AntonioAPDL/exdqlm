# TRACK: QDESN Static exdqlm Cross-Study Validation

Date: 2026-04-05
Branch: `feature/qdesn-mcmc-alternative`  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1) Mission

Build the QDESN counterpart to the exdqlm static validation study on the same recovered static
dataset surface, using:

- likelihoods: `exal`, `al`
- methods: `vb`, `mcmc`
- priors: `ridge`, `rhs_ns`

This tracker is for the cross-study program only. It is not the dynamic DLM certification tracker.

## 2) Current Status

Status: **Wave 3 fit-fail closure completed and promoted a local baseline map; Wave 4 residual MCMC closure is now the active follow-up**

Current scope decision:

- launch surface: `static only`
- dynamic row-15 sidecar: `excluded`
- `gausmix @ tau=0.50`: `excluded`
- current move-forward mode: `residual MCMC closure with local tuning allowed`

Historical source baseline:

- run tag:
  - `qdesn-static-exdqlm-crossstudy-20260404b__git-06ac1c0`
- root materialization:
  - `72/72`
- root status:
  - `66 SUCCESS`
  - `6 FAIL`
- authoritative source:
  - root-level outputs, not the stale top-level broad-wave closeout

Promoted post-Wave-3 baseline map:

- shared default:
  - `F500_anchor_patched`
- local ridge baseline:
  - `F510_ridge_rescue_reference`
- local rhs `tt=100` baseline:
  - `F610_rhs_tt100_conservative_block`
- local rhs `tt=1000` baseline:
  - `F640_rhs_tt1000_chain1200`

Main post-Wave-3 takeaways:

- the old `rhs_ns` VB diagnostics-path false-FAIL bucket is closed under the shared baseline;
- the effective remaining debt is now:
  - `45` promoted fit FAIL rows on successful roots,
  - all `45` are `mcmc`,
  - `41 / 45` are `exal`,
  - `4 / 45` are `al`;
- the remaining problem is not one generic family-wide tuning question anymore;
- the remaining problem is now four residual MCMC slices plus the still-unvalidated original
  `6` hard-root FAILs.

Validation checkpoints completed:

- canonical grid materialization: `PASS`
- prepare-only preflight: `PASS`
- one-root live smoke: `PASS`
- Wave-1 broad shared-setup launch: `SOURCE_BASELINE_ESTABLISHED`
- Wave-2 debt-wave Stage-1 probe: `COMPLETED_AND_STOPPED_BEFORE_STAGE2`
- rhs-family diagnostics fallback validation on representative `rhs_ns` smoke root: `PASS`
- Wave-3 fit-fail closure wave: `COMPLETED`
- Wave-4 residual MCMC closure plan + runner implementation: `PREPARE_ONLY_VALIDATED_AND_READY_FOR_LAUNCH`

## 3) Read First

1. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closeout_20260405.md`
2. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave4_residual_mcmc_closure_20260405.md`
3. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
4. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave1_broad_launch_20260404.md`
5. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave2_stage1_closeout_20260404.md`
6. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closure_20260404.md`
7. `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
8. `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
9. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
10. `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
11. `config/validation/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave_manifest.yaml`
12. `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
13. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`
14. `scripts/run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
15. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
16. `scripts/run_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
17. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
18. `R/qdesn_static_exdqlm_crossstudy.R`
19. `R/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
20. `R/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`

## 4) Hard Rules

1. Recover the dataset surface from disk; do not approximate it.
2. Preserve current-vs-legacy provenance in metadata and reporting.
3. Do not reopen the finished dynamic DLM tuning program here.
4. Keep the cross-study static-only until the static surface is truly closed.
5. Treat comparison tables as required outputs.
6. Use prepare-only before real launch.
7. Keep compute conservative and single-threaded per fit.
8. Do not relaunch the whole `72`-root surface while the debt set remains narrow.
9. Keep the shared static defaults as the default baseline unless a completed local slice result clearly beats them.
10. Allow local slice-specific tuning where needed; do not force one generic setup to solve every remaining FAIL.

## 5) Core Assets

Implementation assets:

- defaults:
  - `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
- grid:
  - `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
- broad validation helper:
  - `R/qdesn_static_exdqlm_crossstudy.R`
- Wave-2 debt helper:
  - `R/qdesn_static_exdqlm_crossstudy_debt_wave.R`
- Wave-3 fit-fail closure helper:
  - `R/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
- Wave-4 residual closure helper:
  - `R/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
- broad launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
- broad healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`
- Wave-3 manifest:
  - `config/validation/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml`
- Wave-3 launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
- Wave-3 healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
- Wave-4 manifest:
  - `config/validation/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave_manifest.yaml`
- Wave-4 launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
- Wave-4 healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`

## 6) Current Debt

Remaining scientific debt is now split more precisely:

1. promoted residual fit FAIL surface on successful roots:
   - `45` fit FAIL rows
   - `41` roots
   - `45 / 45` are `mcmc`
   - `41 / 45` are `exal`
2. unresolved original Wave-1 hard-root FAIL band:
   - `6` roots
   - all in `static_shrink x laplace x tt=1000`
   - `3` ridge
   - `3` rhs_ns
3. residual ridge short-horizon drift slice:
   - `3` FAIL rows
   - `3` roots
4. residual ridge long-horizon ESS slice:
   - `12` FAIL rows
   - `12` roots
5. residual rhs short-horizon drift slice:
   - `15` FAIL rows
   - `12` roots
6. residual rhs long-horizon ESS slice:
   - `15` FAIL rows
   - `14` roots

Current highest-value questions:

- can a tighter F510-derived ridge drift guard eliminate the last `3` ridge `tt=100` residuals?
- can a hybrid F510-plus-chain profile reduce the `12` long-horizon ridge `exal/mcmc` residuals
  and revalidate the ridge half of the old hard-root FAIL band?
- can F610-derived geometry-first rhs profiles remove the remaining `tt=100` drift-heavy residuals
  without replaying the failed chain-only rhs branch?
- can F640-derived long-horizon rhs profiles both revalidate the rhs half of the old hard-root
  FAIL band and reduce the remaining `tt=1000` ESS/autocorrelation residuals?

## 7) Current Baseline Map

Shared default baseline:

- keep the shared static defaults as the default baseline everywhere
- the active shared default now includes the validated `rhs_trace.rds` fallback so successful
  `rhs_ns` VB fits are not falsely marked `FAIL` when `rhs_run_summary.csv` is missing
- the shared default profile id is:
  - `F500_anchor_patched`

Local promoted baselines:

- ridge:
  - `F510_ridge_rescue_reference`
- rhs `tt=100`:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000`:
  - `F640_rhs_tt1000_chain1200`

Current practical read:

- the shared baseline is now the right default only where no local slice winner has already
  beaten it;
- the ridge, rhs `tt=100`, and rhs `tt=1000` slices now each have a justified local control;
- the next follow-up should therefore start from the promoted local-baseline map, not from the
  original broad baseline and not from the earlier Wave-2 probe hints.
