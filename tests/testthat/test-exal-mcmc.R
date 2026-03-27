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

test_that("MCMC supports log-sigma slice sampling when enabled", {
  withr::local_seed(321)

  n <- 24L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  beta0 <- c(0.25, -0.4, 0.15)
  y <- as.numeric(X %*% beta0 + stats::rnorm(n, sd = 0.6))

  fit_mcmc <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 10L,
      n_mcmc = 15L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = TRUE,
      transforms = list(
        use_log_sigma = TRUE,
        sigma_eta_bounds = c(-8, 8)
      ),
      slice = list(
        width_sigma = 0.4
      )
    )
  )

  expect_true(inherits(fit_mcmc, "exal_mcmc"))
  expect_true(all(is.finite(fit_mcmc$samp.sigma)))
  expect_true(all(fit_mcmc$samp.sigma > 0))
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

test_that("RHS_NS VB path runs and contributes finite ELBO traces", {
  withr::local_seed(457)

  n <- 26L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.3, -0.45, 0.2) + stats::rnorm(n, sd = 0.45))

  fit_ns <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "vb",
    beta_prior_obj = exdqlm::beta_prior("rhs_ns", rhs = list(
      tau0 = 0.35,
      a_zeta = 2.5,
      b_zeta = 1.5,
      s2 = 0.8,
      shrink_intercept = FALSE,
      intercept_prec = 1e-10,
      n_inner = 2L
    )),
    max_iter = 12L,
    tol = 1e-3,
    tol_par = 1e-3,
    n_samp_xi = 50L,
    verbose = FALSE
  )

  expect_true(inherits(fit_ns, "exal_vb"))
  expect_identical(fit_ns$beta_prior$type, "rhs_ns")
  expect_true(all(is.finite(fit_ns$qbeta$m)))
  expect_true(all(is.finite(fit_ns$misc$elbo_trace)))
})

test_that("RHS_NS MCMC exposes prior-state outputs and finite precisions", {
  withr::local_seed(458)

  n <- 24L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.35, -0.4, 0.2) + stats::rnorm(n, sd = 0.4))

  rhs_prec0 <- 1e-10
  fit_rhs_ns <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    beta_prior_obj = exdqlm::beta_prior("rhs_ns", rhs = list(
      tau0 = 0.35,
      a_zeta = 2.5,
      b_zeta = 1.5,
      s2 = 0.8,
      shrink_intercept = FALSE,
      intercept_prec = rhs_prec0
    )),
    mcmc_control = list(
      n_burn = 12L,
      n_mcmc = 16L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = TRUE,
      store_rhs_draws = TRUE
    )
  )

  expect_true(inherits(fit_rhs_ns, "exal_mcmc"))
  expect_identical(fit_rhs_ns$beta_prior$type, "rhs_ns")
  expect_false(is.null(fit_rhs_ns$samp.tau))
  expect_false(is.null(fit_rhs_ns$samp.c2))
  expect_false(is.null(fit_rhs_ns$samp.lambda))
  expect_true(all(is.finite(as.numeric(fit_rhs_ns$samp.tau))))
  expect_true(all(as.numeric(fit_rhs_ns$samp.tau) > 0))
  expect_true(all(is.finite(as.numeric(fit_rhs_ns$samp.c2))))
  expect_true(all(as.numeric(fit_rhs_ns$samp.c2) > 0))
  expect_equal(fit_rhs_ns$last$beta_prec_diag[1L], rhs_prec0)
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
        vb_warm_start_seed = 12345L,
        vb_warm_start_control = list(max_iter = 33L),
        rhs = list(
          freeze_tau_burnin_iters = 7L,
          width_adapt = list(
            enabled = TRUE,
            warmup_iters = 12L,
            target_score_low = -1.0,
            target_score_high = 1.0
          )
        ),
        slice = list(
          width_gamma = 0.6,
          width_rhs_tau = 0.9,
          rhs_global_block_update = "transformed_tau_c2_block",
          core_extra_passes = 2L,
          width_rhs_tau_c2_transformed_z1 = 0.5,
          width_rhs_tau_c2_transformed_z2 = 0.4
        ),
        multi_start = list(
          enabled = TRUE,
          n_starts = 3L,
          pilot_n_burn = 40L,
          pilot_n_mcmc = 60L
        ),
        transforms = list(use_log_sigma = TRUE, sigma_eta_bounds = c(-6, 6)),
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
  expect_equal(inf$mcmc$control_base$vb_warm_start_seed, 12345L)
  expect_true(isTRUE(inf$mcmc$control_base$transforms$use_log_sigma))
  expect_equal(inf$mcmc$control_base$transforms$sigma_eta_bounds, c(-6, 6))
  expect_false(isTRUE(inf$mcmc$control_base$init_from_vb))
  expect_equal(inf$mcmc$control_base$vb_warm_start_control$max_iter, 33L)
  expect_equal(inf$mcmc$control_base$rhs$freeze_tau_burnin_iters, 7L)
  expect_true(isTRUE(inf$mcmc$control_base$rhs$width_adapt$enabled))
  expect_equal(inf$mcmc$control_base$rhs$width_adapt$warmup_iters, 12L)
  expect_equal(inf$mcmc$control_base$slice$width_gamma, 0.6)
  expect_equal(inf$mcmc$control_base$slice$width_rhs_tau, 0.9)
  expect_identical(inf$mcmc$control_base$slice$rhs_global_block_update, "transformed_tau_c2_block")
  expect_equal(inf$mcmc$control_base$slice$core_extra_passes, 2L)
  expect_equal(inf$mcmc$control_base$slice$width_rhs_tau_c2_transformed_z1, 0.5)
  expect_equal(inf$mcmc$control_base$slice$width_rhs_tau_c2_transformed_z2, 0.4)
  expect_true(isTRUE(inf$mcmc$control_base$multi_start$enabled))
  expect_equal(inf$mcmc$control_base$multi_start$n_starts, 3L)
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

