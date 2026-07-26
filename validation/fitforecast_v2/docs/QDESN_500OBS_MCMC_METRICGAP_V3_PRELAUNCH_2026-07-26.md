# Q-DESN 500-Observation MCMC Metric-Gap v3 Prelaunch

## Scope

This package prepares the next independent Q-DESN / exQ-DESN RHS calibration
screen. It does not launch compute and it does not search for one global DESN
specification. Calibration remains specific to:

```text
family x quantile x likelihood
```

The stage stub is:

```text
qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3
```

## Evidence And Diagnosis

The article-facing metric envelope is:

```text
validation/fitforecast_v2/promotions/qdesn_dqlm_500obs_mcmc_metric_envelope_20260726
```

Its screening handoff identifies 16 unresolved Q-DESN / exQ-DESN cells and two
resolved cells. The resolved cells are Q-DESN AL-RHS and exQ-DESN exAL-RHS for
the Laplace family at the median. Both already beat the best DQLM/exDQLM
reference on fit RMSE, forecast MAE, and forecast check loss, so they are frozen
out of this screen.

The completed per-case v2 campaign supplied 90 comparable MCMC candidates.
Parameter-pattern auditing found:

| Outcome | Compact winner count |
|---|---:|
| Fit RMSE | 18 / 18 |
| Forecast MAE | 14 / 18 |
| Forecast check loss | 13 / 18 |

Here, compact means a one-layer design with at most 12 reservoir weights and at
most three response lags. High-memory or high-capacity designs supplied no fit
RMSE winner, no forecast-MAE winner, and only one forecast-check winner. They
also generated materially more WARN/FAIL diagnostics. Repeating a broad
high-capacity search would therefore spend substantial MCMC compute in a region
that the current protocol has already disfavored.

## Design

Each unresolved cell receives five candidate arms:

1. The exact profile that currently supplies the cell's limiting metric.
2. A case-local perturbation around that profile.
3. A compact one-layer boundary design.
4. A small two-layer mechanism contrast.
5. A moderate-memory bridge with tighter RHS shrinkage.

Fit-gap cells receive shrinkage and compact-capacity perturbations. Forecast-gap
cells receive controlled memory and persistence perturbations. Family and
quantile determine the exact width, lag count, leak rate, spectral radius,
sparsity, and `tau0`; the final winner remains cell-specific.

The design intentionally avoids the previous uncontrolled combination of large
depth, width, and memory. It still tests depth and memory, but within
`p / n <= 0.5` and with stronger RHS shrinkage.

## Successive-Halving Contract

The first stage is candidate screening:

```text
n_burn = 2000
n_mcmc = 8000
thin = 1
candidate roots = 16 cells x 5 arms = 80
workers prepared = 20
```

Screening chooses one candidate per unresolved cell. Screening-budget metrics
are not article-facing.

The second stage is full confirmation:

```text
n_burn = 5000
n_mcmc = 20000
thin = 1
candidate roots = at most 16
```

Only full-confirmation results may enter a later metric envelope or article
table. Diagnostic status remains attached to every metric even when candidate
selection is status-agnostic.

## Fixed Protocol

The source and forecast contract is unchanged:

```text
fit window:              source indices 8501:9000
forecast origin:         source index 9000
forecast block:          source indices 9001:10000
rolling max lead:        30
rolling origin stride:   30
refit at each origin:    false
```

All roots use the same frozen source registry and hashes as the current
article-facing metric envelope.

## Storage And Telemetry

```text
progress_every = 50
init_from_vb = true
keep_draws = false
keep_mcmc_vb_init = false
save_forecast_objects = false
retain_full_rds_on_failure = false
```

VB is used only to initialize each MCMC fit. It does not rank candidates and
does not decide promotion.

## Materialization

```bash
Rscript scripts/materialize_qdesn_tt500_mcmc_metricgap_v3_prelaunch.R \
  --workers 20 \
  --stamp 20260726
```

Expected outputs:

```text
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_profiles.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_cell_assignments.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_defaults.yaml
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_grid.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_target_spec_ids.csv
config/validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3_materialization_manifest.json
validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_metricgap_v3_prelaunch_20260726/
```

## Launch Gates

The prepared package must pass, in order:

1. Focused testthat checks.
2. A prepare-only manifest audit.
3. One tiny MCMC smoke root.
4. Smoke artifact and storage audit.
5. Explicit human approval for the 80-root screening run.
6. Cell-by-cell screening closeout.
7. Explicit human approval for full confirmation.

This prelaunch package stops before gate 2. No prepare-only, smoke, or full
screen has been launched.
