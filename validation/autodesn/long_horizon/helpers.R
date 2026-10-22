# Study-specific helpers. Production transitions remain in qdesn_normal.R.
lh_specs <- function() {
  grid <- expand.grid(D = 1:3, width = c(20L, 50L), m = c(5L, 30L, 90L),
    profile = c("fast", "slow"), seed = c(11L, 29L), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  specs <- lapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]; slow <- g$profile == "slow"
    list(D = g$D, n = rep(g$width, g$D), n_tilde = rep(g$width, g$D - 1L),
      m = g$m, alpha = if (slow) .15 else .6,
      rho = rep(if (slow) .95 else .6, g$D), seed = g$seed,
      washout = 500L, act_f = "tanh", act_k = "identity",
      standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
      win_scale_global = if (slow) .3 else 1,
      topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
        input_fanin = max(2L, ceiling(.3 * (g$m + 1L))),
        interlayer_fanin = 5L, row_normalize_inputs = TRUE),
      w_dist = function(n) stats::runif(n, -1, 1),
      in_dist = function(n) stats::runif(n, -1, 1))
  })
  names(specs) <- sprintf("desn_%03d", seq_along(specs))
  list(specifications = specs, grid = cbind(candidate = names(specs), grid),
    fixed_index = which(grid$D == 2L & grid$width == 50L & grid$m == 90L &
                        grid$profile == "fast" & grid$seed == 11L))
}

lh_dgp_helper <- function() {
  e <- new.env(parent = .GlobalEnv)
  sys.source("tools/merge_reports/20260305_dynamic_dgp_model_helpers.R", e)
  e$combineMods <- function(a, b) a + b
  e
}

lh_simulate <- function(kind, n, seed) {
  .autodesn_seed(seed, function() {
    if (kind == "dynamic_seasonal") {
      helper <- lh_dgp_helper()
      model <- helper$build_dynamic_dgp_matched_model(list(period = 90L,
        harmonics = c(1L, 2L), C0_scale = .01,
        m0 = helper$dynamic_dgp_make_m0(45, .014, c(32, 12), c(.85, -1.25))),
        TT = n, backend = "R")
      W_sd <- c(.005, .00002, .004, .004, .003, .003)
      latent <- helper$simulate_dynamic_dgp_latent_path(model, n, W_sd, seed,
        initial_state_mode = "deterministic_m0")
      error <- helper$simulate_dynamic_family_errors("normal", n, .5, seed + 1L,
        normal_sigma = 10)$centered_eps[[1L]]
      return(list(y = latent$mu + error, mu = latent$mu, model = model,
                  W = diag(W_sd^2), V = 100, seed = seed))
    }
    y <- mu <- numeric(n)
    error <- stats::rnorm(n, sd = .35)
    for (t in 3:n) {
      mu[t] <- if (kind == "linear") .7 * y[t - 1L] else
        .35 * y[t - 1L] + .65 * sin(1.8 * y[t - 2L])
      y[t] <- mu[t] + error[t]
    }
    list(y = y, mu = mu, seed = seed)
  })
}

lh_pool <- function(fits) {
  dg <- autodesn_diagnostics(fits) # validates common designs and prior target
  f <- fits[[1L]]
  f$draws <- do.call(rbind, lapply(fits, `[[`, "draws"))
  f$draws$chain <- rep(seq_along(fits), lengths(lapply(fits, `[[`, "beta")))
  f$beta <- unlist(lapply(fits, `[[`, "beta"), recursive = FALSE)
  f$conditional_probabilities <- do.call(rbind, lapply(fits, `[[`, "conditional_probabilities"))
  f$model_summary <- dg$models
  f
}

lh_fit <- function(bank, cfg, seed) {
  fits <- lapply(seq_len(cfg$chains), function(k) {
    cat(sprintf("  chain %d/%d, %d burn + %d retained sweeps\n", k, cfg$chains, cfg$n_burn, cfg$n_mcmc))
    flush.console()
    autodesn_fit_bank(bank, n_burn = cfg$n_burn, n_mcmc = cfg$n_mcmc,
      initial_variance = c(.1, 1, 5)[k], ridge_precision = c(.1, 1, 10)[k],
      seed = seed + k)
  })
  list(fit = lh_pool(fits), diagnostics = autodesn_diagnostics(fits))
}

lh_ar <- function(bank, p, H, nd, seed) {
  rows <- bank$keep_idx; z <- bank$history_scaled
  X <- cbind(1, vapply(seq_len(p), function(lag) z[rows - lag], numeric(length(rows))))
  fit <- normal_desn_fit(X, z[rows], prior = list(tau2 = 1, intercept_var = 10),
                        omega_prior = list(a = 3, b = 1))
  .autodesn_seed(seed, function() {
    draw <- normal_desn_posterior_draws(fit, nd = nd)
    lags <- matrix(rev(tail(z, p)), p, nd)
    eps <- sweep(matrix(stats::rnorm(H * nd), H, nd), 2, sqrt(draw$omega2), "*")
    mu <- yrep <- matrix(0, H, nd)
    for (h in seq_len(H)) {
      mu[h, ] <- draw$beta[, 1L] + colSums(lags * t(draw$beta[, -1L, drop = FALSE]))
      yrep[h, ] <- mu[h, ] + eps[h, ]
      lags <- rbind(yrep[h, ], lags[seq_len(p - 1L), , drop = FALSE])
    }
    list(yrep = .autodesn_unscale(bank, yrep), mu_draws = .autodesn_unscale(bank, mu))
  })
}

