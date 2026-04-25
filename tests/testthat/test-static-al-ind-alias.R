tiny_static_alias_xy <- function(n = 18L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.25, -0.15) + stats::rnorm(n, sd = 0.12))
  list(X = X, y = y)
}

test_that("exalStaticLDVB supports al.ind alias for reduced AL path", {
  set.seed(7101)
  dat <- tiny_static_alias_xy(18)

  fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    al.ind = TRUE,
    max_iter = 50,
    tol = 5e-3,
    verbose = FALSE
  )

  expect_s3_class(fit, "exalStaticLDVB")
  expect_true(isTRUE(fit$dqlm.ind))
  expect_true(is.null(fit$qsiggam))
})

test_that("exalStaticMCMC supports al.ind alias for reduced AL path", {
  set.seed(7102)
  dat <- tiny_static_alias_xy(16)

  fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    al.ind = TRUE,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    verbose = FALSE
  )

  expect_s3_class(fit, "exalStaticMCMC")
  expect_true(isTRUE(fit$dqlm.ind))
  expect_false("samp.gamma" %in% names(fit))
})

test_that("static al.ind and dqlm.ind must agree when both are supplied", {
  set.seed(7103)
  dat <- tiny_static_alias_xy(14)

  expect_error(
    exalStaticLDVB(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      dqlm.ind = FALSE,
      al.ind = TRUE,
      max_iter = 30,
      tol = 1e-2,
      verbose = FALSE
    ),
    "conflicting inputs"
  )

  expect_error(
    exalStaticMCMC(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      dqlm.ind = FALSE,
      al.ind = TRUE,
      n.burn = 6,
      n.mcmc = 8,
      thin = 1,
      verbose = FALSE
    ),
    "conflicting inputs"
  )
})

test_that("exalStaticLDVB keeps exAL path when al.ind = FALSE", {
  set.seed(7104)
  dat <- tiny_static_alias_xy(18)

  fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    al.ind = FALSE,
    max_iter = 35,
    tol = 1e-2,
    n_samp_xi = 50,
    verbose = FALSE
  )

  expect_false(isTRUE(fit$dqlm.ind))
  expect_true(is.list(fit$qsiggam))
})
