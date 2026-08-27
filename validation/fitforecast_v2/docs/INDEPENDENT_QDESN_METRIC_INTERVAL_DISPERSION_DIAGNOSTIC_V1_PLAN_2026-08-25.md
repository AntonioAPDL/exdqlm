# Independent Q-DESN metric-interval dispersion diagnostic v1

## Scientific objective

Diagnose why the posterior-draw distributions of forecast MAE and forecast check
loss are much wider for single-quantile Q-DESN AL-RHS and exAL-RHS than for the
DQLM comparators. The diagnostic must distinguish an estimator/protocol effect
from genuine posterior parameter uncertainty before any new `tau0`, slab,
intercept, or DESN architecture screen is authorized.

This campaign does not replace the article estimator, reselect a winner, update
an article table, or treat interval width as the primary forecasting objective.
The article point metrics remain primary. Interval width is used here only to
understand posterior uncertainty and to choose the next efficient experiment.

## Evidence motivating the design

The frozen v10/v10.1 interval evidence established all of the following.

1. Q-DESN forecast-MAE intervals are substantially wider than the corresponding
   DQLM intervals in every displayed MCMC cell.
2. Standard chain diagnostics are healthy in essentially all affected cells.
   The width is therefore not adequately explained by failed mixing.
3. Permuting posterior-draw identities independently by forecast origin greatly
   contracts Q-DESN intervals without changing marginal means. Cross-origin draw
   dependence is material.
4. Small `tau0` is not sufficient: one of the widest cells already uses
   `tau0=1e-8`, and historical controlled `tau0` comparisons changed point
   metrics very little.
5. The RHS intercept is not horseshoe-shrunk. A common intercept component can
   therefore survive reductions in `tau0`.
6. The reported `mu_by_origin` paths are conditional-quantile paths, but leads
   greater than one recursively use sampled future responses as lag inputs.
   Thus predictive innovations can propagate into later conditional means.

The sixth point changes the optimal order of work. A prior screen before a
recursion decomposition could spend substantial compute treating a protocol
mechanism as a shrinkage problem.

## Frozen sentinel panel

Seven case-specific, authoritative forecast-MAE sources are replayed with their
exact DESN design, prior, likelihood, seed contract, MCMC budget, and source
data. Each source receives three chains.

| Family | Quantile | Model | Role |
|---|---:|---|---|
| Gaussian | 0.05 | AL-RHS | Largest AL interval; very small `tau0` stress case |
| Gaussian | 0.05 | exAL-RHS | Wide exact-M0 case with deep/high-memory DESN |
| Gaussian mixture | 0.05 | exAL-RHS | Difficult lower-tail compact-design case |
| Gaussian mixture | 0.25 | exAL-RHS | Wide exact-M0 central-tail case |
| Laplace | 0.05 | AL-RHS | Heavy-tail lower-tail stress case |
| Laplace | 0.50 | AL-RHS | Lower-width AL control |
| Laplace | 0.50 | exAL-RHS | Lower-width exact-M0 control |

The machine-readable source ledger is
`config/validation/independent_interval_dispersion_diagnostic_v1/sentinel_sources.csv`.

## Estimator-preserving decomposition

For every posterior draw and rolling-origin target, the replay computes two
paths from the same posterior parameter draw.

1. `posterior_predictive`: the current authoritative recursion. Simulated future
   responses update future lag inputs.
2. `conditional_mean_plugin`: a diagnostic counterfactual in which future lag
   inputs use the conditional mean (`y_h = mu_h`).

The second path is not promoted and is not substituted into the article. It is
a controlled intervention that removes only recursive predictive innovations.
Lead one must agree between the two modes because both begin from the same
observed history and posterior draw.

The existing native-alignment versus origin-independent-permutation sensitivity
is recomputed in the same replay. This creates a two-axis decomposition:

- recursive innovation propagation;
- cross-origin posterior-draw dependence.

## Compact retained evidence

Full fitted models and pointwise posterior matrices exist only in memory while
the worker is active. Before storage-light pruning, each worker exports:

- draw-level native and plug-in metric diagnostics;
- target-level posterior summaries for both recursion modes;
- lead- and origin-level metric summaries;
- cross-origin covariance and common-path summaries;
- correlations of metric draws with beta norm, intercept, sigma, gamma, and
  available RHS scale draws;
- SHA-256 manifests for every retained artifact.

No `.rds`, `.rda`, or `.RData` payload is retained after a successful worker.

## Interpretation gates

The closeout classifies every cell independently. It never selects one global
specification.

- Plug-in/native MAE-width ratio at most 0.50: recursive innovation is dominant.
- Ratio in (0.50, 0.70]: recursive innovation remains material.
- Origin-permuted/native ratio at most 0.70 with a larger plug-in ratio:
  cross-origin dependence is dominant.
- Otherwise, an absolute parameter-to-MAE Spearman correlation at least 0.35
  indicates a posterior parameter-scale mechanism.
- Remaining cells are mixed or structural.

These are diagnostic routing thresholds, not inferential acceptance thresholds.
All continuous statistics are retained so the decision can be audited.

## Mechanism-gated follow-up

No follow-up fit is launched automatically.

1. If recursion dominates, freeze the current article estimator and first decide
   whether stochastic recursive histories match the intended quantile-forecast
   estimand. Do not claim that a smaller `tau0` solves the interval width.
2. If cross-origin dependence dominates, retain native intervals and disclose
   the coupling sensitivity; dependence cannot be removed merely to obtain a
   narrower interval.
3. If RHS scale parameters dominate after deterministic recursion, run a
   case-specific one-factor `tau0`/slab intervention around the authoritative
   design.
4. If the intercept dominates, test an explicitly regularized intercept while
   holding every DESN and likelihood choice fixed.
5. If gamma or sigma dominates an exAL cell, retain exact M0 and test only the
   relevant shape/scale prior or transition setting.
6. If no single component dominates, change one structural dimension at a time
   around that cell's authority; do not return to an undirected broad grid.

Any later candidate remains subject to the user's case-specific promotion rule:
a finite strict improvement in the targeted point forecast metric is eligible,
however small, with its diagnostic provenance disclosed. Width reduction alone
does not authorize metric promotion.

## Execution and ownership

- Lane: independent single-quantile Q-DESN/DQLM validation only.
- Branch: `validation/independent-interval-dispersion-diagnostic-v1-1.0.0`.
- Workers: up to 20, one numerical thread per worker, CPU-pinned.
- Jobs: 21 (7 sources times 3 chains).
- exAL method: exact M0 (`m0_v_collapsed_support_logit`).
- Article/Overleaf: no write authority.
- Integration: the scientific branch will be handed to the coordinator only
  after hashes, tests, health, closeout, and storage checks pass.

## Reproducible workflow

1. Materialize exact jobs from the frozen v10 production replay.
2. Verify source hashes, configurations, exact-M0 dispatch, CPU plan, and
   storage-light contracts.
3. Run focused unit and harness tests.
4. Run a one-job smoke replay and inspect all compact outputs.
5. Commit and push the coherent launch implementation.
6. Launch the 21-job campaign in a background `tmux` session.
7. Use the generic interval health reporter while jobs run.
8. Close out only after 21/21 successful terminal statuses and artifact hashes.
9. Produce the mechanism-gated follow-up ledger; do not launch its interventions
   without reviewing the observed decomposition.
