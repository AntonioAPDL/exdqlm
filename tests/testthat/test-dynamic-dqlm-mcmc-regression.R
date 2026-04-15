test_that("dynamic dqlm MCMC FFBS sampler stays finite on near-singular state covariances", {
  skip_if_not_installed("withr")

  TT <- 12L
  GG <- array(0, dim = c(2L, 2L, TT))
  for (t in seq_len(TT)) {
    GG[, , t] <- matrix(c(1, 0.2 * t, 0, 1), 2, 2)
  }
  FF <- rbind(rep(1, TT), rep(0, TT))
  model <- as.exdqlm(list(
    m0 = c(0, 0),
    C0 = matrix(c(1, 0, 0, 0), 2, 2),
    GG = GG,
    FF = FF
  ))

  y <- rep(0, TT)

  withr::local_options(list(
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.cpp_mcmc_mode = "strict"
  ))
  set.seed(20260415)

  fit <- exdqlmMCMC(
    y = y,
    p0 = 0.05,
    model = model,
    df = c(0.98, 0.98),
    dim.df = c(1L, 1L),
    dqlm.ind = TRUE,
    fix.sigma = TRUE,
    sig.init = 1,
    init.from.vb = FALSE,
    init.from.isvb = FALSE,
    n.burn = 1,
    n.mcmc = 1,
    verbose = FALSE
  )

  expect_true(all(is.finite(as.numeric(fit$samp.theta))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(fit$theta.out$sm)))
  expect_true(all(is.finite(fit$map.standard.forecast.errors)))
})
