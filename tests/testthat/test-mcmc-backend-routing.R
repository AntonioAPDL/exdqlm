# Backend routing and strict/fast checks for exdqlmMCMC.

tiny_mcmc_model <- function() {
  as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = 1,
    GG = 1
  ))
}

run_mcmc_backend <- function(use_cpp_mcmc, mode, dqlm = FALSE) {
  old_opts <- options(
    exdqlm.use_cpp_mcmc = use_cpp_mcmc,
    exdqlm.cpp_mcmc_mode = mode,
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE
  )
  on.exit(options(old_opts), add = TRUE)

  set.seed(20260302)
  exdqlmMCMC(
    y = c(0.10, -0.15, 0.20, -0.05, 0.08),
    p0 = 0.5,
    model = tiny_mcmc_model(),
    df = 1,
    dim.df = 1,
    dqlm.ind = dqlm,
    fix.gamma = TRUE,
    gam.init = 0,
    fix.sigma = TRUE,
    sig.init = 1,
    Sig.mh = diag(c(0.005, 0.005)),
    n.burn = 3,
    n.mcmc = 6,
    init.from.isvb = FALSE,
    verbose = FALSE
  )
}

test_that("MCMC backend routing respects strict and fast modes", {
  fit_r <- run_mcmc_backend(use_cpp_mcmc = FALSE, mode = "strict", dqlm = FALSE)
  expect_equal(fit_r$backend$mcmc, "R")
  expect_equal(fit_r$backend$mode, "strict")

  fit_strict <- run_mcmc_backend(use_cpp_mcmc = TRUE, mode = "strict", dqlm = FALSE)
  expect_equal(fit_strict$backend$mcmc, "R")
  expect_equal(fit_strict$backend$mode, "strict")

  fit_fast <- run_mcmc_backend(use_cpp_mcmc = TRUE, mode = "fast", dqlm = FALSE)
  expect_equal(fit_fast$backend$mcmc, "C++")
  expect_equal(fit_fast$backend$mode, "fast")
})

test_that("Invalid MCMC mode falls back to strict", {
  old_opts <- options(
    exdqlm.use_cpp_mcmc = TRUE,
    exdqlm.cpp_mcmc_mode = "not-a-mode",
    exdqlm.use_cpp_kf = FALSE
  )
  on.exit(options(old_opts), add = TRUE)

  set.seed(1)
  expect_warning(
    fit <- exdqlmMCMC(
      y = c(0.1, -0.1, 0.2, 0.0),
      p0 = 0.5,
      model = tiny_mcmc_model(),
      df = 1,
      dim.df = 1,
      fix.gamma = TRUE,
      gam.init = 0,
      fix.sigma = TRUE,
      sig.init = 1,
      Sig.mh = diag(c(0.005, 0.005)),
      n.burn = 1,
      n.mcmc = 2,
      init.from.isvb = FALSE,
      verbose = FALSE
    )
  )
  expect_equal(fit$backend$mode, "strict")
  expect_equal(fit$backend$mcmc, "R")
})

