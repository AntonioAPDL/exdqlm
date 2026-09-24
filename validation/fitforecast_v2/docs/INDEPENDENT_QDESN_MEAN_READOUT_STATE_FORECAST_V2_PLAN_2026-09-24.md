# Independent Q-DESN mean-readout-state forecast v2

Status: superseded by
`INDEPENDENT_QDESN_MEAN_READOUT_STATE_FORECAST_V3_IMPLEMENTATION_BLUEPRINT_2026-09-24.md`;
no implementation or scientific run was launched from v2.

This plan supersedes
`INDEPENDENT_QDESN_MEAN_READOUT_STATE_FORECAST_V1_PLAN_2026-09-24.md`.
Version 2 explicitly covers both VB and MCMC, pools MCMC chains when forming the
mean state, freezes the distinction between response-predictive draws and
conditional-quantile draws, and defines how the score bands are reconstructed.

## 1. Decision in plain language

The advisor proposal is coherent and directly testable.

For each rolling forecast origin and lead, the Q-DESN will still generate a
posterior sample of possible future responses. Each response sample creates a
possible next input and therefore a possible reservoir/readout state. Instead
of pairing every coefficient draw with its own noisy reservoir trajectory, the
possible readout states are averaged into one common feature vector. Every
posterior coefficient draw is then applied to that common feature vector.

This separates two uncertainty channels:

1. predictive input/state uncertainty is integrated through the common mean
   readout state;
2. posterior uncertainty in the readout coefficients remains in the reported
   conditional-quantile draws.

The forecast is then advanced recursively by drawing the next response from
each conditional-quantile draw. The response draws are used to construct the
next lead's input ensemble. They are not used directly as the score samples.

This is a forecast-estimator change only. It does not change the data, DGP,
DESN winner, reservoir realization, likelihood, prior, `tau0`, MCMC budget, VB
approximation, or model-selection rule.

## 2. Exact terminology

Two objects must not be conflated.

- `yrep[s,o,h]`: a posterior predictive response draw. It propagates the
  recursive response lags and hence the future input distribution.
- `qdraw[s,o,h]`: a posterior draw of the target conditional quantile after the
  predictive input distribution has been summarized at the readout state. It
  is the object used to calculate forecast MAE and check loss.

The phrase "posterior predictive quantile sample" will be defined in code and
documentation as:

```text
a posterior conditional-quantile draw evaluated at a readout state obtained
by integrating the posterior-predictive recursive input ensemble.
```

This wording preserves the user's intended meaning while avoiding the false
claim that a response draw itself is a quantile draw.

## 3. Current estimator and proposed estimator

### 3.1 Current native recursion

At origin `o`, lead `h`, and posterior draw `s`, the current implementation
uses a fully draw-specific path:

```text
u[s,o,h]    = input from observed data and yrep[s,o,1:(h-1)]
H[s,o,h]    = F(H[s,o,h-1], u[s,o,h])
x[s,o,h]    = G(H[s,o,h], lag and input blocks)
q[s,o,h]    = x[s,o,h]' beta[s]
yrep[s,o,h] = draw_from_working_likelihood(q[s,o,h], sigma[s], gamma[s])
```

Thus the same posterior draw controls its coefficients, response history,
reservoir path, and future design. The score bands include all resulting
cross-origin and cross-lead dependence.

### 3.2 Proposed mean-readout-state recursion

The observed origin state is common. For lead `h`, each posterior-predictive
history first produces a candidate state from the common previous state:

```text
Hcand[s,o,h] = F(Hbar[o,h-1], u[s,o,h]).
```

For a deep reservoir this transition is evaluated layer by layer. Candidate
lower-layer states for draw `s` feed that draw's candidate higher-layer state,
while every layer begins from the corresponding common state at lead `h-1`.

The internal states are collapsed for the next recursion:

```text
Hbar[d,o,h] = mean_s Hcand[d,s,o,h].
```

Each candidate state is then converted to the exact readout feature used by
the fitted model. This includes:

- top-layer state;
- activated/projected lower-layer states;
- intercept;
- direct response/input lag features;
- exogenous features;
- reservoir-lag blocks;
- fitted linear transforms;
- fitted feature scaling.

The complete post-transform feature is averaged:

```text
xbar[o,h] = mean_s x[s,o,h].
```

Every posterior coefficient draw uses the same `xbar[o,h]`:

```text
qdraw[s,o,h] = xbar[o,h]' beta[s].
```

Finally, each draw generates a new response:

```text
yrep[s,o,h] = draw_from_working_likelihood(
  qdraw[s,o,h], sigma[s], gamma[s]
).
```

