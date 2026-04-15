# Strict mode should preserve the R backend for dynamic MCMC paths.
# Draw-for-draw equality is not a stable invariant here because the dynamic
# sampling stack includes compiled samplers that do not guarantee identical
# sample streams across repeated runs, even when the backend remains "R".

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

expect_dynamic_mcmc_outputs_finite <- function(fit, dqlm, fix_gamma = TRUE) {
  expect_true(all(is.finite(as.numeric(fit$samp.theta))))
  expect_true(all(is.finite(as.numeric(fit$samp.vts))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit$samp.post.pred))))
  expect_equal(dim(fit$samp.theta), c(1L, 5L, 8L))
  expect_equal(dim(fit$samp.vts), c(5L, 8L))
  expect_length(as.numeric(fit$samp.sigma), 8L)
  expect_equal(dim(fit$samp.post.pred), c(5L, 8L))

  if (!dqlm && !fix_gamma) {
    expect_true(all(is.finite(as.numeric(fit$samp.gamma))))
    expect_true(all(is.finite(as.numeric(fit$samp.sts))))
    expect_length(as.numeric(fit$samp.gamma), 8L)
    expect_equal(dim(fit$samp.sts), c(5L, 8L))
  }
}

test_that("strict mode keeps dynamic exDQLM on the R backend with finite outputs", {
  fits <- run_mcmc_strict_pair(dqlm = FALSE)
  r_ref <- fits$r_ref
  strict_cpp <- fits$strict_cpp

  expect_equal(r_ref$backend$mcmc, "R")
  expect_equal(r_ref$backend$mode, "strict")
  expect_equal(strict_cpp$backend$mcmc, "R")
  expect_equal(strict_cpp$backend$mode, "strict")

  expect_dynamic_mcmc_outputs_finite(r_ref, dqlm = FALSE, fix_gamma = TRUE)
  expect_dynamic_mcmc_outputs_finite(strict_cpp, dqlm = FALSE, fix_gamma = TRUE)
})

test_that("strict mode keeps dynamic dQLM on the R backend with finite outputs", {
  fits <- run_mcmc_strict_pair(dqlm = TRUE)
  r_ref <- fits$r_ref
  strict_cpp <- fits$strict_cpp

  expect_equal(r_ref$backend$mcmc, "R")
  expect_equal(r_ref$backend$mode, "strict")
  expect_equal(strict_cpp$backend$mcmc, "R")
  expect_equal(strict_cpp$backend$mode, "strict")

  expect_dynamic_mcmc_outputs_finite(r_ref, dqlm = TRUE, fix_gamma = TRUE)
  expect_dynamic_mcmc_outputs_finite(strict_cpp, dqlm = TRUE, fix_gamma = TRUE)
})
