test_that("regMod returns exdqlm-compatible structure", {
  X <- cbind(1, seq(-1, 1, length.out = 6))

  mod <- regMod(X)

  expect_s3_class(mod, "exdqlm")
  expect_equal(dim(mod$FF), c(2, 6))
  expect_equal(dim(mod$GG), c(2, 2))
  expect_equal(length(mod$m0), 2)
  expect_equal(dim(mod$C0), c(2, 2))

  checked <- check_mod(mod)
  expect_s3_class(checked, "exdqlm")
})

test_that("exal_static_LDVB runs on tiny deterministic input", {
  set.seed(123)
  n <- 12
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.25, -0.15)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.1))

  fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 20,
    tol = 1e-2,
    n_samp_xi = 40,
    verbose = FALSE
  )

  expect_true(is.list(fit))
  expect_true(is.numeric(fit$qbeta$m))
  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(is.finite(fit$qsiggam$sigma_mean))
  expect_true(is.finite(fit$qsiggam$gamma_mean))
})

test_that("exal_static_mcmc runs on tiny deterministic input", {
  set.seed(321)
  n <- 10
  X <- cbind(1, seq(-0.5, 0.5, length.out = n))
  beta <- c(0.1, 0.2)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.15))

  fit <- exal_static_mcmc(
    y = y,
    X = X,
    p0 = 0.5,
    n.burn = 8,
    n.mcmc = 12,
    thin = 1,
    verbose = FALSE
  )

  expect_true(is.list(fit))
  expect_true(all(is.finite(as.numeric(fit$samp.beta))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit$samp.gamma))))
})
