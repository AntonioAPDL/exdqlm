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

test_that("qdesn_fit_vb forwards exact chunking controls", {
  y <- tiny_qdesn_series_for_likelihood_tests()
  base_args <- list(
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
  )
  common <- list(
    y = y,
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = 20260529L,
    fit_readout = TRUE
  )

  fit_plain <- do.call(exdqlm::qdesn_fit_vb, c(common, list(vb_args = base_args)))
  fit_chunked <- do.call(
    exdqlm::qdesn_fit_vb,
    c(common, list(vb_args = modifyList(base_args, list(
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 3L)
    ))))
  )

  expect_equal(fit_chunked$fit$qbeta$m, fit_plain$fit$qbeta$m, tolerance = 1e-8)
  expect_equal(fit_chunked$fit$qbeta$V, fit_plain$fit$qbeta$V, tolerance = 1e-8)
  expect_equal(fit_chunked$fit$qv$m, fit_plain$fit$qv$m, tolerance = 1e-8)
  expect_equal(fit_chunked$fit$qs$m, fit_plain$fit$qs$m, tolerance = 1e-8)
  expect_equal(fit_chunked$fit$misc$sigma_trace, fit_plain$fit$misc$sigma_trace, tolerance = 1e-8)

  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(common, list(vb_args = modifyList(base_args, list(
      likelihood_family = "exal",
      chunking = list(enabled = TRUE, mode = "stochastic")
    ))))),
    "stochastic exAL VB chunking is not implemented"
  )
})
