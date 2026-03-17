# TRACK: Q-DESN DLM Phase 0 Derivations and Mapping (Signoff Draft)

Date: 2026-03-17
Branch: `feature/qdesn-mcmc-alternative`
Scope: complete Phase 0 derivation draft for NDLM decomposition engine parity with `R/utils.R::dlm_df` and implementation mapping for C++.

## 1. Objective and Signoff Target

This document locks the mathematical recursions and variable mapping for:
- filtering moments,
- smoothing moments,
- iterative unknown-variance updates (`l_t`, `S_t`),
- covariance scaling/correction logic,
- decomposition component extraction (trend/seasonal/residual),
- YAML parameter mapping (trend degree, seasonal period, harmonics).

Signoff target:
- these equations become the source of truth for C++ implementation,
- no ad-hoc approximations or undocumented deviations.

## 2. Model Definition (Univariate NDLM, Unknown Constant Variance)

Observation model:
- `y_t = F_t' theta_t + nu_t`, `nu_t | V ~ N(0, V)`.

State evolution:
- `theta_t = G_t theta_{t-1} + omega_t`, `omega_t | V ~ N(0, V W_t^*)`.

Unknown constant variance:
- `V` is scalar, constant in time, learned sequentially.

Posterior form at time `t-1`:
- `theta_{t-1} | V, D_{t-1} ~ N(m_{t-1}, V C_{t-1}^*)`,
- `V | D_{t-1} ~ IG(l_{t-1}/2, l_{t-1} S_{t-1}/2)`.

Notes:
- `D_{t-1}` is data up to time `t-1`.
- `C_t^*` and `R_t^*` are unscaled covariance factors (scaled by `V` in the hierarchical model).

## 3. Discount-Factor State Evolution as Implemented in `dlm_df`

`dlm_df` constructs a block matrix `D_df = make_df_mat(df, dim.df, n)` and applies:
- `P_t^* = G_t C_{t-1}^* G_t'`,
- `W_t^* = D_df ⊙ P_t^*` (Hadamard product),
- `R_t^* = P_t^* + W_t^*`.

This is the exact covariance inflation behavior to preserve.

## 4. Filter Recursions (Derived, Then Mapped)

### 4.1 Prior moments

- `a_t = G_t m_{t-1}`
- `R_t^* = G_t C_{t-1}^* G_t' + W_t^*`

### 4.2 One-step forecast moments

- `f_t = F_t' a_t`
- `Q_t^* = 1 + F_t' R_t^* F_t`
- `e_t = y_t - f_t`

(`1` corresponds to observation variance coefficient for the standardized model before multiplying by `V`.)

### 4.3 Posterior moments conditional on variance

- `A_t = R_t^* F_t / Q_t^*`
- `m_t = a_t + A_t e_t`
- `C_t^* = R_t^* - A_t Q_t^* A_t'`

### 4.4 Variance recursion (unknown constant variance)

- `l_t = l_{t-1} + 1`
- `S_t = (l_{t-1} S_{t-1} + e_t^2 / Q_t^*) / l_t`

Initialization:
- `l_0 = s.priors$l0`,
- `S_0 = s.priors$S0`.

These are the exact iterative scale and degrees-of-freedom updates that must be reproduced in C++.

## 5. Variance Scaling/Correction of Covariances (As in `dlm_df`)

After unscaled recursions are complete, `dlm_df` applies variance scaling:
- filtered predictive covariance:
  - `R_1 = S_0 R_1^*`,
  - `R_t = S_{t-1} R_t^*` for `t >= 2`,
- one-step forecast variance:
  - `Q_1 = S_0 Q_1^*`,
  - `Q_t = S_{t-1} Q_t^*` for `t >= 2`,
- filtered posterior state covariance:
  - `C_t = S_t C_t^*`.

Required implementation behavior:
- maintain unscaled recursions internally for stability and exact updates,
- expose scaled covariances in the output object compatible with `dlm_df`.

## 6. RTS Smoothing Recursions (Unscaled Core + Variance Correction)

Backward initialization:
- `m_{T|T} = m_T`,
- `C_{T|T}^* = C_T^*`.

For `t = T-1, ..., 1`:
- `B_t = C_t^* G_{t+1}' (R_{t+1}^*)^{-1}`
- `m_{t|T} = m_t + B_t (m_{t+1|T} - a_{t+1})`
- `C_{t|T}^* = C_t^* + B_t (C_{t+1|T}^* - R_{t+1}^*) B_t'`

Variance correction used by `dlm_df`:
- `C_{t|T} = (S_T / S_t) C_{t|T}^*`.

For parity implementation:
- smooth on unscaled covariance factors,
- then apply ratio correction with final scale.

## 7. Decomposition Component Extraction