Those responses update the draw-specific histories used to form `u[s,o,h+1]`.
The common state `Hbar[o,h]`, rather than `Hcand[s,o,h]`, is carried to the next
reservoir transition.

### 3.3 Why the post-transform readout feature is averaged

The readout does not always use raw layer states. With nonlinear lower-layer
features,

```text
k(mean(H)) != mean(k(H)).
```

Therefore, averaging raw hidden states and then rebuilding the readout can
create a different estimator. The primary contract averages the complete
feature that multiplies `beta`. Layer-wise raw means are also retained for the
next state transition and for diagnostics.

## 4. VB and MCMC contracts

### 4.1 Variational Bayes

For every authoritative VB Q-DESN source:

1. reconstruct the frozen VB fit if no matching retained object exists;
2. draw the same declared number of samples from the fitted variational
   posterior, currently 10,000 for the article authority;
3. form the common readout state over that complete draw ensemble at every
   origin and lead;
4. retain all `qdraw` columns when calculating score draws;
5. label the resulting bands as approximate 95% posterior score intervals.

The VB implementation must support both AL-RHS and exAL-RHS. Under AL, gamma is
fixed by the reduced likelihood. Under exAL, the structured posterior draws of
gamma and sigma are retained in response generation exactly as fitted.

### 4.2 MCMC

For every authoritative MCMC Q-DESN forecast source:

1. reconstruct all three frozen chains;
2. retain chain identifiers and use equal retained counts per chain;
3. concatenate the chain-balanced posterior draws into one posterior ensemble;
4. calculate one common readout state from the pooled ensemble, not three
   unrelated chain-specific mean states;
5. apply every pooled coefficient draw to that common state;
6. calculate score draws while preserving each sample's chain identifier;
7. report pooled posterior bands and chain-specific sensitivity summaries.

Pooling before the state average is the preferred contract because the state
summary is intended to represent the complete posterior, while chain-specific
means are only Monte Carlo approximations to it. A chain-specific implementation
may be retained as a diagnostic, but it cannot silently become the article
estimator.

The pooled ensemble is expected to contain 12,000 draws for most current MCMC
roles. Any role with a different frozen retained count, such as a repeated
confirmation source, keeps its actual chain-balanced count and records it in
the manifest. Draw counts are never fabricated by duplication.

## 5. Score-draw and band construction

Let `G` denote the unchanged 1,000-row rolling-origin scoring grid. It covers
source indices 9001--10000 using 34 origins spaced by 30 observations and
maximum lead 30. Let `qstar[g]` be the known DGP target quantile and `y[g]` the
realized held-out observation.

For every posterior quantile draw `s`, calculate:

```text
forecast_MAE[s] = mean_g abs(qdraw[s,g] - qstar[g])

forecast_check[s] = mean_g rho_tau(y[g] - qdraw[s,g])

rho_tau(u) = u * (tau - I(u < 0)).
```

If forecast RMSE is retained as a diagnostic:

```text
forecast_RMSE[s] = sqrt(mean_g((qdraw[s,g] - qstar[g])^2)).
```

For each metric, report:

- posterior mean;
- posterior median;
- posterior standard deviation;
- 2.5% and 97.5% equal-tailed quantiles;
- number of posterior draws and MCMC chains;
- estimator identifier and recursion label.

The proposed identifiers are:

```text
recursion_mode = posterior_predictive_mean_readout_state
metric_estimator = mean_readout_state_quantile_draw_metric_equal_tailed_95cri_v1
```

The article figure marker remains the posterior mean of the draw-level score.
Its interval is the equal-tailed 95% interval of the draw-level score. The
posterior score interval is not produced by scoring `yrep`; `yrep` is only the
recursive-input mechanism.

The same posterior draw identity is followed across every scored origin and
lead before its metric is calculated. The mean readout state is formed
separately within each origin and lead; states are never averaged across
forecast origins. This preserves coherent posterior parameter uncertainty
without restoring draw-specific reservoir trajectories.

### 5.1 Point forecast metrics

For coherence with the existing Q-DESN point estimator, form the point
conditional-quantile path as the posterior median of `qdraw[s,g]` at each grid
row. Score that path once to obtain point forecast MAE and point check loss.

The following two values are generally different and must both be labeled:

```text
score(posterior_median_quantile_path)
mean_s(score(qdraw[s,]))
```

The first belongs in point-estimate tables. The second is the center shown in
the score-interval tables and figures.

### 5.2 Fit scores

The proposed recursion begins after the forecast origin, so it does not alter
fit-window quantile draws or fit RMSE. The new article projection should carry
forward the authoritative fit point estimates and fit bands with their exact
provenance.