test_that("RHS MCMC can freeze tau during burn-in warmup", {
  withr::local_seed(789)

  n <- 20L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.3, -0.4, 0.2) + stats::rnorm(n, sd = 0.35))
  beta_prior_obj <- exdqlm::beta_prior("rhs", rhs = list(
    tau0 = 0.3,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE,
    intercept_prec = 1e-10,
    eta_bounds = list(lambda = c(-4, 4), tau = c(-4, 4), c2 = c(-4, 4))
  ))

  fit_rhs <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    beta_prior_obj = beta_prior_obj,
    mcmc_control = list(
      n_burn = 6L,
      n_mcmc = 8L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      rhs = list(
        freeze_tau_burnin_iters = 4L,
        freeze_tau_only_during_burn = TRUE
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n),
      rhs_state = beta_prior_obj$init(ncol(X))
    )
  )

  expect_true(inherits(fit_rhs, "exal_mcmc"))
  expect_equal(fit_rhs$control$rhs$freeze_tau_burnin_iters, 4L)
  expect_true(all(fit_rhs$misc$rhs_tau_frozen_trace[1:4]))
  expect_true(!any(fit_rhs$misc$rhs_tau_frozen_trace[7:length(fit_rhs$misc$rhs_tau_frozen_trace)]))
  expect_equal(length(unique(round(fit_rhs$misc$rhs_tau_trace[1:4], 12L))), 1L)
})

test_that("RHS MCMC supports joint directional tau/c2 block updates", {
  withr::local_seed(790)

  n <- 20L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.35, -0.25, 0.15) + stats::rnorm(n, sd = 0.3))
  beta_prior_obj <- exdqlm::beta_prior("rhs", rhs = list(
    tau0 = 0.3,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE,
    intercept_prec = 1e-10,
    eta_bounds = list(lambda = c(-4, 4), tau = c(-4, 4), c2 = c(-4, 4))
  ))

  fit_rhs <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    beta_prior_obj = beta_prior_obj,
    mcmc_control = list(
      n_burn = 4L,
      n_mcmc = 6L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      rhs = list(
        freeze_tau_burnin_iters = 0L,
        freeze_tau_only_during_burn = TRUE
      ),
      slice = list(
        rhs_global_block_update = "directional_tau_c2",
        width_rhs_tau_c2_block = 1.0,
        width_rhs_lambda = 0.3,
        width_rhs_tau = 0.2,
        width_rhs_c2 = 0.2,
        max_steps_out = 20L,
        max_shrink = 80L
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n),
      rhs_state = beta_prior_obj$init(ncol(X))
    )
  )

  expect_true(inherits(fit_rhs, "exal_mcmc"))
  expect_identical(fit_rhs$control$slice$rhs_global_block_update, "directional_tau_c2")
  expect_equal(fit_rhs$control$slice$width_rhs_tau_c2_block, 1.0)
  expect_identical(fit_rhs$diagnostics$rhs$global_block_update_mode, "directional_tau_c2")
  expect_true(all(fit_rhs$misc$rhs_global_block_used_trace))
  expect_true(any(abs(fit_rhs$misc$rhs_global_block_dir_tau) > 0))
  expect_true(any(abs(fit_rhs$misc$rhs_global_block_dir_c2) > 0))
})

