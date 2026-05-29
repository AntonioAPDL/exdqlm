`%||%` <- function(a, b) if (is.null(a)) b else a

make_beta_covariance_test_data <- function(n = 42L, seed = 20260630L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, z = scale(x^2, scale = FALSE)[, 1])
  beta <- c(0.1, 0.25, -0.1)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.06))
  list(X = X, y = y, beta = beta)
}

make_beta_covariance_control <- function(beta_covariance = NULL,
                                         chunking = NULL,
                                         max_iter = 10L) {
  ctrl <- list(
    max_iter = as.integer(max_iter),
    min_iter_elbo = 3L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE
  )
  if (!is.null(beta_covariance)) ctrl$beta_covariance <- beta_covariance
  if (!is.null(chunking)) ctrl$chunking <- chunking
  ctrl
}

make_beta_covariance_rhs_prior <- function(type = c("rhs", "rhs_ns")) {
  type <- match.arg(type)
  rhs <- if (identical(type, "rhs")) {
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
  exdqlm:::exal_make_beta_prior(type = type, rhs = rhs)
}

fit_beta_covariance_al <- function(dat, ctrl, prior = NULL, family = "al") {
  prior <- prior %||% exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 20)
  exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = family,
    al_fixed_gamma = 0,
    vb_control = ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
}

test_that("beta covariance controls normalize without changing absent defaults", {
  expect_false("beta_covariance" %in% names(exdqlm::exal_make_vb_control()))

  full <- exdqlm::exal_make_vb_control(
    beta_covariance = list(approximation = "full")
  )$beta_covariance
  expect_identical(full$approximation, "full")
  expect_true(isTRUE(full$label_uncertainty))

  diagonal <- exdqlm::exal_make_vb_control(
    beta_covariance = list(approximation = "diagonal", label_uncertainty = TRUE)
  )$beta_covariance
  expect_identical(diagonal$approximation, "diagonal")
  expect_true(isTRUE(diagonal$label_uncertainty))

  expect_error(
    exdqlm::exal_make_vb_control(beta_covariance = list(approximation = "low_rank")),
    "must be 'full' or 'diagonal'"
  )
})

test_that("diagonal beta solve uses the documented diagonal formula", {
  S <- matrix(c(3, 0.4, 0.4, 2), 2, 2)
  stats <- list(S = S, g = c(1.2, -0.4), barw = 1, barm = 0)
  prec_diag <- c(0.5, 0.25)
  solved <- exdqlm:::.exal_beta_solve_diagonal_from_data_stats(stats, prec_diag)
  P_diag <- diag(S) + prec_diag

  expect_equal(diag(solved$P), P_diag, tolerance = 1e-14)
  expect_equal(solved$sol$x, stats$g / P_diag, tolerance = 1e-14)
  expect_equal(diag(solved$sol$inv), 1 / P_diag, tolerance = 1e-14)
  expect_equal(solved$sol$inv[lower.tri(solved$sol$inv)], rep(0, 1), tolerance = 1e-14)
  expect_error(
    exdqlm:::.exal_beta_solve_diagonal_from_data_stats(stats, prec_diag, prior_natural = c(1, 2)),
    "expected-precision priors"
  )
})

test_that("default full covariance is unchanged by explicit full control", {
  dat <- make_beta_covariance_test_data()
  plain <- fit_beta_covariance_al(dat, make_beta_covariance_control())
  explicit_full <- fit_beta_covariance_al(
    dat,
    make_beta_covariance_control(beta_covariance = list(approximation = "full"))
  )

  expect_false(isTRUE(plain$misc$approximate_covariance))
  expect_false(isTRUE(explicit_full$misc$approximate_covariance))
  expect_equal(explicit_full$qbeta$m, plain$qbeta$m, tolerance = 1e-12)
  expect_equal(explicit_full$qbeta$V, plain$qbeta$V, tolerance = 1e-12)
  expect_equal(explicit_full$misc$elbo_trace, plain$misc$elbo_trace, tolerance = 1e-12)
})

test_that("diagonal beta covariance AL ridge fit is finite and labeled approximate", {
  dat <- make_beta_covariance_test_data(seed = 20260631L)
  ctrl <- make_beta_covariance_control(beta_covariance = list(approximation = "diagonal"))
  fit <- fit_beta_covariance_al(dat, ctrl)

  expect_identical(fit$misc$beta_covariance$approximation, "diagonal")
  expect_true(isTRUE(fit$misc$approximate_covariance))
  expect_match(fit$misc$covariance_objective_note, "approximate")
  expect_identical(fit$qbeta$covariance_approximation, "diagonal")
  expect_true(isTRUE(fit$qbeta$approximate_covariance))
  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(all(is.finite(diag(fit$qbeta$V))))
  expect_true(all(diag(fit$qbeta$V) > 0))
  expect_equal(fit$qbeta$V[lower.tri(fit$qbeta$V)], rep(0, 3), tolerance = 1e-14)
})

