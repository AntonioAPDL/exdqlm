# Independent Q-DESN/DQLM exdqlm 1.1.1 rerun

## Decision objective

Re-evaluate the complete independent single-quantile validation table under one
pinned `exdqlm` 1.1.1 environment. The campaign changes package inference and
RNG behavior only. It does not recalibrate candidates, edit the article, or
combine old and new rows.

The comparison authority is
`qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827`.
Its 72 article rows expand to 216 metric roles, 90 unique fitted-source
identities, and 198 replay jobs after three-chain MCMC replication.

## Package provenance

- Source branch: `feature/jss-resubmission-from-cran-1.0.0`
- Required source commit: `6dba6f2863705e0e90f0ce19e0c75d106d022a52`
- Required version: `1.1.1`
- Validation branch: `validation/independent-qdesn-exdqlm-1.1.1-rerun-20260827`

The validation branch merges the exact package source commit into the current
shared-validation authority. This is necessary because Q-DESN replay code uses
`pkgload::load_all()` and therefore must execute the same source tree as the
installed DQLM code. The merge remains confined to the dedicated branch.

## Preflight gates

No production CPU may start unless all gates pass in a fresh R process:

1. Version 1.1.1 and ancestry of the required source commit.
2. `collapsed_slice` is the first MCMC proposal for dynamic and static exAL.
3. structured `q(gamma)q(sigma|gamma)` is the default VB factorization, with
   151 gamma-grid nodes.
4. unrestricted exAL MCMC records `collapsed_slice`.
5. unrestricted exAL LDVB records the structured factorization.
6. Q-DESN exAL VB records the same structured factorization.
7. AL/gamma-fixed fits do not run a gamma update.
8. fixed-seed stochastic helpers are identical across one and four OpenMP
   threads and across fresh R processes.
9. source, package, and focused validation tests pass.

## Frozen scientific contract

- Families: Gaussian, Laplace, Gaussian mixture.
- Quantiles: 0.05, 0.25, 0.50.
- Training source indices: 8501--9000.
- Forecast source indices: 9001--10000.
- Rolling origins every 30 observations; leads 1--30; no per-origin refit.
- Models: DQLM AL, exDQLM exAL, Q-DESN AL-RHS-NS, Q-DESN exAL-RHS-NS.
- Candidate, feature, reservoir, DGP, and score definitions are inherited from
  each exact v11 metric source.
- MCMC: three chains, 5,000 burn-in and 20,000 retained iterations per chain.
- VB: at least 300 iterations and 10,000 posterior metric draws.
- Metric intervals use conditional-quantile draws, not response-predictive
  noise.

The seed ledger reuses all 195 compatible seeds from the prior 198-job interval
campaign. The three newly promoted Gaussian 0.05 AL chains use their exact v11
confirmation requests. This isolates package/RNG behavior without inventing a
new randomization protocol.

The promoted Gaussian 0.05 AL requests originally named a runtime-only relative
source path. The exact 1,812-row source CSV is frozen under
`config/validation/frozen_sources/independent_qdesn_v11/` and verified against
the request SHA-256 before materialization. This removes a dependency on an old
worktree without changing any source value or source index.

## Inference routing

- exDQLM MCMC explicitly requests `collapsed_slice`.
- Q-DESN exAL MCMC retains the exact M0 collapsed-support-logit update already
  used by the v11 authority.
- exDQLM and Q-DESN exAL VB explicitly use the structured factorization.
- DQLM and Q-DESN AL are fixed-gamma stability controls.
- Each worker uses one numerical thread. Production uses at most 16 concurrent
  workers to coexist with other active scientific lanes.

## Artifacts and retention

Runtime state lives below the ignored orchestration and results roots. Required
compact artifacts include point metrics, posterior metric draws, 95% interval
summaries, chain diagnostics, gamma/sigma diagnostics, fit/forecast quantile
paths, lead and origin summaries, source/config hashes, and environment
manifests. Successful fitted-model `.rds`, `.rda`, and `.RData` payloads are
forbidden.

Forecast RMSE is retained in the granular forecast-path and lead summaries even
though it is not one of the three article table criteria. aCRPS is not computed
because it is not implemented by the frozen independent-validation tooling;
adding a new score during a package-version compatibility rerun would violate
the fixed scientific contract.

The closeout must compare 1.1.1 against v11 by inference, model, family,
quantile, and metric; distinguish score changes from mixing changes; generate
an ignored diagnostic PDF packet; and issue exactly one decision:
`READY_FOR_INTEGRATION`, `READY_NO_ARTICLE_CHANGE`, or `BLOCKED`.

No result is article-authoritative until all 198 jobs are complete and the
integration lane accepts the frozen handoff.
