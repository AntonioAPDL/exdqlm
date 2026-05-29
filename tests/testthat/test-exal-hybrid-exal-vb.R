`%||%` <- function(a, b) if (is.null(a)) b else a

make_hybrid_exal_test_data <- function(seed = 20260670L, n = 64L) {
  set.seed(as.integer(seed))
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, x2 = x^2)
  beta <- c(0.1, 0.4, -0.18)
  y <- as.numeric(X %*% beta + stats::rnorm(n, sd = 0.05))
  list(X = X, y = y)
}

make_hybrid_exal_control <- function(seed = 20260671L,
                                     max_iter = 18L,
                                     full_every = 4L,
                                     chunk_size = 12L) {
  list(
    max_iter = as.integer(max_iter),
    min_iter_elbo = 4L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 24L,
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
      diagnostics = list(trace = TRUE, store_batch_ids = TRUE, check_finite_every = 1L)
    )
  )
}

fit_static_hybrid_exal_test <- function(dat, ctrl, prior = NULL) {
  prior <- prior %||% exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 40)
  exdqlm:::exal_fit(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    gamma_bounds = c(-3, 3),
    method = "vb",
    likelihood_family = "exal",
    vb_control = ctrl,
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior
  )
}

test_that("hybrid exAL full refresh every iteration recovers exact exAL ridge", {
  dat <- make_hybrid_exal_test_data()
  prior <- exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 40)
  exact_ctrl <- list(
    max_iter = 14L,
    min_iter_elbo = 4L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 24L,
    verbose = FALSE
  )
  hybrid_ctrl <- make_hybrid_exal_control(
    seed = 20260672L,
    max_iter = exact_ctrl$max_iter,
    full_every = 1L,
    chunk_size = 11L
  )

  fit_exact <- fit_static_hybrid_exal_test(dat, exact_ctrl, prior = prior)
  fit_hybrid <- fit_static_hybrid_exal_test(dat, hybrid_ctrl, prior = prior)

  expect_true(isTRUE(fit_hybrid$misc$hybrid))
  expect_true(isTRUE(fit_hybrid$misc$approximate_chunking))
  expect_identical(fit_hybrid$misc$chunking$mode, "hybrid")
  expect_true(all(fit_hybrid$misc$stochastic_trace$full_refresh))
  expect_lt(max(abs(fit_hybrid$qbeta$m - fit_exact$qbeta$m)), 1e-6)
  expect_lt(max(abs(fit_hybrid$qbeta$V - fit_exact$qbeta$V)), 1e-6)
  expect_lt(max(abs(fit_hybrid$qv$m - fit_exact$qv$m)), 1e-6)
  expect_lt(max(abs(fit_hybrid$qs$m - fit_exact$qs$m)), 1e-6)
  expect_lt(max(abs(fit_hybrid$misc$sigma_trace - fit_exact$misc$sigma_trace)), 1e-6)
  expect_lt(max(abs(fit_hybrid$misc$gamma_trace - fit_exact$misc$gamma_trace)), 2e-6)
  expect_lt(max(abs(fit_hybrid$misc$elbo_trace - fit_exact$misc$elbo_trace)), 1e-6)
})

test_that("hybrid exAL ridge is finite and reproducible between refreshes", {
  dat <- make_hybrid_exal_test_data(seed = 20260673L)
  ctrl <- make_hybrid_exal_control(seed = 20260674L, max_iter = 20L, full_every = 5L, chunk_size = 10L)

  fit1 <- fit_static_hybrid_exal_test(dat, ctrl)
  fit2 <- fit_static_hybrid_exal_test(dat, ctrl)

  expect_true(isTRUE(fit1$misc$hybrid))
  expect_match(fit1$misc$stochastic_objective_note, "hybrid updates are approximate")
  expect_true(any(fit1$misc$stochastic_trace$full_refresh))
  expect_true(any(!fit1$misc$stochastic_trace$full_refresh))
  expect_true(all(is.finite(fit1$qbeta$m)))
  expect_true(all(is.finite(fit1$qbeta$V)))
  expect_true(all(is.finite(fit1$qv$m)))
  expect_true(all(fit1$qv$m > 0))
  expect_true(all(is.finite(fit1$qs$m)))
  expect_true(all(fit1$qs$m > 0))
  expect_true(all(is.finite(fit1$misc$sigma_trace)))
  expect_true(all(is.finite(fit1$misc$gamma_trace)))
  expect_true(all(fit1$misc$gamma_trace > -3 & fit1$misc$gamma_trace < 3))
  expect_true(all(is.finite(unlist(fit1$qsiggam$xi))))
  expect_equal(fit1$qbeta$m, fit2$qbeta$m, tolerance = 1e-12)
  expect_equal(fit1$qbeta$V, fit2$qbeta$V, tolerance = 1e-12)
  expect_equal(fit1$misc$stochastic_trace, fit2$misc$stochastic_trace, tolerance = 1e-12)
  expect_equal(fit1$misc$stochastic_batch_ids, fit2$misc$stochastic_batch_ids)
})

test_that("unsupported exAL approximate combinations fail early", {
  dat <- make_hybrid_exal_test_data(seed = 20260675L, n = 40L)
  ctrl <- make_hybrid_exal_control(seed = 20260676L, max_iter = 8L, full_every = 2L, chunk_size = 8L)
  stoch_ctrl <- ctrl
  stoch_ctrl$chunking$mode <- "stochastic"

  expect_error(
    fit_static_hybrid_exal_test(dat, stoch_ctrl),
    "stochastic exAL VB chunking is not implemented"
  )

  rhs_prior <- exdqlm:::exal_make_beta_prior(
    type = "rhs_ns",
    rhs = list(tau0 = 0.5, s2 = 1, shrink_intercept = FALSE, n_inner = 1L)
  )
  expect_error(
    fit_static_hybrid_exal_test(dat, ctrl, prior = rhs_prior),
    "hybrid exAL VB chunking is currently supported only for ridge beta priors"
  )
})
