test_that("M0 GIG decomposition matches the expanded exAL scale-shape kernel", {
  set.seed(1701)
  n <- 14L
  y <- stats::rnorm(n)
  fitted <- seq(-0.2, 0.2, length.out = n)
  s <- abs(stats::rnorm(n)) + 0.05
  v <- abs(stats::rnorm(n)) + 0.05
  a_sigma <- 1
  b_sigma <- 1
  sigma_grid <- exp(seq(log(0.08), log(3), length.out = 7L))
  log_prior <- function(gamma) stats::dnorm(gamma, 0, sqrt(10), log = TRUE)

  for (tau in c(0.05, 0.25, 0.5)) {
    lower <- L.fn(tau)
    upper <- U.fn(tau)
    gamma <- lower + 0.58 * (upper - lower)
    A <- A.fn(tau, gamma)
    B <- B.fn(tau, gamma)
    Cabs <- C.fn(tau, gamma) * abs(gamma)
    stats <- exdqlm:::.exal_mcmc_collapsed_sufficient_stats(y, fitted, s, v)
    decomposed <- vapply(sigma_grid, function(sigma) {
      exdqlm:::.exal_mcmc_sigma_gamma_log_kernel(
        sigma, gamma, stats, A, B, Cabs, a_sigma, b_sigma, log_prior
      )
    }, numeric(1L))
    expanded <- vapply(sigma_grid, function(sigma) {
      residual <- y - fitted - A * v - Cabs * sigma * s
      -0.5 * sum(log(B * sigma * v) + residual^2 / (B * sigma * v)) -
        n * log(sigma) - sum(v) / sigma -
        (a_sigma + 1) * log(sigma) - b_sigma / sigma + log_prior(gamma)
    }, numeric(1L))
    expect_equal(decomposed, expanded, tolerance = 1e-9)
  }
})

test_that("M0 collapsed gamma target agrees with direct numerical integration", {
  set.seed(1702)
  n <- 10L
  y <- stats::rnorm(n)
  fitted <- stats::rnorm(n, sd = 0.2)
  s <- abs(stats::rnorm(n)) + 0.1
  v <- abs(stats::rnorm(n)) + 0.1
  log_prior <- function(gamma) stats::dnorm(gamma, 0, sqrt(10), log = TRUE)

  for (tau in c(0.05, 0.25, 0.5)) {
    lower <- L.fn(tau)
    upper <- U.fn(tau)
    gamma <- lower + 0.43 * (upper - lower)
    A <- A.fn(tau, gamma)
    B <- B.fn(tau, gamma)
    Cabs <- C.fn(tau, gamma) * abs(gamma)
    stats <- exdqlm:::.exal_mcmc_collapsed_sufficient_stats(y, fitted, s, v)
    analytic <- exdqlm:::.exal_mcmc_gamma_collapsed_log_kernel(
      gamma, stats, A, B, Cabs, 1, 1, log_prior
    )
    log_integrand <- function(u) {
      vapply(u, function(u_one) {
        exdqlm:::.exal_mcmc_sigma_gamma_log_kernel(
          exp(u_one), gamma, stats, A, B, Cabs, 1, 1, log_prior
        ) + u_one
      }, numeric(1L))
    }
    mode <- optimize(function(u) -log_integrand(u), c(-12, 10))$minimum
    peak <- log_integrand(mode)
    numeric_integral <- peak + log(stats::integrate(
      function(u) exp(log_integrand(u) - peak),
      lower = -20,
      upper = 20,
      subdivisions = 500L,
      rel.tol = 1e-9
    )$value)
    expect_equal(analytic, numeric_integral, tolerance = 1e-6)
  }
})

test_that("M0 uses a stable large-order GIG normalizer at validation scale", {
  set.seed(1706)
  for (n in c(500L, 890L)) {
    y <- stats::rnorm(n)
    fitted <- stats::rnorm(n, sd = 0.2)
    s <- abs(stats::rnorm(n)) + 0.1
    v <- stats::rexp(n) + 0.1
    sufficient <- exdqlm:::.exal_mcmc_collapsed_sufficient_stats(
      y, fitted, s, v
    )
    terms <- exdqlm:::.exal_mcmc_collapsed_gig_terms(
      gamma = 0.2, stats = sufficient, A = 0.5, B = 3, Cabs = 1.2,
      a_sigma = 1, b_sigma = 1
    )
    stable <- exdqlm:::.exal_mcmc_gig_log_integral(
      terms$lambda, terms$chi, terms$psi
    )
    numeric <- exdqlm:::.exal_mcmc_gig_log_integral_numeric_one(
      terms$lambda, terms$chi, terms$psi
    )
    expect_true(is.finite(stable))
    expect_equal(stable, numeric, tolerance = 1e-8)
  }
})

