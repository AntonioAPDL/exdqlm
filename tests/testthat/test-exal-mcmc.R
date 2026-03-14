test_that("generic exAL draw and predictive dispatch works for VB and MCMC", {
  withr::local_seed(123)

  n <- 32L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  beta0 <- c(0.5, -0.7, 0.3)
  y <- as.numeric(X %*% beta0 + stats::rnorm(n, sd = 0.5))

  fit_vb <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "vb",
    max_iter = 5L,
    tol = 1e-3,
    tol_par = 1e-3,
    n_samp_xi = 30L,
    verbose = FALSE
  )
  expect_s3_class(fit_vb, "exal_vb")

  dr_vb <- exdqlm::exal_posterior_draws(fit_vb, nd = 8L)
  expect_equal(dim(dr_vb$beta), c(8L, ncol(X)))
  expect_length(dr_vb$sigma, 8L)
  expect_length(dr_vb$gamma, 8L)

  pp_vb <- exdqlm::exal_posterior_predict(fit_vb, X_new = X[1:5, , drop = FALSE], nd = 8L)
  expect_equal(dim(pp_vb$yrep), c(5L, 8L))
  expect_equal(dim(pp_vb$mu_draws), c(5L, 8L))

  fit_mcmc <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 20L,
      n_mcmc = 30L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = TRUE
    )
  )
  expect_true(inherits(fit_mcmc, "exal_mcmc"))

  dr_mcmc <- exdqlm::exal_posterior_draws(fit_mcmc, nd = 10L, seed = 1L)
  expect_equal(dim(dr_mcmc$beta), c(10L, ncol(X)))
  expect_length(dr_mcmc$sigma, 10L)
  expect_length(dr_mcmc$gamma, 10L)

  pp_mcmc <- exdqlm::exal_posterior_predict(
    fit_mcmc,
    X_new = X[1:6, , drop = FALSE],
    nd = 10L,
    seed = 1L
  )
  expect_equal(dim(pp_mcmc$yrep), c(6L, 10L))
  expect_equal(dim(pp_mcmc$mu_draws), c(6L, 10L))
})

test_that("Q-DESN MCMC path reuses the existing forecast interface", {
  withr::local_seed(321)

  y <- as.numeric(5 + sin(seq_len(48) / 5) + 0.15 * stats::rnorm(48))

  fit <- exdqlm::qdesn_fit(
    y = y,
    p0 = 0.5,
    method = "mcmc",
    D = 1L,
    n = 12L,
    m = 4L,
    alpha = 0.3,
    rho = 0.9,
    act_f = "tanh",
    act_k = "identity",
    pi_w = 0.2,
    pi_in = 1.0,
    washout = 4L,
    add_bias = TRUE,
    seed = 99L,
    mcmc_args = list(
      n_burn = 20L,
      n_mcmc = 30L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = TRUE
    )
  )

  expect_s3_class(fit, "qdesn_fit")
  expect_true(inherits(fit$fit, "exal_mcmc"))
  expect_equal(length(exdqlm::predict_mu.qdesn_fit(fit)), nrow(fit$X))

  pp <- exdqlm::posterior_predict.qdesn_fit(fit, nd = 12L)
  expect_equal(dim(pp$yrep), c(nrow(fit$X), 12L))

  fore <- exdqlm::forecast_paths.qdesn_fit(fit, H = 3L, nd = 12L, seed = 11L)
  expect_equal(dim(fore$yrep), c(3L, 12L))
  expect_equal(dim(fore$mu_draws), c(3L, 12L))
})
