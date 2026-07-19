test_that("RQR learned-scale lambda conditionals use the declared shape and rate", {
  ls <- exdqlm:::.rqr_lambda_posterior_params(
    loss_sum = 5,
    n = 10,
    lambda_prior = list(shape = 4, rate = 4),
    learning_rate_mode = "learned_scale"
  )
  pure <- exdqlm:::.rqr_lambda_posterior_params(
    loss_sum = 5,
    n = 10,
    lambda_prior = list(shape = 4, rate = 4),
    learning_rate_mode = "learned_pure"
  )

  expect_equal(ls$shape, 14)
  expect_equal(ls$rate, 9)
  expect_equal(ls$power_count, 10)
  expect_equal(pure$shape, 4)
  expect_equal(pure$rate, 9)
  expect_equal(pure$power_count, 0)
})

test_that("RQR MCMC fixed mode remains fixed and learned-scale mode samples lambda", {
  set.seed(7801)
  n <- 18
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(0.1 + 0.45 * X[, 2] + 0.2 * stats::rnorm(n))
  prior <- exdqlm::beta_prior("ridge", ridge = list(tau2 = 5))

  fixed <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1.25,
    loss_reference_scale = 2,
    beta_prior_obj = prior,
    mcmc_control = list(n_burn = 10, n_mcmc = 15, thin = 1, seed = 7801)
  )
  learned <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1,
    learning_rate_mode = "learned_scale",
    lambda_prior = list(shape = 4, rate = 4),
    beta_prior_obj = prior,
    mcmc_control = list(n_burn = 20, n_mcmc = 30, thin = 1, seed = 7802)
  )

  expect_identical(fixed$model_spec$learning_rate_mode, "fixed")
  expect_true(all(fixed$samp.lambda == 1.25))
  expect_equal(fixed$model_spec$effective_learning_rate, 0.625)
  expect_equal(fixed$model_spec$loss_reference_scale, 2)
  expect_identical(learned$model_spec$learning_rate_mode, "learned_scale")
  expect_true(isTRUE(learned$model_spec$learned_inverse_loss_scale))
  expect_true(all(is.finite(learned$samp.lambda)))
  expect_true(all(learned$samp.lambda > 0))
  expect_gt(stats::sd(learned$samp.lambda), 0)
  expect_equal(learned$model_spec$lambda_prior$shape, 4)
  expect_equal(learned$model_spec$lambda_prior$rate, 4)
  expect_equal(learned$model_spec$lambda_power, n)

  draws <- exdqlm::rqr_posterior_draws(learned, nd = 7, seed = 7803)
  expect_equal(length(draws$lambda), 7L)
  pred <- exdqlm::predict_interval(learned, X_new = X[1:4, , drop = FALSE], nd = 7, seed = 7804)
  expect_equal(length(pred$draws$lambda), 7L)
  expect_true(all(pred$upper_draws >= pred$lower_draws))
})

test_that("RQR-DESN learned-scale MCMC is available but VB learned-scale is guarded", {
  set.seed(7805)
  y <- as.numeric(sin(seq_len(28) / 4) + 0.1 * stats::rnorm(28))

  fit <- exdqlm::rqr_desn_fit(
    y = y,
    coverage_level = 0.8,
    learning_rate_mode = "learned_scale",
    lambda_prior = list(shape = 4, rate = 4),
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
    seed = 7805,
    mcmc_args = list(n_burn = 8, n_mcmc = 10, seed = 7806)
  )

  expect_s3_class(fit, "rqr_desn_fit")
  expect_identical(fit$model_spec$learning_rate_mode, "learned_scale")
  expect_true(all(is.finite(fit$fit$samp.lambda)))
  expect_error(
    exdqlm::rqr_desn_fit(
      y = y,
      coverage_level = 0.8,
      inference = "vb",
      learning_rate_mode = "learned_scale",
      D = 1L,
      n = 5L,
      m = 3L,
      washout = 3L
    ),
    "currently implemented for MCMC"
  )
})
