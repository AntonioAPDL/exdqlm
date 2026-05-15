ffv2_make_m0 <- function(level0,
                         slope0,
                         seasonal_amplitudes,
                         seasonal_phases) {
  seasonal_amplitudes <- as.numeric(seasonal_amplitudes)
  seasonal_phases <- as.numeric(seasonal_phases)
  if (length(seasonal_amplitudes) != 2L || length(seasonal_phases) != 2L) {
    stop("Expected two seasonal amplitudes and two seasonal phases.", call. = FALSE)
  }
  c(
    as.numeric(level0)[1L],
    as.numeric(slope0)[1L],
    seasonal_amplitudes[1L] * cos(seasonal_phases[1L]),
    seasonal_amplitudes[1L] * sin(seasonal_phases[1L]),
    seasonal_amplitudes[2L] * cos(seasonal_phases[2L]),
    seasonal_amplitudes[2L] * sin(seasonal_phases[2L])
  )
}

ffv2_propagate_model_m0 <- function(model, start_index = 1L) {
  start_index <- as.integer(start_index)[1L]
  if (!is.finite(start_index) || start_index < 1L) {
    stop("start_index must be a positive integer.", call. = FALSE)
  }
  if (start_index == 1L) return(model)
  GG <- as.matrix(model$GG)
  m0 <- as.numeric(model$m0)
  for (step in seq_len(start_index - 1L)) {
    m0 <- as.numeric(GG %*% m0)
  }
  model$m0 <- matrix(m0, ncol = 1L)
  model$source_index_start <- start_index
  model
}

ffv2_build_dynamic_model <- function(config, train_n) {
  period <- as.integer(config$period %||% 90L)[1L]
  harmonics <- ffv2_parse_numeric_list(config$harmonics %||% "1, 2", default = c(1, 2))
  harmonics <- as.integer(harmonics)
  C0_scale <- as.numeric(config$C0_scale %||% 0.01)[1L]
  m0 <- ffv2_make_m0(
    level0 = as.numeric(config$level0 %||% 0)[1L],
    slope0 = as.numeric(config$slope0 %||% 0)[1L],
    seasonal_amplitudes = c(
      as.numeric(config$harmonic1_amplitude %||% 0)[1L],
      as.numeric(config$harmonic2_amplitude %||% 0)[1L]
    ),
    seasonal_phases = c(
      as.numeric(config$harmonic1_phase %||% 0)[1L],
      as.numeric(config$harmonic2_phase %||% 0)[1L]
    )
  )
  C0 <- diag(C0_scale, 6L)
  trend_mod <- polytrendMod(
    order = 2L,
    m0 = m0[1:2],
    C0 = C0[1:2, 1:2, drop = FALSE],
    backend = "R"
  )
  seas_mod <- seasMod(
    p = period,
    h = harmonics,
    m0 = m0[3:6],
    C0 = C0[3:6, 3:6, drop = FALSE],
    backend = "R"
  )
  model <- trend_mod + seas_mod

  # The shared source index is the scientific time origin. Each row starts the
  # model at the first fitted source index, matching the old time-origin fix.
  model <- ffv2_propagate_model_m0(model, as.integer(config$train_start_source_index)[1L])
  model$FF <- matrix(rep(as.numeric(model$FF), train_n), nrow = length(model$m0), ncol = train_n)
  model$GG <- array(rep(as.matrix(model$GG), train_n), dim = c(length(model$m0), length(model$m0), train_n))
  as.exdqlm(model)
}

ffv2_make_future_model_arrays <- function(model, horizon) {
  horizon <- as.integer(horizon)[1L]
  p <- length(model$m0)
  GG <- if (length(dim(model$GG)) == 3L) model$GG[, , dim(model$GG)[3L], drop = FALSE][, , 1L] else as.matrix(model$GG)
  FF <- if (ncol(model$FF) > 1L) model$FF[, ncol(model$FF), drop = FALSE] else as.matrix(model$FF)
  list(
    fFF = matrix(rep(as.numeric(FF), horizon), nrow = p, ncol = horizon),
    fGG = array(rep(as.matrix(GG), horizon), dim = c(p, p, horizon))
  )
}

ffv2_load_row_data <- function(config) {
  series <- ffv2_read_csv(config$series_wide_path)
  truth <- ffv2_read_truth_for_tau(config$true_quantile_grid_path, config$tau)
  if (!"source_index" %in% names(series) && "t" %in% names(series)) {
    series$source_index <- as.integer(series$t)
  }
  if (!all(c("source_index", "y") %in% names(series))) {
    stop("series_wide.csv must contain source_index/t and y.", call. = FALSE)
  }
  train_idx <- as.integer(config$train_start_source_index):as.integer(config$train_end_source_index)
  fore_idx <- as.integer(config$forecast_start_source_index):as.integer(config$forecast_end_source_index)
  train <- series[as.integer(series$source_index) %in% train_idx, , drop = FALSE]
  forecast <- series[as.integer(series$source_index) %in% fore_idx, , drop = FALSE]
  truth_train <- truth[as.integer(truth$source_index) %in% train_idx, , drop = FALSE]
  truth_fore <- truth[as.integer(truth$source_index) %in% fore_idx, , drop = FALSE]
  train <- train[order(as.integer(train$source_index)), , drop = FALSE]
  forecast <- forecast[order(as.integer(forecast$source_index)), , drop = FALSE]
  truth_train <- truth_train[order(as.integer(truth_train$source_index)), , drop = FALSE]
  truth_fore <- truth_fore[order(as.integer(truth_fore$source_index)), , drop = FALSE]
  if (nrow(train) != as.integer(config$fit_size)[1L]) {
    stop(sprintf("Training window has %d rows; expected %s.", nrow(train), config$fit_size),
         call. = FALSE)
  }
  if (nrow(forecast) != as.integer(config$forecast_horizon_max)[1L]) {
    stop(sprintf("Forecast window has %d rows; expected %s.", nrow(forecast), config$forecast_horizon_max),
         call. = FALSE)
  }
  list(
    train = data.frame(
      source_index = as.integer(train$source_index),
      y = as.numeric(train$y),
      q_true = as.numeric(truth_train$q_true),
      stringsAsFactors = FALSE
    ),
    forecast = data.frame(
      source_index = as.integer(forecast$source_index),
      horizon = seq_len(nrow(forecast)),
      y = as.numeric(forecast$y),
      q_true = as.numeric(truth_fore$q_true),
      stringsAsFactors = FALSE
    )
  )
}
