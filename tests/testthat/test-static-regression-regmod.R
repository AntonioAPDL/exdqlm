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
      auto_stabilize = FALSE,
      reject_bad_mode_commit = FALSE,
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
    auto_stabilize = FALSE,
    reject_bad_mode_commit = FALSE,
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

test_that("static LD cycle detector identifies alternating traces", {
  cycle_fun <- getFromNamespace(".exal_static_ld_cycle_detect", "exdqlm")
  ld_ctrl <- list(
    auto_stabilize = TRUE,
    cycle_window = 8L,
    cycle_lag1_max = -0.8,
    cycle_lag2_min = 0.95,
    cycle_gamma_min_amp = 1e-3,
    cycle_sigma_min_amp = 1e-3,
    cycle_s_min_amp = 1e-5,
    cycle_tau2_min_amp = 1e-5
  )
  ld_trace <- data.frame(
    gamma = c(1, 3, 1, 3, 1, 3, 1),
    sigma = c(10, 20, 10, 20, 10, 20, 10)
  )
  s_trace <- data.frame(
    s_mean = c(0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2),
    tau2_mean = c(0.1, 0.4, 0.1, 0.4, 0.1, 0.4, 0.1)
  )
  cand <- list(gamma = 3, sigma = 20, s_mean = 0.5, tau2_mean = 0.4)

  out <- cycle_fun(ld_trace, s_trace, cand, ld_ctrl)

  expect_true(out$triggered)
  expect_match(out$reason, "cycle_detected")
  expect_true(isTRUE(out$flags[["gamma"]]))
  expect_true(isTRUE(out$flags[["sigma"]]))
})

test_that("static LD cycle detector stays quiet on smooth traces", {
  cycle_fun <- getFromNamespace(".exal_static_ld_cycle_detect", "exdqlm")
  ld_ctrl <- list(
    auto_stabilize = TRUE,
    cycle_window = 8L,
    cycle_lag1_max = -0.8,
    cycle_lag2_min = 0.95,
    cycle_gamma_min_amp = 1e-3,
    cycle_sigma_min_amp = 1e-3,
    cycle_s_min_amp = 1e-5,
    cycle_tau2_min_amp = 1e-5
  )
  ld_trace <- data.frame(
    gamma = seq(0.1, 0.8, length.out = 8),
    sigma = seq(1, 2, length.out = 8)
  )
  s_trace <- data.frame(
    s_mean = seq(0.2, 0.3, length.out = 8),
    tau2_mean = seq(0.1, 0.15, length.out = 8)
  )
  cand <- list(gamma = 0.9, sigma = 2.1, s_mean = 0.31, tau2_mean = 0.16)

  out <- cycle_fun(ld_trace, s_trace, cand, ld_ctrl)

  expect_false(out$triggered)
})

test_that("static LDVB records stabilization diagnostics", {
  set.seed(125)
  n <- 16
  X <- cbind(1, seq(-1, 1, length.out = n))
  beta <- c(0.2, -0.1)
  y <- as.numeric(X %*% beta + rnorm(n, sd = 0.08))

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
      auto_stabilize = TRUE,
      store_trace = TRUE
    ),
    verbose = FALSE
  )

  expect_true(is.list(fit$diagnostics$ld_block$stabilization))
  expect_true(all(c("active_final", "since_iter", "reason",
    "cycle_detect_count", "stabilized_iter_count") %in%
    names(fit$diagnostics$ld_block$stabilization)))
  expect_true(is.list(fit$diagnostics$ld_block$signoff_summary))
  expect_true(all(c(
    "candidate_local_pass_rate", "committed_local_pass_rate",
    "optim_fallback_rate", "numeric_hessian_rate",
    "identity_hessian_rate", "cov_floor_rate",
    "direct_commit_rate", "damped_commit_rate"
  ) %in% names(fit$diagnostics$ld_block$signoff_summary)))
  expect_true(all(c(
    "ld_used_optim_fallback", "ld_used_numeric_hessian",
    "ld_used_identity_hessian", "ld_used_cov_floor",
    "ld_commit_mode", "ld_mode_local_pass_candidate",
    "ld_mode_local_pass_committed"
  ) %in% names(fit$diagnostics$ld_block$trace)))
  expect_true(all(c("ld_cycle_detected", "ld_stabilized",
    "ld_stabilize_reason") %in%
    names(fit$diagnostics$s_block$trace)))
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
