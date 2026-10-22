long_autodesn_specs <- function() {
  list(one_unit = list(D = 1L, n = 1L, m = 0L, alpha = .6, rho = .5,
         seed = 81L, washout = 5L, pi_w = 1, pi_in = 1),
       reduced = list(D = 2L, n = c(6L, 4L), n_tilde = 3L, m = 3L,
         alpha = c(.3, .8), rho = c(.6, .8), seed = 82L, washout = 5L,
         pi_w = 1, pi_in = 1, standardize_inputs = TRUE,
         input_bound = "tanh", input_bound_divisor = 3,
         win_scale_lags = c(.8, .5, .2), win_scale_global = .4),
       identity = list(D = 3L, n = c(4L, 4L, 3L), n_tilde = c(4L, 4L),
         m = 1L, alpha = c(.4, .6, .8), rho = c(.4, .5, .6),
         seed = 83L, washout = 5L, pi_w = 1, pi_in = 1),
       relu = list(D = 2L, n = c(4L, 3L), n_tilde = 4L, m = 2L,
         alpha = .4, rho = c(.3, .4), act_f = "relu", act_k = "relu",
         seed = 84L, washout = 5L, pi_w = 1, pi_in = 1))
}

test_that("explicit washout yields exactly 500 training rows after 500 warmup rows", {
  y <- sin(seq_len(1100) / 9) + seq_len(1100) / 1000
  specs <- long_autodesn_specs()[2:3]
  for (j in seq_along(specs)) specs[[j]]$washout <- 500L
  bank <- autodesn_build_bank(y[1:1000], specs, conditioning = 500L, washout = 500L)
  expect_identical(bank$keep_idx, 501:1000)
  expect_equal(bank$n, 500L)
  expect_equal(bank$preprocessing$center, mean(y[1:500]))
  expect_equal(bank$preprocessing$scale, stats::sd(y[1:500]))
  expect_identical(bank$preprocessing$washout_mode, "total_prefix")
  expect_true(all(vapply(bank$templates, function(z) nrow(z$X) == 500L, TRUE)))
  expect_true(all(vapply(bank$templates, function(z) identical(z$meta$keep_idx, 501:1000), TRUE)))
  expect_error(autodesn_build_bank(y[1:1000], specs, conditioning = 500L, washout = 499L), "must cover")
  expect_error(autodesn_build_bank(y[1:1000], specs, conditioning = 500L, washout = 500.5), "integer")
  fit <- autodesn_fit(y[1:1000], specs, conditioning = 500L, washout = 500L,
    mcmc_args = list(n_burn = 2L, n_mcmc = 12L, seed = 54L))
  expect_identical(fit$bank$keep_idx, bank$keep_idx)
  fc <- forecast_paths.autodesn_fit(fit, H = 100L, nd = 4L, inner_paths = 3L,
                                   seed = 55L, backend = "batched")
  expect_identical(dim(fc$yrep), c(100L, 12L))
  expect_equal(fc$origin, 1000L)
  expect_true(all(is.finite(fc$yrep)))
  expect_error(forecast_paths.autodesn_fit(fit, 100L, y_future_obs = y[1001:1100]), "additional controls")
})

test_that("batched Normal paths share the serial transition across supported feature maps", {
  y <- sin(seq_len(70) / 7) + cos(seq_len(70) / 13)
  bank <- autodesn_build_bank(y, long_autodesn_specs(), conditioning = 10L)
  withr::local_seed(909)
  noise <- matrix(stats::rnorm(7 * 5), 7, 5)
  for (j in seq_along(bank$models)) {
    object <- bank$templates[[j]]
    object$fit <- list(target_label = "test")
    class(object) <- c("qdesn_normal_fit", "list")
    p <- ncol(object$X)
    draws <- list(beta = matrix(stats::rnorm(5 * p, sd = .1), 5, p),
                  omega2 = seq(.1, .5, length.out = 5))
    for (mode in c("posterior_predictive", "conditional_mean_plugin")) {
      args <- list(object = object, H = 7L, y_hist = bank$history_scaled,
        draws = draws, innovations = noise, return_design = TRUE, recursion_mode = mode)
      serial <- do.call(forecast_paths.qdesn_normal_fit, c(args, list(backend = "serial")))
      batched <- do.call(forecast_paths.qdesn_normal_fit, c(args, list(backend = "batched")))
      expect_equal(batched$yrep, serial$yrep, tolerance = 1e-12)
      expect_equal(batched$mu_draws, serial$mu_draws, tolerance = 1e-12)
      expect_equal(batched$design, serial$design, tolerance = 1e-12)
      if (mode == "conditional_mean_plugin") expect_equal(batched$yrep, batched$mu_draws)
    }
    # Retain teacher-forcing compatibility for the existing Normal API.
    observed <- c(2, NA, -.5, rep(NA, 4))
    a <- forecast_paths.qdesn_normal_fit(object, 7L, draws = draws, innovations = noise,
      y_hist = bank$history_scaled, y_future_obs = observed)
    b <- forecast_paths.qdesn_normal_fit(object, 7L, draws = draws, innovations = noise,
      y_hist = bank$history_scaled, y_future_obs = observed, backend = "batched")
    expect_equal(a$yrep, b$yrep, tolerance = 1e-12)
    expect_equal(as.numeric(b$yrep[1, ]), rep(2, 5))
  }
})

