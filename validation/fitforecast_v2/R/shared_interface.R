ffv2_shared_interface_schema_version <- function() {
  "rolling_origin_v3_lead_interface_v1"
}

ffv2_shared_interface_columns <- function() {
  c(
    "validation_contract_id", "interface_schema_version", "study_id", "run_tag", "spec_id",
    "base_spec_id", "calibration_id", "model_spec_hash",
    "model_family", "model_variant", "inference", "inference_method",
    "phase", "validation_stage", "status", "failure_stage", "failure_reason",
    "warning_count", "diagnostic_flags", "health_gate", "signoff_grade",
    "source_registry_id", "source_registry_root", "source_registry_path",
    "source_registry_hash_name", "source_registry_hash_value", "source_registry_hash",
    "source_cell_id", "scenario_id", "source_path", "source_hash",
    "true_quantile_path", "true_quantile_hash",
    "family", "dynamic_family", "tau", "tau_label",
    "fit_size", "effective_fit_size", "TT_warmup", "TT_main", "TT_total",
    "fit_size_label",
    "latent_clock_mode", "latent_clock_start_source_index", "latent_clock_offset",
    "dynamic_model_period", "dynamic_model_harmonics",
    "model_C0_scale", "trend_C0_scale", "seasonal_C0_scale", "df_value", "dim_df",
    "initial_forecast_origin_source_index",
    "train_start_source_index", "train_end_source_index",
    "forecast_protocol", "state_update_method", "refit_per_origin",
    "uses_future_observed_y_for_state", "uses_true_quantile_for_training",
    "max_lead_configured", "origin_stride",
    "forecast_origin_source_index", "forecast_start_source_index",
    "forecast_end_source_index", "forecast_block_start_source_index",
    "forecast_block_end_source_index", "forecast_block_size",
    "rolling_origin_start_source_index", "rolling_origin_end_source_index",
    "forecast_lead", "target_start_source_index", "target_end_source_index",
    "n_origins_scored",
    "forecast_h100_start_source_index",
    "forecast_h100_end_source_index", "forecast_h100_n",
    "forecast_h100_q_mae", "forecast_h100_q_rmse",
    "forecast_h100_pinball_mean", "forecast_h1000_start_source_index",
    "forecast_h1000_end_source_index", "forecast_h1000_n",
    "forecast_h1000_q_mae", "forecast_h1000_q_rmse",
    "forecast_h1000_pinball_mean", "fit_n", "fit_q_mae", "fit_q_rmse",
    "fit_pinball_mean", "fit_qtrue_mae", "fit_qtrue_rmse", "fit_qtrue_bias",
    "fit_coverage", "fit_coverage_error", "fit_interval_width_mean",
    "forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_qtrue_bias",
    "forecast_pinball_mean", "forecast_coverage", "forecast_coverage_error",
    "forecast_interval_width_mean",
    "runtime_sec_fit", "runtime_sec_forecast",
    "fit_runtime_seconds", "forecast_runtime_seconds",
    "runtime_sec_total", "runtime_sec", "row_config_path",
    "row_status_path", "row_health_path", "row_metrics_path",
    "fit_path_summary_path", "forecast_path_summary_path", "forecast_lead_metrics_path",
    "storage_policy", "artifact_manifest_path", "artifact_manifest_hash",
    "compact_path_summary_path", "compact_path_summary_hash",
    "log_path", "row_progress_path", "row_heartbeat_path",
    "progress_path", "heartbeat_path", "last_heartbeat_at",
    "last_progress_stage", "last_progress_iter", "last_progress_total_iter",
    "config_path", "config_hash",
    "package_version", "branch", "validation_branch", "commit", "validation_commit",
    "run_started_at", "run_finished_at"
  )
}

ffv2_shared_source_registry_hash_value <- function() {
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
}

ffv2_first_nonempty <- function(...) {
  vals <- list(...)
  for (val in vals) {
    if (is.null(val) || !length(val)) next
    out <- val[[1L]]
    if (!is.na(out) && nzchar(as.character(out))) return(out)
  }
  NA
}

ffv2_get_scalar <- function(metrics, manifest_row, name) {
  if (name %in% names(metrics)) return(metrics[[name]][[1L]])
  if (name %in% names(manifest_row)) return(manifest_row[[name]][[1L]])
  NA
}

ffv2_get_scalar3 <- function(primary = NULL, secondary = NULL, tertiary = NULL, name, default = NA) {
  for (src in list(primary, secondary, tertiary)) {
    if (is.null(src) || !length(src) || !name %in% names(src)) next
    val <- src[[name]]
    if (!length(val)) next
    out <- val[[1L]]
    if (!is.na(out) && nzchar(as.character(out))) return(out)
  }
  default
}

