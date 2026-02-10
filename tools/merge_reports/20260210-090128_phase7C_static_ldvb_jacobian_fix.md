# Phase 7C Static LDVB Jacobian Alignment

- Date (UTC): 2026-02-10 09:01:28
- Branch: `integrate/v0.6.0-on-v0.5.0`
- Theory source: `/data/muscat_data/jaguir26/exAL---Regression/main.tex`
- Scope: static `(sigma,gamma)` LDVB transformed objective + entropy treatment.

## Theory Contract (Static `main.tex`)

- `sec:LD-sigmagamma` defines transformed coordinates `(rho, xi)` with `sigma=exp(rho)`, `gamma=h(xi)`.
- Jacobian is explicit: `log|J| = rho + log h'(xi)` (`main.tex` around Eq `eq:f-rho-xi`, lines ~1049-1053).
- Laplace objective must be optimized in transformed coordinates as
  `f(rho,xi)=log q^*(sigma,gamma)+rho+log h'(xi)+const` (Eq `eq:f-rho-xi`, lines ~1072-1091).
- Entropy contract for the original block is
  `H_{sigma,gamma}=H(N(hat_eta,Sigma_eta)) + E_q[rho + log h'(xi)]`
  (Eq `eq:H-sigmagamma`, lines ~1732-1757).
- ELBO can remain approximate/up-to-constants, but Jacobian placement must be internally consistent across transformed objective and entropy accounting.

## Code Changes

- Added internal helper for Jacobian term:
  - `R/exal_static_LDVB.R:2` `.exal_static_ld_log_jacobian()`.
- Added internal helper for transformed block objective with explicit Jacobian toggle:
  - `R/exal_static_LDVB.R:8` `.exal_static_ld_log_qsiggam(..., include_jacobian=TRUE)`.
- Wired LD mode objective to include Jacobian:
  - `R/exal_static_LDVB.R:241-266` (`log_qsiggam` calls helper with `include_jacobian = TRUE`).
- Added Jacobian expectation under Gaussian LD approximation:
  - `R/exal_static_LDVB.R:219` computes `zeta_logJ`.
  - `R/exal_static_LDVB.R:232` stores `zeta_logJ` in `xi` list.
- Updated static `(sigma,gamma)` entropy term in ELBO:
  - `R/exal_static_LDVB.R:452-455` now uses
    `H_qsg = H_gaussian(eta,ell) + E_q[log|J|]`.

## Correctness Verdict

- Static Jacobian issue is treated as a real correctness gap and is now fixed.
- Implementation now matches the manuscript contract for both transformed objective and entropy representation (up to constants).

## Test Coverage Added

- `tests/testthat/test-static-ldvb-jacobian.R`
  - Verifies transformed objective difference equals Jacobian term exactly when toggling `include_jacobian`.
  - Verifies LDVB run carries finite `zeta_logJ` and finite ELBO snapshot on tiny deterministic input.

## Notes

- Fix is localized; no public API changes were made.
- Runtime defaults/backends are unchanged.
