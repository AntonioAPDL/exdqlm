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
6. Pool 12,000 draws per source for all seven sentinels and classify the dominant
   mechanism using origin covariance, lead covariance, late/early loss, temporal
   concentration, common-shift energy, oracle-path coverage, and stable RHS-scale
   associations.
7. A case-specific `tau0` intervention is eligible only when an RHS posterior
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
