# Independent Single-Quantile Metric Intervals v1

## Decision

The current article-v9 scalar tables are a frozen rollback authority. They must
remain unchanged until this campaign completes and passes its predeclared
replay, estimator, diagnostics, storage, and article-build gates.

This campaign estimates posterior uncertainty for the three displayed metrics:

1. fit-window oracle-quantile RMSE;
2. rolling-origin oracle-quantile forecast MAE; and
3. rolling-origin forecast check loss.

It is an estimation campaign, not a new model screen. Every fit replays an exact
case-specific, metric-specific source selected by article v9. No result from
this campaign may be used to change the DESN specification, prior, likelihood,
reservoir realization, DQLM design, or source trajectory.

## Scientific estimands

For posterior conditional-quantile draw \(b\), training indices
\(T_{fit}=\{8501,\ldots,9000\}\), and the 1,000 lead-target pairs in the
rolling-origin evaluation grid \(G\), define

\[
R_{fit}^{(b)} =
\left\{|T_{fit}|^{-1}\sum_{t\in T_{fit}}
  (q_t^{(b)}-q_t^\star)^2\right\}^{1/2},
\]

\[
A_{fore}^{(b)} = |G|^{-1}\sum_{(o,h)\in G}
  |q_{o,h}^{(b)}-q_{o+h}^\star|,
\]

and

\[
C_{fore}^{(b)} = |G|^{-1}\sum_{(o,h)\in G}
  \rho_\tau(y_{o+h}-q_{o,h}^{(b)}),
\qquad
\rho_\tau(u)=u\{\tau-\mathbb{1}(u<0)\}.
\]

Each table entry is the posterior mean followed by the equal-tailed 95 percent
credible interval, \([q_{0.025},q_{0.975}]\). VB intervals must be labeled
"approximate 95% CrI". These intervals condition on the simulated data set,
the evaluation design, and one frozen reservoir realization. They are not
Monte Carlo intervals over repeated DGP realizations and do not propagate
reservoir-design uncertainty.

## Draw contracts

### Q-DESN and exQ-DESN

- Fit draws come from `mu_draws_tr`.
- Rolling forecast draws come from `mu_by_origin`.
- `yrep_by_origin` is posterior predictive response noise and is prohibited as
  the primary source for these conditional-quantile metric intervals.
- Draw columns remain aligned across fit and rolling-origin arrays.
- A deterministic, evenly spaced subset is used when a fit contains more draws
  than the predeclared metric budget.

### DQLM and exDQLM

- Fit conditional-quantile draws are computed as
  \(F_t^\top\theta_t^{(b)}\) from `samp.theta`.
- Rolling forecast conditional-quantile draws are sampled from the latent
  forecast state distribution with mean `ff` and variance `fQ`.
- At each rolling origin, these draws are conditional on the observations
  available at that origin. The aggregate therefore uses the predeclared
  product coupling of the origin-specific latent forecast laws; it is not a
  posterior predictive response path and does not claim a common latent future
  across different information sets.
- `samp.post.pred` and `samp.fore` are response draws and are prohibited as the
  primary metric-interval source.
- Draw generation is deterministic under the frozen per-job seed.

## Replay authority

The source authority is
`qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821`.
The replay registry expands each article row into its fit, forecast-MAE, and
forecast-check source roles, then deduplicates by inference, model, family,
quantile, candidate, and run tag.

Expected production scope:

| Component | Source identities | Chains per source | Jobs |
|---|---:|---:|---:|
| VB | 36 | 1 | 36 |
| MCMC | 54 | 3 | 162 |
| Total | 90 | - | 198 |

For MCMC, all three chains for a source must use the same frozen reservoir
seed and reservoir hash. Only the chain seed may differ. Historical
"confirmation chains" that changed the reservoir seed are not pooled as a
single posterior.

When historical evidence contains several reservoir replications, the replay
uses a deterministic source selection made without consulting replay metrics:
the lexicographically first complete source request after filtering by exact
candidate and run tag. The selected request, hash, and reservoir seed are
frozen in the replay registry before production begins.

## Budgets

Production budgets are:

| Inference | Fit budget | Metric draws | Replication |
|---|---|---:|---:|
| VB | current source max-iteration policy, at least 300 iterations | 10,000 | 1 |
| MCMC | 5,000 burn-in plus 20,000 retained iterations | 4,000 per chain | 3 chains |

