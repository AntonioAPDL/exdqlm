# Q-DESN Nested Final-Origin MCMC Confirmation Closeout

## Identity

- Run tag: `qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-bd4da62`
- Design: `qdesn_500obs_mcmc_nested_final_origin9000_v1_design_20260730`
- Stage: `qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1`
- Source-loaded package: `exdqlm` version `1.0.0`.
- Package loading: `pkgload::load_all(repo_root)` from this worktree.
- Source-registry SHA-256: `edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275`
- Frozen confirmation origin: 9000.
- Training source indices: 8501--9000.
- Forecast source indices: 9001--10000.

## Completion

- Successful roots: 8/8.
- Complete MCMC seed fits: 16/16.
- Complete replicated model/family/quantile cells: 4/4.
- Retained heavy model payloads: 0.

## Cell Results

| Model | Family | Tau | Fit RMSE | Forecast MAE H=1000 | Forecast check loss H=1000 | Fit/parent | MAE/parent | Check/parent | PASS/WARN/FAIL | Promote |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| qdesn_al_rhs_ns | gausmix | 0.50 | 1.2996 | 2.7829 | 5.6724 | 1.057 | 1.010 | 1.007 | 1/3/0 | NO |
| qdesn_al_rhs_ns | laplace | 0.05 | 5.3978 | 4.8785 | 1.9069 | 1.014 | 1.037 | 1.010 | 1/3/0 | NO |
| qdesn_al_rhs_ns | normal | 0.05 | 2.8536 | 8.8692 | 1.2854 | 1.005 | 1.186 | 1.052 | 3/1/0 | NO |
| qdesn_exal_rhs_ns | normal | 0.25 | 1.8378 | 3.7485 | 3.4341 | 1.045 | 1.202 | 1.020 | 0/0/4 | NO |

Ratios below one improve on the current parent metric. Diagnostic grades are
reported but do not suppress finite metrics.

## Decision

- Decision: `NO_CONFIRMED_COHERENT_ARTICLE_REFRESH`.
- Coherently promotable cells: 0/4.
- Externally competitive cells: 0/4.
- Article-refresh metric rows: 0.
- The final-origin evidence does not justify changing article values.
- Origin 9000 has now been evaluated and must not be reused as an untouched
  confirmation origin for further tuning.

## Next Safe Scientific Step

1. Diagnose source-window and DGP heterogeneity without fitting new models.
2. Select future candidates by robust performance across multiple predeclared
   pre-confirmation origins, not by a pooled two-origin median alone.
3. Reserve a fresh simulation replicate or source seed as the next untouched
   confirmation sample before any additional MCMC promotion.
4. Keep the current article-facing parent rows unchanged unless a future
   confirmation passes the frozen coherent-promotion contract.

## Invalid Run

The tag `qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-6582f87` is `ABORTED_INVALID_CONTRACT` and is not consumable. Its
per-fit request used 100 rather than 200 posterior predictive draws.
