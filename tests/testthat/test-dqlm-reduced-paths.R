test_that("dynamic ISVB reduced DQLM path returns conjugate outputs", {
  set.seed(20260303)
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.1, -0.2, 0.05, 0.15)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmISVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE,
    fix.sigma = FALSE,
    n.samp = 8,
    tol = 1e-3,
    verbose = FALSE
  )

  expect_s3_class(fit, "exdqlmISVB")
  expect_true(isTRUE(fit$dqlm.ind))
  expect_null(fit$samp.gamma)
  expect_null(fit$samp.sts)
  expect_true(is.list(fit$sig.out))
  expect_true(all(is.finite(fit$sig.out$E.sigma)))
  expect_true(all(is.finite(fit$vts.out$E.uts)))
  expect_true(length(fit$diagnostics$elbo) >= 1)
  expect_true(all(is.finite(fit$diagnostics$elbo)))
})

test_that("dynamic LDVB reduced DQLM path skips LD gamma-sigma block", {
  set.seed(20260303)
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(-0.1, 0.2, 0.0, -0.05)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE,
    fix.sigma = FALSE,
    n.samp = 8,
    tol = 1e-3,
    verbose = FALSE
  )

  expect_s3_class(fit, "exdqlmLDVB")
  expect_true(isTRUE(fit$dqlm.ind))
  expect_null(fit$samp.gamma)
  expect_null(fit$samp.sts)
  expect_true(is.list(fit$sig.out))
  expect_true(all(is.finite(fit$sig.out$E.sigma)))
  expect_true(length(fit$diagnostics$elbo) >= 1)
  expect_true(all(is.finite(fit$diagnostics$elbo)))
  fc <- exdqlmForecast(start.t = 3, k = 1, m1 = fit, plot = FALSE)
  expect_s3_class(fc, "exdqlmForecast")
  expect_true(all(is.finite(fc$ff)))
})

test_that("static MCMC reduced DQLM path excludes gamma/s latent block", {
  set.seed(20260303)
  n <- 12
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.2, -0.1) + rnorm(n, sd = 0.1))

  fit <- exalStaticMCMC(
    y = y, X = X, p0 = 0.5,
    dqlm.ind = TRUE,
    n.burn = 6, n.mcmc = 10, thin = 1,
    verbose = FALSE
  )

  expect_s3_class(fit, "exalStaticMCMC")
  expect_true(isTRUE(fit$dqlm.ind))
  expect_false("samp.gamma" %in% names(fit))
  expect_false("samp.s" %in% names(fit))
  expect_true(all(is.finite(as.numeric(fit$samp.beta))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit$samp.v))))
})

test_that("static LDVB reduced DQLM path returns q(beta) q(v) q(sigma)", {
  set.seed(20260303)
  n <- 15
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.3, 0.2) + rnorm(n, sd = 0.12))

  fit <- exalStaticLDVB(
    y = y, X = X, p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 80, tol = 1e-3,
    verbose = FALSE
  )

  expect_s3_class(fit, "exal_vb")
  expect_true(isTRUE(fit$dqlm.ind))
  expect_true(is.list(fit$qbeta))
  expect_true(is.list(fit$qv))
  expect_true(is.list(fit$qsig))
  expect_null(fit$qsiggam)
  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(all(is.finite(fit$qv$E_v)))
  expect_true(all(is.finite(fit$qsig$E_sigma)))
  expect_true(length(fit$misc$elbo) >= 1)
  expect_true(all(is.finite(fit$misc$elbo)))
})
