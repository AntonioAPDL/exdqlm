# Phase 7B Dynamic Theory Cross-Check (univ-exDQLM---Ensemble)

- Date (UTC): 2026-02-10 08:40:41
- Branch: `integrate/v0.6.0-on-v0.5.0`
- Theory source: `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`
- Scope: dynamic ISVB/LDVB/MCMC + KF/FFBS + LDVB `(sigma,gamma)` + ELBO conventions.

## Theory Anchors (Dynamic `main.tex`)

- **Dynamic hierarchy + exAL augmentation**: `sec:modelA`, `sec:exal_aug`, Eqs `eq:obs`, `eq:theta_evol`, `eq:aug_y`, `eq:p_map`, `eq:ABC`.
- **FFBS recursion/indexing**: `sec:ffbs`, Eqs `eq:ff_a`-`eq:ff_C`, `eq:bs_J`, `eq:bs_alpha` (smoothing gain uses `G_{t+1}^alpha`).
- **MCMC gamma transform/Jacobian**: `sec:mh_gamma`, Eqs `eq:gamma_transform`, `eq:gamma_jac`, `eq:mh_logr`.
- **VB/CAVI and LDVB block**:
  - Factorization/rule: `sec:vb`, Eqs `eq:vb_factorization`, `eq:cavi_rule`
  - Non-conjugate `(sigma,gamma)` block with Laplace-Delta: `sec:laplace_delta`, Eqs `eq:laplace_transform`, `eq:laplace_jac`, `eq:ell_u_xi`, `eq:grad_u`-`eq:hess_xixi`
- **ELBO**: `sec:elbo`, Eqs `eq:elbo_decomp`, `eq:Hsigmagamma`; practical monotonicity caveat in `sec:elbo` monotonicity subsection.

## Code Map (Dynamic)

- **ISVB entry + R FFBS fallback**: `R/exdqlmISVB.R:85`, `R/exdqlmISVB.R:269-318`
  - Backward smoothing gain uses `GG[,,(t+1)]`: `R/exdqlmISVB.R:304-311`
  - `(sigma,gamma)` importance block with ELBO diagnostics: `R/exdqlmISVB.R:320-429`
  - Backend routing R/C++ KF: `R/exdqlmISVB.R:438-450`
  - ELBO snapshot assembly: `R/exdqlmISVB.R:453-502`, loop usage `R/exdqlmISVB.R:565-590`
- **LDVB entry + R FFBS fallback**: `R/exdqlmLDVB.R:87`, `R/exdqlmLDVB.R:270-319`
  - Backward smoothing gain uses `GG[,,(t+1)]`: `R/exdqlmLDVB.R:304-312`
  - LD core with transformed `(theta_s, theta_g)` and Jacobian term: `R/exdqlmLDVB.R:330-355`
  - Jacobian contribution inside entropy-style term: `R/exdqlmLDVB.R:491-495`
  - Backend routing R/C++ KF: `R/exdqlmLDVB.R:557-569`
  - ELBO snapshot assembly and loop usage: `R/exdqlmLDVB.R:572-628`, `R/exdqlmLDVB.R:687-709`
- **MCMC dynamic path**: `R/exdqlmMCMC.R:51`
  - Gamma bounded transform + Jacobian in MH kernel:
    - transform defs: `R/exdqlmMCMC.R:203-205`
    - Jacobian in `logL`: `R/exdqlmMCMC.R:312-324`
  - FFBS smoothing uses `GG[,,(t+1)]` in both exDQLM and DQLM branches:
    - `R/exdqlmMCMC.R:283-290`
    - `R/exdqlmMCMC.R:464-471`
- **C++ bridge FFBS**: `src/kalman.cpp:155` (`update_theta_cpp`)
  - Backward smoothing uses `GG.slice(t+1)`: `src/kalman.cpp:281-289`

## Consistency Verdict By Block

### 1) FFBS indexing convention (`G_{t+1}`)
- **Verdict**: `OK`
- **Reason**: Theory `eq:bs_J` uses transition at `t+1`; both R fallback and C++ bridge use `(t+1)` indexing in backward recursion.

### 2) Dynamic MCMC gamma transformed MH
- **Verdict**: `OK`
- **Reason**: Code uses bounded transform + explicit Jacobian in log acceptance kernel (`R/exdqlmMCMC.R:312-324`), consistent with `eq:gamma_transform`/`eq:gamma_jac`/`eq:mh_logr` semantics.

### 3) Dynamic LDVB `(sigma,gamma)` transform/Jacobian
- **Verdict**: `Notation-mapped`
- **Reason**: Manuscript presents logistic transform (`eq:laplace_transform`), while code uses an alternative smooth bounded map `LL + (UU-LL)*exp(-exp(theta_g))` (`R/exdqlmLDVB.R:337`) with corresponding Jacobian term (`R/exdqlmLDVB.R:351-352`).
- **Impact**: Different coordinate chart, same constrained support treatment; Jacobian is accounted for in the transformed objective.

### 4) Dynamic ELBO labeling and approximation level
- **Verdict**: `Notation-mapped`
- **Reason**: Code computes an ELBO-like snapshot for convergence/diagnostics (`R/exdqlmISVB.R:453-502`, `R/exdqlmLDVB.R:572-628`) with optional block approximations (`gs_logZ` path), aligned with theory’s practical "approximate monotonicity" framing.

### 5) C++ ELBO part in KF bridge
- **Verdict**: `Unresolved (non-blocking)`
- **Evidence**: `src/kalman.cpp` includes internal ELBO part accumulation with inline comments (`src/kalman.cpp:273`, `src/kalman.cpp:308`, `src/kalman.cpp:363`) and is not the sole ELBO source used at package level.
- **Impact**: No immediate API/runtime break observed; derivation-level parity of this internal term is not fully audited here.

## Minimal Resolution Actions (No Behavior Change In This Chunk)

- No package code changes were applied in Phase 7B.
- Documented one non-blocking unresolved item for future derivation audit (`src/kalman.cpp` internal ELBO part).

## Follow-up Tests If/When Fix Is Applied

- Add one deterministic micro-test that compares R and C++ KF outputs (`sm`, `sC`) on a tiny synthetic setup with `exdqlm.use_cpp_kf` toggled.
- If C++ ELBO-part parity is addressed, add one finite comparison test for `elbo.part` tolerance against an R reference on the same tiny dataset.
