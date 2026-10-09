# Independent Q-DESN Rolling-Readout Validation v4

## Scientific question

The exact-M0 finalist campaign established that causal readout refitting helps the
frozen exAL Q-DESN sentinel, but its performance is temporally unstable and does
not consistently close the exDQLM forecast-MAE gap. The strongest finalist,
`3a7a6653cb244f49813c`, improves most strongly after 200 new observations and
remains poor in later folds. This campaign tests the narrow causal hypothesis
that stale readout rows, rather than insufficient static reservoir capacity,
cause the remaining gap.

This is not another architecture screen. The reservoir, feature map, source
trajectory, preprocessing, likelihood, exact-M0 sampler, horizon, priors other
than the dimension-aware RHS global scale, and comparator evidence are frozen.

## Frozen candidate and estimand

The sole candidate has depth 5, layer widths `36;38;29;20;20`, 143 reservoir
states, 240 output lags, leakage 0.1630299, spectral radius 0.9987975, and an
intercept-plus-reservoir readout of dimension 144. The evaluation remains an
internal temporal validation experiment on folds S1--S4. Forecasts are
teacher-forced when the origin advances and recursively generated for 30 steps
within each origin. Source indices 9001--10000 remain sealed.

The reservoir state at an origin retains all causally admissible earlier input
history. A rolling readout therefore limits the likelihood rows used to estimate
the coefficients; it does not erase older information already summarized by the
reservoir state. This distinction is recorded explicitly in every configuration
and diagnostic record.

## Readout policies

The existing expanding refit with its fixed N=1000 global scale is imported as
the anchor. Five new exact-M0 policies are evaluated:

| Policy | Readout rows through the origin | RHS scale |
|---|---|---|
| `expanding_calibrated` | all rows from the base-fold training start | recalibrated for effective N |
| `rolling_1000` | latest 1000 rows | recalibrated for N=1000 |
| `rolling_750` | latest 750 rows | recalibrated for N=750 |
| `rolling_500` | latest 500 rows | recalibrated for N=500 |
| `rolling_250` | latest 250 rows | recalibrated for N=250 |

For 143 shrinkable coefficients, effective sparsity 8, and frozen source-scale
sigma 19.34568, the source-unit global scale is

`tau0(N) = 8 / (143 - 8) * 19.34568 / sqrt(N)`.

This preserves the intended RHS sparsity calibration as the readout sample size
changes. The intercept remains unshrunk. Slab scale, reservoir matrices,
preprocessing, and all other priors remain fixed, preventing the window test
from becoming an uninterpretable prior or architecture screen.

## Staged protocol

1. **Screen:** five new policies x four folds x offsets 50, 125, and 200,
   yielding 60 one-chain fits. The imported expanding-fixed policy is ranked as
   an anchor. A new policy advances only if it beats that anchor, has median
   adapted/exDQLM forecast-MAE ratio below 1.05, and wins at least 6 of 12 cells.
2. **Disjoint-origin validation:** the selected policy is evaluated at offsets
   25, 75, 150, and 220 in each fold, yielding 16 one-chain fits. These origins
   were not used in the screen and their 30-step target windows do not overlap
   within a fold. Advancement requires median adapted/exDQLM forecast-MAE ratio
   below 1 and at least 9 of 16 wins.
3. **Repeated-chain confirmation:** chains 2 and 3 are added only for the 16
   validation cells. The three-chain mean must satisfy the same validation
   rule. At most 108 new fits can run.

Forecast MAE is the selection criterion. Forecast check loss, fit RMSE,
chain-level spread, nuisance ESS, and first-step guards are retained for
interpretation. Finite outputs, exact method identity, causal boundaries,
hashes, and first-step equivalence are hard implementation requirements;
diagnostic grades do not veto a predictive improvement.

## Stop rules and interpretation

No stage opens the article test block or changes the article. Failure at the
screen stops further exact MCMC work and rejects local windowing. Failure on
the disjoint origins or repeated chains rejects the apparent screen gain. A
confirmed internal gain freezes a protocol for fresh-DGP confirmation; it is
not automatically promoted.

If no rolling policy succeeds, the next justified intervention is an explicit
time-varying readout. More static-reservoir screening, intercept shrinkage, or
additional window sizes would not address the temporal instability identified
by the v3 evidence.

## Reproducibility and storage

The production run pins source, package, parent evidence, configurations,
seeds, and all generated summaries with SHA-256 manifests. Each worker uses one
physical core and single-threaded numerical libraries. Up to 15 workers run in
parallel with RAM and CPU-idleness checks. No fitted-model `.rds`, `.rda`, or
`.RData` payloads are retained.
