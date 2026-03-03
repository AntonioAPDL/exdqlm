# DQLM Conjugacy Tracker (gamma = 0)

## Document Control

- Status: Pre-implementation tracker (theory + checklist), updated with branch/revert protocol.
- Branch: `cransub/0.4.0`
- Date: 2026-03-03
- Objective: ensure DQLM mode (no gamma) is implemented with exact conjugate updates in MCMC and VB, for both dynamic and static setups, with correct ELBO and robust tests.
- Package repo: `/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp`

## Mandatory Git Hygiene (Before Any Implementation)

This section operationalizes your instruction to start from a clean `cransub/0.4.0`, then branch out.

Current verified baseline on package repo:

- `cransub/0.4.0` HEAD and `origin/cransub/0.4.0` at commit `e18710a`.
- There are local uncommitted DQLM-related edits in the working tree.
- Revert target on `cransub/0.4.0` right now: none (no committed DQLM-conjugacy commit exists yet on this branch).

Required workflow:

1. Preserve current local work on a safety branch.
   - `git switch -c wip/dqlm-preconjugacy-20260303`
   - `git add -A && git commit -m "wip(dqlm): pre-conjugacy local state snapshot"`
2. Return baseline branch and hard-sync it to remote baseline.
   - `git switch cransub/0.4.0`
   - `git fetch origin`
   - `git reset --hard origin/cransub/0.4.0`
   - verify HEAD is `e18710a`
3. Create implementation branch from clean baseline.
   - `git switch -c jaguir26/dqlm-conjugacy-cavi-gibbs`

Revert protocol if contamination happens:

- If any DQLM implementation commits are accidentally made directly on `cransub/0.4.0`, revert those exact hashes (newest first), then continue on the feature branch.
- Do not revert unrelated historical commits (for example `f2dcdd0`, `0a8187f`) unless explicitly requested.

## Why This Tracker Exists

When `dqlm.ind = TRUE` (or equivalently fixed `gamma = 0`), the model structure changes:

- There is no gamma parameter to infer.
- There is no `s_t` latent block in the reduced DQLM model.
- The sigma block is conjugate (GIG special case with `psi = 0`, i.e., inverse-gamma).
- LD/Laplace-Delta approximations over `(sigma, gamma)` should not be used.
- ELBO terms must be re-derived for the reduced factorization (no gamma block, no `s_t` block).

This tracker is the pre-implementation source of truth for:

- exact formulas to use,
- what is already wired vs missing,
- file-level checklist,
- tests and acceptance gates.

## External Theory Sources Reviewed

All requested references are local and were checked:

- `/data/muscat_data/jaguir26/univ-exDQLM---Ensemble/main.tex`
- `/data/muscat_data/jaguir26/Static-exAL-Regression---VB/main.tex`
- `/data/muscat_data/jaguir26/Static-exAL-Regression---MCMC/main.tex`

## Notation for DQLM Branch

Set `gamma = 0`. Define fixed constants:

- `A0 = A(p0, 0)`
- `B0 = B(p0, 0)`
- `lambda0 = C(p0, 0) * |0| = 0`

Important: all gamma-dependent expectations collapse to constants at `gamma = 0`.

Reduced latent structure in DQLM:

- Parameters/states: location states or regression coefficients, `sigma`.
- Augmentation variable: `v_t` only.
- Removed from reduced model: `gamma`, `s_t`.

## Canonical Conjugate Results to Enforce

### 1) Dynamic MCMC (DQLM, reduced model)

Reduced observation representation:

`y_t | eta_t, sigma, v_t ~ N(eta_t + A0 v_t, B0 sigma v_t)`

`v_t | rest ~ GIG(1/2, chi_t, psi_t)` with:

- `chi_t = (y_t - eta_t)^2 / (B0 sigma)`
- `psi_t = A0^2 / (B0 sigma) + 2 / sigma`

From dynamic exDQLM sigma conditional (GIG form), with `gamma = 0`:

- `u_t = C(p0, 0) * |0| * s_t = 0`, so `psi_sigma = 0`.
- Sigma conditional becomes inverse-gamma:

`q*(sigma | rest) = IG(alpha_dyn, beta_dyn)`

with

