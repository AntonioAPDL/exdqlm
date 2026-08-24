ffv2_metric_interval_probs <- c(0.025, 0.5, 0.975)

ffv2_metric_interval_cfg <- function(config = list()) {
  x <- config$metric_intervals %||% list()
  enabled <- ffv2_truthy(x$enabled %||% FALSE)
  draws <- as.integer(x$draws %||% (config$budget %||% list())$metric_draws %||% 4000L)[1L]
  if (!is.finite(draws) || draws < 2L) draws <- 4000L
  list(
    enabled = enabled,
    draws = draws,
    required = ffv2_truthy(x$required %||% enabled),
    estimator_id = as.character(x$estimator_id %||%
      "posterior_mean_draw_metric_equal_tailed_95cri_v1")[1L],
    draw_source_contract = as.character(x$draw_source_contract %||%
      "conditional_quantile_not_response_predictive")[1L]
  )
}

ffv2_even_draw_indices <- function(n_available, n_keep) {
  n_available <- as.integer(n_available)[1L]
  n_keep <- as.integer(n_keep)[1L]
  if (!is.finite(n_available) || n_available < 1L) integer(0) else if (
    !is.finite(n_keep) || n_keep >= n_available
  ) {
    seq_len(n_available)
  } else {
    unique(as.integer(round(seq(1, n_available, length.out = n_keep))))
  }
}

ffv2_orient_draw_matrix <- function(draws, n_time, context) {
  if (is.null(draws)) stop(sprintf("%s draws are missing.", context), call. = FALSE)
  out <- as.matrix(draws)
  n_time <- as.integer(n_time)[1L]
  if (nrow(out) == n_time) return(out)
  if (ncol(out) == n_time) return(t(out))
  stop(sprintf(
    "%s draws have dimension %s; expected one dimension to equal %d.",
    context, paste(dim(out), collapse = "x"), n_time
  ), call. = FALSE)
}

ffv2_check_loss <- function(y, q, tau) {
  u <- y - q
  u * (tau - as.numeric(u < 0))
}

ffv2_metric_draws_from_paths <- function(fit_draws,
                                         fit_q_true,
                                         forecast_draws,
                                         forecast_q_true,
                                         forecast_y,
                                         tau,
                                         draw_indices = NULL,
                                         chain_id = 1L,
                                         draw_source = NA_character_) {
  fit_q_true <- as.numeric(fit_q_true)
  forecast_q_true <- as.numeric(forecast_q_true)
  forecast_y <- as.numeric(forecast_y)
  tau <- as.numeric(tau)[1L]
  fit_draws <- ffv2_orient_draw_matrix(fit_draws, length(fit_q_true), "fit conditional-quantile")
  forecast_draws <- ffv2_orient_draw_matrix(
    forecast_draws, length(forecast_q_true), "forecast conditional-quantile"
  )
  if (length(forecast_y) != length(forecast_q_true)) {
    stop("forecast_y and forecast_q_true must have equal lengths.", call. = FALSE)
  }
  if (length(fit_q_true) != 500L) {
    stop(sprintf("Fit interval contract requires 500 rows; found %d.", length(fit_q_true)),
         call. = FALSE)
  }
  if (length(forecast_q_true) != 1000L) {
    stop(sprintf("Forecast interval contract requires 1000 rows; found %d.",
                 length(forecast_q_true)), call. = FALSE)
  }
  n_available <- min(ncol(fit_draws), ncol(forecast_draws))
  if (is.null(draw_indices)) draw_indices <- seq_len(n_available)
  draw_indices <- as.integer(draw_indices)
  if (!length(draw_indices) || any(draw_indices < 1L | draw_indices > n_available)) {
    stop("draw_indices do not identify available aligned draws.", call. = FALSE)
  }
  fit_draws <- fit_draws[, draw_indices, drop = FALSE]
  forecast_draws <- forecast_draws[, draw_indices, drop = FALSE]
  fit_err <- sweep(fit_draws, 1L, fit_q_true, "-")
  forecast_err <- sweep(forecast_draws, 1L, forecast_q_true, "-")
  check <- vapply(seq_len(ncol(forecast_draws)), function(j) {
    mean(ffv2_check_loss(forecast_y, forecast_draws[, j], tau), na.rm = TRUE)
  }, numeric(1L))
  out <- data.frame(
    chain_id = as.integer(chain_id),
    draw_id = seq_len(ncol(fit_draws)),
    source_draw_index = draw_indices,
    fit_rmse = sqrt(colMeans(fit_err^2, na.rm = TRUE)),
    forecast_mae = colMeans(abs(forecast_err), na.rm = TRUE),
    forecast_check_loss = check,
    draw_source = as.character(draw_source),
    stringsAsFactors = FALSE
  )
  if (any(!is.finite(as.matrix(out[c("fit_rmse", "forecast_mae", "forecast_check_loss")])))) {
    stop("Metric draw table contains non-finite values.", call. = FALSE)
  }
  out
}

