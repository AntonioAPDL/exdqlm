# TRACK: Q-DESN DLM Decomposition-Informed Input Plan

Date: 2026-03-17
Branch: `feature/qdesn-mcmc-alternative`
Status: Phases 0-6 implemented and validated (R + C++ NDLM backend, decomposition-aware fit/forecast, sim/real pipeline integration, parity/regression coverage, automatic seasonal harmonic selection)

## Document Placement Note

This plan is placed in `docs/` with a `TRACK__...md` prefix because this branch already uses that pattern for implementation trackers and design plans (for example `docs/TRACK__qdesn_mcmc_plan.md`, `docs/TRACK__qdesn_mcmc_validation_plan.md`, `docs/TRACK__qdesn_rhs_mcmc_repair_plan.md`).

## 0. Readiness Recheck (2026-03-17, post-implementation)

Status update: this tracker now reflects completed implementation for both simulation and real-data pipelines with:
- YAML controls for seasonal period/harmonics and polynomial trend degree,
- optional automatic top-k seasonal harmonic selection from spectral scores at harmonic frequencies,
- a derivation-first C++ NDLM Kalman filter/smoother implementation (`src/kalman_ndlm.cpp`),
- R/C++ backend dispatch and fallback wiring for NDLM filter/smoother + structured forecast roll-forward,
- decomposition-aware reservoir-input recursion in fit/forecast/lattice paths,
- regression/parity tests and end-to-end smoke runs for decomposition-enabled and raw-baseline modes.

Implementation completion summary:
- `R/qdesn_dlm_decomposition.R`:
  - R NDLM reference implementation with unknown constant variance updates (`l_t`, `S_t`),
  - C++/R backend wrappers (`qdesn_ndlm_filter_smooth`, `qdesn_ndlm_structured_forecast`),
  - runtime preparation carrying `backend_requested`/`backend_effective`,
  - decomposition trajectory roll-forward now backend-dispatched.
- `src/kalman_ndlm.cpp`:
  - `dlm_ndlm_filter_smooth_cpp` (filter + smoother + variance-sequence outputs + intermediates),
  - `dlm_ndlm_structured_forecast_cpp` (origin-indexed structured roll-forward),
  - SPD-safe solves with jitter escalation and explicit dimension/validity checks.
- `R/qdesn_vb.R`:
  - decomposition input mode active in training and recursive forecasting paths,
  - origin-causal decomposition state initialization in lattice forecasting,
  - metadata wiring preserved for backward compatibility.
- Pipeline/model-selection integration:
  - sim/real pipelines and model-selection utilities pass decomposition config through to `qdesn_fit_vb`,
  - `config/defaults.yaml` includes trend/seasonal/variance/backend controls.
- Tests and execution evidence:
  - `tests/testthat/test-qdesn-dlm-phase2-integration.R`,
  - `tests/testthat/test-qdesn-dlm-phase3-ndlm-backend.R`,
  - baseline smoke/inference suites pass,
  - decomposition-enabled and raw-baseline sim/real pipeline smoke runs complete successfully.

### 0.1 Explicit inventory: implemented vs still-open items

Implemented in this repository/branch:
- decomposition mode wiring in `qdesn_fit_vb`, `forecast_paths.qdesn_fit`, and `forecast_lattice.qdesn_fit`,
- YAML/config controls:
  - `decomposition.trend.degree` (`0=level`, `1=linear`, `2=quadratic`, ...),
  - `decomposition.seasonal.period`,
  - `decomposition.seasonal.harmonics`,
  - `decomposition.seasonal.auto` (`enabled`, `top_k`, `min_harmonic`, `max_harmonic`, `use_log_score`, `center`, `prefer_manual`),
  - decomposition lag/discount/variance/forecast-recursion options,
- dedicated NDLM C++ backend + R wrappers and runtime backend-effective reporting,
- R/C++ parity and integration tests across filter/smoother outputs and structured trajectories.

Confirmed reference/equivalence stance:
- `R/utils.R::dlm_df` remains the behavior reference target for filtered moments and variance recursion.
- `src/kalman.cpp` remains non-equivalent for this feature and is not used as the NDLM implementation path.

Still-open items (non-blocking for current implementation):
- broaden parity stress coverage (very long seasonal periods/high-order trend stress fixtures),
- optional future C++ support for full decomposition path forecasting (current decomposition forecasting intentionally uses R recursion path for compatibility),
- optional stricter production gate to hard-fail instead of fallback when `backend=cpp` fails in runtime environments.

## 1. Executive Summary

Goal: add an optional Q-DESN input-construction mode that replaces raw lag inputs with lagged decomposition features from a causal DLM/state-space decomposition of `y_t` into trend, seasonal, and residual components.

Why useful:
- The current ESN reservoir input is built from raw `y` lag buffers.
- This can be extended upstream so the reservoir receives structured lag signals (trend/seasonal/residual) while leaving the inferential core unchanged.

