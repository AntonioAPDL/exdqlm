# Gaussian AutoDESN: nonlinear heteroscedastic stress tests

**Primary evaluation:** [rolling-origin 30-step forecasts](rolling/README.md).
This page documents the earlier single 100-step forecast and one-step diagnostics.
They are preserved separately after the rolling-origin clarification.

This extends the earlier `long_horizon` experiment without replacing its output.
The exact split is **500 washout + 2000 training + 100 forecast**: observations
1:500 determine response centering/scaling and warm reservoir states; rows
501:2500 contribute to every candidate likelihood; forecasts target 2501:2600.
MCMC burn-in is separate from the time-series washout.

Run from the repository root with R and the package dependencies installed:

```sh
export AUTODESN_HETERO_OUT=/tmp/autodesn_500_2000_100_reproduction
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript validation/autodesn/heteroscedastic/test_contracts.R
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript validation/autodesn/heteroscedastic/run_study.R
python validation/autodesn/heteroscedastic/audit_results.py
python validation/autodesn/heteroscedastic/plot_results.py
python validation/autodesn/heteroscedastic/write_results.py
```

The runner sources the checked-out `R/` code. It fits three independent explicitly seeded
chains serially by default to limit memory use. On Unix, set
`AUTODESN_HETERO_CORES=3` to opt into `parallel::mclapply` when enough RAM is
available. A longer-chain parallel retry exceeded this workspace's 8 GB limit;
the incomplete attempt was archived and the full study restarted with serial
chains before finalizing results. Models, seeds and diagnostic rules did not
change. The contract tests check exact serial/parallel replay and parent RNG preservation. `AUTODESN_HETERO_OUT` selects
an alternative output directory (default `artifacts` here). Existing frozen
configurations cannot be overwritten. Figures and result audits read exported
CSVs and do not change fitting or simulation. The report is written alongside
fresh reproduction outputs; the checked-in run reports to `RESULTS.md` here.
The optional initial memory-recovery ledger is checked when present and is not
required for a fresh serial run. `resource_recovery.json` records the memory
recovery, archived computational source snapshots, and exact first-case
AutoDESN/fixed-DESN parity checks. Python requires numpy, pandas and
matplotlib. No fitted-model binaries are needed for reproduction.

## Three custom data-generating processes

These are transparent synthetic stress tests, **not canonical literature
benchmark datasets**. Their processes and test windows differ from the earlier
500-training example, so this study does not isolate the effect of training size.
All innovations are standard normal before multiplying by the indicated scale. Lags before observation 1 are zero. The first 500 responses
are generated and observed, not hard-coded to zero. The three processes each have
three independent seeded series; these nine series are the replication units.

Let a=y[t-1], b=y[t-2], c=y[t-3].

1. **Smooth state-dependent scale**: mean `0.35a + 0.45 sin(1.5b) +
   0.20c/(1+c²)`; SD `0.16 + 0.75 logistic(3(|a|-0.55)) +
   0.18(0.5+0.5 sin(2 pi t/36))`. The nonlinear mean and time/state-dependent
   variance are fully observable from past responses and the clock.
2. **Threshold + asymmetric volatility**: mean `-0.20+0.45a+0.25 tanh(b)`
   for a<0, otherwise `0.15+0.25a-0.35 tanh(b)`, plus `0.10 sin(c)`.
   Innovation variance `v[t]=0.03+0.06 e[t-1]²+0.12 e[t-1]² I(e[t-1]<0)
   +0.85v[t-1]`, starting at v[0]=1, e[0]=0. Negative innovations increase
   variance more. The innovation recursion has persistence 0.97; its implied
   long-run variance is 1. With Gaussian innovations its fourth-moment recursion
   coefficient is 0.9805, below 1. The nonlinear mean is not the AR(1) mean used
   by the fitted GJR comparator.
3. **Hidden regimes + nonlinear seasonal memory**: mean
   `0.35a+0.30 tanh(y[t-12])+0.55 sin(2 pi t/48)`, plus `0.20 sin(b)` in
   regime 1, or `-0.20 tanh(ab)+0.30 cos(2 pi t/24)` in regime 2. The SD is
   `0.22+0.08|tanh(a)|` in regime 1 and `0.85+0.30|tanh(a/2)|` in regime 2.
   Transition rows are `(0.98,0.02)` and `(0.05,0.95)`. Initial regimes use the
   stationary distribution `(5/7,2/7)`. Mean regime run lengths are 50 and 20
   observations, respectively. True simulated states are stored only for
   description: the known-DGP forecaster filters states from observed responses.

Independent random streams for Gaussian innovations, regime transitions and the
initial state ensure that requesting more future data cannot alter the history.
The generators are custom and include known clock effects; oracle performance
therefore includes a real information advantage over response-only DESNs.

## Models and forecasts

