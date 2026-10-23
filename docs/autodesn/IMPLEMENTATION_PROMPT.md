# Gaussian AutoDESN implementation prompt

Implement a conservative, additive Gaussian AutoDESN extension in an isolated
branch of the current Q-DESN implementation. Reuse its actual reservoir/design
builder and Normal recursive forecast API. Preserve existing quantile models.

Use a finite, explicit prior over architecture, memory, leak, spectral radius,
and reservoir seeds. Use a proper Gaussian intercept, independent Gaussian
ridge slopes, inverse-gamma observation variance, and optional gamma global
ridge precision. Do not implement RHS or pretend the scaled-ridge posterior
in the existing Gaussian backend represents this independent prior.

Score common causal response rows with preprocessing frozen from an unscored
conditioning prefix. Update (model, coefficients) jointly using a collapsed
model draw followed immediately by a coefficient draw; then update variance
and ridge precision. Preserve one joint posterior draw throughout each recursive
forecast path. Make unsupported modes fail explicitly.

Follow package naming, roxygen/manual documentation, export and testing style.
Audit evidence algebra against independent dense covariance calculations,
Gibbs draws against low-dimensional numerical integration, reservoir feature
and forecast parity, temporal leakage, prior duplication, edge cases, and RNG
isolation. Exercise applicable existing regressions and report environment or
pre-existing failures precisely.

Run reproducible simulated linear, nonlinear, and seasonal forecasting studies
with repeated independent series, multiple forecast origins, honest held-out
outcomes, forecast baselines, predictive scoring and interval coverage. Include
multi-chain diagnostics and produce readable plots, raw scores, configuration,
commands, runtime details and limitations. Treat these as implementation
validation, not evidence of general superiority over AutoGP, SMC or other models.

Review the complete diff, commit all relevant code, tests, documentation and
reproducibility assets, and publish the isolated branch without merging it.
