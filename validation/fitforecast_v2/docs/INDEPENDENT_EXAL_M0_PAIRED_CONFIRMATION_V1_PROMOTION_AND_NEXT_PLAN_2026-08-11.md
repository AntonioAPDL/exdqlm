# Independent exAL M0 paired confirmation: promotion and continuation plan

Date: 2026-08-11

## Scope

This document covers only the independent single-quantile Q-DESN/exQ-DESN and
DQLM/exDQLM fit-and-forecast validation. It does not govern joint-QDESN,
PriceFM, GloFAS, or other application campaigns.

The frozen source registry hash is
`edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`.
The package version is 1.0.0. The forecast contract is rolling origin without
refitting, with maximum lead 30, origin stride 30, and source indices
8501--9000 for fitting and 9001--10000 for scoring.

## Completed confirmation

Run tag:
`ind-exal-m0-paired-confirm-v1-full-20260811__git-0f0634e`

Execution commit:
`0f0634e40b5d1e320b61ad7af1464beb56546fb3`

The campaign ran three independent full-budget chains for each of two Gaussian
cells. Each chain used 5,000 burn-in iterations and 20,000 retained iterations.
All six jobs completed, all 18 required metric values were finite, all rolling
artifacts passed, and no RDS, RDA, or RData payload was retained.

The promotion rule was fixed before execution: a metric is eligible only when
all three chains succeed, all three values are finite, both the chain mean and
chain median improve the frozen v5 article value, rolling evidence passes, and
no forbidden binary payload remains. Diagnostic grades are retained but are not
used as a metric veto.

| Cell | Metric | Frozen v5 | Chain mean | Relative gain | Decision |
|---|---:|---:|---:|---:|---|
| Gaussian p=0.05 | Fit RMSE | 2.149293 | 2.491115 | -15.90% | Retain v5 |
| Gaussian p=0.05 | Forecast MAE | 3.048629 | 2.863153 | 6.08% | Promote mean |
| Gaussian p=0.05 | Forecast check loss | 1.086091 | 1.080436 | 0.52% | Promote mean |
| Gaussian p=0.50 | Fit RMSE | 1.127763 | 2.161306 | -91.65% | Retain v5 |
| Gaussian p=0.50 | Forecast MAE | 1.970704 | 2.708903 | -37.46% | Retain v5 |
| Gaussian p=0.50 | Forecast check loss | 4.058562 | 4.145879 | -2.15% | Retain v5 |

The v6 authority therefore changes exactly two numerical roles. It does not
replace the Gaussian p=0.05 fit source and does not change any p=0.50 value.
The promoted estimator is the arithmetic mean across the three full-budget
chains, not the best chain.

## Provenance correction

The model jobs were launched from execution commit `0f0634e`, but the original
closeout used the repository HEAD after a launch-record commit. The closeout
schema must preserve two distinct fields:

- `execution_commit`: immutable commit from `run.env`, verified against all six
  `fit_request.json` records;
- `closeout_commit`: commit containing the closeout implementation.

The legacy `validation_commit` field is retained as an alias for the execution
commit. This correction changes metadata only and does not rerun or alter model
outputs.

## Immutable v6 handoff

Promotion ID:
`qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811`

The handoff inherits the complete 72-row v5 interface. It freezes the six job
requests, status files, signoff summaries, fit metric rows, and lead-level
rolling forecast paths needed to reconstruct the confirmation means. It does
not freeze full parameter traces or sampler objects. Every frozen input is
listed with SHA-256 in `source_ledger.csv`.

The article may consume v6 only after the promotion verifier reports both
`ARTICLE_CONSUMPTION=PASS` and `STORAGE_POLICY=PASS`.

## Scientific diagnosis

The M0 exAL update removed implementation failures and produced valid rolling
forecasts, but it did not eliminate RHS autocorrelation. More importantly, the
short development-panel ranking did not transfer uniformly to full canonical
MCMC. Gaussian p=0.05 transferred for forecast criteria but not fit RMSE;
Gaussian p=0.50 transferred for none of the three criteria.

This rules out another global specification search and another median-first
campaign. The scientific target remains cell- and metric-specific, with lower
quantiles prioritized. VB may generate candidates, but it cannot be the sole
promotion gate because VB and MCMC rankings have repeatedly differed.

## Next calibration campaign (planned, not launched)

Priority exQ-DESN targets, in order:

1. Laplace p=0.05 fit RMSE.
2. Gaussian-mixture p=0.05 fit RMSE.
3. Gaussian-mixture p=0.25 forecast MAE.
4. Gaussian p=0.05 fit RMSE, while guarding the newly promoted forecasts.
5. Gaussian p=0.25 forecast MAE.

Priority Q-DESN AL targets are Gaussian p=0.05 for all three criteria, followed
by Laplace p=0.05 and p=0.25 fit RMSE and Gaussian-mixture p=0.05 and p=0.25 fit
RMSE. Median cells are deferred unless a later article objective explicitly
requires them.

For each target, preserve the current authoritative non-target settings and
search only axes supported by the historical response surface. Candidate
selection should use multiple development source replicates and medium-budget
MCMC, not a single short chain or VB alone. A candidate advances only when its
target metric improves without violating predeclared guardrails on already
authoritative metrics. Final promotion requires an untouched canonical source
and three full-budget chains under the same rolling-origin contract.

No next calibration job is launched by the v6 promotion workflow.
