# Phase 7D Dynamic C++ `elbo.part` Audit

- Date (UTC): 2026-02-10 09:01:28
- Branch: `integrate/v0.6.0-on-v0.5.0`
- Theory source: `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`
- Scope: determine whether C++ `elbo.part` is public ELBO or internal-only diagnostic.

## Audit Question

Does `src/kalman.cpp` `elbo.part` affect exported/user-visible ELBO diagnostics?

## Findings

- C++ returns `Named("elbo.part")` from `update_theta_cpp`:
  - `src/kalman.cpp:366-375`.
- Bridge path used by package inference computes and returns `elbo_theta` from smoothed covariances, not `elbo.part`:
  - `R/update_theta_bridge.R:94-124`.
- Package-level dynamic ELBO snapshots continue to be assembled in R inference code (`exdqlmISVB`/`exdqlmLDVB`) and do not consume C++ `elbo.part` directly.

## Resolution

- Classified `elbo.part` as **internal-only C++ diagnostic** (non-public ELBO).
- Added explicit code comments to prevent future confusion:
  - `src/kalman.cpp:270` and `src/kalman.cpp:366`.
  - `R/update_theta_bridge.R:95-96`.

## Regression Protection

- Extended existing KF parity micro-test:
  - `tests/testthat/test-ffbs-indexing-parity.R:46-47`
  - Asserts finite bridge `elbo_theta` and confirms `elbo.part` is not exposed in R-visible `theta.out`.
- Existing parity assertions for `sm`/`sC` remain in place in the same test.

## Verdict

- Dynamic `elbo.part` unresolved status is closed as **demoted to internal-only**.
- No formula change was required for package-level ELBO outputs.