- `alpha_dyn = a_sigma + 3T/2`
- `beta_dyn = b_sigma + sum_t v_t + (1/(2B0)) * sum_t ((y_t - eta_t - A0 v_t)^2 / v_t)`

Equivalent GIG view: `GIG(k = -(a_sigma + 3T/2), chi = 2*beta_dyn, psi = 0)`.

Consequences in DQLM dynamic Gibbs:

- no MH step for gamma,
- no `s_t` sampling/storage block,
- full Gibbs chain over `{location states, v_t, sigma}`.

### 2) Static MCMC (DQLM, reduced model)

From static exAL sigma conditional:

- general: `sigma | . ~ GIG(k_sigma, chi_sigma, psi_sigma)`
- at `gamma = 0`: `psi_sigma = 0`, so inverse-gamma.

`q*(sigma | rest) = IG(alpha_stat, beta_stat)`

with

- `alpha_stat = a_sigma + 3n/2`
- `beta_stat = b_sigma + sum_i v_i + (1/(2B0)) * sum_i ((y_i - x_i^T beta - A0 v_i)^2 / v_i)`

### 3) Dynamic VB (CAVI, DQLM)

Factorization must reduce to:

`q(alpha_{0:T}) * prod_t q(v_t) * q(sigma)`

There is no `q(gamma)` and no `q(s_t)` block.

Parameter block reduces to univariate conjugate `q(sigma)`:

`q*(sigma) = IG(alpha_vb_dyn, beta_vb_dyn)`

where

- `alpha_vb_dyn = a_sigma + 3T/2`
- `beta_vb_dyn = b_sigma + D3 + (D1 - 2 A0 D2 + A0^2 D3)/(2 B0)`

and dynamic summary terms are those in `univ-exDQLM---Ensemble/main.tex`:

- `D1 = sum_t S_{Delta,t} * E[1/v_t]`
- `D2 = sum_t m_{Delta,t}`
- `D3 = sum_t E[v_t]`

Moment formulas for CAVI coupling:

- `E[1/sigma] = alpha_vb_dyn / beta_vb_dyn`
- `E[sigma] = beta_vb_dyn / (alpha_vb_dyn - 1)` (requires `alpha_vb_dyn > 1`)
- `E[log sigma] = log(beta_vb_dyn) - digamma(alpha_vb_dyn)`

Kappa simplifications in DQLM:

- `kappa4 = kappa5 = kappa6 = 0`
- `kappa1 = E[1/sigma] / B0`
- `kappa2 = A0 * E[1/sigma] / B0`
- `kappa3 = A0^2 * E[1/sigma] / B0`

Implication: DQLM CAVI updates for `q(alpha)` and `q(v_t)` must be written directly from the reduced model, not by carrying an `s_t` block and setting gamma terms to zero.

### 4) Static VB (CAVI, DQLM)

Factorization must reduce to:

`q(beta) * prod_i q(v_i) * q(sigma)`

There is no `q(gamma)` and no `q(s_i)` block.

From static joint kernel, setting `gamma = 0` and removing `s_i` terms:

`q*(sigma) = IG(alpha_vb_stat, beta_vb_stat)`

with

- `alpha_vb_stat = a_sigma + 3n/2`
- `beta_vb_stat = b_sigma + sum_i E[v_i] + (1/(2B0)) * sum_i Ri`

and

- `Ri = E[(y_i - x_i^T beta - A0 v_i)^2 / v_i]`
- using current VB moments:
  - `Ri = (y_i - x_i^T m_beta)^2 + x_i^T V_beta x_i - 2 (y_i - x_i^T m_beta) A0 + A0^2`

Same sigma moments as above apply.

## ELBO Changes Required in DQLM Branch

For both dynamic and static VB:

1. Remove/disable Laplace-Delta entropy and Jacobian terms for gamma.
2. Remove `s_t`/`s_i` prior and entropy ELBO blocks entirely.
3. Replace parameter block by:
   - `E[log p(sigma)] + log p(gamma = 0)` (gamma term is constant if treated degenerate).
4. Use IG entropy for `q(sigma)`:
   - `H[q(sigma)] = alpha + log(beta) + lgamma(alpha) - (1 + alpha) * digamma(alpha)`