What should stay unchanged:
- Reservoir architecture and state transition equations in `qdesn_fit_vb`.
- Readout inference machinery (`exal_fit`, VB/MCMC implementations, ridge/RHS prior objects).
- Forecasting framework (`forecast_paths.qdesn_fit`, `forecast_lattice.qdesn_fit`) as the main recursion/sampling engine.

What should change:
- Input feature builder feeding the reservoir and matching forecast-time recursion for those features.
- Configuration and readout metadata (`readout_spec`-style) to select and parameterize decomposition-informed inputs.

## 2. Current Repository Wiring

### 2.1 Top-level structure and entry points

Relevant top-level directories:
- `R/`: package functions for model fitting, priors, forecasting, inference config.
- `scripts/`: pipeline entry scripts and orchestration wrappers.
- `config/`: defaults and spec overlays.
- `tests/testthat/`: smoke and regression tests.
- `docs/`: tracker/design notes.
- `src/`: C++ forecast backend (`forecast_paths_cpp`).

Primary pipeline entry flow:
- `scripts/pipeline_run.R`:
  - loads/merges `config/defaults.yaml`, mode overrides, dataset entry, and optional spec YAML;
  - writes `manifest/cfg_effective.yaml` and `manifest/cfg_effective.json`;
  - sets env vars (including `EXDQLM_CFG_JSON`) and dispatches main pipeline script.
- `scripts/pipeline_main.R`:
  - dispatches by mode to `scripts/pipeline_sim_main.R` or `scripts/pipeline_real_main.R`.
- `R/run_esn_pipeline.R::run_esn_pipeline_from_cfg`:
  - in-process wrapper that executes pipeline scripts in a child `Rscript`.

### 2.2 QDESN model core and fit/forecast dispatch

Core Q-DESN object construction:
- `R/qdesn_vb.R::qdesn_fit_vb`
  - builds reservoir (`Win`, `W`, reducers), rolls states over `y`,
  - constructs reservoir design matrix `X`,
  - optionally fits readout via `exal_ldvb_fit`.

Inference method dispatch:
- `R/qdesn_mcmc.R::qdesn_fit(method = "vb" | "mcmc")`.
- MCMC path (`qdesn_fit_mcmc`) reuses `qdesn_fit_vb(..., fit_readout = FALSE)` for design/state, then calls `exal_mcmc_fit`.

Forecasting:
- `R/qdesn_vb.R::forecast_paths.qdesn_fit` for recursive path simulation per origin/horizon.
- `R/qdesn_vb.R::forecast_lattice.qdesn_fit` for multi-origin lattice + lead-weighted target-time mixtures.
- Optional C++ backend path through `forecast_paths_cpp` (`src/forecast_paths.cpp`, `R/RcppExports.R`).

### 2.3 Where priors are defined/selected

Prior object constructors:
- `R/priors_beta.R::beta_prior`, `beta_prior_ridge`, `beta_prior_rhs`.
- `R/qdesn_rhs_prior.R::qdesn_rhs_prior_obj` internals.

Configuration-to-prior resolution:
- `R/exal_inference_config.R`:
  - `resolve_exal_inference_config`
  - `resolve_exal_quantile_fit_spec`
  - `exal_make_beta_prior`

Where priors are wired into fit:
- `qdesn_fit_vb` constructs `beta_prior_obj` from `vb_args$beta_prior_type` or explicit object.
- `qdesn_fit_mcmc` constructs `beta_prior_obj` from `mcmc_args$beta_prior_type` or explicit object.
- `exal_ldvb_engine` enforces prior object contract and uses `expected_prec/update/elbo`.

## 3. Current QDESN Input Pipeline

### 3.1 Reservoir input (raw and decomposition modes)

In `qdesn_fit_vb`, reservoir input `u_t` is now mode-aware:
- `input_mode = "raw_y_lags"`:
  - maintain `lag_buf = [y_{t-1}, y_{t-2}, ..., y_{t-m}]`.
- `input_mode = "dlm_decomp_lags"`:
  - maintain component lag buffers from causal decomposition series:
    - `trend`, `seasonal`, `residual`,
  - flatten lag buffers in `runtime$input_components` order to the effective lag vector.
- `make_u_from_inputbuf(...)` constructs `u_t = [1, processed_lags]` with shared preprocessing hooks:
  - `standardize_inputs`,
  - `input_bound` (`none` or `tanh`),
  - `win_scale_global`, `win_scale_bias`, `win_scale_lags`.

Covariates remain readout-side features; reservoir input mode affects the lag source feeding layer-1 only.

### 3.2 Readout design augmentation (lags/covariates/reservoir-lags)

The pipelines construct augmented readout matrices outside `qdesn_fit_vb`.

Simulation mode (`scripts/pipeline_sim_main.R`):
- shared reservoir roll: `qdesn_fit_vb(..., fit_readout = FALSE)`.
- lag builders:
  - `build_lag_mat_vec` for `input_lags_y`;
  - `build_mat_lags` for reservoir lag block (`reservoir_lags`).
