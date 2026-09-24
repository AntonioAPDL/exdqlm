# Independent Q-DESN RHS variance attribution and run recovery

Status: implementation-ready recovery applied in the dedicated IND validation
lane. Prior retuning remains a subsequent, evidence-gated experiment.

## 1. Questions and decisions

This audit separates three questions that must not be conflated:

1. Did the mean-readout-state campaign stop because a model fit failed?
2. Does the intercept explain most posterior quantile and score variability?
3. Would reducing `tau0` or `s2` impose the intended regularization?

The answers are:

- the stopped job completed its fit and exports; an isolated chain-level
  interval-endpoint compatibility check stopped orchestration;
- current evidence identifies the intercept as an important location signal,
  especially for Gaussian `p = 0.05` exAL, but does not identify a majority
  variance share; and
- `tau0` and the RHS-NS slab exclude the intercept, while `s2` is principally
  an initializer when `zeta2` is learned. Lowering `s2` alone is therefore not
  the persistent slab intervention implied by the scientific question.

The immediate action is to repair and complete the frozen recursion campaign.
No prior is changed in that campaign. A later regularization experiment is
allowed only after coefficient-block variance attribution is available.

## 2. Current run diagnosis

Production root:

```text
reports/shared_fitforecast_v2_orchestration/
  independent_mean_readout_state_forecast_v1_20260924_145807
```

At diagnosis, 55 of 96 fits and 19 of 46 forecast evaluations were successful.
One fit status was failed and no campaign process remained active. The failed
job was:

```text
fit__imi_v1_source_079__c02
```

It completed the package pipeline, metric exports, basis capsule, and posterior
capsule. Both metric comparisons passed the finite-row, mean, familywise KS,
and interval-overlap checks. Their endpoint-width ratios were approximately
`0.1022` and `0.1865`, above the frozen per-chain threshold of `0.10`.

The final scientific source for MCMC is the balanced three-chain pool. Pooling
all 12,000 fresh and 12,000 authority draws for source 079 gives:

| Metric | Relative mean difference | KS / limit | Endpoint/width | Overlap | Result |
|---|---:|---:|---:|---:|---|
| Forecast MAE | 0.01355 | 0.01550 / 0.03005 | 0.05017 | 1.00000 | Pass |
| Forecast check loss | 0.00156 | 0.02417 / 0.03023 | 0.07230 | 0.99607 | Pass |

Repeating the deterministic chain would reproduce the same endpoint sample.
Relaxing the global threshold would weaken all 192 frozen comparisons. Neither
is justified.

## 3. Recovery contract

The recovery keeps every numerical threshold unchanged.

1. Every fit retains its complete chain-level compatibility ledger.
2. A strict chain pass proceeds unchanged.
3. An MCMC chain that passes row, finite, mean, KS, and overlap checks but
   misses only the endpoint check may proceed with
   `mcmc_endpoint_review_pending_source_pool`.
4. VB cannot use this exception because it has no independent chain pool.
5. Before candidate forecasting, the worker balances the retained positions
   across chains, applies the same indices to the fresh and historical draws,
   and requires the pooled source to pass every original compatibility check,
   including the unchanged endpoint threshold.
6. Closeout and independent verification require all fit decisions to be
   admissible and every forecast-level source pool to pass strictly.
7. Core incompatibility in the mean, empirical distribution, finite contract,
   or overlap remains terminal.

The existing frozen manifest is amended rather than silently overwritten. Its
original JSON and artifact ledger are archived, changed runtime hashes and the
recovery commit are recorded, and final verification checks both generations.

## 4. What the prior parameters actually control

For RHS-NS, the intercept is intentionally outside the active shrinkage set.
Its prior precision is `intercept_prec`; the present campaign uses `1e-10`, an
effectively diffuse prior on the standardized response scale.

For non-intercept coefficients, the effective conditional precision includes
the local/global horseshoe term and the regularized slab term. Lower `tau0`
increases global shrinkage. With learned `zeta2`, however, `s2` initializes the
slab state; subsequent MCMC and VB updates are controlled by `a_zeta`,
`b_zeta`, and the fitted coefficients. A persistent smaller slab requires
either a deliberately calibrated `a_zeta`/`b_zeta` prior or an explicit
`zeta2_fixed` (`c2_fixed`) experiment.

