test_that("renamed API keeps deprecated function aliases working", {
  set.seed(771)
  x <- seq(-1, 1, length.out = 18)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.4, -0.2) + stats::rnorm(length(x), sd = 0.1))

  expect_warning(
    fit_ldvb_old <- exal_static_LDVB(
      y = y,
      X = X,
      p0 = 0.5,
      max_iter = 30,
      tol = 1e-2,
      n_samp_xi = 50,
      verbose = FALSE
    ),
    "Deprecated"
  )
  expect_s3_class(fit_ldvb_old, "exalStaticLDVB")
  expect_s3_class(fit_ldvb_old, "exal_ldvb")

  expect_warning(
    fit_mcmc_old <- exal_static_mcmc(
      y = y,
      X = X,
      p0 = 0.5,
      n.burn = 8,
      n.mcmc = 10,
      thin = 1,
      verbose = FALSE
    ),
    "Deprecated"
  )
  expect_s3_class(fit_mcmc_old, "exalStaticMCMC")
  expect_s3_class(fit_mcmc_old, "exal_mcmc")

  expect_warning(
    diags_old <- exalDiagnostics(fit_ldvb_old, fit_mcmc_old, ref = as.numeric(drop(X %*% c(0.4, -0.2))), plot = FALSE),
    "Deprecated"
  )
  expect_s3_class(diags_old, "exalStaticDiagnostic")
  expect_s3_class(diags_old, "exalDiagnostic")
})

test_that("renamed synthesis API keeps deprecated alias working", {
  draws_low <- matrix(c(0.1, 0.2, 0.3, 0.4), nrow = 2)
  draws_high <- draws_low + 0.5

  expect_warning(
    syn_old <- exdqlm_synthesize_from_draws(
      draws_list = list(draws_low, draws_high),
      p = c(0.25, 0.75),
      grid_M = 21L,
      n_samp = 16L,
      seed = 99L,
      T_expected = 2L
    ),
    "Deprecated"
  )

  syn_new <- quantileSynthesis(
    draws_list = list(draws_low, draws_high),
    p = c(0.25, 0.75),
    grid_M = 21L,
    n_samp = 16L,
    seed = 99L,
    T_expected = 2L
  )

  expect_equal(syn_old$draws, syn_new$draws)
})

test_that("old static classes still dispatch through compatibility methods", {
  set.seed(772)
  x <- seq(-1, 1, length.out = 16)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.3, 0.1) + stats::rnorm(length(x), sd = 0.1))

  fit_new <- exalStaticLDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 25,
    tol = 1e-2,
    n_samp_xi = 40,
    verbose = FALSE
  )
  class(fit_new) <- c("exal_ldvb", "exal_vb")
  expect_output(print(fit_new), "Bayesian Linear Quantile Regression")

  diag_new <- exalStaticDiagnostics(
    exalStaticLDVB(
      y = y,
      X = X,
      p0 = 0.5,
      max_iter = 25,
      tol = 1e-2,
      n_samp_xi = 40,
      verbose = FALSE
    ),
    plot = FALSE
  )
  class(diag_new) <- "exalDiagnostic"
  expect_output(print(diag_new), "Static exAL diagnostics")
})
