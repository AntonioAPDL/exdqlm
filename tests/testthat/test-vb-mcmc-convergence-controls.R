tiny_dyn_model <- function(TT) {
  as.exdqlm(list(
    m0 = 0,
    C0 = matrix(1, 1, 1),
    FF = matrix(1, nrow = 1, ncol = TT),
    GG = array(1, dim = c(1, 1, TT))
  ))
}

test_that("dynamic LDVB exposes joint convergence diagnostics", {
  set.seed(101)
  TT <- 30
  y <- cumsum(stats::rnorm(TT, sd = 0.2))
  model <- tiny_dyn_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 25L,
    exdqlm.vb.min_iter = 5L,
    exdqlm.vb.patience = 2L,
    exdqlm.tol_elbo = 1e-3
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmLDVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE, tol = 0.1, n.samp = 10, verbose = FALSE
  )

  expect_true(is.list(fit$diagnostics$convergence))
  expect_true(fit$diagnostics$convergence$stop_reason %in% c("joint_converged", "max_iter"))
  expect_true(length(fit$diagnostics$deltas$state) >= 1)
  expect_true(length(fit$diagnostics$deltas$sigma) >= 1)
  expect_true(length(fit$diagnostics$deltas$gamma) >= 1)
  expect_true(length(fit$diagnostics$deltas$s) >= 1)
  expect_true(is.list(fit$diagnostics$ld_block))
  expect_true(is.data.frame(fit$diagnostics$ld_block$trace))
  expect_true(is.list(fit$diagnostics$s_block))
  expect_true(is.data.frame(fit$diagnostics$s_block$trace))
})

test_that("dynamic ISVB honors strict gamma criterion in joint stopping", {
  set.seed(102)
  TT <- 25
  y <- stats::rnorm(TT)
  model <- tiny_dyn_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 6L,
    exdqlm.vb.min_iter = 2L,
    exdqlm.vb.patience = 2L,
    exdqlm.tol_gamma = 1e-12,
    exdqlm.tol_sigma = 1e-2,
    exdqlm.tol_elbo = 1e-2
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmISVB(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE, tol = 0.2, n.IS = 80, n.samp = 8, verbose = FALSE
  )

  expect_identical(fit$diagnostics$convergence$stop_reason, "max_iter")
})

test_that("dynamic MCMC supports VB warm start and MH diagnostics", {
  set.seed(103)
  TT <- 24
  y <- stats::rnorm(TT, sd = 0.4)
  model <- tiny_dyn_model(TT)

  old_opts <- options(
    exdqlm.use_cpp_mcmc = FALSE,
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.compute_elbo = TRUE,
    exdqlm.max_iter = 30L
  )
  on.exit(options(old_opts), add = TRUE)

  fit <- exdqlmMCMC(
    y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
    fix.sigma = FALSE,
    n.burn = 30, n.mcmc = 20,
    init.from.vb = TRUE,
    vb_init_controls = list(method = "ldvb", tol = 0.2, n.samp = 40, max_iter = 20, verbose = FALSE),
    mh.proposal = "laplace_rw",
    mh.adapt = TRUE,
    mh.adapt.interval = 10,
    verbose = FALSE
  )

  expect_true(isTRUE(fit$init.from.vb))
  expect_true(is.list(fit$mh.diagnostics))
  expect_true(is.finite(fit$accept.rate))
  expect_true(is.finite(fit$accept.rate.burn))
  expect_true(is.finite(fit$accept.rate.keep))
  expect_true(is.finite(fit$diagnostics$ess$sigma))
  expect_true(is.data.frame(fit$mh.diagnostics$trace))
  expect_true(all(c("s_mean", "s_sd") %in% names(fit$mh.diagnostics$trace)))
  expect_true(is.list(fit$diagnostics$s_block))
  expect_true(is.data.frame(fit$diagnostics$s_block$trace))
})

test_that("static MCMC supports VB warm start", {
  set.seed(104)
  n <- 40
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- as.numeric(X %*% c(0.2, -0.1) + stats::rnorm(n, sd = 0.2))

  fit <- exal_static_mcmc(
    y = y, X = X, p0 = 0.5,
    n.burn = 20, n.mcmc = 20, thin = 1,
    init.from.vb = TRUE,
    vb_init_controls = list(
      max_iter = 50,
      tol = 1e-3,
      n_samp_xi = 100,
      verbose = FALSE,
      ld_controls = list(
        xi_method = "delta",
        optimizer_method = "lbfgsb",
        direct_commit = TRUE,
        sigma_init_mode = "data_scale"
      )
    ),
    mh.proposal = "laplace_rw",
    mh.adapt = TRUE,
    mh.adapt.interval = 10,
    verbose = FALSE
  )

  expect_true(isTRUE(fit$init.from.vb))
  expect_true(is.list(fit$vb.init.controls))
  expect_identical(fit$vb.init.controls$ld_controls$xi_method, "delta")
  expect_identical(fit$vb.init.controls$ld_controls$optimizer_method, "lbfgsb")
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit$samp.gamma))))
  expect_true(is.list(fit$mh.diagnostics))
  expect_true(is.finite(fit$accept.rate))
  expect_true(is.finite(fit$accept.rate.burn))
  expect_true(is.finite(fit$accept.rate.keep))
})

test_that("multichain diagnostics helper returns chain summaries", {
  set.seed(105)
  TT <- 16
  y <- stats::rnorm(TT)
  model <- tiny_dyn_model(TT)

  out <- exdqlm:::.exdqlm_mcmc_multichain_diag(
    n.chains = 2L,
    seeds = c(201, 202),
    mcmc_args = list(
      y = y, p0 = 0.5, model = model, df = 1, dim.df = 1,
      dqlm.ind = TRUE, fix.sigma = TRUE, sig.init = 1,
      n.burn = 5, n.mcmc = 6, verbose = FALSE
    )
  )

  expect_length(out$fits, 2)
  expect_s3_class(out$diagnostics$sigma$chains, "mcmc.list")
})