- readout assembled as `X_res (+ input block) (+ reservoir lag block)`.
- `readout_spec` stored in `fit_meta` for forecast recursion.

Real-data mode (`scripts/pipeline_real_main.R`):
- constructs explicit `lags_y` and `lags_x` from `cfg$lags`.
- builds `Ylags_all` and `Xlags_all`.
- readout block behavior:
  - if `readout.include_input = TRUE`: input block goes into readout via `input_lags_y/input_lags_x`.
  - else: readout uses `y_lags/x_lags` block.
- supports future exogenous handling through `xreg_all_full`, `xreg_all_lead1`, `xreg_all_tail`.

Model-selection v2 uses the same pattern via utilities:
- `R/model_selection_utils_v2.R::ms_build_readout_design_sim`
- `R/model_selection_utils_v2.R::ms_build_readout_design_real`

### 3.3 Input dimensionality and reservoir coupling

Reservoir input dimension:
- layer-1 `Win[[1]]` has input width `m_input + 1` where:
  - raw mode: `m_input = m`,
  - decomposition mode: `m_input = sum(decomposition.input_lags[active components])`.

Reservoir feature dimension used by readout:
- `p_res` tracked in `meta$p_res`.
- If `add_bias=TRUE`, readout includes bias in reservoir block.
- Additional readout columns can append lag/covariate/reservoir-lag blocks.

## 4. Decomposition-Informed Input Design (Implemented)

### 4.1 Conceptual model

Baseline upstream:
- observed `y` -> raw y-lag reservoir inputs -> reservoir states -> readout.

Implemented optional upstream:
- observed `y` -> causal DLM decomposition -> decomposition-lag reservoir inputs -> reservoir states -> readout.

### 4.2 Required DLM objects and causal summaries

Required decomposition outputs per time `t`:
- observation vector `F_t`,
- evolution matrix `G_t`,
- causal state estimate for time `t` (filtered state),
- trend contribution at `t`,
- seasonal contribution at `t`,
- residual contribution at `t`.

State-space form:
- `y_t = F_t' alpha_t + epsilon_t`
- `alpha_t = G_t alpha_{t-1} + omega_t`

Repository components relevant to this:
- model builders: `polytrendMod`, `seasMod`, `combineMods`, `dlmMod`;
- filtered/smoothed state outputs in exDQLM fits (`theta.out$fm/fC/sm/sC`) from `exdqlmLDVB`/`exdqlmISVB`;
- forecast-time state roll-forward example in `exdqlmForecast` using `fGG` and `fFF` from an origin state.
- existing reference filter/smoother implementation with unknown variance in `R/utils.R::dlm_df`;
- dedicated NDLM C++ backend in `src/kalman_ndlm.cpp` exposed through `R/RcppExports.R` (`dlm_ndlm_filter_smooth_cpp`, `dlm_ndlm_structured_forecast_cpp`).

Parameterization note required by this feature:
- trend degree should be user-facing as `trend_degree` with semantics:
  - `0`: level, `1`: linear, `2`: quadratic, ...
- when using existing `polytrendMod(order, ...)`, map:
  - `order = trend_degree + 1`
- seasonal controls should be user-facing as:
  - `period` and `harmonics` (vector), aligned with `seasMod(p, h, ...)`.

### 4.3 Input vector formation

Reservoir input mode:
- `input_mode = "raw_y_lags" | "dlm_decomp_lags"`.

For `dlm_decomp_lags`, define lagged features from:
- trend series `trend_t`,
- seasonal series `seasonal_t`,
- residual series `resid_t`.

Example input vector at time `t`:
- `u_t = [1, trend_{t-1:t-m_tr}, seasonal_{t-1:t-m_seas}, resid_{t-1:t-m_res}]`
with optional same preprocessing hooks (`standardize_inputs`, bounds, scales).

Compatibility with existing covariates:
- keep readout covariate handling unchanged (`x_lags/input_lags_x` in `readout_spec`);
- this feature primarily changes reservoir input construction, not readout covariate blocks.

## 5. Forecasting Design Under Decomposition-Informed Inputs

### 5.1 Current forecast behavior to preserve

`forecast_paths.qdesn_fit` currently performs recursive simulation:
- rebuilds one-step readout row each horizon using current reservoir state + lag blocks;
- samples `y_h` from exAL predictive equation;
- appends `y_h` to history for future lags;
- supports teacher forcing if `y_future_obs` provided.

`forecast_lattice.qdesn_fit`:
- loops over origins,
- prepares origin-specific histories/states/xreg slices,
- calls `forecast_paths.qdesn_fit`,
- mixes origin/lead draws into target-time mixtures.

### 5.2 Decomposition-aware recursion from origin T

At origin `T`, for horizon `k = 1..H`:
- initialize with causal DLM state at `T` (filtered, not smoothed-forward).
- roll state forward via known `G_{T+1}, ..., G_{T+k}`.
- compute structured component at each step from forecasted state and `F_{T+k}`.
- generate residual inputs recursively:
  - for `k=1`, last observed residual at `T` is available;
  - for `k>1`, residual needed in lag buffer comes from prior forecast output:
    - `resid_{T+k} = yhat_{T+k} - structured_{T+k}`.

