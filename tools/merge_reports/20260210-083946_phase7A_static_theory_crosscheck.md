# Phase 7A Static Theory Cross-Check (exAL---Regression)

- Date (UTC): 2026-02-10 08:39:46
- Branch: `integrate/v0.6.0-on-v0.5.0`
- Theory source: `/data/muscat_data/jaguir26/exAL---Regression/main.tex`
- Scope: static exAL regression mapping (`regMod`, static LDVB, static MCMC, static ELBO terms).

## Theory Anchors (Static `main.tex`)

- **Model + augmentation**: `\label{sec:latent-rep}`, Eqs `eq:aug_y`-style static analog in Section "Latent Variable Representation" (`y_i | beta,sigma,gamma,v_i,s_i` normal with mean shift and variance `sigma B(gamma) v_i`).
- **MCMC conditionals**:
  - `beta`: `eq:gibbs-beta-cov`, `eq:gibbs-beta-mean`
  - `s_i`: `eq:gibbs-si-ab`, `eq:gibbs-si-tn`
  - `v_i`: `eq:gibbs-vi-gig`, `eq:gibbs-vi-ab`
  - `sigma`: `eq:gibbs-sigma-gig`, `eq:gibbs-sigma-nu`, `eq:gibbs-sigma-c`, `eq:gibbs-sigma-d`
  - `gamma` kernel + transform/Jacobian: `eq:gibbs-gamma-kernel`, `eq:mh-accept`
- **VB/CAVI**:
  - Factorization/CAVI rule: `eq:mf-factorization`, `eq:cavi_rule`
  - Non-conjugate block: `eq:vb-sigmagamma-log`, `eq:vb-sigmagamma-kernel`
  - Laplace-Delta transform/Jacobian: Section `\label{sec:LD-sigmagamma}`, Eqs `eq:f-rho-xi`, `eq:f-rho-derivs`, `eq:f-xi-first`, `eq:f-rho-xi-mixed`, `eq:f-xi-xi`
- **ELBO**:
  - Definition/split: `eq:elbo-def`, `eq:elbo-split`
  - Entropy for transformed `(sigma,gamma)` block: `eq:H-sigmagamma`
  - Practical note: approximate ELBO up to constants (`sec:elbo`, practical evaluation subsection)

## Code Map (Static)

- **Builder (`regMod`)**: `R/regMod.R:40`
  - Static coefficients via `GG <- diag(n)` (`R/regMod.R:49`)
  - Observation design via `FF <- t(X)` (`R/regMod.R:48`)
- **Static LDVB (`exal_static_LDVB`)**: `R/exal_static_LDVB.R:50`
  - Transform `(eta, ell) <-> (gamma, sigma)`: `R/exal_static_LDVB.R:82-85`
  - `q(sigma,gamma)` kernel in transformed variables: `R/exal_static_LDVB.R:196-226`
  - CAVI blocks:
    - `q(beta)`: `R/exal_static_LDVB.R:278-295`
    - `q(v_i)` GIG: `R/exal_static_LDVB.R:296-312`
    - `q(s_i)` truncated normal: `R/exal_static_LDVB.R:313-317`
  - LD mode/Hessian: `R/exal_static_LDVB.R:228-262`, `R/exal_static_LDVB.R:318-325`
  - ELBO term-by-term assembly: `R/exal_static_LDVB.R:345-418`
- **Static MCMC (`exal_static_mcmc`)**: `R/exal_static_mcmc.R:60`
  - GIG parameterization declaration: `R/exal_static_mcmc.R:3-6`
  - Gamma transform + Jacobian: `R/exal_static_mcmc.R:125-133`
  - Gamma log-posterior kernel in transformed coord: `R/exal_static_mcmc.R:136-155`
  - Update blocks:
    - `v`: `R/exal_static_mcmc.R:208-215`
    - `s`: `R/exal_static_mcmc.R:217-223`
    - `beta`: `R/exal_static_mcmc.R:224-235`
    - `sigma`: `R/exal_static_mcmc.R:236-244`
    - `gamma` (Laplace-based draw in eta): `R/exal_static_mcmc.R:246-250`
- **Exports**: `NAMESPACE:21-22`, `NAMESPACE:39`

## Consistency Verdict By Block

### 1) Static regression builder (`regMod`) vs state-space static-coefficient setup
- **Verdict**: `OK`
- **Reason**: `FF=t(X)` + `GG=I` directly matches static coefficient evolution and design mapping expected by the static model equations.

### 2) MCMC full-conditionals (`v`, `s`, `sigma`) and support conventions
- **Verdict**: `OK`
- **Reason**: GIG and truncated-normal forms in `R/exal_static_mcmc.R:208-244` match the conditional kernels anchored by `eq:gibbs-vi-gig`, `eq:gibbs-si-tn`, `eq:gibbs-sigma-gig`.

### 3) Gamma transformed update and Jacobian handling in static MCMC
- **Verdict**: `Notation-mapped`
- **Reason**: Theory presents MH in transformed coordinates (`eq:mh-accept`), while code uses a Laplace-based local-normal draw (`R/exal_static_mcmc.R:246-250`) with transformed log-kernel including Jacobian (`R/exal_static_mcmc.R:154`).
- **Impact**: Approximation choice is explicit in function docs (`R/exal_static_mcmc.R:10-12`), but not mathematically identical to the exact MH step in the manuscript.

### 4) Static LDVB non-conjugate `(sigma,gamma)` block
- **Verdict**: `Unresolved`
- **Evidence**:
  - Transformed objective used for optimization is defined in `R/exal_static_LDVB.R:196-226`.
  - Explicit Jacobian terms expected from transformed density (`rho + log h'(xi)` style in theory) are not visibly present in this objective or in `H_qsg` (`R/exal_static_LDVB.R:411-413`).
- **Risk**: Potential mismatch between the manuscript’s transformed-density treatment and the implemented LD objective/entropy for `(sigma,gamma)`.
- **Action**: Defer to a targeted derivation review before modifying algorithmic code.

### 5) Static ELBO labeling
- **Verdict**: `Notation-mapped`
- **Reason**: ELBO is assembled term-by-term (`R/exal_static_LDVB.R:345-418`) under LD and MC moment approximations. This aligns with "approximate ELBO" conventions in theory, but exact constant conventions are not fully documented in package-facing docs.

## Minimal Resolution Actions (No Behavior Change In This Chunk)

- No package code changes were applied in Phase 7A.
- Documented one `Unresolved` block (static LDVB Jacobian/entropy alignment) requiring a dedicated derivation check before any fix.

## Follow-up Tests If/When Fix Is Applied

- Add one high-signal finite-difference check on the transformed `(eta, ell)` objective to verify Jacobian inclusion in gradient/Hessian numerics.
- Add one tiny deterministic static LDVB smoke test asserting ELBO trace stability with fixed seed and fixed synthetic data.
