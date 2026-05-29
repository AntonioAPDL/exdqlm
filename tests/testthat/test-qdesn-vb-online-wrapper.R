tiny_qdesn_online_series <- function(n = 36L) {
  t <- seq_len(n)
  as.numeric(0.14 * sin(t / 4) + 0.05 * cos(t / 8) + 0.002 * t)
}

tiny_qdesn_online_desn_args <- function(seed = 20260640L) {
  list(
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 3L,
    add_bias = TRUE,
    seed = as.integer(seed)
  )
}

tiny_qdesn_online_vb_args <- function(chunking = NULL, max_iter = 6L,
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

test_that("one-batch online wrapper equals ordinary AL ridge Q-DESN fit", {
  y <- tiny_qdesn_online_series()
  desn <- tiny_qdesn_online_desn_args()
  vb <- tiny_qdesn_online_vb_args(max_iter = 6L)

  ordinary <- do.call(
    exdqlm::qdesn_fit_vb,
    c(list(y = y, p0 = 0.5, fit_readout = TRUE), desn, list(vb_args = vb))
  )
  online <- exdqlm::qdesn_vb_fit_online(
    y = y,
    p0 = 0.5,
    desn_args = desn,
    vb_args = vb,
    keep_fits = TRUE
  )

  expect_s3_class(online, "qdesn_vb_online_fit")
  expect_identical(online$target$type, "online_posterior_as_prior_al_ridge")
  expect_false(isTRUE(online$target$preserves_full_data_target))
  expect_true(isTRUE(online$target$order_sensitive))
  expect_equal(nrow(online$batches), 1L)
  expect_true(is.na(online$state_handoffs$input_state_hash[1]))
  expect_equal(online$fits[[1]]$fit$qbeta$m, ordinary$fit$qbeta$m, tolerance = 1e-10)
  expect_equal(online$fits[[1]]$fit$qbeta$V, ordinary$fit$qbeta$V, tolerance = 1e-10)
  expect_equal(online$fits[[1]]$mu_hat, ordinary$mu_hat, tolerance = 1e-10)
})

test_that("two-batch online wrapper uses posterior-as-prior handoff metadata", {
  y <- tiny_qdesn_online_series()
  out1 <- exdqlm::qdesn_vb_fit_online(
    y = y,
    p0 = 0.5,
    batch_ends = c(18L, length(y)),
    desn_args = tiny_qdesn_online_desn_args(seed = 20260641L),
    vb_args = tiny_qdesn_online_vb_args(max_iter = 6L),
    keep_fits = TRUE
  )
  out2 <- exdqlm::qdesn_vb_fit_online(
    y = y,
    p0 = 0.5,
    batch_ends = c(18L, length(y)),
    desn_args = tiny_qdesn_online_desn_args(seed = 20260641L),
    vb_args = tiny_qdesn_online_vb_args(max_iter = 6L),
    keep_fits = TRUE
  )

  expect_equal(nrow(out1$batches), 2L)
  expect_equal(out1$batches$batch_start, c(1L, 19L))
  expect_equal(out1$batches$batch_end, c(18L, 36L))
  expect_false(any(out1$batches$uses_future_rows))
  expect_true(isTRUE(out1$target$no_future_leakage))
  expect_identical(out1$summary$beta_prior_type[1], "ridge")
  expect_identical(out1$summary$beta_prior_type[2], "gaussian_natural")
  expect_identical(out1$state_handoffs$output_state_hash[1], out1$state_handoffs$input_state_hash[2])
  expect_equal(out1$state_handoffs$input_from_batch, c(NA_integer_, 1L))
  expect_true(all(out1$state_handoffs$prior_family == "gaussian_natural"))
  expect_true(all(out1$state_handoffs$covariance_form == "full"))
  expect_true(all(out1$state_handoffs$output_precision_dim == ncol(out1$fits[[1]]$X)))
  expect_equal(out1$state_handoffs$output_natural_norm, out2$state_handoffs$output_natural_norm, tolerance = 1e-12)
})

test_that("exact chunked online wrapper matches unchunked online wrapper", {
  y <- tiny_qdesn_online_series()
  desn <- tiny_qdesn_online_desn_args(seed = 20260642L)
  plain <- exdqlm::qdesn_vb_fit_online(
    y = y,
    p0 = 0.5,
    batch_ends = c(18L, length(y)),
    desn_args = desn,
    vb_args = tiny_qdesn_online_vb_args(max_iter = 7L)
  )
  exact <- exdqlm::qdesn_vb_fit_online(
    y = y,
    p0 = 0.5,
    batch_ends = c(18L, length(y)),
    desn_args = desn,
    vb_args = tiny_qdesn_online_vb_args(
      chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
      max_iter = 7L
    )
  )

  expect_true(all(exact$summary$chunking_mode == "exact"))
  expect_equal(exact$state_handoffs$output_natural_norm, plain$state_handoffs$output_natural_norm, tolerance = 1e-8)
  for (i in seq_along(plain$fits)) {
    expect_equal(exact$fits[[i]]$fit$qbeta$m, plain$fits[[i]]$fit$qbeta$m, tolerance = 1e-8)
    expect_equal(exact$fits[[i]]$fit$qbeta$V, plain$fits[[i]]$fit$qbeta$V, tolerance = 1e-8)
    expect_equal(exact$fits[[i]]$mu_hat, plain$fits[[i]]$mu_hat, tolerance = 1e-8)
  }
})

test_that("online wrapper fails early for unsupported target handoffs", {
  y <- tiny_qdesn_online_series()
  desn <- tiny_qdesn_online_desn_args(seed = 20260643L)
  base <- tiny_qdesn_online_vb_args(max_iter = 4L)

  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_size = 18L,
      desn_args = desn, vb_args = base, posterior_as_prior = FALSE
    ),
    "requires posterior_as_prior"
  )

  exal_args <- base
  exal_args$likelihood_family <- "exal"
  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_size = 18L,
      desn_args = desn, vb_args = exal_args
    ),
    "likelihood_family = 'al' only"
  )

  rhs_args <- base
  rhs_args$beta_prior_type <- "rhs_ns"
  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_size = 18L,
      desn_args = desn, vb_args = rhs_args
    ),
    "beta_prior_type = 'ridge' only"
  )

  stoch_args <- base
  stoch_args$chunking <- list(enabled = TRUE, mode = "stochastic", chunk_size = 6L)
  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_size = 18L,
      desn_args = desn, vb_args = stoch_args
    ),
    "unchunked or exact chunked"
  )

  warm_args <- base
  warm_args$warm_start <- list(enabled = TRUE, state = list())
  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_size = 18L,
      desn_args = desn, vb_args = warm_args
    ),
    "posterior-as-prior handoff"
  )

  diag_args <- tiny_qdesn_online_vb_args(
    max_iter = 4L,
    beta_covariance = list(approximation = "diagonal")
  )
  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_size = 18L,
      desn_args = desn, vb_args = diag_args
    ),
    "requires full beta covariance"
  )

  expect_error(
    exdqlm::qdesn_vb_fit_online(
      y = y, p0 = 0.5, batch_ends = c(12L, 24L),
      desn_args = desn, vb_args = base
    ),
    "batch_ends must include length"
  )
})
