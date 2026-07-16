test_that("RQR interval prediction works for explicit fixed design", {
  set.seed(7601)
  X <- cbind(1, seq(-1, 1, length.out = 16))
  y <- as.numeric(0.1 + 0.2 * X[, 2] + 0.1 * rnorm(16))
  fit <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    mcmc_control = list(n_burn = 30, n_mcmc = 40, thin = 1, seed = 7601)
  )
  pred <- exdqlm::predict_interval(fit, X_new = X[1:3, , drop = FALSE], nd = 20, seed = 7602)
  expect_equal(nrow(pred$lower_draws), 3L)
  expect_true(all(pred$upper_draws >= pred$lower_draws))
})

test_that("RQR-DESN forecast refuses implicit recursive response sampling", {
  set.seed(7603)
  y <- as.numeric(sin(seq_len(30) / 5))
  fit <- exdqlm::rqr_desn_fit(
    y = y,
    coverage_level = 0.8,
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
    seed = 7603,
    mcmc_args = list(n_burn = 10, n_mcmc = 12, seed = 7604)
  )
  expect_error(
    exdqlm::forecast_paths.rqr_desn_fit(fit, H = 2),
    "cannot recursively sample future responses"
  )

  X_future <- fit$X[1:2, , drop = FALSE]
  out <- exdqlm::forecast_paths.rqr_desn_fit(fit, H = 2, X_future = X_future, nd = 8)
  expect_equal(out$H, 2L)
  expect_false(isTRUE(out$response_predictive_draws))
  expect_true(all(out$upper_draws >= out$lower_draws))
})
