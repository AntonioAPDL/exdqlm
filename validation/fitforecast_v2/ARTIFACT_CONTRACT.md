# Artifact Contract

The validation artifact of record is compact CSV/JSON, not fitted R objects.

## Retained Per Row

Each completed row should retain:

- `rows/row_XXXX_status.csv`
- `health/row_XXXX_health.csv`
- `metrics/row_XXXX_metrics.csv`
- `fit_path_summaries/row_XXXX_fit_path.csv`
- `forecast_path_summaries/row_XXXX_forecast_path.csv`
- `forecast_lead_metrics/row_XXXX_forecast_lead_metrics.csv`
- `logs/row_XXXX.log`
- `configs/row_XXXX_config.json`

## Article-Facing Interface

Both Q-DESN and exDQLM/DQLM export the same article-facing schema:

- `validation/fitforecast_v2/schema/shared_fitforecast_interface_schema.csv`
- `interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- `interfaces/qdesn_dynamic_fitforecast_v2_shared_interface.csv`

The active schema version is `rolling_origin_v3_lead_interface_v1`. Article-Q-DESN
should consume only these exported interfaces plus their manifests after a
completed smoke, micro-pilot, or staged run. Native internal fit summaries, old
fit-only outputs, and aborted run tags are not article-facing artifacts.

## Forbidden For Successful Rows

Successful rows must not retain:

- `*.rds`
- `*.rda`
- `*.RData`
- `fit.rds`
- `draws.rds`
- `forecast_objects.rds`
- `vb_init.rds`

Heavy objects are allowed only for a predeclared debug subset with an explicit
manifest and byte cap. That mode is not the default.

## Fit Metrics

- `train_qtrue_mae`
- `train_qtrue_rmse`
- `train_qtrue_bias`
- `train_qtrue_corr`
- `train_pinball_tau`
- `train_hit_rate`
- `train_hit_rate_minus_tau`
- `runtime_sec_fit`

## Forecast Metrics

Primary forecast metrics are rolling-origin lead-level metrics with:

- `forecast_protocol = rolling_origin_no_refit_state_update`
- `max_lead_configured = 30`
- `origin_stride = 30`
- `refit_per_origin = false`

Compatibility window summaries may still report `9001:9100` and `9001:10000`,
but article-facing primary comparison should use the rolling lead metrics.

- `forecast_qtrue_mae`
- `forecast_qtrue_rmse`
- `forecast_qtrue_bias`
- `forecast_qtrue_corr`
- `forecast_pinball_tau`
- `forecast_hit_rate`
- `forecast_hit_rate_minus_tau`
- `forecast_crps_iqs`
- `runtime_sec_forecast`
- `runtime_sec_total`

## Path Summary Columns

Fit and forecast path summaries include:

- `row_id`
- `source_index`
- `horizon`
- `split_role`
- `y`
- `q_true`
- `qhat`
- `q_error`
- `abs_q_error`
- `squared_q_error`
- posterior quantile summaries such as `qhat_p0025`, `qhat_p0250`,
  `qhat_p0500`, `qhat_p0750`, and `qhat_p0975`
- `pinball_tau`
- `hit`
- `coverage_minus_tau`

Rolling forecast path summaries additionally include:

- `forecast_origin_source_index`
- `forecast_lead`
- `target_source_index`
- `origin_stride`
- `max_lead_configured`
- `n_origins_for_lead`
- `state_update_method`
- `refit_per_origin`