### 5.3 Deterministic vs simulation recursion

Current repo default is simulation-based path forecasting (draw-level recursion).

For decomposition mode:
- deterministic plug-in recursion can use `mu_h` as `yhat_h`;
- simulation path recursion should use each sampled `y_h` per draw path.

Recommendation:
- keep simulation-first behavior to match current posterior predictive design;
- optionally expose deterministic mode later as diagnostic only.

## 6. Leakage / Validity Considerations

Leakage to avoid:
- using smoothed future-aware states (`sm`, `sC`) as if available at real-time prediction.
- constructing forecast-time decomposition features using data beyond origin `T`.

Allowed:
- filtered/causal state at or before origin (`fm`, `fC` at `t<=T`).
- model-based state roll-forward from origin using `G/F` and previously generated forecasts.

Design rule:
- training-time decomposition features used for prediction rows must be causal for each row time.
- forecast-time decomposition features beyond `T` must depend only on information available at `T` plus recursively generated path quantities.

## 7. Integration Points in This Repo

### 7.1 Implemented extension strategy

Primary hook points:
- `R/qdesn_vb.R::qdesn_fit_vb`
  - mode-aware lag-builder path using raw or decomposition component buffers.
- `R/qdesn_vb.R::forecast_paths.qdesn_fit`
  - decomposition-aware recursive `make_u` plus sampled/deterministic residual recursion options.
- `R/qdesn_vb.R::forecast_lattice.qdesn_fit`
  - passes `origin_index` and reinitializes decomposition buffers causally per origin.

Metadata/readout spec plumbing:
- extend `meta` and `readout_spec` to carry input mode and decomposition settings.
- preserve existing fields and defaults to keep backward compatibility.

Pipeline assembly:
- `scripts/pipeline_sim_main.R`, `scripts/pipeline_real_main.R`
  - parse decomposition config and inject input-mode/decomposition settings into fit/forecast metadata.

Model-selection support:
- `R/model_selection_utils_v2.R` and `R/qdesn_model_selection_v2.R`
  - keep candidate evaluation path aligned with new input mode.

Current C++ scope decision:
- `src/forecast_paths.cpp` / `forecast_paths_cpp` remains raw-mode focused.
- decomposition forecasting path is routed through R recursion for compatibility; NDLM C++ is used for decomposition state/filter/smoother and structured trajectory roll-forward.

### 7.2 Files extended in this branch

- `R/qdesn_vb.R`
- `scripts/pipeline_sim_main.R`
- `scripts/pipeline_real_main.R`
- `R/model_selection_utils_v2.R`
- `R/qdesn_model_selection_v2.R`
- `config/defaults.yaml`
- tests in `tests/testthat` for forecast/input/config compatibility
- `R/qdesn_dlm_decomposition.R`
- `src/kalman_ndlm.cpp`
- `R/RcppExports.R`, `src/RcppExports.cpp`
- tests in `tests/testthat` for Phase 2/3 integration and backend parity

### 7.3 C++ NDLM/Kalman integration points (new explicit track)

Reference implementations already present:
- `R/utils.R::dlm_df` (R filter + smoother with unknown variance evolution),
- `src/kalman.cpp` (existing C++ Kalman-related routines used in exdqlm internals),
- `R/RcppExports.R`/`src/RcppExports.cpp` for export plumbing.

Scope correction (explicit):
- `src/kalman.cpp` is not currently equivalent to `R/utils.R::dlm_df`.
- For this feature, C++ implementation must target full `dlm_df` parity for the NDLM path, not partial reuse.
- Required parity includes:
  - forward filter moments (`a_t, R_t, f_t, Q_t, m_t, C_t`),
  - backward smoother moments,
  - iterative unknown-variance updates (`l_t, S_t`),
  - post-update covariance scaling/correction by variance sequence exactly as in `dlm_df`.

Implemented integration strategy:
- dedicated NDLM-focused C++ routines were added for:
  - forward filter recursions (state + variance updates),
  - backward smoother recursions,
  - structured-component k-step roll-forward used by decomposition recursion.
- these C++ routines are called from R decomposition helpers used by both:
  - `qdesn_fit_vb` training-time decomposition feature construction,
  - `forecast_paths.qdesn_fit` forecast-time decomposition roll-forward.

Implementation policy:
- keep an R reference path (from `dlm_df`-equivalent equations) available during rollout for parity tests and debugging.
- do not treat current C++ Kalman code as plug-and-play for this feature; adapt with equation-level signoff for NDLM with constant unknown variance.

## 8. YAML / Pipeline / Config Changes

### 8.1 Implemented config surface (consistent style)

The decomposition block is now exposed with explicit controls requested for this feature:

