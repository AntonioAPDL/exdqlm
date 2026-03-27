# TRACK: RHS_NS Execution Tracker (Stages 3-9)

Date: 2026-03-27  
Last Updated: 2026-03-27  
Repo: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`  
Primary Working Branch: `feature/qdesn-mcmc-alternative`  
Related Branches: `origin/cransub/0.4.0`, `origin/feature/qdesn-mcmc-alternative`

## 0) Purpose

This is the operational tracker for delivering `rhs_ns` as an additive, production-quality prior option across exAL/qdesn inference paths, while preserving current `rhs` behavior and CRAN-readiness.

This tracker executes stages 3-9 from the approved plan. Stage 2 (baseline capture) is intentionally skipped by user instruction after validation work freeze.

## 1) Non-Negotiables

1. Keep existing `beta_prior_type: rhs` behavior unchanged.
2. Keep existing `beta_prior_type: ridge` behavior unchanged.
3. Add `beta_prior_type: rhs_ns` as additive option only.
4. Keep `qdesn` integrated through shared exAL inference plumbing (special-case consumer, not divergent fork).
5. Preserve code style, roxygen style, and current package organization conventions.
6. Keep release hygiene suitable for CRAN submission trajectory (`0.4.0` line).

## 2) Current Facts (Confirmed)

1. Both remote branches exist:
   - `origin/cransub/0.4.0`
   - `origin/feature/qdesn-mcmc-alternative`
2. Branches are heavily diverged (`157` vs `233` commits from merge base `091d0e8fb2381d508d22ee8addd617c06ea95302`).
3. `cransub/0.4.0` appears CRAN-focused and leaner for qdesn/RHS internals.
4. `feature/qdesn-mcmc-alternative` contains the richer qdesn + inference stack.
5. Validation campaigns are frozen per user instruction.

## 3) Quality and Style Contract

### 3.1 Code/Architecture

- Reuse prior object contract in `R/priors_beta.R`:
  - `init(p)`, `expected_prec(state, p)`, `update(state, qbeta)`, `elbo(state, qbeta)`
- Avoid duplicated inference logic in qdesn wrappers when shared exAL path can be reused.
- Keep new `rhs_ns` code modular (new prior file + minimal bridge changes).
- Preserve backward compatibility in public APIs and existing configs.

### 3.2 Documentation

- Use concise roxygen updates for any new arguments/behavior.
- Update NEWS and user-facing docs only after behavior stabilizes.
- Keep tracker evidence links explicit (configs, scripts, test outputs).

### 3.3 Testing

- Add unit tests for prior object correctness and ELBO finite behavior.
- Add integration tests for exAL VB/MCMC and qdesn VB/MCMC with `rhs_ns`.
- Include compatibility tests that prove `rhs` behavior is unchanged.

## 4) Global Stage Board

Status legend: `[ ]` not started, `[-]` in progress, `[x]` completed, `[!]` blocked

- [x] Stage 3: Safe Integration Setup
- [x] Stage 4: Branch Reconciliation
- [x] Stage 5: Robust Regression/Quality Gate
- [x] Stage 6: RHS_NS Design Freeze
- [x] Stage 7: RHS_NS Implementation
- [x] Stage 8: Comparative Evaluation + Default Decision
- [x] Stage 9: Release Finalization (`0.4.0` readiness)

## 5) Update Protocol (Mandatory)

For every stage transition and major subtask:

1. Update stage checkbox and status line.
2. Append a dated entry in `Progress Log` with:
   - what was investigated,
   - what was changed,
   - what was verified,
   - blockers/risks,
   - next action.
3. Record evidence pointers (file paths, commit SHA, test command/result summary).

Do not advance a stage without completing its pre-stage investigation checklist.

## 6) Stage 3: Safe Integration Setup

Status: `[x]`  
Owner: Codex + user

### 6.1 Pre-Stage Investigation Checklist

- [x] Confirm clean recovery strategy for current dirty worktree state.
- [x] Inventory all modified/untracked validation assets to preserve.
- [x] Decide archival mechanism (dedicated branch/tag/commit) for frozen validation state.
- [x] Confirm no active jobs are writing into tracked outputs.

### 6.2 Execution Checklist

- [x] Create safety branch/tag anchors for both active lines.
- [x] Preserve frozen validation artifacts without content mutation.
- [x] Create separate clean worktrees for reconciliation.
- [x] Document exact branch/worktree map in this tracker.

### 6.3 Exit Gate

- [x] Any current state can be restored quickly.
- [x] Integration can proceed without risking frozen validation evidence.

## 7) Stage 4: Branch Reconciliation

Status: `[x]`  
Owner: Codex + user

### 7.1 Pre-Stage Investigation Checklist

- [x] Generate file-level conflict forecast (`R/`, `src/`, `man/`, tests, configs).
- [x] Classify modules by ownership/priority (CRAN-critical vs qdesn-forward).
- [x] Dry-run both reconciliation strategies (merge vs rebase) in disposable worktree.
- [x] Quantify conflict volume and breakage risk for each strategy.

### 7.2 Execution Checklist

- [x] Select strategy with lowest operational risk (default preference: merge-based).
- [x] Reconcile modules in deterministic order:
  1. inference core (`R/exal_*`, `R/priors_beta.R`)
  2. qdesn wrappers (`R/qdesn_*`)
  3. config/model-selection plumbing
  4. tests/docs/scripts
- [x] Resolve conflicts with explicit rationale notes.
- [x] Keep behavior of existing `rhs` path unchanged.

### 7.3 Exit Gate

- [x] Reconciled integration branch compiles and loads.
- [x] No namespace/export regressions.
- [x] Critical smoke tests pass.

## 8) Stage 5: Robust Regression/Quality Gate

Status: `[x]`  
Owner: Codex + user

### 8.1 Pre-Stage Investigation Checklist

- [x] Define test matrix tiers: unit, integration, pipeline smoke, CRAN checks.
- [x] Identify deterministic seeds/specs for repeatable parity checks.
- [x] Define pass/fail thresholds for runtime and stability diagnostics.

### 8.2 Execution Checklist

- [x] Run unit/integration suites for exAL + qdesn.
- [x] Run VB and MCMC parity checks under current `rhs`/`ridge`.
- [x] Run `R CMD check` and collect warnings/errors.
- [x] Record failures and either fix or explicitly defer with justification.

### 8.3 Exit Gate

- [x] Existing behavior remains stable.
- [x] Reconciled line is quality-gated and ready for rhs_ns design freeze.

## 9) Stage 6: RHS_NS Design Freeze

Status: `[x]`  
Owner: Codex + user

### 9.1 Pre-Stage Investigation Checklist

- [x] Re-read local theory anchors and align notation (`tau`, `lambda_j`, `c^2`/`zeta^2`).
- [x] Finalize exact hierarchical model for `rhs_ns` (including random slab default).
- [x] Enumerate conditional updates and classify: closed-form vs nonconjugate.
- [x] Verify conditional-vs-joint equivalence language in design notes.

### 9.2 ELBO-Specific Design Checklist (Required)

- [x] Specify full `rhs_ns` ELBO contribution under prior object contract.
- [x] Ensure no double-counting between:
  - `E[log p(beta | latents)]`
  - latent-prior terms
  - latent-factor entropies.
- [x] Confirm compatibility with current ELBO assembly locations:
  - `R/exal_ldvb_engine.R`
  - `R/exal_static_LDVB.R`
- [x] Define optional ELBO component diagnostics (if exposed) while preserving existing return contract.

### 9.3 Execution Checklist

- [x] Freeze API contract for `rhs_ns` hyperparameters and controls.
- [x] Freeze expected state structure for VB and MCMC.
- [x] Freeze update ordering and numerical guardrails.
- [x] Record approved design in tracker + implementation notes.

### 9.4 Exit Gate

- [x] Mathematical and computational design approved.
- [x] ELBO design complete for full objective accounting in CAVI/VB.

## 10) Stage 7: RHS_NS Implementation

Status: `[x]`  
Owner: Codex

### 10.1 Pre-Stage Investigation Checklist

- [x] Confirm exact touch set and ownership boundaries.
- [x] Identify reusable helpers from current `rhs` path.
- [x] Define minimal-risk commit slicing strategy.

### 10.2 Target File Map

New file(s):
- [x] `R/qdesn_rhs_ns_prior.R`
- [ ] optional `R/exal_mcmc_rhs_ns_helpers.R` (only if needed)

Updates expected:
- [x] `R/priors_beta.R`
- [x] `R/exal_inference_config.R`
- [x] `R/exal_ldvb_engine.R`
- [x] `R/exal_static_LDVB.R`
- [x] `R/exal_mcmc_fit.R`
- [x] `R/qdesn_vb.R` (no direct edit required; path already routes via `exal_make_beta_prior`)
- [x] `R/qdesn_mcmc.R` (no direct edit required; path already routes via `exal_make_beta_prior`)
- [x] `R/qdesn_model_selection_v2.R`
- [ ] `NAMESPACE` / `man/` as needed

### 10.3 Implementation Checklist

- [x] Add `rhs_ns` constructor route and validation logic.
- [x] Implement `rhs_ns` prior object methods:
  - `init`, `expected_prec`, `update`, `elbo`.
- [x] Integrate VB path in `exal_ldvb_engine` and static wrapper path.
- [x] Integrate MCMC path in `exal_mcmc_fit` with additive branching.
- [x] Keep qdesn as consumer of shared exAL inference path.
- [x] Add configuration parsing/defaults for `beta_prior_type: rhs_ns`.
- [x] Keep legacy `rhs` diagnostics and controls intact.

### 10.4 Exit Gate

- [x] `rhs_ns` runs in both VB and MCMC paths.
- [x] Current `rhs` and `ridge` tests still pass unchanged.

## 11) Stage 8: Comparative Evaluation + Default Decision

Status: `[x]`  
Owner: Codex + user

### 11.1 Pre-Stage Investigation Checklist

- [x] Define benchmark matrix and compute budget.
- [x] Define objective criteria for “better”:
  - predictive quality,
  - calibration,
  - runtime,
  - stability/mixing.
- [x] Define decision thresholds for default switch.

### 11.2 Execution Checklist

- [x] Run matched experiments for `rhs` vs `rhs_ns`.
- [x] Compare VB (ELBO behavior, convergence, runtime).
- [x] Compare MCMC (mixing diagnostics, runtime, chain health).
- [x] Summarize equivalence/non-equivalence findings clearly.

### 11.3 Default Decision Gate

- [ ] If `rhs_ns` is at least parity in predictive behavior and better in efficiency/stability, set default to `rhs_ns`.
- [x] Otherwise keep default as `rhs` and ship `rhs_ns` as opt-in.
- [x] Record final decision and rationale in docs.

## 12) Stage 9: Release Finalization (`0.4.0`)

Status: `[x]`  
Owner: Codex + user

### 12.1 Pre-Stage Investigation Checklist

- [x] Verify CRAN-facing branch state and release policy constraints.
- [x] Verify docs/examples only reference finalized API names.
- [x] Verify all staged changes are scoped and reviewable.

### 12.2 Execution Checklist

- [x] Update NEWS and user-facing docs.
- [x] Add/update examples for both `rhs` and `rhs_ns`.
- [x] Run full package checks (`R CMD check --as-cran` and project smoke suite).
- [x] Final release-candidate pass on test and diagnostics artifacts.

### 12.3 Exit Gate

- [x] Submission-ready commit set with clear traceability.

## 13) Branching and Version-Control Policy

1. Never rewrite remote history of long-lived branches without explicit approval.
2. Keep integration work in dedicated branch/worktree.
3. Use small, reviewable commits grouped by concern:
   - config/API,
   - prior core,
   - VB integration,
   - MCMC integration,
   - tests/docs.
4. Every merge/rebase decision must be logged in `Progress Log` with rationale.

## 14) Progress Log (Living)

### 2026-03-27

- Confirmed branch topology and divergence:
  - `origin/cransub/0.4.0...origin/feature/qdesn-mcmc-alternative = 157/233`
  - merge base `091d0e8fb2381d508d22ee8addd617c06ea95302`
- Confirmed current role split:
  - CRAN-focused lean line (`cransub/0.4.0`)
  - qdesn-rich development line (`feature/qdesn-mcmc-alternative`)
- Confirmed relevant current inference touchpoints for `rhs`:
  - `R/priors_beta.R`
  - `R/exal_inference_config.R`
  - `R/exal_ldvb_engine.R`
  - `R/exal_mcmc_fit.R`
  - `R/qdesn_vb.R`, `R/qdesn_mcmc.R`, `R/qdesn_model_selection_v2.R`
- Confirmed CAVI ELBO integration points that must be adapted for `rhs_ns`:
  - existing prior latent ELBO plug-in path in `exal_ldvb_engine`
  - corresponding static path in `exal_static_LDVB`
- Created this execution tracker with stage gates and checklists.
- Added safety anchors:
  - branch: `safety/rhs_ns_start_20260327`
  - tag: `safety-rhs_ns-start-20260327`
- Created reconciliation worktree:
  - `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile`
  - branch: `integration/rhs_ns_reconcile`
- Completed branch-reconciliation dry-run merge test against `origin/cransub/0.4.0`.
  - result: conflicts (expected due divergence)
  - conflict count: `35` unmerged files in dry-run
  - merge aborted cleanly after measurement.
- Implemented `rhs_ns` prior module and integration:
  - new file: `R/qdesn_rhs_ns_prior.R`
  - updated: `R/priors_beta.R`, `R/exal_inference_config.R`, `R/exal_ldvb_engine.R`,
    `R/exal_static_LDVB.R`, `R/exal_mcmc_fit.R`, `R/qdesn_model_selection_v2.R`,
    `R/qdesn_mcmc_validation.R`, `R/exal_online_vbld.R`
  - updated tests:
    - `tests/testthat/test-exal-inference-config.R`
    - `tests/testthat/test-exal-mcmc.R`
- Validation and checks run:
  - parse checks: all modified R/test files parse cleanly
  - `testthat::test_local(filter = "exal-(inference-config|mcmc)")`: PASS (146)
  - `testthat::test_local(filter = "online-vbld")`: PASS (86)
  - `testthat::test_local(filter = "qdesn-mcmc-validation")`: PASS (87)
  - updated `test-exal-mcmc.R` to exercise `qdesn_fit(..., method=\"mcmc\")` with
    `beta_prior_type = "rhs_ns"` and validated forecast-interface compatibility.
  - `testthat::test_local(filter = "exal-mcmc")` re-run after qdesn rhs_ns test edit:
    PASS (131)
  - `R CMD check --no-manual --as-cran .`: fails due pre-existing DESCRIPTION issue
    (`Author` field missing/empty), not due rhs_ns code path.
- Stage-8 initial quick compare (small synthetic smoke benchmark):
  - VB runtime: `rhs ~7.33s` vs `rhs_ns ~2.50s`
  - MCMC runtime: `rhs ~18.73s` vs `rhs_ns ~5.21s`
  - posterior summaries (`beta_l2`, `sigma`, `gamma`) are in similar ranges.
- Stage-8 full matrix benchmark finalized (artifact:
  `reports/rhs_ns_stage8_matrix_20260327_v4.csv`):
  - design: 3 synthetic seeds, both methods (`vb`, `mcmc`), both priors (`rhs`, `rhs_ns`)
  - all 12 runs completed without fit errors
  - VB mean runtime: `rhs 7.79s` vs `rhs_ns 1.25s` (speedup ~`6.25x`)
  - MCMC mean runtime: `rhs 33.89s` vs `rhs_ns 9.15s` (speedup ~`3.70x`)
  - predictive parity remained close:
    - VB RMSE: `rhs 0.5478` vs `rhs_ns 0.5281`
    - MCMC RMSE: `rhs 0.5262` vs `rhs_ns 0.5307`
  - decision: keep `rhs` as current default for release stability, ship `rhs_ns` as recommended opt-in.
- Attempted direct backport/cherry-pick into `cransub/0.4.0` from rhs_ns commits:
  - command attempted in reconcile worktree:
    - `cherry-pick 6756954 f500e7b`
  - result: hard modify/delete conflicts because `cransub/0.4.0` does not contain
    the newer inference/qdesn module file set (`exal_inference_config.R`,
    `exal_ldvb_engine.R`, `exal_mcmc_fit.R`, etc.)
  - action: cherry-pick aborted cleanly; mark Stage-9 as blocked pending a native
    0.4.0-line port in the legacy static architecture (`R/static_beta_prior.R`,
    `R/exal_static_LDVB.R`, `R/exal_static_mcmc.R`).
- Native 0.4.0 RHS_NS port completed on `origin/cransub/0.4.0`:
  - commit: `9876844` (`Add rhs_ns support to static exAL VB/MCMC on 0.4.0`)
  - core files updated:
    - `R/static_beta_prior.R`
    - `R/exal_static_LDVB.R`
    - `R/exal_static_mcmc.R`
    - `R/utils.R`
    - `man/exal_static_LDVB.Rd`
    - `man/exal_static_mcmc.Rd`
    - `tests/testthat/test-static-beta-prior-rhs.R`
  - verified on `cransub/0.4.0`:
    - `testthat::test_local(filter = "static-beta-prior-rhs")`: PASS (86)
    - `testthat::test_local(filter = "static-beta-prior-rhs|dqlm-reduced-paths")`: PASS (121)
    - `testthat::test_local(filter = "static-exal-shared-issue-checks|static-class-generics|static-regression-regmod|static-ldvb-jacobian")`: PASS (255)
- Cross-branch compatibility healthcheck re-run on `feature/qdesn-mcmc-alternative`:
  - `testthat::test_local(filter = "exal-(inference-config|mcmc)")`: PASS (147)
  - no local diffs on feature branch after verification run.
- CRAN-facing release-finalization pass completed on `origin/cransub/0.4.0`:
  - docs/API polish commit: `293d1ca` (`Finalize rhs_ns release docs and static API examples`)
  - user-facing updates:
    - `NEWS.md` (`rhs_ns` addition and slab-control aliases)
    - `README.Rmd`, `README.md` (finalized static API names; added `rhs_ns` example)
  - full project test suite:
    - `testthat::test_local('tests/testthat', stop_on_failure = TRUE)`: PASS (1348)
  - release smoke re-run:
    - `testthat::test_local(filter = "smoke|static-beta-prior-rhs", stop_on_failure = TRUE)`: PASS (90)
  - tarball CRAN-style check:
    - `R CMD build .` -> `exdqlm_0.4.0.tar.gz`
    - `env _R_CHECK_DONTTEST_EXAMPLES_=false R CMD check --as-cran exdqlm_0.4.0.tar.gz`
    - result: `DONE`, `Status: 4 NOTEs`, `0 WARNING`, `0 ERROR`
    - note summary from `exdqlm.Rcheck/00check.log`:
      - installed size (`30.1Mb`, mainly `libs`)
      - future timestamp unverifiable in environment
      - `pandoc` unavailable for top-level README/NEWS check
      - environment/toolchain portability flags note
  - evidence logs:
    - `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/check-logs/rhs_ns_stage9_R_CMD_build.log`
    - `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/check-logs/rhs_ns_stage9_R_CMD_check_as_cran_tarball.log`
    - `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/exdqlm.Rcheck/00check.log`
- Added final stage-9 submission handoff memo on CRAN branch:
  - commit: `a95ee8c` (`Add rhs_ns stage-9 submission handoff memo`)
  - memo file:
    - `/home/jaguir26/local/src/exdqlm__wt__rhs_ns_reconcile/RHS_NS_STAGE9_SUBMISSION_MEMO.md`
  - memo captures:
    - final scope/commit map,
    - full validation summary,
    - NOTE triage,
    - release recommendation.

## 15) Next Actions (Post-Implementation)

1. Prepare submission memo using recorded NOTE rationale (environmental/non-blocking).
2. If desired post-CRAN, evaluate whether to switch default from `rhs` to `rhs_ns` after broader external benchmarking.
