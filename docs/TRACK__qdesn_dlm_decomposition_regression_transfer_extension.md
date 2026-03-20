# TRACK: Q-DESN DLM Decomposition Extension (Regression + Transfer Function)

Date: 2026-03-20  
Branch: `feature/qdesn-mcmc-alternative`  
Status: Implemented in code on this branch; this document remains the design/validation tracker.

## 0. Implementation Status (2026-03-20 Update)

This tracker was later used as the implementation target, and the following are now implemented on this branch:

- Decomposition config/schema extended with optional `regression` and `transfer` blocks.
- Decomposition model assembly now supports:
  - trend + seasonal + regression + transfer state blocks,
  - block-discount wiring including `regression`, `transfer_zeta`, `transfer_psi`.
- Q-DESN decomposition runtime now supports component set:
  - `trend`, `seasonal`, `regression`, `transfer`, `residual`.
- Reservoir input lag construction and forecast recursion now work generically for the extended component set.
- C++ posterior-predictive recursion (`forecast_paths_cpp`) now supports decomposition component codes:
  - `trend=1`, `seasonal=2`, `regression=3`, `transfer=4`, `residual=5`.
- Real/model-selection wiring now passes decomposition covariates (`decomposition_xreg`) into `qdesn_fit_vb`.
- Targeted tests added and passing for regression/transfer decomposition integration and R-vs-C++ parity.

What remains intentionally outside this update:
- Real-data production runs and transfer-function family extensions beyond the current NDLM block.

## 1. Scope and Guardrail

This tracker defines the design and implementation plan to extend Q-DESN decomposition-informed inputs from:
- `trend + seasonal + residual`

to:
- `trend + seasonal + regression + transfer + residual`.

Hard guardrail for this tracker:
- Do **not** run the San Lorenzo real-data production pipeline with this new extension until implementation and validation gates below pass.

## 2. What Was Verified in Code (Current State)

### 2.1 Current decomposition capability in this repo

- Decomposition model builder currently constructs only trend + seasonal blocks in `.qdesn_build_dlm_model_from_cfg(...)`.
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:490)
- Decomposition component extraction currently returns only:
  - `trend`, `seasonal`, `structured = trend + seasonal`, `residual`.
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:599)
- Component registry in normalized config currently allows only:
  - `trend`, `seasonal`, `residual`.
  - [R/qdesn_vb.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_vb.R:73)

### 2.2 Current NDLM core already supports time-varying F_t/G_t

- State-space expansion supports:
  - constant `FF/GG` (recycled), and
  - time-varying `FF(:,t)` / `GG(:,:,t)`.
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:37)
- R NDLM filter-smoother uses `F_t`, `G_t` per-time in recursion.
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:210)
- C++ NDLM filter-smoother also uses `FF.col(t)` and `GG.slice(t)`.
  - [src/kalman_ndlm.cpp](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/src/kalman_ndlm.cpp:168)

Conclusion:
- The NDLM engine itself is already general enough for regression/transfer blocks, as long as we build the augmented model (`FF`, `GG`, `m0`, `C0`, discount blocks, index map) correctly.

### 2.3 Discount-factor construction is already in the expected form

- Block discount matrix is built as:
  - diagonal block multiplier `(1 - d_j)/d_j`, then `W_t = D_df ⊙ P_t`, `R_t = P_t + W_t`.
  - [R/utils.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/utils.R:134)
  - [src/kalman_ndlm.cpp](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/src/kalman_ndlm.cpp:43)

This matches the intended component discounting structure.

## 3. External Reference Check Completed

## 3.1 Environmetrics paper repo

Repository checked and pulled:
- `/home/jaguir26/local/src/Environmetrics_paper_repo`
- remote matches requested URL:
  - `https://github.com/AntonioAPDL/Evironmetrics---BAYESIAN-QUANTILE-BASED-CORRECTION-AND-SYNTHESIS-OF-RIVER-FLOW-FORECASTS`

Transfer-function specification in `wileyNJD-APA.tex`:
- base model with transfer states:
  - [wileyNJD-APA.tex](/home/jaguir26/local/src/Environmetrics_paper_repo/wileyNJD-APA.tex:92)
- compact state form:
  - [wileyNJD-APA.tex](/home/jaguir26/local/src/Environmetrics_paper_repo/wileyNJD-APA.tex:103)
- exact block definitions:
  - `F_t^trans = [1; 0_m]`
  - `G_t^trans = [[lambda, x_t']; [0_m, I_m]]`
  - [wileyNJD-APA.tex](/home/jaguir26/local/src/Environmetrics_paper_repo/wileyNJD-APA.tex:111)
