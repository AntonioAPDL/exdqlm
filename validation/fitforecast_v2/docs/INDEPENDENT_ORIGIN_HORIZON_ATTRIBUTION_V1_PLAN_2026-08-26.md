# Independent Q-DESN Origin-Horizon Attribution V1

## Objective

Diagnose why posterior distributions of draw-specific forecast metrics are wide in
selected independent Q-DESN MCMC validation cells. The campaign separates
horizon heterogeneity, temporal-block heterogeneity, common posterior shifts,
cross-group covariance, and RHS-scale associations without changing the
authoritative forecast estimand, case-specific DESN specifications, or article
metrics.

## Frozen evaluation contract

- Training source indices: 8501--9000.
- Held-out source indices: 9001--10000.
- Forecast origins: 9000, 9030, ..., 9990.
- Origin stride: 30.
- Maximum lead: 30.
- Authoritative scope: 1,000 unique target observations from 34 origins.
- Balanced sensitivity scope: 990 targets from the 33 complete 30-lead origins.
- The final 10-lead origin remains in the authoritative metric and is excluded
  only from the balanced diagnostic sensitivity.
- Posterior draws remain coherently aligned across origins and leads.
- Conditional-mean recursion and origin permutation remain diagnostics only.

## Estimands

For posterior draw `s`, origin `o`, and lead `h`, the transient loss surface is

`L[s,o,h] = loss(q_draw[s,o,h], q_oracle[o,h], y[o,h])`.

The primary objects are posterior distributions of group-averaged draw-specific
forecast MAE and check loss. They are not sampling intervals for the point
performance estimate. Every grouped metric must reconstruct the original
1,000-target draw metric within `1e-6`.

## Stages and gates

1. Correct the V1 closeout label for an all-cross-origin diagnosis. No numerical
   evidence changes.
2. Extend the real Q-DESN pipeline to export compact draw-level origin, lead, and
   five-lead-band metrics while the aligned forecast matrix is already in memory.
3. Export covariance matrices, covariance-by-separation summaries, target-level
   width/coverage summaries, balanced path-structure decomposition, localized
   parameter associations, and exact reconstruction checks.
4. Run a six-job pilot: three chains for Laplace AL-RHS at `p=0.05` and three
   chains for the matched-family AL-RHS `p=0.50` lower-width control.
5. Authorize the full 21-job campaign only if every pilot job succeeds, every
   reconstruction error is at most `1e-6`, all expected origin/lead groups are
   present, covariance outputs are finite and nonconstant, each job remains below
   100 MiB, and no fitted-model binary remains.
6. Reuse the six hash-verified pilot jobs as constituent full-campaign evidence
   and execute only the remaining 15 jobs. The full plan retains 21 rows, copies
   the six immutable terminal statuses into its state root, and records a
   pilot-reuse ledger and decision hash. This prevents duplicate fitting while
   preserving a single seven-cell closeout contract.
7. Pool 12,000 draws per source for all seven sentinels and classify the dominant
   mechanism using origin covariance, lead covariance, late/early loss, temporal
   concentration, common-shift energy, oracle-path coverage, and stable RHS-scale
   associations.
8. A case-specific `tau0` intervention is eligible only when an RHS posterior
   scale has median absolute Spearman association of at least 0.35, all three
   chains agree in sign, every chain has absolute association at least 0.20, and
   oracle-path coverage is at least 0.95. Eligibility authorizes a later causal
   pilot; it does not automatically launch or promote one.

## Storage contract

The full `1000 x 4000` conditional-quantile draw matrix is transient. Retained
artifacts are compressed grouped draws, compact target summaries, covariance
tables, parameter associations, manifests, logs, and figures. Forecast objects,
fit handoffs, `.rds`, `.rda`, and `.RData` payloads are prohibited after a
successful job.

The six pilot job roots remain protected constituents of the full closeout and
must not be treated as obsolete after reuse. Their configuration, status, and
artifact hashes are frozen in the full campaign's pilot-reuse ledger.

## Interpretation map

| Evidence pattern | Interpretation | Next action |
|---|---|---|
| High covariance across origins and leads, weak RHS association | Shared posterior model uncertainty | Retain native estimator; do not tune `tau0` for width alone |
| Loss rises primarily at leads 26--30 | Dynamic-memory limitation | Review `m`, `rho`, `alpha`, depth, and reservoir capacity |
| A small set of origins dominates | Local time-block or regime sensitivity | Compare matched models and inspect source trajectory blocks |
| Q-DESN-specific common shift with stable RHS association | Plausible prior-scale overdispersion | Authorize a case-specific matched-seed `tau0` causal pilot |
| Narrower intervals with lower oracle coverage or worse forecast loss | Over-shrinkage | Reject the smaller `tau0` |
| All models struggle in the same blocks | Evaluation/DGP difficulty | Do not attribute the pattern uniquely to Q-DESN |

## Promotion policy

This diagnostic campaign cannot alter article metrics or launch hyperparameter
screening automatically. Any later model promotion remains case-specific and is
based primarily on strict forecast-MAE improvement, with forecast check loss,
fit RMSE, width, and coverage retained as supporting evidence. Article-safe
assets are handed to the integration coordinator only after a complete frozen
closeout.

