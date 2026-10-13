# Independent Q-DESN RHS Forecast-Uncertainty Rescue v9

## Purpose

The Gaussian-mixture, AL, `p = 0.05` cell is the mechanism sentinel for the
remaining independent-study problem: competitive mean forecast error with a
posterior forecast-score interval materially wider than DQLM. V7 reduced mean
forecast MAE from 4.6032 to 3.2762 and reduced the forecast-MAE score interval
width from 3.461 to 2.188, but the latter remained about 4.7 times the matched
DQLM width of 0.468.

V8 holds the validated DESN representation fixed and tests global RHS scales.
Its discovery stage identifies tau multiplier 2 as the best multi-objective
arm, with mean forecast MAE 2.969 and forecast-MAE interval width 1.387 on the
selection folds. Those short-budget values are not confirmation results.

V9 is a conditional successor. It runs only when the hash-verified V8
confirmation fails to close at least half of the V7-to-DQLM excess-width gap.
It targets genuinely distinct RHS controls and cannot change Article-v2,
shared validation, any integration branch, or Overleaf.

## Diagnosis and Design Correction

The retained-draw decomposition rules out three previously plausible causes:

1. Replacing draw-specific recursive states by a shared posterior mean state
   changes mean MAE by only 0.1--0.3% and score width by approximately -0.4%
   to +2.1% across the V8 discovery arms.
2. Removing future process noise does not reduce the spread and is generally
   worse for mean performance.
3. Prior analyses found negligible association between the intercept and
   forecast MAE.

The remaining deviations are low-rank and coherent across origin-lead cells.
The primary target is therefore posterior readout covariance, not recursive
state propagation, process simulation, or an intercept-only adjustment.

`effective_p0` is not an independent fitted-model parameter in the current
implementation. With fixed readout dimension `p` and sample size `N`, it only
elicits

```text
tau0 proportional to p0 / (p - p0) / sqrt(N) * tau_multiplier.
```

Consequently, a factorial `effective_p0` by tau-multiplier screen would contain
duplicate priors. V9 instead varies two distinct controls:

- global shrinkage through `tau0`;
- the RHS-NS slab distribution through `b_zeta`, implemented by scaling
  `slab_source` while holding `a_zeta = 2` fixed.

The intercept remains unshrunk. That follows the package contract and the
mechanism evidence; it is not an untested convenience.

## Frozen Scientific Contract

- Cell: Gaussian-mixture, AL, `p = 0.05`.
- Training size: 2,000 observations after a 500-observation washout.
- Architecture: the V7/V8 winner, held fixed.
- Readout: intercept plus all identity-Q reservoir layers; no raw inputs.
- Forecasting: observations are assimilated when the origin advances and each
  30-step forecast is recursive within origin.
- Selection folds: S1 and S3 only.
- Confirmation folds: S2 and S4 only.
- Article holdout: source indices 9001--10000 remain unopened.
- Software: CRAN `exdqlm` 1.1.2 under R 4.6.0.
- Parallelism: one physical core and one numerical-library thread per model.
- Storage: compressed sufficient evidence only; fitted model binaries are
  forbidden.

## Conditional Entry Rule

For the best V8 confirmation arm define

```text
C_W = (W_v7 - W_v8) / (W_v7 - W_DQLM),
```

where `W` is the 95% posterior forecast-MAE metric interval width. V9 does not
run if the V8 arm passes all V8 metric gates and `C_W >= 0.50`. In that case it
materializes a zero-job closeout recording that no additional screen is
scientifically justified.

## Prior Design

The candidate universe is

```text
tau multiplier:  1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3
slab multiplier: 0.25, 0.5, 0.75, 1
```

Twelve combinations are selected deterministically by maximin coverage on the
log-tau/log-slab plane. The V8 parent arm, tau 2 with slab 1, tau 2 with slab
0.5, and tau 1.5 with slab 0.5 are forced anchors where applicable. The panel
is broad enough to identify a useful shrinkage direction without spending 32
short MCMC fits on a full factorial design.

