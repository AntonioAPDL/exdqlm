tiny_qdesn_rolling_series <- function(n = 34L) {
  t <- seq_len(n)
  as.numeric(0.18 * sin(t / 4) + 0.05 * cos(t / 6) + 0.002 * t)
}

tiny_qdesn_rolling_desn_args <- function(seed = 20260610L) {
  list(
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 3L,
    add_bias = TRUE,
    seed = as.integer(seed)
  )
}

tiny_qdesn_rolling_vb_args <- function(chunking = NULL, max_iter = 8L) {
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
  args
}

test_that("qdesn_vb_fit_rolling fits independent rolling windows without future leakage", {
  y <- tiny_qdesn_rolling_series()
  origins <- c(20L, 24L, 28L)
  out <- exdqlm::qdesn_vb_fit_rolling(
    y = y,
    p0 = 0.5,
    origins = origins,
    window_size = 16L,
    desn_args = tiny_qdesn_rolling_desn_args(),
    vb_args = tiny_qdesn_rolling_vb_args(),
    keep_fits = TRUE
  )

  expect_s3_class(out, "qdesn_vb_rolling_fit")
  expect_identical(out$target$type, "rolling_window_full_data_vb")
  expect_false(isTRUE(out$target$preserves_full_data_target))
  expect_true(isTRUE(out$target$no_future_leakage))
  expect_equal(out$windows$origin, origins)
  expect_true(all(out$windows$window_end == origins))
  expect_true(all(out$windows$window_start == origins - 16L + 1L))
  expect_false(any(out$windows$uses_future_rows))
  expect_equal(nrow(out$summary), length(origins))
  expect_true(all(out$summary$likelihood_family == "al"))
  expect_true(all(out$summary$beta_prior_type == "ridge"))
  expect_true(all(out$summary$finite_qbeta))
  expect_true(all(out$summary$finite_sigma_gamma))
  expect_equal(length(out$fits), length(origins))
  expect_true(all(vapply(out$fits, function(x) inherits(x, "qdesn_fit"), logical(1))))
})

test_that("qdesn_vb_fit_rolling supports expanding windows", {
  y <- tiny_qdesn_rolling_series()
  origins <- c(18L, 22L)
  out <- exdqlm::qdesn_vb_fit_rolling(
    y = y,
    p0 = 0.5,
    origins = origins,
    mode = "expanding",
    desn_args = tiny_qdesn_rolling_desn_args(seed = 20260611L),
    vb_args = tiny_qdesn_rolling_vb_args(max_iter = 6L),
    keep_fits = FALSE
  )

  expect_identical(out$target$type, "expanding_window_full_data_vb")
  expect_true(all(out$windows$window_start == 1L))
  expect_true(all(out$windows$window_end == origins))
  expect_null(out$fits)
  expect_true(all(out$summary$finite_qbeta))
})

test_that("qdesn_vb_fit_rolling exact chunking matches unchunked per window", {
  y <- tiny_qdesn_rolling_series()
  origins <- c(22L, 26L)
  desn <- tiny_qdesn_rolling_desn_args(seed = 20260612L)
  plain_args <- tiny_qdesn_rolling_vb_args(max_iter = 9L)
  exact_args <- tiny_qdesn_rolling_vb_args(
    chunking = list(enabled = TRUE, mode = "exact", chunk_size = 5L),
    max_iter = 9L
  )

  plain <- exdqlm::qdesn_vb_fit_rolling(
    y = y, p0 = 0.5, origins = origins, window_size = 18L,
    desn_args = desn, vb_args = plain_args
  )
  exact <- exdqlm::qdesn_vb_fit_rolling(
    y = y, p0 = 0.5, origins = origins, window_size = 18L,
    desn_args = desn, vb_args = exact_args
  )

  expect_true(all(exact$summary$chunking_mode == "exact"))
  for (i in seq_along(origins)) {
    expect_equal(exact$fits[[i]]$fit$qbeta$m, plain$fits[[i]]$fit$qbeta$m, tolerance = 1e-8)
    expect_equal(exact$fits[[i]]$fit$qbeta$V, plain$fits[[i]]$fit$qbeta$V, tolerance = 1e-8)
    expect_equal(exact$fits[[i]]$mu_hat, plain$fits[[i]]$mu_hat, tolerance = 1e-8)
  }
})

test_that("qdesn_vb_fit_rolling fails early for gated target handoffs and modes", {
  y <- tiny_qdesn_rolling_series()
  desn <- tiny_qdesn_rolling_desn_args(seed = 20260613L)
  base <- tiny_qdesn_rolling_vb_args(max_iter = 4L)

  expect_error(
    exdqlm::qdesn_vb_fit_rolling(
      y = y, p0 = 0.5, origins = 20L, window_size = 12L,
      desn_args = desn, vb_args = base, posterior_as_prior = TRUE
    ),
    "posterior_as_prior is not implemented"
  )

  exal_args <- base
  exal_args$likelihood_family <- "exal"
  expect_error(
    exdqlm::qdesn_vb_fit_rolling(
      y = y, p0 = 0.5, origins = 20L, window_size = 12L,
      desn_args = desn, vb_args = exal_args
    ),
    "likelihood_family = 'al' only"
  )

  rhs_args <- base
  rhs_args$beta_prior_type <- "rhs_ns"
  expect_error(
    exdqlm::qdesn_vb_fit_rolling(
      y = y, p0 = 0.5, origins = 20L, window_size = 12L,
      desn_args = desn, vb_args = rhs_args
    ),
    "beta_prior_type = 'ridge' only"
  )

  stoch_args <- base
  stoch_args$chunking <- list(enabled = TRUE, mode = "stochastic", chunk_size = 5L)
  expect_error(
    exdqlm::qdesn_vb_fit_rolling(
      y = y, p0 = 0.5, origins = 20L, window_size = 12L,
      desn_args = desn, vb_args = stoch_args
    ),
    "unchunked or exact chunked"
  )

  warm_args <- base
  warm_args$warm_start <- list(enabled = TRUE, state = list())
  expect_error(
    exdqlm::qdesn_vb_fit_rolling(
      y = y, p0 = 0.5, origins = 20L, window_size = 12L,
      desn_args = desn, vb_args = warm_args
    ),
    "posterior-as-prior handoff"
  )
})