Assume state partition:
- `theta_t = [theta_t^tr; theta_t^se]` (trend and seasonal blocks; optional additional blocks can be appended similarly).

Partition observation vector:
- `F_t = [F_t^tr; F_t^se]`.

Causal (filtered) component estimates:
- `trend_t = (F_t^tr)' m_t^tr`,
- `seasonal_t = (F_t^se)' m_t^se`,
- `structured_t = trend_t + seasonal_t`,
- `residual_t = y_t - structured_t`.

Forecast origin `T`, horizon `k`:
- state roll-forward: `a_{T+k|T} = G_{T+k} m_{T+k-1|T}`,
- structured forecast: `structured_{T+k|T} = F_{T+k}' a_{T+k|T}`.

Recursive residual feature for QDESN input path `j`:
- `residual_{T+k}^{(j)} = y_{T+k}^{(j)} - structured_{T+k|T}`.

Leakage rule:
- predictive features use filtered/causal quantities only;
- smoothed quantities are diagnostics only.

## 8. Trend/Seasonal Matrix Construction Mapping

### 8.1 Trend degree mapping

User-facing:
- `trend.degree = d`, where `d = 0, 1, 2, ...`.

Internal polynomial order:
- `order = d + 1`.

`polytrendMod(order)` structure:
- `F^tr = [1, 0, ..., 0]'`,
- `G^tr` upper-triangular with ones on diagonal and first superdiagonal.

### 8.2 Seasonal mapping

User-facing:
- `seasonal.period = p`,
- `seasonal.harmonics = {h_1, ..., h_m}`.

For each harmonic `h_j`, angular frequency:
- `omega_j = 2*pi*h_j/p`.

If `omega_j != pi`, 2D block:
- `G_j = [[cos(omega_j), sin(omega_j)], [-sin(omega_j), cos(omega_j)]]`,
- `F_j = [1, 0]'`.

If `omega_j = pi`, 1D block:
- `G_j = [-1]`,
- `F_j = [1]`.

Global seasonal block:
- block diagonal concatenation of `G_j` and matching `F_j` entries, consistent with `seasMod`.

## 9. Equation-to-Code Mapping Table

| Math Symbol | Meaning | `dlm_df` R variable(s) | C++ proposed variable(s) | Shape |
|---|---|---|---|---|
| `m_t` | filtered posterior mean | `m[t, ]` then returned as `fm` | `m_filt[t]` | `n x 1` |
| `C_t^*` | filtered posterior unscaled cov | `C[t,,]` before final scaling | `C_filt_unscaled[t]` | `n x n` |
| `a_t` | prior mean | `a[t, ]` | `a_pred[t]` | `n x 1` |
| `R_t^*` | prior unscaled cov | `R[t,,]` before scaling | `R_pred_unscaled[t]` | `n x n` |
| `f_t` | one-step mean | `f[t]` | `f_pred[t]` | scalar |
| `Q_t^*` | one-step unscaled var | `Q[t,,]` before scaling | `Q_pred_unscaled[t]` | scalar |
| `e_t` | forecast error | `e[t]` | `e_pred[t]` | scalar |
| `A_t` | Kalman gain | `A[t,,]` | `K_gain[t]` | `n x 1` |
| `l_t` | dof state | `l[t]` then returned as `n` | `dof_seq[t]` | scalar |
| `S_t` | scale state | `S[t]` then returned as `s` | `scale_seq[t]` | scalar |
| `R_t` | scaled predictive cov | `R[t,,]` after scaling | `R_pred_scaled[t]` | `n x n` |
| `Q_t` | scaled predictive var | `Q[t,,]` after scaling | `Q_pred_scaled[t]` | scalar |
| `C_t` | scaled filtered cov | `fC[t,,]` (returned `fC`) | `C_filt_scaled[t]` | `n x n` |
| `m_{t|T}` | smoothed mean | `sa[t, ]` then returned as `m` | `m_smooth[t]` | `n x 1` |
| `C_{t|T}^*` | smoothed unscaled cov | `sR[t,,]` before ratio correction | `C_smooth_unscaled[t]` | `n x n` |
| `C_{t|T}` | smoothed scaled cov | `sR[t,,]` after ratio correction, returned as `C` | `C_smooth_scaled[t]` | `n x n` |
| `F_t` | observation vector | `model$FF[,t]` (or single col) | `F_t` view | `n x 1` |
| `G_t` | transition matrix | `model$GG[,,t]` (or single matrix) | `G_t` view | `n x n` |

## 10. YAML-to-Math Mapping Table

