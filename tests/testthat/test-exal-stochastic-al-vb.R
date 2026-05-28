`%||%` <- function(a, b) if (is.null(a)) b else a

make_stochastic_al_test_data <- function(seed = 20260527L, n = 80L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, x2 = x^2)
  beta <- c(0.2, 0.6, -0.3)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.08))
  list(X = X, y = y, beta = beta)
}

make_stochastic_al_control <- function(seed = 77L, max_iter = 80L) {
  list(
    max_iter = as.integer(max_iter),
    min_iter_elbo = 10L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 32L,
    verbose = FALSE,
    chunking = list(
      enabled = TRUE,
      mode = "stochastic",
      chunk_size = 16L,
      order = "random",
      seed = as.integer(seed),
      learning_rate = list(t0 = 10, kappa = 0.75, rho_min = 0.02),
      refresh = list(
        full_every = 20L,
        objective_every = 20L,
        sigma_every = 5L,
        rhs_every = 20L,
        local_every = 20L
      ),
      diagnostics = list(
        trace = TRUE,
        store_batch_ids = TRUE,
        check_finite_every = 1L
      )
    )
  )
}

fit_static_al_for_stochastic_tests <- function(dat, ctrl, prior = NULL, family = "al") {
  prior <- prior %||% exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 50)
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

test_that("stochastic AL VB fit is finite, reproducible, and labeled approximate", {
  dat <- make_stochastic_al_test_data()
  ctrl <- make_stochastic_al_control(seed = 77L, max_iter = 60L)

  fit1 <- fit_static_al_for_stochastic_tests(dat, ctrl)
  fit2 <- fit_static_al_for_stochastic_tests(dat, ctrl)

  expect_identical(as.character(fit1$likelihood_family), "al")
  expect_true(isTRUE(fit1$misc$stochastic))
  expect_identical(fit1$misc$chunking$mode, "stochastic")
  expect_match(fit1$misc$stochastic_objective_note, "approximate")
  expect_true(all(is.finite(fit1$qbeta$m)))
  expect_true(all(is.finite(fit1$qbeta$V)))
  expect_true(all(is.finite(fit1$qv$m)))
  expect_true(all(fit1$qv$m > 0))
  expect_true(all(is.finite(fit1$qv$m_inv)))
  expect_true(all(fit1$qv$m_inv > 0))
  expect_true(all(is.finite(fit1$qs$m)))
  expect_true(all(fit1$qs$m > 0))
  expect_true(all(is.finite(fit1$misc$sigma_trace)))
  expect_true(all(fit1$misc$sigma_trace > 0))
  expect_true(all(abs(as.numeric(fit1$misc$gamma_trace)) < 1e-12))

  expect_equal(fit1$qbeta$m, fit2$qbeta$m, tolerance = 1e-12)
  expect_equal(fit1$qbeta$V, fit2$qbeta$V, tolerance = 1e-12)
  expect_equal(fit1$misc$sigma_trace, fit2$misc$sigma_trace, tolerance = 1e-12)
  expect_equal(fit1$misc$stochastic_trace, fit2$misc$stochastic_trace, tolerance = 1e-12)
  expect_equal(fit1$misc$stochastic_batch_ids, fit2$misc$stochastic_batch_ids)
})

test_that("stochastic AL VB is broadly close to exact AL on easy data", {
  dat <- make_stochastic_al_test_data(seed = 20260528L)
  prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 50)
  exact_ctrl <- list(
    max_iter = 35L,
    min_iter_elbo = 10L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 32L,
    verbose = FALSE
  )
  stoch_ctrl <- make_stochastic_al_control(seed = 88L, max_iter = 80L)

  fit_exact <- fit_static_al_for_stochastic_tests(dat, exact_ctrl, prior = prior)
  fit_stoch <- fit_static_al_for_stochastic_tests(dat, stoch_ctrl, prior = prior)

  expect_true(max(abs(fit_exact$qbeta$m - fit_stoch$qbeta$m)) < 0.08)
  expect_true(max(abs(fit_stoch$qbeta$m - dat$beta)) < 0.12)
  expect_true(is.data.frame(fit_stoch$misc$stochastic_trace))
  expect_equal(nrow(fit_stoch$misc$stochastic_trace), fit_stoch$iter)
  expect_true(any(fit_stoch$misc$stochastic_trace$local_refresh))
  expect_true(any(fit_stoch$misc$stochastic_trace$sigma_refresh))
  expect_true(any(fit_stoch$misc$stochastic_trace$rhs_refresh))
})

test_that("stochastic AL VB keeps RHS updates global and finite", {
  dat <- make_stochastic_al_test_data(seed = 20260529L, n = 48L)
  prior <- exdqlm:::exal_make_beta_prior(
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
      init_log_tau = 0.0
    )
  )
  ctrl <- make_stochastic_al_control(seed = 89L, max_iter = 30L)
  ctrl$rhs_trace <- TRUE

  fit <- fit_static_al_for_stochastic_tests(dat, ctrl, prior = prior)

  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(all(is.finite(fit$beta_prior$state$tau2)))
  expect_true(all(fit$beta_prior$state$tau2 > 0))
  expect_true(all(is.finite(fit$beta_prior$state$lambda2)))
  expect_true(all(fit$beta_prior$state$lambda2 > 0))
  expect_true(is.data.frame(fit$misc$stochastic_trace))
  expect_true(any(fit$misc$stochastic_trace$rhs_refresh))
  expect_true(is.data.frame(fit$misc$rhs_trace))
})

test_that("stochastic mode is AL-only while exact exAL remains unchanged", {
  dat <- make_stochastic_al_test_data(seed = 20260530L, n = 36L)
  ctrl <- make_stochastic_al_control(seed = 90L, max_iter = 12L)

  expect_error(
    fit_static_al_for_stochastic_tests(dat, ctrl, family = "exal"),
    "supported only for likelihood_family = 'al'"
  )

  exact_ctrl <- list(
    max_iter = 8L,
    min_iter_elbo = 3L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    chunking = list(enabled = TRUE, mode = "exact", chunk_size = 9L)
  )
  fit_exal <- fit_static_al_for_stochastic_tests(dat, exact_ctrl, family = "exal")
  expect_identical(as.character(fit_exal$likelihood_family), "exal")
  expect_false(isTRUE(fit_exal$misc$stochastic))
})
