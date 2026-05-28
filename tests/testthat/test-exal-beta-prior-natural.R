make_beta_prior_natural_data <- function(n = 34L, seed = 20260620L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x)
  beta <- c(0.05, 0.12)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.05))
  list(X = X, y = y, beta = beta)
}

make_beta_prior_natural_control <- function(chunking = NULL, max_iter = 12L) {
  ctrl <- list(
    max_iter = as.integer(max_iter),
    min_iter_elbo = 3L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE
  )
  if (!is.null(chunking)) ctrl$chunking <- chunking
  ctrl
}

fit_beta_prior_natural_al <- function(dat, prior, ctrl = make_beta_prior_natural_control()) {
  exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "al",
    al_fixed_gamma = 0,
    vb_control = ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
}

test_that("beta solve is unchanged when no prior natural hook is supplied", {
  dat <- make_beta_prior_natural_data(n = 13L)
  xis <- list(
    xi1 = 1.25,
    xi_lambda = 0.35,
    xi_lambda2 = 0.12,
    xi_A = -0.18,
    xi_A2 = 0.42,
    xi_siginv = 1.1,
    zeta_lam = 0.04
  )
  qv_m_inv <- seq(1.4, 0.7, length.out = nrow(dat$X))
  qs_m <- seq(0.6, 1.1, length.out = nrow(dat$X))
  stats <- exdqlm:::.exal_beta_data_stats(
    X = dat$X,
    y = dat$y,
    xis = xis,
    qv_m_inv = qv_m_inv,
    qs_m = qs_m
  )
  prec_diag <- c(1.0e-8, 0.7)

  old_surface <- exdqlm:::.exal_beta_solve_from_data_stats(stats, prec_diag)
  explicit_null <- exdqlm:::.exal_beta_solve_from_data_stats(
    stats,
    prec_diag,
    prior_precision = NULL,
    prior_natural = NULL
  )

  expect_equal(explicit_null$P, old_surface$P, tolerance = 1e-14)
  expect_equal(explicit_null$h, old_surface$h, tolerance = 1e-14)
  expect_equal(explicit_null$sol$x, old_surface$sol$x, tolerance = 1e-14)
})

test_that("gaussian_natural beta prior validates dimensions and exposes natural parameters", {
  P <- matrix(c(3, 0.4, 0.4, 2), 2, 2)
  m <- c(0.2, -0.3)
  prior <- exdqlm::beta_prior(
    "gaussian_natural",
    gaussian = list(precision = P, mean = m)
  )
  state <- prior$init(2L)
  nat <- prior$natural_params(state, 2L)

  expect_identical(prior$type, "gaussian_natural")
  expect_equal(prior$expected_prec(state, 2L), diag(P), tolerance = 1e-14)
  expect_equal(diag(nat$precision), c(0, 0), tolerance = 1e-14)
  expect_equal(nat$precision + diag(diag(P)), P, tolerance = 1e-14)
  expect_equal(nat$natural, as.numeric(P %*% m), tolerance = 1e-14)
  expect_true(is.finite(prior$elbo(state, list(m = m, V = diag(0.1, 2)))$elbo))

  expect_error(
    exdqlm::beta_prior(
      "gaussian_natural",
      gaussian = list(precision = P, natural = c(1, 2, 3))
    ),
    "length p=2"
  )
  expect_error(
    exdqlm::beta_prior(
      "gaussian_natural",
      gaussian = list(precision = matrix(c(1, 2, 2, 1), 2, 2))
    ),
    "positive definite"
  )
})

test_that("nonzero gaussian_natural prior mean shifts AL beta posterior", {
  dat <- make_beta_prior_natural_data()
  zero_prior <- exdqlm::beta_prior(
    "gaussian_natural",
    gaussian = list(precision = diag(c(0.5, 0.5)), mean = c(0, 0))
  )
  positive_prior <- exdqlm::beta_prior(
    "gaussian_natural",
    gaussian = list(precision = diag(c(0.5, 80)), mean = c(0, 0.9))
  )

  fit_zero <- fit_beta_prior_natural_al(dat, zero_prior)
  fit_positive <- fit_beta_prior_natural_al(dat, positive_prior)

  expect_true(all(is.finite(fit_zero$qbeta$m)))
  expect_true(all(is.finite(fit_positive$qbeta$m)))
  expect_gt(fit_positive$qbeta$m[2], fit_zero$qbeta$m[2] + 0.02)
})

test_that("exact chunking matches unchunked AL with nonzero gaussian_natural prior", {
  dat <- make_beta_prior_natural_data(seed = 20260621L)
  prior <- exdqlm::beta_prior(
    "gaussian_natural",
    gaussian = list(
      precision = matrix(c(2.5, 0.3, 0.3, 1.7), 2, 2),
      mean = c(0.1, -0.25)
    )
  )
  plain_ctrl <- make_beta_prior_natural_control(max_iter = 14L)
  exact_ctrl <- make_beta_prior_natural_control(
    chunking = list(enabled = TRUE, mode = "exact", chunk_size = 7L),
    max_iter = 14L
  )

  plain <- fit_beta_prior_natural_al(dat, prior, plain_ctrl)
  exact <- fit_beta_prior_natural_al(dat, prior, exact_ctrl)

  expect_equal(exact$qbeta$m, plain$qbeta$m, tolerance = 1e-8)
  expect_equal(exact$qbeta$V, plain$qbeta$V, tolerance = 1e-8)
  expect_equal(exact$qv$m, plain$qv$m, tolerance = 1e-8)
  expect_equal(exact$qs$m, plain$qs$m, tolerance = 1e-8)
  expect_equal(exact$misc$elbo_trace, plain$misc$elbo_trace, tolerance = 1e-8)
})
