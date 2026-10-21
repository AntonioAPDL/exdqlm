make_autodesn_test_specs <- function() {
  list(shallow = list(D = 1L, n = 5L, m = 1L, alpha = 0.4, rho = 0.5,
                       pi_w = 0.7, pi_in = 1, washout = 3L, seed = 11L),
       deep = list(D = 2L, n = c(6L, 4L), n_tilde = 3L, m = 3L,
                    alpha = c(0.3, 0.7), rho = c(0.4, 0.8),
                    pi_w = 0.7, pi_in = 1, washout = 5L, seed = 29L,
                    standardize_inputs = TRUE, input_bound = "tanh",
                    win_scale_global = 0.6, win_scale_bias = 0.8))
}

test_that("candidate grids and the series facade follow the Q-DESN argument contract", {
  specs <- autodesn_candidates(D = c(1L, 2L), n = c(4L, 6L), m = 2L,
                               alpha = 0.5, rho = 0.7, seed = c(11L, 29L),
                               washout = 3L, pi_w = 1, pi_in = 1)
  expect_length(specs, 8L)
  expect_true(all(vapply(specs, function(s) length(s$n) == s$D && length(s$n_tilde) == s$D - 1L, logical(1))))
  fit <- autodesn_fit(sin(seq_len(40)), candidates = specs, conditioning = 6L,
          mcmc_args = list(n_burn = 5L, n_mcmc = 20L, seed = 105L))
  expect_s3_class(fit, "autodesn_fit")
  expect_equal(fit$meta$inference_method, "blocked_gibbs")
  expect_equal(fit$meta$beta_prior_type, "independent_ridge")
  expect_identical(getS3method("diagnostics", "autodesn_fit"), diagnostics.autodesn_fit)
  expect_error(autodesn_candidates(n_tilde = 2L), "cannot be overridden")
  expect_error(autodesn_candidates(D = integer()), "nonempty")
  expect_error(autodesn_fit(sin(seq_len(40)), specs, mcmc_args = list(typo = 1)), "unused argument")
})

test_that("collapsed scores match dense Gaussian integration across design ranks", {
  set.seed(317)
  y <- stats::rnorm(17)
  H <- matrix(stats::rnorm(17 * 5), 17, 5)
  bank <- autodesn_prepare_bank(y, list(H, cbind(H, H[, 1], 1),
             matrix(stats::rnorm(17 * 22), 17, 22), matrix(numeric(), 17, 0)))
  for (model in bank$models) for (v in c(0.03, 0.8, 3)) for (lambda in c(0.04, 1, 25)) {
    B <- diag(c(10, rep(1 / lambda, model$d)), model$d + 1L)
    C <- v * diag(17) + model$X %*% B %*% t(model$X)
    R <- chol(C)
    direct <- -0.5 * (17 * log(2 * pi) + 2 * sum(log(diag(R))) +
                       sum(forwardsolve(t(R), y)^2))
    expect_equal(exdqlm:::.autodesn_log_evidence(model, v, lambda), direct, tolerance = 1e-8)
  }
})

test_that("split prior mass leaves duplicate candidate posterior mass invariant", {
  set.seed(36)
  H <- matrix(stats::rnorm(60), 20, 3)
  y <- stats::rnorm(20)
  a <- autodesn_prepare_bank(y, list(H, H[, 1, drop = FALSE]), model_prior = c(0.6, 0.4))
  b <- autodesn_prepare_bank(y, list(H, H, H[, 1, drop = FALSE]), model_prior = c(0.3, 0.3, 0.4))
  p <- exdqlm:::.autodesn_model_probabilities(a, 0.8, 1.2)
  q <- exdqlm:::.autodesn_model_probabilities(b, 0.8, 1.2)
  expect_equal(p, c(sum(q[1:2]), q[3]), tolerance = 1e-13)
  huge <- autodesn_prepare_bank(y, list(H, H), model_prior = c(1e308, 1e308))
  expect_equal(huge$prior, c(0.5, 0.5))
  one <- autodesn_fit_bank(autodesn_prepare_bank(y, list(H)), n_burn = 5L, n_mcmc = 20L)
  expect_equal(one$model_summary$posterior_probability, 1)
})

