`%||%` <- function(a, b) if (is.null(a)) b else a

make_hybrid_al_test_data <- function(seed = 20260528L, n = 72L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, x2 = x^2)
  beta <- c(0.15, 0.55, -0.25)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.06))
  list(X = X, y = y, beta = beta)
}

make_hybrid_al_control <- function(seed = 20260528L,
                                   max_iter = 30L,
                                   full_every = 5L,
                                   chunk_size = 12L) {
  list(
    max_iter = as.integer(max_iter),
    min_iter_elbo = 5L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 32L,
    verbose = FALSE,
    chunking = list(
      enabled = TRUE,
      mode = "hybrid",
      chunk_size = as.integer(chunk_size),
      order = "random",
      seed = as.integer(seed),
      learning_rate = list(t0 = 10, kappa = 0.75, rho_min = 0.02),
      refresh = list(
        full_every = as.integer(full_every),
        objective_every = as.integer(full_every),
        sigma_every = as.integer(full_every),
        rhs_every = as.integer(full_every),
        local_every = as.integer(full_every)
      ),
      diagnostics = list(
        trace = TRUE,
        store_batch_ids = TRUE,
        check_finite_every = 1L
      )
    )
  )
}

fit_static_hybrid_al_test <- function(dat, ctrl, prior = NULL, family = "al") {
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

test_that("hybrid AL full refresh every iteration recovers exact AL", {
  dat <- make_hybrid_al_test_data()
  prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 50)
  exact_ctrl <- list(
    max_iter = 18L,
    min_iter_elbo = 5L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 32L,
    verbose = FALSE
  )
  hybrid_ctrl <- make_hybrid_al_control(
    seed = 20260528L,
    max_iter = exact_ctrl$max_iter,
    full_every = 1L,
    chunk_size = 13L
  )

  fit_exact <- fit_static_hybrid_al_test(dat, exact_ctrl, prior = prior)
  fit_hybrid <- fit_static_hybrid_al_test(dat, hybrid_ctrl, prior = prior)

  expect_true(isTRUE(fit_hybrid$misc$hybrid))
  expect_true(isTRUE(fit_hybrid$misc$approximate_chunking))
  expect_identical(fit_hybrid$misc$chunking$mode, "hybrid")
  expect_true(all(fit_hybrid$misc$stochastic_trace$full_refresh))
  expect_equal(fit_hybrid$qbeta$m, fit_exact$qbeta$m, tolerance = 1e-8)
  expect_equal(fit_hybrid$qbeta$V, fit_exact$qbeta$V, tolerance = 1e-8)
  expect_equal(fit_hybrid$qv$m, fit_exact$qv$m, tolerance = 1e-8)
  expect_equal(fit_hybrid$qs$m, fit_exact$qs$m, tolerance = 1e-8)
  expect_equal(fit_hybrid$misc$sigma_trace, fit_exact$misc$sigma_trace, tolerance = 1e-8)
  expect_equal(fit_hybrid$misc$elbo_trace, fit_exact$misc$elbo_trace, tolerance = 1e-8)
})

test_that("hybrid AL is finite and reproducible between full refreshes", {
  dat <- make_hybrid_al_test_data(seed = 20260529L)
  ctrl <- make_hybrid_al_control(seed = 11L, max_iter = 32L, full_every = 8L, chunk_size = 10L)

  fit1 <- fit_static_hybrid_al_test(dat, ctrl)
  fit2 <- fit_static_hybrid_al_test(dat, ctrl)

  expect_true(isTRUE(fit1$misc$hybrid))
  expect_match(fit1$misc$stochastic_objective_note, "approximate")
  expect_true(all(is.finite(fit1$qbeta$m)))
  expect_true(all(is.finite(fit1$qbeta$V)))
  expect_true(all(is.finite(fit1$qv$m)))
  expect_true(all(fit1$qv$m > 0))
  expect_true(all(is.finite(fit1$qs$m)))
  expect_true(all(fit1$qs$m > 0))
  expect_true(all(is.finite(fit1$misc$sigma_trace)))
  expect_true(any(fit1$misc$stochastic_trace$full_refresh))
  expect_true(any(!fit1$misc$stochastic_trace$full_refresh))
  expect_equal(fit1$qbeta$m, fit2$qbeta$m, tolerance = 1e-12)
  expect_equal(fit1$qbeta$V, fit2$qbeta$V, tolerance = 1e-12)
  expect_equal(fit1$misc$stochastic_trace, fit2$misc$stochastic_trace, tolerance = 1e-12)
  expect_equal(fit1$misc$stochastic_batch_ids, fit2$misc$stochastic_batch_ids)
})

test_that("hybrid AL keeps RHS_NS global state finite", {
  dat <- make_hybrid_al_test_data(seed = 20260530L, n = 54L)
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
  ctrl <- make_hybrid_al_control(seed = 12L, max_iter = 22L, full_every = 5L, chunk_size = 9L)
  ctrl$rhs_trace <- TRUE

  fit <- fit_static_hybrid_al_test(dat, ctrl, prior = prior)

  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(all(is.finite(fit$beta_prior$state$tau2)))
  expect_true(all(fit$beta_prior$state$tau2 > 0))
  expect_true(all(is.finite(fit$beta_prior$state$lambda2)))
  expect_true(all(fit$beta_prior$state$lambda2 > 0))
  expect_true(is.data.frame(fit$misc$rhs_trace))
  expect_true(any(fit$misc$stochastic_trace$rhs_refresh))
})

test_that("hybrid approximate chunking is AL-only", {
  dat <- make_hybrid_al_test_data(seed = 20260531L, n = 36L)
  ctrl <- make_hybrid_al_control(seed = 13L, max_iter = 8L, full_every = 2L, chunk_size = 8L)

  expect_error(
    fit_static_hybrid_al_test(dat, ctrl, family = "exal"),
    "supported only for likelihood_family = 'al'"
  )
})
