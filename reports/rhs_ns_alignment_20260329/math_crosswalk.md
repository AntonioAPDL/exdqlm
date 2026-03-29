# Wave 1 Mathematical Crosswalk Freeze (RHS-NS)

Generated: 2026-03-29

Worktree A (0.4.0 line): `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs`

Worktree B (qdesn line): `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline`

## 1. Purpose and scope

This document freezes the mathematical crosswalk required by Wave 1:

- Article appendix full conditionals -> theory derivations.
- Theory derivations -> implementation formulas.
- Parameterization conventions (IG, GIG, truncated Normal).
- Conditioning sets and support constraints for all blocks.
- Target closed-form RHS-NS hierarchy to be ported into static `0.4.0` in Wave 2.

This is the coding gate artifact for Wave 2.

## 2. Canonical mathematical baseline

Primary manuscript baseline:

- Article prior specification and appendix full conditionals:
  - `/home/jaguir26/local/src/Article-Q-DESN/main.tex:405-506`
  - `/home/jaguir26/local/src/Article-Q-DESN/main.tex:760-887`
- Theory baseline (full posterior, MCMC blocks, VB-CAVI, ELBO):
  - `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation/main.tex:148-357`
  - `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation/main.tex:359-565`

The canonical prior/appendix equations are aligned as follows:

- Conditional coefficient prior uses
  `V_j = (zeta^{-2} + tau^{-2} lambda_j^{-2})^{-1}` and
  `beta_j | lambda_j, tau, zeta ~ N(0, V_j)`.
- NS joint representation is written proportionally in `(beta_j, lambda_j)` and keeps `(tau, zeta)`-dependent Gaussian normalizers when deriving full conditionals for `tau^2` and `zeta^2`.
- IG auxiliary hierarchy:
  - `lambda_j^2 | nu_j ~ IG(1/2, 1/nu_j)`, `nu_j ~ IG(1/2, 1)`
  - `tau^2 | xi ~ IG(1/2, 1/xi)`, `xi ~ IG(1/2, 1/tau0^2)`
  - optional `zeta^2 ~ IG(a_zeta, b_zeta)`.

## 3. Parameterization freeze (W1.3)

### 3.1 IG convention

Frozen convention:

- `IG(a,b)` uses kernel `f(x) propto x^{-a-1} exp(-b/x)`, `x>0`.

Evidence:

- Article appendix setup: `/home/jaguir26/local/src/Article-Q-DESN/main.tex:786-789`
- Theory document: `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation/main.tex:176-184`
- qdesn implementation uses inverse-gamma sampling as `1 / rgamma(shape=a, rate=b)`:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:768-787`
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:791-795`

### 3.2 GIG convention

Frozen convention:

- `GIG(p, chi, psi)` uses kernel
  `f(x) propto x^{p-1} exp{-0.5*(chi/x + psi*x)}`, `x>0`.

Evidence:

- Article appendix setup: `/home/jaguir26/local/src/Article-Q-DESN/main.tex:790-793`
- Theory block for `v_t`: `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation/main.tex:289-306`
- Static MCMC comment explicitly maps R notation to C++ sampler:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_static_mcmc.R:3-7`
- C++ sampler argument convention (`p`, `a`, `b`) aligns with mapping
  `p <- p`, `a <- psi`, `b <- chi`:
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/src/sampling_utils.cpp:120-146`

### 3.3 Truncated Normal convention

Frozen convention for `s_t` block:

- Conditional factor is Normal with mean/variance form and truncation to `(0, infinity)`.
- Equivalent precision form is admissible: variance is `a_t^{-1}`.

Evidence:

- Article Block 5: `/home/jaguir26/local/src/Article-Q-DESN/main.tex:876-887`
- Theory Block (vi): `/home/jaguir26/local/src/Q-DESN---Theory-for-implementation/main.tex:308-326`
- Implementation sampling call with `(mu, tau2)`:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:1498-1503`
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/exal_static_mcmc.R:1019-1025`

