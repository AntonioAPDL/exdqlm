tiny_qdesn_pap_series <- function(n = 34L) {
  t <- seq_len(n)
  as.numeric(0.16 * sin(t / 5) + 0.04 * cos(t / 7) + 0.0015 * t)
}

tiny_qdesn_pap_desn_args <- function(seed = 20260630L) {
  list(
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 3L,
    add_bias = TRUE,
    seed = as.integer(seed)
  )
}

tiny_qdesn_pap_vb_args <- function(chunking = NULL, max_iter = 6L,
                                   beta_covariance = NULL) {
  args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10,
    max_iter = as.integer(max_iter),
    min_iter_elbo = 2L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE
  )
  if (!is.null(chunking)) args$chunking <- chunking
  if (!is.null(beta_covariance)) args$beta_covariance <- beta_covariance
  args
}

test_that("posterior-as-prior records Gaussian natural handoff metadata", {
  y <- tiny_qdesn_pap_series()
  out <- exdqlm::qdesn_vb_fit_rolling(
    y = y,
    p0 = 0.5,
    origins = c(20L, 25L),
    window_size = 16L,
    desn_args = tiny_qdesn_pap_desn_args(),
    vb_args = tiny_qdesn_pap_vb_args(),
    posterior_as_prior = TRUE
  )

  expect_identical(out$target$type, "posterior_as_prior_al_ridge")
  expect_false(isTRUE(out$target$preserves_full_data_target))
  expect_equal(nrow(out$state_handoffs), 2L)
  expect_true(is.na(out$state_handoffs$input_state_hash[1]))
  expect_identical(out$state_handoffs$output_state_hash[1], out$state_handoffs$input_state_hash[2])
  expect_true(all(out$summary$posterior_as_prior))
  expect_identical(out$summary$beta_prior_type[1], "ridge")
  expect_identical(out$summary$beta_prior_type[2], "gaussian_natural")
  expect_true(is.finite(out$summary$prior_natural_norm[2]))
  expect_gt(out$summary$prior_natural_norm[2], 0)
})

test_that("posterior-as-prior exact chunking matches unchunked handoff target", {
  y <- tiny_qdesn_pap_series()
  origins <- c(21L, 27L)
  desn <- tiny_qdesn_pap_desn_args(seed = 20260631L)
  plain <- exdqlm::qdesn_vb_fit_rolling(
    y = y,
    p0 = 0.5,
    origins = origins,
    window_size = 17L,
    desn_args = desn,
    vb_args = tiny_qdesn_pap_vb_args(max_iter = 7L),
    posterior_as_prior = TRUE
  )
  exact <- exdqlm::qdesn_vb_fit_rolling(
    y = y,
    p0 = 0.5,
    origins = origins,
    window_size = 17L,
    desn_args = desn,
    vb_args = tiny_qdesn_pap_vb_args(
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
      max_iter = 7L
    ),
    posterior_as_prior = TRUE
  )

  expect_true(all(exact$summary$chunking_mode == "exact"))
  expect_equal(exact$state_handoffs$output_natural_norm, plain$state_handoffs$output_natural_norm, tolerance = 1e-8)
  for (i in seq_along(origins)) {
    expect_equal(exact$fits[[i]]$fit$qbeta$m, plain$fits[[i]]$fit$qbeta$m, tolerance = 1e-8)
    expect_equal(exact$fits[[i]]$fit$qbeta$V, plain$fits[[i]]$fit$qbeta$V, tolerance = 1e-8)
    expect_equal(exact$fits[[i]]$mu_hat, plain$fits[[i]]$mu_hat, tolerance = 1e-8)
  }
})

test_that("posterior-as-prior forbids diagonal covariance until validated", {
  y <- tiny_qdesn_pap_series()
  expect_error(
    exdqlm::qdesn_vb_fit_rolling(
      y = y,
      p0 = 0.5,
      origins = c(20L, 25L),
      window_size = 16L,
      desn_args = tiny_qdesn_pap_desn_args(),
      vb_args = tiny_qdesn_pap_vb_args(
        beta_covariance = list(approximation = "diagonal")
      ),
      posterior_as_prior = TRUE
    ),
    "requires full beta covariance"
  )
})
