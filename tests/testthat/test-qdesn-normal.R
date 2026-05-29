`%||%` <- function(x, y) if (is.null(x)) y else x

make_normal_desn_fixed_data <- function(n = 40L, seed = 20260529L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, z = x^2 - mean(x^2))
  beta <- c(0.3, -0.4, 0.25)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y, beta = beta)
}

make_normal_desn_rhs <- function(type = c("rhs", "rhs_ns")) {
  type <- match.arg(type)
  if (identical(type, "rhs")) {
    list(
      tau0 = 0.8,
      nu = 4,
      s2 = 1.25,
      shrink_intercept = FALSE,
      intercept_prec = 1e-12,
      n_inner = 1L,
      eta_bounds = list(lambda = c(-8, 8), tau = c(-8, 8), c2 = c(-8, 8)),
      init_log_lambda = 0,
      init_log_tau = 0,
      init_log_c2 = 0
    )
  } else {
    list(
      tau0 = 0.8,
      a_zeta = 2,
      b_zeta = 1,
      zeta2_fixed = 1.25,
      s2 = 1.25,
      shrink_intercept = FALSE,
      intercept_prec = 1e-12,
      n_inner = 1L,
      init_lambda2 = 1,
      init_tau2 = 1,
      init_xi = 1,
      init_zeta2 = 1.25
    )
  }
}

tiny_normal_qdesn_series <- function(n = 36L) {
  t <- seq_len(n)
  as.numeric(0.4 * sin(t / 4) + 0.05 * t / n + 0.03 * cos(t / 2))
}

test_that("normal_desn_fit scaled ridge matches closed-form posterior algebra", {
  dat <- make_normal_desn_fixed_data()
  P <- diag(c(1e-6, 1 / 20, 1 / 20), ncol(dat$X))
  b <- c(0.1, 0, 0)
  omega <- list(a = 2.5, b = 1.3)

  fit <- exdqlm::normal_desn_fit(
    dat$X,
    dat$y,
    beta_prior_type = "scaled_ridge",
    prior = list(mean = b, precision = P),
    omega_prior = omega
  )

  Pn <- P + crossprod(dat$X)
  hn <- as.numeric(P %*% b + crossprod(dat$X, dat$y))
  mn <- as.numeric(solve(Pn, hn))
  an <- omega$a + nrow(dat$X) / 2
  Bn <- omega$b + 0.5 * (
    as.numeric(crossprod(dat$y)) +
      as.numeric(crossprod(b, P %*% b)) -
      as.numeric(crossprod(mn, Pn %*% mn))
  )
  Vn <- Bn / (an - 1) * solve(Pn)

  expect_s3_class(fit, "normal_desn_readout")
  expect_true(isTRUE(fit$exact_closed_form))
  expect_false(isTRUE(fit$uses_vb))
  expect_identical(fit$target, "conditional_mean")
  expect_identical(fit$target_label, "normal_scaled_ridge_exact")
  expect_equal(fit$beta$mean, mn, tolerance = 1e-10)
  expect_equal(fit$omega2$a, an, tolerance = 1e-12)
  expect_equal(fit$omega2$b, Bn, tolerance = 1e-10)
  expect_equal(unname(fit$beta$cov), unname(Vn), tolerance = 1e-10)
  expect_equal(fit$mu_hat, as.numeric(dat$X %*% mn), tolerance = 1e-12)
  expect_true(is.finite(fit$log_marginal))
})

