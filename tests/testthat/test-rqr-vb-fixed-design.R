test_that("RQR VB produces finite approximate interval summaries", {
  set.seed(7501)
  n <- 20
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(-0.1 + 0.3 * X[, 2] + 0.15 * rnorm(n))

  fit <- exdqlm::rqr_vb_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1,
    vb_control = list(max_iter = 60, tol = 1e-5, n_draws = 200, seed = 7501)
  )

  expect_s3_class(fit, "rqr_vb")
  expect_true(all(is.finite(fit$draws$beta_root1)))
  expect_true(all(is.finite(fit$draws$beta_root2)))
  expect_true(all(fit$summary$upper_mean >= fit$summary$lower_mean))
  expect_false(isTRUE(fit$model_spec$calibrated_uncertainty))
})

test_that("RQR VB tracks the MCMC interval center without claiming calibration", {
  set.seed(7502)
  y <- c(-1.0, -0.7, -0.2, 0.05, 0.45, 0.95)
  X <- matrix(1, length(y), 1)
  vb <- exdqlm::rqr_vb_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1,
    vb_control = list(max_iter = 80, n_draws = 300, seed = 7502)
  )
  mc <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1,
    mcmc_control = list(n_burn = 250, n_mcmc = 500, thin = 1, seed = 7503)
  )

  expect_equal(mean(vb$summary$midpoint_mean), mean(mc$summary$midpoint_mean), tolerance = 0.25)
  expect_gt(mean(vb$summary$width_mean), 0)
  expect_true(is.finite(mean(vb$summary$width_mean)))
  expect_false(isTRUE(vb$model_spec$calibrated_uncertainty))
})
