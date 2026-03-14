# TRACK: Q-DESN MCMC Alternative to VB

Date: 2026-03-14
Branch: `feature/qdesn-mcmc-alternative`
Owner: Q-DESN readout inference refactor
Status: phases A-E smoke integration are now in place on this branch; the next work is broader MCMC-focused evaluation, profiling, and refinement rather than benchmark reruns

## 0) Goal

Add an MCMC implementation for the Q-DESN readout that is:

- theory-consistent with the current Q-DESN / exAL hierarchy;
- a real alternative to the current VB path, not a separate experimental fork;
- integrated so the same Q-DESN reservoir/design code can be used with either
  inference method;
- usable from the existing simulation and real-data pipelines with a clean
  `vb` vs `mcmc` switch;
- tested at the sampler, model, and pipeline levels.

Benchmarking is intentionally on standby during this workstream. The first goal
is to make the MCMC readout correct, stable, and easy to route through the
existing Q-DESN stack.

## 0.1) Current State on 2026-03-14

The following items are implemented on `feature/qdesn-mcmc-alternative`:

- method-agnostic exAL dispatch via `exal_fit()`,
  `exal_posterior_draws()`, and `exal_posterior_predict()`;
- ridge and RHS MCMC readout support with Gibbs updates for the conjugate
  blocks and slice sampling for the nonconjugate blocks;
- `qdesn_fit_mcmc()` plus `qdesn_fit(method = "vb" | "mcmc")`, reusing the
  same DESN design/reservoir path as the VB implementation;
- explicit `inference.method` config handling in the simulation and real-data
  pipelines, while keeping legacy `cfg$vb` compatibility;
- pipeline timing/runtime artifacts so VB and MCMC runs can be compared on
  elapsed time and score summaries from saved outputs;
- focused pipeline smoke specs and a smoke-matrix runner covering
  sim/real x vb/mcmc x ridge/rhs;
- regression tests that exercise the pipeline boundary, not just the readout
  internals.

This means the implementation is now past the algorithm-only stage. The repo
can already execute the same sim/real workflow under either inference method on
controlled smoke configurations.

Important current status:

- the earlier RHS VB smoke pathology on tiny validation/smoke cases has now
  been traced and stabilized in the shared inference path;
- the remaining workstream focus stays on MCMC evaluation and refinement, not
  benchmark reruns.

## 1) Scope Boundaries

### In scope

- Static single-quantile exAL readout MCMC for a fixed design matrix `X`.
- Q-DESN integration for one quantile at a time using the same reservoir and
  design matrix construction already used by `qdesn_fit_vb()`.
- Support for both ridge and RHS beta priors.
- Posterior-draw and posterior-predictive APIs that match the current VB-facing
  downstream consumers.
- Simulation and real-data pipeline integration.
- New tests and diagnostics for MCMC correctness and efficiency.

### Out of scope for the first pass

- Online MCMC.
- Benchmark reruns or benchmark-specific tuning.
- C++ reimplementation before the R implementation is correct and validated.
- A full rework of historical `exdqlmMCMC()` state-space code.

## 2) Current Codebase Leverage

The implementation should reuse the following existing seams instead of
rebuilding everything:

- `R/qdesn_vb.R`
  - already contains the Q-DESN reservoir roll, design construction, and
    forecast recursion logic;
  - should remain the canonical place for design/state construction until a
    method-agnostic wrapper is introduced.
- `R/qdesn_design_only.R`
  - already exposes the reservoir/design layer without fitting the readout;
  - this is the right abstraction boundary to avoid duplicating DESN logic for
    MCMC.
- `R/exal_static_mcmc.R`
  - already contains a working static exAL Gibbs-style sampler for the ridge
    case with latent `v_t`, `s_t`, closed-form `beta`, and a nonconjugate
    `gamma` step;
  - should be mined, then generalized, rather than replaced blindly.
- `R/exdqlmMCMC.R`
  - older state-space MCMC code contains useful conventions for chain storage,
    diagnostics, and return-object style.
