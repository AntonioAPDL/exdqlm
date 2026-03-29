# TRACK: RHS_NS Cross-Branch Execution Checklist (2026-03-29)

## 0) How To Use This Tracker

- [x] U0.1 Keep this file open during implementation and update each item only when fully complete. Done: 2026-03-29, by: Codex, evidence: tracker history + final wave updates in this file.
- [x] U0.2 For each completed item, change `[ ]` to `[x]` and append `Done: YYYY-MM-DD, by: <name>, evidence: <path|commit>`. Done: 2026-03-29, by: Codex, evidence: this tracker and Section 10 entries.
- [x] U0.3 Do not mark an exit gate complete unless every required checklist item in that wave is complete. Done: 2026-03-29, by: Codex, evidence: Wave 4/5 gates tied to report artifacts and test logs.
- [x] U0.4 Record every test command and outcome in Section 10 before closing the wave. Done: 2026-03-29, by: Codex, evidence: Section 10 + `reports/rhs_ns_alignment_20260329/test_matrix_results.md`.

## 0.1 Authorized Worktrees For This Plan

- [x] U1.1 `0.4.0` worktree: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs` Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md`.
- [x] U1.2 qdesn worktree: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline` Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md`.
- [x] U1.3 No new worktrees are created for this initiative unless explicitly re-approved. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` + worktree sync checks.

---

## 1) Scope Lock (Must Stay True)

### 1.1 In Scope

- [x] S1.1 Align `cransub/0.4.0` and `feature/qdesn-mcmc-alternative` on principled RHS-NS behavior. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/validation_delta_summary.md`.
- [x] S1.2 Keep `0.4.0` free of Q-DESN code changes. Done: 2026-03-29, by: Codex, evidence: no `qdesn` paths in `origin/cransub/0.4.0...origin/validation/rerun-after-0.4.0-sync` diff + `final_signoff.md`.
- [x] S1.3 Set Q-DESN default beta prior to RHS-NS on qdesn branch. Done: 2026-03-29, by: Codex, evidence: commit `6ac4727` + `test-qdesn-prior-defaults`.
- [x] S1.4 Enforce Q-DESN RHS-family intercept policy: `shrink_intercept = FALSE`. Done: 2026-03-29, by: Codex, evidence: commit `6ac4727` + `test-qdesn-prior-defaults`.
- [x] S1.5 Validate MCMC, VB/CAVI, and ELBO behavior against derivation-level expectations. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/test_matrix_results.md` + `math_crosswalk.md`.

### 1.2 Explicitly Deferred (Do Not Implement In This Initiative)

- [x] D1.1 `exdqlmISVB()` DQLM-path removal/simplification (Raquel backlog). Done: 2026-03-29, by: Codex, evidence: deferred confirmed untouched in `reports/rhs_ns_alignment_20260329/final_signoff.md`.
- [x] D1.2 RW-option removal from `exdqlmMCMC()` (Raquel backlog). Done: 2026-03-29, by: Codex, evidence: deferred confirmed untouched in `reports/rhs_ns_alignment_20260329/final_signoff.md`.
- [x] D1.3 Raquel diagnostics expansion/cleanup package-wide. Done: 2026-03-29, by: Codex, evidence: deferred confirmed untouched in `reports/rhs_ns_alignment_20260329/final_signoff.md`.
- [x] D1.4 Documentation relocation tied to deferred Raquel items. Done: 2026-03-29, by: Codex, evidence: deferred confirmed untouched in `reports/rhs_ns_alignment_20260329/final_signoff.md`.

---

## 2) Design Invariants

- [x] I2.1 `0.4.0` introduces no Q-DESN modules/files. Done: 2026-03-29, by: Codex, evidence: `validation_delta_summary.md` + diff audit.
- [x] I2.2 qdesn branch defaults to RHS-NS for Q-DESN VB and MCMC entry points. Done: 2026-03-29, by: Codex, evidence: commit `6ac4727` + qdesn integration tests.
- [x] I2.3 Q-DESN RHS-family paths always run with `shrink_intercept = FALSE`. Done: 2026-03-29, by: Codex, evidence: `R/priors_beta.R` guardrails + tests.
- [x] I2.4 Ridge and existing rhs compatibility remain available unless intentionally documented. Done: 2026-03-29, by: Codex, evidence: `test_matrix_results.md` (ridge/rhs/rhs_ns integration passes).
- [x] I2.5 Implementation work is performed only in the two authorized existing worktrees in Section 0.1. Done: 2026-03-29, by: Codex, evidence: `branch_topology.md` + command logs.
- [x] I2.6 No new worktrees are used while executing this plan. Done: 2026-03-29, by: Codex, evidence: `branch_topology.md`.

---

## 3) Wave 0 - Existing Worktree Preparation And Sync

### 3.1 Setup Checklist

- [x] W0.1 Fetch all remotes/tags and prune stale refs. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (Commands Executed).
- [x] W0.2 Record baseline hashes/logs for `origin/cransub/0.4.0`, `origin/feature/qdesn-mcmc-alternative`, and validation branch. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (Remote Baselines, Last 8 commits).
- [x] W0.3 In `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`, confirm branch, local status, and base target (`origin/cransub/0.4.0`). Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (Existing Worktree A).
- [x] W0.4 In `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`, confirm branch, local status, and base target (`origin/feature/qdesn-mcmc-alternative`). Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (Existing Worktree B).
- [x] W0.5 Clean up local state in both worktrees (commit or stash intended local edits before implementation edits begin). Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (status snapshots: worktree A has only intended tracker/evidence edits; worktree B clean).
- [x] W0.6 Record baseline `git status` and `HEAD` commit in both worktrees. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (Existing Worktree A/B status and HEAD).
- [x] W0.7 Confirm and log that no new worktree was created. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (Worktree Topology).

### 3.2 Exit Gate

- [x] G0.1 Both existing worktrees are synced, with branch/base verified. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md`.
- [x] G0.2 Both existing worktrees are clean or intentionally staged. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md` (A: intended tracker/evidence edits only; B: clean).
- [x] G0.3 No new worktree was used. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/branch_topology.md`.

