test_that("RQR MCMC supports RHS_NS with finite tiny draws", {
  set.seed(7401)
  n <- 18
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(0.2 + 0.4 * X[, 2] + 0.2 * rnorm(n))
  prior <- exdqlm::beta_prior("rhs_ns", rhs = list(
    tau0 = 0.5,
    a_zeta = 2,
    b_zeta = 1,
    s2 = 1,
    n_inner = 1L
  ))

  fit <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1,
    beta_prior_obj = prior,
    mcmc_control = list(n_burn = 20, n_mcmc = 25, thin = 1, seed = 7401)
  )

  expect_s3_class(fit, "rqr_mcmc")
  expect_identical(fit$beta_prior$type, "rhs_ns")
  expect_false(isTRUE(fit$beta_prior$hypers$shrink_intercept))
  expect_true(all(is.finite(fit$samp.beta_root1)))
  expect_true(all(is.finite(fit$samp.beta_root2)))
  expect_true(all(fit$summary$upper_mean >= fit$summary$lower_mean))
})