- `scripts/pipeline_sim_main.R` and `scripts/pipeline_real_main.R`
  - currently centralize fit, posterior-draw, and forecast dispatch;
  - these are the main integration points for `method = "vb"` versus
    `method = "mcmc"`.

## 3) Theory-Aligned Sampler Design

We work at a fixed quantile level `p0` and condition on the Q-DESN design
matrix `X`. The theory file already gives the Gibbs blocking structure for:

- `beta`
- `(sigma, gamma)`
- `(lambda, tau, c^2)` under RHS
- `v_t`
- `s_t`

The MCMC implementation should follow that structure directly.

### 3.1 Conjugate or closed-form blocks

These blocks should use exact Gibbs updates, not slice sampling:

1. `beta | rest`
   - multivariate Gaussian;
   - precision:
     `X' W X + D^{-1}`;
   - mean:
     `Sigma_beta X' W y*`.

2. `v_t | rest`
   - univariate GIG with index `1/2`;
   - use the existing GIG sampler already used elsewhere in the package.

3. `s_t | rest`
   - univariate truncated normal on `(0, Inf)`;
   - use the existing truncated-normal sampler already used elsewhere.

4. `sigma | rest`
   - keep the closed-form GIG update already used in `R/exal_static_mcmc.R`;
   - this is preferable to slice sampling because the conditional is available
     in a standard family.

### 3.2 Nonconjugate blocks

These blocks should use slice sampling on unconstrained coordinates.

1. `gamma`
   - transform to
     `eta_gamma = logit((gamma - L) / (U - L))`;
   - sample `eta_gamma` with univariate slice sampling;
   - include the transform Jacobian in the log-target.

2. RHS local scales `lambda_j`
   - transform to `eta_lambda_j = log(lambda_j)`;
   - update each coordinate with univariate slice sampling;
   - if `shrink_intercept = false`, exclude the intercept coefficient from the
     RHS local-scale block and keep its prior fixed separately.

3. RHS global scale `tau`
   - transform to `eta_tau = log(tau)`;
   - sample with univariate slice sampling.

4. RHS slab scale `c^2`
   - transform to `eta_c = log(c^2)`;
   - sample with univariate slice sampling.

This directly matches the user decision: use slice sampling for the
nonconjugate blocks.

## 4) Expressions To Derive and Lock Down

Before implementation, we should formalize the exact log-kernels used by the
slice steps and re-check the closed-form blocks against the current theory file.

### 4.1 `gamma` slice target

For fixed `beta`, `sigma`, `v`, `s`, the slice target on `eta_gamma` should be
the transformed version of:

- likelihood contribution through `A(gamma)`, `B(gamma)`,
  `C(gamma) |gamma|`;
- prior contribution `log pi_gamma(gamma)`;
- Jacobian term from `gamma = L + (U-L) plogis(eta_gamma)`.

Working log-target:

`log p(eta_gamma | rest) = log p(gamma(eta_gamma) | rest) + log |d gamma / d eta_gamma|`.

More explicitly, with

- `gamma = L + (U-L) plogis(eta_gamma)`,
- `lambda(gamma) = C(gamma) |gamma|`,
- `mu_t(gamma) = x_t' beta + lambda(gamma) sigma s_t + A(gamma) v_t`,

the log-kernel is

`ell_gamma(eta_gamma) = -(T/2) log B(gamma)
 - (1/2) sum_t (y_t - mu_t(gamma))^2 / (B(gamma) sigma v_t)
 + log pi_gamma(gamma)
 + log(U-L) + log plogis(eta_gamma) + log(1-plogis(eta_gamma))`.

This is the exact one-dimensional target the slice step should use.

### 4.2 `sigma` full conditional

The current static exAL MCMC code already uses a GIG draw for `sigma`. We
should write this explicitly into the theory/implementation note for the
Q-DESN readout path, using the same notation as the current exAL decomposition.

For fixed `beta`, `gamma`, `v`, `s`, let