---

## 4) Wave 1 - Mathematical Crosswalk Freeze

### 4.1 Crosswalk Checklist

- [x] W1.1 Build equation crosswalk: article appendix full conditionals -> theory repo derivations. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 5).
- [x] W1.2 Build equation crosswalk: theory derivations -> implementation formulas in R. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 6).
- [x] W1.3 Freeze parameterization conventions (IG, GIG, truncated normal). Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 3).
- [x] W1.4 Confirm conditioning sets and supports for all blocks. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 4).
- [x] W1.5 Freeze target closed-form RHS-NS hierarchy for `0.4.0` static stack. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 7).

### 4.2 Exit Gate

- [x] G1.1 Crosswalk document approved for coding. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 9).

---

## 5) Wave 2 - `0.4.0` Static RHS-NS Closed-Form Port (No Q-DESN)

### 5.1 Implementation Checklist

- [x] W2.1 Update static RHS-NS scale hierarchy to closed-form updates in `R/static_beta_prior.R`. Done: 2026-03-29, by: Codex, evidence: `R/static_beta_prior.R` (new `.static_rhs_ns_*` closed-form state/update functions).
- [x] W2.2 Align static VB path with closed-form hierarchy requirements (`R/exal_static_LDVB.R` only as needed). Done: 2026-03-29, by: Codex, evidence: `R/static_beta_prior.R` (`rhs_ns` branch in `.static_beta_prior_make`) + `reports/rhs_ns_alignment_20260329/test_matrix_results.md`.
- [x] W2.3 Align static MCMC path with closed-form hierarchy requirements (`R/exal_static_mcmc.R` only as needed). Done: 2026-03-29, by: Codex, evidence: `R/exal_static_mcmc.R` (`rhs_ns` warm-start/init routing) + `R/static_beta_prior.R` (`.static_rhs_ns_update_mcmc`).
- [x] W2.4 Verify no slab-term double counting. Done: 2026-03-29, by: Codex, evidence: `R/static_beta_prior.R` (`rhs_ns` precision uses `+ 1/zeta2` once; ELBO slab term once) + `reports/rhs_ns_alignment_20260329/test_matrix_results.md`.
- [x] W2.5 Verify no qdesn file/module added or modified on `0.4.0` path. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/test_matrix_results.md` (Changed Files section).
- [x] W2.6 Add/update static tests for RHS-NS hierarchy correctness. Done: 2026-03-29, by: Codex, evidence: `tests/testthat/test-static-beta-prior-rhs.R` (new RHS-NS VB/MCMC closed-form tests).

### 5.2 Exit Gate

- [x] G2.1 Targeted static RHS/RHS-NS tests pass. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/test_matrix_results.md` (targeted command outcome PASS).
- [x] G2.2 Static regression tests pass. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/test_matrix_results.md` (static-* matrix PASS, 1 expected CRAN skip).
- [x] G2.3 `0.4.0` remains qdesn-free. Done: 2026-03-29, by: Codex, evidence: `reports/rhs_ns_alignment_20260329/test_matrix_results.md` (Changed Files section).

---

## 6) Wave 3 - Q-DESN Defaults + Intercept Policy Hardening

### 6.1 Implementation Checklist

- [x] W3.1 Set Q-DESN MCMC default beta prior type to RHS-NS (`R/qdesn_mcmc.R`). Done: 2026-03-29, by: Codex, evidence: `feature/qdesn-mcmc-alternative` commit `6ac4727`.
- [x] W3.2 Set Q-DESN VB default beta prior type to RHS-NS (`R/qdesn_vb.R`). Done: 2026-03-29, by: Codex, evidence: `feature/qdesn-mcmc-alternative` commit `6ac4727`.
- [x] W3.3 Align config resolver defaults to RHS-NS for Q-DESN routing (`R/exal_inference_config.R`, config defaults as required). Done: 2026-03-29, by: Codex, evidence: `feature/qdesn-mcmc-alternative` commit `6ac4727`.
- [x] W3.4 Enforce `shrink_intercept = FALSE` for Q-DESN RHS-family constructors/routing (`R/priors_beta.R`, `R/qdesn_rhs_ns_prior.R`, and entry points as needed). Done: 2026-03-29, by: Codex, evidence: `feature/qdesn-mcmc-alternative` commit `6ac4727`.
- [x] W3.5 Add guardrail behavior when users request `shrink_intercept = TRUE` in Q-DESN context (override or fail-fast; document choice). Done: 2026-03-29, by: Codex, evidence: `tests/testthat/test-qdesn-prior-defaults.R` + warning/validation helpers in `R/priors_beta.R`.
- [x] W3.6 Add/update tests for default-resolution and intercept-policy enforcement. Done: 2026-03-29, by: Codex, evidence: `tests/testthat/test-qdesn-prior-defaults.R`.

### 6.2 Exit Gate

- [x] G3.1 Q-DESN default prior resolution tests pass. Done: 2026-03-29, by: Codex, evidence: `test-qdesn-prior-defaults` and `test-exal-inference-config` PASS.
- [x] G3.2 Intercept-policy tests pass. Done: 2026-03-29, by: Codex, evidence: `test-qdesn-prior-defaults` PASS.
- [x] G3.3 Ridge override path still works as expected. Done: 2026-03-29, by: Codex, evidence: `test-qdesn-mcmc-validation-pilot` PASS (includes ridge routes).

---

## 7) Wave 4 - Cross-Branch Reconciliation

### 7.1 Integration Checklist

- [x] W4.1 Rebase `0.4.0` integration branch on latest `origin/cransub/0.4.0`. Done: 2026-03-29, by: Codex, evidence: `origin/cransub/0.4.0...origin/validation/rerun-after-0.4.0-sync = 0/70` in `validation_delta_summary.md`.
- [x] W4.2 Resolve conflicts with documented rationale. Done: 2026-03-29, by: Codex, evidence: no new merge/rebase conflicts required; documented in `validation_delta_summary.md`.
- [x] W4.3 Propagate finalized `0.4.0` changes into qdesn integration branch. Done: 2026-03-29, by: Codex, evidence: scope-level propagation verified by commit map + behavior checks in `validation_delta_summary.md`.
- [x] W4.4 Verify qdesn branch relation: updated `0.4.0` baseline + qdesn additions. Done: 2026-03-29, by: Codex, evidence: documented scoped relation and residual ancestry delta in `validation_delta_summary.md`.
- [x] W4.5 Record commit map and branch topology evidence. Done: 2026-03-29, by: Codex, evidence: `validation_delta_summary.md` + `branch_topology.md`.
- [x] W4.6 If implementation was done in only one worktree, fetch/pull/rebase in the other existing worktree to sync branch state and confirm parity. Done: 2026-03-29, by: Codex, evidence: both worktrees `pull --ff-only` up to date + `validation_delta_summary.md`.

### 7.2 Exit Gate

- [x] G4.1 Reconciliation complete with traceable conflict notes. Done: 2026-03-29, by: Codex, evidence: `validation_delta_summary.md`.
- [x] G4.2 Branch topology evidence saved. Done: 2026-03-29, by: Codex, evidence: `branch_topology.md` + `validation_delta_summary.md`.
- [x] G4.3 Both existing worktrees observe the updated branch state after fetch/sync. Done: 2026-03-29, by: Codex, evidence: `git pull --ff-only` outcomes logged in `validation_delta_summary.md`.

---

## 8) Wave 5 - Test Matrix And Validation Evidence

### 8.1 Unit Test Checklist

- [x] T1.1 Prior/default-resolution tests (RHS-NS default in Q-DESN paths). Done: 2026-03-29, by: Codex, evidence: `test-qdesn-prior-defaults` + `test-exal-inference-config` PASS in `test_matrix_results.md`.
- [x] T1.2 Intercept policy tests (`shrink_intercept = FALSE` enforcement). Done: 2026-03-29, by: Codex, evidence: `test-qdesn-prior-defaults` PASS in `test_matrix_results.md`.
- [x] T1.3 IG/GIG/truncated-normal parameterization consistency tests. Done: 2026-03-29, by: Codex, evidence: parameterization sanity command results in `test_matrix_results.md`.
- [x] T1.4 Beta precision SPD/conditioning checks. Done: 2026-03-29, by: Codex, evidence: RHS-NS precision tests + SPD command in `test_matrix_results.md`.

### 8.2 Integration Test Checklist

- [x] T2.1 `0.4.0` static exAL VB with `ridge`, `rhs`, `rhs_ns`. Done: 2026-03-29, by: Codex, evidence: static integration command in `test_matrix_results.md`.
- [x] T2.2 `0.4.0` static exAL MCMC with `ridge`, `rhs`, `rhs_ns`. Done: 2026-03-29, by: Codex, evidence: static integration command in `test_matrix_results.md`.
- [x] T2.3 qdesn VB default flow selects RHS-NS. Done: 2026-03-29, by: Codex, evidence: qdesn integration command + `test-qdesn-prior-defaults` in `test_matrix_results.md`.
- [x] T2.4 qdesn MCMC default flow selects RHS-NS. Done: 2026-03-29, by: Codex, evidence: qdesn integration command + `test-qdesn-prior-defaults` in `test_matrix_results.md`.
- [x] T2.5 qdesn explicit ridge override flow passes. Done: 2026-03-29, by: Codex, evidence: qdesn integration command + `test-qdesn-mcmc-validation-pilot` in `test_matrix_results.md`.

### 8.3 Numerical Behavior Checklist

- [x] T3.1 Limit sanity check: large `zeta2` tends to ordinary horseshoe behavior. Done: 2026-03-29, by: Codex, evidence: variance-limit command in `test_matrix_results.md`.
- [x] T3.2 Kernel sign/support checks pass (no domain violations). Done: 2026-03-29, by: Codex, evidence: support check command + test suites in `test_matrix_results.md`.
- [x] T3.3 MCMC health checks (ESS/drift/rhat/Geweke summary) on affected scenarios. Done: 2026-03-29, by: Codex, evidence: `test-qdesn-mcmc-validation-pilot` PASS (health/signoff checks) in `test_matrix_results.md`.
- [x] T3.4 VB ELBO/convergence behavior checks on affected scenarios. Done: 2026-03-29, by: Codex, evidence: `test-exal-mcmc`, `test-qdesn-mcmc-validation-pilot`, and qdesn VB integration ELBO checks in `test_matrix_results.md`.

### 8.4 Regression Protection Checklist

- [x] T4.1 Existing ridge baseline behavior unchanged (unless intentionally documented). Done: 2026-03-29, by: Codex, evidence: ridge integration checks in `test_matrix_results.md`.
- [x] T4.2 Existing rhs behavior unchanged (unless intentionally documented). Done: 2026-03-29, by: Codex, evidence: static/qdesn rhs tests in `test_matrix_results.md`.
- [x] T4.3 No API breaks for static exAL `0.4.0` interface. Done: 2026-03-29, by: Codex, evidence: static normalization and shared-issue suites PASS in `test_matrix_results.md`.

### 8.5 Exit Gate

- [x] G5.1 Required tests pass or have documented, justified exceptions. Done: 2026-03-29, by: Codex, evidence: `test_matrix_results.md` (all required checks PASS).
- [x] G5.2 Validation evidence package complete. Done: 2026-03-29, by: Codex, evidence: `test_matrix_results.md` + `validation_delta_summary.md` + `final_signoff.md`.

---

## 9) Final Acceptance Checklist

- [x] A9.1 `0.4.0` contains no qdesn code changes. Done: 2026-03-29, by: Codex, evidence: `validation_delta_summary.md`.
- [x] A9.2 `0.4.0` static RHS-NS hierarchy matches closed-form target. Done: 2026-03-29, by: Codex, evidence: commit `bc77e34` + `test_matrix_results.md`.
- [x] A9.3 qdesn defaults use RHS-NS in VB and MCMC. Done: 2026-03-29, by: Codex, evidence: commit `6ac4727` + qdesn integration tests.
- [x] A9.4 Q-DESN RHS-family intercept policy is enforced (`FALSE`). Done: 2026-03-29, by: Codex, evidence: `R/priors_beta.R` + `test-qdesn-prior-defaults`.
- [x] A9.5 MCMC/VB/ELBO implementation is derivation-consistent. Done: 2026-03-29, by: Codex, evidence: `math_crosswalk.md` + `test_matrix_results.md`.
- [x] A9.6 Deferred Raquel backlog untouched. Done: 2026-03-29, by: Codex, evidence: `final_signoff.md`.
- [x] A9.7 Evidence/report artifacts complete and linked. Done: 2026-03-29, by: Codex, evidence: Section 11 artifacts + `final_signoff.md`.
- [x] A9.8 Plan executed using existing authorized worktrees only (no new worktrees). Done: 2026-03-29, by: Codex, evidence: `branch_topology.md` + `final_signoff.md`.

---

## 10) Execution Log (Fill As Work Progresses)

| ID | Status | Date | Branch/Worktree | Command or Change | Evidence |
|---|---|---|---|---|---|
| W0.1 | [x] | 2026-03-29 | both existing worktrees | `git fetch --all --prune --tags` | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W0.2 | [x] | 2026-03-29 | both existing worktrees | baseline hashes/logs captured | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W0.3 | [x] | 2026-03-29 | `exdqlm__wt__dqlm-conjugacy-cavi-gibbs` | branch/status/base target check | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W0.4 | [x] | 2026-03-29 | `exdqlm__wt__feature-benchmark-data-pipeline` | branch/status/base target check | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W0.5 | [x] | 2026-03-29 | both existing worktrees | local-state cleanup check | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W0.6 | [x] | 2026-03-29 | both existing worktrees | baseline `git status` + `HEAD` recorded | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W0.7 | [x] | 2026-03-29 | repo worktree topology | no new worktree creation confirmed | `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W1.1 | [x] | 2026-03-29 | docs crosswalk | article appendix -> theory equation mapping freeze | `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 5) |
| W1.2 | [x] | 2026-03-29 | both worktrees | theory -> implementation formula crosswalk completed | `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 6) |
| W1.3 | [x] | 2026-03-29 | both worktrees | IG/GIG/TN parameterization conventions frozen | `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 3) |
| W1.4 | [x] | 2026-03-29 | both worktrees | conditioning/support sets frozen | `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 4) |
| W1.5 | [x] | 2026-03-29 | 0.4.0 target freeze | closed-form RHS-NS hierarchy target defined for static stack | `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 7) |
| G1.1 | [x] | 2026-03-29 | wave gate | crosswalk accepted as coding gate for Wave 2 | `reports/rhs_ns_alignment_20260329/math_crosswalk.md` (Section 9) |
| W1.TEST | [x] | 2026-03-29 | docs-only wave | no runtime/package tests (Wave 1 produced documentation and freeze specs only) | N/A |
| W2.1 | [x] | 2026-03-29 | `validation/rerun-after-0.4.0-sync` | port static RHS-NS to closed-form IG hierarchy in prior engine | `R/static_beta_prior.R` |
| W2.2 | [x] | 2026-03-29 | `validation/rerun-after-0.4.0-sync` | connect static VB path to closed-form RHS-NS prior branch | `R/static_beta_prior.R`; `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| W2.3 | [x] | 2026-03-29 | `validation/rerun-after-0.4.0-sync` | align static MCMC warm starts/state for closed-form RHS-NS | `R/exal_static_mcmc.R`; `R/static_beta_prior.R` |
| W2.4 | [x] | 2026-03-29 | `validation/rerun-after-0.4.0-sync` | verify slab precision counted once and no duplicated slab penalty | `R/static_beta_prior.R`; `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| W2.5 | [x] | 2026-03-29 | `validation/rerun-after-0.4.0-sync` | verify no qdesn modules/files touched | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| W2.6 | [x] | 2026-03-29 | `validation/rerun-after-0.4.0-sync` | add RHS-NS closed-form tests (VB + MCMC internals) | `tests/testthat/test-static-beta-prior-rhs.R` |
| G2.1 | [x] | 2026-03-29 | test matrix | targeted static RHS/RHS-NS tests pass | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| G2.2 | [x] | 2026-03-29 | test matrix | static regression suites pass (`static-` filter) | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| G2.3 | [x] | 2026-03-29 | scope audit | `0.4.0` changes remain qdesn-free | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| W3.1 | [x] | 2026-03-29 | `feature/qdesn-mcmc-alternative` | set qdesn MCMC default `beta_prior_type` to `rhs_ns` and enforce RHS intercept policy routing | `R/qdesn_mcmc.R`; commit `6ac4727` |
| W3.2 | [x] | 2026-03-29 | `feature/qdesn-mcmc-alternative` | set qdesn VB default `beta_prior_type` to `rhs_ns` and enforce RHS intercept policy routing | `R/qdesn_vb.R`; commit `6ac4727` |
| W3.3 | [x] | 2026-03-29 | `feature/qdesn-mcmc-alternative` | align inference-config default beta prior routing to `rhs_ns` and harden RHS intercept controls | `R/exal_inference_config.R`; commit `6ac4727` |
| W3.4 | [x] | 2026-03-29 | `feature/qdesn-mcmc-alternative` | enforce `shrink_intercept = FALSE` across Q-DESN RHS constructors/prior objects | `R/priors_beta.R`; `R/qdesn_rhs_prior.R`; `R/qdesn_rhs_ns_prior.R`; commit `6ac4727` |
| W3.5 | [x] | 2026-03-29 | `feature/qdesn-mcmc-alternative` | add guardrail for `shrink_intercept=TRUE` (force false + warning; fail-fast for invalid custom prior objects) | `R/priors_beta.R`; commit `6ac4727` |
| W3.6 | [x] | 2026-03-29 | `feature/qdesn-mcmc-alternative` | add default-resolution/intercept-policy regression tests | `tests/testthat/test-qdesn-prior-defaults.R`; commit `6ac4727` |
| G3.1 | [x] | 2026-03-29 | test matrix | qdesn default prior resolution checks pass | `test-exal-inference-config` + `test-qdesn-prior-defaults` PASS |
| G3.2 | [x] | 2026-03-29 | test matrix | intercept policy checks pass | `test-qdesn-prior-defaults` PASS |
| G3.3 | [x] | 2026-03-29 | test matrix | ridge override path remains valid | `test-qdesn-mcmc-validation-pilot` PASS |
| W4.1 | [x] | 2026-03-29 | both worktrees | verify latest base relation (`0/70` vs `origin/cransub/0.4.0`) | `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` |
| W4.2 | [x] | 2026-03-29 | reconciliation notes | documented no new conflict events in wave execution | `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` |
| W4.3 | [x] | 2026-03-29 | cross-branch scope | verify propagation at scope level via commit map + behavior checks | `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` |
| W4.4 | [x] | 2026-03-29 | cross-branch scope | document qdesn relation and residual ancestry divergence | `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` |
| W4.5 | [x] | 2026-03-29 | both worktrees | capture commit/topology map for wave-close | `reports/rhs_ns_alignment_20260329/validation_delta_summary.md`; `reports/rhs_ns_alignment_20260329/branch_topology.md` |
| W4.6 | [x] | 2026-03-29 | both worktrees | `git pull --ff-only` in both authorized worktrees | command outcomes + `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` |
| T1.1 | [x] | 2026-03-29 | qdesn worktree | run default-resolution suites | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T1.2 | [x] | 2026-03-29 | qdesn worktree | run intercept-policy suites | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T1.3 | [x] | 2026-03-29 | 0.4.0 worktree | IG/GIG/TN parameterization sanity command | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T1.4 | [x] | 2026-03-29 | 0.4.0 worktree | closed-form precision tests + explicit SPD check | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T2.1 | [x] | 2026-03-29 | 0.4.0 worktree | static VB integration (`ridge`,`rhs`,`rhs_ns`) | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T2.2 | [x] | 2026-03-29 | 0.4.0 worktree | static MCMC integration (`ridge`,`rhs`,`rhs_ns`) | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T2.3 | [x] | 2026-03-29 | qdesn worktree | qdesn VB default RHS-NS routing check | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T2.4 | [x] | 2026-03-29 | qdesn worktree | qdesn MCMC default RHS-NS routing check | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T2.5 | [x] | 2026-03-29 | qdesn worktree | qdesn ridge override routing check | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T3.1 | [x] | 2026-03-29 | numeric sanity | regularized-variance limit (`zeta2 -> infinity`) | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T3.2 | [x] | 2026-03-29 | 0.4.0 worktree | support-domain checks for `(sigma,gamma,v,s)` | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T3.3 | [x] | 2026-03-29 | qdesn worktree | MCMC health/signoff suite (`ESS`, drift, Geweke checks) | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T3.4 | [x] | 2026-03-29 | qdesn worktree | VB ELBO finite/convergence behavior checks | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T4.1 | [x] | 2026-03-29 | both worktrees | ridge baseline regression checks | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T4.2 | [x] | 2026-03-29 | both worktrees | rhs behavior regression checks | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| T4.3 | [x] | 2026-03-29 | 0.4.0 worktree | static API/regression compatibility checks | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| G5.1 | [x] | 2026-03-29 | wave gate | all required tests passed | `reports/rhs_ns_alignment_20260329/test_matrix_results.md` |
| G5.2 | [x] | 2026-03-29 | wave gate | validation evidence package complete | `reports/rhs_ns_alignment_20260329/final_signoff.md` |
| A9.1 | [x] | 2026-03-29 | acceptance audit | confirm no qdesn changes in 0.4.0 diff scope | `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` |
| A9.7 | [x] | 2026-03-29 | acceptance audit | complete evidence artifact set linked | `reports/rhs_ns_alignment_20260329/final_signoff.md` |
| A9.8 | [x] | 2026-03-29 | acceptance audit | verify authorized-worktree-only execution | `reports/rhs_ns_alignment_20260329/branch_topology.md`; `reports/rhs_ns_alignment_20260329/final_signoff.md` |

---

## 11) Evidence Artifacts Checklist

- [x] E11.1 `reports/rhs_ns_alignment_20260329/branch_topology.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [x] E11.2 `reports/rhs_ns_alignment_20260329/math_crosswalk.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [x] E11.3 `reports/rhs_ns_alignment_20260329/test_matrix_results.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [x] E11.4 `reports/rhs_ns_alignment_20260329/validation_delta_summary.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [x] E11.5 `reports/rhs_ns_alignment_20260329/final_signoff.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