test_that("diagonal beta covariance supports global RHS-family AL priors", {
  dat <- make_beta_covariance_test_data(seed = 20260635L)
  ctrl <- make_beta_covariance_control(
    beta_covariance = list(approximation = "diagonal"),
    max_iter = 8L
  )

  for (prior_type in c("rhs", "rhs_ns")) {
    prior <- make_beta_covariance_rhs_prior(prior_type)
    fit <- fit_beta_covariance_al(dat, ctrl, prior = prior)

    expect_identical(fit$beta_prior$type, prior_type)
    expect_identical(fit$misc$beta_covariance$approximation, "diagonal")
    expect_true(isTRUE(fit$misc$approximate_covariance))
    expect_identical(fit$qbeta$covariance_approximation, "diagonal")
    expect_true(isTRUE(fit$qbeta$approximate_covariance))
    expect_true(all(is.finite(fit$qbeta$m)))
    expect_true(all(is.finite(diag(fit$qbeta$V))))
    expect_true(all(diag(fit$qbeta$V) > 0))

    prec <- prior$expected_prec(fit$beta_prior$state, ncol(dat$X))
    expect_true(all(is.finite(prec)))
    expect_true(all(prec > 0))
    expect_false(isTRUE(fit$beta_prior$hypers$shrink_intercept))
  }
})

test_that("diagonal exact chunking matches diagonal unchunked AL ridge", {
  dat <- make_beta_covariance_test_data(seed = 20260632L)
  diag_cov <- list(approximation = "diagonal")
  plain <- fit_beta_covariance_al(
    dat,
    make_beta_covariance_control(beta_covariance = diag_cov, max_iter = 12L)
  )
  exact <- fit_beta_covariance_al(
    dat,
    make_beta_covariance_control(
      beta_covariance = diag_cov,
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 8L),
      max_iter = 12L
    )
  )

  expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
  expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
  expect_equal(exact$misc$elbo_trace, plain$misc$elbo_trace, tolerance = 1e-8)
})

test_that("diagonal exact chunking matches diagonal unchunked AL RHS-family priors", {
  dat <- make_beta_covariance_test_data(seed = 20260636L, n = 36L)
  diag_cov <- list(approximation = "diagonal")

  for (prior_type in c("rhs", "rhs_ns")) {
    prior <- make_beta_covariance_rhs_prior(prior_type)
    plain <- fit_beta_covariance_al(
      dat,
      make_beta_covariance_control(beta_covariance = diag_cov, max_iter = 9L),
      prior = prior
    )
    exact <- fit_beta_covariance_al(
      dat,
      make_beta_covariance_control(
        beta_covariance = diag_cov,
        chunking = list(enabled = TRUE, mode = "exact", chunk_size = 7L),
        max_iter = 9L
      ),
      prior = make_beta_covariance_rhs_prior(prior_type)
    )

    expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
    expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
    expect_equal(exact$misc$elbo_trace, plain$misc$elbo_trace, tolerance = 1e-8)
    expect_equal(exact$misc$rhs_tau_trace, plain$misc$rhs_tau_trace, tolerance = 1e-8)
    expect_equal(exact$misc$rhs_c2_trace, plain$misc$rhs_c2_trace, tolerance = 1e-8)
  }
})

test_that("diagonal beta covariance supports exAL ridge full/exact scope", {
  dat <- make_beta_covariance_test_data(seed = 20260633L, n = 40L)
  diag_cov <- list(approximation = "diagonal")
  plain <- fit_beta_covariance_al(
    dat,
    make_beta_covariance_control(beta_covariance = diag_cov, max_iter = 8L),
    family = "exal"
  )
  exact <- fit_beta_covariance_al(
    dat,
    make_beta_covariance_control(
      beta_covariance = diag_cov,
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 7L),
      max_iter = 8L
    ),
    family = "exal"
  )

  expect_identical(plain$misc$beta_covariance$approximation, "diagonal")
  expect_true(isTRUE(plain$misc$approximate_covariance))
  expect_identical(plain$qbeta$covariance_approximation, "diagonal")
  expect_true(all(is.finite(plain$qbeta$m)))
  expect_true(all(diag(plain$qbeta$V) > 0))
  expect_lt(max(abs(exact$qbeta$m - plain$qbeta$m)), 1e-6)
  expect_lt(max(abs(exact$qbeta$V - plain$qbeta$V)), 1e-6)
  expect_lt(max(abs(exact$misc$sigma_trace - plain$misc$sigma_trace)), 1e-6)
  expect_lt(max(abs(exact$misc$gamma_trace - plain$misc$gamma_trace)), 2e-6)
  expect_lt(max(abs(exact$misc$elbo_trace - plain$misc$elbo_trace)), 1e-6)
})

