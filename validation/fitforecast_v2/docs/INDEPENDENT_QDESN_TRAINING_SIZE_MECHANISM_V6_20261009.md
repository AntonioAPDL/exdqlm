# Independent Q-DESN training-size mechanism campaign v6

## Scientific question

The coherent 1,000-observation study shows that Q-DESN forecast error is driven
primarily by biased or insufficiently responsive location paths, not by ordinary
posterior-band width or between-chain variation. Previous reservoir sweeps,
M0 exAL sampling, future-lag replay, rolling readouts, and dynamic readouts did
not establish a general rescue. This campaign therefore tests mechanisms before
another article-scale screen.

The primary sentinel is Normal/exAL at p=0.05. Laplace/exAL at p=0.05 and
Gaussian-mixture/AL at p=0.05 are controls for likelihood and family effects.
All selection is confined to source indices at or before 8,740. Source indices
9,001--10,000 remain unopened and cannot affect selection.

## Fixed contract

- Training sizes: 500, 1,000, 2,000, and 5,000.
- Four blocked internal folds ending at 7,000, 7,500, 8,000, and 8,500.
- A 500-observation washout precedes every training window.
- Forecast origins are teacher forced when the origin moves.
- Each origin produces a recursive 30-step path.
- Readout is intercept plus every reservoir layer; direct input lags are absent.
- All layer-transition Q matrices are identities.
- Reservoir recurrence uses tanh. Layer-projection Q matrices are identities, so
  the configured identity projection activation introduces no dimension reduction.
- Reservoir and design seed is fixed at 920001.
- exdqlm is the CRAN 1.1.2 build in the frozen runtime library.
- exAL MCMC uses M0; AL fixes gamma and uses the AL transition.
- Diagnostic grades are reported but are not metric-exclusion rules.

## Candidate panel

Each cell receives its current N=1,000 anchor, five structurally diverse prior
sentinel candidates, and four deliberate high-capacity probes. The probes reach
depth six, 2,400 total states, and 500 output lags. This is not another random
global search: it is a fixed panel spanning the historical winners and capacity
regimes that can distinguish insufficient representation from estimator failure.

## Stages and gates

1. **Smoke**: one deterministic oracle-ridge job and one 5,000-row matched exAL
   VB job verify indexing, package, memory, and high-N execution.
2. **Representation**: two folds cross cell, training size, fixed architecture,
   oracle-quantile ridge, Gaussian ridge, and Gaussian RHS. Oracle teacher-forced
   error measures whether the feature map contains the target path; recursive
   errors quantify transfer failure.
3. **Matched quantile VB**: three Pareto structures per cell and training size
   are crossed with N-adjusted tau multipliers 0.1, 0.3, 1, and 3. Selection uses
   internal rolling-origin forecast MAE, then check loss.
4. **Four-fold validation**: the best two configurations per cell are evaluated
   on all internal folds against matched DQLM/exDQLM VB comparators.
5. **Rolling readout probe**: only cells still more than 5% behind receive exact
   readout refits at three origins, two folds, and windows 500, 1,000, and 2,000.
   This isolates stale-readout behavior without reopening broad architecture
   search.
6. **MCMC confirmation**: the best static configuration per cell and its matched
   DQLM/exDQLM comparator receive three chains on folds S2 and S4. No article
   result is changed by this diagnostic campaign.

The closeout recommends a full 18-cell confirmation only when every sentinel or
control Q-DESN mean forecast-MAE ratio is at most 1.10. Otherwise the campaign
closes as diagnostic-only and identifies which mechanism failed.

## Execution and storage

The scheduler uses one R process per physical core, one numerical thread per
process, and at most 30 of 32 physical cores. It stops scheduling below 64 GiB
available memory. Every config, plan, source, package tree, and result packet is
hashed. Evidence contains CSV/JSON only; fitted-model RDS/RData payloads are
forbidden. A `STOP_NEW_SCHEDULING` file causes a clean drain.

## Interpretation

- Low oracle error but poor Gaussian and quantile recursion implicates temporal
  transfer or likelihood/readout estimation, not reservoir capacity.
- Oracle improvement with training size implicates sample support.
- Oracle failure even for large candidates supports a representation redesign.
- Matched quantile VB improvement after Gaussian screening confirms that Normal
  screening is useful only as a proposal generator, never as the final selector.
- A rolling-readout gain localizes stale coefficients; no gain rules out another
  costly adaptation campaign for this protocol.