```yaml
readout:
  input_mode: raw_y_lags   # raw_y_lags | dlm_decomp_lags

decomposition:
  enabled: false
  backend: r               # r | cpp (cpp uses NDLM C++ filter/smoother)
  state_estimate: filtered # filtered | smoothed (smoothed for diagnostics only)
  components: [trend, seasonal, residual]

  trend:
    degree: 1              # 0=level, 1=linear, 2=quadratic, ...

  seasonal:
    period: 365
    harmonics: [1, 2, 4]
    auto:
      enabled: false
      top_k: 3
      min_harmonic: 1
      max_harmonic: null
      use_log_score: true
      center: true
      prefer_manual: true

  input_lags:
    trend: 30
    seasonal: 30
    residual: 30

  discount:
    trend: 0.99
    seasonal: 0.99

  variance:
    mode: unknown_constant # current target for NDLM filter/smoother
    l0: 1
    S0: 1

  forecast:
    residual_recursion: sampled_path # sampled_path | deterministic_plugin
```

Compatibility/mapping notes:
- `trend.degree` maps to polynomial order via `order = degree + 1` if reusing `polytrendMod`.
- `seasonal.period` + `seasonal.harmonics` map directly to `seasMod`.
- `seasonal.auto` computes harmonic scores on candidate frequencies `h / period` using cosine/sine projections and selects top-k harmonics.
- if `seasonal.auto.enabled=true` and `seasonal.harmonics` is empty (or `prefer_manual=false`), selected harmonics are injected as effective harmonics.
- `backend = cpp` should require parity-tested NDLM kernel; otherwise fail fast or fallback explicitly with warning.

### 8.2 Pipeline pass-through points (implemented)

- `scripts/pipeline_run.R`: config merge handles decomposition keys transparently.
- `pipeline_sim_main.R` / `pipeline_real_main.R`: parse and pass normalized decomposition config into `qdesn_fit_vb`.
- `readout_spec` in `fit_meta` carries decomposition fields needed for recursive forecast reconstruction.
- model-selection builders pass decomposition keys through to design/fitting helpers.

## 9. Implementation Phases

### Phase 0: Equation signoff (derivation-first gate)

Goal:
- lock exact NDLM filter/smoother equations and variance updates before implementation.

Deliverables:
- written derivation note for:
  - filter recursions,
  - smoother recursions,
  - unknown constant variance update equations,
  - one-step/k-step forecast moment recursions used by decomposition inputs.
- explicit symbol mapping to code variables (R + C++).
- signoff checklist item: no coding shortcuts, no ad-hoc approximations without written justification.

### Phase 1: YAML + wiring scaffold

Goal:
- Add config parsing/validation and metadata fields for input mode/decomposition without changing default behavior.

Deliverables:
- config keys in defaults/spec validation paths;
- `meta`/`readout_spec` shape extension;
- backward-compatible no-op when `input_mode = raw_y_lags`.

Status:
- Completed in this branch.
- Phase 1 scaffold has now been superseded by Phase 2 behavior (decomposition mode is active when requested/enabled).
- Raw mode remains backward compatible (`raw_y_lags` unchanged).

### Phase 2: R reference decomposition engine

Goal:
- implement a clear R reference path for decomposition features and forecast-time recursion.

Deliverables:
- helper using trend/seasonal settings (`degree`, `period`, `harmonics`);
- causal filtered outputs for training rows;
- smoothed outputs allowed only for diagnostics, not predictive features.

Status:
- Completed in this branch.
- Implemented in `R/qdesn_dlm_decomposition.R` and integrated into:
  - `qdesn_fit_vb`,
  - `forecast_paths.qdesn_fit`,
  - `forecast_lattice.qdesn_fit`,
  - sim/real/model-selection shared-design builders.

### Phase 3: C++ NDLM filter/smoother implementation

Goal:
- implement fast NDLM filtering/smoothing (unknown constant variance) in C++ with R parity harness.

Deliverables:
- new C++ exported NDLM routine(s) and R wrappers;
- deterministic parity tests vs R reference on fixed seeds/scenarios;
- full parity checks against `dlm_df` moments and variance recursion outputs (`fm/fC`, smoothed moments, `s`, `n` equivalents);
- numerical stability checks (SPD handling, conditioning, finite outputs).

Status:
- Completed in this branch.
- Implemented in `src/kalman_ndlm.cpp` and exposed via `R/RcppExports.R`/`src/RcppExports.cpp`.
- Wrapped by `qdesn_ndlm_filter_smooth()` and `qdesn_ndlm_structured_forecast()` in `R/qdesn_dlm_decomposition.R`.
- Validated by `tests/testthat/test-qdesn-dlm-phase3-ndlm-backend.R`.

Phase 3 lock (exact interface/data contract):

1. C++ filter/smoother kernel signature (new file target: `src/kalman_ndlm.cpp`)

