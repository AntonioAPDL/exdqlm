# TRACK: QDESN Static exdqlm Cross-Study Validation

Date: 2026-04-06
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

Status: **Wave 7 supervised relaunch completed cleanly under detached supervision
(`qdesn-static-exdqlm-crossstudy-residualmcmc-20260406-032836__git-b0dc6ca`); the launcher root
cause is now treated as fixed for this branch path, the effective local-baseline map has advanced
to `J530/J660`, and the remaining debt is now successful-surface MCMC comparison-health debt rather
than root-status failure debt**

Current scope decision:

- launch surface: `static only`
- dynamic row-15 sidecar: `excluded`
- `gausmix @ tau=0.50`: `excluded`
- current move-forward mode: `comparison-health closure planning on top of the completed local-baseline map`

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

Promoted current baseline map:

- shared default:
  - `F500_anchor_patched`
- local ridge `tt=100` baseline:
  - `G530_ridge_tt100_drift_guard_chain1300`
- local ridge `tt=1000` baseline:
  - `J530_ridge_tt1000_g530_hybrid_chain1600_retry`
- local rhs `tt=100` baseline:
  - `F610_rhs_tt100_conservative_block`
- local rhs `tt=1000` baseline:
  - `J660_rhs_tt1000_chain1600_focus`

Main current takeaways:

- the old `rhs_ns` VB diagnostics-path false-FAIL bucket remains closed under the shared baseline;
- Wave 7 completed cleanly under detached supervision and did not reproduce the orphaned-launcher
  failure shape from Waves 5 and 6;
- `J530` beat the carried-forward `H510` local baseline on the remaining ridge `tt=1000` slice:
  - Stage-1 fit FAIL rows: `7 -> 6`
  - Stage-1 fail roots: `7 -> 6`
  - Stage-1 compare-full roots: `0 -> 1`
- `J540` did not beat `J530` and should be treated as a tested non-winner;
- `F610` remained the best rhs `tt=100` local baseline; both Wave-7 challengers failed to justify
  promotion;
- `J660` beat the carried-forward `F640` long-horizon rhs local baseline and closed the remaining
  root-status FAIL band:
  - root-status FAIL roots: `3 -> 0`
  - original hard-root FAIL band now revalidated to `SUCCESS`
- the effective remaining debt after Wave 7 is now:
  - `38` promoted fit FAIL rows on successful roots,
  - `32` affected successful roots,
  - all `38 / 38` are `mcmc`,
  - `31 / 38` are `exal`,
  - `7 / 38` are `al`,
  - `0` unresolved root-status FAIL roots remain;
- the remaining problem is no longer one generic family-wide tuning question;
- the remaining problem is now a final successful-surface comparison-health closure question over
  three residual MCMC slices, with local tuning only where it still buys down real FAIL debt.

Validation checkpoints completed:

- canonical grid materialization: `PASS`
- prepare-only preflight: `PASS`
- one-root live smoke: `PASS`
- Wave-1 broad shared-setup launch: `SOURCE_BASELINE_ESTABLISHED`
- Wave-2 debt-wave Stage-1 probe: `COMPLETED_AND_STOPPED_BEFORE_STAGE2`
- rhs-family diagnostics fallback validation on representative `rhs_ns` smoke root: `PASS`
- Wave-3 fit-fail closure wave: `COMPLETED`
- Wave-4 Stage-1 ridge residual drift stage: `COMPLETED_AND_PROMOTED_G530`
- Wave-4 long-horizon continuation: `SUPERSEDED_AFTER_STAGE1_DUE_PRIOR_SCOPE_SELECTOR_BUG`
- Wave-5 corrected remaining residual closure: `STALLED_AFTER_PARTIAL_STAGE1__H510_PROMOTED_AFTER_STALL`
- Wave-6 stall-recovery continuation: `STALLED_AFTER_ORPHANED_LAUNCHER_SESSION`
- Wave-7 supervised relaunch: `COMPLETED__DETACHED_LAUNCHER_FIX_CONFIRMED`

## 3) Read First

1. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave7_closeout_20260406.md`
2. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave6_root_cause_and_supervised_relaunch_20260406.md`
3. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave7_supervised_relaunch_20260406.md`
4. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave5_stall_closeout_20260406.md`
5. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave6_stall_recovery_20260406.md`
6. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave4_stage1_closeout_and_scope_fix_20260405.md`
7. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave5_remaining_residual_mcmc_closure_20260405.md`
8. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closeout_20260405.md`
9. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave4_residual_mcmc_closure_20260405.md`
10. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
11. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave1_broad_launch_20260404.md`
12. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave2_stage1_closeout_20260404.md`
13. `docs/PLAN__qdesn_static_exdqlm_crossstudy_validation_20260404.md`
14. `config/validation/qdesn_static_exdqlm_crossstudy_defaults.yaml`
15. `config/validation/qdesn_static_exdqlm_crossstudy_grid.csv`
16. `config/validation/qdesn_static_exdqlm_crossstudy_wave7_supervised_relaunch_manifest.yaml`
17. `config/validation/qdesn_static_exdqlm_crossstudy_wave6_stall_recovery_manifest.yaml`
18. `config/validation/qdesn_static_exdqlm_crossstudy_wave5_remaining_residual_mcmc_closure_manifest.yaml`
19. `config/validation/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave_manifest.yaml`
20. `scripts/run_qdesn_static_exdqlm_crossstudy_validation.R`
21. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R`
22. `scripts/run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
23. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
24. `scripts/run_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
25. `scripts/launch_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
26. `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
27. `R/qdesn_static_exdqlm_crossstudy.R`
28. `R/qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave.R`
29. `R/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`

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
11. When a wave stalls, carry forward only completed evidence; do not promote partial profiles.
12. Do not rerun sourced controls if the current residual launcher can score challengers against the carried-forward baseline directly.

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
- residual closure helper:
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
- residual closure manifests:
  - `config/validation/qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave_manifest.yaml`
  - `config/validation/qdesn_static_exdqlm_crossstudy_wave5_remaining_residual_mcmc_closure_manifest.yaml`
  - `config/validation/qdesn_static_exdqlm_crossstudy_wave6_stall_recovery_manifest.yaml`
  - `config/validation/qdesn_static_exdqlm_crossstudy_wave7_supervised_relaunch_manifest.yaml`
- residual closure launcher:
  - `scripts/run_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
- residual closure detached launcher:
  - `scripts/launch_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`
- residual closure healthcheck:
  - `scripts/healthcheck_qdesn_static_exdqlm_crossstudy_residual_mcmc_closure_wave.R`

## 6) Current Debt

Remaining scientific debt is now split more precisely:

1. promoted residual fit FAIL surface on successful roots:
   - `38` fit FAIL rows
   - `32` successful roots
   - `38 / 38` are `mcmc`
   - `31 / 38` are `exal`
   - `7 / 38` are `al`
2. unresolved original Wave-1 hard-root FAIL band:
   - `RESOLVED_IN_WAVE7_BY_J660`
3. residual ridge short-horizon drift slice:
   - `RESOLVED_IN_WAVE4_STAGE1_BY_G530`
4. residual ridge long-horizon ESS slice after `J530`:
   - `6` FAIL rows
   - `6` roots
   - no remaining ridge root-status FAILs
5. residual rhs short-horizon drift slice:
   - `15` FAIL rows
   - `12` roots
6. residual rhs long-horizon ESS slice after `J660`:
   - `17` FAIL rows
   - `14` roots
   - no remaining rhs root-status FAILs

Current highest-value questions:

- can the remaining `6` ridge `tt=1000` `exal/mcmc` comparison-health FAIL rows under `J530` be
  reduced without giving back the now-closed root-status surface?
- can the remaining `15` rhs `tt=100` MCMC FAIL rows be reduced without reopening the retired
  `J620/J630` challenger paths?
- can the remaining `17` rhs `tt=1000` MCMC FAIL rows under `J660` be reduced now that the hard
  root-status FAIL band is closed?
- can the next follow-up operate as a successful-surface comparison-health closure pass rather than
  another root-status recovery wave?

## 7) Current Baseline Map

Shared default baseline:

- keep the shared static defaults as the default baseline everywhere
- the active shared default includes the validated `rhs_trace.rds` fallback so successful
  `rhs_ns` VB fits are not falsely marked `FAIL` when `rhs_run_summary.csv` is missing
- the shared default profile id is:
  - `F500_anchor_patched`

Local promoted baselines:

- ridge `tt=100`:
  - `G530_ridge_tt100_drift_guard_chain1300`
- ridge `tt=1000`:
  - `J530_ridge_tt1000_g530_hybrid_chain1600_retry`
- rhs `tt=100`:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000`:
  - `J660_rhs_tt1000_chain1600_focus`

Current practical read:

- the shared baseline is now the right default only where no local slice winner has already
  beaten it;
- ridge `tt=100` is closed under the completed `G530` winner;
- ridge `tt=1000` now carries `J530`, not the older `H510`, because Wave 7 completed the clean
  retry and justified promotion;
- rhs `tt=100` remains closed under `F610`; `J620` and `J630` are now retired as non-winners on
  that slice;
- rhs `tt=1000` now carries `J660`, not the older `F640`, because Wave 7 cleared the remaining
  root-status FAIL band and won the stage;
- the correct next follow-up is now a comparison-health closure pass over the remaining successful
  MCMC FAIL rows, not another recovery pass over root-status failures.
