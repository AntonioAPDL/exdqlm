# QDESN Default Warmup Profile and Branch Normalization Tracker

Date: 2026-04-21

## Objective

Implement a package-native default warmup profile in the shared `0.4.0` base so
ordinary users do not need to hand-tune warmup controls for common exAL /
exdqlm use, then propagate that shared package layer into the two validation
branches and re-normalize the branch structure around the intended layering:

1. `0.4.0` package branch:
   only CRAN-bound package code, docs, tests, and intended package data.
2. `0.4.0` validation-study branch:
   the `0.4.0` package layer plus validation-study files, scripts, datasets,
   and reports.
3. `qdesn` validation-study branch:
   the same shared package layer plus validation-study machinery plus
   qdesn-specific files and rescue paths.

## Baseline policy under implementation

The default warmup profile should reduce user burden while staying conservative:

- `rhs` / `rhs_ns` tau warmup should be automatic.
- exAL `(sigma, gamma)` warmup should be automatic but light.
- VB warm-start for MCMC should remain the default where supported.
- stronger `theta`, latent-state, latent-`v`, latent-`s`, and precision rescue
  policies should remain available, but not become the universal baseline.

The current target default profile is:

1. prior-level shrinkage:
   - `freeze_tau_warmup_iters = 50L`
   - `force_tau_after_warmup = TRUE`
2. exAL VB:
   - `sigmagam$freeze_warmup_iters = 10L`
   - `sigmagam$force_after_warmup = TRUE`
   - `sigmagam$postwarmup_damping = 0.6`
   - `sigmagam$postwarmup_damping_iters = 5L`
   - `sigmagam$min_postwarmup_updates = 1L`
3. exAL MCMC:
   - `init_from_vb = TRUE`
   - `sigmagam$freeze_burnin_iters = 25L`
   - `sigmagam$freeze_only_during_burn = TRUE`
   - `sigmagam$force_after_warmup = TRUE`
   - `sigmagam$delay_adapt_until_after_warmup = TRUE`
   - `sigmagam$delay_laplace_refresh_until_after_warmup = TRUE`
4. dynamic theta / latent-state:
   - available for rescue and expert use
   - not part of the default baseline profile
5. precision rescue:
   - remains an escalation layer
   - not part of the default baseline profile

## Implementation principles

- Apply default warmup behavior at the package entrypoint layer.
- Keep builder helpers explicit and composable for advanced users.
- Let explicit user controls override the default profile.
- Clamp effective warmup to the available iteration budget instead of silently
  inflating `n_burn` or `max_iter`.
- Record resolved warmup behavior in diagnostics so the defaults stay auditable.

## Stage 1: Shared `0.4.0` default warmup profile

- [x] Add a package-native default warmup profile helper in the `0.4.0` base.
- [x] Wire the default profile into:
  - [x] `exalStaticLDVB()`
  - [x] `exalStaticMCMC()`
  - [x] `exdqlmLDVB()`
  - [x] `exdqlmMCMC()`
- [x] Ensure explicit `vb_control`, `mcmc_control`, and legacy low-level
  control lists override the defaults cleanly.
- [x] Add clamp / resolve behavior so warmup never exceeds the available
  iteration budget.
- [x] Add diagnostics for resolved default warmup behavior.
- [x] Update package docs / examples to present safe defaults first and manual
  tweaking as the advanced path.
- [x] Add focused regression tests for:
  - [x] shrinkage tau default resolution
  - [x] static VB default sigmagam warmup
  - [x] static MCMC default sigmagam warmup
  - [x] dynamic VB default sigmagam warmup
  - [x] dynamic MCMC default sigmagam warmup
  - [x] override precedence
  - [x] warmup clamp behavior
- [x] Close the `control=` merge gap so existing control lists are preserved and
  only missing defaults are filled.

## Stage 2: Branch normalization and propagation

- [x] Propagate the Stage 1 package-layer changes into the `0.4.0`
  validation-study branch.
- [x] Normalize the qdesn package layer onto the updated shared `0.4.0` base.
- [x] Preserve qdesn-only rescue surfaces as supersets rather than shared base
  behavior.
- [x] Audit shared package files across the three branches to minimize package
  drift.
- [x] Document the resulting branch layering and source-of-truth rules.
- [x] Verify all three branches and leave them committed, pushed, and clean.

## Verification checklist

- [x] `0.4.0` package branch:
  - [x] `roxygen2::roxygenise()`
  - [x] `pkgload::load_all(".", quiet = TRUE)`
  - [x] focused `testthat` slice passes
- [x] `0.4.0` validation-study branch:
  - [x] package loads cleanly
  - [x] focused `testthat` slice passes
- [x] qdesn validation-study branch:
  - [x] package loads cleanly
  - [x] focused `testthat` slice passes
  - [x] qdesn-specific wrapper tests still pass

## Progress log

- [x] Planned the two-stage implementation and pinned the current branch tips.
- [x] Stage 1 implementation in `0.4.0` started.
- [x] Stage 2 propagation / normalization started.
- [x] Final verification complete.

## Notes from implementation

- The shared baseline now defaults to:
  - `rhs` / `rhs_ns` tau warmup of `50L`
  - light exAL VB `(sigma, gamma)` warmup
  - light exAL MCMC `(sigma, gamma)` warmup
- Warmup is clamped to the available iteration budget rather than silently
  inflating `max_iter` or `n_burn`.
- The package entrypoints, not the low-level user-facing builders, own the
  automatic default behavior.
- A late-discovered API issue around `control=` merging was fixed in the shared
  base and then propagated to the validation branches so explicit control lists
  are preserved and only missing defaults are filled.
- Shared package-layer files were audited after propagation and now match across
  `0.4.0`, `0.4.0` validation, and qdesn wherever they are supposed to be
  identical.