```cpp
// [[Rcpp::export]]
Rcpp::List dlm_ndlm_filter_smooth_cpp(
    const arma::vec& y,           // length T
    const arma::mat& FF,          // n_state x T
    const arma::cube& GG,         // n_state x n_state x T (expanded in R if static)
    const arma::vec& m0,          // n_state
    const arma::mat& C0,          // n_state x n_state
    const arma::vec& df,          // n_blocks
    const arma::ivec& dim_df,     // n_blocks; sum(dim_df)==n_state
    const double l0,              // >0
    const double S0,              // >0
    const bool compute_smoothed = true,
    const bool return_intermediates = true,
    const double jitter = 1e-10
);
```

2. C++ structured roll-forward signature (for forecast-time decomposition trajectory)

```cpp
// [[Rcpp::export]]
Rcpp::List dlm_ndlm_structured_forecast_cpp(
    const arma::cube& GG,         // n_state x n_state x T (or expanded static)
    const arma::mat& FF,          // n_state x T
    const arma::vec& state_origin,// n_state (filtered state at origin)
    const arma::ivec& idx_trend,  // 0-based state indices in C++
    const arma::ivec& idx_seasonal,
    const int origin_index,       // 1-based R index passed through; converted in C++
    const int H                   // horizons ahead
);
```

3. Required return schema for `dlm_ndlm_filter_smooth_cpp` (names/shapes locked)

- `fm`: `T x n_state` filtered means.
- `fC`: `T x n_state x n_state` scaled filtered covariances.
- `sm`: `T x n_state` smoothed means (`NULL` if `compute_smoothed=FALSE`).
- `sC`: `T x n_state x n_state` scaled smoothed covariances (optional in Phase 2, required for parity/testing in Phase 3).
- `a`: `T x n_state` prior means.
- `R_unscaled`: `T x n_state x n_state` prior unscaled covariances.
- `C_unscaled`: `T x n_state x n_state` posterior unscaled filtered covariances.
- `Q_unscaled`: length `T` unscaled one-step variances.
- `f`: length `T` one-step means.
- `e`: length `T` one-step errors.
- `K`: `T x n_state` Kalman gains.
- `s`: length `T` variance scale sequence.
- `n`: length `T` variance dof sequence.

4. Required return schema for `dlm_ndlm_structured_forecast_cpp`

- `trend`: length `H`.
- `seasonal`: length `H`.
- `structured`: length `H` (`trend + seasonal`).
- `state_last`: length `n_state` (rolled state at `T+H`).

5. R wrapper signatures (locked from day one)

```r
qdesn_ndlm_filter_smooth <- function(
  y, FF, GG, m0, C0, df, dim_df, l0, S0,
  backend = c("r", "cpp"),
  compute_smoothed = TRUE,
  return_intermediates = TRUE,
  jitter = 1e-10
) { ... }

qdesn_ndlm_structured_forecast <- function(
  GG, FF, state_origin, idx_trend, idx_seasonal, origin_index, H,
  backend = c("r", "cpp")
) { ... }
```

6. Backend dispatch rules

- `decomposition.backend == "r"`: call existing `.qdesn_ndlm_filter_smooth_r` + `.qdesn_decomp_forecast_trajectory`.
- `decomposition.backend == "cpp"`:
  - call C++ kernels directly,
  - fallback to R only on hard failure (with warning + runtime `backend_effective` set to the actual backend used).

7. Data-orientation lock

- Time-major in R outputs (`T` as first dimension in matrices/cubes returned to R).
- Internally C++ may use state-major for speed, but wrappers must convert to the exact schemas above.
- `origin_index` is always 1-based at R boundary; C++ converts once at entry.

### Phase 4: QDESN reservoir-input integration

Goal:
- feed decomposition-informed lag features into `qdesn_fit_vb` and forecast recursion.

Deliverables:
- training-time input mode switch in `qdesn_fit_vb`;
- forecast-time decomposition recursion in `forecast_paths.qdesn_fit`;
- origin-level decomposition state plumbing in `forecast_lattice.qdesn_fit`.

Status:
- Completed in this branch.
- `qdesn_fit_vb` now uses decomposition lag buffers when `input_mode=dlm_decomp_lags`.
- `forecast_paths.qdesn_fit` and `forecast_lattice.qdesn_fit` now initialize and update decomposition buffers causally per origin/path.

### Phase 5: Pipeline/model-selection integration

Goal:
- expose mode in sim/real/model-selection/benchmark runners.

Deliverables:
- pipeline usage path with artifacts unchanged in schema where possible;
- model-selection compatibility for candidate evaluation.

Status:
- Completed in this branch.
- sim/real pipeline scripts and model-selection utilities pass decomposition options into shared fit/design paths.

### Phase 6: Validation and parity hardening

Goal:
- Confirm correctness, forecast validity, and backward compatibility.

Deliverables:
- tests, diagnostics, and mandatory R/C++ parity signoff for NDLM backend before defaulting to C++.

Status:
- Completed for current scope.
- Phase-2/3 integration tests, NDLM parity tests, and baseline smoke/inference suites pass.
- Additional decomposition-enabled sim/real smoke runs and raw-baseline sim/real runs were executed successfully on 2026-03-17.

