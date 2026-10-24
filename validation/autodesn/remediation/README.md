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

`autodesn_readout_coefficients(fit, draw_index)` transports matching draws to original predictor/response coordinates, including all intercept corrections. Its help specifies the lag, reservoir and calendar coordinates. It keeps different readout dimensions separate. Group norms and conditional group EDF are monitored in the scalar trace; conditional EDF is a Gaussian-step quantity rather than a selected-variable count.

`autodesn_extended_local_proposal()` defines an optional exact reservoir-local scale proposal. The prior component has positive mass for every architecture; all active-vector density constants and inactive prior terms are retained in its collapsed Hastings ratio. Reservoir auxiliaries and then coefficients are restored before conditioned updates. The mathematical derivation is in `MATH.md`. This computational option does not modify `tau0`, slab controls, architecture priors or the likelihood. It is disabled unless explicitly supplied and is not a qualified full-bank repair merely because its small-target tests pass.

Forecast with `forecast_paths(fit, H, draw_index = ids, inner_paths = K)`. For SV, initialize `autodesn_filter(fit, ids, particles = N)`, then use the filter explicitly. After issuing a forecast, append actual observations with `autodesn_update_history()` and update the matching conditional filter using `previous`. The new observations never reweight static parameters/architectures. Filters check static-draw identity and history prefixes. Initial filters replay the scored training block under each static draw; cloning a single terminal state is not used.

Both complete `H_all` and recovered compact `H_last` terminal-state formats are supported. A pre-forecast integration audit caught the original augmented adapter's empty-state handling for `H_last`; it was corrected before any new benchmark forecasts. Forecast-map identities are separate from conditional-posterior identities, and conditional filters check the actual selected propagation maps. `compact_templates.R` can recover exact numeric forecasting maps while dropping unused construction closures; read its actual completion/parity evidence before using an output. Its full-bank invocation requires low measured anonymous memory and must wait until the large inference job ends.

Fitted mean functions and constant-variance fixed-design predictions are available. Set `variance_control$save_state_paths=TRUE` to retain latent smoothing paths at bounded joint checkpoints and enable conditional fixed-design fitted replicates. With that option disabled, SV fitted replication is explicitly rejected rather than silently substituting filtered variances. These replicates condition on the observed training design; unconditional recursive PPC and its data-adaptive preprocessing require separate calibration. Causal recursive SV forecasting is supported.

## Execution and provenance

Use the project-local environments recorded in the parent `ENVIRONMENT.md`. Compile `src/autodesn_rhs.cpp` using `Rcpp::sourceCpp()` for source-only runs. Installed builds use the registered Rcpp wrappers. No global/system installation is needed.

- `test.R`: independent numerical/small-target tests.
- `preflight.R F1|F2|SV`: full 426-reservoir training-only feasibility pilots, with source identities captured before loading.
- `launch_fit.py FAMILY pilot --workers 1`: immutable complete-source snapshot, four dispersed 1k-warmup/2k-retained pilot chains and a frozen full-support proposal. Do not edit or launch a live streaming R driver directly.
- `launch_fit.py FAMILY production 32000 --workers 1`: four fresh 8k-warmup/32k-retained chains using the frozen proposal. Higher declared budgets have separate directories. Use `--snapshot KEY` to resume missing complete-chain artifacts under the same immutable source contract; partial chains restart from their recorded seeds.
- `qualify.py FAMILY PHASE`: independent rank/bulk/tail and architecture/period-frequency screens; cross-budget qualification remains separate.
- `cross_budget.py FAMILY LEFT RIGHT`: independently screened successive fresh-budget comparison, fixed training-probe means/predictive SDs and major architecture/period masses. Its result alone cannot authorize forecasting.
- `gp_moves.jl`: native-target period-coordinate independence moves with full proposal corrections.
- `test_gp_moves.jl`: native trace score/update and detailed-balance checks.
- `run_process.py`: observed subprocess completion, actual exit status, runtime caps and measured resource scopes. `test_resources.py` checks aggregate descendant memory and wall-cap handling. Only one large job runs at once; four workers are allowed only with the exact matrix/augmentation cache that passed the longer four-worker memory preflight. The earlier full-bank fork failure remains recorded.
- `launch_sbc.py`: immutable fixed-design ridge/RHS calibration, with atomic per-replication checkpoints and explicit retained budgets.
- `test_sv_references.R` and `test_gp_reference.jl`: independent small-state conditional references.
- `benchmark_kernel.R` and `benchmark_forecast.R`: paired synthetic computational benchmarks, separately labeled from full fit/forecast runtime.
- `grouped_prior_integration.py`, `check_grouped_reference.py`: independent normalized-prior integration versus four full conditional fixed-local grouped-RHS chains.
- `local_prior_integration.py`, `local_reference.R`: seven-dimensional normalized-prior integration and learned-local sampler reference, including the optional exact local proposal. Check actual output before claiming agreement.
- `sv_joint_reference.py`, `sv_joint_mcmc.R`, `check_sv_joint_reference.py`: full two-response SV posterior comparison, distinct from the scalar conditional tests.
- `archive_checkpoints.py`: SHA256-verified split archives of bank-free numerical artifacts and recorded immutable source snapshots.

All fit caches include a target/source/data contract. An unchanged bank is referenced rather than copied into every checkpoint. Compact checkpoints require reattaching the deterministically reconstructed matching bank and verifying `extension_id`.

The original bank contains large reservoir-construction environments not needed by inference. `make_inference_cache.R` and `cache_extensions.R` remove those environments without changing matrices, model masses, frozen transforms or target identifiers. Cache and original-bank checksums are verified before use. The cache intentionally cannot forecast: attach the matching original reservoir objects. Completed original and cached 32k chains 2 and 4 reproduce common traces, coefficients, locals, volatility records and fitted probes bit for bit. The four-chain cache preflight measured aggregate PSS 4,838,922 KiB and environment anonymous memory 5,633,073,152 bytes; the launcher enforces a 6.4 GB anonymous-memory cap.

Full Bayesian production qualification, SBC, GP higher-budget independent runs, independent confirmations, complete predictive/runtime sensitivity and the final comparison/report remain outstanding until their outputs and gates confirm otherwise. Existing timing extrapolations are feasibility estimates, not completed budgets or running background work.

The first 200-case RHS SBC falls inside its simultaneous rank envelope, but 136 cases have spectral ESS below 400 (minimum 66.5); calibration is unresolved. Both four-chain pilots fail the production screen. F2 found period 60 in all four chains but exhibits severe reservoir-mode disagreement. Its launcher also failed after all four checkpoints were saved; the checkpoint validation and failed invocation record must be read together. No new accuracy or superiority claim follows from these runs.

Forecast simulation now batches paths with a common reservoir/period, preserving their coefficient, noise and conditional-state assignments. In a synthetic reservoir-64/H30/192-outer/8-inner paired benchmark, median time changed from 2.359 s to .285 s with maximum path difference below 1e-13. This is a kernel comparison under concurrent training load, not an isolated whole-study speedup.
