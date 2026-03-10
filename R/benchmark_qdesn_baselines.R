# Baseline forecasters for benchmark comparisons.

bench_qdesn_baseline_names <- function(cfg = NULL) {
  requested <- cfg$evaluation$baselines$models %||% c("naive", "seasonal_naive", "naive2", "drift")
  as.character(unlist(requested, use.names = FALSE))
}

bench_qdesn_baseline_available <- function(model_name) {
  model_name <- as.character(model_name)[1L]
  if (model_name %in% c("naive", "seasonal_naive", "naive2", "drift", "mean")) {
    return(TRUE)
  }
  if (model_name %in% c("ses", "holt", "damped", "theta", "comb", "ets", "auto_arima")) {
    return(requireNamespace("forecast", quietly = TRUE))
  }
  FALSE
}

bench_qdesn_bootstrap_matrix <- function(h, n_draws, sim_fun) {
  out <- replicate(n_draws, sim_fun(), simplify = "matrix")
  out <- as.matrix(out)
  if (nrow(out) != h) {
    out <- matrix(out, nrow = h, ncol = n_draws)
  }
  out
}

bench_qdesn_fc_draws_from_intervals <- function(point, lower95 = NULL, upper95 = NULL, n_draws = 500L) {
  point <- as.numeric(point)
  h <- length(point)
  n_draws <- as.integer(n_draws)[1L]
  lower95 <- as.numeric(lower95 %||% rep(NA_real_, h))
  upper95 <- as.numeric(upper95 %||% rep(NA_real_, h))

  sd_hat <- (upper95 - point) / stats::qnorm(0.975)
  sd_hat[!is.finite(sd_hat) | sd_hat <= 0] <- stats::sd(point)
  sd_hat[!is.finite(sd_hat) | sd_hat <= 0] <- 1e-8

  matrix(
    stats::rnorm(h * n_draws, mean = rep(point, n_draws), sd = rep(sd_hat, n_draws)),
    nrow = h,
    ncol = n_draws
  )
}

bench_qdesn_seasonality_test <- function(train_y, seasonal_period) {
  y <- as.numeric(train_y)
  y <- y[is.finite(y)]
  n <- length(y)
  s <- as.integer(seasonal_period)[1L]

  if (!is.finite(s) || s <= 1L || n <= (s + 2L)) {
    return(FALSE)
  }

  acf_vals <- as.numeric(stats::acf(y, lag.max = s, plot = FALSE, na.action = na.pass)$acf)[-1L]
  if (length(acf_vals) < s) {
    return(FALSE)
  }

  clim <- stats::qnorm(0.95) / sqrt(n) * sqrt(cumsum(c(1, 2 * acf_vals[seq_len(max(1L, s - 1L))]^2)))
  abs(acf_vals[[s]]) > clim[[s]]
}

bench_qdesn_naive2_components <- function(train_y, h, seasonal_period) {
  y <- as.numeric(train_y)
  h <- as.integer(h)[1L]
  s <- as.integer(seasonal_period)[1L]

  if (!is.finite(s) || s <= 1L || !bench_qdesn_seasonality_test(y, s) || length(y) <= (2L * s)) {
    return(list(
      adjusted = y,
      future_season = rep(1, h),
      mode = "none"
    ))
  }

  ts_y <- stats::ts(y, frequency = s)
  use_multiplicative <- all(y > 0, na.rm = TRUE)
  decomp_type <- if (use_multiplicative) "multiplicative" else "additive"
  decomp <- tryCatch(
    stats::decompose(ts_y, type = decomp_type),
    error = function(...) NULL
  )
  if (is.null(decomp) || all(!is.finite(decomp$seasonal))) {
    return(list(
      adjusted = y,
      future_season = rep(1, h),
      mode = "none"
    ))
  }

  seasonal_hist <- as.numeric(decomp$seasonal)
  future_season <- rep(tail(seasonal_hist, s), length.out = h)
  if (decomp_type == "multiplicative") {
    seasonal_hist[!is.finite(seasonal_hist) | seasonal_hist == 0] <- 1
    future_season[!is.finite(future_season) | future_season == 0] <- 1
    adjusted <- y / seasonal_hist
  } else {
    seasonal_hist[!is.finite(seasonal_hist)] <- 0
    future_season[!is.finite(future_season)] <- 0
    adjusted <- y - seasonal_hist
  }

  list(
    adjusted = adjusted,
    future_season = future_season,
    mode = decomp_type
  )
}

bench_qdesn_reseasonalize <- function(x, future_season, mode = c("none", "multiplicative", "additive")) {
  mode <- match.arg(mode)
  x <- as.matrix(x)
  seasonal_mat <- matrix(rep(as.numeric(future_season), ncol(x)), nrow = nrow(x), ncol = ncol(x))
  if (mode == "multiplicative") {
    x * seasonal_mat
  } else if (mode == "additive") {
    x + seasonal_mat
  } else {
    x
  }
}

