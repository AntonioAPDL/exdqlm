test_that("qdesn_fit_mcmc accepts precision-beta presets and forwards normalized control", {
  y <- c(1, 2, 3, 4)
  X <- cbind(1, c(0.1, 0.2, 0.3, 0.4))
  captured_control <- NULL

  testthat::local_mocked_bindings(
    qdesn_fit_vb = function(..., fit_readout = FALSE, vb_args = list()) {
      list(
        y_fit = y,
        X = X,
        meta = list(p0 = 0.5)
      )
    },
    exal_mcmc_fit = function(y, X, p0, gamma_bounds, mcmc_control = NULL, ...) {
      captured_control <<- mcmc_control
      list(summary = list(beta_mean = rep(0, ncol(X))))
    },
    .package = "exdqlm"
  )

  fit <- exdqlm::qdesn_fit_mcmc(
    mcmc_args = list(
      likelihood_family = "al",
      gamma_bounds = c(-2, 2),
      precision_beta = "ladder_v2"
    )
  )

  expect_true(is.list(fit$fit))
  expect_identical(as.character(captured_control$precision_beta$preset), "ladder_v2")
  expect_true(isTRUE(captured_control$precision_beta$enabled))
  expect_equal(max(as.numeric(captured_control$precision_beta$jitter_ladder)), 1e-2, tolerance = 1e-12)
  expect_false(isTRUE(captured_control$precision_beta$eigen_fallback))
})

test_that("qdesn_fit_mcmc preserves explicit precision-beta control overrides", {
  y <- c(1, 2, 3, 4)
  X <- cbind(1, c(0.1, 0.2, 0.3, 0.4))
  captured_control <- NULL

  testthat::local_mocked_bindings(
    qdesn_fit_vb = function(..., fit_readout = FALSE, vb_args = list()) {
      list(
        y_fit = y,
        X = X,
        meta = list(p0 = 0.5)
      )
    },
    exal_mcmc_fit = function(y, X, p0, gamma_bounds, mcmc_control = NULL, ...) {
      captured_control <<- mcmc_control
      list(summary = list(beta_mean = rep(0, ncol(X))))
    },
    .package = "exdqlm"
  )

  fit <- exdqlm::qdesn_fit_mcmc(
    mcmc_args = list(
      likelihood_family = "exal",
      gamma_bounds = c(-2, 2),
      precision_beta = list(
        preset = "eigen_v1",
        eigen_floor_abs = 1e-5,
        trace = FALSE
      )
    )
  )

  expect_true(is.list(fit$fit))
  expect_identical(as.character(captured_control$precision_beta$preset), "eigen_v1")
  expect_true(isTRUE(captured_control$precision_beta$eigen_fallback))
  expect_equal(as.numeric(captured_control$precision_beta$eigen_floor_abs), 1e-5, tolerance = 1e-12)
  expect_false(isTRUE(captured_control$precision_beta$trace))
})

test_that("qdesn_fit_mcmc accepts advanced warmup blocks at the top level", {
  y <- c(1, 2, 3, 4)
  X <- cbind(1, c(0.1, 0.2, 0.3, 0.4))
  captured_control <- NULL

  testthat::local_mocked_bindings(
    qdesn_fit_vb = function(..., fit_readout = FALSE, vb_args = list()) {
      list(
        y_fit = y,
        X = X,
        meta = list(p0 = 0.5)
      )
    },
    exal_mcmc_fit = function(y, X, p0, gamma_bounds, mcmc_control = NULL, ...) {
      captured_control <<- mcmc_control
      list(summary = list(beta_mean = rep(0, ncol(X))))
    },
    .package = "exdqlm"
  )

  fit <- exdqlm::qdesn_fit_mcmc(
    mcmc_args = list(
      likelihood_family = "exal",
      gamma_bounds = c(-2, 2),
      sigmagam = exdqlm::exal_make_mcmc_sigmagam_control(
        freeze_burnin_iters = 20L,
        force_after_warmup = FALSE
      ),
      theta = exdqlm::exal_make_mcmc_theta_control(
        freeze_burnin_iters = 12L,
        sparse_update_every = 3L,
        sparse_update_until_iter = 40L,
        force_first_postwarmup_update = FALSE
      ),
      latent_v = exdqlm::exal_make_mcmc_latent_v_control(
        freeze_burnin_iters = 30L,
        rescue_on_invalid = TRUE,
        rescue_max_consecutive = 4L,
        trace = FALSE
      ),
      latent_s = exdqlm::exal_make_mcmc_latent_s_control(
        freeze_burnin_iters = 16L,
        sparse_update_every = 4L,
        sparse_update_until_iter = 25L,
        trace = FALSE
      ),
      rhs = exdqlm::exal_make_mcmc_rhs_control(
        freeze_tau_burnin_iters = 18L,
        width_adapt_enabled = TRUE,
        width_adapt_warmup_iters = 30L
      ),
      precision_beta = exdqlm::exal_make_precision_beta_control("ladder_v2")
    )
  )

  expect_true(is.list(fit$fit))
  expect_equal(captured_control$sigmagam$freeze_burnin_iters, 20L)
  expect_false(isTRUE(captured_control$sigmagam$force_after_warmup))
  expect_equal(captured_control$theta$freeze_burnin_iters, 12L)
  expect_equal(captured_control$theta$sparse_update_every, 3L)
  expect_false(isTRUE(captured_control$theta$force_first_postwarmup_update))
  expect_equal(captured_control$latent_v$freeze_burnin_iters, 30L)
  expect_true(isTRUE(captured_control$latent_v$rescue_on_invalid))
  expect_equal(captured_control$latent_v$rescue_max_consecutive, 4L)
  expect_false(isTRUE(captured_control$latent_v$trace))
  expect_equal(captured_control$latent_s$freeze_burnin_iters, 16L)
  expect_equal(captured_control$latent_s$sparse_update_every, 4L)
  expect_false(isTRUE(captured_control$latent_s$trace))
  expect_equal(captured_control$rhs$freeze_tau_burnin_iters, 18L)
  expect_true(isTRUE(captured_control$rhs$width_adapt$enabled))
  expect_equal(captured_control$rhs$width_adapt$warmup_iters, 30L)
  expect_identical(as.character(captured_control$precision_beta$preset), "ladder_v2")
})
