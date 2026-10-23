# Validation-only adapters. All DESN transitions use the shared production API.
hh_fit <- function(bank, cfg, seed, cores = 1L) {
  run <- function(k) autodesn_fit_bank(bank, n_burn = cfg$n_burn, n_mcmc = cfg$n_mcmc,
    initial_variance = c(.1, 1, 5)[k], ridge_precision = c(.1, 1, 10)[k], seed = seed + k)
  fits <- if (cores > 1L && .Platform$OS.type != "windows")
    parallel::mclapply(seq_len(cfg$chains), run, mc.cores = min(cfg$chains, cores), mc.set.seed = FALSE) else
    lapply(seq_len(cfg$chains), run)
  if (any(vapply(fits, inherits, logical(1), "try-error"))) stop("Parallel chain failed")
  list(fit = lh_pool(fits), diagnostics = autodesn_diagnostics(fits))
}
hh_auto <- function(fit, H, ids, K, z, observed = NULL) {
  if (is.null(observed)) {
    fc <- forecast_paths.autodesn_fit(fit, H, draw_index = ids, inner_paths = K,
      innovations = z, backend = "batched")
  } else {
    # The Normal adapter computes mu_h before feeding observation h back. Its
    # forced yrep is not a forecast: construct fresh predictive samples below.
    bank <- fit$bank; all_ids <- rep(ids, each = K)
    # Observed feedback gives one reservoir trajectory per specification.
    # Evaluate each outer draw once, then repeat locations over inner noises.
    model <- fit$draws$model[ids]; mu <- matrix(NA_real_, H, length(ids))
    future <- (observed - bank$preprocessing$center) / bank$preprocessing$scale
    for (j in unique(model)) {
      cols <- which(model == j); beta <- do.call(rbind, fit$beta[ids[cols]])
      beta[, -1L] <- beta[, -1L, drop = FALSE] / bank$models[[j]]$divisor
      object <- bank$templates[[j]]; object$fit <- list(target_label = "validation_prequential")
      class(object) <- c("qdesn_normal_fit", "list")
      tmp <- forecast_paths.qdesn_normal_fit(object, H, y_hist = bank$history_scaled,
        draws = list(beta = beta, omega2 = fit$draws$variance[ids[cols]]),
        y_future_obs = future, innovations = matrix(0, H, length(cols)), backend = "batched")
      mu[, cols] <- tmp$mu_draws
    }
    mu <- mu[, rep(seq_along(ids), each = K), drop = FALSE]
    fc <- list(mu_draws = .autodesn_unscale(bank, mu), draw_index = all_ids,
      origin = length(bank$history), H = H, n_outer = length(ids), inner_paths = K)
  }
  fc$sd_draws <- matrix(sqrt(fit$draws$variance[fc$draw_index]) * fit$bank$preprocessing$scale,
    H, length(fc$draw_index), byrow = TRUE)
  if (!is.null(observed)) fc$yrep <- fc$mu_draws + fc$sd_draws*z
  fc
}
hh_gaussian_fit <- function(bank, p, N, seed) {
  rows <- bank$keep_idx; y <- bank$history_scaled
  X <- matrix(1, length(rows), p + 1L)
  if (p > 0L) X[, -1L] <- vapply(seq_len(p), function(k) y[rows-k], numeric(length(rows)))
  f <- normal_desn_fit(X, y[rows], prior = list(tau2 = 1, intercept_var = 10),
                      omega_prior = list(a = 3, b = 1))
  list(p = p, bank = bank, draw = .autodesn_seed(seed, function() normal_desn_posterior_draws(f, N)))
}
hh_gaussian <- function(object, H, z, observed = NULL) {
  N <- ncol(z); p <- object$p; bank <- object$bank; draw <- object$draw
  lag <- if (p > 0) matrix(rev(tail(bank$history_scaled, p)), p, N) else NULL
  mu <- y <- matrix(NA_real_, H, N)
  sd <- matrix(sqrt(draw$omega2), H, N, byrow = TRUE)
  for (h in seq_len(H)) {
    mu[h, ] <- draw$beta[, 1L]
    if (p > 0) mu[h, ] <- mu[h, ] + colSums(lag*t(draw$beta[, -1L, drop = FALSE]))
    y[h, ] <- mu[h, ] + sd[h, ]*z[h, ]
    next_y <- if (is.null(observed)) y[h, ] else rep(
      (observed[h] - bank$preprocessing$center)/bank$preprocessing$scale, N)
    if (p > 0) lag <- rbind(next_y, lag[seq_len(p - 1L), , drop = FALSE])
  }
  list(yrep = .autodesn_unscale(bank, y), mu_draws = .autodesn_unscale(bank, mu),
       sd_draws = sd*bank$preprocessing$scale)
}

