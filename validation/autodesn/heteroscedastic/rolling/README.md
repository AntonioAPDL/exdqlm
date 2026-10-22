# Primary experiment: rolling-origin 30-step forecasts

This is the rolling evaluation requested after the original fixed-origin run.
It follows the [corrected Q-DESN protocol](../../../../docs/implementation_notes/independent_qdesn_corrected_forecast_v3_20260930.md):
**observed feedback between origins, recursive simulated feedback within each
origin, and no refitting at each origin**.

The posterior, architecture probabilities and response/input preprocessing are
fitted once with 500 washout observations (1:500) and 2,000 likelihood rows
(501:2500). Reservoir weights and interlayer identity bridges remain fixed.
There are 71 complete origins, 2500:2570, each with leads 1:30 inside the same
100-observation test block (2501:2600).

| Issue time | Observed values available | Forecast targets | Within-forecast feedback |
|---|---|---|---|
| 2500 | 1:2500 | 2501:2530 | Simulated responses |
| 2501 | 1:2501 | 2502:2531 | Simulated responses |
| 2570 | 1:2570 | 2571:2600 | Simulated responses |

Observation 2501 may update the state before the forecast issued at 2501. It
never enters the forecast issued at 2500. A 30-step-ahead plotted prediction
for target 2531 was issued at 2501, even though predictions are displayed at
consecutive target times. Forecasts issued at different origins are scored
separately; their paths are never pooled into one target distribution.

All three custom heteroscedastic DGPs, three independent series per DGP, the
72-candidate bank, priors and initial fit window are unchanged. The Gaussian
AutoDESN retains constant innovation variance and an independent Gaussian ridge
prior. The [earlier fixed-origin/one-step results](../RESULTS.md) remain separate
diagnostics. The rolling protocol was specified after those earlier results;
no DGP, candidate, prior or estimator was tuned on the rolling scores.

## State updates and reuse

The validation adapter calls the existing Normal forecast transition for both
recursive forecasts and observed state updates. For an observed update it asks
for a one-step design row with observed feedback. Under this experiment's
identity bridges and identity lower-layer readout, that row contains every
layer state: intercept, last layer, then lower layers. Recovering these states
avoids duplicating the reservoir transition. Tests compare every recovered
layer to the shared feature builder, including a three-layer fixture.

`hr_checkpoint()` supports this identity/all-layer readout contract explicitly;
it rejects other bridges/readout activations. It saves only selected joint
posterior draws, reservoir matrices, terminal states, frozen preprocessing and
diagnostics. It is a validation forecast checkpoint, not a complete fitted
object for training-design diagnostics or further Gibbs sampling. Checkpoints
allow horizon/origin replays without repeating inference. They are small RDS
files; complete MCMC chains and feature-bank binaries are not retained.

The first rolling execution replays the exact final seeds and diagnostic-selected
sampler durations of the earlier experiment. Posterior model probabilities and
sampled first-origin paths are checked against the earlier frozen evidence.
Earlier failed mixing attempts remain in the parent experiment's ledger.

## Monte Carlo and comparators

Each DESN origin uses 192 joint posterior draws, each repeated over 16 innovation
paths: 3,072 trajectories. A joint model/coefficient/variance draw is fixed for
all 30 leads and reused across origins. A fixed K=8/16/32 sensitivity is recorded
at the first origin of every case. The first origin uses a subset of the earlier
100-step innovation bank for an exact numerical replay. All predictive quantiles
pool paths using type 8, and means average Gaussian component locations.

The same seven methods are scored: AutoDESN, fixed DESN, Gaussian AR(1), Gaussian
AR(12), constant regression, AR(1)-GJR-GARCH, and a known-parameter DGP reference.
All fitted parameters remain frozen at time 2500. GJR volatility and hidden-DGP
state probabilities update from observations between origins. The oracle uses
observed-history filtering, never true simulated hidden states or outcomes
within its unknown forecast horizon. It knows DGP parameters and clock effects.
The fitted GJR comparator omits parameter uncertainty. AR references use their
shared Normal scaled-ridge posterior, which differs from AutoDESN's independent
ridge prior.

Scores are averaged over origin/lead pairs with equal weights. Per-lead results
use the same 71 origins and three series. The 2,130 origin/lead pairs per series
reuse 100 held-out observations; they are serially dependent and overlapping.
There are three independent series per DGP, not thousands of independent test
sets. Comparisons are descriptive implementation/stress tests, not a public
leaderboard or a controlled estimate of the effect of training-set size.

## Reproduction

Run from the repository root with package dependencies and Python numpy/pandas/
matplotlib installed. For a fresh output choose an unused directory:

```sh
export AUTODESN_ROLLING_OUT=/tmp/autodesn_rolling_reproduction
Rscript validation/autodesn/heteroscedastic/rolling/test_contracts.R
Rscript validation/autodesn/heteroscedastic/rolling/init.R
AUTODESN_RSCRIPT=Rscript python validation/autodesn/heteroscedastic/rolling/run_cases.py
Rscript validation/autodesn/heteroscedastic/rolling/verify_checkpoints.R
python validation/autodesn/heteroscedastic/rolling/summarize_audit.py
python validation/autodesn/heteroscedastic/rolling/plot_results.py
python validation/autodesn/heteroscedastic/rolling/write_results.py
```

The coordinator runs at most two independent R cases at once; each fit uses
three serial chains. After large training arrays are released, each case scores
origins with two fork workers and explicit noise seeds. BLAS/OpenMP threads are
limited to one. On Windows replace the origin `mclapply` with serial `lapply`;
this recorded execution uses Unix. The coordinator resumes saved checkpoints
and skips completed cases. Frozen initialization cannot overwrite an existing
configuration. Set `AUTODESN_RSCRIPT` to the desired Rscript executable.

Compressed per-case raw scores retain every origin/lead, intervals, errors,
CRPS and Gaussian-mixture log scores. Checkpoints, sampler diagnostics, compact
path examples, first-origin replay evidence, source hashes, summaries and plots
are included. The main figure shows **exactly 30-step-ahead** rolling predictions;
a separate fan plot shows five prespecified issue times. All 71 origins are
scored even when only five are displayed.