During reconstruction, fit RMSE draws will be recalculated as a reproducibility
check. They must agree with the current authority within the predeclared replay
tolerance, but they are not automatically substituted merely because a fresh
Monte Carlo replay differs slightly.

## 6. Verified scope and minimum computation

The current v14 article authority contains:

- 18 Q-DESN VB rows: 2 likelihood variants x 3 families x 3 quantiles;
- 18 Q-DESN MCMC rows on the same surface;
- 18 distinct VB forecast source identities;
- 26 distinct MCMC forecast source identities because forecast MAE and check
  loss sometimes use different case-specific source specifications;
- 13 MCMC AL-RHS sources and 13 MCMC exAL-RHS sources.

The minimum complete replay is therefore:

| Work unit | Count | Reason |
|---|---:|---|
| MCMC frozen fit reconstructions | 78 | 26 source identities x 3 chains |
| MCMC pooled forecast evaluations | 26 | One pooled posterior per source |
| VB frozen fit reconstructions | 18 | One authoritative source per VB forecast role set |
| VB forecast evaluations | 18 | One variational posterior ensemble per source |
| DQLM/exDQLM fits | 0 | No reservoir recursion |
| New screening candidates | 0 | Winners remain frozen |

These counts must be regenerated from the current authority immediately before
materialization. The code must deduplicate a source used by both forecast
metrics so it is reconstructed only once.

## 7. Why reconstruction may still be necessary

A storage audit of the retained v10/v14 evidence found:

- 126 Q-DESN interval-replay job directories;
- all fit requests, configs, manifests, and scalar/path summaries;
- MCMC `theta_trace.csv` files that record update scheduling rather than beta
  samples;
- no retained MCMC beta matrices;
- no retained VB posterior coefficient objects;
- no Q-DESN fitted-model binary.

Therefore the forecasts cannot be regenerated from the score CSVs alone. The
scientific models are not being re-selected or recalibrated, but the frozen
fits may need to be rerun once to reconstruct the discarded posterior draws.

The recovery ladder is:

1. search again for a fit/posterior capsule matching source identity and hash;
2. reuse it only if every config, seed, package, and source hash agrees;
3. otherwise reproduce the exact frozen fit under its recorded fit environment;
4. immediately export a versioned forecast capsule containing only what the
   two forecast modes need;
5. run native and mean-readout-state forecasts from that same capsule;
6. remove the temporary full fit only after all hashes and outputs verify.

No source is rerun twice merely to obtain the two forecast modes.

## 8. Environment isolation

The implementation branch contains the latest package-main and shared
validation histories. That does not authorize changing the fitted posterior.

For each source, the fit-reconstruction environment is taken from its frozen
manifest. The new forecast helper acts as postprocessing on a neutral forecast
capsule. Native and mean-readout-state forecasts are generated from the same
capsule and pre-generated innovation arrays. This isolates the recursion change
from package, RNG, compiler, or sampler changes.

If a historical fit object cannot be loaded directly by current code, an
explicit converter will export the neutral capsule from the historical fit
environment. Silent schema coercion is forbidden.

## 9. Implementation surface

### 9.1 Package code

Modify `R/qdesn_vb.R` conservatively:

1. leave `posterior_predictive` unchanged;
2. leave `conditional_mean_plugin` unchanged as a diagnostic;
3. add `posterior_predictive_mean_readout_state`;
4. implement a dedicated R helper for ensemble state reduction;
5. explicitly disable the existing independent-draw C++ backend for the new
   mode until exact R/C++ parity is implemented and tested;
6. return `qdraw`, `yrep`, state/readout dispersion, chain ID, draw ID, origin,
   lead, and estimator metadata.

The first implementation should stream candidate states in draw chunks. At
each lead it accumulates layer and readout-feature sums, forms the common state,
then evaluates all beta draws. This avoids retaining a
`draw x layer x state x horizon` array.

### 9.2 Validation code

Add a self-contained independent-validation campaign with:

- authority/source ledger builder;
- fit-capsule materializer;
- paired native/new forecast worker;
- VB and pooled-MCMC aggregators;
- score-draw writer;
- read-only health reporter;
- closeout and promotion-candidate builders;
- artifact/hash verifier;
- ignored diagnostic PDF builder.

Existing v10/v14 evidence remains immutable.

## 10. Verification hierarchy

### Gate 1: unit and invariance tests

- one posterior draw: native and new recursion agree;
- lead one: native and new recursion agree under paired innovations;
- identical input histories: native and new recursion agree;
- draw-order permutation does not change the common state or readout feature;
- averaging occurs after nonlinear readout transformations;
- intercept, direct-input, reservoir-lag, decomposition, scaling, and linear
  transform blocks are all handled;
