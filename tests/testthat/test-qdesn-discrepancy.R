make_discrepancy_design <- function(n = 42L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x)
  beta <- c(0.3, 0.55)
  alpha <- c(-0.1, 0.35)
  H_y <- cbind(X, matrix(0, n, ncol(X)))
  H_g <- cbind(X, X)
  H <- rbind(H_y, H_g)
  colnames(H) <- c("beta_1", "beta_2", "alpha_1", "alpha_2")
  theta <- c(beta, alpha)
  list(
    X = X,
    H = H,
    z = as.numeric(H %*% theta + rep(c(-0.01, 0.01), each = n)),
    source = factor(rep(c("Y", "G"), each = n), levels = c("Y", "G")),
    theta = theta,
    q_y = as.numeric(H_y %*% theta),
    q_g = as.numeric(H_g %*% theta)
  )
}

test_that("RHS_NS supports more than one unshrunk intercept", {
  prior <- exdqlm:::beta_prior("rhs_ns", rhs = list(
    tau0 = 0.5,
    s2 = 1,
    intercept_index = c(1L, 3L),
    intercept_prec = 1e-9
  ))
  st <- prior$init(4L)
  prec <- prior$expected_prec(st, 4L)
  expect_equal(st$intercept_index, c(1L, 3L))
  expect_equal(prec[c(1L, 3L)], c(1e-9, 1e-9), tolerance = 1e-14)
  expect_true(all(prec[c(2L, 4L)] > 1e-9))
})

test_that("qdesn discrepancy capabilities expose supported and gated kernels", {
  caps <- exdqlm::qdesn_discrepancy_capabilities()
  expect_true(all(c("method", "likelihood_family", "fit_supported") %in% names(caps)))
  expect_true(any(caps$method == "mcmc" & caps$likelihood_family == "al" & caps$fit_supported))
  expect_true(any(caps$method == "vb" & caps$likelihood_family == "al" & caps$fit_supported))
  expect_false(any(caps$likelihood_family == "exal" & caps$fit_supported))
})

test_that("qdesn_fit_discrepancy AL MCMC returns finite source-indexed summaries", {
  set.seed(20260511)
  dat <- make_discrepancy_design(n = 30L)
  fit <- exdqlm::qdesn_fit_discrepancy(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    method = "mcmc",
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    intercept_index = c(1L, 3L),
    mcmc_args = list(
      n_burn = 40L,
      n_mcmc = 60L,
      thin = 1L,
      seed = 20260511L,
      beta_rhs = list(
        tau0 = 1.0,
        s2 = 4.0,
        a_zeta = 2.0,
        b_zeta = 4.0,
        intercept_prec = 1e-9,
        n_inner = 1L
      ),
      prior_sigma = list(a = 2, b = 1)
    )
  )

  expect_s3_class(fit, "qdesn_discrepancy_fit")
  expect_identical(fit$method, "mcmc")
  expect_identical(fit$likelihood_family, "al")
  expect_identical(fit$beta_prior$type, "rhs_ns")
  expect_equal(fit$beta_prior$state$intercept_index, c(1L, 3L))
  expect_true(all(is.finite(fit$samp.theta)))
  expect_true(all(is.finite(fit$samp.sigma)))
  expect_true(all(fit$samp.sigma > 0))
  expect_length(fit$summary$fitted_mean, length(dat$z))
})

test_that("qdesn_fit_discrepancy AL VB returns posterior draws and diagnostics", {
  set.seed(20260512)
  dat <- make_discrepancy_design(n = 32L)
  fit <- exdqlm::qdesn_fit_discrepancy(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    method = "vb",
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    intercept_index = c(1L, 3L),
    vb_args = list(
      max_iter = 80L,
      min_iter_elbo = 5L,
      tol = 1.0e-5,
      tol_par = 1.0e-5,
      n_draws = 70L,
      seed = 20260512L,
      beta_rhs = list(
        tau0 = 1.0,
        s2 = 4.0,
        a_zeta = 2.0,
        b_zeta = 4.0,
        intercept_prec = 1e-9,
        n_inner = 1L
      ),
      prior_sigma = list(a = 2, b = 1)
    )
  )

  expect_s3_class(fit, "qdesn_discrepancy_fit")
  expect_identical(fit$method, "vb")
  expect_identical(fit$likelihood_family, "al")
  expect_identical(fit$beta_prior$type, "rhs_ns")
  expect_equal(fit$beta_prior$state$intercept_index, c(1L, 3L))
  expect_equal(dim(fit$draws$theta), c(70L, ncol(dat$H)))
  expect_equal(dim(fit$draws$sigma), c(70L, 2L))
  expect_true(all(is.finite(fit$draws$theta)))
  expect_true(all(is.finite(fit$draws$sigma)))
  expect_true(all(fit$draws$sigma > 0))
  expect_true(is.logical(fit$vb_diagnostics$converged))
  expect_true(is.finite(fit$vb_diagnostics$runtime_seconds))
  expect_true(is.finite(fit$vb_diagnostics$elbo_final))
  expect_false(isTRUE(fit$vb_diagnostics$ld_block_active))
})

