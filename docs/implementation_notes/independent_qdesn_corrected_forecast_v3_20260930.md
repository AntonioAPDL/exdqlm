# Independent Q-DESN Corrected Forecast v3

Date: 2026-09-30

Scientific lane: independent single-quantile Q-DESN/DQLM validation

Status: implemented behind a mandatory forecast-operator canary gate

## Decision

The prior cellwise-refinement campaign is diagnostic evidence, not the next
production path. Its Normal representation screens completed successfully, but
the quantile bridge selected candidates using a recursive conditional-location
plug-in. That object is not generally the marginal multi-step predictive
quantile of a nonlinear autoregressive reservoir. The old scheduler is closed
before its broad MCMC stage and the campaign is labeled
`SUPERSEDED_BY_CORRECTED_FORECAST_ESTIMAND_V3`.

The corrected campaign does not begin with another architecture expansion. It
first establishes that the forecast operator, score estimand, and internal
rolling-origin selection target are scientifically valid. Only a passing
canary can unlock broader screening.

The temporal-design audit also used the server-shared review copy of
`Forecasting Without Data Leakage` (SHA-256
`292193f1330b66f2f88b21ca5d0bc115e27b2a2bd3f65e15a86c754434200d68`).
It is methodological evidence, not a runtime dependency. The implemented
consequences are an origin-defined information contract, preprocessing fitted
only on admissible history, recursive fixed-origin paths, teacher forcing only
between issue times, an internal development forecast surface, and a frozen
future confirmation procedure.

## Preserved scientific contract

- Families: Gaussian, Laplace, and Gaussian mixture.
- Quantile levels: 0.05, 0.25, and 0.50.
- Models tuned here: Q-DESN AL-RHS and Q-DESN exAL-RHS.
- Within-likelihood comparators: DQLM and exDQLM.
- Fit window: 8501:9000.
- Legacy compatibility window: 9001:10000.
- Forecast horizon: 30.
- A new rolling origin is teacher-forced with all outcomes observed through
  that origin.
- Within one origin, all unknown future response lags are generated
  recursively; future observations are never inserted.
- The model is not refitted at each origin.
- The readout contains an intercept and every reservoir layer only.
- Direct response lags, exogenous lags, and reservoir lags are excluded from
  the readout.
- `mx=0` for this simulation.
- Every interlayer projection is the exact identity; dimensionality reduction
  is forbidden.
- Reservoir activation is `tanh`; the lower-state readout activation is the
  identity.
- exAL MCMC uses `m0_v_collapsed_support_logit`.
- Selection is family-, quantile-, and likelihood-specific. No global DESN
  specification is sought.

### Training-only response transport

The source trajectories are not numerically centered near zero: for example,
the Normal p=0.50 internal fitting prefix has a response mean near 196. A real
prelaunch smoke found that raw-scale AL-VB readout fitting produced state
coefficients and fitted quantiles hundreds of units away from the data,
regardless of whether `tau0` was approximately 0.064, 1, or 100. The preceding
Normal reservoir readout remained finite, identifying the quantile-readout
scale transition rather than reservoir dynamics as the failure.

Every corrected fit therefore applies one positive affine response transport,
estimated only on that fold's fitting rows: `(y - mean_train) / sd_train`.
The complete admissible history is transformed with those frozen values,
including reservoir warm-up and recursive forecasts. All fitted and forecast
quantiles are mapped back to source units before any metric is computed. This
does not redefine the estimand: quantiles are equivariant under a positive
affine map. It is also not a second use of future data, an intercept
recalibration, or an article-scale change. The transport parameters and their
fitting boundary are retained in each result.

## Corrected forecast estimands

For posterior parameter draw `theta_j`, draw `theta_j` once and hold it fixed
for all 30 leads of one recursive path. Generate `K` innovation paths. The
implementation exposes four different summaries rather than silently treating
them as interchangeable:

1. `conditional_location_plugin`: propagate the conditional location with
   innovations set to zero.
