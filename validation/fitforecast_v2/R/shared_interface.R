ffv2_shared_interface_columns <- function() {
  c(
    "validation_contract_id", "study_id", "run_tag", "model_family",
    "model_variant", "inference", "phase", "status", "failure_reason",
    "health_gate", "signoff_grade", "source_registry_root",
    "source_registry_hash_name", "source_registry_hash_value",
    "source_cell_id", "scenario_id", "family", "tau", "tau_label",
    "fit_size", "effective_fit_size", "TT_warmup", "TT_main", "TT_total",
    "train_start_source_index", "train_end_source_index",
    "forecast_origin_source_index", "forecast_start_source_index",
    "forecast_end_source_index", "forecast_h100_start_source_index",
    "forecast_h100_end_source_index", "forecast_h100_n",
    "forecast_h100_q_mae", "forecast_h100_q_rmse",
    "forecast_h100_pinball_mean", "forecast_h1000_start_source_index",
    "forecast_h1000_end_source_index", "forecast_h1000_n",
    "forecast_h1000_q_mae", "forecast_h1000_q_rmse",
    "forecast_h1000_pinball_mean", "fit_n", "fit_q_mae", "fit_q_rmse",
    "fit_pinball_mean", "runtime_sec_fit", "runtime_sec_forecast",
    "runtime_sec_total", "runtime_sec", "row_config_path",
    "row_status_path", "row_health_path", "row_metrics_path",
    "fit_path_summary_path", "forecast_path_summary_path", "log_path",
    "artifact_manifest_path", "package_version", "branch", "commit",
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

ffv2_git_value <- function(args) {
  tryCatch(trimws(system2("git", args, stdout = TRUE, stderr = FALSE)[[1L]]), error = function(e) NA_character_)
}

ffv2_export_shared_interface <- function(manifest, out_csv) {
  rows <- list()
  for (i in seq_len(nrow(manifest))) {
    path <- manifest$row_metrics_path[[i]]
    if (!file.exists(path)) next
    metrics <- tryCatch(ffv2_read_csv(path), error = function(e) NULL)
    if (is.null(metrics) || !nrow(metrics)) next
    manifest_row <- manifest[i, , drop = FALSE]
    required <- ffv2_shared_interface_columns()
    row <- as.data.frame(as.list(stats::setNames(rep(NA_character_, length(required)), required)),
                         stringsAsFactors = FALSE)
    for (nm in required) row[[nm]] <- ffv2_get_scalar(metrics, manifest_row, nm)
    row$validation_contract_id <- ffv2_first_nonempty(
      row$validation_contract_id,
      "qdesn_exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface"
    )
    row$model_family <- ffv2_first_nonempty(row$model_family, "exdqlm_dqlm")
    row$failure_reason <- ffv2_first_nonempty(row$failure_reason, row$error_message)
    row$source_registry_root <- ffv2_first_nonempty(
      row$source_registry_root,
      row$source_root,
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
    row$effective_fit_size <- ffv2_first_nonempty(row$effective_fit_size, row$fit_size)
    row$forecast_h100_start_source_index <- ffv2_first_nonempty(row$forecast_h100_start_source_index, row$forecast_start_source_index)
    row$forecast_h100_end_source_index <- ffv2_first_nonempty(row$forecast_h100_end_source_index, 9100L)
    row$forecast_h1000_start_source_index <- ffv2_first_nonempty(row$forecast_h1000_start_source_index, row$forecast_start_source_index)
    row$forecast_h1000_end_source_index <- ffv2_first_nonempty(row$forecast_h1000_end_source_index, row$forecast_end_source_index)
    row$runtime_sec_total <- ffv2_first_nonempty(row$runtime_sec_total, row$runtime_sec)
    row$package_version <- ffv2_first_nonempty(row$package_version, utils::packageDescription("exdqlm")$Version)
    row$branch <- ffv2_first_nonempty(row$branch, ffv2_git_value(c("rev-parse", "--abbrev-ref", "HEAD")))
    row$commit <- ffv2_first_nonempty(row$commit, ffv2_git_value(c("rev-parse", "HEAD")))
    rows[[length(rows) + 1L]] <- row
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
