ffv2_pkg_internal <- function(name) {
  get(name, envir = asNamespace("exdqlm"), inherits = FALSE)
}

ffv2_regularize_cov <- function(x, context = "ffv2") {
  fun <- ffv2_pkg_internal(".exdqlm_regularize_cov")
  fun(x, context = context)
}

ffv2_regularize_var <- function(x, context = "ffv2") {
  fun <- ffv2_pkg_internal(".exdqlm_regularize_var")
  fun(x, context = context)
}

ffv2_exdqlm_plugin_state_update_method <- function() {
  "deterministic_plugin_filter_train_median_latent_moments"
}

ffv2_safe_finite_median <- function(x, default) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(default)
  stats::median(x)
}

ffv2_fit_plugin_pseudo_params <- function(fit, n, method = ffv2_exdqlm_plugin_state_update_method()) {
  n <- as.integer(n)[1L]
  if (!is.finite(n) || n < 0L) stop("n must be a nonnegative integer.", call. = FALSE)
  if (n == 0L) {
    return(data.frame(ex_f = numeric(0), ex_q = numeric(0), stringsAsFactors = FALSE))
  }
  if (!identical(method, ffv2_exdqlm_plugin_state_update_method())) {
    stop(sprintf("Unsupported state update method: %s", method), call. = FALSE)
  }
  p0 <- as.numeric(fit$p0)[1L]
  if (!is.finite(p0) || p0 <= 0 || p0 >= 1) {
    stop("fit$p0 must be a finite quantile level in (0, 1).", call. = FALSE)
  }

  if (isTRUE(fit$dqlm.ind)) {
    a_tau <- (1 - 2 * p0) / (p0 * (1 - p0))
    b_tau <- 2 / (p0 * (1 - p0))
    e_inv_sigma <- ffv2_as_num1((fit$sig.out %||% list())$E.inv.sigma, NA_real_)
    if (!is.finite(e_inv_sigma) || e_inv_sigma <= 0) {
      sigma <- ffv2_safe_finite_median(fit$samp.sigma, default = 1)
      e_inv_sigma <- 1 / max(sigma, .Machine$double.eps)
    }
    e_inv_v <- ffv2_safe_finite_median((fit$vts.out %||% list())$E.inv.uts, default = e_inv_sigma)
    e_inv_v <- max(e_inv_v, .Machine$double.eps)
    return(data.frame(
      ex_f = rep(a_tau / e_inv_v, n),
      ex_q = rep(b_tau / (e_inv_sigma * e_inv_v), n),
      stringsAsFactors = FALSE
    ))
  }

  gammasig <- fit$gammasig.out %||% list()
  sts <- fit$sts.out %||% list()
  vts <- fit$vts.out %||% list()
  e_invb_inv_sigma <- ffv2_as_num1(gammasig$E.invb.inv.sigma, NA_real_)
  if (!is.finite(e_invb_inv_sigma) || e_invb_inv_sigma <= 0) {
    e_invb_inv_sigma <- max(ffv2_safe_finite_median(1 / fit$samp.sigma, default = 1), .Machine$double.eps)
  }
  e_c_invb_absgam <- ffv2_as_num1(gammasig$E.c.invb.absgam, 0)
  e_a_invb_inv_sigma <- ffv2_as_num1(gammasig$E.a.invb.inv.sigma, 0)
  e_sts <- ffv2_safe_finite_median(sts$E.sts, default = 1)
  e_inv_uts <- ffv2_safe_finite_median(vts$E.inv.uts, default = 1)
  e_inv_uts <- max(e_inv_uts, .Machine$double.eps)

  ex_f <- e_c_invb_absgam * e_sts / e_invb_inv_sigma +
    e_a_invb_inv_sigma / (e_inv_uts * e_invb_inv_sigma)
  ex_q <- 1 / (e_invb_inv_sigma * e_inv_uts)
  data.frame(
    ex_f = rep(as.numeric(ex_f), n),
    ex_q = rep(max(as.numeric(ex_q), .Machine$double.eps), n),
    stringsAsFactors = FALSE
  )
}