- `lambda = C(gamma) |gamma|`,
- `r_t = y_t - x_t' beta - A(gamma) v_t`.

Then the conditional kernel for `sigma` is

`p(sigma | rest) propto sigma^{k_sigma - 1}
 exp{- (psi_sigma sigma + chi_sigma / sigma) / 2 }`,

with

- `k_sigma = -(a_sigma + 3T/2)`,
- `chi_sigma = sum_t r_t^2 / (B(gamma) v_t) + 2 sum_t v_t + 2 b_sigma`,
- `psi_sigma = (lambda^2 / B(gamma)) sum_t s_t^2 / v_t`.

So `sigma | rest` is a GIG draw and should remain a Gibbs step.

### 4.3 RHS slice targets

For each transformed RHS coordinate, write the log-target as:

- Gaussian prior term induced by
  `beta_j | lambda_j, tau, c^2 ~ N(0, V_j)`;
- corresponding hyperprior term;
- transform Jacobian term.

Concretely:

1. `eta_lambda_j`
   - uses `V_j(lambda_j, tau, c^2)`;
   - half-Cauchy prior on `lambda_j`;
   - Jacobian `+ eta_lambda_j`.

2. `eta_tau`
   - uses all `V_j`;
   - half-Cauchy prior with scale `tau0`;
   - Jacobian `+ eta_tau`.

3. `eta_c`
   - uses all `V_j`;
   - inverse-gamma prior on `c^2`;
   - Jacobian `+ eta_c`.

Writing these out:

1. `eta_lambda_j = log lambda_j`

`ell_lambda_j(eta_lambda_j) =
 - (1/2) log V_j
 - beta_j^2 / (2 V_j)
 + eta_lambda_j
 - log(1 + exp(2 eta_lambda_j))`,

where `V_j = tau^2 * (c^2 lambda_j^2) / (c^2 + tau^2 lambda_j^2)` and
`lambda_j = exp(eta_lambda_j)`.

2. `eta_tau = log tau`

`ell_tau(eta_tau) =
 - (1/2) sum_j [log V_j + beta_j^2 / V_j]
 + eta_tau
 - log(1 + exp(2 eta_tau) / tau0^2)`.

3. `eta_c = log c^2`

`ell_c(eta_c) =
 - (1/2) sum_j [log V_j + beta_j^2 / V_j]
 - (nu / 2) eta_c
 - nu s^2 / (2 exp(eta_c))`.

All three are smooth one-dimensional targets under coordinate-wise updates and
are therefore appropriate for slice sampling on transformed coordinates.

### 4.4 Ridge case

The ridge case should be a clean subset:

- no RHS latent state;
- `D^{-1}` is fixed;
- only `gamma` remains nonconjugate;
- this is the correct first implementation target because it removes the
  hardest nonconjugate block while preserving the same exAL likelihood.

## 5) Engineering Architecture

### 5.1 Readout-level API

Introduce a method-agnostic readout layer:

- `exal_fit(..., method = c("vb", "mcmc"))`
- `exal_posterior_draws(fit, ...)`
- `exal_posterior_predict(fit, X_new, ...)`

Keep the current functions for backward compatibility:

- `exal_ldvb_fit()`
- `exal_vb_posterior_draws()`
- `exal_vb_posterior_predict()`

Add the new MCMC functions:

- `exal_mcmc_fit()`
- `exal_mcmc_posterior_draws()` if needed as a thin wrapper;
- but downstream code should prefer the generic
  `exal_posterior_draws()` / `exal_posterior_predict()`.

### 5.2 Q-DESN-level API

Do not force downstream code to know how the readout was fit.

Recommended structure:

- keep `qdesn_fit_vb()` unchanged for backward compatibility;
- add `qdesn_fit_mcmc()`;
- add a new dispatcher:
  `qdesn_fit(..., method = c("vb", "mcmc"))`.

Internally:

