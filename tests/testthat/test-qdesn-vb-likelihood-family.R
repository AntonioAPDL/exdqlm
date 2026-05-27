tiny_qdesn_series_for_likelihood_tests <- function(n = 24L) {
  t <- seq_len(n)
  as.numeric(0.2 * sin(t / 3) + 0.05 * cos(t / 5))
}

test_that("qdesn_fit_vb preserves default exAL readout routing", {
  y <- tiny_qdesn_series_for_likelihood_tests()
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260527L,
    vb_args = list(
      max_iter = 5L,
      min_iter_elbo = 2L,
      tol = 0,
      tol_par = 0,
      n_samp_xi = 16L,
      verbose = FALSE,
      beta_prior_type = "ridge",
      beta_ridge_tau2 = 10
    ),
    fit_readout = TRUE
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(as.character(fit$fit$likelihood_family), "exal")
})

test_that("qdesn_fit_vb forwards explicit AL likelihood controls", {
  y <- tiny_qdesn_series_for_likelihood_tests()
  fit <- exdqlm::qdesn_fit_vb(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260528L,
    vb_args = list(
      likelihood_family = "al",
      al_fixed_gamma = 0,
      max_iter = 5L,
      min_iter_elbo = 2L,
      tol = 0,
      tol_par = 0,
      n_samp_xi = 16L,
      verbose = FALSE,
      beta_prior_type = "ridge",
      beta_ridge_tau2 = 10
    ),
    fit_readout = TRUE
  )

  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(as.character(fit$fit$likelihood_family), "al")
  expect_equal(as.numeric(fit$fit$misc$al_fixed_gamma), 0, tolerance = 1e-12)
  expect_true(all(abs(as.numeric(fit$fit$misc$gamma_trace)) < 1e-12))
})