- trend/seasonal decomposition matrix style:
  - [wileyNJD-APA.tex](/home/jaguir26/local/src/Environmetrics_paper_repo/wileyNJD-APA.tex:314)

## 3.2 exdqlm `origin/cransub/0.4.0`

Checked implementation patterns on requested branch:
- regression block helper:
  - [regMod.R@origin/cransub/0.4.0](/home/jaguir26/local/src/exdqlm/R/regMod.R:3)
- transfer augmentation wrappers:
  - `transfn_exdqlmLDVB`:
    - [transfn_exdqlmLDVB.R@origin/cransub/0.4.0](/home/jaguir26/local/src/exdqlm/R/transfn_exdqlmLDVB.R:86)
  - `transfn_exdqlmISVB`:
    - [transfn_exdqlmISVB.R@origin/cransub/0.4.0](/home/jaguir26/local/src/exdqlm/R/transfn_exdqlmISVB.R:118)

Observed augmentation pattern (consistent with paper):
- append two transfer states (`zeta_t`, one beta state in those wrappers),
- inject transfer block in `GG`,
- inject transfer observation selector in `FF`,
- append discount blocks for transfer states.

## 4. Theory Confirmation (Your Two Proposed Paths)

Your two proposed extensions are correct and complementary:

1. Regression via observation vector / identity evolution block:
- Add regression state `beta_t`.
- Use `F_t` augmented with `x_t` entries for that block.
- Use `G_beta = I` (static) or near-static/random-walk variant via discount/evolution variance.

2. Transfer function via dedicated dynamic block:
- Add transfer accumulator and transfer coefficients in state.
- Use block:
  - `F_t^trans = [1; 0]` (or generalized selector),
  - `G_t^trans = [[lambda_t, x_t']; [0, I]]`.

This is exactly aligned with your paper notation and exdqlm implementation style.

## 5. Proposed QDESN Extension Design

## 5.1 Extended decomposition state model

Define augmented state:
- `alpha_t = [theta_trend_t; theta_season_t; beta_reg_t; zeta_tf_t; psi_tf_t]`
- with optional blocks enabled by config.

Observation equation for decomposition stage:
- `y_t = F_t' alpha_t + eps_t`
- where `F_t' alpha_t` decomposes into:
  - trend contribution,
  - seasonal contribution,
  - regression contribution,
  - transfer contribution.

Residual contribution:
- `residual_t = y_t - structured_t`
- `structured_t = trend_t + seasonal_t + regression_t + transfer_t`.

## 5.2 Where to hook in current code

Primary integration points:
- decomposition config normalization:
  - [R/qdesn_vb.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_vb.R:42)
- decomposition model construction and runtime:
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:490)
- series extraction and per-component lags:
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:599)
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:736)
- forecast-time decomposition trajectory and recursion:
  - [R/qdesn_dlm_decomposition.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_dlm_decomposition.R:776)
  - [R/qdesn_vb.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_vb.R:1081)
  - [R/qdesn_vb.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_vb.R:1563)

## 5.3 Forecast-validity rule (must stay strict)

- Training decomposition features may use `state_estimate = smoothed` for historical analysis.
- Predictive decomposition features (forecast beyond origin) must be origin-causal:
  - start from filtered state at origin,
  - roll forward with `G_{T+1:T+H}` and forecast-known inputs,
  - compute residual inputs recursively from generated/predicted `y`.

This keeps leakage control consistent with current guardrail behavior in input-mode resolver:
- [R/qdesn_vb.R](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/R/qdesn_vb.R:225)

## 6. YAML/Config Proposal (Extension)

Proposed additive schema under `decomposition`:

```yaml
decomposition:
  enabled: true
  backend: cpp
  state_estimate: smoothed
  components: [trend, seasonal, regression, transfer, residual]

  trend:
    degree: 0

  seasonal:
    period: 363.5854
    harmonics: [1.0, 2.0, 0.1469108476]
    auto:
      enabled: false

  regression:
    enabled: false
    x_cols: []                  # covariates entering F_t as direct regressors
    dynamic: false              # false => G=I + static-style discount; true => random-walk-style flexibility

  transfer:
    enabled: false
    x_cols: []                  # covariates entering G_t transfer row
    lambda: 0.90                # scalar or (future phase) time-varying vector

  input_lags_mode: component
  input_lags:
    trend: 30
    seasonal: 30
    regression: 30
    transfer: 30
    residual: 30

  discount:
    trend: 1.0
    seasonal: 0.9997
    regression: 1.0
    transfer_zeta: 0.99
    transfer_psi: 1.0
```

