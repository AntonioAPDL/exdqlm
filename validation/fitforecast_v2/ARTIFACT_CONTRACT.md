# Artifact Contract

The validation artifact of record is compact CSV/JSON, not fitted R objects.

## Retained Per Row

Each completed row should retain:

- `rows/row_XXXX_status.csv`
- `health/row_XXXX_health.csv`
- `metrics/row_XXXX_metrics.csv`
- `fit_path_summaries/row_XXXX_fit_path.csv`
- `forecast_path_summaries/row_XXXX_forecast_path.csv`
- `logs/row_XXXX.log`
- `configs/row_XXXX_config.json`

## Article-Facing Interface

Both Q-DESN and exDQLM/DQLM export the same article-facing schema:

- `validation/fitforecast_v2/schema/shared_fitforecast_interface_schema.csv`
- `interfaces/exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv`
- `interfaces/qdesn_dynamic_fitforecast_v2_shared_interface.csv`

Article-Q-DESN should consume only these exported interfaces plus their
manifests after a completed smoke or staged run. Native internal fit summaries,
old fit-only outputs, and aborted run tags are not article-facing artifacts.

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

Forecast metrics are reported for both `H=100` and `H=1000`:

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
- `qhat_tau`
- `pred_mean`
- `pred_q025`
- `pred_q050`
- `pred_q500`
- `pred_q950`
- `pred_q975`
- `pinball_tau`
- `hit`
