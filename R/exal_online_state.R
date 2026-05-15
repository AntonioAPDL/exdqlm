# Shared natural-parameter helpers for exAL VB beta updates.

.exal_effective_barw_barm <- function(y, xis, qv_m_inv, qs_m) {
  y <- as.numeric(y)
  qv_m_inv <- as.numeric(qv_m_inv)
  qs_m <- as.numeric(qs_m)
  n <- length(y)
  if (length(qv_m_inv) != n || length(qs_m) != n) {
    .stopf("effective moments: y, qv_m_inv, qs_m lengths must match.")
  }

  xi1 <- as.numeric(xis$xi1)
  xi_lambda <- as.numeric(xis$xi_lambda)
  xi_A <- as.numeric(xis$xi_A)
  if (!is.finite(xi1) || !is.finite(xi_lambda) || !is.finite(xi_A)) {
    .stopf("effective moments: xis contains non-finite values.")
  }

  barw <- as.numeric(xi1 * qv_m_inv)
  barw <- pmax(barw, 1e-16)
  barm <- as.numeric(y * barw - xi_lambda * (qv_m_inv * qs_m) - xi_A)

  if (any(!is.finite(barw)) || any(barw <= 0)) {
    .stopf("effective moments: invalid barw.")
  }
  if (any(!is.finite(barm))) {
    .stopf("effective moments: invalid barm.")
  }

  list(barw = barw, barm = barm)
}

.exal_beta_natural_stats <- function(X, y, xis, qv_m_inv, qs_m, prec_diag = NULL) {
  assert_matrix(X, "X")
  y <- as.numeric(y)
  if (length(y) != nrow(X)) .stopf("natural stats: y length must match nrow(X).")

  eff <- .exal_effective_barw_barm(
    y = y,
    xis = xis,
    qv_m_inv = qv_m_inv,
    qs_m = qs_m
  )

  Xw <- X * sqrt(eff$barw)
  S <- crossprod(Xw)
  S <- 0.5 * (S + t(S))
  g <- as.numeric(crossprod(X, eff$barm))

  out <- list(
    barw = eff$barw,
    barm = eff$barm,
    S = S,
    g = g
  )

  if (!is.null(prec_diag)) {
    p <- ncol(X)
    prec_diag <- as.numeric(prec_diag)
    if (length(prec_diag) != p) {
      .stopf("natural stats: prec_diag must have length p=%d.", p)
    }
    if (any(!is.finite(prec_diag)) || any(prec_diag <= 0)) {
      .stopf("natural stats: prec_diag must be finite and > 0.")
    }
    P <- S + diag(prec_diag, p)
    P <- 0.5 * (P + t(P))
    out$P <- P
    out$h <- as.numeric(g)
    out$prec_diag <- prec_diag
  }

  out
}
