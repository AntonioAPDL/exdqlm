# Gaussian AutoDESN: 500 washout, 500 training, 100 forecast

This is a larger, fixed-origin experiment following the corrected Q-DESN
forecast contract in `docs/implementation_notes/independent_qdesn_corrected_forecast_v3_20260930.md`.
The earlier 12-step experiment remains separate and unchanged.

## Exact observation split

| Indices | Role | Uses |
|---|---|---|
| 1:500 | Unscored washout | Frozen response mean/SD and reservoir initialization |
| 501:1000 | Training | Exactly 500 common Gaussian likelihood contributions |
| 1001:1100 | Forecast | Evaluation only; one forecast issued at time 1000 |

Generator initialization is not a second hidden washout. MCMC burn-in is a
separate count of sampler sweeps. The scaling prefix is observed information
available before training. It differs from the historical manuscript's fit-row
scaling: retaining a disjoint prefix keeps the AutoDESN prior/conditioning
convention explicit and avoids adding 500 extra observations to the likelihood.

Set both `conditioning = 500L` and `washout = 500L`. Explicit `washout` counts
the entire unscored prefix. Omitting it retains the original additive API.

```r
library(exdqlm)
# y contains the 1,000 observations available at the forecast origin.
specs <- list(list(D = 2L, n = c(50L, 50L), n_tilde = 50L, m = 90L,
  alpha = .6, rho = c(.6, .6), seed = 11L, washout = 500L,
  act_f = "tanh", act_k = "identity"))
bank <- autodesn_build_bank(y, specs, conditioning = 500L, washout = 500L)
stopifnot(identical(bank$keep_idx, 501:1000))
fit <- autodesn_fit_bank(bank, n_burn = 1500L, n_mcmc = 4000L, seed = 101L)
fc <- forecast_paths.autodesn_fit(fit, H = 100L, nd = 192L,
  inner_paths = 64L, backend = "batched", seed = 102L)
forecast_mean <- rowMeans(fc$mean_conditional_location)
forecast_quantiles <- t(apply(fc$yrep, 1L, quantile,
  probs = c(.05, .5, .95), type = 8))
```

The study uses three independently initialized chains and the 72-candidate
bank in `helpers.R`; the snippet illustrates the same API with one model.

## Forecast computation

An outer draw selects one retained joint specification, coefficient vector and
observation variance. Each outer draw has 64 independent Gaussian innovation
paths. All parameters remain fixed across its 100 leads and 64 paths. Every
path updates its own reservoir states and lag buffer using simulated outcomes.
No unknown future observation enters a forecast. The shared Normal engine
implements both serial and batched propagation with the same transition.

Three quantities are kept distinct:

1. `mu_draws` contains conditional means evaluated along each stochastic path.
2. `mean_conditional_location` averages these means over inner paths for each
   outer parameter draw. Since the readout is linear, this also equals applying
   that draw's coefficients to its average readout state. Averaging over outer
   draws estimates the marginal forecast mean with less Monte Carlo noise than
   averaging noisy outcomes.
3. The empirical quantile of **all pooled `yrep` outcomes** estimates the
   marginal predictive quantile. Averaging draw-specific quantiles, or inserting
   a one-step quantile into the next input, estimates a different quantity.

`recursion_mode = "conditional_mean_plugin"` is retained as a diagnostic. In
nonlinear reservoirs, zero-innovation recursion generally differs from an
inner-path average. It is not used to construct predictive intervals. Nested
K=32/64/128 calculations use the same outer draws and matching innovation
subsets. They assess inner simulation error; they do not establish that 192
outer draws eliminate posterior Monte Carlo error.

## Frozen experiment

The bank has depths 1/2/3, widths 20/50, input lag counts 5/30/90, two
leak/radius/input-gain profiles, and seeds 11/29. Bridges are exact identities;
all layers enter a readout containing one proper intercept. Reservoir activation
is tanh and lower-layer readout activation is identity. Recurrent indegree is
5; input/interlayer weights use the existing normalized exact-fan-in builder.
The prior is uniform over depths and specifications within each depth. No
direct response lags enter the DESN readout. One fixed depth-2, width-50,
lag-90, fast-profile, seed-11 specification is chosen before simulation.

The main process reuses
`tools/merge_reports/20260305_dynamic_dgp_model_helpers.R`: period 90, two
harmonics with initial amplitudes 32 and 12, phases 0.85 and -1.25, level 45,
slope 0.014, state innovation SDs `(0.005, 0.00002, 0.004, 0.004, 0.003, 0.003)`,
and Gaussian observation SD 10. Initial state equals m0 deterministically.
Linear AR(1) and nonlinear AR(2) controls use the earlier experiment's
coefficients and innovation SD 0.35, with the larger observation split.

Three fresh series per process use a frozen seed formula. AutoDESN and fixed
DESN each use three chains, 1,500 discarded sweeps and 4,000 retained sweeps
per chain. Before examining forecasts, a prespecified failed diagnostic screen
may trigger one longer rerun (3,000 burn-in; 8,000 retained per chain). Both
attempts' diagnostics are recorded. An unresolved screen is reported, not
silently discarded or relabeled as convergence.

Comparators are fixed DESN, scaled-ridge Gaussian AR(1)/AR(90), a Gaussian
seasonal random walk, a Gaussian constant model, and a known-DGP forecast.
The last has true parameters and is an information-advantaged reference. For
the dynamic seasonal process it filters observations only through time 1000
and propagates latent uncertainty forward; it never conditions on future
latent states. Gaussian AR uses the existing scaled-ridge prior, which differs
from AutoDESN's independent ridge prior. All fitted methods use the same 500
response rows; seasonal reference differences use admissible earlier lags.

RMSE, MAE, CRPS, quantile check losses, predictive coverage and widths are
computed in original response units. Latent realized-path errors and differences
from the known-DGP forecast mean are separate diagnostics. The realized latent
trajectory is not itself the fixed-origin conditional mean. Results are
summarized over all 100 leads and in bands 1–10, 11–30, 31–60 and 61–100.
Only independent simulated series are independent data replications; posterior
draws, paths and horizons are not additional data sets.

## Reproduction

From the repository root after installing the checkout:

```sh
Rscript validation/autodesn/long_horizon/run_study.R
python validation/autodesn/long_horizon/plot_results.py
```

An existing output configuration causes a deliberate stop; choose a new
`AUTODESN_LONG_OUT` for a new run. `AUTODESN_LONG_REPS` controls the number of
independent series per process and defaults to 3. Defaults produce 9 cases,
6,300 scored method/lead rows, and 12,288 AutoDESN paths per case. The full
configuration, source hashes, every forecast lead, chain diagnostics, model
probabilities and 64 complete illustrative paths per case are exported. Arrays
of outer-draw mean locations and plug-in paths are also retained. Full fitted
model binaries and every Monte Carlo trajectory are not stored.

`IMPLEMENTATION_PROMPT.md` records the implementation contract. `RESULTS.md`
records executed outcomes and limitations after the frozen run completes.