## Stages and Budgets

| Stage | Jobs | Purpose | Budget |
|---|---:|---|---|
| Smoke | 1 | Prior override, forecasting, evidence, and hash path | 20 burn + 40 retained |
| Attribution | 6 | Readout-block covariance from the selected V8 arm | retained draws; no refit |
| Warm | 24 | VB initializers for 12 priors on S1/S3 | 800 iterations |
| Discovery | 24 | Direct MCMC screening on S1/S3 | 1,500 burn + 5,000 retained |
| Confirm warm | 4 | VB initializers for two priors on S2/S4 | 1,000 iterations |
| Confirmation | 12 | 2 priors x 2 folds x 3 chains | 3,000 burn + 10,000 retained |

The maximum is 30 concurrent jobs. Every job is pinned to one physical core,
and all numerical-library thread counts are fixed at one.

## Attribution Outputs

The no-refit attribution stage reconstructs the training-fold design from the
frozen reservoir and retained V8 coefficient draws. It records:

- covariance trace and first-PC share for the intercept and every reservoir
  layer;
- posterior coefficient mean norm and mean coefficient standard deviation;
- first-step forecast contribution dispersion by block and origin;
- covariance contribution of every block to total first-step variation;
- the full nonintercept coefficient covariance eigenspectrum.

This is deliberately based on teacher-forced first steps. V8 already showed
that sharing recursive states does not remove the spread, so replaying every
future state merely to recover the same beta uncertainty would add cost rather
than information.

## Selection and Confirmation

Discovery excludes priors whose mean MAE is more than 10% above the best
discovery mean. Remaining arms are ranked by mean forecast MAE, forecast-MAE
interval width, and interval score. The best multi-objective arm and the V8
parent prior proceed to confirmation.

A confirmed metric rescue requires all of:

1. mean forecast MAE no more than 1.10 times DQLM;
2. worst-fold forecast MAE no more than 1.20 times DQLM;
3. mean forecast MAE no more than 2% above V8;
4. forecast-MAE interval width strictly below V8;
5. forecast check loss no more than 2% above V8;
6. interval score no more than 2% above V8.

Full closure additionally requires `C_W >= 0.50` relative to the original V7
and DQLM widths. Width is never optimized by itself: interval score and mean
performance prevent artificial certainty from qualifying.

## Decisions

- `RHS_UNCERTAINTY_RESCUE_CONFIRMED_PREPARE_CELLWISE_PROPAGATION`: at least
  one arm passes every metric gate and closes half of the excess-width gap.
- `PARTIAL_RHS_RESCUE_PREPARE_LOCAL_REPRESENTATION_FALLBACK`: metric rescue
  passes, but the practical width target does not.
- `RHS_RESCUE_INSUFFICIENT_PREPARE_LOCAL_REPRESENTATION_FALLBACK`: no arm
  passes the metric gates.
- `V8_FULL_RESCUE_NO_ADDITIONAL_RHS_SCREEN`: V8 already met the stricter
  closure rule and V9 correctly ran zero jobs.

No fallback is appended dynamically. A representation fallback would be a new
frozen campaign based on the completed attribution evidence. This prevents
confirmation-fold feedback from leaking into candidate generation.

## Reproducibility and Publication Boundary

Every configuration, plan, package tree, source file, parent artifact, and
result packet is SHA-256 hashed. Stage advancement requires successful worker
statuses and verified evidence manifests. The run retains score draws,
origin-lead diagnostics, selected coefficient draws, prior metadata, and
attribution tables, but no `.rds`, `.rda`, or `.RData` fitted-model payloads.

The campaign is diagnostic and confirmatory only. Any later 18-cell
propagation must preserve case-specific specifications, use M0 for exAL, and
be followed by fresh-DGP confirmation before article replacement.
