# PLAN: QDESN Dynamic Tau-0.50 Refreshed Main Relaunch

Date: 2026-04-16
Branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
Worktree: `/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration`

## 1) Purpose

Prepare the next dynamic-only QDESN validation relaunch on top of the synced `0.4.0` package core,
using the corrected `tau = 0.05 / 0.25 / 0.50` dynamic materialized-source surface and a cleaner
canonical inference lane.

This document is intentionally a **no-launch preparation plan**.

It records:

- what the refreshed main study should optimize for;
- what the recent replay and comparison evidence actually says;
- which controls should be canonical in the refreshed main lane; and
- which settings should remain available only as narrow rescue overrides.

## 2) Scope

This refreshed relaunch is **dynamic-only**.

The target data surface is:

- scenario:
  - `dlm_constV_smallW`
- families:
  - `gausmix`, `laplace`, `normal`
- taus:
  - `0.05`, `0.25`, `0.50`
- fit sizes:
  - `500`, `5000`
- priors:
  - `ridge`, `rhs_ns`

This gives:

- unique dataset cells:
  - `18`
- QDESN roots:
  - `36`
- intended fit lanes per root:
  - `vb / al`
  - `vb / exal`
  - `mcmc / al`
  - `mcmc / exal`
- total fits in the refreshed main study:
  - `144`

Important scope clarification:

- the datasets are dynamic;
- the QDESN readout fitting backend is still the static `al` / `exal` package algorithm;
- static-dataset validation surfaces are **not** part of this relaunch.

## 3) Evidence Base

The refreshed relaunch should be driven by the following already-frozen branch-local evidence:

- `docs/REPORT__qdesn_0p4p0_core_sync_and_validation_freeze_20260416.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_closeout_and_failure_audit_20260416.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_main_comparison_outputs_20260416.md`
- `docs/REPORT__qdesn_dynamic_exdqlm_crossstudy_tau050_materialized_surface_reset_20260416.md`

Focused post-sync tests already passed on the current branch, including:

- `test-transfer-mcmc-wrapper.R`
- `test-static-diagnostics.R`
- `test-static-p025-stability.R`
- `test-vb-mcmc-convergence-controls.R`
- `test-qdesn-prior-defaults.R`
- `test-pipeline-inference-validation.R`
- `test-qdesn-dynamic-failure-repair.R`
- `test-qdesn-validation-group-summary-robustness.R`

## 4) Confirmed Lessons From The Current Evidence

### 4.1 MCMC Default Direction

The synced branch now clearly points toward **slice** as the canonical MCMC path.

Evidence:

- dynamic MCMC defaults to slice in `tests/testthat/test-vb-mcmc-convergence-controls.R`
- static MCMC defaults to slice in `tests/testthat/test-static-diagnostics.R`
- the active dynamic validation defaults already use slice-specific control blocks
- the package-core sync preserved and strengthened the slice path rather than moving toward
  `rw` or `laplace_rw`

### 4.2 VB Default Direction

The current exercised VB path is **LDVB**.

Evidence:

- dynamic convergence diagnostics tests are written against `exdqlmLDVB`
- dynamic and static MCMC warm-start tests expect `vb.init.method = "ldvb"`
- the synced `0.4.0` branch updated shared LDVB stabilization code in `R/exal_static_LDVB.R`
- the current validation runner and post-sync tests already exercise that stabilized LDVB path

### 4.3 Root Cause Read

The recent dynamic root-cause work does **not** support the idea that the refreshed main study
needs a broad zoo of custom kernels in the core lane.

What the evidence actually shows:

- there were `0` root-level crashes;
- the remaining replay failures were entirely in `MCMC`;
- those failures split into:
  - true mixing/drift failures; and
  - numerically/diagnostically invalid long-horizon rows with
    `missing_chain_diagnostics`

So the real blocker was:

- MCMC quality / numerical stability / replay drift in specific pockets;

not:

- a lack of `rw` / `laplace_rw` coverage in the main study.

## 5) Recommended Core-Lane Contract

### 5.1 VB

Use **LDVB everywhere** in the refreshed main study.

The explicit recommendation is:

- one canonical LDVB control profile in the manifest;
- applied to both `al` and `exal`;
- with prior-specific overrides only where justified and documented.

### 5.2 MCMC

Use **slice everywhere** in the refreshed main study.

The explicit recommendation is:

- `mh.proposal = "slice"` in the core lane;
- `init_from_vb = TRUE` by default;
- the warm start should come from LDVB, not legacy ISVB.

### 5.3 Priors

Use:

- `ridge`
- `rhs_ns`

Do **not** reopen raw `rhs` for the refreshed main study.

