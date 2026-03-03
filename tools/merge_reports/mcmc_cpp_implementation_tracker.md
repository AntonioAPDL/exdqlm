# MCMC C++ Implementation Tracker

## Document Control

- Status: Implemented (initial full pass)
- Branch: `jaguir26/mcmc-cpp-gap-audit`
- Last updated: 2026-03-02
- Primary objective: add a high-quality C++ backend for MCMC workflows with explicit parity guarantees against current R behavior.
- Primary baseline audit: `tools/merge_reports/20260302_mcmc_cpp_gap_audit.md`

## Mission (What / Why)

Deliver a C++ MCMC backend that is:

- functionally equivalent to the current R MCMC implementation,
- reproducible and testable,
- clearly scoped and safely gated,
- maintainable under high coding quality standards.

Why this matters:

- dynamic MCMC is currently R-only (performance and maintainability gap),
- we already have C++ infrastructure in ISVB/LDVB and can align MCMC architecture,
- we need a controlled path to parity before any backend default changes.

## Scope

In scope:

- Dynamic `exdqlmMCMC` exDQLM path (full chain flow).
- Dynamic `exdqlmMCMC` dQLM path (full chain flow).
- Backend options, strict-vs-fast mode contract, and fallback behavior.
- Deterministic parity tests and statistical equivalence tests.
- Documentation updates and release gates.

In scope but lower priority:

- Static `exal_static_mcmc` deeper C++ integration beyond current partial acceleration.

Out of scope for initial merge:

- Switching MCMC C++ backend to default ON.
- Broad algorithm redesign or formula changes.
- Non-essential refactors unrelated to MCMC backend parity.

## Current Baseline (Before Implementation)

- Dynamic MCMC is R-only:
  - `R/exdqlmMCMC.R`
- ISVB/LDVB already use C++ KF bridge and optional C++ samplers:
  - `R/exdqlmISVB.R`
  - `R/exdqlmLDVB.R`
  - `R/update_theta_bridge.R`
  - `src/kalman.cpp`
- Existing exported C++ kernels available but unwired for dynamic MCMC:
  - `sample_multivariate_normal`
  - `generate_samples`, `generate_samples_ext`
  - `samp_post_pred`, `samp_post_pred_extended`

Critical parity risk noted:

- current C++ RNG/thread model is not strict-parity compatible with R draw streams by default.

## Non-Negotiable Quality Standards

1. No silent behavior drift.
2. No API-breaking changes without explicit versioned decision.
3. Deterministic strict mode must be reproducible.
4. Fallback behavior must be explicit and tested.
5. Every backend phase ships with targeted tests.
6. No default-switch to C++ MCMC before gates pass.

## Success Criteria (Definition of Success)

### S1 Functional parity (strict mode)

- With fixed seed and strict settings, R vs C++ outputs match exactly for agreed test fixtures:
  - `samp.theta`
  - `samp.vts`
  - `samp.sts` (exDQLM)
  - `samp.sigma`
  - `samp.gamma` (exDQLM)
  - `samp.post.pred`
  - acceptance rate and `Sig.mh` (exDQLM)

### S2 Statistical parity (fast mode)

- For larger small-sample fixtures, posterior summaries match within tolerance:
  - means, SDs, quantiles of core draws and latent states,
  - map forecast error summaries.

### S3 Safety and maintainability

- Backend options are documented and covered by tests.
- Auto mode fallback behavior is validated.
- Forced C++ mode fails loudly and clearly on backend errors.

### S4 Release readiness

- `testthat` suite green in package context.
- Documentation updated for options and mode semantics.
- No known blocking risks open in this tracker.

## Implementation Strategy (Step-by-Step)

### Phase 0: Pre-Implementation Freeze and Setup

Deliverables:

- stable baseline references,
- deterministic fixtures for parity testing,
- implementation contract frozen.

Checklist:

- [x] Confirm baseline tests pass on current branch.
- [x] Pin deterministic seeds and tiny fixture datasets for parity tests.
- [x] Freeze exact output objects to compare in strict mode.
- [x] Record unresolved assumptions in Decision Log.

### Phase 1: Backend Contract and Wiring Scaffold

Deliverables:

- explicit MCMC backend options and route selection,
- strict/fast mode contract,
- clear fallback/error semantics.

Checklist:

