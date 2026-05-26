tiny_transfer_base_model <- function(TT) {
  exdqlm::as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))
}

normalize_test_X <- function(X, TT) {
  X <- as.matrix(X)
  if (nrow(X) != TT) {
    if (ncol(X) == TT) {
      X <- t(X)
    } else {
      stop("X must have TT rows in test helper")
    }
  }
  X
}

normalize_test_tf_df <- function(tf.df, k) {
  tf.df <- as.numeric(tf.df)
  if (length(tf.df) == 1L) {
    list(tf.df = c(tf.df, tf.df), tf.dim.df = c(1L, k))
  } else if (length(tf.df) == 2L) {
    list(tf.df = tf.df, tf.dim.df = c(1L, k))
  } else if (length(tf.df) == (k + 1L)) {
    list(tf.df = tf.df, tf.dim.df = rep(1L, k + 1L))
  } else {
    stop("invalid tf.df length in test helper")
  }
}

manual_transfer_augmented <- function(model, X, lam, tf.m0 = NULL, tf.C0 = NULL) {
  TT <- if (is.null(dim(X))) length(X) else max(dim(X))
  X <- normalize_test_X(X, TT)
  k <- ncol(X)
  temp.p <- length(model$m0)
  zeta_idx <- temp.p + 1L
  psi_idx <- seq.int(temp.p + 2L, temp.p + k + 1L)
  p_aug <- temp.p + k + 1L

  if (is.null(tf.m0)) tf.m0 <- rep(0, k + 1L)
  if (is.null(tf.C0)) tf.C0 <- diag(1, k + 1L)

  FF <- matrix(0, p_aug, TT)
  FF[1:temp.p, ] <- model$FF
  FF[zeta_idx, ] <- 1

  GG <- array(0, c(p_aug, p_aug, TT))
  GG[1:temp.p, 1:temp.p, ] <- model$GG
  GG[zeta_idx, zeta_idx, ] <- lam
  for (j in seq_len(k)) {
    GG[zeta_idx, psi_idx[j], ] <- X[, j]
    GG[psi_idx[j], psi_idx[j], ] <- 1
  }

  exdqlm::as.exdqlm(list(
    GG = GG,
    FF = FF,
    m0 = c(model$m0, tf.m0),
    C0 = magic::adiag(model$C0, tf.C0)
  ))
}

manual_transfer_median_kt <- function(fit, X, lam, threshold = 1e-3) {
  X <- normalize_test_X(X, length(fit$y))
  TT <- nrow(X)
  k <- ncol(X)
  sm <- fit$theta.out$sm
  p_aug <- dim(sm)[1]
  psi_idx <- seq.int(p_aug - k + 1L, p_aug)

  psi_prev <- matrix(NA_real_, nrow = TT, ncol = k)
  psi_prev[1, ] <- fit$model$m0[psi_idx]
  if (TT > 1L) {
    psi_prev[2:TT, ] <- t(sm[psi_idx, seq_len(TT - 1L), drop = FALSE])
  }

  agg_effect <- abs(rowSums(X * psi_prev))
  k_seq <- numeric(TT)
  idx <- agg_effect > threshold
  k_seq[idx] <- (log(threshold) - log(agg_effect[idx])) / log(lam)
  stats::median(k_seq, na.rm = TRUE)
}