ffv2_extend_dynamic_model_arrays <- function(model, n_extra) {
  n_extra <- as.integer(n_extra)[1L]
  if (!is.finite(n_extra) || n_extra < 0L) stop("n_extra must be a nonnegative integer.", call. = FALSE)
  if (n_extra == 0L) return(model)

  p <- length(model$m0)
  GG_last <- if (length(dim(model$GG)) == 3L) {
    model$GG[, , dim(model$GG)[3L], drop = FALSE][, , 1L]
  } else {
    as.matrix(model$GG)
  }
  FF_last <- if (is.matrix(model$FF) && ncol(model$FF) > 1L) {
    model$FF[, ncol(model$FF), drop = FALSE]
  } else {
    matrix(model$FF, nrow = p)
  }

  old_n <- if (length(dim(model$GG)) == 3L) dim(model$GG)[3L] else ncol(model$FF)
  GG_old <- array(model$GG, dim = c(p, p, old_n))
  FF_old <- matrix(model$FF, nrow = p, ncol = old_n)
  GG_new <- array(rep(as.matrix(GG_last), n_extra), dim = c(p, p, n_extra))
  FF_new <- matrix(rep(as.numeric(FF_last), n_extra), nrow = p, ncol = n_extra)

  model$GG <- array(NA_real_, dim = c(p, p, old_n + n_extra))
  model$GG[, , seq_len(old_n)] <- GG_old
  model$GG[, , old_n + seq_len(n_extra)] <- GG_new
  model$FF <- cbind(FF_old, FF_new)
  model
}

ffv2_extend_theta_filtered_state <- function(fit, y_new, method = ffv2_exdqlm_plugin_state_update_method()) {
  y_new <- as.numeric(y_new)
  n_extra <- length(y_new)
  if (n_extra == 0L) return(fit)
  if (is.null(fit$theta.out$fm) || is.null(fit$theta.out$fC)) {
    stop("fit$theta.out must contain filtered means fm and covariances fC.", call. = FALSE)
  }

  p <- length(fit$model$m0)
  old_n <- ncol(fit$theta.out$fm)
  total_n <- old_n + n_extra
  model <- ffv2_extend_dynamic_model_arrays(fit$model, n_extra)
  GG <- array(model$GG, dim = c(p, p, total_n))
  FF <- matrix(model$FF, nrow = p, ncol = total_n)
  df_mat <- make_df_mat(fit$df, fit$dim.df, p)
  pseudo <- ffv2_fit_plugin_pseudo_params(fit, n_extra, method = method)

  fm <- matrix(NA_real_, nrow = p, ncol = total_n)
  fC <- array(NA_real_, dim = c(p, p, total_n))
  fm[, seq_len(old_n)] <- as.matrix(fit$theta.out$fm)
  fC[, , seq_len(old_n)] <- array(fit$theta.out$fC, dim = c(p, p, old_n))
  sfe <- rep(NA_real_, total_n)
  old_sfe <- fit$theta.out$standard.forecast.errors %||% fit$map.standard.forecast.errors %||% NULL
  if (!is.null(old_sfe)) sfe[seq_len(min(length(old_sfe), old_n))] <- as.numeric(old_sfe)[seq_len(min(length(old_sfe), old_n))]

  for (j in seq_len(n_extra)) {
    t <- old_n + j
    a <- as.vector(GG[, , t] %*% fm[, t - 1L])
    P <- ffv2_regularize_cov(
      GG[, , t] %*% fC[, , t - 1L] %*% t(GG[, , t]),
      context = sprintf("ffv2_plugin_P_t%d", t)
    )
    R <- ffv2_regularize_cov(P + df_mat * P, context = sprintf("ffv2_plugin_R_t%d", t))
    f <- as.numeric(t(FF[, t]) %*% a + pseudo$ex_f[[j]])
    fB <- t(FF[, t]) %*% R
    q <- ffv2_regularize_var(
      fB %*% FF[, t] + pseudo$ex_q[[j]],
      context = sprintf("ffv2_plugin_q_t%d", t)
    )
    fm[, t] <- a + as.vector(t(fB)) * (y_new[[j]] - f) / q
    fC[, , t] <- ffv2_regularize_cov(
      R - (t(fB) %*% fB) / q,
      context = sprintf("ffv2_plugin_C_t%d", t)
    )
    sfe[[t]] <- (y_new[[j]] - f) / sqrt(q)
  }

  out <- fit
  out$y <- c(as.numeric(fit$y), y_new)
  out$model <- model
  out$theta.out$fm <- fm
  out$theta.out$fC <- fC
  out$theta.out$standard.forecast.errors <- sfe
  out$map.standard.forecast.errors <- sfe
  out$ffv2_state_update <- list(
    method = method,
    refit_per_origin = FALSE,
    n_original = as.integer(old_n),
    n_added = as.integer(n_extra),
    n_total = as.integer(total_n)
  )
  class(out) <- class(fit)
  out
}