- reservoir/design construction should remain shared;
- readout fitting should dispatch to `exal_ldvb_fit()` or `exal_mcmc_fit()`;
- the returned object should still be class `"qdesn_fit"` with
  `object$fit` holding either an `exal_vb` or `exal_mcmc` object.

### 5.3 Prior object contract

The current `beta_prior()` contract is VB-oriented. We should extend it so the
same prior object can support both inference engines.

Recommended direction:

- keep existing VB methods:
  - `init`
  - `expected_prec`
  - `update`
  - `elbo`
- add MCMC methods:
  - `mcmc_init`
  - `mcmc_sample_state`
  - `mcmc_prec_diag`
  - `mcmc_log_prior`

This keeps ridge and RHS under one prior interface and avoids hard-coding the
RHS sampler inside unrelated readout code.

## 6) Sampler Control Design

Add a dedicated `mcmc` control block rather than overloading `vb`.

Recommended config shape:

```yaml
inference:
  method: mcmc
  vb:
    ...
  mcmc:
    n_burn: 2000
    n_keep: 1500
    thin: 1
    n_chains: 4
    init: vb
    verbose: false
    store_latent_draws: false
    slice:
      width_gamma: 1.0
      width_lambda: 1.0
      width_tau: 1.0
      width_c2: 1.0
      max_steps_out: 100
      max_shrink: 1000
      adapt_during_burn: true
```

Backward compatibility policy:

- if `inference.method` is missing, default to `vb`;
- existing configs with only `vb:` remain valid;
- `vb.online` remains a VB-only feature.

## 7) Data Structures and Return Objects

The core downstream requirement is stable draw access.

### 7.1 `exal_mcmc` object

Recommended fields:

- `method = "mcmc"`
- `call`
- `control`
- `misc`
  - `p0`
  - `bounds`
  - prior metadata
  - runtime
- `chains`
  - `beta`
  - `sigma`
  - `gamma`
  - optional `v`
  - optional `s`
  - optional RHS latent states
- `summary`
  - posterior means, medians, intervals
  - acceptance / slice diagnostics
  - ESS, R-hat, autocorrelation summaries
- `last`
  - final chain state for restart

### 7.2 Draw interface

`exal_posterior_draws()` should return the same basic shape for both methods:

- `beta`: matrix `nd x p`
- `sigma`: length `nd`
- `gamma`: length `nd`
- `nd`

That lets:

- `forecast_paths.qdesn_fit()`
- `posterior_predict.qdesn_fit()`
- synthesis code
- sim/real pipelines

stay almost unchanged once they stop calling the VB-specific helper names.

## 8) Pipeline Refactor Plan

The current simulation and real-data scripts duplicate some inference-dispatch
logic. The MCMC work is the right time to centralize that.

### 8.1 First refactor

Move duplicated readout dispatch helpers out of scripts and into package code:

- `fit_exal_readout(...)`
- `get_exal_param_draws(...)`
- `predict_exal_readout(...)`

These helpers should:

- dispatch on `inference.method`;
- hide whether the fit object is `exal_vb` or `exal_mcmc`;
- present a uniform draw/predict interface to pipeline code.

### 8.2 Pipeline config handling

Update:

- `scripts/pipeline_sim_main.R`
- `scripts/pipeline_real_main.R`

so they:

- read `inference.method`;
- read `inference.vb` or `inference.mcmc`;
- keep legacy fallback to `cfg$vb`.

### 8.3 Reporting artifacts

All saved artifacts should record:

- `inference_method`
- method-specific control settings
- chain diagnostics if `mcmc`
- VB diagnostics if `vb`

This is required so simulation and real-data outputs remain comparable.

## 9) Efficiency Strategy

The MCMC path must be correct first, then optimized deliberately.

### Phase-1 efficiency choices

- keep the reservoir/design fixed and reuse `qdesn_build_design()` /
  `fit_readout = FALSE` flows;
- reuse existing compiled GIG / truncated-normal samplers;
- use scalar slice sampling for nonconjugate parameters on transformed scales;
- allow optional initialization from VB for faster warm starts;
- avoid storing full latent draws by default.