test_that("Gaussian coefficient conditional uses the correct precision factor", {
  set.seed(204)
  H <- cbind(seq(-1, 1, length.out = 20), seq(-1, 1, length.out = 20)^2)
  bank <- autodesn_prepare_bank(stats::rnorm(20), list(H))
  model <- bank$models[[1L]]
  P <- crossprod(model$X) / 0.7 + diag(c(0.1, 1.3, 1.3))
  V <- solve(P)
  expected_mean <- as.numeric(V %*% crossprod(model$X, bank$y) / 0.7)
  cond <- exdqlm:::.autodesn_beta_conditional(model, 0.7, 1.3, 10, draw = FALSE)
  expect_equal(cond$mean, expected_mean, tolerance = 1e-12)
  expect_equal(crossprod(cond$precision_chol), P, tolerance = 1e-12)
  draws <- replicate(10000, exdqlm:::.autodesn_beta_conditional(model, 0.7, 1.3, 10))
  expect_true(all(abs(rowMeans(draws) - expected_mean) < 5 * sqrt(diag(V) / 10000)))
  # For Gaussian draws, sample covariance has Wishart sampling variance.
  # Entrywise Monte Carlo errors remain meaningful when a true covariance is zero.
  covariance_mcse <- sqrt((outer(diag(V), diag(V)) + V^2) / (ncol(draws) - 1L))
  expect_true(all(abs(stats::cov(t(draws)) - V) < 6 * covariance_mcse))
})

test_that("bank uses Q-DESN designs, common rows and prefix-only scaling", {
  y <- sin(seq_len(85) / 5) + seq_len(85) / 100
  specs <- make_autodesn_test_specs()
  set.seed(992)
  rng <- .Random.seed
  bank <- autodesn_build_bank(y, specs, conditioning = 12L)
  expect_identical(.Random.seed, rng)
  expect_equal(bank$keep_idx, 18:85)
  expect_equal(bank$preprocessing$center, mean(y[1:12]))
  expect_equal(bank$preprocessing$scale, stats::sd(y[1:12]))
  expect_equal(bank$prior, c(0.5, 0.5))
  for (j in seq_along(specs)) {
    args <- bank$specifications[[j]]
    args$washout <- bank$preprocessing$drop
    ref <- do.call(qdesn_fit_vb, c(list(y = bank$history_scaled, p0 = 0.5, fit_readout = FALSE), args))
    expected <- ref$X
    expected[, -1L] <- expected[, -1L] / sqrt(ncol(expected) - 1L)
    expect_equal(unname(bank$models[[j]]$X), unname(expected), tolerance = 1e-13)
    expect_equal(bank$templates[[j]]$reservoir, ref$reservoir)
  }
  changed <- y
  changed[65:85] <- changed[65:85] + 40
  other <- autodesn_build_bank(changed, specs, conditioning = 12L)
  expect_identical(bank$preprocessing, other$preprocessing)
  for (j in seq_along(specs)) {
    # Features at t use y through t-1, so t=65 also stays unchanged.
    early <- bank$keep_idx <= 65
    expect_equal(bank$models[[j]]$X[early, ], other$models[[j]]$X[early, ], tolerance = 1e-13)
  }
  longer <- autodesn_build_bank(c(y, 100, -100), specs, conditioning = 12L)
  for (j in seq_along(specs)) expect_equal(bank$models[[j]]$X, utils::head(longer$models[[j]]$X, bank$n))
})

test_that("depth prior is independent of the number of specifications at that depth", {
  specs <- make_autodesn_test_specs()
  specs$another_shallow <- utils::modifyList(specs$shallow, list(seed = 103L))
  bank <- autodesn_build_bank(sin(seq_len(70)), specs, conditioning = 10L)
  expect_equal(bank$prior, c(0.25, 0.5, 0.25))
  # A duplicated candidate still requires explicit splitting of its old mass.
  weighted <- autodesn_build_bank(sin(seq_len(70)), specs, conditioning = 10L, model_prior = c(1, 6, 3))
  expect_equal(weighted$prior, c(0.1, 0.6, 0.3))
})