ffv2_safe_path_hash <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  ffv2_file_sha256(path)
}

ffv2_safe_read_csv <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(data.frame())
  tryCatch(ffv2_read_csv(path), error = function(e) data.frame())
}

ffv2_fit_size_label <- function(fit_size) {
  fit_size <- suppressWarnings(as.integer(fit_size)[1L])
  if (!is.finite(fit_size)) return(NA_character_)
  paste0("TT", fit_size)
}

ffv2_git_value <- function(args) {
  tryCatch(trimws(system2("git", args, stdout = TRUE, stderr = FALSE)[[1L]]), error = function(e) NA_character_)
}

ffv2_package_version_value <- function() {
  installed <- tryCatch(as.character(utils::packageVersion("exdqlm")), error = function(e) NA_character_)
  if (!is.na(installed) && nzchar(installed)) return(installed)
  repo_root <- tryCatch(
    normalizePath(system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]], winslash = "/", mustWork = TRUE),
    error = function(e) NA_character_
  )
  desc_path <- if (!is.na(repo_root) && nzchar(repo_root)) file.path(repo_root, "DESCRIPTION") else "DESCRIPTION"
  desc <- tryCatch(utils::read.dcf(desc_path), error = function(e) NULL)
  if (!is.null(desc) && "Version" %in% colnames(desc)) return(as.character(desc[1L, "Version"]))
  NA_character_
}

ffv2_last_heartbeat_values <- function(path) {
  hb <- ffv2_safe_read_heartbeat(path)
  if (is.null(hb)) {
    return(list(
      last_heartbeat_at = NA_character_,
      last_progress_stage = NA_character_,
      last_progress_iter = NA_integer_,
      last_progress_total_iter = NA_integer_
    ))
  }
  list(
    last_heartbeat_at = ffv2_as_chr1(hb$timestamp),
    last_progress_stage = ffv2_as_chr1(hb$stage),
    last_progress_iter = ffv2_as_int1(hb$current_iter),
    last_progress_total_iter = ffv2_as_int1(hb$total_iter)
  )
}

ffv2_safe_read_heartbeat <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NULL)
  tryCatch(ffv2_read_heartbeat(path), error = function(e) NULL)
}

