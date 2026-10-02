iqbs_test_load <- function() {
  source(file.path(harness_root, "R/independent_qdesn_beta_solver_v5.R"), local = FALSE)
  iqbs_v5_source(repo_root)
}

test_that("v5 exact solver preserves coupled means and covariance on challenging designs", {
  iqbs_test_load()
  set.seed(901)
  for (wide in c(FALSE, TRUE)) {
    n <- 18L; p <- if (wide) 25L else 6L
    X <- cbind(1, matrix(rnorm(n * (p - 1L)), n))
    X[, 3L] <- X[, 2L]
    w <- exp(seq(-2, 2, length.out = n))
    prior <- c(1e-8, exp(seq(-2, 4, length.out = p - 1L)))
    S <- crossprod(X * sqrt(w)); g <- drop(crossprod(X, sin(seq_len(n))))
    solved <- exdqlm:::.exal_beta_solve_from_data_stats(list(S = S, g = g), prior)
    P <- S + diag(prior)
    expect_equal(solved$sol$x, drop(solve(P, g)), tolerance = 1e-6)
    expect_equal(solved$sol$inv, solve(P), tolerance = 1e-6)
    expect_lt(sqrt(sum((P %*% solved$sol$x - g)^2)) / sqrt(sum(g^2)), 1e-6)
    expect_equal(rowSums((X %*% solved$sol$inv) * X), diag(X %*% solve(P) %*% t(X)), tolerance = 1e-6)
  }
})

test_that("diagonal precision counterexample is not mistaken for the coupled solution", {
  iqbs_test_load()
  x <- seq(-1, 1, length.out = 100)
  X <- cbind(x, x); S <- crossprod(X); g <- drop(crossprod(X, x))
  full <- exdqlm:::.exal_beta_solve_from_data_stats(list(S = S, g = g), c(.1, .1))
  diag <- exdqlm:::.exal_beta_solve_diagonal_from_data_stats(list(S = S, g = g), c(.1, .1))
  expect_gt(sum(diag$sol$x), 1.99)
  expect_lt(abs(sum(full$sol$x) - 1), .002)
})

test_that("fit point-path and posterior score intervals are kept distinct", {
  iqbs_test_load()
  identity_transport <- list(inverse = function(x) x)
  s <- iqbs_v5_fit_summaries(matrix(1, 4, 1), 0, matrix(c(-2, 2), 2, 1),
    rep(0, 4), rep(0, 4), .5, identity_transport)
  expect_equal(s$scores$fit_point_rmse, 0)
  expect_equal(s$scores$fit_draw_rmse_mean, 2)
  expect_equal(s$scores$fit_sample_mean_path_rmse, 0)
  expect_equal(s$path$lower_025, rep(-1.9, 4))
  t <- iqbs_v5_fit_summaries(matrix(1, 4, 1), 0, matrix(c(-2, 2), 2, 1),
    rep(10, 4), rep(10, 4), .5, list(inverse = function(x) 10 + 3 * x))
  expect_equal(t$scores$fit_draw_rmse_mean, 6)
  expect_equal(t$scores$fit_point_rmse, 0)
})

test_that("comparison rejects changes outside the solver and metadata", {
  iqbs_test_load()
  original <- setNames(as.list(seq_along(iqbs_v5_science_fields)), iqbs_v5_science_fields)
  child <- original; child$beta_covariance_approximation <- "full"
  expect_true(all(iqbs_v5_science_check(original, child)))
  child$seed <- 991
  expect_false(all(iqbs_v5_science_check(original, child)))
})

test_that("v5 has bounded parallel workers and no automatic expansion", {
  iqbs_test_load()
  script <- paste(readLines(file.path(repo_root,
    "validation/fitforecast_v2/scripts/run_independent_qdesn_beta_solver_v5.sh")), collapse = "\n")
  expect_match(script, "for i in 0 1 2 3", fixed = TRUE)
  expect_match(script, "OMP_NUM_THREADS=1", fixed = TRUE)
  expect_match(script, "7200s", fixed = TRUE)
  expect_match(script, "flock -n 9", fixed = TRUE)
  expect_false(grepl("adaptive_refinement|origin/main|overleaf", script))
})

test_that("replay gate covers all metrics and rejects missing estimator rows", {
  iqbs_test_load()
  x <- data.frame(estimator = c("mean_conditional_location", "posterior_predictive_quantile_pooled"), inner_paths = 128)
  for (f in c("forecast_qtrue_mae", "forecast_qtrue_rmse", "forecast_check_loss",
    "fit_qtrue_rmse_mean", "fit_qtrue_mae_mean", "fit_check_loss_mean")) x[[f]] <- c(1, 2)
  expect_true(iqbs_v5_replay_check(x, x)$pass)
  y <- x; y$forecast_check_loss[1] <- 1.01
  expect_false(iqbs_v5_replay_check(x, y)$pass)
  expect_false(iqbs_v5_replay_check(x, x[1, ])$pass)
})
