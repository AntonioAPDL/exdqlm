tiny_static_xy_generics <- function(n = 16L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.2, -0.15) + stats::rnorm(n, sd = 0.12))
  list(X = X, y = y)
}

test_that("exal_mcmc generics dispatch and return stable outputs", {
  set.seed(601)
  dat <- tiny_static_xy_generics(16)

  fit <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    mh.proposal = "slice",
    verbose = FALSE
  )

  expect_true(is.exal_mcmc(fit))
  expect_s3_class(fit, "exal_mcmc")
  expect_output(print(fit), "Static Quantile Regression")
  expect_output(summary(fit), "Posterior mean sigma")

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(fit, cr.percent = 0.9))
})

test_that("exal_ldvb generics dispatch and enforce plot X contract", {
  set.seed(602)
  dat <- tiny_static_xy_generics(18)

  fit <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    max_iter = 40,
    tol = 5e-3,
    n_samp_xi = 60,
    verbose = FALSE
  )

  expect_true(is.exal_ldvb(fit))
  expect_s3_class(fit, "exal_ldvb")
  expect_output(print(fit), "Static Quantile Regression")
  expect_output(summary(fit), "Posterior mean sigma")
  expect_error(plot(fit), "requires design matrix X")

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(fit, X = dat$X, cr.percent = 0.9))
})
