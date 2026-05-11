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