test_that("M0 transition is deterministic and remains inside gamma support", {
  set.seed(1703)
  tau <- 0.25
  lower <- L.fn(tau)
  upper <- U.fn(tau)
  y <- stats::rnorm(18)
  fitted <- stats::rnorm(18, sd = 0.1)
  s <- abs(stats::rnorm(18)) + 0.05
  v <- abs(stats::rnorm(18)) + 0.05
  args <- list(
    sigma = 1,
    eta_gamma = stats::qlogis((0 - lower) / (upper - lower)),
    y = y,
    fitted = fitted,
    s = s,
    v = v,
    lower = lower,
    upper = upper,
    A_of = function(gamma) A.fn(tau, gamma),
    B_of = function(gamma) B.fn(tau, gamma),
    Cabs_of = function(gamma) C.fn(tau, gamma) * abs(gamma),
    log_prior_gamma = function(gamma) stats::dnorm(gamma, 0, sqrt(10), log = TRUE),
    a_sigma = 1,
    b_sigma = 1,
    width = 1,
    max_steps_out = 80L,
    max_shrink = 300L
  )
  draw_a <- local({
    set.seed(1704)
    do.call(exdqlm:::.exal_mcmc_collapsed_scale_shape_draw, args)
  })
  draw_b <- local({
    set.seed(1704)
    do.call(exdqlm:::.exal_mcmc_collapsed_scale_shape_draw, args)
  })
  expect_identical(draw_a, draw_b)
  expect_gt(draw_a$sigma, 0)
  expect_gt(draw_a$gamma, lower)
  expect_lt(draw_a$gamma, upper)
  expect_gt(draw_a$gamma_density_evaluations, 0L)
})

test_that("M0 is opt-in, exAL-only, and leaves the legacy default unchanged", {
  legacy <- exal_make_mcmc_control(n_burn = 2L, n_mcmc = 3L, init_from_vb = FALSE)
  expect_identical(legacy$slice$core_update_mode, "sigma_then_gamma")

  m0 <- exal_make_mcmc_control(
    n_burn = 2L,
    n_mcmc = 3L,
    init_from_vb = FALSE,
    slice = list(core_update_mode = "m0_v_collapsed_support_logit")
  )
  expect_identical(m0$slice$core_update_mode, "m0_v_collapsed_support_logit")

  y <- c(-0.4, 0.1, 0.3, 0.8, -0.2, 0.5)
  X <- cbind(1, seq_along(y) / length(y))
  expect_error(
    exal_mcmc_fit(
      y = y,
      X = X,
      p0 = 0.25,
      gamma_bounds = c(L.fn(0.25), U.fn(0.25)),
      likelihood_family = "al",
      mcmc_control = m0,
      init = list(beta = c(0, 0), sigma = 1, gamma = 0),
      beta_prior_obj = exal_make_beta_prior("ridge", tau2 = 10)
    ),
    "available only for exAL"
  )
})

test_that("a tiny M0 fit records finite method-specific telemetry", {
  set.seed(1705)
  y <- stats::rnorm(20)
  X <- cbind(1, stats::rnorm(20))
  control <- exal_make_mcmc_control(
    n_burn = 5L,
    n_mcmc = 10L,
    thin = 1L,
    init_from_vb = FALSE,
    slice = list(
      core_update_mode = "m0_v_collapsed_support_logit",
      width_gamma = 1,
      max_steps_out = 20L,
      max_shrink = 100L
    )
  )
  fit <- exal_mcmc_fit(
    y = y,
    X = X,
    p0 = 0.25,
    gamma_bounds = c(L.fn(0.25), U.fn(0.25)),
    mcmc_control = control,
    init = list(beta = c(0, 0), sigma = 1, gamma = 0),
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = exal_make_beta_prior("ridge", tau2 = 10)
  )
  expect_identical(fit$diagnostics$core_update_mode, "m0_v_collapsed_support_logit")
  expect_true(all(is.finite(fit$samp.sigma)))
  expect_true(all(is.finite(fit$samp.gamma)))
  expect_gt(fit$diagnostics$gamma_density_evaluations_mean, 0)
})
