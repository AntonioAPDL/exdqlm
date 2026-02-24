# Shared local-moment updates for exAL VB factors.
#
# These helpers are intentionally internal and reused by both:
# - batch LDVB engine (`exal_ldvb_engine`),
# - online/streaming updater (`exal_online_vbld`).

.exal_tn_moments <- function(mu, tau2) {
  tau2 <- pmax(as.numeric(tau2), 1e-12)
  tau <- sqrt(tau2)
  mu <- as.numeric(mu)

  alpha <- mu / tau
  logPhi <- pnorm(alpha, log.p = TRUE)
  logphi <- dnorm(alpha, log = TRUE)

  # Mills ratio lambda = phi/Phi with a stable tail approximation.
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

.exal_local_qv_update <- function(y, xb, q_i, qs_m, qs_m2, xis) {
  y <- as.numeric(y)
  xb <- as.numeric(xb)
  q_i <- as.numeric(q_i)
  qs_m <- as.numeric(qs_m)
  qs_m2 <- as.numeric(qs_m2)

  n <- length(y)
  if (length(xb) != n || length(q_i) != n || length(qs_m) != n || length(qs_m2) != n) {
    .stopf("local q(v) update: vector lengths must match.")
  }

  xi1 <- as.numeric(xis$xi1)
  xi_lambda <- as.numeric(xis$xi_lambda)
  xi_lambda2 <- as.numeric(xis$xi_lambda2)
  xi_A2 <- as.numeric(xis$xi_A2)
  xi_siginv <- as.numeric(xis$xi_siginv)

  if (!is.finite(xi1) || !is.finite(xi_lambda) || !is.finite(xi_lambda2) ||
      !is.finite(xi_A2) || !is.finite(xi_siginv)) {
    .stopf("local q(v) update: xis contains non-finite values.")
  }

  psi <- pmax(xi_A2 + 2 * xi_siginv, 1e-12)

  chi <- as.numeric(
    xi1 * ((y - xb)^2 + q_i) -
      2 * xi_lambda * (y * qs_m) +
      xi_lambda2 * qs_m2 +
      2 * xi_lambda * (xb * qs_m)
  )
  chi <- pmax(chi, 1e-12)

  m_gig <- .gig_half_moments(chi = chi, psi = psi)
  m <- as.numeric(m_gig$m)
  m_inv <- as.numeric(m_gig$m_inv)
  z <- as.numeric(m_gig$z)

  if (any(!is.finite(m)) || any(m <= 0)) .stopf("local q(v) update: E[v] invalid.")
  if (any(!is.finite(m_inv)) || any(m_inv <= 0)) .stopf("local q(v) update: E[1/v] invalid.")

  list(
    m = m,
    m_inv = m_inv,
    chi = chi,
    psi = as.numeric(psi),
    z = z
  )
}

.exal_local_qs_update <- function(y, xb, qv_m_inv, xis) {
  y <- as.numeric(y)
  xb <- as.numeric(xb)
  qv_m_inv <- as.numeric(qv_m_inv)

  n <- length(y)
  if (length(xb) != n || length(qv_m_inv) != n) {
    .stopf("local q(s) update: vector lengths must match.")
  }

  xi_lambda <- as.numeric(xis$xi_lambda)
  xi_lambda2 <- as.numeric(xis$xi_lambda2)
  zeta_lam <- as.numeric(xis$zeta_lam)

  if (!is.finite(xi_lambda) || !is.finite(xi_lambda2) || !is.finite(zeta_lam)) {
    .stopf("local q(s) update: xis contains non-finite values.")
  }

  tau2 <- 1 / (1 + xi_lambda2 * qv_m_inv)
  tau2 <- pmax(tau2, 1e-12)

  mu <- tau2 * (xi_lambda * (qv_m_inv * (y - xb)) - zeta_lam)
  moms <- .exal_tn_moments(mu, tau2)

  m <- as.numeric(moms$Es)
  m2 <- as.numeric(moms$Es2)
  if (any(!is.finite(m)) || any(m <= 0)) .stopf("local q(s) update: E[s] invalid.")
  if (any(!is.finite(m2)) || any(m2 <= 0)) .stopf("local q(s) update: E[s^2] invalid.")

  list(
    m = m,
    m2 = m2,
    mu = as.numeric(mu),
    tau2 = as.numeric(tau2)
  )
}
