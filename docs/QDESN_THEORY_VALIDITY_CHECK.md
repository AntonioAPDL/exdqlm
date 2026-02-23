# QDESN Theory Validity Check

Date: 2026-02-23

Scope:
- Theory source: `theory/Q-DESN---Theory-for-implementation/main.tex`
- Implementation path used in pipelines:
  - `R/qdesn_vb.R`
  - `R/exal_ldvb_fit.R`
  - `R/exal_ldvb_engine.R`
  - `R/priors_beta.R`
  - `R/qdesn_rhs_prior.R`
  - `R/00_utils.R`
  - `R/utils.R`
  - `R/exdqlm_synthesize_from_draws.R`

## 0) Constraint Compliance (This Rerun)

- Article file excluded from all comparisons and edits:
  - `/data/muscat_data/jaguir26/Article-Q-DESN/main.tex`
- Validation rerun used only:
  - Theory file: `theory/Q-DESN---Theory-for-implementation/main.tex`
  - Implementation files: `R/*.R` under `exdqlm`
- Online VB text adjustments were applied only to:
  - `theory/Q-DESN---Theory-for-implementation/main.tex`

## 1) Wiring Map (What Runs in Practice)

Primary fit path (used by QDESN):

1. `qdesn_fit_vb()` builds DESN states and readout matrix `X` (`R/qdesn_vb.R`).
2. `qdesn_fit_vb()` calls `exal_ldvb_fit(...)` (`R/qdesn_vb.R`).
3. `exal_ldvb_fit()` normalizes args and calls `exal_ldvb_engine(...)` (`R/exal_ldvb_fit.R`).
4. `exal_ldvb_engine()` runs CAVI + Laplace-Delta updates (`R/exal_ldvb_engine.R`).
5. Beta prior block is injected via `beta_prior(...)` (`R/priors_beta.R`):
   - ridge: fixed diagonal precision
   - rhs: `qdesn_rhs_prior_obj(...)` with Laplace state updates (`R/qdesn_rhs_prior.R`).
6. exAL constants and gamma support use `A.fn/B.fn/C.fn` and `L.fn/U.fn` (`R/utils.R`) via `exal_get_ABC(...)` (`R/00_utils.R`).
7. Multi-quantile predictive synthesis uses `exdqlm_synthesize_from_draws(...)` (`R/exdqlm_synthesize_from_draws.R`).

## 2) Theory-to-Code Alignment Matrix

| Theory block | Implementation status | Evidence | Decision |
|---|---|---|---|
| exAL Gaussian-mixture observation model with latent `v_t, s_t` | Aligned | `R/exal_ldvb_engine.R` (`qv`, `qs`, `log_qsiggam`) | Keep as canonical |
| Readout quantile function `x_t^T beta` | Aligned | `R/qdesn_vb.R` readout construction + `mu_hat = X %*% qbeta$m` | Keep |
| `q_beta` closed-form Gaussian update | Aligned | `update_qbeta()` in `R/exal_ldvb_engine.R` | Keep |
| `q_{v_t}` as GIG(1/2, chi, psi) | Aligned | `.gig_half_moments()` in `R/00_utils.R` + qv update in `R/exal_ldvb_engine.R` | Keep |
| `q_{s_t}` as truncated normal | Aligned | `tn_moments()` + qs update in `R/exal_ldvb_engine.R` | Keep |
| Joint non-conjugate block `(sigma, gamma)` with transformed coordinates and Laplace-Delta | Aligned | `log_qsiggam()`, `find_mode_ld()`, `compute_xi_fast()` in `R/exal_ldvb_engine.R` | Keep |
| Regularized horseshoe prior structure (`lambda_j`, `tau`, `c^2`) | Aligned | `rhs_obj_eta()` and Hessian logic in `R/qdesn_rhs_prior.R` | Keep |
| ELBO as convergence monitor | Aligned | `compute_elbo_current()` and stopping in `R/exal_ldvb_engine.R` | Keep |
| Mean-field factorization includes explicit `q_{lambda,tau,c2}` factor | Partially aligned (implemented as modular prior-state Laplace block, not explicit top-level factor object) | `beta_prior_obj$update/expected_prec/elbo` in `R/qdesn_rhs_prior.R`; consumed by `R/exal_ldvb_engine.R` | Accept; document as implementation form |
| Pure batch CAVI without scheduling/gating | Intentionally deviated | RHS tau gating (`rhs_tau_local_tol`, warmup, min/max updates) in `R/exal_ldvb_engine.R` | Keep for stability; document as pragmatic extension |
| Unbounded transformed optimization variables | Intentionally deviated | finite bounds on `eta`, `ell` and log-scales in engine/prior | Keep for numerical robustness |
| Intercept always shrunk under RHS | Intentionally deviated (optional non-shrunk intercept supported) | `shrink_intercept` path in `R/qdesn_rhs_prior.R` | Keep; add note in theory appendix |

## 3) Main Discrepancies and What To Do

1. `q_{lambda,tau,c2}` representation mismatch (theory vs code shape)
- Status after rigorous check (2026-02-23): resolved as an interface/notation difference, not a model mismatch.
- Theory writes an explicit factor; code stores the same factor state inside `beta_prior_obj` (`eta` mode, full Laplace covariance, ELBO term).
- Action: Keep code as-is; keep the theory wording that this factor is implemented on unconstrained Gaussian coordinates.

2. Extra optimization safeguards in code
- Finite bounds on transformed variables and gated tau updates are not explicit in current theory.
- Action: Keep safeguards; add an "implementation notes" paragraph (engineering layer over theory).