ffv2_shared_interface_rows_for_metric <- function(metrics, manifest_row) {
  lead_path <- ffv2_first_nonempty(
    ffv2_get_scalar(metrics, manifest_row, "forecast_lead_metrics_path"),
    ffv2_get_scalar(metrics, manifest_row, "forecast_lead_metrics"),
    ffv2_get_scalar(metrics, manifest_row, "forecast_lead_metrics_file")
  )
  lead_metrics <- ffv2_safe_read_csv(lead_path)
  if (!nrow(lead_metrics)) lead_metrics <- data.frame(.no_lead_metrics = TRUE)

  rows <- vector("list", nrow(lead_metrics))
  for (j in seq_len(nrow(lead_metrics))) {
    lead_row <- lead_metrics[j, , drop = FALSE]
    required <- ffv2_shared_interface_columns()
    row <- as.data.frame(as.list(stats::setNames(rep(NA_character_, length(required)), required)),
                         stringsAsFactors = FALSE)
    for (nm in required) {
      row[[nm]] <- ffv2_get_scalar3(lead_row, metrics, manifest_row, nm)
    }
    row$validation_contract_id <- ffv2_first_nonempty(
      row$validation_contract_id,
      "qdesn_exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface"
    )
    row$interface_schema_version <- ffv2_first_nonempty(
      row$interface_schema_version,
      ffv2_shared_interface_schema_version()
    )
    row$validation_stage <- ffv2_first_nonempty(row$validation_stage, "all")
    row$model_family <- ffv2_first_nonempty(row$model_family, "exdqlm_dqlm")
    row$inference <- ffv2_first_nonempty(row$inference, row$inference_method)
    row$inference_method <- ffv2_first_nonempty(row$inference_method, row$inference)
    row$failure_reason <- ffv2_first_nonempty(
      row$failure_reason,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "error_message")
    )
    row$failure_stage <- ffv2_first_nonempty(
      row$failure_stage,
      if (isTRUE(startsWith(as.character(row$status), "failed"))) as.character(row$status) else NA_character_
    )
    row$warning_count <- ffv2_first_nonempty(row$warning_count, 0L)
    row$diagnostic_flags <- ffv2_first_nonempty(row$diagnostic_flags, "")
    row$source_registry_root <- ffv2_first_nonempty(
      row$source_registry_root,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "source_root"),
      "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
    )
    row$source_registry_hash_name <- ffv2_first_nonempty(
      row$source_registry_hash_name,
      "000__bundle_manifest.json.sha256"
    )
    row$source_registry_hash_value <- ffv2_first_nonempty(
      row$source_registry_hash_value,
      ffv2_shared_source_registry_hash_value()
    )
    row$source_registry_id <- ffv2_first_nonempty(
      row$source_registry_id,
      "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
    )
    row$source_registry_path <- ffv2_first_nonempty(row$source_registry_path, row$source_registry_root)
    row$source_registry_hash <- ffv2_first_nonempty(row$source_registry_hash, row$source_registry_hash_value)
    row$source_path <- ffv2_first_nonempty(
      row$source_path,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "series_wide_path"),
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "source_series_wide_path")
    )
    row$source_hash <- ffv2_first_nonempty(
      row$source_hash,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "series_wide_sha256"),
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "source_sim_sha256")
    )
    row$true_quantile_path <- ffv2_first_nonempty(
      row$true_quantile_path,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "true_quantile_grid_path"),
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "source_true_quantile_grid_path")
    )
    row$true_quantile_hash <- ffv2_first_nonempty(
      row$true_quantile_hash,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "true_quantile_grid_sha256")
    )
    row$dynamic_family <- ffv2_first_nonempty(row$dynamic_family, row$family)
    row$effective_fit_size <- ffv2_first_nonempty(row$effective_fit_size, row$fit_size)
    row$fit_size_label <- ffv2_first_nonempty(row$fit_size_label, ffv2_fit_size_label(row$effective_fit_size))
    row$initial_forecast_origin_source_index <- ffv2_first_nonempty(
      row$initial_forecast_origin_source_index,
      row$forecast_origin_source_index,
      row$train_end_source_index,
      9000L
    )
    row$forecast_protocol <- ffv2_first_nonempty(
      row$forecast_protocol,
      "rolling_origin_no_refit_state_update"
    )
    row$state_update_method <- ffv2_first_nonempty(
      row$state_update_method,
      ffv2_exdqlm_plugin_state_update_method()
    )
    row$refit_per_origin <- ffv2_first_nonempty(row$refit_per_origin, FALSE)
    row$uses_future_observed_y_for_state <- ffv2_first_nonempty(
      row$uses_future_observed_y_for_state,
      TRUE
    )
    row$uses_true_quantile_for_training <- ffv2_first_nonempty(
      row$uses_true_quantile_for_training,
      FALSE
    )
    row$max_lead_configured <- ffv2_first_nonempty(row$max_lead_configured, 30L)
    row$origin_stride <- ffv2_first_nonempty(row$origin_stride, 30L)
    row$forecast_origin_source_index <- ffv2_first_nonempty(
      row$forecast_origin_source_index,
      row$initial_forecast_origin_source_index
    )
    row$forecast_block_start_source_index <- ffv2_first_nonempty(
      row$forecast_block_start_source_index,
      row$forecast_start_source_index,
      9001L
    )
    row$forecast_block_end_source_index <- ffv2_first_nonempty(
      row$forecast_block_end_source_index,
      row$forecast_end_source_index,
      10000L
    )
    row$forecast_block_size <- ffv2_first_nonempty(
      row$forecast_block_size,
      suppressWarnings(as.integer(row$forecast_block_end_source_index) -
                         as.integer(row$forecast_block_start_source_index) + 1L)
    )
    row$rolling_origin_start_source_index <- ffv2_first_nonempty(
      row$rolling_origin_start_source_index,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "origin_start_source_index"),
      row$forecast_origin_source_index
    )
    row$rolling_origin_end_source_index <- ffv2_first_nonempty(
      row$rolling_origin_end_source_index,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "origin_end_source_index"),
      row$forecast_origin_source_index
    )
    row$forecast_lead <- ffv2_first_nonempty(
      row$forecast_lead,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "horizon")
    )
    row$target_start_source_index <- ffv2_first_nonempty(
      row$target_start_source_index,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "source_index")
    )
    row$target_end_source_index <- ffv2_first_nonempty(
      row$target_end_source_index,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "source_index")
    )
    row$n_origins_scored <- ffv2_first_nonempty(
      row$n_origins_scored,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "n_origins_for_lead")
    )
    row$forecast_h100_start_source_index <- ffv2_first_nonempty(row$forecast_h100_start_source_index, row$forecast_start_source_index)
    row$forecast_h100_end_source_index <- ffv2_first_nonempty(row$forecast_h100_end_source_index, 9100L)
    row$forecast_h1000_start_source_index <- ffv2_first_nonempty(row$forecast_h1000_start_source_index, row$forecast_start_source_index)
    row$forecast_h1000_end_source_index <- ffv2_first_nonempty(row$forecast_h1000_end_source_index, row$forecast_end_source_index)
    row$fit_qtrue_mae <- ffv2_first_nonempty(
      row$fit_qtrue_mae,
      row$fit_q_mae,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "train_qtrue_mae")
    )
    row$fit_qtrue_rmse <- ffv2_first_nonempty(
      row$fit_qtrue_rmse,
      row$fit_q_rmse,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "train_qtrue_rmse")
    )
    row$fit_qtrue_bias <- ffv2_first_nonempty(
      row$fit_qtrue_bias,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "fit_q_bias"),
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "train_qtrue_bias")
    )
    row$fit_coverage <- ffv2_first_nonempty(
      row$fit_coverage,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "fit_hit_rate")
    )
    row$fit_coverage_error <- ffv2_first_nonempty(
      row$fit_coverage_error,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "fit_coverage_minus_tau")
    )
    row$forecast_qtrue_mae <- ffv2_first_nonempty(
      row$forecast_qtrue_mae,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "forecast_q_mae")
    )
    row$forecast_qtrue_rmse <- ffv2_first_nonempty(
      row$forecast_qtrue_rmse,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "forecast_q_rmse")
    )
    row$forecast_qtrue_bias <- ffv2_first_nonempty(
      row$forecast_qtrue_bias,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "forecast_q_bias")
    )
    row$forecast_pinball_mean <- ffv2_first_nonempty(
      row$forecast_pinball_mean,
      ffv2_get_scalar3(lead_row, metrics, manifest_row, "forecast_pinball_tau")
    )
    row$runtime_sec_total <- ffv2_first_nonempty(row$runtime_sec_total, row$runtime_sec)
    row$fit_runtime_seconds <- ffv2_first_nonempty(row$fit_runtime_seconds, row$runtime_sec_fit)
    row$forecast_runtime_seconds <- ffv2_first_nonempty(row$forecast_runtime_seconds, row$runtime_sec_forecast)
    row$storage_policy <- ffv2_first_nonempty(row$storage_policy, "compact_success_only")
    row$compact_path_summary_path <- ffv2_first_nonempty(
      row$compact_path_summary_path,
      row$forecast_lead_metrics_path,
      row$forecast_path_summary_path,
      row$fit_path_summary_path
    )
    row$compact_path_summary_hash <- ffv2_first_nonempty(
      row$compact_path_summary_hash,
      ffv2_safe_path_hash(row$compact_path_summary_path)
    )
    row$artifact_manifest_hash <- ffv2_first_nonempty(
      row$artifact_manifest_hash,
      ffv2_safe_path_hash(row$artifact_manifest_path)
    )
    row$progress_path <- ffv2_first_nonempty(row$progress_path, row$row_progress_path)
    row$heartbeat_path <- ffv2_first_nonempty(row$heartbeat_path, row$row_heartbeat_path)
    hb <- ffv2_last_heartbeat_values(row$heartbeat_path)
    row$last_heartbeat_at <- ffv2_first_nonempty(row$last_heartbeat_at, hb$last_heartbeat_at)
    row$last_progress_stage <- ffv2_first_nonempty(row$last_progress_stage, hb$last_progress_stage)
    row$last_progress_iter <- ffv2_first_nonempty(row$last_progress_iter, hb$last_progress_iter)
    row$last_progress_total_iter <- ffv2_first_nonempty(row$last_progress_total_iter, hb$last_progress_total_iter)
    row$config_path <- ffv2_first_nonempty(row$config_path, row$row_config_path)
    row$config_hash <- ffv2_first_nonempty(row$config_hash, ffv2_safe_path_hash(row$config_path))
    row$package_version <- ffv2_first_nonempty(row$package_version, ffv2_package_version_value())
    row$branch <- ffv2_first_nonempty(row$branch, ffv2_git_value(c("rev-parse", "--abbrev-ref", "HEAD")))
    row$validation_branch <- ffv2_first_nonempty(row$validation_branch, row$branch)
    row$commit <- ffv2_first_nonempty(row$commit, ffv2_git_value(c("rev-parse", "HEAD")))
    row$validation_commit <- ffv2_first_nonempty(row$validation_commit, row$commit)
    rows[[j]] <- row
  }
  ffv2_bind_rows(rows)
}

ffv2_export_shared_interface <- function(manifest, out_csv) {
  rows <- list()
  for (i in seq_len(nrow(manifest))) {
    path <- manifest$row_metrics_path[[i]]
    if (!file.exists(path)) next
    metrics <- tryCatch(ffv2_read_csv(path), error = function(e) NULL)
    if (is.null(metrics) || !nrow(metrics)) next
    manifest_row <- manifest[i, , drop = FALSE]
    rows[[length(rows) + 1L]] <- ffv2_shared_interface_rows_for_metric(
      metrics[1L, , drop = FALSE],
      manifest_row
    )
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
