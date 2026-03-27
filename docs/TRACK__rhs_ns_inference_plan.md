# TRACK: RHS_NS Augmented Conjugacy Path (VB + MCMC)

Date: 2026-03-26  
Branch: `feature/qdesn-mcmc-alternative`  
Scope: static exAL/AL readout inference and qdesn integration, with backward-compatible prior selection

## 0) Goal

Add a new beta-prior option, `rhs_ns`, that keeps the current `rhs` implementation intact while providing an alternative augmentation-based path designed for more closed-form updates and improved computational efficiency.

`rhs_ns` target:

1. Preserve regularized horseshoe behavior with random slab parameter support (no forced fixed slab parameter).
2. Support both CAVI/VB and MCMC with a coherent hierarchical model.
3. Keep current `rhs` (joint Laplace log-scale block) as a selectable baseline.
4. Make `qdesn` consume `rhs_ns` via existing inference plumbing with minimal user-facing disruption.

## 1) Why This Exists

Current `rhs` in this repo is a structured nonconjugate approximation over:

- `eta_lambda = log(lambda_j)`
- `eta_tau = log(tau)`
- `eta_c2 = log(c^2)`

implemented as a joint Laplace block with full covariance.

This is stable and useful, but it is not a mostly closed-form CAVI structure. The `rhs_ns` path is intended to trade some structural fidelity for stronger conditional conjugacy in the scale hierarchy.

## 2) Theory Anchors (Local References)

Primary local theory repo:

- `/home/jaguir26/local/src/RHS---Implementations`

Core papers (local files):

1. `/home/jaguir26/local/src/RHS---Implementations/Download.pdf`  
   Piironen–Vehtari regularized horseshoe:
   - finite slab regularization
   - slab-width prior recommendation (IG on slab variance, Student-t slab implication)
2. `/home/jaguir26/local/src/RHS---Implementations/nihms-1991193.pdf`  
   Nishimura–Suchard augmentation perspective:
   - fictitious-data/pseudo-data mechanism
   - preservation of global-local block conditionally on beta
3. `/home/jaguir26/local/src/RHS---Implementations/2507.10975v2.pdf`  
   robust Laplace-mixture modeling with horseshoe family and auxiliary-mixture Gibbs
4. `/home/jaguir26/local/src/RHS---Implementations/2101.00366v1.pdf`  
   Gibbs structure and geometric ergodicity context for regularized variants

Interpretation constraints used in this tracker:

1. Distinguish conditional equivalence from full joint-prior identity.
2. Distinguish what is closed form in the beta-scale hierarchy from what remains nonconjugate in exAL (`sigma, gamma` block).
3. Allow random slab parameter (no requirement to fix `zeta`/`c`).

## 3) Current Codebase Anchors

Current beta-prior object contract:

- `R/priors_beta.R`
- expected interface: `init(p)`, `expected_prec(state,p)`, `update(state,qbeta)`, `elbo(state,qbeta)`

Current RHS (Laplace log-scale block):

- `R/qdesn_rhs_prior.R`

Batch VB engine and exAL wrappers:

- `R/exal_ldvb_engine.R`
- `R/exal_ldvb_fit.R`
- `R/exal_static_LDVB.R`
- local closed-form exAL latent updates:
  - `R/exal_online_step.R`
  - `R/exal_online_state.R`

MCMC path:

- `R/exal_mcmc_fit.R`
- `R/qdesn_mcmc.R`

Config plumbing and prior-type resolution:

- `R/exal_inference_config.R`
- `R/qdesn_vb.R`
- `R/qdesn_model_selection_v2.R`

Online reuse path:

- `R/exal_online_vbld.R`

## 4) RHS_NS Model Target (Implementation Contract)

Base intention for `rhs_ns` beta prior block:

1. Keep Gaussian beta prior kernel:
   - `beta_j | tau^2, lambda_j^2 ~ N(0, tau^2 lambda_j^2)` with regularization mechanism.
2. Introduce NS-style augmentation for regularization:
   - pseudo-data latent layer producing slab-like regularization while preserving tractable conditional updates for scale block given beta.
3. Use half-Cauchy scale-mixture representation via inverse-gamma auxiliaries:
   - local: `lambda_j^2 | nu_j`, `nu_j`
   - global: `tau^2 | xi`, `xi`
4. Slab parameter:
   - random by default (`zeta^2` or `c^2`) with IG prior
   - optionally fixed through config for sensitivity studies

Design rule:

- `rhs_ns` must never remove or mutate behavior of current `rhs`; both must coexist.

## 5) CAVI/VB Requirements

### 5.1 Factorization Target

At minimum, support:

