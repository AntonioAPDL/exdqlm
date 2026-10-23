# C1: AutoDESN, AutoGP and AutoARIMA

Selected series C1, `switching_seasonal`, seed 866020. The frozen input is exactly
the 3,000 observations displayed in the selection gallery. `configuration.json`
is the experiment contract; the TOML file is its Julia-readable scalar/list
projection and the Python contracts verify parity and input SHA-256 hashes.

All methods fit responses 501:2500 once. The initial 500 observations initialize
and scale the DESN, not its likelihood. AutoGP and AutoARIMA use their native
training-only preprocessing. The 500 test days are evaluated at every origin
2500:2970, each with 30 unknown responses. There are 471 complete origins and
14,130 forecast pairs per model. Parameters and ensemble weights remain fixed;
observed history/state updates between origins. Forecasts within an origin use
stochastic recursive DESN paths, the GP joint predictive distribution, or the
ARIMA predictive distribution, never teacher-forced unknown observations.

AutoDESN uses the exact 456 recovered specification objects, not a newly sampled
grid. Every specification receives a training-only opposite-state washout test.
Admitted candidates receive equal prior mass per depth, then per specification.
The production independent ridge Gibbs sampler is used with an exact grouped
conditional model-score adapter whose dense-density and seeded-chain parity are
tested. Its three chains must pass the frozen R-hat, spectral ESS and probability
agreement screens before forecasts are labeled complete. These are convergence
screens, not proof of mixing. The architecture is selected/averaged within this
finite dictionary; recurrent weights are not trained. The Gaussian innovation
variance is constant for each posterior draw. The more complicated DGP is not
assumed by the fitted likelihood.

AutoGP is the authors' `probsys/AutoGP.jl` version 0.1.19, revision
`2ad372db2b8bea176e3b32a769bfb5d6cff80866`. It uses native default kernel grammar
and parameter priors with depth at most 4, two independent eight-particle SMC
runs, and the recorded structure MCMC/HMC budgets. Runs are pooled equally;
they are not selected by test results. Finite-particle approximation and possible
particle collapse must be assessed from the retained ESS, weights, structures
and separate-run forecasts. One Julia thread makes the native RNG reproducible.
For fixed particles the whole 500-dimensional predictive normal is computed
once, then conditioned on observed prefixes by exact rank-one Gaussian updates.
Three origins are checked against the authors' native API. Native `add_data!`
updates weights, so those checks restore the training weights explicitly. A
serialization adapter removes the library's included numerical jitter before
reconstruction to prevent adding it a second time; round-trip tests verify it.

AutoARIMA uses forecast 8.21.1, training-only `findfrequency`, unit-root and
seasonal differencing tests and exhaustive AICc search within recorded bounds,
with exact ML and no approximation. It receives no true simulation period.
`Arima(model=fit)` filters observed prefixes with trained coefficients; innovation
variance is reset to the original estimate before predicting. No coefficients
are re-estimated at rolling origins. Each method has different priors/search
and computational cost; this is a comparison of practical automatic procedures,
not an equal-compute architecture experiment.

The R scripts source the checked-out production files and record their hashes.
Run `test_contracts.R`, `test_scoring.py`, then the three `run_*` scripts and
`report.py` from the repository root. For Julia, activate a checkout of the pinned
AutoGP source and instantiate its dependencies. CI executes independent method
jobs and always uploads diagnostic/checkpoint evidence, even on failure. A final
comparison job requires all three successful methods and independent index,
target, interval and score audits. Feature-bank parts are local resume files
and excluded from uploaded artifacts to limit size. The compact posterior and
each chain's numerical draws are retained.

Reported metrics: RMSE, MAE, CRPS, negative log predictive density, central 50/90%
coverage and widths, overall and by lead. GP/ARIMA scores and quantiles are
analytic Gaussian-mixture calculations (quantiles use numerical root finding).
DESN CRPS/quantiles use 192 posterior draws × 8 innovation paths; its log score
averages conditional Gaussian densities along recursive paths. The finite
ensemble CRPS has a Monte Carlo approximation error; paired 192/384 outer draw
and 4/8/16/32 inner-path sensitivity checks at three origins are retained.
Overlapping rolling forecasts are dependent; no naive independent-error p-values
are reported. C1 was selected visually, so results are descriptive for this
example. Aggregate scores weight forecast pairs equally, not unique target days.