## 10. Risks / Open Questions / Decisions Needed

Resolved in this implementation:

1. Causal decomposition availability:
- Implemented via `R/qdesn_dlm_decomposition.R` runtime helpers used in fit and forecast paths for both sim and real pipelines.

2. State-estimate validity:
- Predictive path enforces forecast-causal behavior:
  - `state_estimate="smoothed"` is downgraded to filtered for predictive features with warning.

3. Forecast recursion policy:
- Both `sampled_path` and `deterministic_plugin` residual recursion modes are supported in decomposition forecasting.

4. C++ NDLM backend readiness:
- NDLM filter/smoother and structured roll-forward implemented in `src/kalman_ndlm.cpp` with R wrappers and backend fallback behavior.

5. `src/kalman.cpp` non-equivalence:
- Explicitly handled by implementing dedicated NDLM kernels instead of reusing non-equivalent routines.

6. Training-time leakage control:
- Decomposition feature extraction for predictive rows is causal/filtered; no future-smoothed leakage in forecast recursion.

7. Config semantics for harmonic/period/trend controls:
- YAML keys for `trend.degree`, `seasonal.period`, `seasonal.harmonics`, and `seasonal.auto.*` are wired and exercised in tests/smokes.

Still-open follow-up decisions (non-blocking):

8. Fallback strictness:
- Current behavior falls back to R when C++ backend errors.
- Optional hard-fail mode can be added later for stricter production contracts.

9. Extended stress coverage:
- Core parity and smoke suites pass; additional heavy stress fixtures (very long seasonal periods/high-order trend/short noisy series) are still recommended for broader robustness hardening.

## 11. Suggested Validation Strategy

1. Unit tests: input construction
- Verify raw mode outputs unchanged.
- Verify decomposition mode dimensions and column ordering.
- Verify lag windows and dropped rows (`drop = max(m, washout)`) remain consistent.

2. Unit tests: forecast recursion
- Check one-step and multi-step decomposition residual recursion logic.
- Assert no access to future observations when `y_future_obs` is `NA`.

3. Integration tests: pipeline smoke
- Sim and real smoke runs with `readout.input_mode = raw_y_lags` (baseline) and `dlm_decomp_lags`.
- Confirm outputs still include expected artifacts (for example `models/forecast_objects.rds`, timing tables).

4. Leakage tests
- Construct controlled examples where smoothed-vs-filtered use would differ and assert configured causal path.

5. Backward compatibility tests
- Ensure prior existing specs/configs (without decomposition keys) produce identical results to current branch behavior.

6. Priors/inference invariance checks
- Validate ridge/RHS readout fits receive expected design shapes and no changes in prior API contract.

7. Forecast sanity checks
- For fixed seeds, compare decomposition mode vs raw mode path stability and dimension checks across R/C++ backend selection.

8. R vs C++ NDLM parity tests (new mandatory block)
- Fixed synthetic cases with known trend/seasonal settings:
  - compare filtered means/covariances, smoothed means/covariances, forecast moments.
- compare iterative variance-state outputs (`S_t`, `l_t` or exact mapped equivalents) and final covariance rescaling behavior.
- Tolerance-based equality checks over full time axis.
- Stress tests for:
  - high harmonics,
  - long periods,
  - higher polynomial degrees,
  - short series edge cases.

9. Derivation-to-code traceability checks
- For each derived equation, include test assertions mapping symbols to implementation variables.
- Fail tests when algebraic identities do not hold numerically in controlled fixtures.

10. End-to-end pipeline validation (sim + real)
- Sim pipeline:
  - decomposition off vs on; ensure artifacts and scoring tables remain consistent.
- Real pipeline:
  - decomposition off vs on with exogenous covariates and lag blocks enabled.
- Confirm model-selection and benchmark paths either support decomposition mode or fail explicitly with actionable errors.

### 11.1 Executed validation evidence (2026-03-17)

- Tests executed and passing:
  - `tests/testthat/test-qdesn-dlm-phase3-ndlm-backend.R`
  - `tests/testthat/test-qdesn-dlm-phase2-integration.R`
    - includes auto-harmonic tests for dominant-frequency recovery and manual-preference override.
  - `tests/testthat/test-smoke.R`
  - `tests/testthat/test-pipeline-inference-validation.R`
  - `tests/testthat/test-benchmark-pipeline.R`
- Pipeline dry-runs executed and passing:
  - sim: `pipeline_run.R --slug dlm_constV_smallW_local_sim --spec /tmp/qdesn_dlm_sim_smoke.yaml --dry-run`
  - real: `pipeline_run.R --slug dlm_constV_smallW_local_real --spec /tmp/qdesn_dlm_real_smoke.yaml --dry-run`
  - sim (auto harmonics): `pipeline_run.R --slug dlm_constV_smallW_local_sim --spec /tmp/qdesn_dlm_auto_harm_sim.yaml --dry-run`
  - real (auto harmonics): `pipeline_run.R --slug dlm_constV_smallW_local_real --spec /tmp/qdesn_dlm_auto_harm_real.yaml --dry-run`