lh_reference <- function(y, rows, H, nd, seed, period = NULL) {
  .autodesn_seed(seed, function() {
    if (is.null(period)) {
      fit <- normal_desn_fit(matrix(1, length(rows), 1), y[rows],
        prior = list(tau2 = 1, intercept_var = 1e6), omega_prior = list(a = 3, b = 1))
      draw <- normal_desn_posterior_draws(fit, nd)
      mu <- matrix(draw$beta[, 1L], H, nd, byrow = TRUE)
      return(list(yrep = mu + sweep(matrix(stats::rnorm(H * nd), H, nd), 2, sqrt(draw$omega2), "*"), mu_draws = mu))
    }
    # Gaussian seasonal random-walk reference: variance estimated only on the
    # same 500 scored rows, with a fixed variance draw throughout each path.
    residual <- y[rows] - y[rows - period]
    variance <- 1 / stats::rgamma(nd, 3 + length(rows) / 2, 1 + sum(residual^2) / 2)
    lags <- matrix(rev(tail(y, period)), period, nd)
    mu <- paths <- matrix(0, H, nd)
    eps <- sweep(matrix(stats::rnorm(H * nd), H, nd), 2, sqrt(variance), "*")
    for (h in seq_len(H)) {
      mu[h, ] <- lags[period, ]
      paths[h, ] <- mu[h, ] + eps[h, ]
      lags <- rbind(paths[h, ], lags[seq_len(period - 1L), , drop = FALSE])
    }
    list(yrep = paths, mu_draws = mu)
  })
}

lh_dlm_filter <- function(dgp, history) {
  F <- as.numeric(dgp$model$FF); G <- as.matrix(dgp$model$GG)
  m <- as.numeric(dgp$model$m0); C <- matrix(0, length(m), length(m))
  for (y in history) {
    a <- as.numeric(G %*% m); R <- G %*% C %*% t(G) + dgp$W
    v <- as.numeric(R %*% F); Q <- sum(F * v) + dgp$V
    m <- a + v * (y - sum(F * a)) / Q
    C <- R - tcrossprod(v) / Q
    C <- (C + t(C)) / 2
  }
  list(m = m, C = C)
}

lh_oracle <- function(kind, dgp, history, H, nd, seed) {
  .autodesn_seed(seed, function() {
    eps <- matrix(stats::rnorm(H * nd), H, nd)
    mu <- yrep <- matrix(0, H, nd)
    if (kind == "dynamic_seasonal") {
      filter <- lh_dlm_filter(dgp, history)
      theta <- filter$m + t(chol(filter$C)) %*% matrix(stats::rnorm(length(filter$m) * nd), length(filter$m), nd)
      F <- as.numeric(dgp$model$FF); G <- as.matrix(dgp$model$GG)
      for (h in seq_len(H)) {
        theta <- G %*% theta + sqrt(diag(dgp$W)) * matrix(stats::rnorm(nrow(G) * nd), nrow(G), nd)
        mu[h, ] <- as.numeric(crossprod(F, theta))
        yrep[h, ] <- mu[h, ] + sqrt(dgp$V) * eps[h, ]
      }
    } else {
      lag1 <- rep(tail(history, 1), nd); lag2 <- rep(tail(history, 2)[1L], nd)
      for (h in seq_len(H)) {
        mu[h, ] <- if (kind == "linear") .7 * lag1 else .35 * lag1 + .65 * sin(1.8 * lag2)
        yrep[h, ] <- mu[h, ] + .35 * eps[h, ]
        lag2 <- lag1; lag1 <- yrep[h, ]
      }
    }
    list(yrep = yrep, mu_draws = mu)
  })
}

lh_score <- function(fc, actual, latent, oracle_mean) {
  x <- fc$yrep; H <- nrow(x); N <- ncol(x)
  stopifnot(all(is.finite(x)), length(actual) == H)
  qs <- t(apply(x, 1L, stats::quantile, probs = c(.05, .25, .5, .75, .95), type = 8))
  # Gaussian innovations have zero conditional mean. Average the conditional
  # means along stochastic paths to remove unnecessary current-step MC noise.
  means <- rowMeans(fc$mu_draws)
  crps <- vapply(seq_len(H), function(h) {
    z <- sort(x[h, ])
    mean(abs(z - actual[h])) - sum((2 * seq_len(N) - N - 1) * z) / N^2
  }, numeric(1))
  data.frame(horizon = seq_len(H), actual = actual, latent = latent,
    mean = means, predictive_sample_mean = rowMeans(x), mean_location = means,
    lower90 = qs[, 1L], lower50 = qs[, 2L], median = qs[, 3L], upper50 = qs[, 4L], upper90 = qs[, 5L],
    squared_error = (means - actual)^2, absolute_error = abs(means - actual), crps = crps,
    covered90 = actual >= qs[, 1L] & actual <= qs[, 5L], width90 = qs[, 5L] - qs[, 1L],
    latent_squared_error = (rowMeans(fc$mu_draws) - latent)^2,
    oracle_mean_squared_error = (rowMeans(fc$mu_draws) - oracle_mean)^2,
    check05 = (actual - qs[, 1L]) * (.05 - (actual < qs[, 1L])),
    check50 = (actual - qs[, 3L]) * (.5 - (actual < qs[, 3L])),
    check95 = (actual - qs[, 5L]) * (.95 - (actual < qs[, 5L])))
}
