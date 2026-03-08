tiny_rhs_xy <- function(n = 20L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(`(Intercept)` = 1, x = x, x2 = x^2)
  y <- as.numeric(0.5 + 0.8 * x - 0.3 * x^2 + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

test_that("static VB RHS warns about ignored Gaussian prior inputs and returns RHS metadata", {
  set.seed(601)
  dat <- tiny_rhs_xy(18)

  expect_warning(
    fit <- exal_static_LDVB(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      beta_prior = "rhs",
      b0 = rep(0.2, ncol(dat$X)),
      V0 = diag(2, ncol(dat$X)),
      beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
      max_iter = 40,
      tol = 5e-3,
      n_samp_xi = 40,
      ld_controls = list(
        xi_method = "delta",
        optimizer_method = "lbfgsb",
        direct_commit = TRUE,
        sigma_init_mode = "data_scale"
      ),
      verbose = FALSE
    ),
    "ignores b0/V0"
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_false(isTRUE(fit$beta_prior$summary$shrink_intercept))
  expect_true(is.finite(fit$beta_prior$summary$tau))
  expect_true(is.finite(fit$beta_prior$summary$c2))

  norm <- exdqlm:::.static_normalize_vb_fit(fit, model_name = "exal", tau = 0.5)
  expect_identical(norm$diagnostics$beta_prior$type, "rhs")
  expect_true(is.list(norm$diagnostics$rhs$summary))
  expect_true(is.finite(norm$diagnostics$rhs$summary$tau))

  init <- exdqlm:::.static_vb_to_mcmc_init(fit, dqlm.ind = FALSE)
  expect_true(all(c("lambda", "tau", "c2") %in% names(init)))
  expect_length(init$lambda, ncol(dat$X))
  expect_true(is.finite(init$tau))
  expect_true(is.finite(init$c2))
})

test_that("static AL VB reduced path supports RHS prior", {
  set.seed(602)
  dat <- tiny_rhs_xy(16)

  fit <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    beta_prior = "rhs",
    beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
    max_iter = 50,
    tol = 5e-3,
    verbose = FALSE
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_true(is.finite(fit$beta_prior$summary$tau))
  expect_true(is.numeric(fit$qbeta$m))
})

test_that("static MCMC RHS warns, stores latent draws, and normalizes cleanly", {
  set.seed(603)
  dat <- tiny_rhs_xy(18)

  expect_warning(
    fit <- exal_static_mcmc(
      y = dat$y,
      X = dat$X,
      p0 = 0.5,
      beta_prior = "rhs",
      b0 = rep(0.2, ncol(dat$X)),
      V0 = diag(2, ncol(dat$X)),
      beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
      n.burn = 10,
      n.mcmc = 12,
      mh.proposal = "slice",
      trace.diagnostics = FALSE,
      verbose = FALSE
    ),
    "ignores b0/V0"
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_s3_class(fit$samp.lambda, "mcmc")
  expect_s3_class(fit$samp.tau, "mcmc")
  expect_s3_class(fit$samp.c2, "mcmc")
  expect_true(is.list(fit$rhs.diagnostics))
  expect_true(is.finite(fit$rhs.diagnostics$summary$tau))
  expect_true(is.finite(fit$rhs.diagnostics$summary$c2))

  norm <- exdqlm:::.static_normalize_mcmc_fit(fit, model_name = "exal", tau = 0.5)
  expect_identical(norm$diagnostics$beta_prior$type, "rhs")
  expect_true(is.list(norm$diagnostics$rhs$summary))
  expect_true(is.list(norm$diagnostics$rhs$ess))
  expect_true(is.list(norm$diagnostics$rhs$draws))
})

test_that("static AL MCMC reduced path supports RHS prior", {
  set.seed(604)
  dat <- tiny_rhs_xy(18)

  fit <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    beta_prior = "rhs",
    beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
    n.burn = 8,
    n.mcmc = 10,
    trace.diagnostics = FALSE,
    verbose = FALSE
  )

  expect_identical(fit$beta_prior$type, "rhs")
  expect_s3_class(fit$samp.lambda, "mcmc")
  expect_true(is.finite(fit$rhs.diagnostics$summary$tau))
  expect_true(is.finite(fit$rhs.diagnostics$summary$c2))
})
