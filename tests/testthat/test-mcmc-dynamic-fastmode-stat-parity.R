skip_on_cran()

# Fast mode uses C++ FFBS. Compare summary behavior vs R baseline.

run_mcmc_fast_compare <- function(dqlm = FALSE) {
  model <- as.exdqlm(list(m0 = 0, C0 = matrix(1, 1, 1), FF = 1, GG = 1))
  y <- c(0.12, -0.08, 0.15, -0.03, 0.11, 0.02, -0.01, 0.05)

  run_one <- function(use_cpp_mcmc, mode) {
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
      n.burn = 10,
      n.mcmc = 40,
      init.from.isvb = FALSE,
      init.from.vb = FALSE,
      verbose = FALSE
    )
  }

  list(
    r_ref = run_one(FALSE, "strict"),
    cpp_fast = run_one(TRUE, "fast")
  )
}

test_that("fast mode exDQLM stays statistically close to R baseline", {
  fits <- run_mcmc_fast_compare(dqlm = FALSE)
  r_ref <- fits$r_ref
  cpp_fast <- fits$cpp_fast

  expect_equal(cpp_fast$backend$mcmc, "C++")
  expect_equal(cpp_fast$backend$mode, "fast")

  th_r <- as.numeric(r_ref$samp.theta)
  th_c <- as.numeric(cpp_fast$samp.theta)
  expect_true(all(is.finite(th_c)))
  expect_lt(abs(mean(th_r) - mean(th_c)), 0.75)
  expect_lt(abs(stats::sd(th_r) - stats::sd(th_c)), 0.75)

  pp_r <- as.numeric(r_ref$samp.post.pred)
  pp_c <- as.numeric(cpp_fast$samp.post.pred)
  expect_true(all(is.finite(pp_c)))
  expect_lt(abs(stats::median(pp_r) - stats::median(pp_c)), 1.0)
})

test_that("fast mode dQLM stays statistically close to R baseline", {
  fits <- run_mcmc_fast_compare(dqlm = TRUE)
  r_ref <- fits$r_ref
  cpp_fast <- fits$cpp_fast

  expect_equal(cpp_fast$backend$mcmc, "C++")
  expect_equal(cpp_fast$backend$mode, "fast")

  th_r <- as.numeric(r_ref$samp.theta)
  th_c <- as.numeric(cpp_fast$samp.theta)
  expect_true(all(is.finite(th_c)))
  expect_lt(abs(mean(th_r) - mean(th_c)), 0.75)
  expect_lt(abs(stats::sd(th_r) - stats::sd(th_c)), 0.75)

  pp_r <- as.numeric(r_ref$samp.post.pred)
  pp_c <- as.numeric(cpp_fast$samp.post.pred)
  expect_true(all(is.finite(pp_c)))
  expect_lt(abs(stats::median(pp_r) - stats::median(pp_c)), 1.0)
})