test_that("nested AutoDESN paths retain joint draws, paired noise and outer summaries", {
  bank <- autodesn_build_bank(sin(seq_len(80) / 5), long_autodesn_specs()[2:3], conditioning = 10L)
  fit <- autodesn_fit_bank(bank, n_burn = 10L, n_mcmc = 80L, seed = 601L)
  ids <- c(2L, 7L, 13L)
  withr::local_seed(602)
  noise <- matrix(stats::rnorm(20 * 12), 20, 12)
  rng <- .Random.seed
  full <- forecast_paths.autodesn_fit(fit, 20L, draw_index = ids, inner_paths = 4L,
    innovations = noise, backend = "batched")
  expect_identical(.Random.seed, rng)
  expect_identical(full$draw_index, rep(ids, each = 4L))
  expect_identical(full$model, fit$draws$model[full$draw_index])
  expect_identical(full$outer_draw_index, rep(1:3, each = 4L))
  expect_identical(full$inner_path_index, rep(1:4, times = 3L))
  expected <- vapply(1:3, function(k) rowMeans(full$mu_draws[, (k - 1L) * 4L + 1:4]), numeric(20))
  expect_equal(full$mean_conditional_location, expected, tolerance = 1e-12)
  keep <- c(1L, 2L, 5L, 6L, 9L, 10L)
  nested <- forecast_paths.autodesn_fit(fit, 20L, draw_index = ids, inner_paths = 2L,
    innovations = noise[, keep], backend = "batched")
  expect_equal(nested$yrep, full$yrep[, keep], tolerance = 1e-12)
  serial <- forecast_paths.autodesn_fit(fit, 20L, draw_index = ids, inner_paths = 4L,
    innovations = noise)
  expect_equal(serial$yrep, full$yrep, tolerance = 1e-12)
  plugin <- forecast_paths.autodesn_fit(fit, 20L, draw_index = ids, inner_paths = 4L,
    innovations = noise, backend = "batched", recursion_mode = "conditional_mean_plugin")
  expect_equal(plugin$yrep, plugin$mu_draws)
  expect_equal(plugin$mu_draws[1, ], full$mu_draws[1, ], tolerance = 1e-12)
  expect_gt(max(abs(plugin$mu_draws[-1, ] - full$mu_draws[-1, ])), 0)
  expect_error(forecast_paths.autodesn_fit(fit, 2L, draw_index = 1000L), "valid retained")
  expect_error(forecast_paths.autodesn_fit(fit, 2L, inner_paths = 0L), "integer")
  expect_error(forecast_paths.autodesn_fit(fit, 2L, nd = 3L, innovations = matrix(0, 2, 2)), "total-path-count")
})

test_that("100-step Gaussian AR forecasts recover analytic marginal moments and quantiles", {
  # Force a one-unit linear reservoir to implement y[t] = phi*y[t-1] + noise.
  object <- qdesn_fit_vb(y = sin(1:40), p0 = .5, D = 1L, n = 1L, m = 1L,
    n_tilde = integer(), alpha = .8, rho = .5, act_f = "identity",
    washout = 5L, pi_w = 1, pi_in = 1, add_bias = TRUE, seed = 711L,
    fit_readout = FALSE)
  object$reservoir$W[[1L]] <- matrix(0, 1, 1)
  object$reservoir$Win[[1L]] <- matrix(c(0, 1), 1, 2)
  object$reservoir$alpha <- 1
  object$fit <- list(target_label = "analytic_AR1")
  class(object) <- c("qdesn_normal_fit", "list")
  phi <- .8; sigma <- .35; y0 <- 1.2; H <- 100L; N <- 10000L
  draws <- list(beta = cbind(rep(0, N), rep(phi, N)), omega2 = rep(sigma^2, N))
  fc <- forecast_paths.qdesn_normal_fit(object, H, y_hist = y0, draws = draws,
    backend = "batched", seed = 712L)
  h <- seq_len(H)
  truth <- phi^h * y0
  variance <- sigma^2 * (1 - phi^(2 * h)) / (1 - phi^2)
  expect_true(all(abs(rowMeans(fc$yrep) - truth) < 6 * sqrt(variance / N)))
  expect_true(all(abs(apply(fc$yrep, 1L, stats::var) - variance) < 6 * variance * sqrt(2 / (N - 1))))
  for (p in c(.05, .5, .95)) {
    quantile <- apply(fc$yrep, 1L, stats::quantile, probs = p, type = 8, names = FALSE)
    q <- stats::qnorm(p, truth, sqrt(variance))
    mcse <- sqrt(p * (1 - p) / N) / stats::dnorm(q, truth, sqrt(variance))
    expect_true(all(abs(quantile - q) < 6 * mcse))
  }
  plugin <- forecast_paths.qdesn_normal_fit(object, H, y_hist = y0,
    draws = list(beta = matrix(c(0, phi), 1, 2), omega2 = sigma^2),
    backend = "batched", recursion_mode = "conditional_mean_plugin")
  expect_equal(as.numeric(plugin$mu_draws), truth, tolerance = 1e-12)
  expect_lt(abs(stats::var(fc$yrep[100, ]) - sigma^2 / (1 - phi^2)), .02)
  expect_gt(variance[100], sigma^2)
})