test_that("diagonal covariance stage fails early outside supported full/exact scope", {
  dat <- make_beta_covariance_test_data(seed = 20260639L, n = 30L)
  ctrl <- make_beta_covariance_control(beta_covariance = list(approximation = "diagonal"))
  rhs_prior <- make_beta_covariance_rhs_prior("rhs")
  expect_error(
    fit_beta_covariance_al(dat, ctrl, prior = rhs_prior, family = "exal"),
    "exAL diagonal beta covariance approximation is currently supported only for ridge beta priors"
  )

  stoch_ctrl <- make_beta_covariance_control(
    beta_covariance = list(approximation = "diagonal"),
    chunking = list(enabled = TRUE, mode = "stochastic", chunk_size = 8L)
  )
  expect_error(
    fit_beta_covariance_al(dat, stoch_ctrl),
    "unchunked or exact chunked"
  )
})

test_that("diagonal beta covariance keeps unsupported prior corrections forbidden", {
  dat <- make_beta_covariance_test_data(seed = 20260637L, n = 26L)
  ctrl <- make_beta_covariance_control(beta_covariance = list(approximation = "diagonal"))
  P <- diag(c(2, 3, 4), 3)
  gaussian_prior <- exdqlm::beta_prior(
    type = "gaussian_natural",
    gaussian = list(precision = P, mean = c(1, 0, 0))
  )

  expect_error(
    fit_beta_covariance_al(dat, ctrl, prior = gaussian_prior),
    "ridge and RHS-family beta priors"
  )
})

test_that("qdesn_fit_vb routes diagonal covariance controls for AL ridge", {
  t <- seq_len(30L)
  y <- as.numeric(0.18 * sin(t / 4) + 0.05 * cos(t / 6))
  args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10,
    max_iter = 8L,
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    beta_covariance = list(approximation = "diagonal")
  )
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260634L,
    fit_readout = TRUE,
    vb_args = args
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(fit$fit$misc$beta_covariance$approximation, "diagonal")
  expect_true(isTRUE(fit$fit$misc$approximate_covariance))
  expect_true(all(is.finite(fit$fit$qbeta$m)))
  expect_true(all(diag(fit$fit$qbeta$V) > 0))
})

test_that("qdesn_fit_vb routes diagonal covariance controls for exAL ridge", {
  t <- seq_len(32L)
  y <- as.numeric(0.15 * sin(t / 5) + 0.03 * cos(t / 7))
  args <- list(
    likelihood_family = "exal",
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10,
    max_iter = 7L,
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    beta_covariance = list(approximation = "diagonal")
  )
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260639L,
    fit_readout = TRUE,
    vb_args = args
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(fit$fit$misc$beta_covariance$approximation, "diagonal")
  expect_true(isTRUE(fit$fit$misc$approximate_covariance))
  expect_identical(fit$fit$likelihood_family, "exal")
  expect_true(all(is.finite(fit$fit$qbeta$m)))
  expect_true(all(diag(fit$fit$qbeta$V) > 0))
})

test_that("qdesn_fit_vb routes diagonal covariance controls for AL RHS_NS", {
  t <- seq_len(34L)
  y <- as.numeric(0.12 * sin(t / 5) + 0.04 * cos(t / 7))
  args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    beta_prior_type = "rhs_ns",
    beta_rhs = list(
      tau0 = 0.8,
      s2 = 1.25,
      zeta2_fixed = 1.25,
      shrink_intercept = FALSE,
      n_inner = 1L
    ),
    max_iter = 7L,
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    beta_covariance = list(approximation = "diagonal")
  )
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260638L,
    fit_readout = TRUE,
    vb_args = args
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(fit$fit$beta_prior$type, "rhs_ns")
  expect_identical(fit$fit$misc$beta_covariance$approximation, "diagonal")
  expect_true(isTRUE(fit$fit$misc$approximate_covariance))
  expect_false(isTRUE(fit$fit$beta_prior$hypers$shrink_intercept))
  expect_true(all(is.finite(fit$fit$qbeta$m)))
  expect_true(all(diag(fit$fit$qbeta$V) > 0))
})