test_that("normal_desn_fit exact chunked scaled ridge matches unchunked", {
  dat <- make_normal_desn_fixed_data(n = 43L, seed = 20260536L)
  prior <- list(
    mean = c(0.05, 0, 0),
    precision = diag(c(1e-6, 1 / 25, 1 / 30), ncol(dat$X))
  )
  omega <- list(a = 2.2, b = 0.9)
  ref <- exdqlm::normal_desn_fit(
    dat$X, dat$y,
    beta_prior_type = "scaled_ridge",
    prior = prior,
    omega_prior = omega
  )

  for (chunk_size in c(nrow(dat$X), 8L, 1L)) {
    fit <- exdqlm::normal_desn_fit(
      dat$X, dat$y,
      beta_prior_type = "scaled_ridge",
      prior = prior,
      omega_prior = omega,
      control = list(chunking = list(
        enabled = TRUE,
        mode = "exact",
        chunk_size = chunk_size,
        order = "sequential",
        trace = TRUE
      ))
    )
    expect_s3_class(fit, "normal_desn_readout")
    expect_identical(fit$target_label, "normal_scaled_ridge_exact_chunked")
    expect_true(isTRUE(fit$misc$chunking$enabled))
    expect_identical(fit$misc$chunking$mode, "exact")
    expect_equal(fit$beta$mean, ref$beta$mean, tolerance = 1e-10)
    expect_equal(fit$beta$cov, ref$beta$cov, tolerance = 1e-10)
    expect_equal(fit$beta$scale_cov, ref$beta$scale_cov, tolerance = 1e-10)
    expect_equal(fit$omega2$a, ref$omega2$a, tolerance = 1e-12)
    expect_equal(fit$omega2$b, ref$omega2$b, tolerance = 1e-10)
    expect_equal(fit$log_marginal, ref$log_marginal, tolerance = 1e-10)
    expect_equal(fit$mu_hat, ref$mu_hat, tolerance = 1e-12)
    expect_equal(fit$stats$XtX, ref$stats$XtX, tolerance = 1e-12)
    expect_equal(fit$stats$Xty, ref$stats$Xty, tolerance = 1e-12)
    expect_equal(fit$stats$yty, ref$stats$yty, tolerance = 1e-12)
    expect_true(is.data.frame(fit$stats$chunk_trace))
    expect_equal(sum(fit$stats$chunk_trace$n_rows), nrow(dat$X), tolerance = 0)
  }
})

test_that("normal_desn_fit validates scaled ridge inputs", {
  dat <- make_normal_desn_fixed_data()
  expect_error(
    exdqlm::normal_desn_fit(dat$X, dat$y[-1L]),
    "length\\(y\\)"
  )
  expect_error(
    exdqlm::normal_desn_fit(dat$X, dat$y, omega_prior = list(a = -1, b = 1)),
    "omega_prior\\$a"
  )
  expect_error(
    exdqlm::normal_desn_fit(dat$X, dat$y, prior = list(precision = diag(c(1, -1, 1)))),
    "positive definite"
  )
  expect_error(
    exdqlm::normal_desn_fit(
      dat$X, dat$y,
      control = list(chunking = list(enabled = TRUE, mode = "stochastic", chunk_size = 5L))
    ),
    "mode = 'exact'"
  )
  expect_error(
    exdqlm::normal_desn_fit(
      dat$X, dat$y,
      control = list(chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L, order = "random"))
    ),
    "order = 'sequential'"
  )
  expect_error(
    exdqlm::normal_desn_fit(
      dat$X, dat$y,
      control = list(chunking = list(enabled = TRUE, mode = "exact"))
    ),
    "chunk_size"
  )
  expect_error(
    exdqlm::normal_desn_fit(dat$X, dat$y, control = 1),
    "control must be a list"
  )
})

test_that("normal_desn_fit RHS-family priors are finite approximate VB fits", {
  dat <- make_normal_desn_fixed_data(seed = 20260530L)
  for (prior_type in c("rhs", "rhs_ns")) {
    fit <- exdqlm::normal_desn_fit(
      dat$X,
      dat$y,
      beta_prior_type = prior_type,
      rhs = make_normal_desn_rhs(prior_type),
      omega_prior = list(a = 2, b = 1),
      control = list(max_iter = 8L, min_iter = 3L, tol = 0)
    )
    expect_s3_class(fit, "normal_desn_readout")
    expect_false(isTRUE(fit$exact_closed_form))
    expect_true(isTRUE(fit$uses_vb))
    expect_match(fit$target_label, "vb_approx")
    expect_true(all(is.finite(fit$beta$mean)))
    expect_true(all(is.finite(fit$beta$cov)))
    expect_true(all(diag(fit$beta$cov) > 0))
    expect_true(is.data.frame(fit$trace))
    expect_gte(nrow(fit$trace), 3L)
    expect_true(all(is.finite(fit$trace$sigma2_mean)))
    expect_false(isTRUE(fit$beta_prior$hypers$shrink_intercept))
  }
  expect_error(
    exdqlm::normal_desn_fit(
      dat$X,
      dat$y,
      beta_prior_type = "rhs_ns",
      rhs = make_normal_desn_rhs("rhs_ns"),
      control = list(chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L))
    ),
    "RHS/RHS_NS chunking"
  )
})

