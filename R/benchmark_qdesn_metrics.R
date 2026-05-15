# Metrics and forecast summaries for benchmarked probabilistic forecasts.

bench_qdesn_pinball_loss <- function(y, qhat, tau) {
  err <- as.numeric(y) - as.numeric(qhat)
  (tau - as.numeric(err < 0)) * err
}

bench_qdesn_crps_row <- function(y_true, draws_vec) {
  z <- sort(as.numeric(draws_vec))
  z <- z[is.finite(z)]
  m <- length(z)
  if (m < 2L || !is.finite(y_true)) {
    return(NA_real_)
  }
  mean(abs(z - y_true)) - sum((2 * seq_len(m) - m - 1) * z) / (m^2)
}

bench_qdesn_crps_vec <- function(y_true, draws_mat) {
  draws_mat <- as.matrix(draws_mat)
  stopifnot(length(y_true) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) bench_qdesn_crps_row(y_true[[i]], draws_mat[i, ]), numeric(1))
}

bench_qdesn_quantile_mat <- function(draws_mat, probs) {
  draws_mat <- as.matrix(draws_mat)
  probs <- as.numeric(probs)
  out <- vapply(
    probs,
    function(prob) {
      apply(draws_mat, 1L, stats::quantile, probs = prob, names = FALSE, na.rm = TRUE)
    },
    numeric(nrow(draws_mat))
  )
  out <- as.matrix(out)
  if (ncol(out) != length(probs)) {
    out <- matrix(out, nrow = nrow(draws_mat), ncol = length(probs))
  }
  colnames(out) <- paste0("q", formatC(probs * 100, format = "f", digits = 0, flag = "0"))
  out
}

bench_qdesn_mase_scale <- function(train_y, seasonal_period) {
  y <- as.numeric(train_y)
  y <- y[is.finite(y)]
  n <- length(y)
  s <- as.integer(seasonal_period)[1L]
  if (!is.finite(s) || s < 1L) s <- 1L

  if (s > 1L && n > s) {
    denom <- mean(abs(y[(s + 1L):n] - y[seq_len(n - s)]))
  } else if (n > 1L) {
    denom <- mean(abs(diff(y)))
  } else {
    denom <- NA_real_
  }

  if (!is.finite(denom) || denom <= 0) NA_real_ else denom
}

bench_qdesn_smape <- function(y, f) {
  num <- abs(as.numeric(f) - as.numeric(y))
  den <- abs(as.numeric(y)) + abs(as.numeric(f))
  out <- ifelse(den > 0, 200 * num / den, 0)
  as.numeric(out)
}

bench_qdesn_interval_score <- function(y, lo, hi, alpha) {
  lo <- as.numeric(lo)
  hi <- as.numeric(hi)
  y <- as.numeric(y)
  width <- hi - lo
  below <- pmax(lo - y, 0)
  above <- pmax(y - hi, 0)
  width + (2 / alpha) * below + (2 / alpha) * above
}

bench_qdesn_owa_value <- function(smape_model, mase_model, smape_naive2, mase_naive2) {
  if (!is.finite(smape_model) || !is.finite(mase_model) ||
      !is.finite(smape_naive2) || !is.finite(mase_naive2) ||
      smape_naive2 <= 0 || mase_naive2 <= 0) {
    return(NA_real_)
  }

  0.5 * ((smape_model / smape_naive2) + (mase_model / mase_naive2))
}