- `q(beta)` Gaussian
- `q(v_i)` and `q(s_i)` unchanged exAL local factors (already closed-form in current engine)
- `q(sigma,gamma)` unchanged LD block
- `q(rhs_ns_latents)` where scale/auxiliary factors are updated in closed form where possible

Recommended `rhs_ns` latent factorization:

- `q(lambda_1^2)...q(lambda_p^2)`
- `q(nu_1)...q(nu_p)`
- `q(tau^2)`
- `q(xi)`
- `q(zeta^2)` (if random slab)

### 5.2 Closed-Form Map (Target)

For the `rhs_ns` latent scale hierarchy:

1. `q(beta)`: Gaussian
2. `q(lambda_j^2)`: IG or GIG-form depending on chosen algebra
3. `q(nu_j)`: IG
4. `q(tau^2)`: IG or GIG-form depending on parameterization
5. `q(xi)`: IG
6. `q(zeta^2)`: IG when IG prior is used

Nonconjugate block expected to remain:

- `q(sigma,gamma)` in exAL path (LD update remains acceptable and expected)

### 5.3 ELBO Requirements

`rhs_ns` must provide an ELBO contribution function analogous to current `rhs`:

- exact entropy/log-joint terms for all closed-form factors
- stable numerics for log expectations (digamma/logdet guards)
- compatible with existing per-iteration ELBO accounting in `exal_ldvb_engine.R`

## 6) MCMC Requirements

`rhs_ns` MCMC path must provide:

1. Gibbs or blocked-Gibbs updates for beta + rhs_ns latent scales/auxiliaries.
2. Random slab parameter update (`zeta^2`/`c^2`) when configured random.
3. Optional fixed-slab mode for diagnostics/comparison.
4. Full compatibility with existing exAL latent updates and existing `gamma`/`sigma` path in `exal_mcmc_fit.R`.
5. Trace outputs analogous to existing RHS diagnostics where meaningful.

## 7) Backward Compatibility Rules

Non-negotiable:

1. Existing `beta_prior_type: rhs` behavior remains unchanged.
2. Existing `beta_prior_type: ridge` behavior remains unchanged.
3. New type is additive: `beta_prior_type: rhs_ns`.
4. Existing configs and scripts that do not mention `rhs_ns` must run unchanged.

## 8) File-Level Implementation Plan

### 8.1 New Files

1. `R/qdesn_rhs_ns_prior.R`
   - `qdesn_rhs_ns_prior_obj(...)`
   - state structure for augmented hierarchy
   - `init`, `expected_prec`, `update`, `elbo`

2. Optional helper file if needed:
   - `R/exal_mcmc_rhs_ns_helpers.R`
   - keep `exal_mcmc_fit.R` manageable

### 8.2 Files To Update

1. `R/priors_beta.R`
   - add `rhs_ns` constructor path
   - parse hypers/control/init for `rhs_ns`

2. `R/exal_inference_config.R`
   - allow `beta_prior_type` in `{ridge, rhs, rhs_ns}`
   - resolve `beta_prior_rhs_ns` defaults/hypers
   - extend `exal_make_beta_prior(...)`

3. `R/exal_ldvb_engine.R`
   - generalize hard-coded `type == "rhs"` branches to handle `rhs_ns` where appropriate
   - ensure prior-specific tracing does not assume only `rhs`

4. `R/exal_static_LDVB.R`
   - maintain compatibility with new prior type in wrapper paths

5. `R/exal_mcmc_fit.R`
   - add `rhs_ns` branch for beta-prior latent update
   - preserve current `rhs` slice path as-is

6. `R/qdesn_vb.R`
   - allow `beta_prior_type: rhs_ns`

7. `R/qdesn_mcmc.R`
   - allow `beta_prior_type: rhs_ns`

8. `R/qdesn_model_selection_v2.R`
   - allow and correctly instantiate `rhs_ns` in selection workflows

9. `R/exal_online_vbld.R` (if online support required in phase-1)
   - ensure refresh/update path works with `rhs_ns` state object

### 8.3 Tests To Add/Extend

1. `tests/testthat/test-exal-inference-config.R`
   - type validation includes `rhs_ns`
   - defaults/hyper resolution for `rhs_ns`

2. New tests suggested:
   - `tests/testthat/test-rhs-ns-prior-object.R`
   - `tests/testthat/test-exal-ldvb-rhs-ns-smoke.R`
   - `tests/testthat/test-exal-mcmc-rhs-ns-smoke.R`
   - `tests/testthat/test-qdesn-vb-rhs-ns-routing.R`
   - `tests/testthat/test-qdesn-mcmc-rhs-ns-routing.R`

3. Regression guard:
   - existing `rhs` tests and snapshots must continue to pass

