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
