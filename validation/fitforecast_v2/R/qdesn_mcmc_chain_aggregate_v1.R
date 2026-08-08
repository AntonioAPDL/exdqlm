qdesn_chainagg_as_bool <- function(x) {
  if (is.logical(x)) return(replace(x, is.na(x), FALSE))
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}

qdesn_chainagg_require_columns <- function(value, required, label) {
  missing <- setdiff(required, names(value))
  if (length(missing)) {
    stop(sprintf("%s is missing columns: %s", label, paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  invisible(value)
}

qdesn_chainagg_check_loss <- function(y, qhat, tau) {
  residual <- as.numeric(y) - as.numeric(qhat)
  mean(ifelse(residual >= 0, tau * residual, (tau - 1) * residual))
}

qdesn_chainagg_assert_shared <- function(values, label, tolerance = 1e-10) {
  reference <- values[[1L]]
  for (index in seq_along(values)[-1L]) {
    if (!isTRUE(all.equal(reference, values[[index]], tolerance = tolerance,
                          check.attributes = FALSE))) {
      stop(sprintf("Chain paths disagree on %s.", label), call. = FALSE)
    }
  }
  reference
}

qdesn_chainagg_key <- function(value, columns) {
  do.call(paste, c(lapply(value[columns], as.character), sep = "::"))
}

qdesn_chainagg_read_fit_path <- function(path, train_start, train_end) {
  value <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  qdesn_chainagg_require_columns(
    value, c("source_index", "y", "q_true", "q_pred"), basename(path)
  )
  keep <- value$source_index >= train_start & value$source_index <= train_end
  if ("effective_train" %in% names(value)) {
    keep <- keep & qdesn_chainagg_as_bool(value$effective_train)
  }
  value <- value[keep, , drop = FALSE]
  value <- value[order(value$source_index), , drop = FALSE]
  expected <- seq.int(train_start, train_end)
  if (!identical(as.integer(value$source_index), expected)) {
    stop(sprintf("Fit path does not cover %d:%d exactly: %s",
                 train_start, train_end, path), call. = FALSE)
  }
  if (anyDuplicated(value$source_index) || any(!is.finite(value$q_pred))) {
    stop(sprintf("Fit path is duplicated or non-finite: %s", path), call. = FALSE)
  }
  value
}

qdesn_chainagg_read_forecast_path <- function(path, forecast_start, forecast_end,
                                               max_lead) {
  value <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  required <- c(
    "y", "q_true", "qhat", "forecast_lead", "target_source_index",
    "origin_sequence_id"
  )
  qdesn_chainagg_require_columns(value, required, basename(path))
  keep <- value$target_source_index >= forecast_start &
    value$target_source_index <= forecast_end &
    value$forecast_lead >= 1L & value$forecast_lead <= max_lead
  value <- value[keep, , drop = FALSE]
  key_columns <- c("origin_sequence_id", "forecast_lead", "target_source_index")
  value$.chainagg_key <- qdesn_chainagg_key(value, key_columns)
  value <- value[order(value$.chainagg_key), , drop = FALSE]
  if (!nrow(value) || anyDuplicated(value$.chainagg_key) || any(!is.finite(value$qhat))) {
    stop(sprintf("Forecast path is empty, duplicated, or non-finite: %s", path),
         call. = FALSE)
  }
  value
}

qdesn_chainagg_aggregate_paths <- function(chain_rows, train_start = 8501L,
                                            train_end = 9000L,
                                            forecast_start = 9001L,
                                            forecast_end = 10000L,
                                            max_lead = 30L,
                                            tau = 0.25) {
  qdesn_chainagg_require_columns(
    chain_rows,
    c("fit_quantile_path_train_file", "forecast_rolling_origin_path_file"),
    "chain inventory"
  )
  if (nrow(chain_rows) < 2L) stop("At least two chains are required.", call. = FALSE)
  fit_paths <- as.character(chain_rows$fit_quantile_path_train_file)
  forecast_paths <- as.character(chain_rows$forecast_rolling_origin_path_file)
  missing <- c(fit_paths, forecast_paths)[!file.exists(c(fit_paths, forecast_paths))]
  if (length(missing)) {
    stop(sprintf("Missing compact path file(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }

  fit <- lapply(fit_paths, qdesn_chainagg_read_fit_path,
                train_start = train_start, train_end = train_end)
  fit_index <- qdesn_chainagg_assert_shared(lapply(fit, `[[`, "source_index"),
                                                  "fit source indices")
  fit_y <- qdesn_chainagg_assert_shared(lapply(fit, `[[`, "y"), "fit observations")
  fit_truth <- qdesn_chainagg_assert_shared(lapply(fit, `[[`, "q_true"),
                                            "fit true quantiles")
  fit_matrix <- do.call(cbind, lapply(fit, `[[`, "q_pred"))
  fit_estimate <- apply(fit_matrix, 1L, stats::median)

  forecast <- lapply(
    forecast_paths, qdesn_chainagg_read_forecast_path,
    forecast_start = forecast_start, forecast_end = forecast_end,
    max_lead = max_lead
  )
  forecast_key <- qdesn_chainagg_assert_shared(
    lapply(forecast, `[[`, ".chainagg_key"), "forecast lattice keys"
  )
  forecast_y <- qdesn_chainagg_assert_shared(lapply(forecast, `[[`, "y"),
                                             "forecast observations")
  forecast_truth <- qdesn_chainagg_assert_shared(lapply(forecast, `[[`, "q_true"),
                                                 "forecast true quantiles")
  forecast_matrix <- do.call(cbind, lapply(forecast, `[[`, "qhat"))
  forecast_estimate <- apply(forecast_matrix, 1L, stats::median)

  list(
    metrics = data.frame(
      chain_count = nrow(chain_rows),
      fit_n = length(fit_estimate),
      forecast_pair_n = length(forecast_estimate),
      fit_qtrue_rmse = sqrt(mean((fit_estimate - fit_truth)^2)),
      forecast_qtrue_mae_H1000 = mean(abs(forecast_estimate - forecast_truth)),
      forecast_check_loss_H1000 = qdesn_chainagg_check_loss(
        forecast_y, forecast_estimate, tau
      ),
      stringsAsFactors = FALSE
    ),
    fit = data.frame(
      source_index = fit_index, y = fit_y, q_true = fit_truth,
      qhat_chain_median = fit_estimate, stringsAsFactors = FALSE
    ),
    forecast = data.frame(
      key = forecast_key, y = forecast_y, q_true = forecast_truth,
      qhat_chain_median = forecast_estimate, stringsAsFactors = FALSE
    )
  )
}

qdesn_chainagg_pareto <- function(value, metric_columns) {
  result <- rep(TRUE, nrow(value))
  for (index in seq_len(nrow(value))) {
    candidate <- as.numeric(value[index, metric_columns, drop = TRUE])
    for (other in setdiff(seq_len(nrow(value)), index)) {
      comparator <- as.numeric(value[other, metric_columns, drop = TRUE])
      if (all(comparator <= candidate) && any(comparator < candidate)) {
        result[[index]] <- FALSE
        break
      }
    }
  }
  result
}
