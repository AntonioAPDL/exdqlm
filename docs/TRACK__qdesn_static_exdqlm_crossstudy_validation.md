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

Status: **Wave 6 is now treated as an orphaned launcher-session stall, not a scientific invalidation;
the root cause was traced to non-detached supervision; Wave 7 supervised relaunch is now live under
detached launcher control (`qdesn-static-exdqlm-crossstudy-residualmcmc-20260406-032836__git-b0dc6ca`)**

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

Promoted current baseline map:

- shared default:
  - `F500_anchor_patched`
- local ridge `tt=100` baseline:
  - `G530_ridge_tt100_drift_guard_chain1300`
- local ridge `tt=1000` baseline:
  - `H510_ridge_tt1000_local_control`
- local rhs `tt=100` baseline:
  - `F610_rhs_tt100_conservative_block`
- local rhs `tt=1000` baseline:
  - `F640_rhs_tt1000_chain1200`

Main current takeaways:

- the old `rhs_ns` VB diagnostics-path false-FAIL bucket remains closed under the shared baseline;
- Wave 5 Stage 1 completed two valid ridge `tt=1000` candidates before stalling in `H530`;
- `H510` clearly improved the carried-forward baseline on that slice:
  - Stage-1 fit FAIL rows: `12 -> 7`
  - Stage-1 fail roots: `12 -> 7`
  - Stage-1 root-status FAIL roots: `3 -> 0`
  - Stage-1 compare-full roots: `0 / 15 -> 8 / 15`
- `H520` was a clear loser and should not be rerun;
- `H530` is unresolved because the run died mid-profile after partial VB output only;
- the effective remaining debt after promoting `H510` is now:
  - `37` promoted fit FAIL rows on successful roots,
  - `33` affected roots,
  - all `37 / 37` are `mcmc`,
  - `33 / 37` are `exal`,
  - `4 / 37` are `al`,
  - only `3` unresolved root-status FAIL roots remain, all on `rhs_ns` hard roots;
- the remaining problem is not one generic family-wide tuning question anymore;
- the remaining problem is now one narrow ridge `tt=1000` residual slice plus two rhs residual
  slices, with local tuning only where it still buys down real FAIL debt.

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
- Wave-7 supervised relaunch: `LIVE_UNDER_DETACHED_LAUNCHER`

## 3) Read First

1. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave6_root_cause_and_supervised_relaunch_20260406.md`
2. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave7_supervised_relaunch_20260406.md`
3. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave5_stall_closeout_20260406.md`
4. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave6_stall_recovery_20260406.md`
5. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave4_stage1_closeout_and_scope_fix_20260405.md`
6. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave5_remaining_residual_mcmc_closure_20260405.md`
7. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closeout_20260405.md`
8. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave4_residual_mcmc_closure_20260405.md`
9. `docs/REPORT__qdesn_static_exdqlm_crossstudy_investigation_20260404.md`
10. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave1_broad_launch_20260404.md`
11. `docs/REPORT__qdesn_static_exdqlm_crossstudy_wave2_stage1_closeout_20260404.md`
12. `docs/PLAN__qdesn_static_exdqlm_crossstudy_wave3_fit_fail_closure_20260404.md`
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
   - `37` fit FAIL rows
   - `33` roots
   - `37 / 37` are `mcmc`
   - `33 / 37` are `exal`
   - `4 / 37` are `al`
2. unresolved original Wave-1 hard-root FAIL band:
   - `3` roots
   - all in `static_shrink x laplace x tt=1000 x rhs_ns`
   - `tau in {0.05, 0.25, 0.95}`
3. residual ridge short-horizon drift slice:
   - `RESOLVED_IN_WAVE4_STAGE1_BY_G530`
4. residual ridge long-horizon ESS slice after `H510`:
   - `7` FAIL rows
   - `7` roots
   - no remaining ridge root-status FAILs
5. residual rhs short-horizon drift slice:
   - `15` FAIL rows
   - `12` roots
6. residual rhs long-horizon ESS slice:
   - `15` FAIL rows
   - `14` roots

Current highest-value questions:

- can a direct `H510`-geometry chain extension remove the remaining `7` ridge `tt=1000`
  `exal/mcmc` residuals more cleanly than the stalled G530-derived long-horizon branch?
- does `H530` deserve one controlled retry now that it is competing against the updated `H510`
  baseline instead of the older `F510` baseline?
- can the carried-forward `H620/H630` rhs short-horizon challengers reduce the remaining
  `tt=100` drift-heavy rhs residuals without replaying chain-only losers?
- can the carried-forward `H650/H660` rhs long-horizon challengers both revalidate the remaining
  `3` rhs hard-root FAILs and reduce the remaining `tt=1000` ESS/autocorrelation rhs residuals?

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
  - `H510_ridge_tt1000_local_control`
- rhs `tt=100`:
  - `F610_rhs_tt100_conservative_block`
- rhs `tt=1000`:
  - `F640_rhs_tt1000_chain1200`

Current practical read:

- the shared baseline is now the right default only where no local slice winner has already
  beaten it;
- ridge `tt=100` is closed under the completed `G530` winner;
- ridge `tt=1000` now carries `H510`, not the older `F510`, because Wave 5 completed enough valid
  evidence to justify promotion before stalling;
- `H520` is retired as a demonstrated loser on the long-horizon ridge slice;
- `H530` is unresolved and should be treated as a retry candidate, not as a promoted result;
- the corrected next follow-up should therefore start from the post-`H510` local-baseline map and
  use remaining stage sizes `7`, `12`, and `17`, not the earlier `15`, `12`, and `17`.
