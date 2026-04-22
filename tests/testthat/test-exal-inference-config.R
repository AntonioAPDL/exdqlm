tiny_static_xy_builder <- function(n = 18L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.25, -0.2) + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

tiny_dyn_model_builder <- function(TT) {
  as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))
}

test_that("public builder helpers normalize package warmup blocks", {
  vb_sigmagam_default <- exal_make_vb_sigmagam_control()
  expect_equal(vb_sigmagam_default$freeze_warmup_iters, 10L)
  expect_true(isTRUE(vb_sigmagam_default$force_after_warmup))
  expect_equal(vb_sigmagam_default$postwarmup_damping, 0.6, tolerance = 1e-12)
  expect_equal(vb_sigmagam_default$postwarmup_damping_iters, 5L)
  expect_equal(vb_sigmagam_default$min_postwarmup_updates, 1L)

  vb_sigmagam <- exal_make_vb_sigmagam_control(
    freeze_warmup_iters = 10L,
    force_after_warmup = FALSE,
    postwarmup_damping = 0.6,
    postwarmup_damping_iters = 4L,
    min_postwarmup_updates = 2L
  )
  expect_equal(vb_sigmagam$freeze_warmup_iters, 10L)
  expect_false(isTRUE(vb_sigmagam$force_after_warmup))
  expect_equal(vb_sigmagam$postwarmup_damping, 0.6, tolerance = 1e-12)

  vb_sts <- exal_make_vb_sts_control(
    freeze_warmup_iters = 8L,
    force_after_warmup = FALSE,
    min_postwarmup_updates = 3L
  )
  expect_equal(vb_sts$freeze_warmup_iters, 8L)
  expect_false(isTRUE(vb_sts$force_after_warmup))
  expect_equal(vb_sts$min_postwarmup_updates, 3L)

  vb_control <- exal_make_vb_control(
    max_iter = 60L,
    tol = 2e-3,
    n_samp_xi = 40L,
    verbose = TRUE,
    sigmagam = vb_sigmagam,
    sts = vb_sts
  )
  expect_equal(vb_control$max_iter, 60L)
  expect_equal(vb_control$tol, 2e-3, tolerance = 1e-12)
  expect_true(isTRUE(vb_control$verbose))
  expect_equal(vb_control$sigmagam$freeze_warmup_iters, 10L)
  expect_equal(vb_control$sts$freeze_warmup_iters, 8L)

  latent_state <- exal_make_mcmc_latent_state_control(
    mode = "u_st_pair",
    freeze_burnin_iters = 12L,
    freeze_only_during_burn = FALSE,
    force_after_warmup = FALSE,
    min_postwarmup_updates = 2L,
    trace = FALSE
  )
  expect_identical(latent_state$mode, "u_st_pair")
  expect_equal(latent_state$freeze_burnin_iters, 12L)
  expect_false(isTRUE(latent_state$trace))

  dqlm_sigma <- exal_make_mcmc_dqlm_sigma_control(
    freeze_burnin_iters = 9L,
    freeze_only_during_burn = FALSE,
    force_after_warmup = FALSE,
    trace = FALSE
  )
  expect_equal(dqlm_sigma$freeze_burnin_iters, 9L)
  expect_false(isTRUE(dqlm_sigma$trace))

  mcmc_sigmagam_default <- exal_make_mcmc_sigmagam_control()
  expect_equal(mcmc_sigmagam_default$freeze_burnin_iters, 25L)
  expect_true(isTRUE(mcmc_sigmagam_default$freeze_only_during_burn))
  expect_true(isTRUE(mcmc_sigmagam_default$force_after_warmup))
  expect_true(isTRUE(mcmc_sigmagam_default$delay_adapt_until_after_warmup))
  expect_true(isTRUE(mcmc_sigmagam_default$delay_laplace_refresh_until_after_warmup))

  mcmc_control <- exal_make_mcmc_control(
    n_burn = 25L,
    n_mcmc = 10L,
    verbose = TRUE,
    init_from_vb = TRUE,
    sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 7L),
    theta = exal_make_mcmc_theta_control(
      enabled = TRUE,
      freeze_burnin_iters = 6L,
      sparse_update_every = 2L
    ),
    latent_state = latent_state,
    dqlm_sigma = dqlm_sigma
  )
  expect_equal(mcmc_control$n_burn, 25L)
  expect_equal(mcmc_control$n_mcmc, 10L)
  expect_true(isTRUE(mcmc_control$verbose))
  expect_equal(mcmc_control$sigmagam$freeze_burnin_iters, 7L)
  expect_true(isTRUE(mcmc_control$theta$enabled))
  expect_identical(mcmc_control$latent_state$mode, "u_st_pair")
  expect_equal(mcmc_control$dqlm_sigma$freeze_burnin_iters, 9L)
})