## 9) Phased Checklist

## Phase A: Contract Freeze

- [ ] Confirm exact `rhs_ns` hierarchy and notation.
- [ ] Confirm random slab default and fixed slab override semantics.
- [ ] Confirm expected closed-form families for each latent factor.
- [ ] Freeze `rhs_ns` state schema and diagnostics schema.

## Phase B: Prior Object (VB Core)

- [ ] Implement `qdesn_rhs_ns_prior_obj` in new file.
- [ ] Implement stable `expected_prec` for beta update.
- [ ] Implement CAVI updates for latent scales/auxiliaries.
- [ ] Implement `elbo` contribution with numerical guards.
- [ ] Add unit tests for object contract and invariants.

## Phase C: Engine Integration (VB)

- [ ] Integrate `rhs_ns` in `beta_prior(...)` constructor path.
- [ ] Integrate `rhs_ns` in config resolver and `exal_make_beta_prior(...)`.
- [ ] Update `exal_ldvb_engine.R` type handling for `rhs_ns`.
- [ ] Add VB smoke tests (`exal` and `qdesn` entrypoints).
- [ ] Validate ELBO monotonicity behavior in smoke runs.

## Phase D: MCMC Integration

- [ ] Add `rhs_ns` latent update path in `exal_mcmc_fit.R`.
- [ ] Support random/fixed slab update modes.
- [ ] Add MCMC diagnostics for key `rhs_ns` scales.
- [ ] Add qdesn routing for `rhs_ns` in MCMC path.
- [ ] Add MCMC smoke/regression tests.

## Phase E: Compatibility + Validation

- [ ] Re-run existing `rhs` and `ridge` tests; verify no regressions.
- [ ] Verify prior-type selection works across scripts/config flow.
- [ ] Add example config snippets for `rhs_ns`.
- [ ] Compare `rhs` vs `rhs_ns` on representative small scenarios.
- [ ] Record differences in runtime, numerical stability, and fit behavior.

## Phase F: Documentation + Rollout

- [ ] Add user-facing notes to relevant docs/vignettes or config guides.
- [ ] Add tracker update summarizing implementation decisions and caveats.
- [ ] Mark rollout status and any deferred enhancements.

## 10) Acceptance Criteria

`rhs_ns` is accepted only if all hold:

1. `rhs_ns` selectable from both VB and MCMC qdesn paths.
2. Current `rhs` path remains fully available and unchanged by default.
3. Random slab parameter is supported (no mandatory fixed slab).
4. CAVI/VB latent-scale updates are closed-form where promised, with explicit documentation of any remaining nonconjugate blocks.
5. ELBO expressions are implemented and numerically stable.
6. Test coverage includes config routing, prior-object invariants, VB smoke, MCMC smoke, and backward-compatibility checks.
7. No unrelated functionality changes are introduced.

## 11) Risks and Mitigations

Risk: drift between theoretical hierarchy and implemented updates.  
Mitigation: lock model equations in code comments and this tracker before coding.

Risk: hard-coded `type == "rhs"` logic causes silent partial integration.  
Mitigation: grep-driven sweep and explicit checklist of touched conditionals.

Risk: ELBO mismatch due to missing entropy/expectation terms.  
Mitigation: isolate `rhs_ns` ELBO terms and test against finite-difference sanity checks where possible.

Risk: MCMC complexity growth in already-large file.  
Mitigation: optionally move `rhs_ns` MCMC helpers into a dedicated helper file.

## 12) Suggested Config Surface (Draft)

VB:

```yaml
pipeline:
  inference:
    method: vb
    vb:
      priors:
        beta:
          type: rhs_ns
          rhs_ns:
            tau0: 0.1
            # slab prior (random by default)
            slab:
              mode: random
              c2_prior:
                shape: 2.0
                scale: 8.0
```

MCMC:

```yaml
pipeline:
  inference:
    method: mcmc
    mcmc:
      priors:
        beta:
          type: rhs_ns
          rhs_ns:
            tau0: 0.1
            slab:
              mode: random
              c2_prior:
                shape: 2.0
                scale: 8.0
```

Note: exact key names can be adjusted during Phase A, but compatibility with existing config style is required.

## 13) Deliverables

Mandatory implementation deliverables:

1. New prior object file for `rhs_ns`.
2. Updated constructor/config routing for `rhs_ns`.
3. VB integration + ELBO integration.
4. MCMC integration.
5. Test additions and updates.
6. Tracker updates documenting final decisions and outcomes.

## 14) Current Status

Status: planning tracker created, implementation not started.

Immediate next action:

1. Execute Phase A contract freeze (notation + exact hierarchy + final config keys).
2. Start Phase B prior-object implementation with unit tests first.