5. All gamma-dependent expectation terms should be deterministic constants at `gamma = 0`.
6. ELBO diagnostics should not report gamma variational uncertainty in DQLM mode.

ELBO emphasis and guardrails:

- DQLM ELBO must be treated as a different objective from exDQLM ELBO because the latent/parameter factorization changes.
- Any inherited exDQLM ELBO term involving `s_t`, `gamma`, Jacobian, or LD covariance is a red flag in DQLM mode.
- Add ELBO component-level unit checks (not only total ELBO trend) to avoid silent algebra mistakes.

## Current Package Status (Audit Snapshot)

Status legend:

- `Implemented`: present in code path.
- `Partial`: behavior exists but not yet fully conjugate/clean by this spec.
- `Missing`: not implemented by this spec.

| Area | Status | Audit notes |
|---|---|---|
| Dynamic MCMC DQLM (`R/exdqlmMCMC.R`) | Implemented | Uses reduced DQLM Gibbs path with no gamma/no `s_t`, conjugate IG sigma. |
| Dynamic VB-IS DQLM (`R/exdqlmISVB.R`) | Missing (for reduced DQLM spec) | Still keeps exDQLM-style factors (`s_t`, IS over sigma/gamma-style block logic). Needs reduced CAVI derivation and coding. |
| Dynamic VB-LD DQLM (`R/exdqlmLDVB.R`) | Partial (working tree) | Conjugate sigma branch exists, but DQLM still needs strict reduced-factorization treatment (no `s_t` block in CAVI/ELBO). |
| Static MCMC DQLM (`R/exal_static_mcmc.R`) | Partial (working tree) | Conjugate sigma branch exists; still needs confirmation of reduced no-`s_i` implementation path. |
| Static VB-LD DQLM (`R/exal_static_LDVB.R`) | Partial (working tree) | Conjugate sigma and entropy branch exist; still needs reduced no-`s_i` CAVI/ELBO path. |
| DQLM logic coercion (`R/utils.R::check_logics`) | Implemented | Correctly coerces `fix.gamma = TRUE`, `gam.init = 0` when `dqlm.ind = TRUE`. |

## Implementation Checklist (What Must Be True Before Merge)

### A) Dynamic MCMC DQLM

- [ ] Confirm sigma full conditional exactly matches `IG(alpha_dyn, beta_dyn)` derivation.
- [ ] Confirm no gamma MH step executes in DQLM mode.
- [ ] Confirm no `s_t` object is sampled/stored/used in DQLM branch.
- [ ] Confirm `v_t` update uses reduced DQLM conditional (no `s_t` terms).
- [ ] Add/strengthen test asserting all `samp.gamma == 0` when applicable output exists.

### B) Dynamic VB-LD DQLM

- [ ] Ensure DQLM branch never calls LD mode optimization for `(sigma, gamma)`.
- [ ] Confirm `q(sigma)` update uses exact conjugate IG parameters from DQLM kernel.
- [ ] Confirm all gamma-dependent moments are constants at `gamma = 0`.
- [ ] Confirm no `q(s_t)` update exists in DQLM mode.
- [ ] Confirm ELBO branch excludes LD Jacobian/2D entropy and all `s_t` blocks in DQLM mode.
- [ ] Confirm returned objects clearly indicate degenerate gamma (`E.gam = 0`, var = 0 or omitted).

### C) Dynamic VB-IS DQLM

- [ ] Replace exDQLM-style IS gamma/sigma block by reduced DQLM conjugate `q(sigma)`.
- [ ] Remove `q(s_t)` in DQLM mode and re-derive `q(alpha), q(v_t)` from reduced model.
- [ ] Align ELBO computation with reduced DQLM blocks (`alpha`, `v`, `sigma` only).
- [ ] Keep output schema backward-compatible.

### D) Static MCMC DQLM

- [ ] Confirm static sigma IG formula uses correct `A0, B0` and latent terms.
- [ ] Confirm gamma fixed exactly at zero in all samples/returns.
- [ ] Confirm no `s_i` object is sampled/stored/used in DQLM branch.

### E) Static VB-LD DQLM

- [ ] Confirm no Laplace-Delta optimization in DQLM branch.
- [ ] Confirm sigma moments and entropy match IG formulas.
- [ ] Confirm no `q(s_i)` update exists in DQLM mode.
- [ ] Confirm ELBO decomposition uses reduced DQLM blocks only.

