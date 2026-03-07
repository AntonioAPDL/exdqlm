tiny_static_xy <- function(n = 20L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  y <- as.numeric(X %*% c(0.3, -0.2) + stats::rnorm(n, sd = 0.15))
  list(X = X, y = y)
}

test_that("static VB normalization and init extraction work for AL (dqlm.ind=TRUE)", {
  set.seed(501)
  dat <- tiny_static_xy(20)

  vb_fit <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 60,
    tol = 1e-3,
    verbose = FALSE
  )

  init <- exdqlm:::.static_vb_to_mcmc_init(vb_fit, dqlm.ind = TRUE)
  expect_true(all(c("beta", "sigma", "v") %in% names(init)))
  expect_length(init$beta, ncol(dat$X))

  norm <- exdqlm:::.static_normalize_vb_fit(vb_fit, model_name = "al", tau = 0.5)
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

  vb_fit <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = FALSE,
    max_iter = 40,
    tol = 5e-3,
    n_samp_xi = 60,
    verbose = FALSE
  )

  init <- exdqlm:::.static_vb_to_mcmc_init(vb_fit, dqlm.ind = FALSE)
  expect_true(all(c("beta", "sigma", "gamma", "v", "s") %in% names(init)))
  expect_length(init$beta, ncol(dat$X))

  norm <- exdqlm:::.static_normalize_vb_fit(vb_fit, model_name = "exal", tau = 0.5)
  expect_identical(norm$model_family, "static")
  expect_identical(norm$algorithm, "vb")
  expect_false(norm$dqlm.ind)
  expect_true(is.finite(norm$sigma_est))
  expect_true(is.finite(norm$gamma_est))
  expect_true(length(norm$diagnostics$elbo$trace) >= 1)
  expect_true(is.data.frame(norm$diagnostics$ld_block$trace))
  expect_true(nrow(norm$diagnostics$ld_block$trace) >= 1)
  expect_true(is.list(norm$diagnostics$ld_block$setup))
  expect_true(norm$diagnostics$ld_block$setup$sigma_min < norm$diagnostics$ld_block$setup$sigma_max)
  expect_true(is.data.frame(norm$diagnostics$s_block$trace))
  expect_true(nrow(norm$diagnostics$s_block$trace) >= 1)
})

test_that("static MCMC normalization reports ESS and acceptance fields", {
  set.seed(503)
  dat <- tiny_static_xy(16)

  fit_al <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    n.burn = 8,
    n.mcmc = 12,
    thin = 1,
    verbose = FALSE
  )
  norm_al <- exdqlm:::.static_normalize_mcmc_fit(fit_al, model_name = "al", tau = 0.5)
  expect_identical(norm_al$algorithm, "mcmc")
  expect_true(isTRUE(norm_al$dqlm.ind))
  expect_true(is.finite(norm_al$diagnostics$ess$sigma) || is.na(norm_al$diagnostics$ess$sigma))
  expect_true(is.na(norm_al$diagnostics$ess$gamma))

  fit_exal <- exal_static_mcmc(
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
  norm_exal <- exdqlm:::.static_normalize_mcmc_fit(fit_exal, model_name = "exal", tau = 0.5)
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

  fit_exal_local <- exal_static_mcmc(
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
  norm_exal_local <- exdqlm:::.static_normalize_mcmc_fit(fit_exal_local, model_name = "exal", tau = 0.5)
  expect_identical(norm_exal_local$diagnostics$mh$proposal, "laplace_local")
  expect_false(norm_exal_local$diagnostics$mh$kernel_exact)
  expect_false(norm_exal_local$diagnostics$mh$signoff_ready)
  expect_match(norm_exal_local$diagnostics$mh$approximation_note, "without MH correction")
})

test_that("static quantile path extractor returns aligned vectors", {
  set.seed(504)
  dat <- tiny_static_xy(14)

  vb_fit <- exal_static_LDVB(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    max_iter = 40,
    tol = 1e-3,
    verbose = FALSE
  )

  mcmc_fit <- exal_static_mcmc(
    y = dat$y,
    X = dat$X,
    p0 = 0.5,
    dqlm.ind = TRUE,
    n.burn = 8,
    n.mcmc = 12,
    thin = 1,
    verbose = FALSE
  )

  q_vb <- exdqlm:::.static_quantile_path_from_fit(vb_fit, dat$X, algorithm = "vb")
  q_mc <- exdqlm:::.static_quantile_path_from_fit(mcmc_fit, dat$X, algorithm = "mcmc")

  expect_length(q_vb$mean, nrow(dat$X))
  expect_length(q_vb$lo, nrow(dat$X))
  expect_length(q_vb$hi, nrow(dat$X))

  expect_length(q_mc$mean, nrow(dat$X))
  expect_length(q_mc$lo, nrow(dat$X))
  expect_length(q_mc$hi, nrow(dat$X))
  expect_true(all(is.finite(q_mc$mean)))
})