Notes:
- Keep existing fields backward-compatible.
- New blocks are opt-in (`enabled: false` by default).
- `components` order controls lag concatenation order into reservoir inputs.

## 7. C++/R Interface Lock Plan

## 7.1 NDLM filter-smoother kernel

No signature change required for:
- `dlm_ndlm_filter_smooth_cpp(y, FF, GG, m0, C0, df, dim_df, l0, S0, ...)`

Reason:
- it already handles generic time-varying `FF/GG`; block extension is in model assembly.

## 7.2 Structured forecast helper

Current helper is trend/seasonal-specific:
- [src/kalman_ndlm.cpp](/home/jaguir26/local/src/exdqlm__wt__feature-benchmark-data-pipeline/src/kalman_ndlm.cpp:277)

Planned change:
- introduce generic component forecast helper (R + C++) returning all requested component trajectories, not only trend/seasonal.
- maintain existing API as compatibility wrapper until migration is complete.

## 7.3 `forecast_paths_cpp` decomposition arguments

Current C++ path accepts only trend/seasonal trajectories + residual recursion mode.
Planned generalization:
- pass `decomp_component_codes` and per-component trajectories/buffers generically.
- preserve current behavior for existing component set.

## 8. Implementation Phases and Gates

Phase E0: Spec lock (this tracker)
- Deliverables:
  - finalized equations and component mapping,
  - YAML/API lock,
  - validation gate checklist.
- Exit criteria:
  - signoff on regression and transfer block equations and forecast assumptions.

Phase E1: R-only model assembly extension
- Add config normalization for `regression` and `transfer`.
- Build augmented model (`FF/GG/m0/C0/df/dim_df`) using existing helpers/patterns.
- Extend component index map and extracted decomposition series.
- Keep forecast path initially on R fallback if needed.

Phase E2: R decomposition forecast recursion extension
- Extend component trajectory computation to include regression/transfer.
- Extend residual recursion to use full structured component.
- Enforce causality checks for future covariates when regression/transfer enabled.

Phase E3: C++ parity and generic component forecast
- Add C++ generic component trajectory helper.
- Extend `forecast_paths_cpp` decomp interface for generic components.
- Add strict parity tests (R vs C++).

Phase E4: Pipeline integration and defaults/spec updates
- Wire new options through sim/real pipelines.
- Add spec examples for:
  - trend+seasonal only,
  - +regression,
  - +transfer.

Phase E5: Validation gate (must pass before San Lorenzo run)
- Unit tests pass.
- R/C++ parity tests pass.
- End-to-end sim decomposition tests pass.
- Backward compatibility: current trend+seasonal mode unchanged.

## 9. Test Plan (Required Before Real-Data Run)

Unit tests:
- config normalization for new fields/defaults/error conditions,
- block-dimension checks (`sum(dim_df) == n_state`),
- component extraction correctness for each enabled block.

Numerical parity:
- R vs C++ filter/smoother parity with synthetic time-varying `FF/GG`,
- R vs C++ component forecast trajectory parity.

Forecast recursion tests:
- deterministic plugin vs sampled-path residual recursion,
- transfer/ regression enabled with known future covariates,
- strict failure on missing future covariates when required.

Regression/backward-compatibility:
- all existing decomposition tests (phase2/phase3) remain passing,
- raw lag mode outputs unchanged within tolerance.

Performance smoke:
- decomposition sim pipeline with new blocks enabled on moderate `T`,
- verify no pathological slowdown vs current decomposition path.

## 10. Open Decisions Needed Before Implementation

1. Transfer-rate parameterization:
- v1: scalar `lambda` only.
- later: time-varying `lambda_t`.

2. Regression state dynamics:
- static coefficients (`discount=1`) default vs mild dynamics.

3. Transfer block dimensionality:
- support multivariate `x_t` immediately (recommended),
- keep univariate special-case wrapper for convenience.

4. Component-lag inclusion policy:
- whether `regression` and `transfer` lags are optional independent knobs (recommended yes).

5. Forecast-time covariate policy:
- require user-provided `xreg_future` for enabled regression/transfer blocks,
- no silent imputation.

## 11. Go/No-Go Checklist Before San Lorenzo Real Run

Must all be true:
- [ ] E1-E5 implemented and merged locally.
- [ ] testthat suite for new feature passes.
- [ ] decomposition parity tests pass (R vs C++).
- [ ] sim pipeline smoke for new blocks succeeds with full outputs.
- [ ] documented residual recursion and causality checks verified.

Only after this checklist is complete, proceed to San Lorenzo real-data pipeline run with the requested decomposition specification.