The 4,000 MCMC metric draws are selected deterministically and evenly across
the retained chain. The pooled metric posterior therefore contains 12,000
equally weighted values per replay identity. No thinning is justified by file
size because only three scalar metrics per selected draw are retained.

## Validation gates

### Static replay gates

- The article-v9 interface and manifest hashes match the frozen authority.
- Exactly 72 article rows and 216 metric roles are represented.
- Exactly 90 replay identities resolve to complete source specifications.
- Every source series and selection-index hash matches its frozen request.
- Each Q-DESN replay preserves the winner's native contiguous pre-fit context,
  whose start depends on its memory and washout requirements. The common
  evaluation windows remain exactly 8501--9000 and 9001--10000; source files
  are not padded or truncated to a global context length.
- All absolute paths are either current validation authority paths or are
  rewritten to verified current equivalents with matching hashes.
- exQ-DESN MCMC uses exact exAL M0
  `m0_v_collapsed_support_logit`.
- Q-DESN MCMC uses the frozen AL transition.
- The DQLM/exDQLM design remains the c13 trend-plus-seasonal design.

### Estimator gates

- Hand-computed fixture values match RMSE, MAE, and check-loss outputs.
- Draw orientation is time by draw for every engine.
- Fit uses exactly 500 oracle-aligned rows.
- Rolling forecast uses exactly 1,000 unique target indices, leads 1 through
  30, and origin stride 30.
- Conditional-quantile draws are used and response draws are rejected.
- Every finite equal-tailed interval satisfies lower <= posterior median <=
  upper. Whether the posterior mean lies inside the interval is recorded as a
  disclosure field rather than imposed as a mathematically invalid gate for
  skewed metric posteriors.
- MCMC chains contribute equal draw counts.

### MCMC reporting gates

Metric-level split-Rhat, bulk ESS, tail ESS, Monte Carlo standard error,
pairwise interval overlap, and interval-endpoint stability are reported.
Diagnostics are disclosure fields, not automatic metric-exclusion rules. A
warning does not permit a specification switch or selective omission after
observing the result. Any later extension must preserve the exact specification,
reservoir, and source identity and is a separately versioned follow-up rather
than an automatic branch of this fixed-budget campaign.

### Storage gates

Each successful job retains only:

- `metric_draws.csv.gz`;
- `metric_interval_summary.csv`;
- compact point-path summaries;
- diagnostics, status, logs, configuration, and hash manifests.

Fitted-model `.rds`, `.rda`, and `.RData` payloads are transient. They may be
removed only after compact metric files exist, pass schema checks, and have
recorded hashes. Failed jobs retain enough logs and metadata for diagnosis but
must not retain large binary payloads unless explicitly quarantined.

## Execution

The production scheduler uses at most 20 workers and one numerical thread per
worker. It must inspect CPU, available memory, and free disk space before each
wave and must not bind to cores used by another scientific lane. Jobs are
restartable and skip only when a success marker matches the current config
hash.

Execution order:

1. static registry and source-hash audit;
2. two-engine smoke test using reduced budgets;
3. VB production wave;
4. DQLM/exDQLM MCMC wave;
5. Q-DESN/exQ-DESN MCMC wave;
6. pooled interval diagnostics and closeout;
7. article packet generation, with any same-spec extension left as an explicit
   separately versioned follow-up when the diagnostic record warrants it.

The scheduler may overlap waves only when resource gates pass. It never
interrupts or modifies Joint, GloFAS, PriceFM, or other validation jobs.

## Article handoff

No article file is changed during computation. After all 198 jobs and any
predeclared extensions finish, the closeout builds a candidate v10 interface.
Unlike v9, v10 uniformly reports the posterior mean of each draw-wise metric;
it must not selectively preserve favorable v9 point estimators.

The article handoff should provide:

- three compact MCMC family tables, grouped by quantile;
- three VB companion tables in the supplement;
- posterior mean on the first line of each metric cell and 95% CrI on the
  second line;
- boldface based on the displayed posterior mean only;
- concise protocol prose explaining conditioning and metric-specific sources;
- a complete source/interval manifest and rollback pointer to v9.

Main and supplement must compile without unresolved references, overfull boxes,
or placeholders. Publishing, merging, and Overleaf synchronization are owned by
the ARTICLE QDESN INTEGRATION lane after this scientific branch is frozen and
marked `READY_FOR_INTEGRATION`.
