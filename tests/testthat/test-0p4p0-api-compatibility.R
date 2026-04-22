tiny_static_xy_0p4p0 <- function(n = 18L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.25, -0.2) + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

test_that("restored 0.4.0 API symbols are exported", {
  ns <- asNamespace("exdqlm")

  expect_true(exists("exalStaticLDVB", where = ns, inherits = FALSE))
  expect_true(exists("exalStaticMCMC", where = ns, inherits = FALSE))
  expect_true(exists("exalStaticDiagnostics", where = ns, inherits = FALSE))
  expect_true(exists("exdqlmTransferISVB", where = ns, inherits = FALSE))
  expect_true(exists("exdqlmTransferLDVB", where = ns, inherits = FALSE))
  expect_true(exists("exdqlmTransferMCMC", where = ns, inherits = FALSE))
  expect_true(exists("quantileSynthesis", where = ns, inherits = FALSE))
})

test_that("restored 0.4.0 static wrappers preserve alias classes and predicates", {
  set.seed(1401)
  dat <- tiny_static_xy_0p4p0()

  fit_vb <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 40,
    tol = 5e-3,
    n_samp_xi = 60,
    verbose = FALSE
  )

  expect_s3_class(fit_vb, "exal_ldvb")
  expect_true(inherits(fit_vb, "exalStaticLDVB"))
  expect_true(is.exalStaticLDVB(fit_vb))

  fit_mcmc <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    verbose = FALSE
  )

  expect_s3_class(fit_mcmc, "exal_mcmc")
  expect_true(inherits(fit_mcmc, "exalStaticMCMC"))
  expect_true(is.exalStaticMCMC(fit_mcmc))

  diag_out <- exalStaticDiagnostics(fit_vb, fit_mcmc, plot = FALSE)
  expect_true(inherits(diag_out, "exalStaticDiagnostic"))
  expect_true(is.exalStaticDiagnostic(diag_out))
})

test_that("quantileSynthesis remains a clean wrapper", {
  draws <- list(
    matrix(seq(1, 12), nrow = 4, ncol = 3),
    matrix(seq(2, 13), nrow = 4, ncol = 3)
  )

  syn_old <- exdqlm_synthesize_from_draws(
    draws_list = draws,
    p = c(0.25, 0.75),
    rearrange = FALSE,
    n_samp = 8L,
    seed = 11L,
    T_expected = 4L
  )

  syn_new <- quantileSynthesis(
    draws_list = draws,
    p = c(0.25, 0.75),
    rearrange = FALSE,
    n_samp = 8L,
    seed = 11L,
    T_expected = 4L
  )

  expect_equal(syn_new$draws, syn_old$draws)
  expect_equal(syn_new$levels, syn_old$levels)
  expect_equal(syn_new$quantiles, syn_old$quantiles)
})