- Pipeline smoke runs executed and passing:
  - decomposition-enabled sim/real runs with `decomposition.backend=cpp`,
  - sim (auto harmonics): `pipeline_run.R --slug dlm_constV_smallW_local_sim --spec /tmp/qdesn_dlm_auto_harm_sim.yaml`,
  - real (auto harmonics): `pipeline_run.R --slug dlm_constV_smallW_local_real --spec /tmp/qdesn_dlm_auto_harm_real.yaml`,
  - decomposition-enabled sim/real runs with `decomposition.seasonal.auto.enabled=true` and fixed `seasonal.period`,
  - raw-baseline sim/real runs with existing smoke specs (`mcmc_smoke_*_vb_ridge.yaml`).

## 12. Confirmed Existing vs Implemented Work

### 12.1 Confirmed already available in repo

- DLM component builders for requested controls:
  - trend block: `R/polytrendMod.R`
  - seasonal harmonics/period: `R/seasMod.R`
  - block composition: `R/combineMods.R`, `R/dlmMod.R`
- R filter/smoother baseline with unknown variance:
  - `R/utils.R::dlm_df`
- Existing C++ Kalman infrastructure (non-equivalent for this NDLM path):
  - `src/kalman.cpp` (+ exports in `R/RcppExports.R`)
- QDESN integration points:
  - `R/qdesn_vb.R` fit and recursive forecast functions
  - pipeline config plumbing in `scripts/pipeline_*`.

### 12.2 Implemented in this branch

- YAML/config surface for:
  - `trend.degree`, `seasonal.period`, `seasonal.harmonics`,
  - `seasonal.auto` top-k spectral harmonic selection controls,
  - decomposition backend/state/variance/forecast recursion controls.
- automatic harmonic selection implementation:
  - `R/qdesn_dlm_decomposition.R::.qdesn_select_harmonics_spectral`,
  - model runtime metadata fields (`harmonics_requested`, `harmonics_effective`, `harmonics_source`, `auto_selection`).
- dedicated NDLM C++ path:
  - `src/kalman_ndlm.cpp` with `dlm_ndlm_filter_smooth_cpp` and `dlm_ndlm_structured_forecast_cpp`.
- decomposition-aware reservoir input/forecast recursion:
  - integrated in `qdesn_fit_vb`, `forecast_paths.qdesn_fit`, and `forecast_lattice.qdesn_fit`.
- R/C++ parity and integration coverage:
  - Phase 2/3 tests plus sim/real smoke runs (decomposition on/off).

### 12.3 Where user collaboration may still be useful

- Optional signoff on any future extension beyond the current trend+seasonal+residual NDLM blocks.
- Optional derivation review if adding new structural blocks or changing variance assumptions beyond unknown-constant variance.
- Optional decision on hard-fail policy for `backend=cpp` (instead of fallback) in production runs.

## 13. Appendix: Relevant File / Function Map

### Core QDESN fit/forecast

- `R/qdesn_vb.R`
  - `qdesn_fit_vb`
  - `forecast_paths.qdesn_fit`
  - `forecast_lattice.qdesn_fit`
- `R/qdesn_mcmc.R`
  - `qdesn_fit`
  - `qdesn_fit_mcmc`
- `R/qdesn_design_only.R`
  - `qdesn_build_design`

### Priors and inference

- `R/priors_beta.R`
- `R/qdesn_rhs_prior.R`
- `R/exal_ldvb_engine.R`
- `R/exal_ldvb_fit.R`
- `R/exal_mcmc_fit.R`
- `R/exal_inference_config.R`

### Pipeline and config

- `scripts/pipeline_run.R`
- `scripts/pipeline_main.R`
- `scripts/pipeline_sim_main.R`
- `scripts/pipeline_real_main.R`
- `R/run_esn_pipeline.R`
- `config/defaults.yaml`

### Model-selection and benchmark paths

- `R/qdesn_model_selection_v2.R`
- `R/model_selection_utils_v2.R`
- `scripts/qdesn_model_selection_main.R`
- `R/benchmark_qdesn_runner.R`
- `scripts/benchmark_qdesn_run.R`

### State-space / decomposition-relevant existing components

- `R/polytrendMod.R`
- `R/seasMod.R`
- `R/combineMods.R`
- `R/dlmMod.R`
- `R/exdqlmLDVB.R`
- `R/exdqlmISVB.R`
- `R/exdqlmForecast.R`
- `R/utils.R` (`dlm_df`)

### C++ backends / exports

- `src/forecast_paths.cpp` (raw-mode forecast sampler backend)
- `src/kalman.cpp` (existing Kalman utilities, non-equivalent for NDLM decomposition parity target)
- `src/kalman_ndlm.cpp` (NDLM filter/smoother + structured-trajectory backend for decomposition mode)
- `R/RcppExports.R`
- `src/RcppExports.cpp`
