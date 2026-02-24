legacy_tn_moments <- function(mu, tau2) {
  tau2 <- pmax(as.numeric(tau2), 1e-12)
  tau <- sqrt(tau2)
  mu <- as.numeric(mu)

  alpha <- mu / tau
  logPhi <- pnorm(alpha, log.p = TRUE)
  logphi <- dnorm(alpha, log = TRUE)

  lambda <- exp(pmin(logphi - logPhi, 700))
  idx <- (alpha < -8)
  if (any(idx)) {
    a <- -alpha[idx]
    lambda[idx] <- a + 1 / a + 2 / (a^3)
  }

  Es <- mu + tau * lambda
  Es <- pmax(Es, 1e-12)

  Es2 <- tau2 + mu^2 + tau * mu * lambda
  Es2 <- pmax(Es2, Es^2 + 1e-12)
  list(Es = Es, Es2 = Es2)
}

test_that("Stage1 helper: q(v) local update matches legacy formulas", {
  set.seed(20260224)
  n <- 17L
  y <- rnorm(n, sd = 0.8)
  xb <- rnorm(n, sd = 0.6)
  q_i <- rexp(n, rate = 2) + 1e-3
  qs_m <- abs(rnorm(n, mean = 0.7, sd = 0.25)) + 1e-4
  qs_m2 <- pmax(qs_m^2 + rexp(n, rate = 4), qs_m^2 + 1e-6)
  xis <- list(
    xi1 = 0.83,
    xi_lambda = -0.21,
    xi_lambda2 = 0.57,
    xi_A2 = 0.49,
    xi_siginv = 1.12
  )

  psi_old <- pmax(as.numeric(xis$xi_A2 + 2 * xis$xi_siginv), 1e-12)
  chi_old <- as.numeric(
    xis$xi1 * ((y - xb)^2 + q_i) -
      2 * xis$xi_lambda * (y * qs_m) +
      xis$xi_lambda2 * qs_m2 +
      2 * xis$xi_lambda * (xb * qs_m)
  )
  chi_old <- pmax(chi_old, 1e-12)
  m_old <- exdqlm:::.gig_half_moments(chi = chi_old, psi = psi_old)

  up <- exdqlm:::.exal_local_qv_update(
    y = y,
    xb = xb,
    q_i = q_i,
    qs_m = qs_m,
    qs_m2 = qs_m2,
    xis = xis
  )

  expect_equal(up$psi, as.numeric(psi_old), tolerance = 1e-14)
  expect_equal(up$chi, as.numeric(chi_old), tolerance = 1e-12)
  expect_equal(up$m, as.numeric(m_old$m), tolerance = 1e-12)
  expect_equal(up$m_inv, as.numeric(m_old$m_inv), tolerance = 1e-12)
})

test_that("Stage1 helper: q(s) local update matches legacy formulas", {
  set.seed(20260225)
  n <- 19L
  y <- rnorm(n, sd = 0.9)
  xb <- rnorm(n, sd = 0.7)
  qv_m_inv <- rexp(n, rate = 1.5) + 1e-3
  xis <- list(
    xi_lambda = -0.37,
    xi_lambda2 = 0.81,
    zeta_lam = 0.16
  )

  tau2_old <- 1 / (1 + xis$xi_lambda2 * qv_m_inv)
  tau2_old <- pmax(tau2_old, 1e-12)
  mu_old <- tau2_old * (xis$xi_lambda * (qv_m_inv * (y - xb)) - xis$zeta_lam)
  moms_old <- legacy_tn_moments(mu_old, tau2_old)

  up <- exdqlm:::.exal_local_qs_update(
    y = y,
    xb = xb,
    qv_m_inv = qv_m_inv,
    xis = xis
  )

  expect_equal(up$tau2, as.numeric(tau2_old), tolerance = 1e-12)
  expect_equal(up$mu, as.numeric(mu_old), tolerance = 1e-12)
  expect_equal(up$m, as.numeric(moms_old$Es), tolerance = 1e-12)
  expect_equal(up$m2, as.numeric(moms_old$Es2), tolerance = 1e-12)
})

test_that("Stage2 helper: natural stats match legacy X'WX and X'barm forms", {
  set.seed(20260226)
  n <- 23L
  p <- 6L
  X <- cbind(1, matrix(rnorm(n * (p - 1L)), nrow = n))
  y <- rnorm(n)
  qv_m_inv <- rexp(n, rate = 1.7) + 1e-3
  qs_m <- abs(rnorm(n, mean = 0.8, sd = 0.3)) + 1e-4
  xis <- list(
    xi1 = 0.91,
    xi_lambda = 0.43,
    xi_A = -0.18
  )
  prec_diag <- runif(p, min = 0.05, max = 2.5)

  W_old <- as.numeric(xis$xi1 * qv_m_inv)
  W_old <- pmax(W_old, 1e-16)
  barm_old <- as.numeric(y * W_old - xis$xi_lambda * (qv_m_inv * qs_m) - xis$xi_A)
  S_old <- crossprod(X * sqrt(W_old))
  S_old <- 0.5 * (S_old + t(S_old))
  g_old <- as.numeric(crossprod(X, barm_old))
  P_old <- S_old + diag(prec_diag, p)
  P_old <- 0.5 * (P_old + t(P_old))

  nat <- exdqlm:::.exal_beta_natural_stats(
    X = X,
    y = y,
    xis = xis,
    qv_m_inv = qv_m_inv,
    qs_m = qs_m,
    prec_diag = prec_diag
  )

  expect_equal(nat$barw, W_old, tolerance = 1e-14)
  expect_equal(nat$barm, barm_old, tolerance = 1e-12)
  expect_equal(nat$S, S_old, tolerance = 1e-12)
  expect_equal(nat$g, g_old, tolerance = 1e-12)
  expect_equal(nat$P, P_old, tolerance = 1e-12)
  expect_equal(nat$h, g_old, tolerance = 1e-12)
})

test_that("batch LDVB remains stable after Stage1/2 refactor", {
  set.seed(20260227)
  n <- 30L
  p <- 5L
  X <- cbind(1, matrix(rnorm(n * (p - 1L)), nrow = n))
  beta <- c(0.3, -0.6, 0.25, 0.15, -0.1)
  y <- as.numeric(X %*% beta + 0.35 * rt(n, df = 7))
  p0 <- 0.5
  bounds <- get_gamma_bounds(p0)

  fit <- exal_ldvb_fit(
    y = y,
    X = X,
    p0 = p0,
    gamma_bounds = bounds,
    vb_control = list(max_iter = 30L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE),
    beta_prior_obj = beta_prior("ridge", ridge = list(tau2 = 5))
  )

  expect_s3_class(fit, "exal_vb")
  expect_true(all(is.finite(fit$qbeta$m)))
  expect_true(all(is.finite(fit$qbeta$V)))
  expect_true(all(is.finite(fit$qv$m)))
  expect_true(all(is.finite(fit$qv$m_inv)))
  expect_true(all(is.finite(fit$qs$m)))
  expect_true(all(is.finite(fit$qs$m2)))
})