test_that("static entrypoints accept normalized control builders", {
  set.seed(1801)
  dat <- tiny_static_xy_builder()

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    vb_control = exal_make_vb_control(
      max_iter = 25L,
      tol = 5e-3,
      n_samp_xi = 30L,
      sigmagam = exal_make_vb_sigmagam_control(freeze_warmup_iters = 2L)
    ),
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 2L)

  mcmc_fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    mcmc_control = exal_make_mcmc_control(
      n_burn = 8L,
      n_mcmc = 10L,
      init_from_vb = TRUE,
      sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 3L)
    ),
    thin = 1L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$sigmagam$freeze_burnin_iters, 3L)
})

test_that("entrypoints apply the default warmup profile and allow explicit opt-out", {
  set.seed(1803)
  dat <- tiny_static_xy_builder()

  vb_fit_default <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 40L,
    n_samp_xi = 30L,
    verbose = FALSE
  )
  expect_equal(vb_fit_default$misc$sigmagam$freeze_warmup_iters, 10L)
  expect_equal(vb_fit_default$misc$sigmagam$postwarmup_damping, 0.6, tolerance = 1e-12)

  vb_fit_none <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 40L,
    vb_control = exal_make_vb_control(
      n_samp_xi = 30L,
      sigmagam = exal_make_vb_sigmagam_control(
        freeze_warmup_iters = 0L,
        postwarmup_damping = 1.0,
        postwarmup_damping_iters = 0L,
        min_postwarmup_updates = 0L
      )
    ),
    verbose = FALSE
  )
  expect_equal(vb_fit_none$misc$sigmagam$freeze_warmup_iters, 0L)

  mcmc_fit_default <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 30L,
    n.mcmc = 12L,
    thin = 1L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit_default$diagnostics$sigmagam$freeze_burnin_iters, 25L)

  mcmc_fit_none <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 30L,
    n.mcmc = 12L,
    thin = 1L,
    mcmc_control = exal_make_mcmc_control(
      sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 0L)
    ),
    verbose = FALSE
  )
  expect_equal(mcmc_fit_none$diagnostics$sigmagam$freeze_burnin_iters, 0L)
})

test_that("default sigmagam warmup clamps to the available iteration budget", {
  set.seed(1804)
  dat <- tiny_static_xy_builder()

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    max_iter = 12L,
    n_samp_xi = 30L,
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 2L)

  mcmc_fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    n.burn = 6L,
    n.mcmc = 8L,
    thin = 1L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$sigmagam$freeze_burnin_iters, 1L)
})

test_that("dynamic entrypoints accept normalized control builders", {
  set.seed(1802)
  TT <- 18L
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- tiny_dyn_model_builder(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 25L,
    exdqlm.vb.min_iter = 5L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  vb_fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    vb_control = exal_make_vb_control(
      tol = 0.1,
      sigmagam = exal_make_vb_sigmagam_control(freeze_warmup_iters = 2L),
      sts = exal_make_vb_sts_control(freeze_warmup_iters = 2L)
    ),
    n.samp = 10,
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 2L)
  expect_equal(vb_fit$misc$sts$freeze_warmup_iters, 2L)

  mcmc_fit <- exdqlmMCMC(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    mcmc_control = exal_make_mcmc_control(
      n_burn = 10L,
      n_mcmc = 10L,
      init_from_vb = TRUE,
      vb_warm_start_control = list(method = "ldvb", tol = 0.2, n.samp = 20L, max_iter = 10L, verbose = FALSE),
      sigmagam = exal_make_mcmc_sigmagam_control(freeze_burnin_iters = 2L),
      theta = exal_make_mcmc_theta_control(enabled = TRUE, freeze_burnin_iters = 2L),
      latent_state = exal_make_mcmc_latent_state_control(
        mode = "u_st_pair",
        freeze_burnin_iters = 2L
      )
    ),
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$latent_state$freeze_burnin_iters, 2L)
  expect_identical(mcmc_fit$diagnostics$latent_state$mode, "u_st_pair")
})

test_that("dynamic entrypoints use the default sigmagam warmup profile", {
  set.seed(1805)
  TT <- 18L
  y <- cumsum(stats::rnorm(TT, sd = 0.15))
  model <- tiny_dyn_model_builder(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 30L,
    exdqlm.vb.min_iter = 5L,
    exdqlm.vb.patience = 2L
  )
  on.exit(options(old_opts), add = TRUE)

  vb_fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    n.samp = 10,
    verbose = FALSE
  )
  expect_equal(vb_fit$misc$sigmagam$freeze_warmup_iters, 10L)

  mcmc_fit <- exdqlmMCMC(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    n.burn = 30L,
    n.mcmc = 10L,
    verbose = FALSE
  )
  expect_equal(mcmc_fit$diagnostics$sigmagam$freeze_burnin_iters, 25L)
})