### F) Documentation and User-Facing Behavior

- [ ] Update `man/*.Rd` for DQLM branch behavior (conjugate sigma, gamma fixed).
- [ ] Clarify in docs that GIG with `psi = 0` is inverse-gamma in this parameterization.
- [ ] Add a short algorithm note in package docs for DQLM dynamic/static MCMC and VB.

## Test Plan (Must Exist Before Sign-Off)

### Unit tests

- [ ] Dynamic MCMC DQLM: gamma fixed at 0, finite sigma draws, stable posterior predictive draws.
- [ ] Dynamic LDVB DQLM: gamma fixed at 0, sigma moments finite, ELBO finite and stable.
- [ ] Static MCMC DQLM: gamma fixed at 0 and sigma finite.
- [ ] Static LDVB DQLM: gamma fixed at 0, sigma shape/scale valid.
- [ ] Dynamic/static DQLM: explicit test that no `s_t`/`s_i` latent block is present in DQLM code path.

### Formula-consistency tests

- [ ] Given frozen latent states, compare computed sigma posterior params against hand-calculated formulas.
- [ ] Given frozen state moments, compare reduced DQLM CAVI updates (`q(v)`, `q(sigma)`) against hand derivation.
- [ ] Check IG moment identities numerically:
  - `E[1/sigma] = alpha/beta`
  - `E[log sigma] = log(beta) - digamma(alpha)`

### Integration tests

- [ ] DQLM runs end-to-end for both dynamic and static paths without gamma-related errors.
- [ ] DQLM output schemas are valid for downstream plotting/forecasting/summary utilities.
- [ ] DQLM runs end-to-end without any `s_t`/`s_i` dependencies.

### Regression tests

- [ ] Existing exDQLM (gamma free) tests remain green.
- [ ] No behavior drift in non-DQLM branches.

## Acceptance Gates

### Gate G1: Theory lock

- [ ] Dynamic and static DQLM sigma formulas approved.
- [ ] Reduced-model (no gamma/no `s_t`) CAVI/Gibbs formulas approved.
- [ ] ELBO DQLM modifications approved with component checks.

### Gate G2: Implementation lock

- [ ] All target files updated and documented.
- [ ] No remaining code paths using LD block in DQLM mode.
- [ ] No remaining code paths using `s_t`/`s_i` blocks in DQLM mode.

### Gate G3: Validation lock

- [ ] New DQLM tests pass.
- [ ] Full `devtools::test()` passes.

### Gate G4: Parity lock

- [ ] DQLM results are numerically consistent with intended R reference behavior.
- [ ] Dynamic and static DQLM are both fully wired for package workflows.

## File-Level Work Map

Primary package files expected to be touched during implementation:

- `R/exdqlmMCMC.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmISVB.R`
- `R/exal_static_mcmc.R`
- `R/exal_static_LDVB.R`
- `R/utils.R`
- `man/exdqlmMCMC.Rd`
- `man/exdqlmLDVB.Rd`
- `man/exdqlmISVB.Rd`
- `man/exal_static_mcmc.Rd`
- `man/exal_static_LDVB.Rd`
- `tests/testthat/test-ldvb-dqlm-gamma-fixed.R`
- `tests/testthat/test-static-regression-regmod.R`
- (plus any new DQLM-specific dynamic test files)

## Open Decisions

1. In return objects for DQLM mode, should gamma variance be explicit `0` or omitted/`NA` for cleaner semantics?
2. Should DQLM-specific outputs explicitly expose reduced-factorization diagnostics (`alpha`, `v`, `sigma`) for clarity?

## Hold Point

Per your instruction, implementation is paused until your derivation document is provided.

## Immediate Next Step (After Your Derivation Doc Arrives)

Execute implementation in this order:

1. lock formulas from your derivation doc and map each to code blocks,
2. clean/sync `cransub/0.4.0` and branch out using the protocol above,
3. implement reduced DQLM Gibbs/CAVI (no gamma/no `s_t`) for dynamic and static,
4. implement ELBO with component-level checks,
5. add formula-consistency and integration tests,
6. run full package tests,
7. update tracker with final status and evidence.