test_that("Gibbs and prediction restore RNG and preserve joint draw dimensions", {
  y <- sin(seq_len(65) / 4)
  bank <- autodesn_build_bank(y, make_autodesn_test_specs(), conditioning = 10L)
  set.seed(392)
  rng <- .Random.seed
  fit <- autodesn_fit_bank(bank, n_burn = 30L, n_mcmc = 120L, thin = 3L, seed = 82L)
  expect_identical(.Random.seed, rng)
  expect_length(fit$beta, 40L)
  expect_equal(vapply(fit$beta, length, integer(1)),
               vapply(bank$models[fit$draws$model], function(x) x$d + 1L, integer(1)))
  expect_equal(rowSums(fit$conditional_probabilities), rep(1, 40L))
  again <- autodesn_fit_bank(bank, n_burn = 30L, n_mcmc = 120L, thin = 3L, seed = 82L)
  expect_identical(fit$draws, again$draws)
  expect_identical(fit$beta, again$beta)
  fc <- forecast_paths.autodesn_fit(fit, H = 4L, nd = 17L, seed = 371L)
  expect_identical(.Random.seed, rng)
  expect_identical(dim(fc$yrep), c(4L, 17L))
  expect_true(all(is.finite(fc$yrep)))
  expect_identical(fc$model, fit$draws$model[fc$draw_index])
  expect_identical(fc, forecast_paths.autodesn_fit(fit, H = 4L, nd = 17L, seed = 371L))
  pp <- posterior_predict.autodesn_fit(fit, nd = 15L, seed = 54L)
  expect_identical(.Random.seed, rng)
  expect_identical(dim(pp$yrep), c(bank$n, 15L))
  expected_mu <- Reduce(`+`, lapply(seq_len(nrow(fit$draws)), function(k) {
    bank$models[[fit$draws$model[k]]]$X %*% fit$beta[[k]]
  })) / nrow(fit$draws)
  expect_equal(predict_mu.autodesn_fit(fit), as.numeric(bank$preprocessing$center + bank$preprocessing$scale * expected_mu))
  fixed <- autodesn_fit_bank(bank, n_burn = 5L, n_mcmc = 30L, learn_ridge = FALSE, ridge_precision = 3)
  expect_equal(fixed$draws$ridge_precision, rep(3, 30L))
})

test_that("one-step recursive rows match the next shared-builder feature", {
  y <- sin(seq_len(75) / 4) + 0.1 * cos(seq_len(75))
  specs <- make_autodesn_test_specs()
  for (j in seq_along(specs)) {
    bank <- autodesn_build_bank(y, specs[j], conditioning = 12L)
    fit <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 70L, seed = 180L)
    extended <- autodesn_build_bank(c(y, 1e4, -1e4), specs[j], conditioning = 12L)
    next_x <- extended$models[[1L]]$X[bank$n + 1L, ]
    fc <- forecast_paths.autodesn_fit(fit, H = 1L, nd = 60L, seed = 77L)
    expected <- vapply(fc$draw_index, function(k) sum(next_x * fit$beta[[k]]), numeric(1))
    expect_equal(as.numeric(fc$mu_draws), bank$preprocessing$center + bank$preprocessing$scale * expected, tolerance = 1e-11)
  }
})

