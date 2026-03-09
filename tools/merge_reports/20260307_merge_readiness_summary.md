# Merge Readiness Summary

Date: 2026-03-08
Repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`
Branch: `jaguir26/dqlm-conjugacy-cavi-gibbs`
Target integration branch later: `cransub/0.4.0`

## Scope of this branch

This branch prepares the `0.4.0` line with the dynamic/static exAL and AL work completed on the feature branch, including:

- static exAL/AL simulation, normalization, pipeline, reporting, and diagnostics support
- dynamic/static VB and MCMC convergence-control hardening
- reduced-path DQLM handling and tests
- dynamic/static sigma-gamma diagnostics standardization
- exact slice support for gamma in MCMC
- optional MCMC trace diagnostics and related efficiency improvements
- audit and comparison scripts under `tools/merge_reports/` for reproducibility of the branch work
- static `RHS` prior support for `AL` / `exAL` in both `VB` and `MCMC`
- qdesn-style `RHS` tau warmup/freeze safeguards for static `VB`

## Main package-level changes

### Dynamic
- `exdqlmLDVB()` and `exdqlmISVB()` now expose more complete convergence diagnostics and support the reduced DQLM path consistently.
- `exdqlmMCMC()` now supports:
  - slice sampling for gamma
  - optional per-iteration diagnostics traces
  - standardized `mh.diagnostics` metadata
  - lower-overhead internal state-signal reuse in the MCMC loop

### Static
- `exal_static_LDVB()` now defaults to a truncated Student-t prior on gamma over the admissible support.
- `exal_static_mcmc()` now supports:
  - slice sampling for gamma
  - optional per-iteration diagnostics traces
  - cached `xb = X %*% beta` reuse in the gamma slice path for better efficiency
- static fit normalization/reporting supports the richer diagnostics structure.
- static `AL` / `exAL` now support `beta_prior = "ridge"` or `"rhs"` with:
  - zero-centered regularized horseshoe shrinkage
  - optional intercept shrinkage control
  - RHS latent summaries in `VB` and `MCMC`
  - RHS-only coefficient tree plots in static reporting

### Tooling and reproducibility
- Added/updated simulation, pipeline, audit, and comparison scripts under `tools/merge_reports/`.
- Added branch-specific test coverage for reduced DQLM paths and shared exAL sanity checks.

## Documentation status

- Roxygen documentation regenerated with `devtools::document()`.
- Generated Rd files updated for changed public interfaces.
- New/changed controls now documented, including:
  - slice sampler support
  - optional trace diagnostics
  - gamma prior defaults
  - dynamic/static convergence and diagnostics metadata

## Validation status

### Targeted tests
- Status: passed
- Counts: `PASS 43, FAIL 0, WARN 0, SKIP 1`
- The single skip is an expected guarded skip from smoke-style coverage.

### Full package test suite
- Status: passed
- Counts: `PASS 1363, FAIL 0, WARN 0, SKIP 1`
- The single skip is an expected environment/path guard in the static pipeline/report smoke test.

### Package-level check
- Status: completed for merge-readiness via `R CMD check --no-manual --no-examples`
- Authoritative merge-readiness result:
  - `Status: 1 NOTE`
  - NOTE source: installed package size (`libs` directory size)

## RHS-specific signoff status

- The earlier static `exAL + RHS` `VB` tail-collapse pathology was fixed by the
  qdesn-style tau warmup/freeze schedule.
- Updated broad static `RHS` validation shows:
  - `AL + RHS` behaving well
  - `exAL + RHS` `VB` tails no longer collapsing
  - `exAL + RHS` `MCMC` remaining scientifically interpretable but still showing
    weak tail mixing (`ESS_gamma`, `ESS_sigma`)
- The current `VB` LD stability gate was revised for `RHS` tails so that it
  still guards collapse/local-mode quality without failing stabilized tail fits
  solely because sigma/gamma traces oscillate around convergence.
- Remaining `RHS` work before later integration should be treated as localized
  tuning/signoff work for `exAL` tails, not as a structural blocker.

## Cleanup status

- generated `tools/merge_reports/*.log` files were removed from the worktree
- `.gitignore` updated so those logs do not reappear as branch noise
- remaining branch changes are intentional source/docs/tests/scripts for this feature line

## Merge watchpoints for later integration with `cransub/0.4.0`

1. This branch has broad touch points across dynamic MCMC/VB, static MCMC/VB, utilities, tests, and merge-report tooling.
2. Raquel's `cransub/0.4.0` work may overlap on:
   - documentation regeneration
   - namespace/roxygen outputs
   - tests
   - any files in `R/` touched by release prep
3. Likely file overlap to check explicitly during later integration:
   - `R/utils.R`
   - `R/exdqlmLDVB.R`
   - `R/exdqlmISVB.R`
   - `R/exdqlmMCMC.R`
   - `R/exal_static_LDVB.R`
   - `R/exal_static_mcmc.R`
   - `R/static_fit_normalization.R`
   - `man/exal_static_LDVB.Rd`
   - `man/exal_static_mcmc.Rd`
   - `tests/testthat/`
   - `tools/merge_reports/`
3. Integration should be done only after her confirmation, followed by:
   - pull/rebase or merge strategy decision
   - full test suite rerun
   - package-level check rerun on the integrated branch

## Current recommendation

This branch should be treated as merge-ready pending:

1. Raquel's confirmation that her `cransub/0.4.0` work is ready to be integrated

Do not merge into `cransub/0.4.0` before that confirmation.
