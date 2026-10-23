# C1: AutoDESN versus AutoGP versus AutoARIMA

Implement and execute the user's selected single-series comparison. Publish the
source, frozen data, recovered dictionary and execution workflow before expensive
inference. Preserve outputs and checkpoints independently of a chat session.

Use C1 (switching_seasonal, repetition1, original seed866020) exactly as exported
in the selectable gallery. Freeze time/y only: 500 washout, 2000 fitting rows
(501:2500), and 500 test days. Evaluate origins2500:2970, leads1:30. Fit once;
update observed history/state between origins. Unknown future responses never
enter an issued forecast. Hold fitted parameters and model-ensemble weights
fixed. The GP may condition each fixed kernel on newly observed responses.

Use the exact recovered456 DESN specifications, with the production shared
builder, Gaussian likelihood and proper independent ridge readout. Apply the
recorded training-only opposite-initial-state washout test (maximum difference
<=.001). Retain all audit rows and normalize the depth-balanced prior after
admission. Reuse the original Gibbs body; an exact locally grouped model-score
calculation may improve speed only after parity tests. Require three-chain
Rhat<=1.01, spectral ESS>=400, model-probability chain range<=.05. Retry solely
on those diagnostics using the previously frozen durations.

Use the authors' AutoGP.jl SMC implementation, pinned to an explicit revision.
Infer kernel structures and parameters using all2000 training observations.
Do not substitute a fixed-kernel GP or a hand-written kernel grid. Use bounded
depth4, native grammar/prior, two independent eight-particle runs, and explicit
recorded SMC/MCMC/HMC budgets. Pool independent runs equally; do not pick a run
by test performance. Preserve particle weights, structures and SMC diagnostics.
For efficient rolling forecasts, precompute the joint500-day predictive normal
per fixed particle, then condition sequentially via exact Gaussian updates.
Check this against direct Gaussian conditioning and the native AutoGP API.

Use forecast::auto.arima, with the seasonal period estimated from training by
forecast::findfrequency, exhaustive AICc search under recorded order bounds,
and exact likelihood (no approximation). Never supply the true DGP period.
Keep coefficients and innovation variance fixed during rolling state updates.
Use the native predictive Gaussian distributions. Record chosen period/orders.

Score every model on the same14130 origin/lead pairs: RMSE, MAE, CRPS, log score,
50/90% coverage and interval widths. Preserve per-origin/per-lead scores and
report results for the original100 and new400 targets separately. Explicitly
distinguish analytic predictive scores from DESN finite-ensemble approximations.
Check DESN Monte Carlo sensitivity at first/middle/final origins. Produce actual
forecast plots and horizon/coverage comparisons, with no invented performance.
The user selected C1 visually; this is a descriptive worked example, not an
unbiased benchmark or a general claim about model superiority.

Do not mark results complete until all three methods, independent audits and
plots exist. Keep failures visible. Never merge the development branch.
