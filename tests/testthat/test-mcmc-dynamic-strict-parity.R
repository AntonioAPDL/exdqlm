# Strict mode keeps the legacy R FFBS path. The current dynamic MCMC stack still
# relies on C++ GIG draws, which are not bitwise reproducible across identical
# reruns, so this file checks routing/contract stability rather than exact
# sample identity.

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
      init.from.vb = FALSE,
      verbose = FALSE
    )
  }

  list(r_ref = run_one(FALSE), strict_cpp = run_one(TRUE))
}

test_that("strict mode preserves the R-routing contract for exDQLM", {
  fits <- run_mcmc_strict_pair(dqlm = FALSE)
  r_ref <- fits$r_ref
  strict_cpp <- fits$strict_cpp

  expect_equal(r_ref$backend$mcmc, "R")
  expect_equal(r_ref$backend$mode, "strict")
  expect_equal(strict_cpp$backend$mcmc, "R")
  expect_equal(strict_cpp$backend$mode, "strict")
  expect_equal(strict_cpp$backend$gig, r_ref$backend$gig)

  expect_identical(sort(names(strict_cpp)), sort(names(r_ref)))
  expect_equal(length(as.numeric(strict_cpp$samp.theta)), length(as.numeric(r_ref$samp.theta)))
  expect_equal(length(as.numeric(strict_cpp$samp.vts)), length(as.numeric(r_ref$samp.vts)))
  expect_equal(length(as.numeric(strict_cpp$samp.sts)), length(as.numeric(r_ref$samp.sts)))
  expect_equal(length(as.numeric(strict_cpp$samp.sigma)), length(as.numeric(r_ref$samp.sigma)))
  expect_equal(length(as.numeric(strict_cpp$samp.gamma)), length(as.numeric(r_ref$samp.gamma)))
  expect_equal(length(as.numeric(strict_cpp$samp.post.pred)), length(as.numeric(r_ref$samp.post.pred)))

  expect_true(all(is.finite(as.numeric(strict_cpp$samp.theta))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.vts))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.sts))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.sigma))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.gamma))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.post.pred))))

  expect_equal(as.numeric(strict_cpp$samp.sigma), rep(1, length(as.numeric(strict_cpp$samp.sigma))), tolerance = 0)
  expect_equal(as.numeric(strict_cpp$samp.gamma), rep(0, length(as.numeric(strict_cpp$samp.gamma))), tolerance = 0)
  expect_null(strict_cpp$accept.rate)
  expect_null(strict_cpp$accept.rate.burn)
  expect_null(strict_cpp$accept.rate.keep)
  expect_false(isTRUE(strict_cpp$init.from.vb))
})

test_that("strict mode preserves the R-routing contract for dQLM", {
  fits <- run_mcmc_strict_pair(dqlm = TRUE)
  r_ref <- fits$r_ref
  strict_cpp <- fits$strict_cpp

  expect_equal(r_ref$backend$mcmc, "R")
  expect_equal(r_ref$backend$mode, "strict")
  expect_equal(strict_cpp$backend$mcmc, "R")
  expect_equal(strict_cpp$backend$mode, "strict")
  expect_equal(strict_cpp$backend$gig, r_ref$backend$gig)

  expect_identical(sort(names(strict_cpp)), sort(names(r_ref)))
  expect_equal(length(as.numeric(strict_cpp$samp.theta)), length(as.numeric(r_ref$samp.theta)))
  expect_equal(length(as.numeric(strict_cpp$samp.vts)), length(as.numeric(r_ref$samp.vts)))
  expect_equal(length(as.numeric(strict_cpp$samp.sigma)), length(as.numeric(r_ref$samp.sigma)))
  expect_equal(length(as.numeric(strict_cpp$samp.post.pred)), length(as.numeric(r_ref$samp.post.pred)))

  expect_true(all(is.finite(as.numeric(strict_cpp$samp.theta))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.vts))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.sigma))))
  expect_true(all(is.finite(as.numeric(strict_cpp$samp.post.pred))))

  expect_equal(as.numeric(strict_cpp$samp.sigma), rep(1, length(as.numeric(strict_cpp$samp.sigma))), tolerance = 0)
  expect_false(isTRUE(strict_cpp$init.from.vb))
})