Consequences:

- lowering `tau0` cannot directly reduce intercept uncertainty;
- lowering `s2` alone is not a reliable persistent slab restriction;
- setting the intercept to zero is stronger than the available evidence;
- increasing `intercept_prec` is the direct, testable intercept intervention;
  and
- global and slab shrinkage should be tuned only if reservoir/readout blocks,
  rather than the intercept, dominate the posterior quantile variance.

## 5. Existing evidence about the intercept

The earlier origin/horizon audit found, for Gaussian `p = 0.05`:

- AL: Spearman correlation between `beta_intercept` and draw-level forecast MAE
  was about `0.147`, while the strongest reported RHS hyperparameter signal was
  much smaller in absolute magnitude;
- exAL: the intercept correlation was about `0.581` and remained above `0.547`
  in absolute value in every chain, while `tau`, `c2`, and mean local-scale
  signals were near zero.

This is evidence for a common posterior-location mechanism, not a variance
decomposition. Correlation with a nonlinear aggregate score cannot establish
that the intercept contributes more than 50% of quantile-path variance.

The completed mean-state source 075 still has wide intervals despite
near-zero state/readout propagation dispersion. This shows that averaging the
recursive reservoir state does not remove the dominant uncertainty, but it
does not by itself distinguish intercept, reservoir coefficients, lagged input
coefficients, and their posterior covariance.

## 6. Required variance attribution after campaign closeout

For each retained Q-DESN source and each origin/lead mean readout vector
`x_bar`, compute

```text
Var(q | y, x_bar) = x_bar' Cov(beta | y) x_bar.
```

Partition `beta` and `x_bar` into:

- intercept;
- reservoir features;
- lagged response/readout inputs; and
- deterministic exogenous inputs, when present.

Report for each block:

- marginal block variance;
- covariance-aware allocation
  `Var(block) + sum Cov(block, other blocks)`, which sums to total variance;
- leave-one-block variance change;
- summaries by family, quantile, likelihood, inference method, origin, and
  lead; and
- the relationship between block variance and draw-level MAE/check-loss width.

Negative covariance allocations are retained rather than clipped. The
decomposition must be computed on the exact mean-readout vectors and balanced
posterior draws used by the completed campaign.

## 7. Evidence-gated regularization experiment

No broad screening starts until the attribution ledger is complete.

### If intercept/common location dominates

Hold the current case-specific DESN winner, `tau0`, slab prior, likelihood,
seeds, windows, and scoring fixed. Compare the current diffuse intercept prior
against finite zero-centered Normal priors on the standardized scale. Use a
small ordered grid of interpretable prior standard deviations rather than a
hard zero. For example, standard deviations `1`, `0.5`, `0.2`, and `0.1`
correspond to precisions `1`, `4`, `25`, and `100`.

### If non-intercept readout blocks dominate

Hold the intercept prior fixed. Use a small crossed design:

- `tau0` multipliers relative to the case-specific authority, such as `1`,
  `0.1`, and `0.01`; and
- persistent slab caps through explicit `zeta2_fixed` values, not `s2`-only
  initialization.

The slab values must be calibrated on the standardized coefficient scale and
include the current learned-slab authority as the control.

### If both mechanisms matter

Use a fractional factorial design over intercept precision, `tau0`, and
`zeta2_fixed`, followed by local refinement. Do not enumerate a full Cartesian
grid. Selection remains family-, quantile-, likelihood-, inference-, and
metric-specific.

## 8. Decision criteria

The primary target is narrower posterior metric intervals without materially
worsening the corresponding point forecast score. Report fit RMSE and chain
diagnostics, but do not use them to conceal or replace forecast behavior.

Every candidate must preserve:

- the frozen DGP and train/forecast windows;
- the same origin/lead scoring contract;
- the current case-specific DESN winner unless DESN structure is the explicit
  intervention;
- the exAL M0/CRAN inference path where applicable;
- finite outputs and exact provenance; and
- separate results for VB and MCMC.

The current recursion campaign is diagnostic and must close before this later
prior experiment is launched. Its result determines whether recursion or
posterior coefficient uncertainty is the primary mechanism.