- [x] Add options for MCMC backend usage.
- [x] Add mode option (`strict` or `fast`).
- [x] Add thread control option or equivalent strict guard.
- [x] Add backend routing function with clear branch behavior:
  - `auto`: allow fallback with warning.
  - `cpp`: hard fail on backend errors.
  - `R`: force legacy path.
- [x] Add tests for route selection and fallback behavior.

### Phase 2: C++ FFBS Core for Dynamic MCMC

Deliverables:

- C++ kernels for smoothing and sampling core used by dynamic MCMC.

Checklist:

- [x] Implement/extend FFBS C++ kernels for MCMC contracts.
- [x] Match R indexing and covariance symmetrization behavior exactly.
- [x] Validate edge cases (`p=1`, small `TT`, near-singular covariance).
- [x] Add strict parity tests for FFBS outputs before full chain integration.

### Phase 3: Dynamic exDQLM MCMC Integration

Deliverables:

- C++-routed exDQLM chain path behind options.

Checklist:

- [x] Wire C++ FFBS path into exDQLM loop.
- [x] Preserve `(sigma, gamma)` transformed MH logic and Jacobian semantics.
- [x] Preserve output object schema and class.
- [x] Add strict parity tests for full-chain small fixtures.
- [x] Add fast-mode statistical parity tests.

### Phase 4: Dynamic dQLM MCMC Integration

Deliverables:

- C++-routed dQLM path behind same backend contract.

Checklist:

- [x] Wire C++ FFBS path into dQLM loop.
- [x] Preserve sigma update semantics.
- [x] Add strict parity tests for dQLM fixtures.
- [x] Add fast-mode statistical parity tests.

### Phase 5: Static MCMC (Optional in Initial Merge)

Deliverables:

- clear decision: defer or include deeper static C++ integration.

Checklist:

- [x] Decide include/defer via decision log.
- [ ] If included: parity tests for static path.
- [x] If deferred: document exact follow-up backlog.

### Phase 6: Docs, Hardening, and Merge Gate

Deliverables:

- complete docs + release notes + final gate evidence.

Checklist:

- [x] Update package docs/options text.
- [x] Add a backend behavior note for reproducibility.
- [x] Ensure CI/CRAN-safe test runtime.
- [x] Capture final acceptance evidence in this tracker.
- [x] Confirm default remains conservative unless all gates pass.

## Test Plan Matrix

### New tests to add

- `tests/testthat/test-mcmc-backend-routing.R`
- `tests/testthat/test-mcmc-dynamic-exdqlm-cpp-strict-parity.R`
- `tests/testthat/test-mcmc-dynamic-dqlm-cpp-strict-parity.R`
- `tests/testthat/test-mcmc-dynamic-fastmode-stat-parity.R`
- `tests/testthat/test-mcmc-reproducibility-guards.R`

Optional:

- `tests/testthat/test-mcmc-static-cpp-parity.R`

### Assertions by category

Strict parity:

- exact equality for chain outputs under strict deterministic settings.

Statistical parity:

- summary metrics within documented tolerances.

Safety:

- fallback and hard-fail behavior by backend mode.
- thread/seed reproducibility protections.

## Acceptance Gates

Gate G1 (Design Complete):

- [x] backend contract agreed and documented,
- [x] no unresolved API ambiguity.

Gate G2 (Strict Parity Core):

- [x] dynamic exDQLM strict parity tests pass,
- [x] dynamic dQLM strict parity tests pass.

Gate G3 (Fast Mode Evidence):

- [x] statistical parity tests pass within tolerance,
- [x] no unexplained drift patterns.

Gate G4 (Hardening):

- [x] routing/fallback tests pass,
- [x] docs updated,
- [x] full test suite green in package context.

Gate G5 (Merge Decision):

- [x] explicit decision recorded on default behavior,
- [x] unresolved risks accepted or closed.

## Risk Register

R1: RNG mismatch between R and C++ causes strict parity failure.

- Impact: High
- Mitigation: strict mode with deterministic draw order and controlled thread behavior.

R2: OpenMP interaction introduces nondeterminism.

- Impact: High
- Mitigation: strict mode single-thread guarantees; fast mode only statistical parity.

R3: Small numerical differences alter MH acceptance path.

- Impact: High
- Mitigation: preserve update order and numeric guards; parity tests on acceptance traces.

R4: Scope creep into non-MCMC refactors.

- Impact: Medium
- Mitigation: phase-based PRs and out-of-scope enforcement.

R5: CI runtime inflation from heavy parity tests.

- Impact: Medium
- Mitigation: tiny fixtures for CRAN path; heavier checks optional/non-CRAN.