test_that("RHS MCMC supports transformed tau/c2 block updates with warmup width adaptation", {
  withr::local_seed(791)

  n <- 18L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.3, -0.2, 0.1) + stats::rnorm(n, sd = 0.28))
  beta_prior_obj <- exdqlm::beta_prior("rhs", rhs = list(
    tau0 = 0.3,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE,
    intercept_prec = 1e-10,
    eta_bounds = list(lambda = c(-4, 4), tau = c(-4, 4), c2 = c(-4, 4))
  ))

  fit_rhs <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    beta_prior_obj = beta_prior_obj,
    mcmc_control = list(
      n_burn = 8L,
      n_mcmc = 10L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      rhs = list(
        freeze_tau_burnin_iters = 0L,
        width_adapt = list(
          enabled = TRUE,
          warmup_iters = 4L,
          only_during_burn = TRUE,
          target_score_low = -1.0,
          target_score_high = 1.0,
          step_size = 0.08,
          width_min = 0.05,
          width_max = 1.5
        )
      ),
      slice = list(
        rhs_global_block_update = "transformed_tau_c2_block",
        rhs_transformed_block_passes = 2L,
        width_rhs_lambda = 0.3,
        width_rhs_tau = 0.2,
        width_rhs_c2 = 0.2,
        width_rhs_tau_c2_block = 0.3,
        width_rhs_tau_c2_transformed_z1 = 0.35,
        width_rhs_tau_c2_transformed_z2 = 0.25,
        max_steps_out = 20L,
        max_shrink = 80L
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n),
      rhs_state = beta_prior_obj$init(ncol(X))
    )
  )

  expect_true(inherits(fit_rhs, "exal_mcmc"))
  expect_identical(fit_rhs$control$slice$rhs_global_block_update, "transformed_tau_c2_block")
  expect_equal(fit_rhs$control$slice$rhs_transformed_block_passes, 2L)
  expect_true(any(fit_rhs$misc$rhs_width_adapt_active_trace[1:4]))
  expect_true(all(!fit_rhs$misc$rhs_width_adapt_active_trace[9:length(fit_rhs$misc$rhs_width_adapt_active_trace)]))
  expect_true(all(fit_rhs$misc$rhs_width_tau_trace >= 0.05 & fit_rhs$misc$rhs_width_tau_trace <= 1.5))
  expect_true(is.finite(fit_rhs$diagnostics$rhs$width_rhs_tau_final))
  expect_true(is.finite(fit_rhs$diagnostics$rhs$transformed_z1_steps_out_mean))
})

test_that("MCMC supports core extra sigma/gamma passes and records control metadata", {
  withr::local_seed(793)

  n <- 20L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.3, -0.22, 0.08) + stats::rnorm(n, sd = 0.3))

  fit <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 6L,
      n_mcmc = 8L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      slice = list(
        width_gamma = 0.6,
        core_extra_passes = 1L,
        max_steps_out = 20L,
        max_shrink = 80L
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n)
    )
  )

  expect_s3_class(fit, "exal_mcmc")
  expect_equal(fit$control$slice$core_extra_passes, 1L)
  expect_equal(fit$diagnostics$core_sigma_gamma_passes_per_iter, 2L)
  expect_true(all(is.finite(as.numeric(fit$samp.gamma))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
})