test_that("one-step simulation matches joint posterior predictive mixture moments", {
  y <- sin(seq_len(60) / 4)
  specs <- make_autodesn_test_specs()
  bank <- autodesn_build_bank(y, specs, conditioning = 10L)
  fit <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 100L, seed = 181L)
  extended <- autodesn_build_bank(c(y, 999), specs, conditioning = 10L)
  means <- vapply(seq_len(nrow(fit$draws)), function(k) {
    j <- fit$draws$model[k]
    sum(extended$models[[j]]$X[bank$n + 1L, ] * fit$beta[[k]])
  }, numeric(1))
  target_mean <- bank$preprocessing$center + bank$preprocessing$scale * mean(means)
  target_variance <- bank$preprocessing$scale^2 *
    (mean(fit$draws$variance) + mean((means - mean(means))^2))
  fc <- forecast_paths.autodesn_fit(fit, H = 1L, nd = 4000L, seed = 1033L)
  expect_lt(abs(mean(fc$yrep) - target_mean), 6 * sqrt(target_variance / 4000))
  expect_lt(abs(stats::var(as.numeric(fc$yrep)) / target_variance - 1), 0.1)
})

test_that("recursive paths exactly reuse the Normal Q-DESN forecast with external draws", {
  bank <- autodesn_build_bank(sin(seq_len(70) / 4), make_autodesn_test_specs()[2], conditioning = 10L,
                               normalize_features = FALSE)
  fit <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 50L, seed = 73L)
  fc <- forecast_paths.autodesn_fit(fit, H = 5L, nd = 15L, seed = 531L)
  set.seed(531L)
  ids <- sample.int(50L, 15L, replace = TRUE)
  template <- bank$templates[[1L]]
  template$fit <- list(target_label = "test")
  class(template) <- c("qdesn_normal_fit", "list")
  ref <- forecast_paths.qdesn_normal_fit(template, H = 5L, y_hist = bank$history_scaled,
       draws = list(beta = do.call(rbind, fit$beta[ids]), omega2 = fit$draws$variance[ids]))
  expect_identical(ids, fc$draw_index)
  expect_equal(fc$yrep, bank$preprocessing$center + bank$preprocessing$scale * ref$yrep, tolerance = 1e-13)
})

test_that("later forecast means use their own sampled feedback histories", {
  y <- sin(seq_len(65) / 4)
  for (spec in make_autodesn_test_specs()) {
    bank <- autodesn_build_bank(y, list(spec), conditioning = 10L)
    fit <- autodesn_fit_bank(bank, n_burn = 10L, n_mcmc = 30L, seed = 208L)
    fc <- forecast_paths.autodesn_fit(fit, H = 2L, nd = 3L, seed = 904L)
    for (s in 1:3) {
      extended <- autodesn_build_bank(c(y, fc$yrep[1L, s], 999), list(spec), conditioning = 10L)
      x <- extended$models[[1L]]$X[bank$n + 2L, ]
      expected <- sum(x * fit$beta[[fc$draw_index[s]]])
      expect_equal(fc$mu_draws[2L, s], bank$preprocessing$center + bank$preprocessing$scale * expected, tolerance = 1e-11)
    }
  }
})

test_that("identity bridges, zero lag input and single draws retain forecast dimensions", {
  spec <- list(D = 2L, n = c(4L, 3L), n_tilde = 4L, m = 0L,
                alpha = c(0.3, 0.7), rho = c(0.5, 0.8), seed = 39L,
                pi_w = 1, pi_in = 1, washout = 2L)
  bank <- autodesn_build_bank(cos(seq_len(40)), list(spec), conditioning = 6L)
  expect_true(bank$templates[[1L]]$reservoir$Q_is_identity[1L])
  fit <- autodesn_fit_bank(bank, n_burn = 2L, n_mcmc = 10L)
  fc <- forecast_paths.autodesn_fit(fit, H = 1L, nd = 1L, seed = 44L)
  expect_identical(dim(fc$yrep), c(1L, 1L))
  pp <- posterior_predict.autodesn_fit(fit, nd = 1L,
          X_new = list(matrix(rep(0, bank$models[[1L]]$d), 1L)), seed = 88L)
  expect_identical(dim(pp$yrep), c(1L, 1L))
  expect_error(forecast_paths.autodesn_fit(fit, H = 1L, y_future_obs = 1), "additional controls")
})

