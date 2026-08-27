test_that("reservoir orthogonalization is train-fitted and forecast-consistent", {
  set.seed(417)
  n <- 160L
  phase <- seq_len(n) / 11
  X <- cbind(
    bias = 1,
    h1_1 = 2 * sin(phase) + rnorm(n, sd = 0.05),
    h1_2 = -cos(phase) + rnorm(n, sd = 0.05),
    lag_y_1 = rnorm(n),
    period90_sin_h1_lag_0 = sin(phase),
    period90_cos_h1_lag_0 = cos(phase)
  )
  fit <- readout_linear_transform_fit(
    X[1:100, , drop = FALSE],
    transform_spec = list(
      mode = "orthogonalize_reservoir",
      deterministic_prefix = "period90_"
    ),
    p_res = 3L,
    has_intercept = TRUE
  )
  expect_true(fit$transform$active)
  expect_identical(dim(fit$X), c(100L, 6L))
  expect_lt(max(abs(crossprod(
    fit$X[, c(1L, 5L, 6L), drop = FALSE],
    fit$X[, 2:3, drop = FALSE]
  ))), 1e-6)

  future <- readout_linear_transform_apply(X[101:160, , drop = FALSE], fit$transform)
  manual <- X[101:160, 2:3, drop = FALSE] -
    X[101:160, c(1L, 5L, 6L), drop = FALSE] %*%
      as.matrix(fit$transform$projection_coef)
  expect_equal(future[, 2:3, drop = FALSE], manual, tolerance = 1e-12)
  expect_identical(colnames(future), colnames(X))
})

test_that("SVD orthogonalization has a stable reusable reduced schema", {
  set.seed(418)
  n <- 120L
  d <- cbind(1, sin(seq_len(n) / 9), cos(seq_len(n) / 9))
  latent <- matrix(rnorm(n * 3L), nrow = n)
  reservoir <- cbind(latent, latent[, 1] + latent[, 2], latent[, 2] * 2)
  colnames(reservoir) <- paste0("h1_", seq_len(ncol(reservoir)))
  X <- cbind(
    bias = d[, 1], reservoir,
    lag_y_1 = rnorm(n),
    period90_sin_h1_lag_0 = d[, 2],
    period90_cos_h1_lag_0 = d[, 3]
  )
  fit <- readout_linear_transform_fit(
    X[1:80, , drop = FALSE],
    transform_spec = list(
      mode = "orthogonalize_reservoir_svd",
      deterministic_prefix = "period90_",
      svd_energy_threshold = 0.999,
      svd_max_rank = 4L
    ),
    p_res = 6L,
    has_intercept = TRUE
  )
  expect_lte(fit$transform$selected_rank, 4L)
  expect_equal(ncol(fit$X), 4L + fit$transform$selected_rank)
  future <- readout_linear_transform_apply(X[81:120, , drop = FALSE], fit$transform)
  expect_identical(colnames(future), colnames(fit$X))
  expect_true(all(is.finite(future)))
})

test_that("readout transforms reject schema drift", {
  X <- cbind(
    bias = 1,
    h1_1 = seq_len(30),
    period90_sin_h1_lag_0 = sin(seq_len(30))
  )
  fit <- readout_linear_transform_fit(
    X,
    transform_spec = list(mode = "orthogonalize_reservoir"),
    p_res = 2L,
    has_intercept = TRUE
  )
  bad <- X
  colnames(bad)[2L] <- "different"
  expect_error(
    readout_linear_transform_apply(bad, fit$transform),
    "column names"
  )
})
