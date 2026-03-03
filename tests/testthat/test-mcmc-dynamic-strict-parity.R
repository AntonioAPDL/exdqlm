# Strict mode parity checks: cpp routing should preserve legacy R behavior.

run_mcmc_strict_pair <- function(dqlm = FALSE) {
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.12, -0.08, 0.15, -0.03, 0.11)

  run_one <- function(use_cpp_mcmc) {
    old_opts <- options(
      exdqlm.use_cpp_mcmc = use_cpp_mcmc,
      exdqlm.cpp_mcmc_mode = "strict",
      exdqlm.use_cpp_kf = FALSE,
      exdqlm.use_cpp_samplers = FALSE,
      exdqlm.use_cpp_postpred = FALSE
    )
    on.exit(options(old_opts), add = TRUE)

    set.seed(20260302)
    exdqlmMCMC(
      y = y,
      p0 = 0.5,
      model = model,
      df = 1,
      dim.df = 1,
      dqlm.ind = dqlm,
      fix.gamma = TRUE,
      gam.init = 0,
      fix.sigma = TRUE,
      sig.init = 1,
      Sig.mh = diag(c(0.005, 0.005)),
      n.burn = 3,
      n.mcmc = 8,
      init.from.isvb = FALSE,
      verbose = FALSE
    )
  }

  list(r_ref = run_one(FALSE), strict_cpp = run_one(TRUE))
}

test_that("strict mode matches R reference for exDQLM", {
  fits <- run_mcmc_strict_pair(dqlm = FALSE)
  r_ref <- fits$r_ref
  strict_cpp <- fits$strict_cpp

  expect_equal(strict_cpp$backend$mcmc, "R")
  expect_equal(strict_cpp$backend$mode, "strict")

  expect_equal(as.numeric(r_ref$samp.theta), as.numeric(strict_cpp$samp.theta), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.vts), as.numeric(strict_cpp$samp.vts), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.sts), as.numeric(strict_cpp$samp.sts), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.sigma), as.numeric(strict_cpp$samp.sigma), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.gamma), as.numeric(strict_cpp$samp.gamma), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.post.pred), as.numeric(strict_cpp$samp.post.pred), tolerance = 0)
  expect_equal(r_ref$accept.rate, strict_cpp$accept.rate, tolerance = 0)
})

test_that("strict mode matches R reference for dQLM", {
  fits <- run_mcmc_strict_pair(dqlm = TRUE)
  r_ref <- fits$r_ref
  strict_cpp <- fits$strict_cpp

  expect_equal(strict_cpp$backend$mcmc, "R")
  expect_equal(strict_cpp$backend$mode, "strict")

  expect_equal(as.numeric(r_ref$samp.theta), as.numeric(strict_cpp$samp.theta), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.vts), as.numeric(strict_cpp$samp.vts), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.sigma), as.numeric(strict_cpp$samp.sigma), tolerance = 0)
  expect_equal(as.numeric(r_ref$samp.post.pred), as.numeric(strict_cpp$samp.post.pred), tolerance = 0)
})