test_that("a one-unit reservoir retains time rows in the shared builder", {
  specs <- list(list(D = 1L, n = 1L, m = 1L, alpha = 0.5, rho = 0.5,
                      pi_w = 1, pi_in = 1, washout = 2L, seed = 1L))
  bank <- autodesn_build_bank(sin(seq_len(40)), specs, conditioning = 6L)
  expect_identical(dim(bank$models[[1L]]$X), c(32L, 2L))
  expect_identical(dim(bank$templates[[1L]]$states$H_all[[1L]]), c(40L, 1L))
  fit <- autodesn_fit_bank(bank, n_burn = 5L, n_mcmc = 20L, seed = 13L)
  fc <- forecast_paths.autodesn_fit(fit, H = 2L, nd = 3L, seed = 14L)
  expect_identical(dim(fc$yrep), c(2L, 3L))
  expect_true(all(is.finite(fc$yrep)))
})

test_that("validation rejects unsupported modes and malformed controls explicitly", {
  H <- matrix(1, 20, 2)
  y <- seq_len(20)
  expect_error(autodesn_prepare_bank(y, list(H), normalize_features = NA), "TRUE or FALSE")
  expect_error(autodesn_prepare_bank(y, list(H[-1, ])), "rows")
  expect_error(autodesn_prepare_bank(y, list(H), model_prior = 0), "strictly positive")
  expect_error(autodesn_prepare_bank(y, list(H), model_info = list(a = 1)), "one row")
  bank <- autodesn_prepare_bank(y, list(H))
  expect_error(autodesn_fit_bank(bank, n_burn = -1), "integer")
  expect_error(autodesn_fit_bank(bank, n_mcmc = 1.5), "integer")
  expect_error(autodesn_fit_bank(bank, learn_ridge = NA), "TRUE or FALSE")
  expect_error(autodesn_fit_bank(bank, a_sigma = 0), "positive")
  fit <- autodesn_fit_bank(bank, n_burn = 0L, n_mcmc = 1L)
  expect_error(forecast_paths.autodesn_fit(fit, 2L), "build_bank")
  expect_error(posterior_predict.autodesn_fit(fit, X_new = list(matrix(0, 1, 3))), "dimensions")
  specs <- make_autodesn_test_specs()[1]
  for (bad in list(list(seed = NULL), list(weights = rep(1, 20)), list(state_noise_sd = 0.1),
                   list(input_mode = "dlm_decomp_lags"), list(add_bias = FALSE), list(unknown = 1))) {
    s <- specs
    for (nm in names(bad)) s[[1]][nm] <- bad[nm]
    expect_error(autodesn_build_bank(y, s, conditioning = 5L))
  }
  expect_error(autodesn_build_bank(y, specs, conditioning = 19L), "scored")
  constant <- autodesn_build_bank(rep(4, 35), specs, conditioning = 6L)
  expect_equal(constant$preprocessing$scale, 1)
  expect_true(all(is.finite(constant$models[[1]]$X)))
  expect_error(autodesn_fit(y, specs, mcmc_args = list(bank = bank)), "override bank")
})

test_that("diagnostics identify equivalent targets and fixed-precision edge cases", {
  set.seed(922)
  bank <- autodesn_prepare_bank(stats::rnorm(25), list(matrix(stats::rnorm(50), 25, 2)))
  a <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 100L, learn_ridge = FALSE, seed = 18L)
  b <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 100L, learn_ridge = FALSE, seed = 39L)
  d <- autodesn_diagnostics(list(a, b))
  expect_true(is.finite(d$parameters$rhat[1]))
  expect_true(is.na(d$parameters$rhat[2]))
  expect_true(is.na(d$parameters$ess_spectral[2]))
  expect_equal(d$models$posterior_probability, 1)
  expect_equal(d$models$chain_range, 0)
  expect_equal(diagnostics(a, b), d)
  other <- autodesn_fit_bank(bank, n_burn = 20L, n_mcmc = 100L, learn_ridge = FALSE, ridge_precision = 3)
  expect_error(autodesn_diagnostics(list(a, other)), "same bank, prior and target")
})