ffv2_extend_fit_to_source_origin <- function(fit, config, data, origin_source_index) {
  origin_source_index <- as.integer(origin_source_index)[1L]
  train_end <- as.integer(config$train_end_source_index)[1L]
  if (!is.finite(origin_source_index) || origin_source_index < train_end) {
    stop("origin_source_index must be >= train_end_source_index.", call. = FALSE)
  }
  if (origin_source_index == train_end) return(fit)
  future_rows <- data$forecast[
    as.integer(data$forecast$source_index) <= origin_source_index,
    ,
    drop = FALSE
  ]
  expected_n <- origin_source_index - train_end
  if (nrow(future_rows) != expected_n) {
    stop(sprintf(
      "Need %d observed forecast rows through origin %d; found %d.",
      expected_n, origin_source_index, nrow(future_rows)
    ), call. = FALSE)
  }
  ffv2_extend_theta_filtered_state(fit, future_rows$y)
}

ffv2_rolling_exdqlm_forecast_summary <- function(fit,
                                                 config,
                                                 data,
                                                 hmax = NULL,
                                                 origin_stride = NULL,
                                                 n_draws = NULL,
                                                 seed = 1L,
                                                 started_at = Sys.time()) {
  hmax <- as.integer(hmax %||% config$max_lead_configured %||% config$rolling_hmax %||% 30L)[1L]
  origin_stride <- as.integer(origin_stride %||% config$origin_stride %||% hmax)[1L]
  grid <- ffv2_rolling_grid(
    initial_origin_source_index = as.integer(config$train_end_source_index)[1L],
    forecast_block_start_source_index = as.integer(config$forecast_start_source_index)[1L],
    forecast_block_end_source_index = as.integer(config$forecast_end_source_index)[1L],
    hmax = hmax,
    origin_stride = origin_stride,
    forecast_protocol = "rolling_origin_no_refit_state_update"
  )
  ffv2_validate_rolling_grid(grid, require_complete_targets = identical(origin_stride, hmax))
  origins <- sort(unique(as.integer(grid$forecast_origin_source_index)))
  n_draws <- as.integer(n_draws %||% 2000L)[1L]
  if (!is.finite(n_draws) || n_draws < 1L) n_draws <- 2000L
  rows <- list()
  row_i <- 0L
  for (origin_idx in seq_along(origins)) {
    origin <- origins[[origin_idx]]
    origin_grid <- grid[as.integer(grid$forecast_origin_source_index) == origin, , drop = FALSE]
    k <- max(as.integer(origin_grid$forecast_lead))
    fit_origin <- ffv2_extend_fit_to_source_origin(fit, config, data, origin)
    future <- ffv2_make_future_model_arrays(fit_origin$model, k)
    ffv2_record_progress(
      config,
      stage = "rolling_forecast",
      substage = "exdqlm_state_update",
      event = "progress",
      forecast_origin_current = origin_idx,
      forecast_origin_total = length(origins),
      forecast_lead_current = 0L,
      forecast_lead_total = k,
      percent_complete = 100 * (origin_idx - 1L) / length(origins),
      elapsed_seconds = ffv2_seconds(started_at),
      message = sprintf("Rolling origin %d/%d source_index=%d", origin_idx, length(origins), origin)
    )
    forecast <- exdqlmForecast(
      start.t = length(fit_origin$y),
      k = k,
      m1 = fit_origin,
      fFF = future$fFF,
      fGG = future$fGG,
      plot = FALSE,
      return.draws = TRUE,
      n.samp = n_draws,
      seed = as.integer(seed) + origin_idx
    )
    for (j in seq_len(nrow(origin_grid))) {
      lead <- as.integer(origin_grid$forecast_lead[[j]])
      target <- as.integer(origin_grid$target_source_index[[j]])
      target_row <- data$forecast[as.integer(data$forecast$source_index) == target, , drop = FALSE]
      if (nrow(target_row) != 1L) {
        stop(sprintf("Could not find exactly one forecast target row for source index %d.", target),
             call. = FALSE)
      }
      draw_row <- matrix(forecast$samp.fore[lead, ], nrow = 1L)
      qhat <- as.numeric(forecast$ff[[lead]])
      qs <- ffv2_quantile_columns(draw_row)
      row_i <- row_i + 1L
      rows[[row_i]] <- cbind(
        data.frame(
          split_role = "rolling_forecast",
          source_index = target,
          y = as.numeric(target_row$y[[1L]]),
          q_true = as.numeric(target_row$q_true[[1L]]),
          qhat = qhat,
          q_error = qhat - as.numeric(target_row$q_true[[1L]]),
          abs_q_error = abs(qhat - as.numeric(target_row$q_true[[1L]])),
          squared_q_error = (qhat - as.numeric(target_row$q_true[[1L]]))^2,
          pinball_tau = ffv2_pinball(as.numeric(target_row$y[[1L]]), qhat, as.numeric(config$tau)),
          hit = as.integer(as.numeric(target_row$y[[1L]]) <= qhat),
          coverage_minus_tau = as.integer(as.numeric(target_row$y[[1L]]) <= qhat) - as.numeric(config$tau),
          horizon = lead,
          forecast_protocol = "rolling_origin_no_refit_state_update",
          state_update_method = ffv2_exdqlm_plugin_state_update_method(),
          refit_per_origin = FALSE,
          forecast_origin_source_index = origin,
          forecast_lead = lead,
          target_source_index = target,
          origin_sequence_id = as.integer(origin_grid$origin_sequence_id[[j]]),
          origin_stride = as.integer(origin_grid$origin_stride[[j]]),
          max_lead_configured = as.integer(origin_grid$max_lead_configured[[j]]),
          n_origins_for_lead = as.integer(origin_grid$n_origins_for_lead[[j]]),
          local_start_t = length(fit_origin$y),
          stringsAsFactors = FALSE
        ),
        qs
      )
    }
  }
  ffv2_record_progress(
    config,
    stage = "rolling_forecast",
    substage = "exdqlm_state_update",
    event = "complete",
    forecast_origin_current = length(origins),
    forecast_origin_total = length(origins),
    forecast_lead_current = hmax,
    forecast_lead_total = hmax,
    percent_complete = 100,
    elapsed_seconds = ffv2_seconds(started_at),
    message = "Rolling-origin forecast completed"
  )
  out <- ffv2_bind_rows(rows)
  out[order(as.integer(out$forecast_origin_source_index), as.integer(out$forecast_lead)), , drop = FALSE]
}

