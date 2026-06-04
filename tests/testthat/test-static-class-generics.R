skip_on_cran()

tiny_static_xy_generics <- function(n = 16L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.2, -0.15) + stats::rnorm(n, sd = 0.12))
  list(X = X, y = y)
}

test_that("exalStaticMCMC generics dispatch and return stable outputs", {
  set.seed(601)
  dat <- tiny_static_xy_generics(16)

  fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    verbose = FALSE
  )

  expect_true(is.exalStaticMCMC(fit))
  expect_s3_class(fit, "exalStaticMCMC")
  expect_output(print(fit), "Bayesian Linear Quantile Regression")
  expect_output(summary(fit), "Posterior mean sigma")
  expect_true(!is.null(fit$X))
  expect_true(!is.null(fit$y))

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(fit, cr.percent = 0.9))
})

test_that("exalStaticLDVB generics dispatch and enforce plot X contract", {
  set.seed(602)
  dat <- tiny_static_xy_generics(18)

  fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 40,
    tol = 5e-3,
    n_samp_xi = 60,
    verbose = FALSE
  )

  expect_true(is.exalStaticLDVB(fit))
  expect_s3_class(fit, "exalStaticLDVB")
  expect_output(print(fit), "Bayesian Linear Quantile Regression")
  expect_output(summary(fit), "Posterior mean sigma")
  expect_true(!is.null(fit$X))
  expect_true(!is.null(fit$y))

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(fit, cr.percent = 0.9))
})