### Phase-2 efficiency options

- C++ implementation of repeated slice updates if profiling shows they dominate;
- blocking or elliptical proposals for subsets of RHS coordinates if univariate
  slice is too slow;
- Rao-Blackwellized summaries where possible;
- parallel chains at the outer level.

## 10) Testing Plan

### 10.1 Unit tests

- slice sampler invariants on transformed bounded and positive domains;
- `beta` Gaussian update dimensions and SPD handling;
- `v_t` and `s_t` closed-form update correctness on toy inputs;
- `sigma` GIG update sanity;
- RHS transformed log-target finite-value checks.

### 10.2 Model tests

- ridge MCMC on a small synthetic linear design:
  posterior means recover the data-generating signal reasonably;
- RHS MCMC smoke test:
  chain stays finite and does not violate domain constraints;
- multi-chain diagnostics test:
  R-hat and ESS fields are produced.

### 10.3 API compatibility tests

- `exal_posterior_draws()` returns the same fields for VB and MCMC;
- `posterior_predict.qdesn_fit()` works with both `exal_vb` and `exal_mcmc`;
- `forecast_paths.qdesn_fit()` works unchanged when given MCMC draws.

### 10.4 Pipeline tests

- simulation pipeline smoke config with `method = vb`;
- simulation pipeline smoke config with `method = mcmc`;
- real-data pipeline smoke config with `method = vb`;
- real-data pipeline smoke config with `method = mcmc`.

### 10.5 Regression tests

- existing VB behavior must remain unchanged when `method = vb`;
- config fallback from legacy `cfg$vb` must still work;
- MCMC introduction must not break benchmark code even though benchmark use is
  paused.

## 11) Rollout Phases

### Phase A: derivation and contract freeze

- Status: complete on this branch.
- write the exact log-targets and closed-form updates for the static readout;
- freeze the readout object contract and generic draw/predict API;
- decide final config schema.

### Phase B: ridge MCMC core

- Status: complete on this branch.
- implement `exal_mcmc_fit()` for ridge;
- implement generic draw/predict dispatch;
- add unit tests and synthetic recovery tests.

### Phase C: RHS MCMC

- Status: complete on this branch for the first R implementation.
- extend the prior contract for MCMC;
- implement slice updates for `lambda_j`, `tau`, `c^2`;
- add RHS diagnostics and smoke tests.

### Phase D: Q-DESN integration

- Status: complete on this branch.
- add `qdesn_fit_mcmc()` and `qdesn_fit()`;
- keep reservoir/design code shared;
- ensure forecast recursion works with MCMC draws.

### Phase E: pipeline integration

- Status: complete at the smoke-test level.
- refactor sim/real scripts to use inference dispatch helpers;
- add method-aware config and output recording;
- add smoke runs for both methods.

### Phase F: quality hardening

- Status: active on this branch.
- profile bottlenecks;
- improve storage defaults and diagnostics;
- document when VB or MCMC should be preferred.
- broaden the controlled validation campaign using the fixed VB RHS baseline.

## 11.1) Smoke Matrix Completion

The smoke-matrix layer is now implemented through:

- `scripts/mcmc_smoke_matrix.R`;
- eight explicit smoke specs covering
  sim/real x vb/mcmc x ridge/rhs;
- local committed datasets for reproducible non-benchmark smoke validation;
- pipeline summary collectors that read timing and score artifacts from saved
  runs.

The current completed matrix is:

- `sim_vb_ridge`
- `sim_vb_rhs`
- `sim_mcmc_ridge`
- `sim_mcmc_rhs`
- `real_vb_ridge`
- `real_vb_rhs`
- `real_mcmc_ridge`
- `real_mcmc_rhs`

All eight cases completed successfully in the latest smoke run.

## 11.2) Current VB vs MCMC Smoke Findings

These findings are only for the controlled smoke configurations used to validate
integration, runtime recording, and method comparability. They are not
benchmark claims.

