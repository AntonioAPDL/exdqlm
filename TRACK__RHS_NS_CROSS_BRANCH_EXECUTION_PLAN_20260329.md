# TRACK: RHS_NS Cross-Branch Execution Checklist (2026-03-29)

## 0) How To Use This Tracker

- [ ] U0.1 Keep this file open during implementation and update each item only when fully complete.
- [ ] U0.2 For each completed item, change `[ ]` to `[x]` and append `Done: YYYY-MM-DD, by: <name>, evidence: <path|commit>`.
- [ ] U0.3 Do not mark an exit gate complete unless every required checklist item in that wave is complete.
- [ ] U0.4 Record every test command and outcome in Section 10 before closing the wave.

## 0.1 Authorized Worktrees For This Plan

- [ ] U1.1 `0.4.0` worktree: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`
- [ ] U1.2 qdesn worktree: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`
- [ ] U1.3 No new worktrees are created for this initiative unless explicitly re-approved.

---

## 1) Scope Lock (Must Stay True)

### 1.1 In Scope

- [ ] S1.1 Align `cransub/0.4.0` and `feature/qdesn-mcmc-alternative` on principled RHS-NS behavior.
- [ ] S1.2 Keep `0.4.0` free of Q-DESN code changes.
- [ ] S1.3 Set Q-DESN default beta prior to RHS-NS on qdesn branch.
- [ ] S1.4 Enforce Q-DESN RHS-family intercept policy: `shrink_intercept = FALSE`.
- [ ] S1.5 Validate MCMC, VB/CAVI, and ELBO behavior against derivation-level expectations.

### 1.2 Explicitly Deferred (Do Not Implement In This Initiative)

- [ ] D1.1 `exdqlmISVB()` DQLM-path removal/simplification (Raquel backlog).
- [ ] D1.2 RW-option removal from `exdqlmMCMC()` (Raquel backlog).
- [ ] D1.3 Raquel diagnostics expansion/cleanup package-wide.
- [ ] D1.4 Documentation relocation tied to deferred Raquel items.

---

## 2) Design Invariants

- [ ] I2.1 `0.4.0` introduces no Q-DESN modules/files.
- [ ] I2.2 qdesn branch defaults to RHS-NS for Q-DESN VB and MCMC entry points.
- [ ] I2.3 Q-DESN RHS-family paths always run with `shrink_intercept = FALSE`.
- [ ] I2.4 Ridge and existing rhs compatibility remain available unless intentionally documented.
- [ ] I2.5 Implementation work is performed only in the two authorized existing worktrees in Section 0.1.
- [ ] I2.6 No new worktrees are used while executing this plan.

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

- [ ] W4.1 Rebase `0.4.0` integration branch on latest `origin/cransub/0.4.0`.
- [ ] W4.2 Resolve conflicts with documented rationale.
- [ ] W4.3 Propagate finalized `0.4.0` changes into qdesn integration branch.
- [ ] W4.4 Verify qdesn branch relation: updated `0.4.0` baseline + qdesn additions.
- [ ] W4.5 Record commit map and branch topology evidence.
- [ ] W4.6 If implementation was done in only one worktree, fetch/pull/rebase in the other existing worktree to sync branch state and confirm parity.

### 7.2 Exit Gate

- [ ] G4.1 Reconciliation complete with traceable conflict notes.
- [ ] G4.2 Branch topology evidence saved.
- [ ] G4.3 Both existing worktrees observe the updated branch state after fetch/sync.

---

## 8) Wave 5 - Test Matrix And Validation Evidence

### 8.1 Unit Test Checklist

- [ ] T1.1 Prior/default-resolution tests (RHS-NS default in Q-DESN paths).
- [ ] T1.2 Intercept policy tests (`shrink_intercept = FALSE` enforcement).
- [ ] T1.3 IG/GIG/truncated-normal parameterization consistency tests.
- [ ] T1.4 Beta precision SPD/conditioning checks.

### 8.2 Integration Test Checklist

- [ ] T2.1 `0.4.0` static exAL VB with `ridge`, `rhs`, `rhs_ns`.
- [ ] T2.2 `0.4.0` static exAL MCMC with `ridge`, `rhs`, `rhs_ns`.
- [ ] T2.3 qdesn VB default flow selects RHS-NS.
- [ ] T2.4 qdesn MCMC default flow selects RHS-NS.
- [ ] T2.5 qdesn explicit ridge override flow passes.

### 8.3 Numerical Behavior Checklist

- [ ] T3.1 Limit sanity check: large `zeta2` tends to ordinary horseshoe behavior.
- [ ] T3.2 Kernel sign/support checks pass (no domain violations).
- [ ] T3.3 MCMC health checks (ESS/drift/rhat/Geweke summary) on affected scenarios.
- [ ] T3.4 VB ELBO/convergence behavior checks on affected scenarios.

### 8.4 Regression Protection Checklist

- [ ] T4.1 Existing ridge baseline behavior unchanged (unless intentionally documented).
- [ ] T4.2 Existing rhs behavior unchanged (unless intentionally documented).
- [ ] T4.3 No API breaks for static exAL `0.4.0` interface.

### 8.5 Exit Gate

- [ ] G5.1 Required tests pass or have documented, justified exceptions.
- [ ] G5.2 Validation evidence package complete.

---

## 9) Final Acceptance Checklist

- [ ] A9.1 `0.4.0` contains no qdesn code changes.
- [ ] A9.2 `0.4.0` static RHS-NS hierarchy matches closed-form target.
- [ ] A9.3 qdesn defaults use RHS-NS in VB and MCMC.
- [ ] A9.4 Q-DESN RHS-family intercept policy is enforced (`FALSE`).
- [ ] A9.5 MCMC/VB/ELBO implementation is derivation-consistent.
- [ ] A9.6 Deferred Raquel backlog untouched.
- [ ] A9.7 Evidence/report artifacts complete and linked.
- [ ] A9.8 Plan executed using existing authorized worktrees only (no new worktrees).

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
| W4.1 | [ ] |  |  |  |  |
| W4.3 | [ ] |  |  |  |  |
| W4.6 | [ ] |  |  |  |  |
| T1.1 | [ ] |  |  |  |  |
| T2.1 | [ ] |  |  |  |  |
| T2.3 | [ ] |  |  |  |  |
| T3.3 | [ ] |  |  |  |  |
| A9.1 | [ ] |  |  |  |  |
| A9.7 | [ ] |  |  |  |  |
| A9.8 | [ ] |  |  |  |  |

---

## 11) Evidence Artifacts Checklist

- [x] E11.1 `reports/rhs_ns_alignment_20260329/branch_topology.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [x] E11.2 `reports/rhs_ns_alignment_20260329/math_crosswalk.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [x] E11.3 `reports/rhs_ns_alignment_20260329/test_matrix_results.md` Done: 2026-03-29, by: Codex, evidence: file created and populated.
- [ ] E11.4 `reports/rhs_ns_alignment_20260329/validation_delta_summary.md`
- [ ] E11.5 `reports/rhs_ns_alignment_20260329/final_signoff.md`
