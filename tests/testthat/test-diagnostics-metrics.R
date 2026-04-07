test_that("dynamic diagnostics expose flipped KL and CRPS metrics", {
  set.seed(20260406)
  TT <- 12
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 20L
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    dqlm.ind = TRUE, fix.sigma = FALSE,
    tol = 0.05, n.samp = 12, verbose = FALSE
  )
  diags <- exdqlmDiagnostics(fit, fit, plot = FALSE, ref = stats::rnorm(TT))

  expect_true(all(c("m1.KL.flip", "m1.CRPS", "m2.KL.flip", "m2.CRPS") %in% names(diags)))
  expect_true(all(is.finite(c(
    diags$m1.KL, diags$m1.KL.flip, diags$m1.CRPS,
    diags$m2.KL, diags$m2.KL.flip, diags$m2.CRPS
  ))))
})