bench_qdesn_score_forecast <- function(bundle, model_name, draws, probs = c(0.05, 0.5, 0.95)) {
  draws <- as.matrix(draws)
  y_true <- as.numeric(bundle$eval_y)
  stopifnot(length(y_true) == nrow(draws))

  probs <- sort(unique(as.numeric(probs)))
  q_mat <- bench_qdesn_quantile_mat(draws, probs)

  q_lookup <- function(prob) {
    col <- paste0("q", formatC(prob * 100, format = "f", digits = 0, flag = "0"))
    if (!col %in% colnames(q_mat)) {
      return(apply(draws, 1L, stats::quantile, probs = prob, names = FALSE, na.rm = TRUE))
    }
    q_mat[, col]
  }

  pred_mean <- rowMeans(draws)
  pred_median <- q_lookup(0.5)
  q05 <- q_lookup(0.05)
  q10 <- q_lookup(0.10)
  q90 <- q_lookup(0.90)
  q95 <- q_lookup(0.95)
  q025 <- q_lookup(0.025)
  q975 <- q_lookup(0.975)

  crps <- bench_qdesn_crps_vec(y_true, draws)
  pinball_mean <- rowMeans(vapply(
    probs,
    function(prob) bench_qdesn_pinball_loss(y_true, q_lookup(prob), prob),
    numeric(length(y_true))
  ))

  abs_error_mean <- abs(y_true - pred_mean)
  abs_error_median <- abs(y_true - pred_median)
  sq_error_mean <- (y_true - pred_mean)^2
  mase_scale <- bench_qdesn_mase_scale(bundle$fit_y, bundle$seasonal_period)
  mase <- if (is.finite(mase_scale)) abs_error_median / mase_scale else rep(NA_real_, length(y_true))
  smape <- bench_qdesn_smape(y_true, pred_median)

  cov80 <- as.numeric(y_true >= q10 & y_true <= q90)
  cov90 <- as.numeric(y_true >= q05 & y_true <= q95)
  cov95 <- as.numeric(y_true >= q025 & y_true <= q975)
  is80 <- bench_qdesn_interval_score(y_true, q10, q90, alpha = 0.20)
  is90 <- bench_qdesn_interval_score(y_true, q05, q95, alpha = 0.10)
  is95 <- bench_qdesn_interval_score(y_true, q025, q975, alpha = 0.05)
  msis95 <- if (is.finite(mase_scale)) is95 / mase_scale else rep(NA_real_, length(y_true))
  interval_width95 <- q975 - q025
  acd95 <- abs(cov95 - 0.95)

  lead_metrics <- data.table::data.table(
    dataset = bundle$dataset,
    source_family = bundle$source_family,
    benchmark_pool = bundle$benchmark_pool,
    route_key = bundle$route_key %||% "global",
    series_id = bundle$series_id,
    stage = bundle$stage,
    benchmark_split_protocol = bundle$benchmark_split_protocol,
    selection_protocol = bundle$selection_protocol,
    model_name = model_name,
    lead = seq_along(y_true),
    y_true = y_true,
    pred_mean = pred_mean,
    pred_median = pred_median,
    q025 = q025,
    q05 = q05,
    q10 = q10,
    q50 = pred_median,
    q90 = q90,
    q95 = q95,
    q975 = q975,
    crps = crps,
    pinball_mean = pinball_mean,
    mae_mean = abs_error_mean,
    mae_median = abs_error_median,
    rmse_component = sq_error_mean,
    mase = mase,
    mase_scale = mase_scale,
    smape = smape,
    coverage80 = cov80,
    coverage90 = cov90,
    coverage95 = cov95,
    interval_score80 = is80,
    interval_score90 = is90,
    interval_score95 = is95,
    msis95 = msis95,
    interval_width95 = interval_width95,
    acd95 = acd95
  )

  series_metrics <- lead_metrics[, .(
    dataset_label = bundle$dataset_label,
    frequency_label = bundle$frequency_label,
    seasonal_period = as.integer(bundle$seasonal_period),
    forecast_horizon = as.integer(bundle$forecast_horizon),
    n_leads = .N,
    crps_mean = mean(crps, na.rm = TRUE),
    pinball_mean = mean(pinball_mean, na.rm = TRUE),
    mae_mean = mean(mae_mean, na.rm = TRUE),
    mae_median = mean(mae_median, na.rm = TRUE),
    rmse_mean = sqrt(mean(rmse_component, na.rm = TRUE)),
    mase_mean = mean(mase, na.rm = TRUE),
    smape_mean = mean(smape, na.rm = TRUE),
    coverage80_mean = mean(coverage80, na.rm = TRUE),
    coverage90_mean = mean(coverage90, na.rm = TRUE),
    coverage95_mean = mean(coverage95, na.rm = TRUE),
    interval_score80_mean = mean(interval_score80, na.rm = TRUE),
    interval_score90_mean = mean(interval_score90, na.rm = TRUE),
    interval_score95_mean = mean(interval_score95, na.rm = TRUE),
    msis95_mean = mean(msis95, na.rm = TRUE),
    interval_width95_mean = mean(interval_width95, na.rm = TRUE),
    acd95_mean = abs(mean(coverage95, na.rm = TRUE) - 0.95)
  ), by = .(
    dataset,
    source_family,
    benchmark_pool,
    route_key,
    series_id,
    stage,
    benchmark_split_protocol,
    selection_protocol,
    model_name
  )]

  forecast_summary <- data.table::data.table(
    dataset = bundle$dataset,
    source_family = bundle$source_family,
    benchmark_pool = bundle$benchmark_pool,
    route_key = bundle$route_key %||% "global",
    series_id = bundle$series_id,
    stage = bundle$stage,
    model_name = model_name,
    lead = seq_along(y_true),
    timestamp = bundle$timestamp[bundle$eval_idx],
    y_true = y_true,
    pred_mean = pred_mean,
    pred_median = pred_median,
    q025 = q025,
    q05 = q05,
    q10 = q10,
    q50 = pred_median,
    q90 = q90,
    q95 = q95,
    q975 = q975
  )

  list(
    series_metrics = series_metrics,
    lead_metrics = lead_metrics,
    forecast_summary = forecast_summary
  )
}
