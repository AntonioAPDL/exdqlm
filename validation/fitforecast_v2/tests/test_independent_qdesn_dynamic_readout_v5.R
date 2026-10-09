repo <- normalizePath(Sys.getenv("IDRV5_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_sentinel_mechanism_recovery_v1.R",
    "independent_qdesn_causal_adaptation_v2.R",
    "independent_qdesn_mcmc_finalist_bridge_v3.R",
    "independent_qdesn_rolling_readout_v4.R",
    "independent_qdesn_dynamic_readout_v5.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

testthat::test_that("half-life grid is broad, ordered, and finite after control", {
  x <- idrv5_policies()
  testthat::expect_identical(nrow(x), 6L)
  testthat::expect_true(is.infinite(x$half_life[1L]))
  testthat::expect_equal(x$half_life[-1L], c(1000, 500, 250, 125, 62.5))
  testthat::expect_equal(idrv5_delta(Inf), 1)
  testthat::expect_equal(idrv5_delta("infinite"), 1)
  testthat::expect_equal(idrv5_delta(100), 2^(-.01))
  testthat::expect_lt(idrv5_delta(62.5), idrv5_delta(1000))
})

testthat::test_that("rank-one assumed-density update matches direct solve", {
  e <- new.env(parent = emptyenv())
  e$.online_local_update_one <- function(...) list(barw = 2, barm = 6)
  state <- list(m = c(.2, -.1), V = matrix(c(.5, .1, .1, .3), 2),
    xis = list(), sigma = 1, gamma = 0, updates = 0L)
  x <- c(1, 2); delta <- idrv5_delta(250)
  observed <- idrv5_update(e, state, 0, x, 250)
  R <- state$V / delta
  P <- solve(R) + 2 * tcrossprod(x)
  h <- solve(R, state$m) + 6 * x
  expected_m <- solve(P, h)
  expected_V <- solve(P)
  testthat::expect_equal(observed$m, as.numeric(expected_m), tolerance = 1e-8)
  testthat::expect_equal(as.vector(observed$V), as.vector(expected_V),
    tolerance = 1e-8)
  testthat::expect_identical(observed$updates, 1L)
})

testthat::test_that("covariance stabilization only floors numerical modes", {
  V <- diag(c(1, 1e-20))
  out <- idrv5_stabilize_covariance(V)
  testthat::expect_true(all(eigen(out, symmetric = TRUE)$values > 0))
  testthat::expect_identical(attr(out, "clipped_eigenvalues"), 1L)
  testthat::expect_equal(out[1, 1], 1, tolerance = 1e-12)
})

testthat::test_that("screen and disjoint validation remain internal", {
  fold_ends <- c(S1 = 8000L, S2 = 8250L, S3 = 8500L, S4 = 8750L)
  for (end in fold_ends) {
    testthat::expect_lte(max(end + idrv5_screen_offsets + 30L), 9000L)
    targets <- lapply(end + idrv5_validation_offsets,
      function(origin) seq.int(origin + 1L, origin + 30L))
    testthat::expect_equal(length(unique(unlist(targets))), 120L)
    testthat::expect_lte(max(unlist(targets)), 9000L)
  }
})

testthat::test_that("scientific boundary is explicit in code and closeout", {
  worker <- paste(deparse(body(idrv5_worker)), collapse = "\n")
  closeout <- paste(deparse(body(idrv5_closeout)), collapse = "\n")
  testthat::expect_match(worker, "exact_M0_initialized")
  testthat::expect_match(worker, "exact_mcmc_after_initialization = FALSE")
  testthat::expect_match(closeout, "estimator_is_exact_mcmc = FALSE")
  testthat::expect_match(closeout, "validation_only_no_article_metric_replacement")
})

testthat::test_that("selection gates prioritize forecast MAE", {
  screen <- paste(deparse(body(idrv5_advance_screen)), collapse = "\n")
  validation <- paste(deparse(body(idrv5_advance_validation)), collapse = "\n")
  testthat::expect_match(screen, "median_rolling_mae_ratio < 1")
  testthat::expect_match(screen, "baseline_mae_wins\\s*>=\\s*6L")
  testthat::expect_match(validation, "median_baseline_mae_ratio < 1")
  testthat::expect_match(validation, "baseline_mae_wins\\s*>=\\s*9L")
})
