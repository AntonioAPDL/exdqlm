ffv2_shared_interface_columns <- function() {
  c(
    "study_id", "run_tag", "row_id", "row_key", "scenario_id", "family",
    "tau", "tau_label", "fit_size", "model_variant", "inference", "phase",
    "status", "health_gate", "runtime_sec", "source_cell_id",
    "series_wide_sha256", "true_quantile_grid_sha256", "meta_sha256",
    "fit_n", "fit_q_mae", "fit_q_rmse", "fit_pinball_mean",
    "forecast_h100_n", "forecast_h100_q_mae", "forecast_h100_q_rmse",
    "forecast_h100_pinball_mean", "forecast_h1000_n",
    "forecast_h1000_q_mae", "forecast_h1000_q_rmse",
    "forecast_h1000_pinball_mean"
  )
}

ffv2_export_shared_interface <- function(manifest, out_csv) {
  rows <- list()
  for (i in seq_len(nrow(manifest))) {
    path <- manifest$row_metrics_path[[i]]
    if (!file.exists(path)) next
    metrics <- tryCatch(ffv2_read_csv(path), error = function(e) NULL)
    if (is.null(metrics) || !nrow(metrics)) next
    metrics$study_id <- manifest$study_id[[i]]
    rows[[length(rows) + 1L]] <- metrics[1L, , drop = FALSE]
  }
  out <- ffv2_bind_rows(rows)
  required <- ffv2_shared_interface_columns()
  for (nm in setdiff(required, names(out))) {
    out[[nm]] <- if (nrow(out)) NA else character(0)
  }
  out <- out[, c(required, setdiff(names(out), required)), drop = FALSE]
  ffv2_stop_stale_paths(out)
  ffv2_write_csv(out, out_csv)
  out
}
