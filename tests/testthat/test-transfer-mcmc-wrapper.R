tiny_transfer_base_model <- function(TT) {
  as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))
}

manual_transfer_augmented <- function(model, X, lam, tf.m0 = rep(0, 2), tf.C0 = diag(1, 2)) {
  TT <- length(X)
  temp.p <- length(model$m0)
  p_aug <- temp.p + 2L

  FF <- matrix(0, p_aug, TT)
  FF[1:temp.p, ] <- model$FF
  FF[seq(temp.p + 1L, temp.p + 2L, 2L), ] <- 1

  GG <- array(0, c(p_aug, p_aug, TT))
  GG[1:temp.p, 1:temp.p, ] <- model$GG
  GG[(temp.p + 1L):(temp.p + 2L), (temp.p + 1L):(temp.p + 2L), ] <- matrix(c(lam, 0, NA, 1), 2, 2)
  GG[temp.p + 1L, temp.p + 2L, ] <- X

  as.exdqlm(list(
    GG = GG,
    FF = FF,
    m0 = c(model$m0, tf.m0),
    C0 = magic::adiag(model$C0, tf.C0)
  ))
}

test_that("transfer-function MCMC wrapper matches direct augmented model contract", {
  TT <- 18
  y <- ts(stats::rnorm(TT, sd = 0.2))
  X <- ts(stats::rnorm(TT, sd = 0.3))
  lam <- 0.6
  model <- tiny_transfer_base_model(TT)
  direct_model <- manual_transfer_augmented(model, X, lam = lam)

  old_opts <- options(
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.compute_elbo = TRUE
  )
  on.exit(options(old_opts), add = TRUE)

  set.seed(20260412)
  fit_wrap <- transfn_exdqlmMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = lam, tf.df = 0.98,
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  set.seed(20260412)
  fit_direct <- exdqlmMCMC(
    y = y, p0 = 0.5, model = direct_model,
    df = c(1, 0.98, 0.98), dim.df = c(1, 1, 1),
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  expect_s3_class(fit_wrap, "exdqlmMCMC")
  expect_equal(fit_wrap$df, c(1, 0.98, 0.98))
  expect_equal(fit_wrap$dim.df, c(1, 1, 1))
  expect_equal(fit_wrap$model$GG, fit_direct$model$GG)
  expect_equal(fit_wrap$model$FF, fit_direct$model$FF)
  expect_equal(fit_wrap$model$m0, fit_direct$model$m0)
  expect_equal(fit_wrap$model$C0, fit_direct$model$C0)
  expect_equal(fit_wrap$backend, fit_direct$backend)
  expect_equal(dim(fit_wrap$samp.theta), dim(fit_direct$samp.theta))
  expect_equal(dim(fit_wrap$samp.post.pred), dim(fit_direct$samp.post.pred))
  expect_equal(dim(fit_wrap$theta.out$sm), dim(fit_direct$theta.out$sm))
  expect_equal(dim(fit_wrap$theta.out$fm), dim(fit_direct$theta.out$fm))
  expect_equal(fit_wrap$n.burn, fit_direct$n.burn)
  expect_equal(fit_wrap$n.mcmc, fit_direct$n.mcmc)
  expect_equal(fit_wrap$lam, lam)
  expect_true(is.finite(fit_wrap$median.kt))
})

test_that("transfer-function MCMC output works with downstream methods", {
  TT <- 20
  y <- ts(stats::rnorm(TT, sd = 0.2))
  X <- ts(stats::rnorm(TT, sd = 0.25))
  model <- tiny_transfer_base_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.compute_elbo = TRUE
  )
  on.exit(options(old_opts), add = TRUE)

  set.seed(20260413)
  fit <- transfn_exdqlmMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.55, tf.df = c(0.97, 0.95),
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  fc <- exdqlmForecast(start.t = 15, k = 3, m1 = fit, plot = FALSE)
  expect_s3_class(fc, "exdqlmForecast")
  expect_length(fc$ff, 3)

  di <- exdqlmDiagnostics(fit, plot = FALSE, ref = stats::rnorm(TT))
  expect_true(is.finite(di$m1.KL))
  expect_true(is.finite(di$m1.CRPS))
  expect_true(is.finite(di$m1.pplc))

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit({
    if (grDevices::dev.cur() > 1L) grDevices::dev.off()
    unlink(tf)
  }, add = TRUE)

  qplot <- exdqlmPlot(fit, add = FALSE, col = "blue")
  cplot <- compPlot(fit, index = 1, add = FALSE, col = "red", just.theta = TRUE)
  expect_length(qplot$map.quant, TT)
  expect_length(cplot$map.comp, TT)
})

test_that("transfer-function MCMC supports full exDQLM path and shared tf.df handling", {
  TT <- 18
  y <- ts(stats::rnorm(TT, sd = 0.3))
  X <- ts(stats::rnorm(TT))
  model <- tiny_transfer_base_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 12L
  )
  on.exit(options(old_opts), add = TRUE)

  set.seed(20260414)
  fit_mcmc <- transfn_exdqlmMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.5, tf.df = 0.97,
    fix.sigma = FALSE,
    n.burn = 8, n.mcmc = 8,
    init.from.vb = TRUE,
    vb_init_controls = list(method = "ldvb", tol = 0.2, n.samp = 20, max_iter = 8, verbose = FALSE),
    verbose = FALSE
  )

  expect_equal(fit_mcmc$df, c(1, 0.97, 0.97))
  expect_true(all(is.finite(as.numeric(fit_mcmc$samp.gamma))))
  expect_true(all(is.finite(as.numeric(fit_mcmc$samp.sigma))))
  expect_identical(fit_mcmc$mh.diagnostics$proposal, "slice")
  expect_true(is.finite(fit_mcmc$median.kt))

  set.seed(20260415)
  fit_ldvb <- transfn_exdqlmLDVB(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.5, tf.df = 0.97,
    fix.sigma = TRUE, sig.init = 1,
    dqlm.ind = TRUE,
    tol = 0.2, n.samp = 10,
    verbose = FALSE
  )
  expect_equal(fit_ldvb$df, c(1, 0.97, 0.97))
  expect_true(is.finite(fit_ldvb$median.kt))

  set.seed(20260416)
  fit_isvb <- transfn_exdqlmISVB(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.5, tf.df = 0.97,
    fix.sigma = TRUE, sig.init = 1,
    dqlm.ind = TRUE,
    tol = 0.2, n.IS = 60, n.samp = 10,
    verbose = FALSE
  )
  expect_equal(fit_isvb$df, c(1, 0.97, 0.97))
  expect_true(is.finite(fit_isvb$median.kt))
})
