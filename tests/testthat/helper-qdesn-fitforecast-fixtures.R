make_fitforecast_compact_fixture <- function(tmp, fit_size = 500L) {
  raw_start <- if (fit_size == 500L) 8189L else 3689L
  train_start <- if (fit_size == 500L) 8501L else 4001L
  train_end <- 9000L
  forecast_start <- 9001L
  forecast_end <- 10000L
  source_index <- seq.int(raw_start, forecast_end)
  n_total <- length(source_index)
  n_context_train <- train_end - raw_start + 1L
  train_rows <- seq.int(train_start - raw_start + 1L, train_end - raw_start + 1L)
  forecast_rows <- seq.int(forecast_start - raw_start + 1L, forecast_end - raw_start + 1L)
  source_df <- data.frame(
    t = source_index,
    y = sin(source_index / 30),
    q_target = cos(source_index / 40),
    stringsAsFactors = FALSE
  )
  source_path <- file.path(tmp, "series_wide.csv")
  utils::write.csv(source_df, source_path, row.names = FALSE)

  train_df <- data.frame(
    h = seq_len(fit_size),
    p0 = 0.25,
    y = source_df$y[train_rows],
    q_true = source_df$q_target[train_rows],
    q_pred = source_df$q_target[train_rows] + 0.01,
    mu = source_df$q_target[train_rows] + 0.01,
    lo = source_df$q_target[train_rows] - 0.1,
    hi = source_df$q_target[train_rows] + 0.1,
    stringsAsFactors = FALSE
  )
  forecast_df <- data.frame(
    h = seq_len(1000L),
    p0 = 0.25,
    y = source_df$y[forecast_rows],
    q_true = source_df$q_target[forecast_rows],
    q_pred = source_df$q_target[forecast_rows] + 0.02,
    mu = source_df$q_target[forecast_rows] + 0.02,
    lo = source_df$q_target[forecast_rows] - 0.1,
    hi = source_df$q_target[forecast_rows] + 0.1,
    stringsAsFactors = FALSE
  )
  summary_obj <- list(
    summary = data.frame(n_train = n_context_train, stringsAsFactors = FALSE),
    forecast_objects = list(
      fits_fc = list(list(
        df_mu_tr = train_df,
        df_pred_tr = train_df,
        df_mu_fc = forecast_df,
        df_pred_fc = forecast_df,
        fit_train = list(meta = list(keep_idx = train_rows))
      ))
    )
  )
  root_spec <- list(
    root_id = "root_fixture",
    dataset_cell_id = "cell_fixture",
    scenario = "fitforecast_fixture",
    source_family = "normal",
    tau = 0.25,
    effective_fit_size = fit_size,
    fit_size = fit_size,
    source_total_size = n_total,
    beta_prior_type = "ridge",
    source_series_wide_path = source_path,
    train_start_source_index = train_start,
    train_end_source_index = train_end,
    forecast_start_source_index = forecast_start,
    forecast_end_source_index = forecast_end
  )
  list(summary_obj = summary_obj, root_spec = root_spec)
}
