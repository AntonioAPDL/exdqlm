# Wave 2 Test Matrix Results (2026-03-29)

Repository: `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

## Scope

Wave 2 validation for static RHS-NS closed-form hierarchy port:

- W2.1-W2.4 implementation validation
- W2.6 test additions and execution
- G2.1/G2.2/G2.3 gate evidence

## Commands Executed

1. Targeted prior/scale suite

```bash
Rscript -e "pkgload::load_all(quiet=TRUE); testthat::test_dir('tests/testthat', filter='static-beta-prior-rhs', reporter='summary')"
```

Outcome:

- PASS
- Includes new RHS-NS closed-form assertions:
  - VB moment/precision consistency (`E[1/tau2]E[1/lambda2]+E[1/zeta2]`)
  - MCMC Gibbs block update consistency
  - fixed-`zeta2` invariance

2. Static regression matrix

```bash
Rscript -e "pkgload::load_all(quiet=TRUE); testthat::test_dir('tests/testthat', filter='static-', reporter='summary')"
```

Outcome:

- PASS (all static suites run under this filter)
- 1 skipped test (`static-vb-mcmc-pipeline-report-smoke`) marked `On CRAN` by test design

## Changed Files (Wave 2)

- `R/static_beta_prior.R`
- `R/exal_static_mcmc.R`
- `tests/testthat/test-static-beta-prior-rhs.R`
- `tests/testthat/helper-static-fit-normalization.R`

No qdesn module/file changes were made in this wave.

## Wave 2 Checks

- Closed-form RHS-NS hierarchy implemented for static VB and MCMC.
- Static VB consumes exact RHS-NS expected precision map.
- Static MCMC uses Gibbs updates for `(lambda2, nu, tau2, xi, zeta2)` under RHS-NS.
- Slab precision enters once as `+ 1/zeta2` in coefficient precision.
- Static regression tests pass after integration.
