# TRACK: RHS_NS Cross-Branch Execution Checklist (2026-03-29)

## 0) How To Use This Tracker

- [ ] U0.1 Keep this file open during implementation and update each item only when fully complete.
- [ ] U0.2 For each completed item, change `[ ]` to `[x]` and append `Done: YYYY-MM-DD, by: <name>, evidence: <path|commit>`.
- [ ] U0.3 Do not mark an exit gate complete unless every required checklist item in that wave is complete.
- [ ] U0.4 Record every test command and outcome in Section 10 before closing the wave.

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
- [ ] I2.5 No edits are made in active validation worktrees used by ongoing runs.

---

## 3) Wave 0 - Safety And Isolation

### 3.1 Setup Checklist

- [ ] W0.1 Fetch all remotes/tags and prune stale refs.
- [ ] W0.2 Record baseline hashes/logs for `origin/cransub/0.4.0`, `origin/feature/qdesn-mcmc-alternative`, and validation branch.
- [ ] W0.3 Create isolated worktree + branch for `0.4.0` implementation.
- [ ] W0.4 Create isolated worktree + branch for qdesn implementation.
- [ ] W0.5 Verify active validation worktrees remain untouched.
- [ ] W0.6 Record baseline `git status` in all relevant worktrees.

### 3.2 Exit Gate

- [ ] G0.1 Isolated branches are ready and clean.
- [ ] G0.2 No unintended changes in active validation worktrees.

---

## 4) Wave 1 - Mathematical Crosswalk Freeze

### 4.1 Crosswalk Checklist

- [ ] W1.1 Build equation crosswalk: article appendix full conditionals -> theory repo derivations.
- [ ] W1.2 Build equation crosswalk: theory derivations -> implementation formulas in R.
- [ ] W1.3 Freeze parameterization conventions (IG, GIG, truncated normal).
- [ ] W1.4 Confirm conditioning sets and supports for all blocks.
- [ ] W1.5 Freeze target closed-form RHS-NS hierarchy for `0.4.0` static stack.

### 4.2 Exit Gate

- [ ] G1.1 Crosswalk document approved for coding.

---

## 5) Wave 2 - `0.4.0` Static RHS-NS Closed-Form Port (No Q-DESN)

### 5.1 Implementation Checklist

- [ ] W2.1 Update static RHS-NS scale hierarchy to closed-form updates in `R/static_beta_prior.R`.
- [ ] W2.2 Align static VB path with closed-form hierarchy requirements (`R/exal_static_LDVB.R` only as needed).
- [ ] W2.3 Align static MCMC path with closed-form hierarchy requirements (`R/exal_static_mcmc.R` only as needed).
- [ ] W2.4 Verify no slab-term double counting.
- [ ] W2.5 Verify no qdesn file/module added or modified on `0.4.0` path.
- [ ] W2.6 Add/update static tests for RHS-NS hierarchy correctness.

### 5.2 Exit Gate

- [ ] G2.1 Targeted static RHS/RHS-NS tests pass.
- [ ] G2.2 Static regression tests pass.
- [ ] G2.3 `0.4.0` remains qdesn-free.

---

## 6) Wave 3 - Q-DESN Defaults + Intercept Policy Hardening

### 6.1 Implementation Checklist

- [ ] W3.1 Set Q-DESN MCMC default beta prior type to RHS-NS (`R/qdesn_mcmc.R`).
- [ ] W3.2 Set Q-DESN VB default beta prior type to RHS-NS (`R/qdesn_vb.R`).
- [ ] W3.3 Align config resolver defaults to RHS-NS for Q-DESN routing (`R/exal_inference_config.R`, config defaults as required).
- [ ] W3.4 Enforce `shrink_intercept = FALSE` for Q-DESN RHS-family constructors/routing (`R/priors_beta.R`, `R/qdesn_rhs_ns_prior.R`, and entry points as needed).
- [ ] W3.5 Add guardrail behavior when users request `shrink_intercept = TRUE` in Q-DESN context (override or fail-fast; document choice).
- [ ] W3.6 Add/update tests for default-resolution and intercept-policy enforcement.

### 6.2 Exit Gate

- [ ] G3.1 Q-DESN default prior resolution tests pass.
- [ ] G3.2 Intercept-policy tests pass.
- [ ] G3.3 Ridge override path still works as expected.

---

## 7) Wave 4 - Cross-Branch Reconciliation

### 7.1 Integration Checklist

- [ ] W4.1 Rebase `0.4.0` integration branch on latest `origin/cransub/0.4.0`.
- [ ] W4.2 Resolve conflicts with documented rationale.
- [ ] W4.3 Propagate finalized `0.4.0` changes into qdesn integration branch.
- [ ] W4.4 Verify qdesn branch relation: updated `0.4.0` baseline + qdesn additions.
- [ ] W4.5 Record commit map and branch topology evidence.

### 7.2 Exit Gate

- [ ] G4.1 Reconciliation complete with traceable conflict notes.
- [ ] G4.2 Branch topology evidence saved.

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

---

## 10) Execution Log (Fill As Work Progresses)

| ID | Status | Date | Branch/Worktree | Command or Change | Evidence |
|---|---|---|---|---|---|
| W0.1 | [ ] |  |  |  |  |
| W0.2 | [ ] |  |  |  |  |
| W0.3 | [ ] |  |  |  |  |
| W1.1 | [ ] |  |  |  |  |
| W2.1 | [ ] |  |  |  |  |
| W2.2 | [ ] |  |  |  |  |
| W2.3 | [ ] |  |  |  |  |
| W3.1 | [ ] |  |  |  |  |
| W3.2 | [ ] |  |  |  |  |
| W3.3 | [ ] |  |  |  |  |
| W3.4 | [ ] |  |  |  |  |
| W4.1 | [ ] |  |  |  |  |
| W4.3 | [ ] |  |  |  |  |
| T1.1 | [ ] |  |  |  |  |
| T2.1 | [ ] |  |  |  |  |
| T2.3 | [ ] |  |  |  |  |
| T3.3 | [ ] |  |  |  |  |
| A9.1 | [ ] |  |  |  |  |
| A9.7 | [ ] |  |  |  |  |

---

## 11) Evidence Artifacts Checklist

- [ ] E11.1 `reports/rhs_ns_alignment_20260329/branch_topology.md`
- [ ] E11.2 `reports/rhs_ns_alignment_20260329/math_crosswalk.md`
- [ ] E11.3 `reports/rhs_ns_alignment_20260329/test_matrix_results.md`
- [ ] E11.4 `reports/rhs_ns_alignment_20260329/validation_delta_summary.md`
- [ ] E11.5 `reports/rhs_ns_alignment_20260329/final_signoff.md`