ffv2_rolling_lead_metrics <- function(config, forecast_summary) {
  if (!nrow(forecast_summary)) return(data.frame())
  pieces <- lapply(split(forecast_summary, forecast_summary$forecast_lead), function(x) {
    data.frame(
      row_id = as.integer(config$row_id),
      row_key = as.character(config$row_key),
      run_tag = as.character(config$run_tag),
      forecast_protocol = "rolling_origin_no_refit_state_update",
      state_update_method = ffv2_exdqlm_plugin_state_update_method(),
      refit_per_origin = FALSE,
      model_variant = as.character(config$model_variant),
      inference = as.character(config$inference),
      family = as.character(config$family),
      tau = as.numeric(config$tau),
      fit_size = as.integer(config$fit_size),
      forecast_lead = as.integer(x$forecast_lead[[1L]]),
      origin_stride = as.integer(x$origin_stride[[1L]]),
      max_lead_configured = as.integer(x$max_lead_configured[[1L]]),
      n_origins_scored = nrow(x),
      origin_start_source_index = min(as.integer(x$forecast_origin_source_index)),
      origin_end_source_index = max(as.integer(x$forecast_origin_source_index)),
      target_start_source_index = min(as.integer(x$target_source_index)),
      target_end_source_index = max(as.integer(x$target_source_index)),
      forecast_qtrue_mae = mean(x$abs_q_error, na.rm = TRUE),
      forecast_qtrue_rmse = sqrt(mean(x$squared_q_error, na.rm = TRUE)),
      forecast_qtrue_bias = mean(x$q_error, na.rm = TRUE),
      forecast_pinball_mean = mean(x$pinball_tau, na.rm = TRUE),
      forecast_coverage = mean(x$hit, na.rm = TRUE),
      forecast_coverage_error = mean(x$coverage_minus_tau, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- ffv2_bind_rows(pieces)
  out[order(as.integer(out$forecast_lead)), , drop = FALSE]
}