2. `mean_conditional_location`: average the conditional-location path over the
   `K` recursive innovation paths for each `theta_j`.
3. `mean_readout_state`: average the complete candidate readout state over
   paths for each `theta_j`, then apply that draw's coefficients.
4. `posterior_predictive_quantile_pooled`: at each origin and lead, take the
   requested empirical quantile over the pooled outer-draw and inner-path
   posterior predictive outcomes.

The first three estimate an oracle-location trajectory and are scored against
the known simulated `q_target`. The fourth estimates a marginal predictive
quantile and is scored by check loss against realized observations. A
draw-specific predictive quantile is retained for posterior score summaries,
but its mean score is not conflated with the score of the pooled posterior
predictive quantile.

Three uncertainty layers are kept distinct:

- posterior parameter-draw intervals;
- forecast-origin block intervals, retaining each origin's complete lead
  vector;
- fresh-DGP replicate intervals in the eventual frozen confirmation.

## Why this precedes more architecture tuning

The superseded campaign already covered depths through 5, response lags
through 360, total state dimensions through 2400, alpha through 0.99, rho
through 0.999, and broad input/topology controls. Its first completed MCMC
pilot was finite but scientifically poor: Normal/AL at p=0.05 had forecast
oracle MAE approximately 19.27. This does not support spending another 168
pilot chains on the same funnel.

The earlier Normal ridge screen also found better internal forecast
representations than Normal RHS in every family. In particular, the Laplace
median internal forecast MAE was about 1.55 under ridge versus 11.79 under RHS.
The corrected design therefore separates reservoir representation discovery
from final quantile-readout shrinkage. A ridge-discovered representation may be
refit with AL-RHS or exAL-RHS; it is not discarded merely because its Normal
readout prior differed.

## Shrinkage policy

`tau0` remains case-specific and structure-matched. On the source scale, the
reference value is

```text
tau0_ref = p0 / (p - p0) * sigma / sqrt(n_eff),
```

where `p` is the number of shrinkable readout coefficients, the intercept is
excluded, and `p0` is a predeclared effective nonzero count. This formula is
consistent with the implemented half-Cauchy global scale, but it is only a
reference coordinate. Since the corrected fit uses a standardized response,
every source-scale `tau0` is divided by the training response SD before it is
passed to the model. Historical values therefore retain their source-unit
meaning without silently becoming 19--25 times broader merely because the
numerical parameterization changed.

The canary uses three deliberately different standardized coordinates: the
dimension-aware reference, a source-equivalent historical continuity value,
and the source-equivalent high sentinel `100 / sd_train`. This replaces an
initially considered narrow
`tau0_ref * {0.1,1,10}` canary: a real dry job showed that such a design would
concentrate around a raw-scale `tau0` near 0.06 even though the completed
matched screens frequently selected `100`. A later local refinement can use
`{1/30, 1/10, 1/3, 1, 3, 10, 30}` around a supported center plus sparse absolute sentinels
source-scale `{3e-9, 1e-6, 1e-4, 1e-2, 1, 100}`, converting each value to the
standardized model scale. It does not cross every value with every
structure. The RHS state is cold across `tau0` arms so initialization does not
confound the comparison. `s2=1` and an unshrunk intercept stay fixed unless a
specific coefficient/slab or common-shift diagnostic justifies opening them.

## Gated execution

### Gate 0: predecessor closeout

- Allow only already-running atomic canaries to finish.
- Block all remaining predecessor MCMC jobs.
- Verify every retained config, result, status, and hash.
- Store compact CSV/JSON/log evidence only.
- Promote no article result.

### Gate 1: forecast-kernel contract

Required tests cover:

- the analytic Gaussian AR(1) distinction between recursively substituted
  one-step quantiles and marginal multi-step quantiles;
- future-value replacement within an origin;
- teacher forcing between origins;
- one parameter draw held across all leads of a path;
- paired inner-path innovations and nested `K` subsets;
- posterior predictive pooling versus averaging draw-specific quantiles;
- exact seed replay within `1e-6`;
- identity projections and fold-local preprocessing;
- separately labeled posterior and origin-block score uncertainty.

