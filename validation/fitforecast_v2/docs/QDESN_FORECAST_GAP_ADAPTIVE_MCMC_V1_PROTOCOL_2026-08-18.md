# Independent Q-DESN Forecast-Gap Adaptive MCMC v1

## Decision and scope

This campaign is the next independent, single-quantile Q-DESN/DQLM validation
stage. It targets only forecast metrics for AL-RHS and exact-M0 exAL-RHS cells
that remain above the best DQLM/exDQLM value in the frozen v7 interface. It does
not modify the package API, the article repository, JOINT validation, PriceFM,
GloFAS, or any application pipeline.

The authority is commit `8e8000af40661526062c5e20279dc82e056a29b6` and:

```text
validation/fitforecast_v2/promotions/
  qdesn_dqlm_500obs_trainonly_article_v7_postm0_forecast_20260818/
  qdesn_dqlm_500obs_trainonly_article_v7_postm0_forecast_20260818_interface.csv
```

The campaign is forecast-first. Fit RMSE is retained as descriptive context but
cannot select or promote a candidate. Each family, quantile, likelihood, and
metric role has its own authority and may select its own winner. A global DESN
specification is explicitly out of scope.

## Audit conclusions

1. v7 contains 14 unresolved forecast roles across eight cells: seven MAE roles
   and seven check-loss roles.
2. Five cells have large or multi-metric gaps and receive 12 candidates. Three
   narrower cells receive eight candidates.
3. Laplace forecast cells and exAL Gaussian-mixture at `p=0.25` are frozen
   because their displayed forecast metrics already beat the structured
   comparators.
4. Pre-M0 exAL MCMC scores are sampler-confounded. Their designs may be used as
   candidate priors, but poor pre-M0 scores are not negative evidence.
5. VB ranking has not been a dependable proxy for full MCMC ranking in this
   study. The campaign therefore uses direct, staged MCMC.
6. Recent gains show that compact, strongly regularized reservoirs can be
   competitive, while older screens also leave meaningful high-alpha,
   high-rho, memory-decomposition, and capacity boundaries underexplored on a
   cell-specific basis. The design includes both regimes.

## Frozen target contract

| Tier | Cell | Promotion roles | Candidates |
|---|---|---|---:|
| A | AL normal `p=0.05` | forecast MAE; forecast check | 12 |
| A | AL normal `p=0.50` | forecast MAE; forecast check | 12 |
| A | exAL normal `p=0.50` | forecast MAE; forecast check | 12 |
| A | exAL Gaussian-mixture `p=0.50` | forecast MAE; forecast check | 12 |
| A | AL Gaussian-mixture `p=0.50` | forecast MAE; forecast check | 12 |
| B | exAL normal `p=0.25` | forecast MAE | 8 |
| B | AL Gaussian-mixture `p=0.05` | forecast MAE; forecast check | 8 |
| B | exAL Gaussian-mixture `p=0.05` | forecast check | 8 |

The tracked metric-role ledger records each v7 value, its structured comparator,
candidate identifier, source path, and SHA-256 hash. Parent controls are frozen
from the objective metric source for each cell. Development comparisons are
paired against that exact parent design on the same generated source.

## Candidate geometry

Tier A uses 12 non-Cartesian arms; Tier B uses a deterministic diverse subset of
eight. The full arm set is:

1. Local RHS scale down.
2. Local RHS scale up.
3. Local readout-memory expansion.
4. Local input-memory expansion.
5. Compact near-zero-alpha, persistent-rho post-M0 design.
6. Compact high-alpha, persistent-rho post-M0 design.
7. Two-layer controlled multiscale recurrence.
8. Three-layer persistent high-alpha/high-rho recurrence.
9. Readout-heavy memory decomposition.
10. Reservoir-heavy memory decomposition.
11. Deterministic history-gap maximin design.
12. Deterministic high-alpha/capacity-boundary maximin design.

Every profile is bounded by an effective readout dimension of 900. Candidate
signatures are checked against the frozen historical ledger and against each
other. Replacements use a deterministic fixed-seed maximin rule. The campaign
therefore does not replay a known exact specification while still covering both
compact and flexible regimes.

## Source and stage contract

Eight new deterministic source blocks use nonoverlapping seeds:

- `dev37` and `dev38`: discovery;
- `dev39` and `dev40`: replication;
- `dev41` through `dev44`: sealed holdout.

| Stage | Budget per job | Maximum jobs | Advancement rule |
|---|---:|---:|---|
| Smoke | 4 burn + 4 sample | 2 | AL and exact-M0 exAL execution contract |
| Calibration | 200 + 500 | 8 | one largest design per cell completes within six hours |
| Discovery | 1,000 + 3,000 | 184 | retain three cell-specific candidates using paired metric leaders and worst-role balance |
| Replication | 1,000 + 3,000 | 64 | retain two candidates after four total development sources |
| Sealed | 2,000 + 6,000 | 96 | nominate a role only if mean and median paired ratios are below one and at least three of four sources improve |
| Canonical confirmation | 5,000 + 20,000 | at most 42 | three chains per unique cell-candidate pair |

The parent control is included at every development stage. When one candidate
wins both forecast roles, canonical fitting is deduplicated and the same three
chains feed both metric decisions.

## Promotion contract

A metric is integration-eligible only when:

1. all three canonical jobs complete successfully;
2. the metric is finite in all chains;
3. configuration, input, source-registry, and output-retention provenance checks
   pass; and
4. the arithmetic mean across the three chains is strictly below its own frozen
   v7 metric authority.

There is no minimum gain threshold. MCMC mixing diagnostics are recorded and
reported but are not a promotion veto, as requested for this forecast-focused
screen. A gain in one metric does not authorize replacement of another metric.
No article update is automatic; the final ledger is a coordinator-facing
integration handoff.

## Execution, telemetry, and storage

- Up to 20 workers run concurrently, with one thread per model.
- The scheduler selects idle cores and requires at least 64 GiB available memory
  and 80 GiB free disk.
- MCMC progress is requested every 50 iterations.
- Heartbeat and stale thresholds are 1,800 seconds.
- The same run ID and run tag resume completed jobs by configuration hash.
- Every stage has a finite-metric, status, hash, and zero-binary-payload gate.
- `.rds`, `.rda`, and `.RData` payloads are pruned per job after compact CSV/JSON
  evidence is written. Final rankings, statuses, progress traces, manifests,
  hashes, and lead-level summaries are retained.
- The pipeline requires a clean, pushed, upstream-synchronized task branch and
  refuses to operate from another branch.

## Reproducibility outputs

Tracked inputs include the source contract, frozen target and metric-role
ledgers, parent requests, candidate profiles, history ledger, scripts, tests,
and a SHA-256 tracked-file manifest. Runtime outputs live under:

```text
reports/shared_fitforecast_v2_orchestration/<run_id>/
results/qdesn_mcmc_validation/
  qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1/<run_tag>/
```

The final handoff must report stage counts, run tag, confirmation decision,
promotion ledger, hashes, tests, binary-payload count, worktree/branch/HEAD, and
whether it is `READY_FOR_INTEGRATION`. It must not merge article `main` or push
an Overleaf branch.