The intended sparse prior is the proper conjugate/closed-form `rhs_ns` path.

### 5.4 What Should Not Be In The Core Lane

Do **not** use in the refreshed main lane:

- `init_from_isvb`
- `mh.proposal = "rw"`
- `mh.proposal = "laplace_rw"`

These may remain available in package code or isolated diagnostics, but they should not define the
main relaunch contract.

## 6) Recommended Slice Policy

### 6.1 Core Recommendation

Use a **standardized slice profile** in the refreshed main study, not the raw paper-facing
`slice.width = 0.01`, `slice.max.steps = Inf` contract everywhere.

Why:

- the active synced branch is already structured around explicit slice control blocks rather than a
  single scalar width;
- the recent failure surface was not caused by insufficient kernel variety, but by stability and
  diagnostics in hard MCMC pockets;
- a standardized explicit slice profile is more reproducible, more inspectable, and easier to
  audit than a broad implicit paper-width rule;
- it keeps the core lane aligned with what the current validation runner actually knows how to
  record and report.

### 6.2 Rescue Policy

Keep **row-specific rescue settings** available and documented, but outside the core lane.

That means:

- the manifest should define one canonical slice profile;
- any root-specific rescue override must be explicit and narrow;
- rescue overrides should only survive if they are tied to concrete prior evidence from the prior
  replay history or the new relaunch canary.

In plain terms:

- standardize the core lane;
- do not erase hard-won rescue knowledge;
- but do not let rescue settings silently become the default policy.

## 7) Recommended LDVB Policy

The refreshed main study should use one explicit LDVB control profile per block and write it into
the manifest so the run is reproducible.

The stabilized options we now trust should remain on:

- bounded eta range
- finite eigenvalue floor
- `data_scale` sigma initialization
- trace retention
- bad-mode rejection / stabilization checks
- no silent fallback to old legacy init behavior

Operationally, that means the refreshed manifest should make visible controls for:

- eta bounds
- eigenvalue floor
- sigma initialization mode
- trace storage / retention
- candidate/committed mode quality checks

## 8) Proposed Relaunch Structure

### Stage A: Freeze And Traceability

- keep the pre-sync replay and comparison artifacts as frozen evidence;
- treat them as branch-local justification, not as the final post-sync answer.

### Stage B: Core-Lane Manifest Draft

Draft a new dynamic relaunch manifest with:

- `tau = 0.05 / 0.25 / 0.50`
- `ridge` and `rhs_ns`
- `vb = LDVB everywhere`
- `mcmc = slice everywhere`
- `init_from_vb = TRUE`
- standardized posterior export counts
- explicit slice and LDVB profiles in the manifest

### Stage C: Rescue Overlay Definition

Create a separate documented overlay for root-specific rescue settings:

- only the settings that remain justified by prior evidence;
- no generic `rw` / `laplace_rw` reopen in the main lane;
- rescue settings remain visible and reviewable instead of being hidden in ad hoc patches.

### Stage D: Preflight And Focused Tests

Before any launch:

- validate manifest materialization;
- run committed-state `prepare-only` preflights;
- run focused touched-path tests again if the manifest plumbing changes.

### Stage E: Launch Decision

Only after the above should we choose:

- a canary relaunch first; or
- the full refreshed main study.

This document does **not** authorize launch by itself.

## 9) Open Decision Still Worth Reviewing

The main unresolved design choice is now narrow:

- standardized slice profile everywhere in the core lane, with rescue overrides preserved; or
- literal paper-facing `slice.width = 0.01`, `slice.max.steps = Inf` everywhere.

Current recommendation:

- choose the standardized slice profile as the main lane;
- preserve row-specific rescue settings separately.

This is the cleaner choice because it matches the current branch behavior, the current reporting,
and the actual root-cause evidence.

## 10) Immediate Next Deliverables

Without launching anything yet, the next implementation deliverables should be:

1. a refreshed dynamic relaunch plan artifact
2. a refreshed manifest draft for the dynamic-only study
3. a documented core slice profile
4. a documented core LDVB profile
5. a documented rescue-overlay inventory
6. no-launch preflight validation on the new manifest set

## 11) Current Decision

The current best-supported relaunch direction is:

- dynamic datasets only
- `tau = 0.05 / 0.25 / 0.50`
- families `gausmix`, `laplace`, `normal`
- priors `ridge` and `rhs_ns`
- `VB = LDVB`
- `MCMC = slice`
- `MCMC warm start = LDVB`
- no `init_from_isvb`, `rw`, or `laplace_rw` in the refreshed core lane
- preserve row-specific rescue settings as explicit overlays, not default behavior

That is the cleanest path supported by the current synced branch and the validation evidence we now
have.
