test_that("RQR-DESN rejects ambiguous quantile-target arguments", {
  y <- as.numeric(sin(seq_len(28) / 5))
  base_args <- list(
    y = y,
    coverage_level = 0.8,
    D = 1L,
    n = 4L,
    m = 2L,
    washout = 2L,
    seed = 7701,
    fit_readout = FALSE
  )

  expect_error(
    do.call(exdqlm::rqr_desn_fit, c(base_args, list(p0 = 0.5))),
    "coverage_level"
  )
  expect_error(
    do.call(exdqlm::rqr_desn_fit, c(base_args, list(target_p = 0.5))),
    "coverage_level"
  )
})

test_that("fixed-design RQR save/load round trip preserves interval summaries", {
  set.seed(7702)
  x <- seq(-1, 1, length.out = 14)
  X <- cbind("(Intercept)" = 1, x = x)
  y <- as.numeric(0.05 + 0.25 * x + 0.12 * rnorm(length(x)))

  fit <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1.1,
    beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = 8)),
    mcmc_control = list(n_burn = 30, n_mcmc = 45, thin = 1, seed = 7702)
  )

  path <- tempfile(fileext = ".rds")
  saveRDS(fit, path)
  fit2 <- readRDS(path)

  expect_identical(fit2$model_spec, fit$model_spec)
  expect_identical(fit2$misc$column_names, fit$misc$column_names)

  X_new <- X[1:4, , drop = FALSE]
  pred1 <- exdqlm::predict_interval(fit, X_new = X_new)
  pred2 <- exdqlm::predict_interval(fit2, X_new = X_new)

  expect_equal(pred2$lower_mean, pred1$lower_mean)
  expect_equal(pred2$upper_mean, pred1$upper_mean)
  expect_true(all(pred2$upper_mean >= pred2$lower_mean))
})

test_that("learning-rate contract is stored and produces finite intervals", {
  set.seed(7703)
  x <- seq(-0.9, 0.9, length.out = 12)
  X <- cbind("(Intercept)" = 1, x = x)
  y <- as.numeric(-0.1 + 0.35 * x + 0.08 * rnorm(length(x)))

  fit_low <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.75,
    learning_rate = 0.5,
    mcmc_control = list(n_burn = 20, n_mcmc = 30, seed = 7703)
  )
  fit_high <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.75,
    learning_rate = 1.8,
    mcmc_control = list(n_burn = 20, n_mcmc = 30, seed = 7704)
  )

  expect_equal(fit_low$model_spec$learning_rate, 0.5)
  expect_equal(fit_high$model_spec$learning_rate, 1.8)
  expect_equal(fit_low$model_spec$sigma, 2)
  expect_equal(fit_high$model_spec$sigma, 1 / 1.8)
  expect_true(all(is.finite(fit_low$summary$width_mean)))
  expect_true(all(is.finite(fit_high$summary$width_mean)))
  expect_true(all(fit_low$summary$upper_mean >= fit_low$summary$lower_mean))
  expect_true(all(fit_high$summary$upper_mean >= fit_high$summary$lower_mean))
})

test_that("RQR-DESN design-only shell records interval target metadata", {
  y <- as.numeric(cos(seq_len(30) / 6))
  shell <- exdqlm::rqr_desn_fit(
    y = y,
    coverage_level = 0.7,
    D = 1L,
    n = 5L,
    m = 3L,
    alpha = 0.25,
    rho = 0.8,
    act_f = "tanh",
    act_k = "identity",
    pi_w = 0.3,
    pi_in = 1.0,
    washout = 3L,
    add_bias = TRUE,
    seed = 7705,
    fit_readout = FALSE
  )

  expect_true(isTRUE(shell$meta$rqr_design_only))
  expect_equal(shell$meta$rqr_coverage_level, 0.7)
  expect_true(is.matrix(shell$X))
  expect_true(nrow(shell$X) > 0)
  expect_gt(max(abs(shell$X)), 0)
})

test_that("RQR-DESN fit rejects an all-zero design shell", {
  y <- as.numeric(sin(seq_len(38) / 5))
  expect_error(
    exdqlm::rqr_desn_fit(
      y = y,
      coverage_level = 0.8,
      D = 1L,
      n = 6L,
      m = 3L,
      washout = 4L,
      seed = 8816007,
      mcmc_args = list(n_burn = 5, n_mcmc = 5, seed = 8816008)
    ),
    "all-zero Q-DESN design shell"
  )
})