test_that("qdesn_fit_discrepancy recovers simple reference and discrepancy paths", {
  set.seed(2201)
  dat <- make_discrepancy_design(n = 36L)
  fit <- exdqlm::qdesn_fit_discrepancy(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    method = "mcmc",
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    intercept_index = c(1L, 3L),
    mcmc_args = list(
      n_burn = 80L,
      n_mcmc = 100L,
      thin = 1L,
      seed = 2201L,
      beta_rhs = list(
        tau0 = 1.5,
        s2 = 6.0,
        a_zeta = 2.0,
        b_zeta = 6.0,
        intercept_prec = 1e-9,
        n_inner = 1L
      ),
      prior_sigma = list(a = 4, b = 0.4)
    )
  )

  n <- length(dat$q_y)
  q_y_hat <- fit$summary$fitted_mean[seq_len(n)]
  q_g_hat <- fit$summary$fitted_mean[n + seq_len(n)]
  rmse_y <- sqrt(mean((q_y_hat - dat$q_y)^2))
  rmse_g <- sqrt(mean((q_g_hat - dat$q_g)^2))
  expect_lt(rmse_y, 0.35)
  expect_lt(rmse_g, 0.35)
})

test_that("qdesn_fit_discrepancy AL VB recovers simple reference and discrepancy paths", {
  set.seed(20260512)
  dat <- make_discrepancy_design(n = 48L)
  fit <- exdqlm::qdesn_fit_discrepancy(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    method = "vb",
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    intercept_index = c(1L, 3L),
    vb_args = list(
      max_iter = 120L,
      min_iter_elbo = 5L,
      tol = 1.0e-6,
      tol_par = 1.0e-6,
      n_draws = 80L,
      seed = 20260512L,
      beta_rhs = list(
        tau0 = 1.5,
        s2 = 6.0,
        a_zeta = 2.0,
        b_zeta = 6.0,
        intercept_prec = 1e-9,
        n_inner = 1L
      ),
      prior_sigma = list(a = 4, b = 0.4)
    )
  )

  n <- length(dat$q_y)
  q_y_hat <- fit$summary$fitted_mean[seq_len(n)]
  q_g_hat <- fit$summary$fitted_mean[n + seq_len(n)]
  rmse_y <- sqrt(mean((q_y_hat - dat$q_y)^2))
  rmse_g <- sqrt(mean((q_g_hat - dat$q_g)^2))
  expect_lt(rmse_y, 0.25)
  expect_lt(rmse_g, 0.25)
})

test_that("qdesn_fit_discrepancy AL VB posterior draws satisfy the discrepancy identity", {
  dat <- make_discrepancy_design(n = 16L)
  fit <- exdqlm::qdesn_fit_discrepancy(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    method = "vb",
    likelihood_family = "al",
    beta_prior_type = "ridge",
    intercept_index = c(1L, 3L),
    vb_args = list(
      max_iter = 50L,
      min_iter_elbo = 5L,
      tol = 1.0e-5,
      tol_par = 1.0e-5,
      n_draws = 20L,
      seed = 11L,
      tau2 = 1.0e4,
      prior_sigma = list(a = 2, b = 1)
    )
  )

  theta <- fit$draws$theta
  beta_draws <- theta[, 1:2, drop = FALSE]
  alpha_draws <- theta[, 3:4, drop = FALSE]
  q_y <- beta_draws %*% t(dat$X)
  d_g <- alpha_draws %*% t(dat$X)
  q_g <- (beta_draws + alpha_draws) %*% t(dat$X)
  expect_equal(q_y + d_g, q_g, tolerance = 1.0e-10)
})

test_that("qdesn_fit_discrepancy AL VB forwards RHS schedule controls", {
  dat <- make_discrepancy_design(n = 12L)
  fit <- exdqlm::qdesn_fit_discrepancy(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    method = "vb",
    likelihood_family = "al",
    beta_prior_type = "rhs_ns",
    intercept_index = c(1L, 3L),
    vb_args = list(
      max_iter = 2L,
      min_iter_elbo = 10L,
      n_draws = 5L,
      seed = 12L,
      beta_rhs = list(
        tau0 = 1.0,
        s2 = 4.0,
        a_zeta = 2.0,
        b_zeta = 4.0,
        intercept_prec = 1e-9
      ),
      rhs = list(
        freeze_tau_warmup_iters = 5L,
        n_inner = 1L
      ),
      prior_sigma = list(a = 2, b = 1)
    )
  )

  expect_true(isTRUE(fit$beta_prior$state$freeze_tau))
  expect_identical(fit$beta_prior$state$last_schedule$reason, "warmup")
})