### Gate 2: bounded p=0.50 canary

For each family and likelihood, compare four representation roles:

- best ridge-discovered structure;
- best RHS-discovered structure;
- current authority anchor where its full specification is recoverable;
- compact transparent control.

Each matched structure receives the three predeclared reference, continuity,
and high-sentinel `tau0` arms.
The six operator smokes use the dimension-aware reference arm; the absolute
high arm remains in the full 72-job canary rather than being mistaken for a
universally stable default.
The ceiling is 72 atomic VB fits. The canary starts with 16 outer draws and 128
inner paths, then checks `K` in `{64,128,256,512}` on finalists. It may not
unlock broad screening unless paths are finite, the causal contract passes,
Monte Carlo ranking is stable, and at least one structure avoids catastrophic
quantile-bridge degradation in every family-by-likelihood cell. Catastrophic
is operationalized before launch: the best corrected mean-location oracle MAE
in a cell must be no more than five times the constant training empirical-
quantile benchmark on the identical origin/lead lattice. This intentionally
loose guard rejects broken forecast funnels without pretending that the
bounded canary has already solved model selection.

### Gate 3: nonrepeating broad screen

Only after a passing canary, construct a signature-deduplicated pool from
ridge winners, RHS winners, authority anchors, and a small deterministic
boundary-balanced unseen arm. The allowed support remains broad:

- depth 1:5;
- widths 20:800 and total states 20:2400;
- response lags 30:360 over the frozen discrete grid;
- alpha 0.01:0.99, deliberately including values above 0.4;
- rho 0.20:0.999;
- input gain 0.01:3;
- mean/SD and median/MAD scaling;
- unbounded and `tanh(z/3)` inputs;
- sparse-to-dense exact-fanin topology.

Candidates use internal rolling-origin H=30 forecasts ending no later than
9000. A coarse origin stride of 5 is permitted for the broad screen; finalists
must be rescored at stride 1. Fit metrics are diagnostics and tie-breakers, not
the primary selection target.

### Gate 4: direct staged MCMC

VB is a filter, not assumed to be a faithful MCMC rank proxy. At most three
diverse candidates per unresolved cell receive one short chain. Only the best
finite forecast candidate receives three full chains. Imperfect mixing is
reported but does not veto a finite score improvement unless it exposes a hard
invalidity such as leakage, corruption, or nonfinite output.

### Gate 5: compatibility and fresh confirmation

The 9001:10000 block is now a legacy compatibility benchmark because prior
development inspected it repeatedly. After the protocol is frozen, evaluate
it once for continuity and run fresh DGP replicates for the strongest unbiased
confirmation. DGP replicate, not posterior draw or reservoir seed, is the
independent uncertainty unit for population-level claims.

## Compute and storage limits

The protocol stores ceilings rather than quotas:

- 72 canary VB fits;
- 72 new Normal representation jobs;
- 288 broad quantile VB fits;
- 96 adaptive VB fits;
- 54 short MCMC chains;
- 54 full confirmation chains.

Every stage is resumable by atomic status. Workers use one thread each. Fitted
model binaries are not retained; compact metric draws, origin/lead summaries,
manifests, hashes, configs, and logs are retained.

Production materialization requires a clean committed worktree. Resume skips
a successful job only after rechecking its config hash and every retained
artifact hash; a stale or incomplete status is rerun atomically.

Workers load this worktree's `exdqlm` 1.1.1 source explicitly and verify both
the source and loaded runtime version before fitting. The system library's
version is recorded as launcher context only; it is not the worker runtime and
cannot silently replace the pinned source.

## Integration boundary

This branch may contain validation code, configuration, tests, and compact
evidence. It must not edit Article-v2 main, shared-validation authority,
Overleaf, joint validation, PriceFM, or GloFAS. Article changes can occur only
after a complete frozen comparison and coordinator integration.
