`%||%` <- function(a, b) if (is.null(a)) b else a

dynamic_dgp_prob_label <- function(x, digits = 2L) {
  vals <- as.numeric(x)
  vapply(vals, function(one) {
    gsub("\\.", "p", format(one, nsmall = digits, digits = digits + 2L, trim = TRUE))
  }, character(1))
}

dynamic_dgp_make_m0 <- function(level0,
                                slope0,
                                seasonal_amplitudes,
                                seasonal_phases) {
  seasonal_amplitudes <- as.numeric(seasonal_amplitudes)
  seasonal_phases <- as.numeric(seasonal_phases)
  if (length(seasonal_amplitudes) != 2L || any(!is.finite(seasonal_amplitudes))) {
    stop("seasonal_amplitudes must be a finite numeric vector of length 2.", call. = FALSE)
  }
  if (length(seasonal_phases) != 2L || any(!is.finite(seasonal_phases))) {
    stop("seasonal_phases must be a finite numeric vector of length 2.", call. = FALSE)
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

.dynamic_dgp_resolve_m0 <- function(params) {
  m0_raw <- params[["m0", exact = TRUE]]
  if (!is.null(m0_raw)) {
    m0 <- as.numeric(m0_raw)
    if (length(m0) != 6L || any(!is.finite(m0))) {
      stop("params$m0 must be a finite numeric vector of length 6.", call. = FALSE)
    }
    return(m0)
  }
  dynamic_dgp_make_m0(
    level0 = params$level0 %||% 0,
    slope0 = params$slope0 %||% 0,
    seasonal_amplitudes = params$seasonal_amplitudes %||% c(0, 0),
    seasonal_phases = params$seasonal_phases %||% c(0, 0)
  )
}

.dynamic_dgp_resolve_C0 <- function(params) {
  C0_raw <- params[["C0", exact = TRUE]]
  if (!is.null(C0_raw)) {
    C0 <- as.matrix(C0_raw)
    if (!identical(dim(C0), c(6L, 6L)) || any(!is.finite(C0))) {
      stop("params$C0 must be a finite 6x6 matrix.", call. = FALSE)
    }
    return(C0)
  }
  C0_scale <- as.numeric(params[["C0_scale", exact = TRUE]] %||% 25)[1L]
  if (!is.finite(C0_scale) || C0_scale <= 0) {
    stop("params$C0_scale must be a positive finite scalar.", call. = FALSE)
  }
  diag(C0_scale, 6L)
}

build_dynamic_dgp_matched_model <- function(params, TT = NULL, backend = c("auto", "R", "cpp")) {
  backend <- match.arg(backend)
  period <- as.integer(params[["period", exact = TRUE]] %||% 50L)[1L]
  harmonics <- as.integer(unlist(params[["harmonics", exact = TRUE]] %||% c(1L, 2L), use.names = FALSE))
  harmonics <- harmonics[is.finite(harmonics) & harmonics > 0L]
  if (!is.finite(period) || period < 2L) {
    stop("params$period must be an integer >= 2.", call. = FALSE)
  }
  if (!length(harmonics)) {
    stop("params$harmonics must contain at least one positive harmonic.", call. = FALSE)
  }
  m0 <- .dynamic_dgp_resolve_m0(params)
  C0 <- .dynamic_dgp_resolve_C0(params)
  no_trend <- isTRUE(params[["no_trend", exact = TRUE]])

  if (no_trend) {
    trend_mod <- as.exdqlm(list(
      m0 = matrix(m0[1:2], ncol = 1L),
      C0 = C0[1:2, 1:2, drop = FALSE],
      FF = matrix(c(1, 0), ncol = 1L),
      GG = diag(2L)
    ))
  } else {
    trend_mod <- polytrendMod(order = 2L, m0 = m0[1:2], C0 = C0[1:2, 1:2, drop = FALSE], backend = backend)
  }

  seas_mod <- seasMod(
    p = period,
    h = harmonics,
    m0 = m0[3:6],
    C0 = C0[3:6, 3:6, drop = FALSE],
    backend = backend
  )

  model <- trend_mod + seas_mod
  model
}

simulate_dynamic_dgp_latent_path <- function(model,
                                             TT,
                                             W_sd,
                                             seed,
                                             initial_state_mode = c("deterministic_m0", "sample_C0")) {
  initial_state_mode <- match.arg(initial_state_mode)
  TT <- as.integer(TT)[1L]
  if (!is.finite(TT) || TT < 1L) {
    stop("TT must be a positive integer.", call. = FALSE)
  }
  W_sd <- as.numeric(W_sd)
  if (length(W_sd) != length(model$m0) || any(!is.finite(W_sd)) || any(W_sd < 0)) {
    stop(sprintf("W_sd must be a finite numeric vector of length %d with non-negative entries.", length(model$m0)), call. = FALSE)
  }

  GG <- as.matrix(model$GG)
  FF <- as.numeric(model$FF)
  k <- length(model$m0)
  set.seed(as.integer(seed)[1L])

  if (identical(initial_state_mode, "sample_C0")) {
    chol_C0 <- tryCatch(chol(as.matrix(model$C0)), error = function(e) NULL)
    if (is.null(chol_C0)) {
      stop("model$C0 must be positive definite when initial_state_mode='sample_C0'.", call. = FALSE)
    }
    theta_prev <- as.numeric(model$m0) + drop(t(chol_C0) %*% stats::rnorm(k))
  } else {
    theta_prev <- as.numeric(model$m0)
  }

  theta <- matrix(NA_real_, nrow = TT, ncol = k)
  for (tt in seq_len(TT)) {
    eta <- stats::rnorm(k, sd = W_sd)
    theta_curr <- as.numeric(GG %*% theta_prev + eta)
    theta[tt, ] <- theta_curr
    theta_prev <- theta_curr
  }

  list(
    theta = theta,
    mu = as.numeric(theta %*% FF),
    W_sd = W_sd,
    initial_state_mode = initial_state_mode,
    theta0 = theta[1L, , drop = TRUE]
  )
}

dynamic_dgp_normal_quantile_shift <- function(tau, sigma) {
  stats::qnorm(as.numeric(tau)[1L], mean = 0, sd = as.numeric(sigma)[1L])
}

dynamic_dgp_laplace_quantile_shift <- function(tau, scale) {
  tau <- as.numeric(tau)[1L]
  scale <- as.numeric(scale)[1L]
  if (tau < 0.5) {
    scale * log(2 * tau)
  } else {
    -scale * log(2 * (1 - tau))
  }
}

.dynamic_dgp_gausmix_cdf <- function(x, sigma, weights, offset) {
  weights[1L] * stats::pnorm(x, mean = 0, sd = sigma[1L]) +
    weights[2L] * stats::pnorm(x, mean = offset, sd = sigma[2L])
}

dynamic_dgp_gausmix_quantile_shift <- function(tau,
                                               sigma,
                                               weights = c(0.1, 0.9),
                                               offset = 1) {
  tau <- as.numeric(tau)[1L]
  sigma <- as.numeric(sigma)
  weights <- as.numeric(weights)
  offset <- as.numeric(offset)[1L]
  if (length(sigma) != 2L || any(!is.finite(sigma)) || any(sigma <= 0)) {
    stop("gausmix sigma must be a finite positive numeric vector of length 2.", call. = FALSE)
  }
  if (length(weights) != 2L || any(!is.finite(weights)) || any(weights <= 0) || abs(sum(weights) - 1) > 1e-8) {
    stop("gausmix weights must be a positive numeric vector of length 2 that sums to 1.", call. = FALSE)
  }

  bound <- max(abs(offset), 1) + 20 * max(sigma)
  lower <- -bound
  upper <- bound
  f_root <- function(x) .dynamic_dgp_gausmix_cdf(x, sigma = sigma, weights = weights, offset = offset) - tau
  while (f_root(lower) > 0) lower <- lower * 2
  while (f_root(upper) < 0) upper <- upper * 2
  stats::uniroot(f_root, lower = lower, upper = upper, tol = 1e-10)$root
}

dynamic_dgp_family_quantile_shift <- function(family,
                                              tau,
                                              normal_sigma = 10,
                                              laplace_scale = 10,
                                              gausmix_sigma = c(0.5, 15),
                                              gausmix_weights = c(0.1, 0.9),
                                              gausmix_offset = 1) {
  family <- tolower(as.character(family)[1L])
  if (identical(family, "normal")) {
    return(dynamic_dgp_normal_quantile_shift(tau = tau, sigma = normal_sigma))
  }
  if (identical(family, "laplace")) {
    return(dynamic_dgp_laplace_quantile_shift(tau = tau, scale = laplace_scale))
  }
  if (identical(family, "gausmix")) {
    return(dynamic_dgp_gausmix_quantile_shift(
      tau = tau,
      sigma = gausmix_sigma,
      weights = gausmix_weights,
      offset = gausmix_offset
    ))
  }
  stop(sprintf("Unsupported family '%s'.", family), call. = FALSE)
}

simulate_dynamic_family_errors <- function(family,
                                           n,
                                           taus,
                                           seed,
                                           normal_sigma = 10,
                                           laplace_scale = 10,
                                           gausmix_sigma = c(0.5, 15),
                                           gausmix_weights = c(0.1, 0.9),
                                           gausmix_offset = 1) {
  family <- tolower(as.character(family)[1L])
  taus <- as.numeric(taus)
  taus <- taus[is.finite(taus) & taus > 0 & taus < 1]
  if (!length(taus)) {
    stop("taus must contain at least one probability in (0, 1).", call. = FALSE)
  }
  n <- as.integer(n)[1L]
  if (!is.finite(n) || n < 1L) {
    stop("n must be a positive integer.", call. = FALSE)
  }

  set.seed(as.integer(seed)[1L])
  if (identical(family, "normal")) {
    z <- stats::rnorm(n, mean = 0, sd = as.numeric(normal_sigma)[1L])
  } else if (identical(family, "laplace")) {
    u <- stats::runif(n)
    b <- as.numeric(laplace_scale)[1L]
    z <- ifelse(u < 0.5, b * log(2 * u), -b * log(2 * (1 - u)))
  } else if (identical(family, "gausmix")) {
    sigma <- as.numeric(gausmix_sigma)
    weights <- as.numeric(gausmix_weights)
    offset <- as.numeric(gausmix_offset)[1L]
    comp <- sample.int(2L, size = n, replace = TRUE, prob = weights)
    means <- c(0, offset)
    z <- stats::rnorm(n, mean = means[comp], sd = sigma[comp])
  } else {
    stop(sprintf("Unsupported family '%s'.", family), call. = FALSE)
  }

  shift_vals <- vapply(
    taus,
    dynamic_dgp_family_quantile_shift,
    numeric(1),
    family = family,
    normal_sigma = normal_sigma,
    laplace_scale = laplace_scale,
    gausmix_sigma = gausmix_sigma,
    gausmix_weights = gausmix_weights,
    gausmix_offset = gausmix_offset
  )
  tau_labels <- paste0("tau_", dynamic_dgp_prob_label(taus))
  centered_eps <- stats::setNames(
    lapply(shift_vals, function(shift) z - as.numeric(shift)),
    tau_labels
  )

  list(
    family = family,
    raw_noise = z,
    tau_values = taus,
    tau_labels = tau_labels,
    quantile_shifts = stats::setNames(as.numeric(shift_vals), tau_labels),
    centered_eps = centered_eps,
    generation = list(
      normal_sigma = as.numeric(normal_sigma)[1L],
      laplace_scale = as.numeric(laplace_scale)[1L],
      gausmix_sigma = as.numeric(gausmix_sigma),
      gausmix_weights = as.numeric(gausmix_weights),
      gausmix_offset = as.numeric(gausmix_offset)[1L]
    )
  )
}