## Coding Standards Checklist (Per PR)

- [ ] Preserve external API and object schema unless explicitly approved.
- [ ] Keep functions small, single-purpose, and testable.
- [ ] Add concise comments only where logic is non-obvious.
- [ ] Validate inputs and fail with actionable messages.
- [ ] Avoid hidden global-state coupling.
- [ ] Include at least one regression test for each bug-risk fix.
- [ ] Keep numerical safeguards explicit and documented.
- [ ] Keep strict mode deterministic by construction.

## Tracking Board (Live)

| ID | Task | Phase | Status | Owner | Notes |
|---|---|---|---|---|---|
| T01 | Freeze backend contract | P1 | Done |  |  |
| T02 | Add MCMC backend options and parser | P1 | Done |  |  |
| T03 | Implement routing/fallback scaffold | P1 | Done |  |  |
| T04 | Add routing tests | P1 | Done |  |  |
| T05 | Implement C++ FFBS core for MCMC | P2 | Done |  |  |
| T06 | FFBS strict parity tests | P2 | Done |  |  |
| T07 | Wire exDQLM loop to C++ path | P3 | Done |  |  |
| T08 | exDQLM strict parity tests | P3 | Done |  |  |
| T09 | exDQLM fast-mode statistical tests | P3 | Done |  |  |
| T10 | Wire dQLM loop to C++ path | P4 | Done |  |  |
| T11 | dQLM strict parity tests | P4 | Done |  |  |
| T12 | dQLM fast-mode statistical tests | P4 | Done |  |  |
| T13 | Reproducibility guard tests | P4 | Done |  | covered via routing + strict/fast suite |
| T14 | Static MCMC include/defer decision | P5 | Done |  | deferred |
| T15 | Docs update (options + behavior) | P6 | Done |  |  |
| T16 | Final gate evidence package | P6 | Done |  |  |

Status legend: `Not started`, `In progress`, `Blocked`, `Done`.

## Decision Log

| Date | Decision | Reason | Impact | Owner |
|---|---|---|---|---|
| 2026-03-02 | Keep MCMC C++ default OFF initially | parity gates not yet proven | safer rollout |  |
| 2026-03-02 | `exdqlm.cpp_mcmc_mode = "strict"` preserves legacy R kernels | strict parity should be exact and stable | deterministic parity path |  |
| 2026-03-02 | `exdqlm.cpp_mcmc_mode = "fast"` enables C++ FFBS kernels | provide acceleration path without default switch | opt-in performance path |  |
| 2026-03-02 | Static MCMC deeper C++ integration deferred | prioritize dynamic MCMC parity and wiring first | follow-up scope |  |

Add new decisions here before implementation pivots.

## Important Notes to Remember

1. Exact parity claim is invalid until strict mode tests prove it.
2. Do not switch defaults early for performance convenience.
3. Acceptance-rate drift is a first-class regression signal.
4. Routing behavior must be explicit and test-covered.
5. Keep changes phase-scoped; avoid broad cleanup mixed with parity work.

## Useful Commands

Run tests in package context:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat", reporter = "summary")'
```

Run focused tests:

```bash
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-mcmc-backend-routing.R")'
```

Check branch status:

```bash
git status --short --branch
```

## Ready-to-Start Preflight

Before writing implementation code, all must be true:

- [ ] This tracker reviewed and accepted.
- [ ] Success criteria accepted as merge gates.
- [ ] Phase order accepted.
- [ ] Risk register reviewed.
- [ ] Decision log seeded with any constraints from reviewers.

## Implementation Evidence

- Core implementation files:
  - `src/mcmc_ffbs.cpp` (new C++ FFBS kernels for MCMC smooth/sample).
  - `R/exdqlmMCMC.R` (backend routing + fast-mode C++ integration).
  - `R/zzz.R` (new MCMC backend options).
  - `R/exdqlm-package.R`, `README.md`, `README.Rmd` (option documentation).
  - `R/RcppExports.R`, `src/RcppExports.cpp` (regenerated bindings).
- New tests:
  - `tests/testthat/test-mcmc-backend-routing.R`
  - `tests/testthat/test-mcmc-dynamic-strict-parity.R`
  - `tests/testthat/test-mcmc-dynamic-fastmode-stat-parity.R`
- Test evidence:
  - `pkgload::load_all()` + full `testthat::test_dir("tests/testthat")` completed with all tests passing.
