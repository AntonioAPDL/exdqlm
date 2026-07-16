tiny_rqr_grid_reference <- function(y, coverage_level, learning_rate, tau2,
                                    lo = -3, hi = 3, n_grid = 121L) {
  b <- seq(lo, hi, length.out = n_grid)
  grid <- expand.grid(beta1 = b, beta2 = b)
  loss <- vapply(seq_len(nrow(grid)), function(i) {
    e <- (y - grid$beta1[i]) * (y - grid$beta2[i])
    sum(exdqlm::rqr_check_loss(e, coverage_level))
  }, numeric(1))
  logw <- -learning_rate * loss -
    0.5 * (grid$beta1^2 + grid$beta2^2) / tau2
  w <- exp(logw - max(logw))
  w <- w / sum(w)
  lower <- pmin(grid$beta1, grid$beta2)
  upper <- pmax(grid$beta1, grid$beta2)
  c(
    lower_mean = sum(w * lower),
    upper_mean = sum(w * upper),
    width_mean = sum(w * (upper - lower))
  )
}

test_that("fixed-design RQR MCMC runs finite and respects root swapping", {
  set.seed(7201)
  y <- c(-1.1, -0.6, -0.2, 0.25, 0.7, 1.3)
  X <- matrix(1, length(y), 1)
  prior <- exdqlm::beta_prior("ridge", ridge = list(tau2 = 4))

  fit_a <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1.2,
    beta_prior_obj = prior,
    init = list(beta1 = -1, beta2 = 1),
    mcmc_control = list(n_burn = 350, n_mcmc = 500, thin = 1, seed = 7201)
  )
  fit_b <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = 0.8,
    learning_rate = 1.2,
    beta_prior_obj = prior,
    init = list(beta1 = 1, beta2 = -1),
    mcmc_control = list(n_burn = 350, n_mcmc = 500, thin = 1, seed = 7202)
  )

  expect_s3_class(fit_a, "rqr_mcmc")
  expect_true(all(is.finite(fit_a$samp.beta_root1)))
  expect_true(all(is.finite(fit_a$samp.beta_root2)))
  expect_equal(
    mean(fit_a$summary$width_mean),
    mean(fit_b$summary$width_mean),
    tolerance = 0.35
  )
  expect_true(all(fit_a$summary$upper_mean >= fit_a$summary$lower_mean))
})

test_that("intercept-only RQR MCMC is close to dense-grid reference", {
  set.seed(7202)
  y <- c(-1.2, -0.75, -0.1, 0.15, 0.55, 1.05, 1.35)
  X <- matrix(1, length(y), 1)
  tau2 <- 5
  alpha <- 0.8
  omega <- 1.0
  ref <- tiny_rqr_grid_reference(y, alpha, omega, tau2, lo = -2.8, hi = 2.8, n_grid = 101L)

  fit <- exdqlm::rqr_mcmc_fit(
    y = y,
    X = X,
    coverage_level = alpha,
    learning_rate = omega,
    beta_prior_obj = exdqlm::beta_prior("ridge", ridge = list(tau2 = tau2)),
    mcmc_control = list(n_burn = 500, n_mcmc = 900, thin = 1, seed = 7203)
  )
  got <- c(
    lower_mean = mean(fit$summary$lower_mean),
    upper_mean = mean(fit$summary$upper_mean),
    width_mean = mean(fit$summary$width_mean)
  )

  expect_equal(got["lower_mean"], ref["lower_mean"], tolerance = 0.35)
  expect_equal(got["upper_mean"], ref["upper_mean"], tolerance = 0.35)
  expect_equal(got["width_mean"], ref["width_mean"], tolerance = 0.45)
})

test_that("RQR beta update matches analytic Gaussian conditional moments", {
  set.seed(7204)
  n <- 16
  X <- cbind(1, seq(-1, 1, length.out = n))
  y <- sin(seq_len(n) / 3)
  beta_other <- c(0.1, -0.2)
  V <- rep(0.9, n)
  cc <- exdqlm::rqr_constants(0.75, 1.3)
  prior_prec <- rep(0.25, ncol(X))

  eta_other <- drop(X %*% beta_other)
  A <- X * as.numeric(y - eta_other)
  z <- y^2 - y * eta_other - cc$xi * V
  W <- 1 / (cc$phi * cc$sigma * V)
  Prec <- crossprod(A * sqrt(W)) + diag(prior_prec, ncol(X))
  rhs <- as.numeric(crossprod(A, W * z))
  Uc <- chol((Prec + t(Prec)) / 2)
  mu <- as.numeric(backsolve(Uc, forwardsolve(t(Uc), rhs)))

  draws <- replicate(2500, {
    exdqlm:::.rqr_beta_update(
      y = y,
      X = X,
      beta_other = beta_other,
      V = V,
      constants = cc,
      prior_prec = prior_prec
    )$draw
  })
  expect_equal(rowMeans(draws), mu, tolerance = 0.08)
})