hh_gjr_parameters <- function(theta) {
  w <- .autodesn_softmax(c(theta[4:6], 0))
  c(intercept = unname(theta[1L]), phi = .98*tanh(theta[2L]), omega = exp(theta[3L]),
    alpha = .995*w[1L], gamma = 2*.995*w[2L], beta = .995*w[3L])
}
hh_gjr_filter <- function(y, rows, theta, initial_variance, details = FALSE) {
  p <- hh_gjr_parameters(theta)
  error <- y - p[1L] - p[2L]*c(0, head(y, -1L))
  previous <- c(0, head(error, -1L))
  shock <- p[3L] + p[4L]*previous^2 + p[5L]*previous^2*(previous < 0)
  # stats::filter evaluates v[t] = shock[t] + beta*v[t-1] in compiled code.
  # This is the same conditional likelihood as the tested scalar recursion.
  variance <- as.numeric(stats::filter(shock, p[6L], method = "recursive", init = initial_variance))
  if (any(!is.finite(variance)) || any(variance < 1e-14) || any(!is.finite(error)))
    return(if (details) NULL else 1e100)
  ll <- sum(.5*(log(2*pi*variance[rows]) + error[rows]^2/variance[rows]))
  if (details) list(error = tail(error, 1L), variance = tail(variance, 1L),
    objective = ll, parameters = p) else ll
}
hh_gjr_fit <- function(history, rows) {
  initial_variance <- max(var(history[1:500]), 1e-6)
  fit_ar <- lm.fit(cbind(1, history[rows-1L]), history[rows])$coefficients
  phi <- max(-.95, min(.95, fit_ar[2L])); intercept <- fit_ar[1L]
  starts <- list(c(.06, .12, .85), c(.10, .05, .70), c(.03, .20, .80))
  results <- lapply(starts, function(q) {
    w <- c(q[1L], q[2L]/2, q[3L])/.995; remainder <- 1-sum(w)
    theta <- c(intercept, atanh(phi/.98), log(max(initial_variance*(1-sum(c(q[1L],q[2L]/2,q[3L]))),1e-5)), log(w/remainder))
    optim(theta, hh_gjr_filter, y = history, rows = rows, initial_variance = initial_variance,
      method = "L-BFGS-B", lower = c(-20,-3,-14,rep(-12,3)), upper = c(20,3,8,rep(12,3)),
      control = list(maxit = 800, factr = 1e7))
  })
  valid <- vapply(results, function(x) x$convergence == 0 && is.finite(x$value), TRUE)
  if (!any(valid)) stop("No converged GJR optimization start")
  values <- vapply(results, `[[`, numeric(1), "value"); values[!valid] <- Inf
  best <- which.min(values); f <- results[[best]]
  filtered <- hh_gjr_filter(history, rows, f$par, initial_variance, TRUE)
  list(parameters = filtered$parameters, variance = filtered$variance, error = filtered$error,
    last_y = tail(history, 1L), objective = f$value, convergence = f$convergence, selected_start = best,
    starts = data.frame(start = seq_along(results), objective = vapply(results, `[[`, numeric(1), "value"),
      convergence = vapply(results, `[[`, integer(1), "convergence")))
}
hh_gjr <- function(object, H, z, observed = NULL) {
  N <- ncol(z); p <- object$parameters
  variance <- rep(object$variance, N); error <- rep(object$error, N); last <- rep(object$last_y, N)
  mu <- sd <- y <- matrix(NA_real_, H, N)
  for (h in seq_len(H)) {
    variance <- p[3L] + p[4L]*error^2 + p[5L]*error^2*(error < 0) + p[6L]*variance
    mu[h, ] <- p[1L] + p[2L]*last; sd[h, ] <- sqrt(variance)
    y[h, ] <- mu[h, ] + sd[h, ]*z[h, ]
    last <- if (is.null(observed)) y[h, ] else rep(observed[h], N)
    error <- last - mu[h, ]
  }
  list(yrep = y, mu_draws = mu, sd_draws = sd)
}

hh_score <- function(fc, actual, latent, oracle_mean) {
  score <- lh_score(fc, actual, latent, oracle_mean)
  mean <- rowMeans(fc$mu_draws)
  score$predictive_sd <- sqrt(pmax(0, rowMeans(fc$sd_draws^2 + fc$mu_draws^2) - mean^2))
  score$innovation_sd <- sqrt(rowMeans(fc$sd_draws^2))
  score$covered50 <- actual >= score$lower50 & actual <= score$upper50
  score$width50 <- score$upper50 - score$lower50
  score$negative_log_score <- -vapply(seq_along(actual), function(h)
    hh_logmean(dnorm(actual[h], fc$mu_draws[h, ], fc$sd_draws[h, ], log = TRUE)), numeric(1))
  score
}
hh_qualify <- function(dg) all(is.finite(dg$parameters$rhat)) &&
  max(dg$parameters$rhat) <= 1.01 && min(dg$parameters$ess_spectral) >= 400 &&
  max(dg$models$chain_range) <= .05