bench_qdesn_run_baseline <- function(model_name, train_y, h, seasonal_period, n_draws = 500L, seed = NULL) {
  model_name <- as.character(model_name)[1L]
  train_y <- as.numeric(train_y)
  h <- as.integer(h)[1L]
  n_draws <- as.integer(n_draws)[1L]
  s <- as.integer(seasonal_period)[1L]
  if (!is.finite(s) || s < 1L) s <- 1L

  if (!is.null(seed)) set.seed(as.integer(seed))

  n <- length(train_y)
  if (n < 2L) {
    stop("Baselines require at least two training observations.", call. = FALSE)
  }

  if (model_name == "naive") {
    point <- rep(train_y[[n]], h)
    residuals <- diff(train_y)
    if (!length(residuals) || all(!is.finite(residuals))) residuals <- 0
    residuals <- residuals[is.finite(residuals)]
    if (!length(residuals)) residuals <- 0

    draws <- bench_qdesn_bootstrap_matrix(h, n_draws, function() {
      path <- numeric(h)
      cur <- train_y[[n]]
      for (i in seq_len(h)) {
        cur <- cur + sample(residuals, 1L, replace = TRUE)
        path[[i]] <- cur
      }
      path
    })
  } else if (model_name == "naive2") {
    comp <- bench_qdesn_naive2_components(train_y, h = h, seasonal_period = s)
    base_res <- bench_qdesn_run_baseline(
      model_name = "naive",
      train_y = comp$adjusted,
      h = h,
      seasonal_period = 1L,
      n_draws = n_draws,
      seed = seed
    )
    point <- as.numeric(bench_qdesn_reseasonalize(matrix(base_res$point, nrow = h, ncol = 1L), comp$future_season, comp$mode))
    draws <- bench_qdesn_reseasonalize(base_res$draws, comp$future_season, comp$mode)
  } else if (model_name == "seasonal_naive") {
    if (s <= 1L || n <= s) {
      return(bench_qdesn_run_baseline("naive", train_y, h, seasonal_period = 1L, n_draws = n_draws, seed = seed))
    }
    anchor <- rep(tail(train_y, s), length.out = h)
    residuals <- train_y[(s + 1L):n] - train_y[seq_len(n - s)]
    residuals <- residuals[is.finite(residuals)]
    if (!length(residuals)) residuals <- 0
    point <- anchor
    draws <- bench_qdesn_bootstrap_matrix(h, n_draws, function() {
      anchor + sample(residuals, h, replace = TRUE)
    })
  } else if (model_name == "drift") {
    drift_step <- (train_y[[n]] - train_y[[1L]]) / (n - 1L)
    point <- train_y[[n]] + drift_step * seq_len(h)
    residuals <- diff(train_y) - drift_step
    residuals <- residuals[is.finite(residuals)]
    if (!length(residuals)) residuals <- 0
    draws <- bench_qdesn_bootstrap_matrix(h, n_draws, function() {
      path <- numeric(h)
      cur <- train_y[[n]]
      for (i in seq_len(h)) {
        cur <- cur + drift_step + sample(residuals, 1L, replace = TRUE)
        path[[i]] <- cur
      }
      path
    })
  } else if (model_name == "mean") {
    mu_hat <- mean(train_y)
    sigma_hat <- stats::sd(train_y)
    if (!is.finite(sigma_hat) || sigma_hat <= 0) sigma_hat <- 1e-8
    point <- rep(mu_hat, h)
    draws <- matrix(stats::rnorm(h * n_draws, mean = mu_hat, sd = sigma_hat), nrow = h, ncol = n_draws)
  } else if (model_name %in% c("ses", "holt", "damped", "theta", "comb", "ets", "auto_arima")) {
    if (!requireNamespace("forecast", quietly = TRUE)) {
      stop(sprintf("Baseline '%s' requires the forecast package.", model_name), call. = FALSE)
    }

    if (model_name == "comb") {
      comp_names <- c("ses", "holt", "damped")
      comp_res <- lapply(comp_names, function(name) {
        bench_qdesn_run_baseline(name, train_y, h, seasonal_period = s, n_draws = n_draws, seed = seed)
      })
      point <- Reduce(`+`, lapply(comp_res, `[[`, "point")) / length(comp_res)
      draws <- Reduce(`+`, lapply(comp_res, `[[`, "draws")) / length(comp_res)
    } else {
      fit <- switch(
        model_name,
        ets = forecast::ets(train_y),
        auto_arima = forecast::auto.arima(train_y),
        ses = NULL,
        holt = NULL,
        damped = NULL,
        theta = NULL
      )

      fc <- switch(
        model_name,
        ses = forecast::ses(train_y, h = h, level = c(80, 95)),
        holt = forecast::holt(train_y, h = h, damped = FALSE, level = c(80, 95)),
        damped = forecast::holt(train_y, h = h, damped = TRUE, level = c(80, 95)),
        theta = forecast::thetaf(train_y, h = h, level = c(80, 95)),
        ets = forecast::forecast(fit, h = h, level = c(80, 95)),
        auto_arima = forecast::forecast(fit, h = h, level = c(80, 95))
      )

      point <- as.numeric(fc$mean)
      if (model_name %in% c("ets", "auto_arima")) {
        draws <- bench_qdesn_bootstrap_matrix(h, n_draws, function() {
          as.numeric(stats::simulate(fit, nsim = h, future = TRUE, bootstrap = TRUE))
        })
      } else {
        upper95 <- as.numeric(fc$upper[, ncol(fc$upper), drop = TRUE])
        lower95 <- as.numeric(fc$lower[, ncol(fc$lower), drop = TRUE])
        draws <- bench_qdesn_fc_draws_from_intervals(point, lower95 = lower95, upper95 = upper95, n_draws = n_draws)
      }
    }
  } else {
    stop(sprintf("Unknown baseline '%s'.", model_name), call. = FALSE)
  }

  list(
    model_name = model_name,
    draws = as.matrix(draws),
    point = as.numeric(point)
  )
}