test_that("Normal DESN posterior draws and predictions are reproducible", {
  dat <- make_normal_desn_fixed_data(seed = 20260531L)
  fit <- exdqlm::normal_desn_fit(dat$X, dat$y)
  draws1 <- exdqlm::normal_desn_posterior_draws(fit, nd = 25L, seed = 99L)
  draws2 <- exdqlm::normal_desn_posterior_draws(fit, nd = 25L, seed = 99L)
  pred1 <- exdqlm::normal_desn_posterior_predict(fit, nd = 25L, seed = 100L)
  pred2 <- exdqlm::normal_desn_posterior_predict(fit, nd = 25L, seed = 100L)

  expect_equal(draws1$beta, draws2$beta, tolerance = 0)
  expect_equal(draws1$omega2, draws2$omega2, tolerance = 0)
  expect_equal(dim(pred1$yrep), c(nrow(dat$X), 25L))
  expect_equal(pred1$yrep, pred2$yrep, tolerance = 0)
  expect_equal(pred1$mu_draws, pred2$mu_draws, tolerance = 0)
})

test_that("qdesn_fit_normal reuses Q-DESN design construction and returns Normal class", {
  y <- tiny_normal_qdesn_series()
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260532L,
    normal_args = list(
      beta_prior_type = "scaled_ridge",
      prior = list(beta_ridge_tau2 = 50, intercept_var = 1e6),
      omega_prior = list(a = 2, b = 1)
    )
  )

  design <- exdqlm::qdesn_build_design(
    y,
    desn_args = list(D = 1L, n = 4L, m = 1L, washout = 4L, add_bias = TRUE, seed = 20260532L)
  )

  expect_s3_class(fit, "qdesn_normal_fit")
  expect_s3_class(fit$fit, "normal_desn_readout")
  expect_equal(fit$X, design$X, tolerance = 0)
  expect_equal(fit$y_fit, y[design$keep_idx], tolerance = 0)
  expect_identical(fit$meta$likelihood_family, "normal")
  expect_identical(fit$meta$target, "conditional_mean")
  expect_true(isTRUE(fit$meta$normal$exact_closed_form))
  expect_equal(exdqlm::predict_mu.qdesn_normal_fit(fit), fit$mu_hat, tolerance = 1e-12)

  pp <- exdqlm::posterior_predict.qdesn_normal_fit(fit, nd = 10L, seed = 101L)
  expect_equal(dim(pp$yrep), c(nrow(fit$X), 10L))
})

test_that("qdesn_fit_normal forwards exact chunking to scaled-ridge readout", {
  y <- tiny_normal_qdesn_series(n = 44L)
  common_args <- list(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 5L,
    m = 1L,
    washout = 5L,
    add_bias = TRUE,
    seed = 20260537L,
    normal_args = list(
      beta_prior_type = "scaled_ridge",
      prior = list(beta_ridge_tau2 = 40, intercept_var = 1e6),
      omega_prior = list(a = 2.5, b = 1.2)
    )
  )
  ref <- do.call(exdqlm::qdesn_fit_normal, common_args)
  chunked_args <- common_args
  chunked_args$normal_args$control <- list(chunking = list(
    enabled = TRUE,
    mode = "exact",
    chunk_size = 3L,
    order = "sequential"
  ))
  fit <- do.call(exdqlm::qdesn_fit_normal, chunked_args)

  expect_s3_class(fit, "qdesn_normal_fit")
  expect_equal(fit$X, ref$X, tolerance = 0)
  expect_identical(fit$meta$target_label, "normal_scaled_ridge_exact_chunked")
  expect_true(isTRUE(fit$fit$misc$chunking$enabled))
  expect_equal(fit$fit$beta$mean, ref$fit$beta$mean, tolerance = 1e-8)
  expect_equal(fit$fit$beta$cov, ref$fit$beta$cov, tolerance = 1e-8)
  expect_equal(fit$fit$omega2$b, ref$fit$omega2$b, tolerance = 1e-8)
  expect_equal(fit$fit$log_marginal, ref$fit$log_marginal, tolerance = 1e-8)
  expect_equal(fit$mu_hat, ref$mu_hat, tolerance = 1e-10)
})

test_that("qdesn_fit_normal supports RHS-family approximate readouts", {
  y <- tiny_normal_qdesn_series()
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260533L,
    normal_args = list(
      beta_prior_type = "rhs_ns",
      rhs = make_normal_desn_rhs("rhs_ns"),
      control = list(max_iter = 6L, min_iter = 3L, tol = 0)
    )
  )

  expect_s3_class(fit, "qdesn_normal_fit")
  expect_false(isTRUE(fit$fit$exact_closed_form))
  expect_true(isTRUE(fit$fit$uses_vb))
  expect_identical(fit$meta$inference_method, "normal_vb")
  expect_true(all(is.finite(fit$mu_hat)))
  expect_true(all(is.finite(fit$fit$beta$mean)))
})

