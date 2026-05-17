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
  invisible(TRUE)
}