## 4. Conditioning-set and support freeze (W1.4)

### 4.1 Conditioning sets by block

- Block 1 (`beta | rest`): condition on `(sigma, gamma, v_{1:T}, s_{1:T}, lambda, tau, zeta)`.
- Block 2 (`(sigma, gamma) | rest`): condition on all latent variables and current `beta`; retain non-conjugate kernel.
- Block 3 (global-local scales): condition on `beta` and companion latent scales (`nu`, `xi`, optional random `zeta^2`) under IG augmentation.
- Block 4 (`v_t | rest`): condition on `(beta, sigma, gamma, s_t)` and data at `t`.
- Block 5 (`s_t | rest`): condition on `(beta, sigma, gamma, v_t)` and data at `t`.

### 4.2 Support constraints

- `sigma > 0`
- `gamma in (L, U)`
- `v_t > 0`
- `s_t > 0`
- `lambda_j^2, nu_j, tau^2, xi, zeta^2 > 0`
- `X'WX + D^{-1}` must be SPD for stable Gaussian `beta` updates.

Implementation evidence for support checks:

- `v` GIG input validation and positivity guards:
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/exal_static_mcmc.R:327-341`
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/src/sampling_utils.cpp:125-139`
- Positive expected precision and SPD solve path in VB:
  - `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_ldvb_engine.R:761-780`

## 5. Crosswalk A: Article -> Theory (W1.1)

| Topic | Article evidence | Theory evidence | Crosswalk verdict |
|---|---|---|---|
| RHS variance and conditional prior for `beta_j` | `Article-Q-DESN/main.tex:437-447` | `Q-DESN---Theory-for-implementation/main.tex:227-235` | Exact match |
| NS proportional joint expression and interpretation | `Article-Q-DESN/main.tex:463-477` | `Q-DESN---Theory-for-implementation/main.tex:160-174` | Consistent (same conditional prior target) |
| IG auxiliary hierarchy for half-Cauchy scales | `Article-Q-DESN/main.tex:481-487` | `Q-DESN---Theory-for-implementation/main.tex:176-184` | Exact match |
| Block 1 (`beta`) | `Article-Q-DESN/main.tex:799-807` | `Q-DESN---Theory-for-implementation/main.tex:212-235` | Exact match |
| Block 2 (`sigma, gamma`) non-conjugate kernel | `Article-Q-DESN/main.tex:809-829` | `Q-DESN---Theory-for-implementation/main.tex:330-352` | Exact match |
| Block 3 (scales) | `Article-Q-DESN/main.tex:831-863` | `Q-DESN---Theory-for-implementation/main.tex:237-287` | Exact match |
| Block 4 (`v_t`) | `Article-Q-DESN/main.tex:865-874` | `Q-DESN---Theory-for-implementation/main.tex:289-306` | Exact match |
| Block 5 (`s_t`) | `Article-Q-DESN/main.tex:876-887` | `Q-DESN---Theory-for-implementation/main.tex:308-326` | Exact match |
| VB factorization and exact/approx split | `Article-Q-DESN/main.tex:568-583` | `Q-DESN---Theory-for-implementation/main.tex:364-500` | Theory expands article notation without conflict |
| ELBO decomposition | `Article-Q-DESN/main.tex:595-615` (algorithmic summary) | `Q-DESN---Theory-for-implementation/main.tex:501-535` | Theory provides full decomposition consistent with article narrative |

## 6. Crosswalk B: Theory -> Implementation (W1.2)

### 6.1 qdesn branch (reference implementation) - closed-form RHS-NS hierarchy present