test_that("forecast_paths.qdesn_normal_fit produces reproducible recursive paths", {
  y <- tiny_normal_qdesn_series(n = 38L)
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 2L,
    washout = 5L,
    add_bias = TRUE,
    seed = 20260538L
  )
  fore1 <- exdqlm::forecast_paths.qdesn_normal_fit(
    fit,
    H = 4L,
    nd = 12L,
    seed = 333L,
    return_design = TRUE
  )
  fore2 <- exdqlm::forecast_paths.qdesn_normal_fit(
    fit,
    H = 4L,
    nd = 12L,
    seed = 333L,
    return_design = TRUE
  )

  expect_equal(dim(fore1$yrep), c(4L, 12L))
  expect_equal(dim(fore1$mu_draws), c(4L, 12L))
  expect_equal(dim(fore1$design), c(4L, 12L, ncol(fit$X)))
  expect_equal(fore1$yrep, fore2$yrep, tolerance = 0)
  expect_equal(fore1$mu_draws, fore2$mu_draws, tolerance = 0)
  expect_true(all(is.finite(fore1$yrep)))
  expect_true(all(is.finite(fore1$mu_draws)))
  expect_identical(fore1$forecast_family, "normal_recursive")

  observed <- c(0.1, 0.2, 0.3, 0.4)
  forced <- exdqlm::forecast_paths.qdesn_normal_fit(
    fit,
    H = 4L,
    nd = 5L,
    seed = 334L,
    y_future_obs = observed
  )
  expect_equal(forced$yrep, matrix(observed, nrow = 4L, ncol = 5L), tolerance = 0)
})

test_that("forecast_paths.qdesn_normal_fit fails early for unsupported settings", {
  y <- tiny_normal_qdesn_series(n = 34L)
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 3L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260539L
  )
  expect_error(
    exdqlm::forecast_paths.qdesn_normal_fit(fit, H = 2L, nd = 3L, xreg_future = list(a = 1:2)),
    "do not yet support"
  )
  expect_error(
    exdqlm::forecast_paths.qdesn_normal_fit(fit, H = 2L, nd = 3L, y_future_obs = 1),
    "length H"
  )
})

test_that("qdesn_normal_to_vb_init carries beta moments and metadata", {
  y <- tiny_normal_qdesn_series()
  fit <- exdqlm::qdesn_fit_normal(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260534L
  )
  init <- exdqlm::qdesn_normal_to_vb_init(
    fit,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    p0 = 0.5
  )

  expect_equal(init$qbeta$m, fit$fit$beta$mean, tolerance = 1e-12)
  expect_equal(init$beta_m, fit$fit$beta$mean, tolerance = 1e-12)
  expect_equal(init$beta_V, fit$fit$beta$cov + diag(1e-8, ncol(fit$X)), tolerance = 1e-12)
  expect_equal(init$beta_mean, fit$fit$beta$mean, tolerance = 1e-12)
  expect_equal(dim(init$qbeta$V), c(ncol(fit$X), ncol(fit$X)))
  expect_identical(init$source$type, "qdesn_normal_vb_init")
  expect_identical(init$source$normal_target, "normal_scaled_ridge_exact")
})

test_that("Normal DESN initializers seed AL/exAL VB and MCMC contracts", {
  y <- tiny_normal_qdesn_series(n = 32L)
  normal_fit <- exdqlm::qdesn_fit_normal(
    y = y,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260535L
  )
  vb_init <- exdqlm::qdesn_normal_to_vb_init(
    normal_fit,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    p0 = 0.5
  )
  mcmc_init <- exdqlm::qdesn_normal_to_mcmc_init(
    normal_fit,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    p0 = 0.5
  )

  expect_named(vb_init, c("beta_m", "beta_V", "qbeta", "beta_mean", "beta_cov", "sigma", "source"))
  expect_named(mcmc_init, c("beta", "sigma", "gamma", "source"))
  expect_equal(vb_init$beta_m, normal_fit$fit$beta$mean, tolerance = 1e-12)
  expect_equal(mcmc_init$beta, normal_fit$fit$beta$mean, tolerance = 1e-12)
  expect_true(is.finite(vb_init$sigma) && vb_init$sigma > 0)
  expect_true(is.finite(mcmc_init$sigma) && mcmc_init$sigma > 0)

  vb_fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260535L,
    vb_args = list(
      likelihood_family = "al",
      al_fixed_gamma = 0,
      init = vb_init,
      max_iter = 3L,
      min_iter_elbo = 2L,
      tol = 0,
      tol_par = 0,
      n_samp_xi = 16L,
      beta_prior_type = "ridge",
      beta_ridge_tau2 = 20
    )
  )
  expect_s3_class(vb_fit$fit, "exal_vb")
  expect_true(all(is.finite(vb_fit$fit$qbeta$m)))
})
