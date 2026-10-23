# AutoDESN 500/2000/100 experiment contract

Extend the existing isolated feature branch, preserving the earlier experiments
and the Gaussian independent-ridge AutoDESN implementation. Use exactly 500
initial observations for frozen scaling and washout, 2,000 likelihood rows
(501:2500), and 100 future observations (2501:2600). Preserve the corrected
Q-DESN recursive transition and joint model/readout/variance draws. Fit only on
the available history; feed simulated responses back at every forecast lead.

Prespecify three nonlinear, conditionally Gaussian but heteroscedastic synthetic
processes: smooth state-dependent scale, threshold mean with asymmetric GJR
volatility, and hidden Markov regimes with nonlinear seasonal/delayed dynamics.
Use three independent series per process and the existing 72-candidate bank.
Keep the AutoDESN likelihood homoscedastic. Include a fixed DESN, Gaussian AR
references, a fitted AR-GJR-GARCH reference and an information-advantaged known
DGP forecast. Filter hidden states using observations only; never initialize the
oracle from the simulated hidden state. Do not call custom generators canonical
published benchmarks or tune on their future forecast scores.

Run three seeded Gibbs chains and a diagnostic-only retry rule. Freeze the
configuration and source hashes before evaluation. Quantiles pool predictive
paths (type 8); means average conditional Gaussian locations. Separately evaluate
one-step forecasts with observed feedback only after each forecast is issued,
without refitting or posterior updating. Use this separate experiment to compare
conditional predictive scale and coverage in volatility groups defined on the
training data. Never interpret the realized future volatility path as known to
a fixed-origin forecast.

Test prefix-invariant simulation, exact row counts, causal forecast timing,
independent GJR recursions, hidden-state filtering and mixture moments, Gaussian
mixture density calculations, and serial/parallel sampler reproducibility.
Export reproducible configurations, seeds, diagnostic attempts, all 100 leads,
illustrative paths, calibration metrics and plots. Audit exported results against
raw scores and do not require AutoDESN to win. Commit and push the completed work
on the existing feature branch and update the draft PR without merging.