ffv2_metric_interval_summary <- function(metric_draws,
                                         inference = NA_character_,
                                         estimator_id = "posterior_mean_draw_metric_equal_tailed_95cri_v1") {
  required <- c("fit_rmse", "forecast_mae", "forecast_check_loss")
  missing <- setdiff(required, names(metric_draws))
  if (length(missing)) {
    stop(sprintf("Metric draw table is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  rows <- lapply(required, function(metric) {
    x <- as.numeric(metric_draws[[metric]])
    qs <- stats::quantile(x, probs = ffv2_metric_interval_probs, names = FALSE,
                          type = 8, na.rm = TRUE)
    data.frame(
      metric = metric,
      posterior_mean = mean(x, na.rm = TRUE),
      posterior_sd = stats::sd(x, na.rm = TRUE),
      cri_lower = qs[[1L]],
      posterior_median = qs[[2L]],
      cri_upper = qs[[3L]],
      posterior_mean_inside_cri = mean(x, na.rm = TRUE) >= qs[[1L]] &&
        mean(x, na.rm = TRUE) <= qs[[3L]],
      interval_probability = 0.95,
      n_draws = sum(is.finite(x)),
      n_chains = length(unique(metric_draws$chain_id %||% 1L)),
      inference = as.character(inference),
      interval_label = if (identical(tolower(as.character(inference)), "vb")) {
        "approximate_95pct_credible_interval"
      } else {
        "95pct_credible_interval"
      },
      estimator_id = estimator_id,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

ffv2_write_csv_gz <- function(x, path) {
  ffv2_ensure_dir(dirname(path))
  con <- gzfile(path, open = "wt")
  on.exit(close(con), add = TRUE)
  utils::write.csv(x, con, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ffv2_write_metric_interval_artifacts <- function(config, metric_draws) {
  cfg <- ffv2_metric_interval_cfg(config)
  if (!isTRUE(cfg$enabled)) return(invisible(NULL))
  draws_path <- as.character(config$metric_draws_path %||% "")[1L]
  summary_path <- as.character(config$metric_interval_summary_path %||% "")[1L]
  manifest_path <- as.character(config$metric_interval_manifest_path %||% "")[1L]
  if (!nzchar(draws_path) || !nzchar(summary_path) || !nzchar(manifest_path)) {
    stop("Metric interval output paths are required when intervals are enabled.", call. = FALSE)
  }
  summary <- ffv2_metric_interval_summary(
    metric_draws, inference = config$inference, estimator_id = cfg$estimator_id
  )
  if (any(summary$cri_lower > summary$posterior_median |
          summary$posterior_median > summary$cri_upper)) {
    stop("A metric interval does not contain its posterior median.", call. = FALSE)
  }
  ffv2_write_csv_gz(metric_draws, draws_path)
  ffv2_write_csv(summary, summary_path)
  manifest <- list(
    schema_version = "independent_metric_intervals_v1",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    row_key = as.character(config$row_key %||% NA_character_),
    inference = as.character(config$inference %||% NA_character_),
    estimator_id = cfg$estimator_id,
    draw_source_contract = cfg$draw_source_contract,
    fit_rows = 500L,
    forecast_rows = 1000L,
    metric_draws = nrow(metric_draws),
    chain_ids = sort(unique(as.integer(metric_draws$chain_id))),
    metric_draws_path = normalizePath(draws_path, winslash = "/", mustWork = TRUE),
    metric_draws_sha256 = ffv2_file_sha256(draws_path),
    metric_interval_summary_path = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
    metric_interval_summary_sha256 = ffv2_file_sha256(summary_path),
    heavy_binary_retained = FALSE
  )
  ffv2_write_json(manifest, manifest_path)
  invisible(manifest)
}

ffv2_dqlm_conditional_quantile_draws <- function(fit, n_draws) {
  theta <- fit$samp.theta
  if (is.null(theta) || length(dim(theta)) != 3L) {
    stop("DQLM/exDQLM fit must contain p x time x draw samp.theta.", call. = FALSE)
  }
  theta <- array(as.numeric(theta), dim = dim(theta))
  p <- dim(theta)[1L]
  n_time <- dim(theta)[2L]
  FF <- as.matrix(fit$model$FF)
  if (nrow(FF) != p && ncol(FF) == p) FF <- t(FF)
  if (nrow(FF) != p) stop("State design FF is not aligned with samp.theta.", call. = FALSE)
  if (ncol(FF) == 1L) FF <- matrix(rep(FF[, 1L], n_time), nrow = p)
  if (ncol(FF) < n_time) stop("State design FF is shorter than samp.theta.", call. = FALSE)
  idx <- ffv2_even_draw_indices(dim(theta)[3L], n_draws)
  out <- vapply(idx, function(j) {
    colSums(FF[, seq_len(n_time), drop = FALSE] * theta[, , j, drop = FALSE][, , 1L])
  }, numeric(n_time))
  out <- matrix(out, nrow = n_time, ncol = length(idx))
  attr(out, "source_draw_index") <- idx
  out
}

ffv2_latent_forecast_draws <- function(forecast, n_draws, seed) {
  n_draws <- as.integer(n_draws)[1L]
  ff <- as.numeric(forecast$ff)
  fQ <- pmax(as.numeric(forecast$fQ), 0)
  old <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    } else assign(".Random.seed", old, envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(as.integer(seed)[1L])
  sweep(matrix(stats::rnorm(length(ff) * n_draws), nrow = length(ff), ncol = n_draws),
        1L, sqrt(fQ), "*") + ff
}

ffv2_metric_chain_diagnostics <- function(metric_draws) {
  metrics <- c("fit_rmse", "forecast_mae", "forecast_check_loss")
  chains <- sort(unique(as.integer(metric_draws$chain_id)))
  if (length(chains) < 2L) return(data.frame())
  safe_ess <- function(x) {
    x <- as.numeric(x)
    if (length(x) < 3L || !all(is.finite(x))) return(NA_real_)
    if (stats::sd(x) <= sqrt(.Machine$double.eps)) return(length(x))
    tryCatch(as.numeric(coda::effectiveSize(coda::mcmc(x))),
             error = function(...) NA_real_)
  }
  rows <- lapply(metrics, function(metric) {
    series <- lapply(chains, function(chain) {
      as.numeric(metric_draws[as.integer(metric_draws$chain_id) == chain, metric])
    })
    n <- min(vapply(series, length, integer(1L)))
    series <- lapply(series, function(x) x[seq_len(n)])
    split <- unlist(lapply(series, function(x) {
      half <- floor(length(x) / 2L)
      list(x[seq_len(half)], x[half + seq_len(half)])
    }), recursive = FALSE)
    mcmc_list <- do.call(coda::mcmc.list, lapply(split, coda::mcmc))
    rhat <- tryCatch(as.numeric(coda::gelman.diag(
      mcmc_list, autoburnin = FALSE, multivariate = FALSE
    )$psrf[1L, 1L]), error = function(...) NA_real_)
    bulk_ess <- sum(vapply(series, safe_ess, numeric(1L)), na.rm = TRUE)
    pooled <- unlist(series, use.names = FALSE)
    lo <- stats::quantile(pooled, 0.025, names = FALSE, type = 8)
    hi <- stats::quantile(pooled, 0.975, names = FALSE, type = 8)
    lower_tail_ess <- sum(vapply(series, function(x) safe_ess(x <= lo), numeric(1L)),
                          na.rm = TRUE)
    upper_tail_ess <- sum(vapply(series, function(x) safe_ess(x >= hi), numeric(1L)),
                          na.rm = TRUE)
    tail_ess <- min(lower_tail_ess, upper_tail_ess)
    chain_intervals <- t(vapply(series, function(x) {
      stats::quantile(x, c(0.025, 0.975), names = FALSE, type = 8)
    }, numeric(2L)))
    pair_index <- utils::combn(seq_along(series), 2L)
    pair_overlap <- apply(pair_index, 2L, function(pair) {
      left <- max(chain_intervals[pair, 1L])
      right <- min(chain_intervals[pair, 2L])
      denom <- min(diff(chain_intervals[pair[[1L]], ]),
                   diff(chain_intervals[pair[[2L]], ]))
      if (!is.finite(denom) || denom <= 0) return(NA_real_)
      max(0, right - left) / denom
    })
    pooled_sd <- stats::sd(pooled)
    endpoint_range_sd <- if (is.finite(pooled_sd) && pooled_sd > 0) {
      max(diff(range(chain_intervals[, 1L])), diff(range(chain_intervals[, 2L]))) / pooled_sd
    } else 0
    mcse <- pooled_sd / sqrt(max(bulk_ess, 1))
    data.frame(
      metric = metric,
      chains = length(chains),
      draws_per_chain = n,
      split_rhat = rhat,
      bulk_ess = bulk_ess,
      tail_ess = tail_ess,
      mcse_mean = mcse,
      mcse_fraction_interval_width = mcse / max(hi - lo, .Machine$double.eps),
      endpoint_max_range_pooled_sd = endpoint_range_sd,
      interval_overlap_min = if (all(is.na(pair_overlap))) NA_real_ else
        min(pair_overlap, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
