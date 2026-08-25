test_that("conditional-mean lattice recursion preserves draw identity and lead one", {
  withr::local_seed(9201)
  y <- as.numeric(arima.sim(list(ar = 0.55), n = 90, sd = 0.25))
  fit <- exdqlm:::qdesn_fit_vb(
    y = y,
    p0 = 0.25,
    D = 1L,
    n = 6L,
    n_tilde = integer(0),
    m = 2L,
    alpha = 0.25,
    rho = 0.85,
    pi_w = 1,
    pi_in = 1,
    washout = 5L,
    add_bias = TRUE,
    seed = 9202,
    fit_readout = TRUE,
    vb_args = list(max_iter = 8L, min_iter_elbo = 2L, tol = 1e-3,
                   tol_par = 1e-3, verbose = FALSE)
  )
  draws <- exdqlm::exal_posterior_draws(fit$fit, nd = 24L)
  native <- exdqlm:::forecast_lattice.qdesn_fit(
    fit, y_all = y, origins = c(70L, 75L), H = 4L, nd = 24L,
    draws = draws, keep_origin_draws = TRUE, seed = 9203,
    recursion_mode = "posterior_predictive"
  )
  plugin <- exdqlm:::forecast_lattice.qdesn_fit(
    fit, y_all = y, origins = c(70L, 75L), H = 4L, nd = 24L,
    draws = draws, keep_origin_draws = TRUE, seed = 9203,
    recursion_mode = "conditional_mean_plugin"
  )

  expect_identical(native$source_draw_index, plugin$source_draw_index)
  expect_equal(native$mu_by_origin[[1L]][1L, ], plugin$mu_by_origin[[1L]][1L, ],
               tolerance = 1e-12)
  expect_equal(plugin$yrep_by_origin[[1L]], plugin$mu_by_origin[[1L]],
               tolerance = 1e-12)
  expect_gt(max(abs(native$mu_by_origin[[1L]][-1L, ] -
                    plugin$mu_by_origin[[1L]][-1L, ])), 0)
  expect_identical(plugin$recursion_mode, "conditional_mean_plugin")
  expect_equal(nrow(plugin$draw_parameters), 24L)
})

test_that("MCMC posterior subsampling records exact source rows", {
  fit <- structure(list(
    samp.beta = matrix(seq_len(60), nrow = 20L, ncol = 3L),
    samp.sigma = seq_len(20) / 10,
    samp.gamma = seq(-0.5, 0.5, length.out = 20)
  ), class = "exal_mcmc")
  draws <- exdqlm::exal_mcmc_posterior_draws(fit, nd = 8L, seed = 711L)
  expect_length(draws$source_draw_index, 8L)
  expect_equal(draws$beta, as.matrix(fit$samp.beta)[draws$source_draw_index, , drop = FALSE])
  expect_equal(draws$sigma, as.numeric(fit$samp.sigma)[draws$source_draw_index])
  expect_equal(draws$gamma, as.numeric(fit$samp.gamma)[draws$source_draw_index])
})