3. Duplicate LDVB implementations
- `R/exal_static_LDVB.R` and `R/exal_ldvb_engine.R` both implement similar ideas.
- Pipeline/QDESN path currently uses `exal_ldvb_engine` through `exal_ldvb_fit`.
- Action: declare canonical path (`exal_ldvb_engine`) for QDESN and treat `exal_static_LDVB` as secondary/legacy.

4. RHS expected precision exactness (fixed)
- `expected_prec` in `R/qdesn_rhs_prior.R` now uses the exact Gaussian-moment identity for
  `E_q[1/V_j] = E_q[exp(-eta_c)] + E_q[exp(-2 eta_tau - 2 eta_lambda_j)]`.
- This removes the prior delta-approximation bias for this specific moment while keeping the same Laplace Gaussian factor.
- Action: keep this as canonical for RHS precision updates.

## 4) Validity Verdict

Overall verdict: **theory and implementation are strongly aligned** on model definition and inference architecture.

- Core exAL hierarchy, CAVI blocks, Laplace-Delta treatment, and RHS structure are consistent.
- Remaining differences are implementation-level stabilizers and software factoring choices, not conceptual contradictions.

## 5) Immediate Next Steps for Safe Development

1. Keep `R/exal_ldvb_engine.R` as the single reference implementation for QDESN updates.
2. Keep theory symbols aligned with engine symbols (`xi_*`, transformed `(eta, ell)`, RHS log-scale parameters).
3. For future parameter-space changes, tune only config/search layers first, not inference equations.
4. Add online-VB formulation to theory (done in `theory/Q-DESN---Theory-for-implementation/main.tex`) before coding streaming updates.

## 6) Rigorous Check: `q_{lambda,tau,c2}` Representation Mismatch

Repro script:
- `scripts/check_rhs_representation_mismatch.R`

Date run:
- 2026-02-23

### 6.1 Equation-Level Equivalence (Theory Kernel vs Code Objective)

Theory block:
- Mean-field factorization includes `q_{\\lambda,\\tau,c^2}` in `theory/Q-DESN---Theory-for-implementation/main.tex` (`\\eqref{eq:mf-factorization}`).
- Joint kernel `\\ell_{\\lambda,\\tau,c^2}` appears in `\\eqref{eq:lambda-tau-c2-kernel}`.
- Log-scale Jacobian is `\\eqref{eq:jac-lambda-tau-c2}`.
- VB Gaussian approximation on transformed coordinates is `\\eqref{eq:vb-q-lambda}`.

Implementation block:
- `rhs_obj_eta()` in `R/qdesn_rhs_prior.R` contains:
  - `-0.5 * sum(logV + beta2 * invV)` from `p(beta | lambda,tau,c2)`
  - `sum(eta_lambda - log(1+exp(2 eta_lambda)))` for half-Cauchy `lambda`
  - `eta_tau - log(1+exp(2(eta_tau-log tau0)))` for half-Cauchy `tau`
  - `-(nu/2) eta_c - (nu s^2)/(2 exp(eta_c))` for IG on `c^2` after Jacobian

Numerical result:
- Objective difference (code vs transformed-theory expression): `max abs = 7.105427e-15` over randomized stress tests.

Conclusion:
- The transformed kernel in code is mathematically identical to the theory kernel up to additive constants.

### 6.2 Representation/Shape Equivalence

Theory notation:
- Writes `q_{\\lambda,\\tau,c^2}` as an explicit mean-field factor.

Code wiring:
- `update_qbeta()` in `R/exal_ldvb_engine.R` consumes `beta_prior_obj$expected_prec(beta_state, p)`.
- `beta_state <- beta_prior_obj$update(beta_state, qbeta)` updates the latent RHS factor state each iteration.
- `compute_elbo_current()` adds `beta_prior_obj$elbo(beta_state, qbeta)$elbo`.

Shape checks from script:
- `length(eta_lambda_hat) = p`
- `dim(Sigma_full) = (p+2) x (p+2)`
- Active-block inverse consistency `max ||(-H) Sigma - I||_inf = 7.771561e-16`
- ELBO identity (manual vs code) `max abs = 3.552714e-15`

Conclusion:
- The factor is present and updated consistently; it is represented as a modular state object rather than a separate top-level R list named `q_{lambda,tau,c2}`.

### 6.3 Hessian/Laplace Consistency

Check:
- Closed-form Hessian `.rhs_hess_active()` vs finite-difference Hessian (Richardson) on random points.

Result:
- `max abs = 2.692105e-06`
- `p95 abs = 6.381299e-07`
- `median abs = 8.399953e-09`

Conclusion:
- Laplace curvature implementation is consistent with the transformed objective.

### 6.4 Post-Fix Exact-Moment Confirmation for `E_q[1/V_j]`

Check:
- Compare code `expected_prec` (exact Gaussian-moment implementation) with direct exact Gaussian moments:
  - `E[exp(-eta_c)] = exp(-mu_c + 0.5 Var_c)`
  - `E[exp(-2 eta_tau - 2 eta_lambda_j)] = exp(-2(mu_tau+mu_lambda_j) + 2 Var(eta_tau+eta_lambda_j))`

Result (relative error `|code-exact|/exact`, pooled):
- `median = 0`
- `p90 = 0`
- `p95 = 0`
- `max = 0`

Conclusion:
- `expected_prec` now matches exact Gaussian moments for this block.
- No approximation mismatch remains for `E_q[1/V_j]`.

### 6.5 Final Decision on the Original Issue

- The original `q_{lambda,tau,c2}` shape mismatch is **resolved** as notation/software factoring.
- No crucial structural mismatch was found in objective, Hessian, ELBO, or factor wiring.
- The previous `expected_prec` approximation gap is fixed by exact Gaussian-moment computation.
