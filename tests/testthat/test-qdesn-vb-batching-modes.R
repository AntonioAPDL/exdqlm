tiny_qdesn_series_for_batching_tests <- function(n = 30L) {
  t <- seq_len(n)
  as.numeric(0.2 * sin(t / 3) + 0.05 * cos(t / 5))
}

tiny_qdesn_common_args <- function(seed = 20260531L) {
  list(
    p0 = 0.5,
    D = 1L,
    n = 4L,
    m = 1L,
    washout = 4L,
    add_bias = TRUE,
    seed = as.integer(seed),
    fit_readout = TRUE
  )
}

tiny_qdesn_al_vb_args <- function(chunking = NULL, max_iter = 20L) {
  args <- list(
    likelihood_family = "al",
    al_fixed_gamma = 0,
    max_iter = as.integer(max_iter),
    min_iter_elbo = 5L,
    tol = 0,
    tol_par = 0,
    n_samp_xi = 16L,
    verbose = FALSE,
    beta_prior_type = "ridge",
    beta_ridge_tau2 = 10
  )
  if (!is.null(chunking)) args$chunking <- chunking
  args
}

tiny_qdesn_stochastic_chunking <- function(seed = 42L) {
  list(
    enabled = TRUE,
    mode = "stochastic",
    chunk_size = 5L,
    order = "random",
    seed = as.integer(seed),
    learning_rate = list(t0 = 5, kappa = 0.75, rho_min = 0.02),
    refresh = list(
      full_every = 10L,
      objective_every = 10L,
      sigma_every = 5L,
      rhs_every = 10L,
      local_every = 10L
    ),
    diagnostics = list(trace = TRUE, store_batch_ids = TRUE, check_finite_every = 1L)
  )
}

tiny_qdesn_hybrid_chunking <- function(seed = 45L, full_every = 1L) {
  out <- tiny_qdesn_stochastic_chunking(seed = seed)
  out$mode <- "hybrid"
  out$refresh$full_every <- as.integer(full_every)
  out$refresh$objective_every <- as.integer(full_every)
  out$refresh$sigma_every <- as.integer(full_every)
  out$refresh$rhs_every <- as.integer(full_every)
  out$refresh$local_every <- as.integer(full_every)
  out
}

test_that("qdesn_fit_vb routes stochastic AL chunking through the static readout engine", {
  y <- tiny_qdesn_series_for_batching_tests()
  common <- tiny_qdesn_common_args()
  stoch_args <- tiny_qdesn_al_vb_args(chunking = tiny_qdesn_stochastic_chunking(seed = 42L))

  fit1 <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = stoch_args)))
  fit2 <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = stoch_args)))

  expect_s3_class(fit1$fit, "exal_vb")
  expect_identical(as.character(fit1$fit$likelihood_family), "al")
  expect_true(isTRUE(fit1$fit$misc$stochastic))
  expect_identical(fit1$fit$misc$chunking$mode, "stochastic")
  expect_true(all(is.finite(fit1$fit$qbeta$m)))
  expect_true(all(is.finite(fit1$fit$qbeta$V)))
  expect_true(all(is.finite(fit1$fit$misc$sigma_trace)))
  expect_true(all(fit1$fit$misc$sigma_trace > 0))
  expect_true(is.data.frame(fit1$fit$misc$stochastic_trace))
  expect_equal(fit1$fit$qbeta$m, fit2$fit$qbeta$m, tolerance = 1e-12)
  expect_equal(fit1$fit$misc$stochastic_trace, fit2$fit$misc$stochastic_trace, tolerance = 1e-12)
  expect_equal(fit1$fit$misc$stochastic_batch_ids, fit2$fit$misc$stochastic_batch_ids)
})

test_that("qdesn_fit_vb stochastic AL is approximate but close on tiny smooth data", {
  y <- tiny_qdesn_series_for_batching_tests()
  common <- tiny_qdesn_common_args(seed = 20260532L)
  exact_args <- tiny_qdesn_al_vb_args(max_iter = 20L)
  stoch_args <- tiny_qdesn_al_vb_args(
    chunking = tiny_qdesn_stochastic_chunking(seed = 43L),
    max_iter = 40L
  )

  fit_exact <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = exact_args)))
  fit_stoch <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = stoch_args)))

  expect_false(isTRUE(fit_exact$fit$misc$stochastic))
  expect_true(isTRUE(fit_stoch$fit$misc$stochastic))
  expect_true(max(abs(fit_exact$fit$qbeta$m - fit_stoch$fit$qbeta$m)) < 0.25)
  expect_true(max(abs(diag(fit_stoch$fit$qbeta$V))) < 10)
})

test_that("qdesn_fit_vb routes hybrid AL and full-refresh hybrid matches exact", {
  y <- tiny_qdesn_series_for_batching_tests()
  common <- tiny_qdesn_common_args(seed = 20260534L)
  exact_args <- tiny_qdesn_al_vb_args(max_iter = 16L)
  hybrid_args <- tiny_qdesn_al_vb_args(
    chunking = tiny_qdesn_hybrid_chunking(seed = 45L, full_every = 1L),
    max_iter = 16L
  )

  fit_exact <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = exact_args)))
  fit_hybrid <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = hybrid_args)))

  expect_s3_class(fit_hybrid$fit, "exal_vb")
  expect_identical(as.character(fit_hybrid$fit$likelihood_family), "al")
  expect_true(isTRUE(fit_hybrid$fit$misc$hybrid))
  expect_identical(fit_hybrid$fit$misc$chunking$mode, "hybrid")
  expect_true(all(fit_hybrid$fit$misc$stochastic_trace$full_refresh))
  expect_equal(fit_hybrid$fit$qbeta$m, fit_exact$fit$qbeta$m, tolerance = 1e-8)
  expect_equal(fit_hybrid$fit$qbeta$V, fit_exact$fit$qbeta$V, tolerance = 1e-8)
})

test_that("qdesn_fit_vb rejects stochastic exAL while preserving exact exAL", {
  y <- tiny_qdesn_series_for_batching_tests()
  common <- tiny_qdesn_common_args(seed = 20260533L)
  exal_stoch <- tiny_qdesn_al_vb_args(chunking = tiny_qdesn_stochastic_chunking(seed = 44L))
  exal_stoch$likelihood_family <- "exal"
  exal_stoch$al_fixed_gamma <- NULL

  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = exal_stoch))),
    "supported only for likelihood_family = 'al'"
  )

  exal_exact <- exal_stoch
  exal_exact$chunking <- list(enabled = TRUE, mode = "exact", chunk_size = 5L)
  fit <- do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = exal_exact)))
  expect_s3_class(fit$fit, "exal_vb")
  expect_identical(as.character(fit$fit$likelihood_family), "exal")
  expect_false(isTRUE(fit$fit$misc$stochastic))
})

test_that("qdesn_fit_vb rejects hybrid exAL", {
  y <- tiny_qdesn_series_for_batching_tests()
  common <- tiny_qdesn_common_args(seed = 20260535L)
  exal_hybrid <- tiny_qdesn_al_vb_args(chunking = tiny_qdesn_hybrid_chunking(seed = 46L, full_every = 2L))
  exal_hybrid$likelihood_family <- "exal"
  exal_hybrid$al_fixed_gamma <- NULL

  expect_error(
    do.call(exdqlm::qdesn_fit_vb, c(list(y = y), common, list(vb_args = exal_hybrid))),
    "supported only for likelihood_family = 'al'"
  )
})
