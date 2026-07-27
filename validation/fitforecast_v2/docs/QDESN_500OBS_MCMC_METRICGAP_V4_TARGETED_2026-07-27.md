# Q-DESN 500-Observation MCMC Metric-Gap v4 Targeted Screen

## Purpose

This campaign targets the remaining independent Q-DESN/exQ-DESN RHS MCMC
simulation-study rows whose current metric envelope is still more than 10
percent worse than the matched DQLM/exDQLM reference on at least one article
metric.

It is deliberately not a global-specification search. The calibration unit is
the family x quantile x likelihood row because the current evidence shows
different bottlenecks across cells.

## Current Diagnosis

The current article-facing MCMC metric envelope is:

```text
validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_metric_envelope_20260727/
```

The source handoff is:

```text
validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_metric_envelope_20260727/qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_targeted_screening_handoff.csv
```

That handoff contains 18 Q-DESN/exQ-DESN RHS rows. At the v4 threshold
`worst_ratio_to_external_best >= 1.10`, 15 rows remain targeted and 3 rows are
frozen.

The frozen source registry hash is:

```text
edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275
```

## Why This Is The Right Next Step

Earlier VB and MCMC screens showed that VB ranking is not always predictive of
MCMC ranking. The scientific target is also metric-specific: fit RMSE can be
weak in one row while the forecast metrics are already competitive, and the
reverse happens in other rows. A broad but unfocused global design would spend
compute on cells that are already adequate and would blur the diagnosis.

The v4 screen therefore does three things:

1. Keeps the frozen registry, TT500 fit window, rolling-origin forecast design,
   likelihood family, RHS prior family, and storage-light policy unchanged.
2. Targets only rows whose current Q-DESN/exQ-DESN metric envelope is still
   outside the 10 percent tolerance band versus DQLM/exDQLM.
3. Tests a controlled breakout from the compact-design plateau: larger memory,
   width, and depth are allowed, but paired with much smaller `rhs_tau0`, low
   `alpha`, high `rho`, and sparse reservoir/input probabilities.

## Candidate Arms

Each targeted row receives five candidates:

| Arm | Role | Reason |
| --- | --- | --- |
| 1 | current metric-source anchor | Retain the best known metric source for continuity. |
| 2 | anchor with `rhs_tau0 = 1e-6` | Test whether stronger global shrinkage fixes variance without structural change. |
| 3 | high-memory sparse | Increase memory and width under low `alpha`, high `rho`, and `rhs_tau0 = 1e-6`. |
| 4 | deep sparse | Test deeper reservoirs with tight shrinkage for nonlinear structure. |
| 5 | wide tight-shrinkage | Test a wider two-layer compromise using `rhs_tau0 = 3e-6`. |

The v4 exploratory p/n gate is `p_over_n_tt500 <= 1.60`. This is intentionally
larger than earlier compact screens, but still bounded for TT500 stability.

## Budgets

Screening budget:

```text
n_burn = 2000
n_mcmc = 8000
thin = 1
progress_every = 50
```

Confirmation budget:

```text
n_burn = 5000
n_mcmc = 20000
thin = 1
```

The screening run can identify improved candidates, but article promotion still
requires a closeout and, for any strong claim, a full-budget confirmation.

## Storage-Light Contract

The stage keeps:

- scalar fit metrics;
- scalar rolling-origin forecast metrics;
- compact path summaries;
- configs, manifests, status, and logs.

The stage does not routinely keep:

- posterior draws;
- forecast objects;
- VB-initialization payloads;
- full failure RDS payloads.

## Prepared Artifacts

Materialization script:

```text
scripts/materialize_qdesn_tt500_mcmc_metricgap_v4_targeted.R
```

Orchestrator:

```text
scripts/orchestrate_qdesn_tt500_mcmc_metricgap_v4_targeted.R
```

Prelaunch outputs:

```text
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_defaults.yaml
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_profiles.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_cell_assignments.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_grid.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_target_spec_ids.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted_materialization_manifest.json
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v4_targeted_prelaunch_20260727/
```

Prelaunch test:

```text
validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-metricgap-v4-targeted.R
```

## Safe Launch Commands

Materialize only:

```bash
Rscript scripts/materialize_qdesn_tt500_mcmc_metricgap_v4_targeted.R --workers 24
```

Prepare-only:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_metricgap_v4_targeted.R \
  --prepare-only \
  --skip-materialize \
  --workers 24
```

Full staged launch, after committing the materialized artifacts:

```bash
Rscript scripts/orchestrate_qdesn_tt500_mcmc_metricgap_v4_targeted.R \
  --full \
  --launch-approved \
  --skip-materialize \
  --workers 24
```

The full command runs prepare-only and a one-spec smoke before launching the
75-spec MCMC screen in a detached tmux session.

## Closeout Rule

After completion, close out v4 by comparing each candidate against the current
metric envelope row-by-row. Improved candidates should be classified by metric,
status retained, and provenance recorded. The article-facing table should not be
updated directly from this screening stage unless a separate confirmation
contract explicitly allows it.
