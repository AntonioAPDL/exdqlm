# qdesn 0.4.0 Proper Normalization Implementation Report

Date: 2026-04-21

## Summary

This pass converts the earlier `aced17a` sync checkpoint into a cleaner
long-lived source commit for the qdesn validation-study branch.

The main idea was simple:

- keep the real warmup / freeze / numerical-stability improvements,
- remove temporary integration scaffolding,
- normalize the public package surface to the native upstream `0.4.0` shape,
- keep only a narrow qdesn-specific low-level bridge where it is still useful.

## Starting point

Normalization started from:

- branch: `feature/qdesn-mcmc-alternative-0p4p0-integration`
- checkpoint commit: `aced17acd287e457792482192c30f792619261aa`

That checkpoint was already green on the focused sync regression slice, but it
still carried:

- `R/compat_0p4p0_api_aliases.R`
- `R/BTflowUSGS.R`
- `data/BTflowUSGS.rda`
- wrapper-generated man pages and exports for the temporary compatibility layer

## What changed

### 1. Removed temporary scaffolding and out-of-scope dataset additions

Deleted:

- `R/compat_0p4p0_api_aliases.R`
- `R/BTflowUSGS.R`
- `data/BTflowUSGS.rda`

Roxygen cleanup then removed the corresponding temporary documentation:

- wrapper man pages tied to the alias layer
- wrapper-era diagnostic docs
- `BTflowUSGS.Rd`

### 2. Normalized the package surface to native upstream `0.4.0` names

The public static, transfer, and synthesis entry points are now defined
natively rather than through a separate wrapper file.

Native package files now align to the upstream `0.4.0` layout:

- `R/exalStaticLDVB.R`
- `R/exalStaticMCMC.R`
- `R/exalStaticDiagnostics.R`
- `R/exdqlmTransferISVB.R`
- `R/exdqlmTransferLDVB.R`
- `R/exdqlmTransferMCMC.R`
- `R/quantileSynthesis.R`

This also removed the legacy lower-snake public exports:

- `exal_static_LDVB`
- `exal_static_mcmc`
- `transfn_exdqlmISVB`
- `transfn_exdqlmLDVB`
- `transfn_exdqlmMCMC`
- `exdqlm_synthesize_from_draws`

### 3. Normalized the public static S3 surface

The static S3 surface now follows upstream `0.4.0` directly:

- `is.exalStaticMCMC()`
- `print.exalStaticMCMC()`
- `summary.exalStaticMCMC()`
- `plot.exalStaticMCMC()`
- `is.exalStaticLDVB()`
- `print.exalStaticLDVB()`
- `summary.exalStaticLDVB()`
- `plot.exalStaticLDVB()`
- `is.exalStaticDiagnostic()`
- `print.exalStaticDiagnostic()`
- `summary.exalStaticDiagnostic()`
- `plot.exalStaticDiagnostic()`

### 4. Kept a narrow qdesn-specific low-level bridge

The qdesn-specific low-level classes were intentionally retained where they are
still part of the qdesn-side helper layer:

- `exal_mcmc`
- `exal_ldvb`
- `exal_vb`

The bridge is intentionally narrower now:

- public static fits lead with canonical static classes,
- low-level qdesn classes remain as secondary classes where needed,
- low-level print / summary / plot methods defer to the canonical static
  implementations.

This preserves smooth behavior for qdesn-specific helper paths without letting
the lower-snake compatibility layer define the public package surface.

### 5. Updated tests and package-facing docs

Updated:

- package-facing README text
- `NEWS.md`
- the focused static API test
- static class-generic tests
- the rest of the renamed public-surface tests through mechanical conversion

The dedicated API-surface test now checks two things:

1. native `0.4.0` symbols are exported,
2. the lower-snake public wrappers are not exported anymore.

## Verification

These commands passed after normalization:

```bash
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'pkgload::load_all(".", quiet = TRUE)'
Rscript -e 'testthat::test_local(filter = "0p4p0-api-compatibility|vb-mcmc-convergence-controls|mcmc-dynamic-strict-parity|static-diagnostics|static-class-generics|crps-helper-regression|dlm-df-smoother-regression", reporter = "summary")'
Rscript -e 'testthat::test_local(filter = "smoke|dqlm-reduced-paths|static-beta-prior-rhs|static-regression-regmod|static-fit-normalization|static-p025-stability|static-exal-gamma-band-reduction|synthesize-from-draws|transfer-mcmc-wrapper", reporter = "summary")'
```

## Notes

1. This normalization is intentionally separate from the later dynamic-dataset
   replacement phase. No dataset swap was started here.
2. `README.Rmd` and `README.md` were kept aligned manually. A full
   `rmarkdown::render(..., output_format = "github_document")` pass was not
   performed in this environment because `pandoc` is unavailable.

## Outcome

The qdesn validation-study branch now sits much closer to the desired branch
layering:

- native `0.4.0` package surface,
- validation/qdesn-specific numerical improvements preserved,
- temporary wrapper layer removed,
- unreleased `BTflowUSGS` addition removed,
- ready to serve as the cleaner carry-forward reference for the other
  worktrees.
