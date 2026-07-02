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

ffv2_model_clock_mode <- function(config) {
  models <- config$models %||% list()
  mode <- as.character(ffv2_first_model_value(
    config$latent_clock_mode,
    models$latent_clock_mode,
    default = "source_index_only"
  ))[1L]
  if (is.na(mode) || !nzchar(mode)) mode <- "source_index_only"
  allowed <- c("source_index_only", "post_warmup_source_index", "explicit")
  if (!mode %in% allowed) {
    stop(sprintf("latent_clock_mode must be one of: %s", paste(allowed, collapse = ", ")),
         call. = FALSE)
  }
  mode
}

ffv2_positive_scalar <- function(x, name) {
  out <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(out) || out <= 0) {
    stop(sprintf("%s must be a positive finite scalar.", name), call. = FALSE)
  }
  out
}

ffv2_first_model_value <- function(..., default = NULL) {
  vals <- list(...)
  for (val in vals) {
    if (is.null(val) || !length(val)) next
    one <- val[[1L]]
    if (is.na(one)) next
    if (is.character(one) && !nzchar(one)) next
    return(val)
  }
  default
}

ffv2_int_scalar <- function(x, name) {
  out <- suppressWarnings(as.integer(x)[1L])
  if (!is.finite(out)) stop(sprintf("%s must be a finite integer.", name), call. = FALSE)
  out
}

ffv2_model_clock_start_index <- function(config) {
  models <- config$models %||% list()
  explicit <- config$latent_clock_start_source_index %||% models$latent_clock_start_source_index %||% NULL
  if (!is.null(explicit) && length(explicit) && !is.na(explicit[[1L]]) && nzchar(as.character(explicit[[1L]]))) {
    out <- ffv2_int_scalar(explicit, "latent_clock_start_source_index")
    if (out < 1L) stop("latent_clock_start_source_index must be positive.", call. = FALSE)
    return(out)
  }

  mode <- ffv2_model_clock_mode(config)
  train_start <- ffv2_int_scalar(config$train_start_source_index, "train_start_source_index")
  if (mode == "explicit") {
    stop("latent_clock_mode='explicit' requires latent_clock_start_source_index.", call. = FALSE)
  }
  if (mode == "source_index_only") return(train_start)

  warmup <- ffv2_int_scalar(config$TT_warmup %||% 0L, "TT_warmup")
  train_start + warmup
}

ffv2_model_clock_offset <- function(config) {
  ffv2_model_clock_start_index(config) -
    ffv2_int_scalar(config$train_start_source_index, "train_start_source_index")
}

ffv2_model_C0_scales <- function(config) {
  models <- config$models %||% list()
  base <- ffv2_positive_scalar(
    ffv2_first_model_value(config$model_C0_scale, models$C0_scale, config$C0_scale, default = 0.01),
    "model_C0_scale"
  )
  trend <- ffv2_positive_scalar(
    ffv2_first_model_value(config$trend_C0_scale, models$trend_C0_scale, default = base),
    "trend_C0_scale"
  )
  seasonal <- ffv2_positive_scalar(
    ffv2_first_model_value(config$seasonal_C0_scale, models$seasonal_C0_scale, default = base),
    "seasonal_C0_scale"
  )
  list(model_C0_scale = base, trend_C0_scale = trend, seasonal_C0_scale = seasonal)
}

ffv2_parse_numeric_config_value <- function(x, default) {
  if (is.null(x) || !length(x)) return(default)
  x <- unlist(x, use.names = FALSE)
  if (length(x) == 1L && is.character(x) && grepl(",", x, fixed = TRUE)) {
    x <- trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
  }
  out <- suppressWarnings(as.numeric(x))
  out <- out[is.finite(out)]
  if (!length(out)) default else out
}

ffv2_model_df_label <- function(config) {
  models <- config$models %||% list()
  df <- ffv2_parse_numeric_config_value(models$df_value %||% config$df_value, default = 0.98)
  paste(format(df, trim = TRUE, scientific = FALSE), collapse = ",")
}

ffv2_model_dim_df_label <- function(config) {
  models <- config$models %||% list()
  dim_df <- as.integer(ffv2_parse_numeric_config_value(models$dim_df %||% config$dim_df, default = c(2L, 4L)))
  paste(dim_df, collapse = ",")
}

ffv2_sync_model_provenance <- function(config) {
  models <- config$models %||% list()
  scales <- ffv2_model_C0_scales(config)
  config$calibration_id <- as.character(
    config$calibration_id %||% models$calibration_id %||% "baseline"
  )[1L]
  config$latent_clock_mode <- ffv2_model_clock_mode(config)
  config$latent_clock_start_source_index <- ffv2_model_clock_start_index(config)
  config$latent_clock_offset <- ffv2_model_clock_offset(config)
  config$model_C0_scale <- scales$model_C0_scale
  config$trend_C0_scale <- scales$trend_C0_scale
  config$seasonal_C0_scale <- scales$seasonal_C0_scale
  config$df_value <- ffv2_model_df_label(config)
  config$dim_df <- ffv2_model_dim_df_label(config)
  config$dynamic_model_period <- as.integer(config$period %||% 90L)[1L]
  config$dynamic_model_harmonics <- as.character(config$harmonics %||% "1, 2")[1L]
  spec_fields <- c(
    calibration_id = config$calibration_id,
    latent_clock_mode = config$latent_clock_mode,
    latent_clock_start_source_index = as.character(config$latent_clock_start_source_index),
    latent_clock_offset = as.character(config$latent_clock_offset),
    model_C0_scale = as.character(config$model_C0_scale),
    trend_C0_scale = as.character(config$trend_C0_scale),
    seasonal_C0_scale = as.character(config$seasonal_C0_scale),
    df_value = config$df_value,
    dim_df = config$dim_df,
    dynamic_model_period = as.character(config$dynamic_model_period),
    dynamic_model_harmonics = config$dynamic_model_harmonics
  )
  config$model_spec_hash <- ffv2_hash_string(
    paste(names(spec_fields), spec_fields, sep = "=", collapse = "\n"),
    n = 14L
  )
  config
}

ffv2_build_dynamic_model <- function(config, train_n) {
  config <- ffv2_sync_model_provenance(config)
  period <- as.integer(config$period %||% 90L)[1L]
  harmonics <- ffv2_parse_numeric_list(config$harmonics %||% "1, 2", default = c(1, 2))
  harmonics <- as.integer(harmonics)
  C0_scales <- ffv2_model_C0_scales(config)
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
  C0 <- diag(c(rep(C0_scales$trend_C0_scale, 2L), rep(C0_scales$seasonal_C0_scale, 4L)), 6L)
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

  # New prepared runs use the post-warmup latent clock. Historical row configs
  # without latent_clock_mode keep the old source_index_only behavior.
  model <- ffv2_propagate_model_m0(model, ffv2_model_clock_start_index(config))
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
