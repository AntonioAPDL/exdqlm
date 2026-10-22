# AutoDESN 500/500/100 implementation contract

Extend the existing Gaussian independent-ridge AutoDESN branch without changing
the default likelihood, priors, sampler target, or historical experiment outputs.
Use observations 1:500 only for response scaling and reservoir warmup, 501:1000
for exactly 500 likelihood contributions, and 1001:1100 as a fixed-origin test.
Keep generator initialization, reservoir washout, and MCMC burn-in distinct.

Audit and follow the corrected Q-DESN forecast contract: identity interlayer
bridges, tanh reservoir activations, identity lower-layer readout activation,
intercept plus all layers, and no direct-response readout lags. Draw one joint
model/coefficient/variance sample per outer draw. Repeat that joint sample over
inner innovation paths, holding it fixed for every lead. Feed each path's own
simulated observation back into its lag buffer. Never use future outcomes for
scaling, fitting, candidate design, forecasts, or architecture selection.

Extend the shared Normal forecast implementation with an opt-in batched path
backend, explicit standard-normal innovations, and an explicitly labeled
zero-innovation plug-in mode. Share its reservoir transition with the existing
serial implementation; preserve default serial RNG behavior. Extend AutoDESN
with explicit total washout, joint draw indices and nested paths. Test serial
and batched parity, analytic Gaussian AR predictive moments and quantiles,
nested path subsets, scaling, dimensions, RNG isolation and future exclusion.

Freeze a broader identity-bridge bank before inspecting future scores. Use the
repository's dynamic trend/two-harmonic Gaussian simulator for the main example,
with its period-90, high-noise parameters, and include stationary linear and
nonlinear controls. Run three independently initialized Gibbs chains, inspect
mixing before forecasting, and retain raw diagnostics. Compare AutoDESN with a
prespecified fixed DESN, Gaussian lag regression, seasonal/constant references,
and a clearly labeled known-parameter DGP forecast. Keep realized-error metrics,
latent-location diagnostics and forecast distribution summaries separate.

Export complete 100-step paths, pooled predictive quantiles, outer-draw mean
conditional locations, plug-in diagnostics, lead-band scores, specifications,
source hashes and repeatable configuration. Use fresh independent series,
fixed seeds and type-8 quantiles. Produce readable forecast, horizon-score and
specification plots. Report poor long-horizon behavior or mixing honestly;
never tune on the 100 held-out observations or claim improvement by construction.

Run focused existing regressions, an unchanged-default replay, and the new
contract tests. Commit and push only to the existing isolated feature branch;
update its draft PR without merging or changing manuscript/reporting authority.