test_that("qdesn_fit_discrepancy AL VB reproduces one-source ridge readout behavior", {
  x <- seq(-1, 1, length.out = 30L)
  H <- cbind(1, x)
  colnames(H) <- c("beta_1", "beta_2")
  theta <- c(0.2, -0.4)
  z <- as.numeric(H %*% theta)
  source <- factor(rep("Y", length(z)), levels = "Y")

  fit <- exdqlm::qdesn_fit_discrepancy(
    z = z,
    H = H,
    source = source,
    source_levels = "Y",
    p0 = 0.5,
    method = "vb",
    likelihood_family = "al",
    beta_prior_type = "ridge",
    intercept_index = 1L,
    vb_args = list(
      max_iter = 80L,
      min_iter_elbo = 5L,
      tol = 1.0e-6,
      tol_par = 1.0e-6,
      n_draws = 30L,
      seed = 20260512L,
      tau2 = 1.0e6,
      prior_sigma = list(a = 4, b = 0.2)
    )
  )

  expect_identical(fit$method, "vb")
  expect_equal(ncol(fit$draws$sigma), 1L)
  expect_lt(sqrt(mean((fit$summary$fitted_mean - z)^2)), 0.05)
  expect_lt(max(abs(fit$summary$theta_mean - theta)), 0.08)
})

test_that("qdesn_fit_discrepancy AL VB is stable to stacked-row permutation", {
  dat <- make_discrepancy_design(n = 30L)
  set.seed(117)
  perm <- sample(seq_along(dat$z))
  args <- list(
    p0 = 0.5,
    method = "vb",
    likelihood_family = "al",
    beta_prior_type = "ridge",
    intercept_index = c(1L, 3L),
    vb_args = list(
      max_iter = 80L,
      min_iter_elbo = 5L,
      tol = 1.0e-6,
      tol_par = 1.0e-6,
      n_draws = 20L,
      seed = 117L,
      tau2 = 1.0e6,
      prior_sigma = list(a = 4, b = 0.2)
    )
  )

  fit_a <- do.call(exdqlm::qdesn_fit_discrepancy, c(
    list(z = dat$z, H = dat$H, source = dat$source),
    args
  ))
  fit_b <- do.call(exdqlm::qdesn_fit_discrepancy, c(
    list(z = dat$z[perm], H = dat$H[perm, , drop = FALSE], source = dat$source[perm]),
    args
  ))

  expect_equal(fit_a$summary$theta_mean, fit_b$summary$theta_mean, tolerance = 1.0e-5)
  expect_equal(fit_a$summary$sigma_mean, fit_b$summary$sigma_mean, tolerance = 1.0e-5)
})

test_that("qdesn_fit_discrepancy AL VB agrees with small MCMC within diagnostic tolerance", {
  set.seed(20260513)
  dat <- make_discrepancy_design(n = 28L)
  common <- list(
    z = dat$z,
    H = dat$H,
    source = dat$source,
    p0 = 0.5,
    likelihood_family = "al",
    beta_prior_type = "ridge",
    intercept_index = c(1L, 3L)
  )
  fit_vb <- do.call(exdqlm::qdesn_fit_discrepancy, c(
    common,
    list(
      method = "vb",
      vb_args = list(
        max_iter = 100L,
        min_iter_elbo = 5L,
        tol = 1.0e-5,
        tol_par = 1.0e-5,
        n_draws = 80L,
        seed = 20260513L,
        tau2 = 1.0e5,
        prior_sigma = list(a = 4, b = 0.3)
      )
    )
  ))
  fit_mcmc <- do.call(exdqlm::qdesn_fit_discrepancy, c(
    common,
    list(
      method = "mcmc",
      mcmc_args = list(
        n_burn = 80L,
        n_mcmc = 120L,
        thin = 1L,
        seed = 20260513L,
        tau2 = 1.0e5,
        prior_sigma = list(a = 4, b = 0.3)
      )
    )
  ))

  n <- length(dat$q_y)
  vb_rmse <- sqrt(mean((fit_vb$summary$fitted_mean - dat$z)^2))
  mcmc_rmse <- sqrt(mean((fit_mcmc$summary$fitted_mean - dat$z)^2))
  vb_y <- fit_vb$summary$fitted_mean[seq_len(n)]
  mcmc_y <- fit_mcmc$summary$fitted_mean[seq_len(n)]
  expect_lt(vb_rmse, 0.20)
  expect_lt(mcmc_rmse, 0.40)
  expect_lt(sqrt(mean((vb_y - mcmc_y)^2)), 0.45)
})
