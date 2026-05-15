# Internal recalibration helpers for benchmarked synthesized forecasts.

bench_qdesn_calibration_horizon <- function(fit_n, forecast_horizon, candidate_cfg, cfg) {
  fit_n <- as.integer(fit_n)[1L]
  forecast_horizon <- as.integer(forecast_horizon)[1L]
  cal_cfg <- candidate_cfg$calibration %||% list(mode = "none")
  mode <- tolower(as.character(cal_cfg$mode %||% "none")[1L])
  if (mode == "none") {
    return(0L)
  }

  min_core <- if (is.finite(cal_cfg$min_train_points)) as.integer(cal_cfg$min_train_points) else as.integer(cfg$evaluation$selection$min_train_points %||% 24L)
  min_points <- if (is.finite(cal_cfg$min_points)) as.integer(cal_cfg$min_points) else as.integer(max(6L, ceiling(forecast_horizon / 2L)))
  tail_h <- if (is.finite(cal_cfg$tail_h)) as.integer(cal_cfg$tail_h) else as.integer(forecast_horizon)
  tail_h <- min(tail_h, max(0L, fit_n - min_core))
  if (!is.finite(tail_h) || tail_h < min_points || (fit_n - tail_h) < min_core) {
    return(0L)
  }

  as.integer(tail_h)
}

bench_qdesn_fit_recalibration <- function(y_true, draws, mode = c("none", "bias", "affine")) {
  mode <- match.arg(mode)
  draws <- as.matrix(draws)
  y_true <- as.numeric(y_true)

  if (mode == "none" || !nrow(draws) || !length(y_true)) {
    return(list(mode = "none", intercept = 0, slope = 1, n_cal = 0L))
  }

  pred_mean <- rowMeans(draws)
  if (mode == "bias" || length(unique(pred_mean[is.finite(pred_mean)])) < 2L) {
    intercept <- stats::median(y_true - pred_mean, na.rm = TRUE)
    if (!is.finite(intercept)) intercept <- 0
    return(list(
      mode = "bias",
      intercept = intercept,
      slope = 1,
      n_cal = length(y_true)
    ))
  }

  X <- cbind(1, pred_mean)
  fit <- tryCatch(stats::lm.fit(X, y_true), error = function(...) NULL)
  if (is.null(fit) || any(!is.finite(fit$coefficients))) {
    intercept <- stats::median(y_true - pred_mean, na.rm = TRUE)
    if (!is.finite(intercept)) intercept <- 0
    return(list(
      mode = "bias",
      intercept = intercept,
      slope = 1,
      n_cal = length(y_true)
    ))
  }

  intercept <- as.numeric(fit$coefficients[[1L]])
  slope <- as.numeric(fit$coefficients[[2L]])
  if (!is.finite(intercept)) intercept <- 0
  if (!is.finite(slope) || slope <= 0.05) {
    intercept <- stats::median(y_true - pred_mean, na.rm = TRUE)
    if (!is.finite(intercept)) intercept <- 0
    slope <- 1
    mode <- "bias"
  }

  list(
    mode = mode,
    intercept = intercept,
    slope = slope,
    n_cal = length(y_true)
  )
}

bench_qdesn_apply_recalibration <- function(draws, recalibration) {
  draws <- as.matrix(draws)
  recalibration <- recalibration %||% list(mode = "none", intercept = 0, slope = 1)
  if ((recalibration$mode %||% "none") == "none") {
    return(draws)
  }

  as.numeric(recalibration$intercept %||% 0) + as.numeric(recalibration$slope %||% 1) * draws
}
