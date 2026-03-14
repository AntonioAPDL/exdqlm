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

test_that("RHS MCMC exposes healthy prior-state outputs and exact current precisions", {
  withr::local_seed(456)

  n <- 28L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.4, -0.5, 0.25) + stats::rnorm(n, sd = 0.4))

  rhs_prec0 <- 1e-10
  fit_rhs <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    beta_prior_obj = exdqlm::beta_prior("rhs", rhs = list(
      tau0 = 0.5,
      nu = 4,
      s2 = 1,
      shrink_intercept = FALSE,
      intercept_prec = rhs_prec0,
      eta_bounds = list(lambda = c(-4, 4), tau = c(-4, 4), c2 = c(-4, 4))
    )),
    mcmc_control = list(
      n_burn = 15L,
      n_mcmc = 20L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = TRUE,
      store_rhs_draws = TRUE
    )
  )

  expect_true(inherits(fit_rhs, "exal_mcmc"))
  expect_identical(fit_rhs$beta_prior$type, "rhs")
  expect_false(is.null(fit_rhs$samp.tau))
  expect_false(is.null(fit_rhs$samp.c2))
  expect_false(is.null(fit_rhs$samp.lambda))
  expect_true(is.finite(fit_rhs$summary$rhs$tau_mean))
  expect_true(fit_rhs$summary$rhs$tau_mean > 0)
  expect_true(is.finite(fit_rhs$summary$rhs$c2_mean))
  expect_true(fit_rhs$summary$rhs$c2_mean > 0)
  expect_equal(fit_rhs$last$beta_prec_diag[1L], rhs_prec0)
})

test_that("inference config resolver supports explicit mcmc mode with backward-compatible structure", {
  cfg <- list(
    vb = list(
      max_iter = 99L,
      online = list(enabled = TRUE, M = 5L)
    ),
    inference = list(
      method = "mcmc",
      readout_scale = TRUE,
      mcmc = list(
        n_burn = 11L,
        n_mcmc = 17L,
        thin = 2L,
        init_from_vb = FALSE,
        slice = list(width_gamma = 0.6, width_rhs_tau = 0.9),
        init = list(gamma = c(0.1, 0.2)),
        priors = list(
          gamma = list(mu0 = c(-0.2, 0.3), s20 = 4),
          sigma = list(a = 2, b = 3),
          beta = list(
            type = "rhs",
            rhs = list(tau0 = 0.4, s2 = 2, shrink_intercept = FALSE)
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = c(0.1, 0.9), verbose = FALSE)
  expect_identical(inf$method, "mcmc")
  expect_true(inf$readout_scale)
  expect_equal(inf$mcmc$control_base$n_burn, 11L)
  expect_equal(inf$mcmc$control_base$n_mcmc, 17L)
  expect_equal(inf$mcmc$control_base$thin, 2L)
  expect_false(isTRUE(inf$mcmc$control_base$init_from_vb))
  expect_equal(inf$mcmc$control_base$slice$width_gamma, 0.6)
  expect_equal(inf$mcmc$control_base$slice$width_rhs_tau, 0.9)
  expect_identical(inf$beta_prior_type, "rhs")
  expect_equal(inf$prior_gamma_mu0, c(-0.2, 0.3))
  expect_equal(inf$prior_gamma_s20, c(4, 4))
  expect_equal(inf$prior_sigma_a, c(2, 2))
  expect_equal(inf$prior_sigma_b, c(3, 3))

  qspec <- exdqlm:::resolve_exal_quantile_fit_spec(inf, idx_p = 2L, p0 = 0.9)
  expect_identical(qspec$method, "mcmc")
  expect_identical(qspec$beta_type, "rhs")
  expect_identical(qspec$beta_prior_obj$type, "rhs")
  expect_equal(qspec$init$gamma, 0.2)
  expect_equal(qspec$prior_sigma$a, 2)
  expect_equal(qspec$prior_sigma$b, 3)
})

test_that("VB RHS config preserves null tau init and separate warmup freeze settings", {
  cfg <- list(
    inference = list(
      method = "vb",
      readout_scale = TRUE,
      vb = list(
        max_iter = 20L,
        rhs = list(
          freeze_tau_iters = 5L,
          freeze_tau_warmup_iters = 9L
        ),
        priors = list(
          beta = list(
            type = "rhs",
            rhs = list(
              tau0 = 0.01,
              nu = 4,
              s2 = 0.5,
              shrink_intercept = FALSE,
              intercept_prec = 1e-10,
              init_log_tau = NULL,
              init_log_c2 = 0.0
            )
          )
        )
      )
    )
  )

  inf <- exdqlm:::resolve_exal_inference_config(cfg, p_vec = 0.25, verbose = FALSE)
  expect_identical(inf$method, "vb")
  expect_equal(inf$vb$args_base$rhs_freeze_tau_iters, 5L)
  expect_equal(inf$vb$args_base$rhs_freeze_tau_warmup_iters, 9L)

  qspec <- exdqlm:::resolve_exal_quantile_fit_spec(inf, idx_p = 1L, p0 = 0.25)
  state0 <- qspec$beta_prior_obj$init(3L)

  expect_identical(qspec$beta_type, "rhs")
  expect_equal(exp(state0$eta_tau_hat), 0.01, tolerance = 1e-12)
})

test_that("VB RHS stays numerically healthy on a centered lower-tail toy regression", {
  withr::local_seed(1)

  n <- 48L
  x1 <- scale(sin(seq_len(n) / 6))[, 1L]
  X <- cbind(1, x1)
  y <- as.numeric(0.4 * x1 + stats::rnorm(n, sd = 0.1))

  fit_rhs_vb <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.25,
    gamma_bounds = exdqlm::get_gamma_bounds(0.25),
    method = "vb",
    max_iter = 12L,
    min_iter_elbo = 4L,
    tol = 1e-4,
    tol_par = 1e-4,
    n_samp_xi = 30L,
    verbose = FALSE,
    beta_prior_obj = exdqlm::beta_prior("rhs", rhs = list(
      tau0 = 0.01,
      nu = 4,
      s2 = 0.5,
      shrink_intercept = FALSE,
      intercept_prec = 1e-10,
      init_log_tau = NULL,
      eta_bounds = list(lambda = c(-8, 8), tau = c(-8, 8), c2 = c(-8, 8)),
      h_curv = 1e-8,
      var_floor = 1e-8
    ))
  )

  expect_s3_class(fit_rhs_vb, "exal_vb")
  expect_true(all(is.finite(fit_rhs_vb$qbeta$m)))
  expect_lt(sqrt(sum(fit_rhs_vb$qbeta$m^2)), 10)
  expect_equal(fit_rhs_vb$misc$rhs_tau_trace[[1L]], 0.01, tolerance = 1e-3)
  expect_gt(fit_rhs_vb$qsiggam$gamma_mean, exdqlm::get_gamma_bounds(0.25)[1L] + 0.01)
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
