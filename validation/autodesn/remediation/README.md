# AutoDESN remediation execution

This branch implements the approved plan in `../nonlinear_heteroscedastic/plans/REMEDIATION_PLAN.md`. The original NHS1 benchmark and audit remain immutable references. Work begins at `fea371fbfa73c425a6f98407095194c1e8098a24` on a separate feature branch.

**Current status:** implementation and training-only development. No new model is scientifically qualified and no confirmation outcomes have been generated or inspected. Passing numerical tests and running short pilots do not establish posterior convergence. See `execution.json` and actual evidence files; a script's presence is not evidence it ran.

## Implemented opt-in API

```r
bank <- autodesn_build_bank(y_train, candidates,
  conditioning = 30, washout = 500,
  standardize_features = TRUE, normalize_features = FALSE)
augmented <- autodesn_extend_bank(bank,
  readout_control = list(lags = 1:90, prior = "grouped"),
  seasonal_control = list(periods = 20:120, harmonics = 16))
fit <- autodesn_fit_bank(augmented,
  beta_prior = "rhs",
  rhs_control = list(tau0 = 0.001, slab_scale = 1, slab_df = 4,
                     interweave_global = TRUE),
  model_control = list(save_draws = 2048),
  variance_control = list(type = "sv"), seed = 123)
```

The example uses default illustrative inference budgets, not a qualified experiment. Direct `autodesn_fit()` accepts `readout_control`, `seasonal_control`, and `variance_control` as opt-in arguments. Existing default ridge/RHS paths are preserved.

Period and reservoir indices have proper independent prior masses. Every period remains in the declared support. The proper intercept variance is independent of observation variance. Flat RHS applies to all slopes; grouped RHS has separate lag/reservoir global scales and a proper Gaussian calendar prior. Normalized finite-slab local updates, slice updates and coefficient-collapsed architecture/period moves retain all Gaussian determinants. Frozen general-dimensional Student-t independence proposals include exact Hastings corrections; they are never priors.

`model_control$save_draws` bounds coefficient/local-scale checkpoint storage while retaining every scalar/functional trace in `fit$trace` and `fit$probes`. `fit$draws` matches saved joint coefficient states exactly. Diagnostic occupancy uses all retained draws. This avoids retaining gigabytes of full coefficient vectors. It is a storage choice, not architecture screening.

Forecast with `forecast_paths(fit, H, draw_index = ids, inner_paths = K)`. For SV, initialize `autodesn_filter(fit, ids, particles = N)`, then use the filter explicitly. After issuing a forecast, append actual observations with `autodesn_update_history()` and update the matching conditional filter using `previous`. The new observations never reweight static parameters/architectures. Filters check static-draw identity and history prefixes. Initial filters replay the scored training block under each static draw; cloning a single terminal state is not used.

Fitted mean functions and constant-variance fixed-design predictions are available. SV fixed-design posterior prediction is explicitly rejected because full smoothing paths are not retained; causal recursive SV prediction is supported. Full smoothing/PPC support is an outstanding deliverable rather than silently substituting filtered variances.

## Execution and provenance

Use the project-local environments recorded in the parent `ENVIRONMENT.md`. Compile `src/autodesn_rhs.cpp` using `Rcpp::sourceCpp()` for source-only runs. Installed builds use the registered Rcpp wrappers. No global/system installation is needed.

- `test.R`: independent numerical/small-target tests.
- `preflight.R F1|F2|SV`: full 426-reservoir training-only feasibility pilots, with source identities captured before loading.
- `fit.R FAMILY pilot`: four dispersed 1k-warmup/2k-retained pilot chains and a frozen full-support proposal.
- `fit.R FAMILY production 32000`: four fresh 8k-warmup/32k-retained production chains using that frozen proposal. Higher declared budgets have separate directories.
- `qualify.py FAMILY PHASE`: independent rank/bulk/tail and architecture/period-frequency screens; cross-budget qualification remains separate.
- `gp_moves.jl`: native-target period-coordinate independence moves with full proposal corrections.
- `test_gp_moves.jl`: native trace score/update and detailed-balance checks.
- `run_process.py`: foreground subprocess completion, actual exit status and Linux child resource use.

All fit caches include a target/source/data contract. An unchanged bank is referenced rather than copied into every checkpoint. Compact checkpoints require reattaching the deterministically reconstructed matching bank and verifying `extension_id`.

Full Bayesian production qualification, SBC, GP higher-budget independent runs, independent confirmations, complete predictive/runtime sensitivity and the final comparison/report remain outstanding until their outputs and gates confirm otherwise. Existing timing extrapolations are feasibility estimates, not completed budgets or running background work.
