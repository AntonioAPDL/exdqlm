# qdesn 0.4.0 Proper Normalization Plan

Date: 2026-04-21

## Context

The `aced17a` carry-forward commit proved that the QDESN validation-study branch
could absorb the important `0.4.0` warmup, freeze, and numerical-stability
behavior while staying green on the focused sync regression slice. It was a
useful integration checkpoint, but not yet the clean long-lived source of truth
for the branch architecture we actually want.

That checkpoint still mixed three different concerns:

1. reusable package-layer numerical and warmup improvements,
2. temporary compatibility scaffolding (`R/compat_0p4p0_api_aliases.R` and the
   matching wrapper man pages / exports),
3. an unreleased upstream dataset addition (`BTflowUSGS`) that is not part of
   the intended CRAN-facing scope for this phase.

## Target architecture

The desired layering is:

1. `0.4.0` branch:
   only CRAN-bound package files, docs, tests, and intended package data.
2. `validation study for 0.4.0` branch:
   `0.4.0` package layer plus validation-study scripts, datasets, reports, and
   orchestration.
3. `validation study for qdesn` branch:
   the same normalized `0.4.0` package layer plus validation-study machinery
   plus qdesn-specific model code and tools.

## Normalization goals

1. Replace the temporary wrapper layer with the native upstream `0.4.0` package
   surface:
   - `exalStaticLDVB()`
   - `exalStaticMCMC()`
   - `exalStaticDiagnostics()`
   - `exdqlmTransferISVB()`
   - `exdqlmTransferLDVB()`
   - `exdqlmTransferMCMC()`
   - `quantileSynthesis()`
2. Remove package-layer scaffolding that should not propagate further:
   - `R/compat_0p4p0_api_aliases.R`
   - `R/BTflowUSGS.R`
   - `data/BTflowUSGS.rda`
3. Preserve the stronger warmup / stability behavior already integrated during
   the validation recovery work.
4. Keep the change reversible and auditable by documenting the normalization as
   a distinct pass after `aced17a`.

## Design choices

1. Native `0.4.0` names should become the real package entry points, not
   wrappers around lower-snake validation-era functions.
2. Public static S3 classes and methods should follow the upstream `0.4.0`
   shape.
3. QDESN-only low-level fit classes (`exal_mcmc`, `exal_ldvb`) may remain as
   a narrow compatibility bridge for qdesn-specific helper paths, but they
   should no longer define the package-facing static API.
4. Historical validation-study reports remain as historical records; the new
   normalization report should explain the cleanup instead of rewriting history.

## Verification plan

1. Regenerate metadata with `roxygen2::roxygenise()`.
2. Confirm clean package load with `pkgload::load_all(".", quiet = TRUE)`.
3. Run the focused carry-forward regression slice:
   - `0p4p0-api-compatibility`
   - `vb-mcmc-convergence-controls`
   - `mcmc-dynamic-strict-parity`
   - `static-diagnostics`
   - `static-class-generics`
   - `crps-helper-regression`
   - `dlm-df-smoother-regression`
4. Run an additional renamed-surface sweep over:
   - smoke
   - static regression
   - static normalization
   - RHS prior regression
   - synthesis
   - transfer wrappers
   - reduced DQLM paths

## Expected output

A new normalized commit after `aced17a` that is suitable as the clean
carry-forward base for the later `0.4.0` and validation-study worktree updates.