The existing 72-model bank crosses depth 1/2/3, width 20/50, lag length 5/30/90,
fast/slow reservoir profiles and seeds 11/29. Identity interlayer bridges,
intercept plus all reservoir layers, no direct response lags in the readout,
and the previous input transformations are unchanged. Priors assign equal mass
to each depth and then within depth. Readout slopes have independent Gaussian
ridge priors after division by sqrt(number of slopes); observation variance and
ridge precision are learned with the existing blocked Gibbs algorithm. See
`configuration.R` and `specifications.csv` for every fixed setting.

The Gaussian AutoDESN and fixed DESN are **homoscedastic models** in this study.
Their path distributions can vary with uncertain states, coefficients and model
specifications, but they do not learn a conditional innovation variance process.
This is a deliberate misspecification test of the existing implementation.

Comparators: prespecified depth-2/width-50/lag-90 fast DESN (seed 11), Gaussian
AR(1), Gaussian AR(12), intercept-only Gaussian regression, fitted AR(1)-GJR(1,1),
and the known-parameter DGP. The two-state oracle uses exact observation filtering;
Monte Carlo is used for its predictive trajectories. Gaussian AR and constant references use the shared
Normal regression posterior, whose scaled-ridge prior differs from AutoDESN's
independent ridge prior. The GJR comparator maximizes training-only conditional
Gaussian likelihood from three predetermined starts, selects the best converged
local optimum,
and omits parameter uncertainty. Its transform enforces positive variance
parameters and alpha+gamma/2+beta<0.995. The initial variance uses only the
500-observation prefix. These are predictive references, not a controlled
architecture-only ablation or a package leaderboard.

Three Gibbs chains start at distinct variance/precision values. The screen is
rank/folded split Rhat<=1.01, spectral ESS>=400, and maximum model probability
range across chains<=0.05. Failed screens trigger prespecified longer attempts
before any future scores are inspected: 2000+6000, 4000+16000, then 6000+32000
burn+retained sweeps per chain. All attempts are retained. These screens are
practical diagnostics, not proofs of convergence.

**Fixed origin:** AutoDESN and fixed DESN use 192 joint posterior draws, each
with 64 innovation trajectories
(12,288 paths), held fixed through all 100 leads. Each path feeds back its own
simulated response. The same standard-normal noise bank is used across fitted
comparators. Gaussian AR/constant references use one posterior parameter draw
per trajectory; the GJR reference holds one fitted parameter vector throughout.
This is a predictive comparison, not an equal-compute Monte Carlo comparison.
The oracle has its own seeded simulation, including sampled hidden
regimes. A nearly flat long-horizon mean can be appropriate for a short-memory
nonlinear process: it averages unpredictable future shocks rather than tracing
one realized path. The seasonal oracle additionally knows the clock effects.
This is forward Monte Carlo, not an SMC sampler: forecast paths are not
reweighted or resampled. A paired K=32/64/128 inner-path sensitivity is recorded for the first
prespecified case; it does not tune models or change the primary K=64 results.

**One step:** an additional evaluation of the same held-out observations.
Coefficients and model probabilities stay fixed at time 2500. Observation t is
fed back only after its one-step forecast is computed, and may inform forecasts
for t+1 onwards. The validation adapter delegates DESN state transitions to the
existing shared Normal forecast API and constructs fresh predictive samples;
forced observations returned by that API are never scored as forecasts. This
mode measures filtering/volatility tracking and is distinct from the 100-step
fixed-origin task. It does not update the coefficient posterior.

## Metrics and artifacts

Predictive means average conditional Gaussian component locations; predictive
quantiles pool trajectories using type 8. CRPS uses its exact empirical-sample
formula. Negative log scores average conditional Gaussian densities along
simulated paths using log-sum-exp. Predictive SD integrates innovation variance
and variation in conditional locations. Coverage/width at 50% and 90%, RMSE,
MAE, CRPS and density scores are exported for both forecast modes. Raw realized latent-
location errors are simulation diagnostics; those future locations are not
available at the fixed forecast origin and are not the marginal forecast target. Lower RMSE,
CRPS and negative log score are better; calibration must be assessed with width.

One-step volatility bins use the known-DGP predictive SD quartiles on **training
rows only**. Frozen boundaries classify test one-step SDs for post-hoc evaluation.
The hidden-regime oracle SD includes uncertainty in the regime, whereas the
simulator's realized innovation SD conditions on its hidden state. Neither is a
future volatility path available to the fixed-origin forecaster. Conditional
coverage groups can be small and serially dependent; do not interpret them as
formal coverage guarantees.

Artifacts retain all nine observed series, all 100 leads of each score, diagnostic
attempts, optimization starts/parameters, model probabilities, 64 complete
illustrative AutoDESN paths per case, outer-draw mean locations, and source hashes.
Do not treat paths, horizons, or overlapping evaluation modes as independent
experimental replications. With only three series per process, rankings are
descriptive; no superiority or calibration claim should be generalized.
