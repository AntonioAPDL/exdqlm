tiny_static_xy <- function(n = 20L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.3, -0.2) + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

test_that("static VB normalization and init extraction work for AL (dqlm.ind=TRUE)", {
  set.seed(501)
  dat <- tiny_static_xy(20)

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 60,
    tol = 1e-3,
    verbose = FALSE
  )

  init <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = TRUE)
  expect_true(all(c("beta", "sigma", "v") %in% names(init)))
  expect_length(init$beta, ncol(dat$X))

  norm <- .static_normalize_vb_fit(vb_fit, model_name = "al", tau = 0.5)
  expect_identical(norm$model_family, "static")
  expect_identical(norm$algorithm, "vb")
  expect_true(isTRUE(norm$dqlm.ind))
  expect_true(is.numeric(norm$sigma_est))
  expect_true(is.na(norm$gamma_est))
  expect_true(is.list(norm$diagnostics$convergence))
})

test_that("static VB normalization and init extraction work for exAL", {
  set.seed(502)
  dat <- tiny_static_xy(18)

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    max_iter = 40,
    tol = 5e-3,
    n_samp_xi = 60,
    verbose = FALSE
  )

  init <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = FALSE)
  expect_true(all(c("beta", "sigma", "gamma", "v", "s") %in% names(init)))
  expect_length(init$beta, ncol(dat$X))

  norm <- .static_normalize_vb_fit(vb_fit, model_name = "exal", tau = 0.5)
  expect_identical(norm$model_family, "static")
  expect_identical(norm$algorithm, "vb")
  expect_false(norm$dqlm.ind)
  expect_true(is.finite(norm$sigma_est))
  expect_true(is.finite(norm$gamma_est))
  expect_true(length(norm$diagnostics$elbo$trace) >= 1)
  expect_true(is.data.frame(norm$diagnostics$ld_block$trace))
  expect_true(nrow(norm$diagnostics$ld_block$trace) >= 1)
  expect_true(is.list(norm$diagnostics$ld_block$setup))
  expect_true(is.list(norm$diagnostics$ld_block$stabilization))
  expect_true(is.list(norm$diagnostics$ld_block$signoff_summary))
  expect_true(norm$diagnostics$ld_block$setup$sigma_min < norm$diagnostics$ld_block$setup$sigma_max)
  expect_true(is.data.frame(norm$diagnostics$s_block$trace))
  expect_true(nrow(norm$diagnostics$s_block$trace) >= 1)
})

test_that("static MCMC normalization reports ESS and acceptance fields", {
  set.seed(503)
  dat <- tiny_static_xy(16)

  fit_al <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    n.burn = 8,
    n.mcmc = 12,
    thin = 1,
    verbose = FALSE
  )
  norm_al <- .static_normalize_mcmc_fit(fit_al, model_name = "al", tau = 0.5)
  expect_identical(norm_al$algorithm, "mcmc")
  expect_true(isTRUE(norm_al$dqlm.ind))
  expect_true(is.finite(norm_al$diagnostics$ess$sigma) || is.na(norm_al$diagnostics$ess$sigma))
  expect_true(is.na(norm_al$diagnostics$ess$gamma))

  fit_exal <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    n.burn = 12,
    n.mcmc = 12,
    thin = 1,
    mh.proposal = "laplace_rw",
    mh.adapt = TRUE,
    mh.adapt.interval = 6,
    verbose = FALSE
  )
  norm_exal <- .static_normalize_mcmc_fit(fit_exal, model_name = "exal", tau = 0.5)
  expect_identical(norm_exal$algorithm, "mcmc")
  expect_false(norm_exal$dqlm.ind)
  expect_true(is.finite(norm_exal$sigma_est))
  expect_true(is.finite(norm_exal$gamma_est))
  expect_true(length(norm_exal$diagnostics$rhat_ready$sigma) == 12)
  expect_true(length(norm_exal$diagnostics$rhat_ready$gamma) == 12)
  expect_identical(norm_exal$diagnostics$mh$proposal, "laplace_rw")
  expect_true(isTRUE(norm_exal$diagnostics$mh$kernel_exact))
  expect_true(isTRUE(norm_exal$diagnostics$mh$signoff_ready))
  expect_true(is.finite(norm_exal$diagnostics$acceptance$total))
  expect_true(is.data.frame(norm_exal$diagnostics$mh$trace))
  expect_true(all(c("s_mean", "s_sd") %in% names(norm_exal$diagnostics$mh$trace)))
  expect_true(is.data.frame(norm_exal$diagnostics$s_block$trace))

  fit_exal_local <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    mh.proposal = "laplace_local",
    verbose = FALSE
  )
  norm_exal_local <- .static_normalize_mcmc_fit(fit_exal_local, model_name = "exal", tau = 0.5)
  expect_identical(norm_exal_local$diagnostics$mh$proposal, "laplace_local")
  expect_false(norm_exal_local$diagnostics$mh$kernel_exact)
  expect_false(norm_exal_local$diagnostics$mh$signoff_ready)
  expect_match(norm_exal_local$diagnostics$mh$approximation_note, "without MH correction")

  fit_exal_slice <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    mh.proposal = "slice",
    verbose = FALSE
  )
  norm_exal_slice <- .static_normalize_mcmc_fit(fit_exal_slice, model_name = "exal", tau = 0.5)
  expect_identical(norm_exal_slice$diagnostics$mh$proposal, "slice")
  expect_true(norm_exal_slice$diagnostics$mh$kernel_exact)
  expect_true(norm_exal_slice$diagnostics$mh$signoff_ready)
  expect_true(is.na(norm_exal_slice$diagnostics$acceptance$total))
  expect_true(all(c("slice_evals", "s_mean", "s_sd") %in% names(norm_exal_slice$diagnostics$mh$trace)))
})

