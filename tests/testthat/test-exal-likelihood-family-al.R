make_al_test_data <- function(seed = 123L, n = 36L) {
  set.seed(as.integer(seed))
  x1 <- seq(-1, 1, length.out = n)
  x2 <- sin(seq_len(n) / 4)
  X <- cbind(1, x1, x2)
  mu <- as.numeric(0.15 + 0.35 * x1 - 0.2 * x2)
  y <- mu + stats::rnorm(n, sd = 0.2)
  list(y = as.numeric(y), X = X)
}

make_rhs_ns_prior_for_tests <- function() {
  exdqlm:::exal_make_beta_prior(
    type = "rhs_ns",
    rhs = list(
      tau0 = 0.01,
      a_zeta = 2.0,
      b_zeta = 1.0,
      s2 = 0.5,
      shrink_intercept = FALSE,
      intercept_prec = 1.0e-10,
      n_inner = 2L,
      var_floor = 1.0e-8,
      init_log_tau = 0.0,
      init_log_lambda = 0.0,
      init_log_c2 = 0.0
    )
  )
}

test_that("AL VB path stays finite for ridge and rhs_ns priors", {
  dat <- make_al_test_data()
  priors <- list(
    ridge = exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 20),
    rhs_ns = make_rhs_ns_prior_for_tests()
  )

  for (nm in names(priors)) {
    fit <- exdqlm:::exal_fit(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      gamma_bounds = c(-3, 3),
      method = "vb",
      likelihood_family = "al",
      al_fixed_gamma = 0,
      vb_control = list(
        max_iter = 24L,
        min_iter_elbo = 6L,
        tol = 1e-3,
        tol_par = 1e-3,
        n_samp_xi = 48L,
        verbose = FALSE
      ),
      prior_gamma = list(mu0 = 0, s20 = 10),
      prior_sigma = list(a = 1, b = 1),
      beta_prior_obj = priors[[nm]]
    )

    expect_identical(as.character(fit$likelihood_family), "al")
    expect_true(all(is.finite(as.numeric(fit$misc$elbo))))
    expect_true(all(is.finite(as.numeric(fit$misc$sigma_trace))))
    expect_true(all(as.numeric(fit$misc$sigma_trace) > 0))
    expect_true(all(abs(as.numeric(fit$misc$gamma_trace) - as.numeric(fit$misc$al_fixed_gamma)) < 1e-12))
  }
})

test_that("AL exact chunking matches unchunked VB updates", {
  dat <- make_al_test_data(seed = 789L, n = 28L)
  prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 20)
  ctrl <- list(
    max_iter = 12L,
    min_iter_elbo = 5L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 40L,
    verbose = FALSE
  )

  fit_full <- exdqlm:::exal_fit(
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
  fit_chunked <- exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "al",
    al_fixed_gamma = 0,
    vb_control = modifyList(ctrl, list(chunking = list(enabled = TRUE, chunk_size = 7L))),
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )

  expect_identical(as.character(fit_chunked$likelihood_family), "al")
  expect_equal(fit_chunked$iter, fit_full$iter)
  expect_equal(fit_chunked$qbeta$m, fit_full$qbeta$m, tolerance = 1e-8)
  expect_equal(fit_chunked$qbeta$V, fit_full$qbeta$V, tolerance = 1e-8)
  expect_equal(fit_chunked$qv$m, fit_full$qv$m, tolerance = 1e-8)
  expect_equal(fit_chunked$qv$m_inv, fit_full$qv$m_inv, tolerance = 1e-8)
  expect_equal(fit_chunked$qs$m, fit_full$qs$m, tolerance = 1e-8)
  expect_equal(fit_chunked$qs$m2, fit_full$qs$m2, tolerance = 1e-8)
  expect_equal(fit_chunked$misc$sigma_trace, fit_full$misc$sigma_trace, tolerance = 1e-8)
  expect_equal(fit_chunked$misc$gamma_trace, fit_full$misc$gamma_trace, tolerance = 1e-12)
  expect_equal(fit_chunked$misc$elbo_trace, fit_full$misc$elbo_trace, tolerance = 1e-8)
})

test_that("AL exact chunking leaves RHS updates global", {
  dat <- make_al_test_data(seed = 790L, n = 24L)
  ctrl <- list(
    max_iter = 10L,
    min_iter_elbo = 4L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 32L,
    verbose = FALSE,
    rhs_freeze_tau_warmup_iters = 2L,
    rhs_update_every = 1L
  )

  fit_full <- exdqlm:::exal_fit(
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
    beta_prior_obj = make_rhs_ns_prior_for_tests()
  )
  fit_chunked <- exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "al",
    al_fixed_gamma = 0,
    vb_control = modifyList(ctrl, list(chunking = list(enabled = TRUE, chunk_size = 5L))),
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = make_rhs_ns_prior_for_tests()
  )

  expect_equal(fit_chunked$qbeta$m, fit_full$qbeta$m, tolerance = 1e-7)
  expect_equal(fit_chunked$beta_prior$state$tau2, fit_full$beta_prior$state$tau2, tolerance = 1e-7)
  expect_equal(fit_chunked$beta_prior$state$lambda2, fit_full$beta_prior$state$lambda2, tolerance = 1e-7)
  expect_equal(fit_chunked$misc$rhs_tau_trace, fit_full$misc$rhs_tau_trace, tolerance = 1e-7)
})

test_that("AL MCMC path keeps gamma fixed and respects parameter domains", {
  dat <- make_al_test_data(seed = 456L)
  priors <- list(
    ridge = exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 20),
    rhs_ns = make_rhs_ns_prior_for_tests()
  )

  for (nm in names(priors)) {
    fit <- exdqlm:::exal_fit(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      gamma_bounds = c(-3, 3),
      method = "mcmc",
      likelihood_family = "al",
      al_fixed_gamma = 0,
      mcmc_control = list(
        n_burn = 20L,
        n_mcmc = 30L,
        thin = 1L,
        verbose = FALSE,
        progress_every = 10L,
        init_from_vb = FALSE,
        slice = list(
          width_gamma = 0.5,
          width_sigma = 0.35,
          width_rhs_lambda = 0.4,
          width_rhs_tau = 0.3,
          width_rhs_c2 = 0.3,
          max_steps_out = 30L,
          max_shrink = 120L
        )
      ),
      prior_gamma = list(mu0 = 0, s20 = 10),
      prior_sigma = list(a = 1, b = 1),
      beta_prior_obj = priors[[nm]]
    )

    g <- as.numeric(fit$samp.gamma)
    s <- as.numeric(fit$samp.sigma)
    expect_identical(as.character(fit$likelihood_family), "al")
    expect_true(all(is.finite(g)))
    expect_true(all(is.finite(s)))
    expect_true(all(s > 0))
    expect_true(all(abs(g - as.numeric(fit$misc$al_fixed_gamma)) < 1e-12))
  }
})