| YAML key | Math object | Existing helper |
|---|---|---|
| `decomposition.trend.degree` | trend polynomial order `order=d+1` | `polytrendMod(order, ...)` |
| `decomposition.seasonal.period` | period `p` | `seasMod(p, h, ...)` |
| `decomposition.seasonal.harmonics` | harmonic set `{h_j}` | `seasMod(p, h, ...)` |
| `decomposition.input_lags.trend` | lag set for trend feature | QDESN input builder |
| `decomposition.input_lags.seasonal` | lag set for seasonal feature | QDESN input builder |
| `decomposition.input_lags.residual` | lag set for residual feature | QDESN input builder |
| `decomposition.variance.mode` | unknown constant `V` recursion | `l_t`, `S_t` equations above |
| `decomposition.state_estimate` | filtered vs smoothed selection | filtered for predictive path |

## 11. C++ Interface Contract (Phase 3 lock)

### 11.1 Filter/smoother kernel signature (exact)

```cpp
// [[Rcpp::export]]
Rcpp::List dlm_ndlm_filter_smooth_cpp(
    const arma::vec& y,           // length T
    const arma::mat& FF,          // n_state x T
    const arma::cube& GG,         // n_state x n_state x T
    const arma::vec& m0,          // n_state
    const arma::mat& C0,          // n_state x n_state
    const arma::vec& df,          // n_blocks
    const arma::ivec& dim_df,     // n_blocks, sum(dim_df)=n_state
    const double l0,              // >0
    const double S0,              // >0
    const bool compute_smoothed = true,
    const bool return_intermediates = true,
    const double jitter = 1e-10
);
```

### 11.2 Forecast structured-component roll-forward signature (exact)

```cpp
// [[Rcpp::export]]
Rcpp::List dlm_ndlm_structured_forecast_cpp(
    const arma::cube& GG,
    const arma::mat& FF,
    const arma::vec& state_origin,
    const arma::ivec& idx_trend,
    const arma::ivec& idx_seasonal,
    const int origin_index,       // 1-based at R boundary
    const int H
);
```

### 11.3 Output contract for `dlm_ndlm_filter_smooth_cpp`

Mandatory fields:
- `fm`: `T x n_state`.
- `fC`: `T x n_state x n_state` (scaled filtered covariance).
- `sm`: `T x n_state` (`NULL` if smoothing disabled).
- `sC`: `T x n_state x n_state` (scaled smoothed covariance; required for parity harness).
- `s`: length `T` scale sequence.
- `n`: length `T` dof sequence.

Intermediate fields (required when `return_intermediates=TRUE`):
- `a`: `T x n_state`.
- `R_unscaled`: `T x n_state x n_state`.
- `C_unscaled`: `T x n_state x n_state`.
- `Q_unscaled`: length `T`.
- `f`: length `T`.
- `e`: length `T`.
- `K`: `T x n_state`.

### 11.4 Output contract for `dlm_ndlm_structured_forecast_cpp`

- `trend`: length `H`.
- `seasonal`: length `H`.
- `structured`: length `H`.
- `state_last`: length `n_state`.

## 12. Signoff Items Requiring Explicit Confirmation

1. Smoothing index convention:
- use canonical `G_{t+1}` in `B_t = C_t^* G_{t+1}' (R_{t+1}^*)^{-1}`.

2. Smoothing variance correction:
- use `C_{t|T} = (S_T/S_t) C_{t|T}^*` as parity target.

3. Predictive leakage policy:
- filtered-only for production decomposition features.

4. Legacy quirks policy:
- C++ implementation targets mathematically indexed recursions above;
- R parity harness should compare to a corrected reference wrapper when legacy indexing issues in raw `dlm_df` are encountered.

## 13. Completion Statement for Phase 0

Phase 0 deliverables completed in draft form:
- exact recursion equations,
- variance update equations,
- covariance correction equations,
- decomposition extraction equations,
- equation-to-code mapping table,
- YAML-to-math mapping table,
- signoff checklist for implementation gate.

Pending for implementation gate:
- user signoff on Section 12 decisions.

## 14. Phase 3 Lock Checklist (R/C++ Contract + Dependencies)

Confirmed already available:
- trend/seasonal structure controls in YAML (`degree`, `period`, `harmonics`),
- matrix-construction helpers in R path (`polytrendMod`, `seasMod`, `combineMods` usage),
- Phase 2 R runtime with decomposition-informed inputs and recursive forecast buffering.

Confirmed non-equivalence (must be respected in implementation):
- `src/kalman.cpp` is not a drop-in replacement for `R/utils.R::dlm_df`.
- Phase 3 target is full `dlm_df`-parity NDLM filter/smoother (moments + variance recursion + covariance scaling/correction).

Implementation gate before enabling C++ backend by default:
1. C++ outputs exactly match Section 11 names/shapes.
2. Numerical parity vs R reference on fixed-seed fixtures (filter + smoother + `s/n` sequences).
3. Forecast-trajectory parity for structured components from identical origin states.
4. Sim and real pipeline regression tests pass with `decomposition.backend=r` and `decomposition.backend=cpp`.