## Completed execution and diagnosis

The pilot and full campaign are complete. The full campaign identifier is
`independent_origin_horizon_attribution_v1_full_20260826_021943`. It pools three
chains for each of seven predeclared cells: 21/21 jobs succeeded, 6 pilot jobs
were reused by verified hash, 15 jobs were newly executed, and every retained
job has 4,000 draw-specific metric draws. All 16 final closeout checks pass.
There are no active campaign processes and no retained `.rds`, `.rda`, or
`.RData` payloads.

Final decision:
`ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED`.

| Cell | Family / model / level | MAE mean | 95% width | Origin covariance | Late/early | Oracle coverage | Error mode |
|---|---|---:|---:|---:|---:|---:|---|
| `055` | Laplace / AL-RHS / 0.05 | 7.652 | 6.029 | 0.931 | 1.087 | 0.988 | Dispersion-dominant |
| `073` | Gaussian / AL-RHS / 0.05 | 7.462 | 9.304 | 0.961 | 0.970 | 0.645 | Location-error-dominant |
| `075` | Gaussian / exAL-RHS / 0.05 | 3.571 | 6.489 | 0.957 | 1.003 | 0.891 | Location-error-dominant |
| `078` | Laplace / AL-RHS / 0.50 | 1.819 | 3.689 | 0.953 | 1.051 | 1.000 | Dispersion-dominant |
| `080` | Laplace / exAL-RHS / 0.50 | 1.884 | 3.649 | 0.953 | 1.031 | 1.000 | Dispersion-dominant |
| `082` | Gaussian mixture / exAL-RHS / 0.05 | 3.786 | 7.443 | 0.961 | 1.020 | 0.970 | Mixed |
| `083` | Gaussian mixture / exAL-RHS / 0.25 | 3.471 | 7.511 | 0.957 | 0.981 | 1.000 | Dispersion-dominant |

The diagnosis is stable across all seven cells:

- Posterior forecast losses move coherently across origins and leads. Origin
  covariance explains 93.1--96.1% of aggregate metric variance, and lead-loss
  correlation remains material throughout the 30-step horizon.
- Late-horizon forecast MAE is not systematically worse. Late/early ratios are
  0.970--1.087, far below the predeclared 1.25 horizon-instability threshold.
- No small group of temporal blocks dominates. Top-20% origin loss shares are
  0.249--0.327, below the 0.35 concentration threshold.
- The incomplete final origin is not responsible. Removing it changes posterior
  mean MAE by at most 1.21% and interval width by at most 1.04%.
- The strongest RHS-scale median Spearman association has absolute magnitude
  only 0.018--0.077. No cell approaches the causal `tau0` gate.
- Gaussian lower-tail cells `073` and `075` are chiefly location/design-bias
  cases, not excess-RHS-variance cases. Cell `075` has a stable association with
  the readout intercept, which further argues for location calibration rather
  than indiscriminate prior tightening.

These intervals are therefore not wide because 34 origins and 30 leads were
naively treated as independent observations. Each posterior draw is kept aligned
over the full forecast surface, so common parameter uncertainty correctly
survives averaging. A smaller `tau0` could narrow coefficient draws, but the
observed width does not track the RHS scale and narrowing alone would not show
that calibration or forecast accuracy improved.

## Recommended scientific continuation

1. Retain the current `tau0` values for these seven cells. Do not launch a broad
   smaller-`tau0` screen merely to make intervals visually narrower.
2. For Gaussian lower-tail cells `073` and `075`, design a separate case-specific
   location/design-bias study. Evaluate intercept behavior, oracle-path bias,
   feature design, and likelihood/location specification while preserving the
   current 1,000-target estimator.
3. For the four dispersion-dominant cells and mixed cell `082`, inspect
   common-mode posterior components, especially intercept, likelihood scale,
   and propagated latent-state uncertainty. Any intervention must be tested with
   matched seeds against forecast MAE, check loss, interval width, and oracle
   coverage; narrower intervals alone are not a success criterion.
4. A future `tau0` experiment must remain case-specific and causal: hold the
   selected DESN design fixed, vary only `tau0`, use matched seeds, and reject a
   narrower result if forecast performance or coverage deteriorates.
5. Do not alter article tables from this diagnostic campaign. It explains the
   interval mechanism but produces no replacement performance metric.

## Operational closeout

The live full launch exposed a CPU-indexing defect when six reused pilot rows
preceded 15 new rows. Three active jobs were initially assigned the same cores
as another active cell; their complete process trees were moved live to free
cores 41--43 without restart. The effective assignment is recorded in
`runtime_core_reassignment_ledger.csv`. Materialization now indexes cores only
over newly executed jobs, requires one unique core per new job, and verifies the
effective assignment before execution and closeout.

Health reporting now counts the 5,000 burn-in and 20,000 retained iterations as
25,000 total MCMC iterations and falls back to the live sampler log when the
retained-draw trace is not yet available. The pooled closeout implementation was
also changed from repeated full-table scans to replay-block grouping. Its output
was compared against the original pooled table and matched exactly, with maximum
absolute numerical difference zero.