test_that("static MCMC can disable per-iteration diagnostics trace", {
  set.seed(5031)
  dat <- tiny_static_xy(16)

  fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    n.burn = 8,
    n.mcmc = 10,
    thin = 1,
    mh.proposal = "slice",
    trace.diagnostics = FALSE,
    verbose = FALSE
  )

  expect_true(is.data.frame(fit$mh.diagnostics$trace))
  expect_identical(nrow(fit$mh.diagnostics$trace), 0L)
  expect_false(isTRUE(fit$mh.diagnostics$trace_enabled))
  expect_true(is.na(fit$mh.diagnostics$trace_every))
})

test_that("static quantile path extractor returns aligned vectors", {
  set.seed(504)
  dat <- tiny_static_xy(14)

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 40,
    tol = 1e-3,
    verbose = FALSE
  )

  mcmc_fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    n.burn = 8,
    n.mcmc = 12,
    thin = 1,
    verbose = FALSE
  )

  q_vb <- .static_quantile_path_from_fit(vb_fit, dat$X, algorithm = "vb")
  q_mc <- .static_quantile_path_from_fit(mcmc_fit, dat$X, algorithm = "mcmc")

  expect_length(q_vb$mean, nrow(dat$X))
  expect_length(q_vb$lo, nrow(dat$X))
  expect_length(q_vb$hi, nrow(dat$X))

  expect_length(q_mc$mean, nrow(dat$X))
  expect_length(q_mc$lo, nrow(dat$X))
  expect_length(q_mc$hi, nrow(dat$X))
  expect_true(all(is.finite(q_mc$mean)))
})

test_that("static normalization marks RHS collapse runs as unhealthy", {
  set.seed(505)
  dat <- tiny_static_xy(16)

  vb_fit <- exalStaticLDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    beta_prior = "rhs",
    beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
    max_iter = 35,
    tol = 5e-3,
    n_samp_xi = 40,
    verbose = FALSE
  )
  vb_fit$beta_prior$summary$collapse_flag <- TRUE
  if (!is.null(vb_fit$diagnostics$rhs$summary)) {
    vb_fit$diagnostics$rhs$summary$collapse_flag <- TRUE
  }
  norm_vb <- .static_normalize_vb_fit(vb_fit, model_name = "exal", tau = 0.5)
  expect_identical(norm_vb$status, "collapse")
  expect_false(norm_vb$healthy)
  expect_true(isTRUE(norm_vb$diagnostics$rhs$collapse_flag))
  expect_true(is.list(norm_vb$diagnostics$rhs$preflight))

  mc_fit <- exalStaticMCMC(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    beta_prior = "rhs",
    beta_prior_controls = list(tau0 = 0.5, nu = 3, s2 = 1, shrink_intercept = FALSE),
    n.burn = 8,
    n.mcmc = 10,
    mh.proposal = "slice",
    trace.diagnostics = FALSE,
    verbose = FALSE
  )
  mc_fit$beta_prior$summary$collapse_flag <- TRUE
  if (!is.null(mc_fit$rhs.diagnostics$summary)) {
    mc_fit$rhs.diagnostics$summary$collapse_flag <- TRUE
  }
  norm_mc <- .static_normalize_mcmc_fit(mc_fit, model_name = "exal", tau = 0.5)
  expect_identical(norm_mc$status, "collapse")
  expect_false(norm_mc$healthy)
  expect_true(isTRUE(norm_mc$diagnostics$rhs$collapse_flag))
  expect_true(is.list(norm_mc$diagnostics$rhs$preflight))
})