test_that("transfer-function MCMC wrapper matches direct augmented model contract for k=1", {
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
  fit_wrap <- exdqlm::exdqlmTransferMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = lam, tf.df = 0.98,
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  set.seed(20260412)
  fit_direct <- exdqlm::exdqlmMCMC(
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
  expect_equal(fit_wrap$transfer_input_names, "X1")
  expect_true(is.finite(fit_wrap$median.kt))
  expect_equal(fit_wrap$median.kt, manual_transfer_median_kt(fit_wrap, X = X, lam = lam))
})

test_that("transfer-function wrappers support multivariate X with block tf.df semantics", {
  TT <- 20
  y <- ts(stats::rnorm(TT, sd = 0.2))
  X <- cbind(
    rain = stats::rnorm(TT, sd = 0.25),
    soil = stats::rnorm(TT, sd = 0.15)
  )
  lam <- 0.55
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

  set.seed(20260421)
  fit_wrap <- exdqlm::exdqlmTransferMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = lam, tf.df = c(0.97, 0.95),
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  set.seed(20260421)
  fit_direct <- exdqlm::exdqlmMCMC(
    y = y, p0 = 0.5, model = direct_model,
    df = c(1, 0.97, 0.95), dim.df = c(1, 1, 2),
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  expect_equal(fit_wrap$df, c(1, 0.97, 0.95))
  expect_equal(fit_wrap$dim.df, c(1, 1, 2))
  expect_equal(fit_wrap$model$GG, fit_direct$model$GG)
  expect_equal(fit_wrap$model$FF, fit_direct$model$FF)
  expect_equal(dim(fit_wrap$model$GG), c(4, 4, TT))
  expect_equal(dim(fit_wrap$model$FF), c(4, TT))
  expect_equal(fit_wrap$transfer_input_names, c("rain", "soil"))
  expect_true(is.finite(fit_wrap$median.kt))
  expect_equal(fit_wrap$median.kt, manual_transfer_median_kt(fit_wrap, X = X, lam = lam))
})

test_that("transfer-function wrappers support componentwise tf.df and full exDQLM path", {
  TT <- 18
  y <- ts(stats::rnorm(TT, sd = 0.3))
  X <- cbind(
    rain = stats::rnorm(TT),
    soil = stats::rnorm(TT, sd = 0.8)
  )
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

  set.seed(20260422)
  fit_mcmc <- exdqlm::exdqlmTransferMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.5, tf.df = c(0.97, 0.96, 0.95),
    fix.sigma = FALSE,
    n.burn = 8, n.mcmc = 8,
    init.from.vb = TRUE,
    vb_init_controls = list(method = "ldvb", tol = 0.2, n.samp = 20, max_iter = 8, verbose = FALSE),
    verbose = FALSE
  )

  expect_equal(fit_mcmc$df, c(1, 0.97, 0.96, 0.95))
  expect_equal(fit_mcmc$dim.df, c(1, 1, 1, 1))
  expect_true(all(is.finite(as.numeric(fit_mcmc$samp.gamma))))
  expect_true(all(is.finite(as.numeric(fit_mcmc$samp.sigma))))
  expect_identical(fit_mcmc$mh.diagnostics$proposal, "slice")
  expect_true(is.finite(fit_mcmc$median.kt))

  set.seed(20260423)
  fit_ldvb <- exdqlm::exdqlmTransferLDVB(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.5, tf.df = c(0.97, 0.96, 0.95),
    fix.sigma = TRUE, sig.init = 1,
    dqlm.ind = TRUE,
    tol = 0.2, n.samp = 10,
    verbose = FALSE
  )
  expect_equal(fit_ldvb$df, c(1, 0.97, 0.96, 0.95))
  expect_equal(fit_ldvb$dim.df, c(1, 1, 1, 1))
  expect_true(is.finite(fit_ldvb$median.kt))
  expect_equal(fit_ldvb$transfer_input_names, c("rain", "soil"))

  set.seed(20260424)
  fit_isvb <- exdqlm::exdqlmTransferISVB(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.5, tf.df = c(0.97, 0.96, 0.95),
    fix.sigma = TRUE, sig.init = 1,
    dqlm.ind = TRUE,
    tol = 0.2, n.IS = 60, n.samp = 10,
    verbose = FALSE
  )
  expect_equal(fit_isvb$df, c(1, 0.97, 0.96, 0.95))
  expect_equal(fit_isvb$dim.df, c(1, 1, 1, 1))
  expect_true(is.finite(fit_isvb$median.kt))
})

test_that("transfer-function MCMC output with multivariate X works with downstream methods", {
  TT <- 20
  y <- ts(stats::rnorm(TT, sd = 0.2))
  X <- cbind(
    rain = stats::rnorm(TT, sd = 0.25),
    soil = stats::rnorm(TT, sd = 0.15)
  )
  model <- tiny_transfer_base_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.compute_elbo = TRUE
  )
  on.exit(options(old_opts), add = TRUE)

  set.seed(20260425)
  fit <- exdqlm::exdqlmTransferMCMC(
    y = y, p0 = 0.5, model = model, X = X,
    df = 1, dim.df = 1,
    lam = 0.55, tf.df = c(0.97, 0.95),
    dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
    n.burn = 5, n.mcmc = 8,
    init.from.vb = FALSE,
    verbose = FALSE
  )

  fc <- exdqlm::exdqlmForecast(start.t = 15, k = 3, m1 = fit, plot = FALSE)
  expect_s3_class(fc, "exdqlmForecast")
  expect_identical(fc$k, 3)
  expect_equal(dim(fc$fa), c(length(fit$model$m0), 3))

  di <- exdqlm::exdqlmDiagnostics(fit, plot = FALSE, kl_k = 3L)
  expect_true(is.finite(di$m1.KL))
  expect_true(is.finite(di$m1.CRPS))
  expect_true(is.finite(di$m1.pplc))

  tf <- tempfile(fileext = ".pdf")
  grDevices::pdf(tf)
  on.exit({
    if (grDevices::dev.cur() > 1L) grDevices::dev.off()
    unlink(tf)
  }, add = TRUE)

  qplot <- exdqlm::exdqlmPlot(fit, add = FALSE, col = "blue")
  cplot <- exdqlm::compPlot(fit, index = 1, add = FALSE, col = "red", just.theta = TRUE)
  expect_length(qplot$map.quant, TT)
  expect_length(cplot$map.comp, TT)
  expect_length(qplot$x, TT)
  expect_length(cplot$x, TT)

  qsummary <- exdqlm::exdqlmPlot(fit, plot = FALSE)
  csummary <- exdqlm::compPlot(fit, index = 1, just.theta = TRUE, plot = FALSE)
  expect_named(qsummary, c("map.quant", "lb.quant", "ub.quant", "x"))
  expect_named(csummary, c("map.comp", "lb.comp", "ub.comp", "x"))
  expect_equal(qsummary$map.quant, qplot$map.quant)
  expect_equal(csummary$map.comp, cplot$map.comp)

  graphics::plot(qsummary$x, qsummary$map.quant, type = "n",
                 xlim = range(qsummary$x), ylim = range(qsummary$lb.quant, qsummary$ub.quant))
  expect_silent(exdqlm::exdqlmPlot(fit, add = TRUE, col = "black",
                                   xlim = range(qsummary$x),
                                   ylim = range(qsummary$lb.quant, qsummary$ub.quant),
                                   xlab = "custom x", ylab = "custom y",
                                   lwd = 1, lwd.interval = 0.5))
  expect_silent(exdqlm::compPlot(fit, index = 1, add = TRUE, col = "orange",
                                 just.theta = TRUE, xlim = range(csummary$x),
                                 ylim = range(csummary$lb.comp, csummary$ub.comp),
                                 xlab = "custom x", ylab = "custom y",
                                 lwd = 1, lwd.interval = 0.5))
})
