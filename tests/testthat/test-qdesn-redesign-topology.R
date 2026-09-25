test_that("exact-fan-in reservoirs honor row degree and input normalization", {
  set.seed(11)
  y <- 20 + sin(seq_len(120) / 9) + rnorm(120, sd = 0.1)
  fit <- qdesn_fit_vb(
    y = y, p0 = 0.25, D = 2L, n = c(12L, 8L), n_tilde = 12L,
    m = 5L, standardize_inputs = TRUE,
    input_center_scale = "median_mad", input_bound = "tanh",
    input_bound_divisor = 3, alpha = 0.4, rho = c(0.8, 0.85),
    pi_w = 0.1, pi_in = 0.1,
    topology = list(
      mode = "exact_fanin", recurrent_indegree = c(4L, 3L),
      input_fanin = c(3L, 1L), interlayer_fanin = c(1L, 5L),
      row_normalize_inputs = TRUE
    ),
    w_dist = function(n) runif(n, -1, 1),
    in_dist = function(n) runif(n, -1, 1),
    washout = 10L, add_bias = TRUE, seed = 910001L,
    fit_readout = FALSE
  )

  expect_identical(fit$reservoir$topology$mode, "exact_fanin")
  expect_true(all(rowSums(fit$reservoir$W[[1L]] != 0) == 4L))
  expect_true(all(rowSums(fit$reservoir$W[[2L]] != 0) == 3L))
  expect_true(all(rowSums(fit$reservoir$Win[[1L]] != 0) == 3L))
  expect_true(all(rowSums(fit$reservoir$Win[[2L]] != 0) == 5L))
  expect_equal(sqrt(rowSums(fit$reservoir$Win[[1L]]^2)), rep(1, 12),
               tolerance = 1e-12)
  expect_equal(sqrt(rowSums(fit$reservoir$Win[[2L]]^2)), rep(1, 8),
               tolerance = 1e-12)
  expect_identical(fit$meta$input_center_scale, "median_mad")
  expect_equal(fit$meta$input_bound_divisor, 3)
  expect_equal(unique(fit$meta$lag_center), median(y), tolerance = 1e-12)
  expect_true(all(fit$reservoir$Q_is_identity))
})

test_that("spectral normalization preserves the failed 300-unit fan-in case", {
  y <- sin(seq_len(90) / 7) + cos(seq_len(90) / 19)
  fit <- qdesn_fit_vb(
    y = y, p0 = 0.5, D = 2L, n = c(150L, 300L), n_tilde = 150L,
    m = 15L, standardize_inputs = TRUE,
    input_center_scale = "mean_sd", input_bound = "tanh",
    input_bound_divisor = 3, win_scale_global = 1,
    alpha = 0.470584459965098,
    rho = rep(0.969479367788519, 2L),
    pi_w = 0.1, pi_in = 0.1,
    topology = list(
      mode = "exact_fanin", recurrent_indegree = rep(20L, 2L),
      input_fanin = rep(16L, 2L), interlayer_fanin = rep(25L, 2L),
      row_normalize_inputs = TRUE
    ),
    w_dist = function(n) runif(n, -1, 1),
    in_dist = function(n) runif(n, -1, 1),
    washout = 20L, add_bias = TRUE, seed = 97278416L,
    fit_readout = FALSE
  )

  expect_true(all(rowSums(fit$reservoir$W[[1L]] != 0) == 20L))
  expect_true(all(rowSums(fit$reservoir$W[[2L]] != 0) == 20L))
  expect_equal(
    fit$reservoir$spectral_diagnostics$achieved_rho,
    rep(0.969479367788519, 2L), tolerance = 1e-8
  )
  expect_true(all(fit$reservoir$spectral_diagnostics$leaky_radius < 1))
  expect_true(all(
    fit$reservoir$spectral_diagnostics$achieved_method ==
      "dense_exact_scaled_eigenvalues"
  ))
})

test_that("large approximate spectral radii require a verified eigenpair", {
  set.seed(97278416L)
  A <- matrix(rnorm(520L^2), 520L, 520L)
  details <- .qdesn_spectral_radius_details(A, dense_threshold = 32L)
  expect_true(is.finite(details$radius))
  expect_true(details$method %in% c(
    "rspectra_residual_verified", "dense_fallback_residual",
    "dense_fallback_solver_failure"
  ))
  if (identical(details$method, "rspectra_residual_verified")) {
    expect_lte(details$approximate_residual, 1e-7)
  }
})

test_that("Normal recursive forecasts accept an explicit teacher-forced origin state", {
  set.seed(12)
  y <- 10 + 0.02 * seq_len(100) + sin(seq_len(100) / 7) +
    rnorm(100, sd = 0.05)
  fit <- qdesn_fit_normal(
    y = y, p0 = 0.5, D = 1L, n = 8L, n_tilde = integer(), m = 3L,
    standardize_inputs = TRUE, input_center_scale = "mean_sd",
    input_bound = "tanh", input_bound_divisor = 3,
    alpha = 0.5, rho = 0.7, pi_w = 0.2, pi_in = 1,
    topology = list(
      mode = "exact_fanin", recurrent_indegree = 3L,
      input_fanin = 4L, interlayer_fanin = 1L,
      row_normalize_inputs = TRUE
    ),
    w_dist = function(n) runif(n, -1, 1),
    in_dist = function(n) runif(n, -1, 1),
    washout = 5L, add_bias = TRUE, seed = 910001L,
    normal_args = list(beta_prior_type = "scaled_ridge")
  )
  draws <- normal_desn_posterior_draws(fit, nd = 4L, seed = 77L)
  origin_state <- list(fit$states$H_all[[1L]][80L, ])
  out <- forecast_paths.qdesn_normal_fit(
    fit, H = 3L, nd = 4L, y_hist = y[seq_len(80L)],
    origin_state = origin_state, draws = draws, seed = 88L
  )
  expect_equal(dim(out$mu_draws), c(3L, 4L))
  expect_true(all(is.finite(out$mu_draws)))
})

test_that("Woodbury Normal-RHS moments match the full covariance solver", {
  set.seed(13)
  X <- cbind(1, matrix(rnorm(45 * 11), 45, 11))
  y <- as.numeric(X %*% c(2, rep(c(0.4, -0.2), length.out = 11)) +
                    rnorm(45, sd = 0.2))
  common <- list(
    X = X, y = y, beta_prior_type = "rhs_ns",
    rhs = list(tau0 = 1e-3, shrink_intercept = FALSE),
    omega_prior = list(a = 2, b = 1)
  )
  full <- do.call(normal_desn_fit, c(
    common,
    list(control = list(max_iter = 4L, min_iter = 4L, tol = 0,
                        covariance = "full"))
  ))
  dual <- do.call(normal_desn_fit, c(
    common,
    list(control = list(max_iter = 4L, min_iter = 4L, tol = 0,
                        covariance = "woodbury_diagonal"))
  ))

  expect_equal(dual$beta$mean, full$beta$mean, tolerance = 1e-8)
  expect_equal(diag(dual$beta$cov), diag(full$beta$cov), tolerance = 1e-8)
  expect_equal(dual$omega2$mean, full$omega2$mean, tolerance = 1e-8)
  expect_identical(
    dual$qbeta$covariance_approximation,
    "woodbury_exact_marginals_diagonal_storage"
  )
})