- no future observation or oracle value enters the forecast recursion;
- fixed seed and draw ordering reproduce exactly;
- odd/even split ensembles produce sufficiently close common states and score
  summaries, quantifying Monte Carlo error in the state average;
- existing native forecast tests remain unchanged.

### Gate 2: VB and MCMC smoke

Run four small but scientifically representative jobs:

- one wide VB exAL-RHS cell;
- its MCMC exAL-RHS counterpart;
- one VB AL-RHS control;
- its MCMC AL-RHS counterpart.

The smoke uses frozen source specifications and reduced forecast-draw counts,
not shortened scientific fits. It verifies API behavior, pooled-chain logic,
memory, runtime, score formulas, and artifact schemas.

### Gate 3: native replay equivalence

Before accepting a source capsule, its native forecast must reproduce the
retained source under the recorded tolerance for:

- point forecast MAE;
- point check loss;
- posterior score means;
- interval endpoints;
- origin/lead indexing;
- output scale.

Any mismatch is diagnosed as provenance, package, draw-selection, or RNG
drift. Tolerances are not widened after seeing the result.

### Gate 4: full paired campaign

Run all 18 VB and 26 pooled-MCMC forecast sources. Every result must be finite
and complete. Partial surfaces cannot enter the article.

### Gate 5: scientific interpretation

Compare native and mean-readout-state recursion using:

- interval width and center;
- point forecast MAE/check loss;
- DGP-oracle distance;
- lead and origin profiles;
- origin-by-lead heatmaps;
- state/readout dispersion by lead;
- chain-specific MCMC sensitivity;
- VB-versus-MCMC agreement.

Narrower bands alone do not prove a better forecast. The new method should
reduce state-path-driven dispersion without producing material bias or poor
check loss.

## 11. Article decision rule

The recursion estimator is a common methodological contract, not another
case-specific tuning parameter. Therefore:

- DESN specifications and `tau0` remain family/quantile/likelihood specific;
- the forecast recursion must not be selected cell-by-cell according to which
  gives a smaller score or narrower interval;
- if the advisor estimator is accepted, it replaces the full Q-DESN VB and
  MCMC forecast surface;
- if it fails the scientific gates, the full native Q-DESN surface remains;
- DQLM/exDQLM and all fit metrics remain unchanged.

The integration candidate will include:

- regenerated VB and MCMC Q-DESN point forecast values;
- regenerated posterior score means and 95% bands;
- complete family/quantile tables;
- updated interval figures with the posterior mean marker;
- estimator-specific prose and supplement definition;
- native-versus-new diagnostic figures kept in the evidence packet;
- unchanged DQLM/exDQLM and fit values copied with hashes.

Article-v2 and Overleaf remain coordinator-owned. This lane only produces a
clean, tested, hashed handoff.

## 12. Storage and reproducibility

Retain:

- source/config/seed/environment manifests;
- compact posterior forecast capsules while the audit remains active;
- score draws in compressed tabular form;
- point paths and origin/lead summaries;
- state/readout dispersion summaries;
- tests, closeout ledgers, hashes, and integration handoff.

Do not retain:

- duplicate full fitted-model binaries after capsule verification;
- full candidate-state arrays;
- duplicate native forecast matrices already represented by verified compact
  score/path artifacts;
- smoke outputs after their hashes and conclusions enter the closeout.

Cleanup is allowed only after the campaign is terminal and the retained bundle
can independently regenerate every table and figure.

## 13. Recommended execution order

1. Freeze and hash the v14 source-role ledger.
2. Implement the R mean-readout-state recursion and capsule schema.
3. Pass unit/invariance tests.
4. Run the four-mode VB/MCMC smoke.
5. Prove native replay equivalence on the smoke sources.
6. Materialize the 78 MCMC chain reconstructions and 18 VB reconstructions.
7. Build 26 pooled-MCMC and 18 VB paired forecast outputs.
8. Recompute posterior quantile score draws and 95% bands.
9. Build the full diagnostic packet and scientific closeout.
10. Produce article-ready assets only after the estimator decision is frozen.
11. Commit and push the dedicated lane branch.
12. Hand off to the integration coordinator; do not merge main or Overleaf in
    this lane.

## 14. Final recommendation

Proceed with implementation of this v2 plan. It exactly addresses the advisor
request for both VB and MCMC and creates the score bands from posterior
conditional-quantile samples under a posterior-predictive mean-state recursion.
It avoids another screening campaign, preserves all case-specific winners, and
isolates the forecast-estimator change through paired native/new forecasts.

No expensive launch should begin until the implementation, four-mode smoke,
and native-replay equivalence gates pass.
