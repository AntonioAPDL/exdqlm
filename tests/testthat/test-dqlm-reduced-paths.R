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
  expect_s3_class(fit, "exdqlmFit")
  expect_true(is.exdqlmFit(fit))
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
  expect_s3_class(fit, "exdqlmFit")
  expect_true(is.exdqlmFit(fit))
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
  fc_draws_1 <- exdqlmForecast(start.t = 3, k = 1, m1 = fit, plot = FALSE,
                               return.draws = TRUE, n.samp = 5, seed = 123)
  fc_draws_2 <- exdqlmForecast(start.t = 3, k = 1, m1 = fit, plot = FALSE,
                               return.draws = TRUE, n.samp = 5, seed = 123)
  expect_equal(dim(fc_draws_1$samp.fore), c(1L, 5L))
  expect_true(all(is.finite(fc_draws_1$samp.fore)))
  expect_equal(fc_draws_1$samp.fore, fc_draws_2$samp.fore, tolerance = 1e-12)

  future_k <- 6L
  future_FF <- matrix(1, nrow = 1L, ncol = future_k)
  future_GG <- array(1, dim = c(1L, 1L, future_k))
  fc_future <- exdqlmForecast(
    start.t = length(y), k = future_k, m1 = fit,
    fFF = future_FF, fGG = future_GG, plot = FALSE,
    return.draws = TRUE, n.samp = 5, seed = 123
  )
  expect_s3_class(fc_future, "exdqlmForecast")
  expect_equal(dim(fc_future$fR), c(1L, 1L, future_k))
  expect_equal(length(fc_future$ff), future_k)
  expect_equal(length(fc_future$fQ), future_k)
  expect_equal(dim(fc_future$samp.fore), c(future_k, 5L))
  expect_true(all(is.finite(fc_future$ff)))
  expect_true(all(is.finite(fc_future$fQ)))
  expect_true(all(is.finite(fc_future$samp.fore)))

  fc_constant_GG <- exdqlmForecast(
    start.t = length(y), k = future_k, m1 = fit,
    fFF = future_FF, fGG = matrix(1, 1L, 1L), plot = FALSE
  )
  expect_equal(dim(fc_constant_GG$fR), c(1L, 1L, future_k))
  expect_equal(length(fc_constant_GG$ff), future_k)
  expect_error(
    exdqlmForecast(
      start.t = length(y), k = future_k, m1 = fit,
      fFF = future_FF, fGG = array(1, dim = c(1L, 1L, future_k - 1L)),
      plot = FALSE
    ),
    "depth k"
  )
})

test_that("dynamic MCMC fits inherit from the shared exdqlmFit family", {
  set.seed(20260303)
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.1, -0.2, 0.05, 0.15)

  fit <- exdqlmMCMC(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE,
    fix.sigma = TRUE,
    sig.init = 1,
    n.burn = 2,
    n.mcmc = 3,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  expect_s3_class(fit, "exdqlmMCMC")
  expect_s3_class(fit, "exdqlmFit")
  expect_true(is.exdqlmFit(fit))
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
  expect_s3_class(fit, "exalStaticFit")
  expect_true(is.exalStaticFit(fit))
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

  expect_s3_class(fit, "exalStaticLDVB")
  expect_s3_class(fit, "exalStaticFit")
  expect_true(is.exalStaticFit(fit))
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
