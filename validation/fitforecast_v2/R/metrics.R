ffv2_path_summary <- function(row_df,
                              draws,
                              tau,
                              split_role,
                              qhat_override = NULL) {
  draws <- as.matrix(draws)
  if (nrow(draws) != nrow(row_df)) {
    stop("draw matrix rows must match row_df rows.", call. = FALSE)
  }
  tau <- as.numeric(tau)[1L]
  qhat <- if (is.null(qhat_override)) {
    as.numeric(apply(draws, 1L, stats::quantile, probs = tau, na.rm = TRUE))
  } else {
    as.numeric(qhat_override)
  }
  qs <- ffv2_quantile_columns(draws)
  out <- cbind(
    data.frame(
      split_role = split_role,
      source_index = as.integer(row_df$source_index),
      y = as.numeric(row_df$y),
      q_true = as.numeric(row_df$q_true),
      qhat = qhat,
      q_error = qhat - as.numeric(row_df$q_true),
      abs_q_error = abs(qhat - as.numeric(row_df$q_true)),
      squared_q_error = (qhat - as.numeric(row_df$q_true))^2,
      pinball_tau = ffv2_pinball(as.numeric(row_df$y), qhat, tau),
      hit = as.integer(as.numeric(row_df$y) <= qhat),
      coverage_minus_tau = as.integer(as.numeric(row_df$y) <= qhat) - tau,
      stringsAsFactors = FALSE
    ),
    qs
  )
  if ("horizon" %in% names(row_df)) out$horizon <- as.integer(row_df$horizon)
  out
}

ffv2_metric_block <- function(path_summary, prefix, horizon = NULL) {
  x <- path_summary
  if (!is.null(horizon) && "horizon" %in% names(x)) {
    x <- x[as.integer(x$horizon) <= as.integer(horizon)[1L], , drop = FALSE]
  }
  if (!nrow(x)) {
    return(stats::setNames(as.list(rep(NA_real_, 9L)), paste0(prefix, c(
      "_n", "_q_mae", "_q_rmse", "_q_bias", "_pinball_mean",
      "_hit_rate", "_coverage_minus_tau", "_q_corr", "_max_abs_q_error"
    ))))
  }
  vals <- list(
    n = nrow(x),
    q_mae = mean(abs(x$q_error), na.rm = TRUE),
    q_rmse = sqrt(mean(x$q_error^2, na.rm = TRUE)),
    q_bias = mean(x$q_error, na.rm = TRUE),
    pinball_mean = mean(x$pinball_tau, na.rm = TRUE),
    hit_rate = mean(x$hit, na.rm = TRUE),
    coverage_minus_tau = mean(x$coverage_minus_tau, na.rm = TRUE),
    q_corr = suppressWarnings(stats::cor(x$qhat, x$q_true, use = "complete.obs")),
    max_abs_q_error = max(abs(x$q_error), na.rm = TRUE)
  )
  stats::setNames(vals, paste0(prefix, "_", names(vals)))
}

ffv2_iqs_from_draws <- function(y, draws, probs = seq(0.05, 0.95, by = 0.05)) {
  draws <- as.matrix(draws)
  qs <- t(apply(draws, 1L, stats::quantile, probs = probs, na.rm = TRUE, names = FALSE))
  losses <- sapply(seq_along(probs), function(j) ffv2_pinball(y, qs[, j], probs[[j]]))
  rowMeans(losses, na.rm = TRUE)
}

ffv2_row_metrics <- function(config,
                             fit_summary,
                             forecast_summary,
                             runtime_sec,
                             status = "done",
                             health_gate = "PASS",
                             error_message = "") {
  blocks <- c(
    ffv2_metric_block(fit_summary, "fit"),
    ffv2_metric_block(forecast_summary, "forecast_h100", horizon = 100L),
    ffv2_metric_block(forecast_summary, "forecast_h1000", horizon = 1000L)
  )
  base <- list(
    row_id = as.integer(config$row_id),
    row_key = as.character(config$row_key),
    spec_id = as.character(config$spec_id %||% NA_character_),
    run_tag = as.character(config$run_tag),
    scenario_id = as.character(config$scenario_id),
    family = as.character(config$family),
    tau = as.numeric(config$tau),
    tau_label = as.character(config$tau_label),
    fit_size = as.integer(config$fit_size),
    model_variant = as.character(config$model_variant),
    inference = as.character(config$inference),
    phase = as.character(config$phase),
    validation_stage = as.character(config$validation_stage %||% NA_character_),
    status = status,
    health_gate = health_gate,
    runtime_sec = as.numeric(runtime_sec),
    error_message = error_message,
    source_cell_id = as.character(config$source_cell_id),
    series_wide_sha256 = as.character(config$series_wide_sha256),
    true_quantile_grid_sha256 = as.character(config$true_quantile_grid_sha256),
    meta_sha256 = as.character(config$meta_sha256),
    calibration_id = as.character(config$calibration_id %||% NA_character_),
    model_spec_hash = as.character(config$model_spec_hash %||% NA_character_),
    latent_clock_mode = as.character(config$latent_clock_mode %||% NA_character_),
    latent_clock_start_source_index = as.integer(config$latent_clock_start_source_index %||% NA_integer_),
    latent_clock_offset = as.integer(config$latent_clock_offset %||% NA_integer_),
    model_C0_scale = as.numeric(config$model_C0_scale %||% NA_real_),
    trend_C0_scale = as.numeric(config$trend_C0_scale %||% NA_real_),
    seasonal_C0_scale = as.numeric(config$seasonal_C0_scale %||% NA_real_),
    df_value = as.character(config$df_value %||% NA_character_),
    dim_df = as.character(config$dim_df %||% NA_character_),
    dynamic_model_period = as.integer(config$dynamic_model_period %||% config$period %||% NA_integer_),
    dynamic_model_harmonics = as.character(config$dynamic_model_harmonics %||% config$harmonics %||% NA_character_)
  )
  as.data.frame(c(base, blocks), stringsAsFactors = FALSE)
}
