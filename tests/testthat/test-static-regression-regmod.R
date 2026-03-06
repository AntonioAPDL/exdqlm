# Smoke tests for static regression API (regMod + static exAL inference routines).

test_that("regMod returns exdqlm-compatible structure", {
  X <- cbind(1, seq(-1, 1, length.out = 6))

  mod <- regMod(X)

  expect_s3_class(mod, "exdqlm")
  expect_equal(dim(mod$FF), c(2, 6))
  expect_equal(dim(mod$GG), c(2, 2))
  expect_equal(length(mod$m0), 2)
  expect_equal(dim(mod$C0), c(2, 2))

  checked <- check_mod(mod)
  expect_s3_class(checked, "exdqlm")
})

test_that("exal_static_LDVB runs on tiny deterministic input", {
  set.seed(123)
  n <- 12
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.25, -0.15)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.1))

  fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 20,
    tol = 1e-2,
    n_samp_xi = 40,
    ld_controls = list(
      xi_method = "delta",
      optimizer_method = "lbfgsb",
      direct_commit = TRUE,
      sigma_init_mode = "data_scale"
    ),
    verbose = FALSE
  )

  expect_true(is.list(fit))
  expect_true(is.numeric(fit$qbeta$m))
  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(is.finite(fit$qsiggam$sigma_mean))
  expect_true(is.finite(fit$qsiggam$gamma_mean))
  expect_true(is.list(fit$diagnostics$ld_block))
  expect_true(is.data.frame(fit$diagnostics$ld_block$trace))
  expect_identical(fit$diagnostics$ld_block$controls$xi_method, "delta")
  expect_identical(fit$diagnostics$ld_block$controls$optimizer_method, "lbfgsb")
  expect_true(is.list(fit$diagnostics$ld_block$setup))
  expect_true(fit$diagnostics$ld_block$setup$sigma_min < fit$diagnostics$ld_block$setup$sigma_max)
  expect_true(is.list(fit$diagnostics$ld_block$mode_quality))
  expect_true(is.finite(fit$diagnostics$ld_block$mode_quality$grad_inf_norm) || is.na(fit$diagnostics$ld_block$mode_quality$grad_inf_norm))
})

test_that("static LDVB qdesn-style delta xi path is deterministic", {
  set.seed(124)
  n <- 16
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.25, -0.15)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.08))
  ctrl <- list(
    xi_method = "delta",
    optimizer_method = "lbfgsb",
    direct_commit = TRUE,
    sigma_init_mode = "data_scale",
    store_trace = TRUE
  )

  fit1 <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 30,
    tol = 5e-3,
    n_samp_xi = 40,
    ld_controls = ctrl,
    verbose = FALSE
  )
  fit2 <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 30,
    tol = 5e-3,
    n_samp_xi = 40,
    ld_controls = ctrl,
    verbose = FALSE
  )

  expect_equal(unlist(fit1$qsiggam$xi), unlist(fit2$qsiggam$xi), tolerance = 1e-12)
  expect_equal(fit1$qsiggam$gamma_mean, fit2$qsiggam$gamma_mean, tolerance = 1e-12)
  expect_equal(fit1$qsiggam$sigma_mean, fit2$qsiggam$sigma_mean, tolerance = 1e-12)
  expect_equal(fit1$diagnostics$ld_block$xi$replicates, 0L)
  expect_identical(fit1$diagnostics$ld_block$xi$mode, "delta")
})

test_that("static LDVB replicated MC xi mode remains available with reused draws", {
  set.seed(1241)
  n <- 14
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.1, -0.2)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.08))
  ctrl <- list(
    xi_method = "mc",
    xi_mode = "replicated",
    xi_replicates = 3L,
    reuse_draws = TRUE,
    reuse_seed = 20260305L,
    optimizer_method = "bfgs",
    direct_commit = FALSE,
    store_trace = TRUE
  )

  fit1 <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 25,
    tol = 5e-3,
    n_samp_xi = 40,
    ld_controls = ctrl,
    verbose = FALSE
  )
  fit2 <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = 0.5,
    max_iter = 25,
    tol = 5e-3,
    n_samp_xi = 40,
    ld_controls = ctrl,
    verbose = FALSE
  )

  expect_equal(unlist(fit1$qsiggam$xi), unlist(fit2$qsiggam$xi), tolerance = 1e-12)
  expect_equal(fit1$diagnostics$ld_block$xi$replicates, 3L)
  expect_identical(fit1$diagnostics$ld_block$xi$mode, "replicated")
})

test_that("static LD precision regularization handles singular Hessians", {
  reg_fun <- getFromNamespace(".exal_static_ld_cov_from_precision", "exdqlm")
  H <- matrix(c(1, 1, 1, 1 + 1e-18), nrow = 2, byrow = TRUE)

  reg <- reg_fun(H, eig_floor = 1e-6, eig_cap = 25)
  eig_cov <- eigen(reg$Sigma, symmetric = TRUE, only.values = TRUE)$values

  expect_true(all(is.finite(reg$Sigma)))
  expect_true(all(eig_cov > 0))
  expect_true(isTRUE(reg$used_floor))
})

test_that("exal_static_mcmc runs on tiny deterministic input", {
  set.seed(321)
  n <- 10
  X <- cbind(1, seq(-0.5, 0.5, length.out = n))
  beta <- c(0.1, 0.2)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.15))

  fit <- exal_static_mcmc(
    y = y,
    X = X,
    p0 = 0.5,
    n.burn = 8,
    n.mcmc = 12,
    thin = 1,
    verbose = FALSE
  )

  expect_true(is.list(fit))
  expect_true(all(is.finite(as.numeric(fit$samp.beta))))
  expect_true(all(is.finite(as.numeric(fit$samp.sigma))))
  expect_true(all(is.finite(as.numeric(fit$samp.gamma))))
})