- `beta` precision with slab-augmented additive precision:
  - `prec_j = 1/(tau2*lambda2_j) + 1/zeta2` for active coefficients.
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:693-699`
- Closed-form Gibbs updates for RHS-NS scale hierarchy:
  - `lambda2, nu, tau2, xi, zeta2` updates.
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:764-796`
- `v_t` and `s_t` updates match GIG/TN forms:
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:1490-1503`
- MCMC `beta` block uses `X'WX + diag(beta_prec_diag)` and `y_star` construction:
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_mcmc_fit.R:1505-1510`
- VB/CAVI prior updates and expected precision for RHS-NS:
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_rhs_ns_prior.R:177-197`
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_rhs_ns_prior.R:200-260`
- VB `q(beta), q(v), q(s)`, non-conjugate `q(sigma,gamma)`, and ELBO terms:
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_ldvb_engine.R:1041-1135`
  - Evidence: `/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/exal_ldvb_engine.R:1194-1329`

Verdict: qdesn branch is the correct computational anchor for closed-form RHS-NS hierarchy.

### 6.2 `0.4.0` static stack (current state) - not yet in closed-form RHS-NS hierarchy

Current `rhs_ns` static path uses transformed latent optimization/slice over
`(eta_lambda, eta_tau, eta_c2)`:

- Objective-based update (not IG block updates):
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/static_beta_prior.R:351-370`
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/static_beta_prior.R:743-803`
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/static_beta_prior.R:854-903`
- VB expected precision currently uses second-order correction from
  `Sigma_full` on transformed coordinates:
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/static_beta_prior.R:548-572`
- Static MCMC/VB exAL skeleton itself is consistent with blocking pattern for
  `v`, `s`, `beta`, and non-conjugate `(sigma,gamma)`:
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/exal_static_mcmc.R:1009-1055`
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/exal_static_LDVB.R:1270-1324`
  - `/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs/R/exal_static_LDVB.R:1673-1749`

Verdict: static `rhs_ns` in `0.4.0` is mathematically related but not the frozen closed-form IG hierarchy target. This is the principal discrepancy to be resolved in Wave 2.

## 7. Frozen target for Wave 2 (W1.5)

For static `0.4.0` RHS-NS, freeze the target hierarchy to the same closed-form block structure as the theory/qdesn anchor.

Let `A` be the active coefficient index set:

- if `shrink_intercept = FALSE`, `A = {2, ..., p}` and `m_active = p - 1`;
- if `shrink_intercept = TRUE`, `A = {1, ..., p}` and `m_active = p`.

Frozen conditional forms for `j in A`:

- `lambda_j^2 | rest ~ IG(1, 1/nu_j + beta_j^2/(2*tau^2))`
- `nu_j | rest ~ IG(1, 1 + 1/lambda_j^2)`
- `tau^2 | rest ~ IG((m_active+1)/2, 1/xi + 0.5*sum_{j in A}(beta_j^2/lambda_j^2))`
- `xi | rest ~ IG(1, 1/tau0^2 + 1/tau^2)`
- if slab random:
  `zeta^2 | rest ~ IG(a_zeta + m_active/2, b_zeta + 0.5*sum_{j in A} beta_j^2)`
- if slab fixed: `zeta^2 = zeta2_fixed`.

Frozen `beta` precision:

- active coefficients: `prec_j = 1/(tau^2*lambda_j^2) + 1/zeta^2`
- intercept when not shrunk: `prec_1 = intercept_prec`.

Frozen exact-vs-approx split:

- exact closed form: Blocks 1, 3, 4, 5.
- non-conjugate numerical block: Block 2 (`sigma, gamma`).

Frozen no-double-count rule:

- include slab contribution exactly once via additive precision term
  `+ 1/zeta^2` (or equivalent pseudo-data contribution), with no duplicated slab penalty in the same conditional kernel.

## 8. Wave 1 discrepancy register

- DR1 (major): `0.4.0` static `rhs_ns` currently updates scale hierarchy through transformed objective/slice, not through the frozen IG closed-form hierarchy.
- DR2 (clarity): active-set cardinality in shape updates must follow `m_active` under intercept policy, not always full `p`.
- DR3 (consistency): keep NS proportional-kernel constant handling explicit so `tau^2`/`zeta^2` shape terms remain correct.

## 9. Wave 1 coding gate decision

Wave 1 crosswalk is complete and internally consistent for coding.

Status: READY FOR WAVE 2 IMPLEMENTATION.
