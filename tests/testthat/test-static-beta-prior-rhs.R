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

test_that("static RHS VB warmup freezes tau before the forced post-warmup update", {
  obj <- exdqlm:::.static_beta_prior_make(
    beta_prior = "rhs",
    p = 3L,
    b0 = rep(0, 3L),
    V0 = diag(1, 3L),
    beta_prior_controls = list(
      tau0 = 0.5,
      nu = 3,
      s2 = 1,
      shrink_intercept = FALSE,
      freeze_tau_iters = 3L,
      freeze_tau_warmup_iters = 3L,
      update_every = 5L,
      force_tau_after_warmup = TRUE
    )
  )
  state <- obj$init_vb()
  tau_init <- exp(state$eta_tau_hat)
  qbeta <- list(m = c(0, 0.8, -0.4), V = diag(c(1e-6, 0.1, 0.1)))

  state <- obj$update_vb(state, qbeta)
  expect_equal(exp(state$eta_tau_hat), tau_init, tolerance = 1e-12)
  expect_true(isTRUE(state$last_schedule$tau_warmup))
  expect_identical(state$tau_update_count, 0L)

  state <- obj$update_vb(state, qbeta)
  state <- obj$update_vb(state, qbeta)
  expect_identical(state$tau_update_count, 0L)

  state <- obj$update_vb(state, qbeta)
  expect_false(isTRUE(state$last_schedule$tau_warmup))
  expect_identical(state$last_schedule$reason, "force_after_warmup")
  expect_identical(state$tau_update_count, 1L)
})

test_that("static RHS collapse diagnostic flags tau collapse and zeroed slopes", {
  ctrl <- exdqlm:::.static_parse_beta_prior_controls(list(
    tau0 = 1,
    nu = 4,
    s2 = 1,
    shrink_intercept = FALSE
  ))
  state <- exdqlm:::.static_rhs_init_vb_state(4L, ctrl)
  state$eta_tau_hat <- ctrl$eta_bounds$tau[1]
  qbeta <- list(m = c(0.7, 1e-8, -3e-7, 6e-7), V = diag(rep(1e-10, 4L)))

  diag <- exdqlm:::.static_rhs_collapse_diag(state, qbeta, ctrl)
  expect_true(isTRUE(diag$collapse_flag))
  expect_true(isTRUE(diag$tau_near_zero))
  expect_true(isTRUE(diag$slope_collapse))
  expect_true(is.finite(diag$tau_ratio))
  expect_match(diag$warning, "collapsed near zero")
})