test_that("RHS MCMC multi-start pilot selection stores diagnostics and selected start", {
  withr::local_seed(792)

  n <- 16L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.25, -0.18, 0.12) + stats::rnorm(n, sd = 0.25))
  beta_prior_obj <- exdqlm::beta_prior("rhs", rhs = list(
    tau0 = 0.2,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE,
    intercept_prec = 1e-10,
    eta_bounds = list(lambda = c(-4, 4), tau = c(-4, 4), c2 = c(-4, 4))
  ))

  fit_rhs <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    beta_prior_obj = beta_prior_obj,
    mcmc_control = list(
      n_burn = 6L,
      n_mcmc = 8L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      multi_start = list(
        enabled = TRUE,
        n_starts = 2L,
        pilot_n_burn = 3L,
        pilot_n_mcmc = 5L,
        perturb_sd_log_tau = 0.2,
        perturb_sd_log_c2 = 0.2,
        perturb_sd_log_lambda = 0.1,
        perturb_sd_beta = 0.03
      )
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n),
      rhs_state = beta_prior_obj$init(ncol(X))
    )
  )

  expect_true(inherits(fit_rhs, "exal_mcmc"))
  expect_true(is.list(fit_rhs$control$multi_start))
  expect_true(isTRUE(fit_rhs$control$multi_start$enabled))
  expect_true("selected_start_id" %in% names(fit_rhs$control$multi_start))
  expect_true(is.data.frame(fit_rhs$misc$multi_start_pilot_summary))
  expect_equal(nrow(fit_rhs$misc$multi_start_pilot_summary), 2L)
})

test_that("MCMC sampler rng_seed is accepted and stored on the fit", {
  withr::local_seed(2026)

  n <- 24L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.25, -0.35, 0.15) + stats::rnorm(n, sd = 0.3))

  fit_a <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 12L,
      n_mcmc = 16L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      seed = 11L
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n)
    )
  )

  fit_c <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = list(
      n_burn = 12L,
      n_mcmc = 16L,
      thin = 1L,
      verbose = FALSE,
      init_from_vb = FALSE,
      seed = 12L
    ),
    init = list(
      beta = rep(0, ncol(X)),
      sigma = 1,
      gamma = 0.5,
      v = rep(1, n),
      s = rep(0.1, n)
    )
  )

  expect_equal(fit_a$control$rng_seed, 11L)
  expect_equal(fit_c$control$rng_seed, 12L)
  expect_length(as.numeric(fit_a$samp.gamma), 16L)
  expect_length(as.numeric(fit_c$samp.gamma), 16L)
})

test_that("MCMC accepts and stores vb warm-start seed under init_from_vb", {
  withr::local_seed(2027)

  n <- 22L
  X <- cbind(1, stats::rnorm(n), stats::rnorm(n))
  y <- as.numeric(X %*% c(0.2, -0.3, 0.1) + stats::rnorm(n, sd = 0.35))

  control_cfg <- list(
    n_burn = 12L,
    n_mcmc = 16L,
    thin = 1L,
    verbose = FALSE,
    init_from_vb = TRUE,
    rng_seed = 777L,
    vb_warm_start_seed = 1777L,
    vb_warm_start_control = list(
      max_iter = 20L,
      min_iter_elbo = 5L,
      n_samp_xi = 40L,
      verbose = FALSE
    )
  )

  fit_a <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = control_cfg
  )
  fit_b <- exdqlm::exal_fit(
    y = y,
    X = X,
    p0 = 0.5,
    gamma_bounds = c(exdqlm::get_gamma_bounds(0.5)),
    method = "mcmc",
    mcmc_control = control_cfg
  )

  expect_equal(fit_a$control$rng_seed, 777L)
  expect_equal(fit_a$control$vb_warm_start_seed, 1777L)
  expect_equal(fit_b$control$rng_seed, 777L)
  expect_equal(fit_b$control$vb_warm_start_seed, 1777L)
  expect_length(as.numeric(fit_a$samp.gamma), 16L)
  expect_length(as.numeric(fit_b$samp.gamma), 16L)
  expect_true(all(is.finite(as.numeric(fit_a$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit_b$samp.sigma))))
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
  expect_equal(exp(state0$eta_tau_hat), 1.0, tolerance = 1e-12)
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
