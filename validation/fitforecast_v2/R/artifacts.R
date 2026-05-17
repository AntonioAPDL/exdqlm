ffv2_required_metric_columns <- function() {
  c(
    "row_id", "row_key", "run_tag", "scenario_id", "family", "tau",
    "fit_size", "model_variant", "inference", "phase", "status",
    "health_gate", "runtime_sec", "fit_q_mae", "forecast_h100_q_mae",
    "forecast_h1000_q_mae"
  )
}

ffv2_required_path_columns <- function() {
  c(
    "split_role", "source_index", "y", "q_true", "qhat", "q_error",
    "abs_q_error", "squared_q_error", "pinball_tau", "hit",
    "coverage_minus_tau"
  )
}

ffv2_validate_metrics_schema <- function(x) {
  missing <- setdiff(ffv2_required_metric_columns(), names(x))
  if (length(missing)) {
    stop(sprintf("Metric schema missing column(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_validate_path_schema <- function(x) {
  missing <- setdiff(ffv2_required_path_columns(), names(x))
  if (length(missing)) {
    stop(sprintf("Path summary schema missing column(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_row_artifact_manifest <- function(config,
                                       paths,
                                       status = "done") {
  paths <- paths[!vapply(paths, is.null, logical(1))]
  artifacts <- lapply(names(paths), function(role) {
    path <- as.character(paths[[role]] %||% "")[1L]
    exists <- nzchar(path) && file.exists(path)
    info <- if (exists) file.info(path) else NULL
    data.frame(
      role = role,
      path = path,
      exists = exists,
      sha256 = if (exists) ffv2_file_sha256(path) else NA_character_,
      bytes = if (exists) as.numeric(info$size[[1L]]) else NA_real_,
      storage_class = if (grepl("handoff|[.]rds$|[.]rda$|[.]RData$", path, ignore.case = TRUE)) {
        "heavy_or_transient_not_article_facing"
      } else {
        "storage_light_article_evidence"
      },
      stringsAsFactors = FALSE
    )
  })
  artifact_df <- ffv2_bind_rows(artifacts)
  manifest <- list(
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    validation_contract_id = "qdesn_exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface",
    interface_schema_version = ffv2_shared_interface_schema_version(),
    run_tag = as.character(config$run_tag %||% NA_character_),
    row_id = as.integer(config$row_id %||% NA_integer_),
    row_key = as.character(config$row_key %||% NA_character_),
    spec_id = as.character(config$spec_id %||% NA_character_),
    status = as.character(status %||% NA_character_),
    storage_policy = "compact_success_only",
    artifacts = artifact_df
  )
  manifest_path <- as.character(config$artifact_manifest_path %||% "")[1L]
  if (nzchar(manifest_path)) ffv2_write_json(manifest, manifest_path)
  invisible(manifest)
}

ffv2_status_row <- function(config,
                            status,
                            started_at,
                            finished_at = Sys.time(),
                            runtime_sec = ffv2_seconds(started_at, finished_at),
                            health_gate = NA_character_,
                            error_message = "") {
  data.frame(
    row_id = as.integer(config$row_id),
    row_key = as.character(config$row_key),
    spec_id = as.character(config$spec_id %||% NA_character_),
    run_tag = as.character(config$run_tag),
    status = status,
    phase = as.character(config$phase),
    validation_stage = as.character(config$validation_stage %||% NA_character_),
    model_variant = as.character(config$model_variant),
    inference = as.character(config$inference),
    fit_size = as.integer(config$fit_size),
    family = as.character(config$family),
    tau = as.numeric(config$tau),
    started_at = format(started_at, "%Y-%m-%d %H:%M:%S %Z"),
    finished_at = format(finished_at, "%Y-%m-%d %H:%M:%S %Z"),
    runtime_sec = as.numeric(runtime_sec),
    health_gate = health_gate,
    error_message = error_message,
    stringsAsFactors = FALSE
  )
}

ffv2_write_row_artifacts <- function(config,
                                     health,
                                     metrics,
                                     fit_path,
                                     forecast_path,
                                     status) {
  ffv2_validate_metrics_schema(metrics)
  ffv2_validate_path_schema(fit_path)
  ffv2_validate_path_schema(forecast_path)
  ffv2_write_csv(health, config$row_health_path)
  ffv2_write_csv(metrics, config$row_metrics_path)
  ffv2_write_csv(fit_path, config$fit_path_summary_path)
  ffv2_write_csv(forecast_path, config$forecast_path_summary_path)
  ffv2_write_csv(status, config$row_status_path)
  ffv2_row_artifact_manifest(
    config,
    paths = list(
      row_status_path = config$row_status_path,
      row_health_path = config$row_health_path,
      row_metrics_path = config$row_metrics_path,
      fit_path_summary_path = config$fit_path_summary_path,
      forecast_path_summary_path = config$forecast_path_summary_path,
      forecast_lead_metrics_path = config$forecast_lead_metrics_path,
      row_progress_path = config$row_progress_path,
      row_heartbeat_path = config$row_heartbeat_path,
      log_path = config$log_path,
      row_config_path = config$row_config_path
    ),
    status = if ("status" %in% names(status)) tail(status$status, 1L) else "done"
  )
  invisible(TRUE)
}