- Ridge, real-data smoke:
  MCMC is about 1.37x slower than VB in wall time, but achieved better forecast
  CRPS and S scores on the latest smoke run.
- Ridge, simulation smoke:
  MCMC is about 1.38x slower than VB in wall time and was worse than VB on the
  latest smoke score summary.
- RHS, both real and simulation smoke:
  VB completed, but produced extremely unhealthy score magnitudes on the latest
  smoke configurations, while RHS MCMC produced finite and reasonable forecast
  scores.
- RHS, runtime cost:
  MCMC is about 1.54x to 1.56x slower than VB in wall time on the latest smoke
  runs.

Operational conclusion from the current smoke evidence:

- the new `vb | mcmc` dispatch is working in both sim and real-data pipelines;
- MCMC is slower, as expected, but currently gives the healthier RHS behavior
  on these smoke settings;
- the right next step is not benchmarking, but targeted MCMC evaluation,
  profiling, and refinement under larger non-benchmark study grids.

## 11.3) Validation Framework Planning

The next workstream is now split out into a dedicated validation-plan tracker:

- `docs/TRACK__qdesn_mcmc_validation_plan.md`

That file is the planning document for the post-smoke validation framework:

- single-root `vb -> mcmc` comparison;
- toy-scenario-first rollout;
- fixed artifact contract;
- expandable grid over scenarios, taus, priors, and seeds.

That framework is now implemented for the phase-0 pilot:

- toy-series generator;
- root runner;
- campaign runner;
- campaign collector;
- root/campaign plots and summaries;
- focused regression tests for the pilot artifact contract.

The next validation layer is also implemented on this branch:

- `config/validation/qdesn_mcmc_compare_defaults.yaml`
- `config/validation/qdesn_mcmc_compare_grid.csv`
- `scripts/run_qdesn_mcmc_full_comparison.R`

This phase-1 comparison extends the same root contract to a broader controlled
toy-study grid:

- scenarios:
  - `toy_sine_small`
  - `const_small`
  - `sin_asym_small`
  - `level_shift_small`
- taus:
  - `0.05`
  - `0.25`
  - `0.50`
- priors:
  - `ridge`
  - `rhs`
- seed:
  - `123`
- total roots:
  - `24`

The broader collector now also writes:

- grouped method summaries;
- grouped pair summaries;
- campaign stage-timing summaries;
- campaign chain-diagnostic summaries;
- a markdown campaign overview.

As of `2026-03-14`, the validation collector also includes a formal inference
signoff layer:

- `PASS / WARN / FAIL` grading for each `vb` fit;
- `PASS / WARN / FAIL` grading for each `mcmc` fit;
- pair-level comparison eligibility and pair-level signoff grading;
- report manifests that record the analysis SHA and signoff thresholds used for
  each collected campaign.

This was added after the full phase-1 run showed that execution health alone
was too weak a basis for tuning decisions.

## 12) Acceptance Criteria

We should consider the MCMC workstream ready for broader use only when all of
the following are true:

- the static exAL MCMC readout is correct on synthetic tests;
- ridge and RHS both run with finite chains on small Q-DESN examples;
- the same forecast and synthesis code can consume VB and MCMC draws;
- simulation and real-data pipelines can run with either method from config;
- existing VB runs are unchanged under legacy configs;
- chain diagnostics are stored and surfaced clearly enough to judge MCMC
  quality.

## 13) Immediate Next Actions

1. Use the completed phase-1 baseline plus the new signoff tables to choose
   default tuning targets for `vb` and `mcmc`.
2. Run the same phase-1 grid again under tuned settings so the comparison is
   baseline versus tuned, not one tuned method against one untuned method.
3. Profile runtime by stage and isolate the dominant cost centers for ridge and
   RHS MCMC separately.
4. Once the tuned single-chain campaign is stable, add a reduced multi-chain
   validation layer for final MCMC certification.
5. Only after the MCMC path is judged stable and informative should broader
   evaluation work resume.
