# Online / streaming extension for exAL VB-LD (single quantile)
#
# This module adds a stateful online updater while leaving the existing
# offline/batch engine unchanged.

.online_as_int <- function(x, default) {
  if (is.null(x) || !length(x)) return(as.integer(default))
  as.integer(x)[1L]
}

.online_as_num <- function(x, default) {
  if (is.null(x) || !length(x)) return(as.numeric(default))
  as.numeric(x)[1L]
}

.online_log_sigmoid <- function(x) {
  ifelse(x >= 0, -log1p(exp(-x)), x - log1p(exp(x)))
}

.online_build_log_prior_gamma <- function(prior_gamma) {
  prior_gamma <- prior_gamma %||% list()
  if (!is.null(prior_gamma$log_prior) && is.function(prior_gamma$log_prior)) {
    return(prior_gamma$log_prior)
  }
  if (!is.null(prior_gamma$mu0) && !is.null(prior_gamma$s20)) {
    mu0 <- as.numeric(prior_gamma$mu0)[1L]
    s20 <- max(as.numeric(prior_gamma$s20)[1L], 1e-12)
    return(function(g) dnorm(g, mean = mu0, sd = sqrt(s20), log = TRUE))
  }
  function(g) 0
}

.online_trans_par <- function(z, p0, gamma_bounds) {
  eta <- as.numeric(z[1L])
  ell <- as.numeric(z[2L])
  L <- as.numeric(gamma_bounds[1L])
  U <- as.numeric(gamma_bounds[2L])

  s <- plogis(eta)
  gamma <- L + (U - L) * s
  sigma <- exp(ell)

  abc <- exal_get_ABC(p0 = p0, gamma = gamma)
  A <- as.numeric(abc$A)
  B <- pmax(as.numeric(abc$B), 1e-12)
  lam <- as.numeric(abc$C) * abs(gamma)

  list(
    eta = eta,
    ell = ell,
    gamma = gamma,
    sigma = sigma,
    A = A,
    B = B,
    lam = lam,
    log_hprime = .online_log_sigmoid(eta) + .online_log_sigmoid(-eta)
  )
}

.online_compute_xi <- function(eta_hat, ell_hat, Sigma, p0, gamma_bounds,
                               log_prior_gamma_fun) {
  z0 <- c(as.numeric(eta_hat), as.numeric(ell_hat))
  Sigma <- as.matrix(Sigma)
  if (!all(dim(Sigma) == c(2L, 2L))) .stopf("online: Sigma for (eta,ell) must be 2x2.")

  g_vec <- function(z) {
    p <- .online_trans_par(z, p0 = p0, gamma_bounds = gamma_bounds)

    xi1        <- 1 / (p$B * p$sigma)
    xi_lambda  <- p$lam / p$B
    xi_lambda2 <- (p$lam^2) * p$sigma / p$B
    xi_A       <- p$A / (p$B * p$sigma)
    xi_A2      <- (p$A^2) / (p$B * p$sigma)
    zeta_lam   <- (p$lam * p$A) / p$B

    zeta_logB      <- log(pmax(p$B, 1e-300))
    zeta_logpi     <- as.numeric(log_prior_gamma_fun(p$gamma))
    zeta_loghprime <- p$log_hprime

    c(
      xi1 = xi1,
      xi_lambda = xi_lambda,
      xi_lambda2 = xi_lambda2,
      xi_A = xi_A,
      xi_A2 = xi_A2,
      zeta_lam = zeta_lam,
      zeta_logB = zeta_logB,
      zeta_logpi = zeta_logpi,
      zeta_loghprime = zeta_loghprime
    )
  }

  h1s <- 1e-3 * sqrt(pmax(Sigma[1, 1], 1e-8))
  h2s <- 1e-3 * sqrt(pmax(Sigma[2, 2], 1e-8))
  h1 <- max(1e-4 * (1 + abs(z0[1])), h1s)
  h2 <- max(1e-4 * (1 + abs(z0[2])), h2s)
  h1 <- min(max(h1, 1e-6), 1e-2)
  h2 <- min(max(h2, 1e-6), 1e-2)

  f00 <- g_vec(z0)
  f10 <- g_vec(z0 + c( h1,  0))
  f_10 <- g_vec(z0 + c(-h1,  0))
  f01 <- g_vec(z0 + c(  0, h2))
  f0_1 <- g_vec(z0 + c(  0,-h2))
  f11 <- g_vec(z0 + c( h1, h2))
  f1_1 <- g_vec(z0 + c( h1,-h2))
  f_11 <- g_vec(z0 + c(-h1, h2))
  f_1_1 <- g_vec(z0 + c(-h1,-h2))

  H11 <- (f10 - 2 * f00 + f_10) / (h1^2)
  H22 <- (f01 - 2 * f00 + f0_1) / (h2^2)
  H12 <- (f11 - f1_1 - f_11 + f_1_1) / (4 * h1 * h2)

  corr <- 0.5 * (H11 * Sigma[1, 1] + 2 * H12 * Sigma[1, 2] + H22 * Sigma[2, 2])
  out <- f00 + corr

  out <- c(
    out,
    xi_siginv = exp(-z0[2] + 0.5 * Sigma[2, 2]),
    zeta_logsigma = z0[2]
  )

  out <- as.numeric(out)
  names(out) <- names(c(f00, xi_siginv = 0, zeta_logsigma = 0))

  if (!all(is.finite(out))) .stopf("online: non-finite xi moments after Delta computation.")
  as.list(out)
}

.online_tn_moments <- function(mu, tau2) {
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

.online_local_update_one <- function(y_t, x_t, qbeta, xis,
                                     n_alt = 2L,
                                     s_init = sqrt(2 / pi),
                                     s2_init = 1) {
  x_t <- as.numeric(x_t)
  y_t <- as.numeric(y_t)[1L]

  xb <- as.numeric(sum(x_t * qbeta$m))
  qx <- as.numeric(t(x_t) %*% (qbeta$V %*% x_t))

  psi <- as.numeric(xis$xi_A2 + 2 * xis$xi_siginv)
  psi <- pmax(psi, 1e-12)

  s_m <- pmax(as.numeric(s_init)[1L], 1e-12)
  s_m2 <- pmax(as.numeric(s2_init)[1L], s_m^2 + 1e-12)

  n_alt <- max(1L, as.integer(n_alt)[1L])

  v_m <- 1
  v_inv <- 1
  for (ii in seq_len(n_alt)) {
    chi <- as.numeric(
      xis$xi1 * ((y_t - xb)^2 + qx) -
        2 * xis$xi_lambda * (y_t * s_m) +
        xis$xi_lambda2 * s_m2 +
        2 * xis$xi_lambda * (xb * s_m)
    )
    chi <- pmax(chi, 1e-12)

    m_gig <- .gig_half_moments(chi = chi, psi = psi)
    v_m <- as.numeric(m_gig$m)
    v_inv <- as.numeric(m_gig$m_inv)

    tau2 <- 1 / (1 + as.numeric(xis$xi_lambda2) * v_inv)
    tau2 <- pmax(tau2, 1e-12)

    mu_s <- tau2 * (as.numeric(xis$xi_lambda) * (v_inv * (y_t - xb)) - as.numeric(xis$zeta_lam))
    moms <- .online_tn_moments(mu_s, tau2)

    s_m <- as.numeric(moms$Es)
    s_m2 <- as.numeric(moms$Es2)
  }

  barw <- as.numeric(xis$xi1) * v_inv
  barm <- as.numeric(y_t * xis$xi1 * v_inv - xis$xi_lambda * s_m * v_inv - xis$xi_A)

  if (!is.finite(barw) || barw <= 0) .stopf("online local update produced invalid barw.")
  if (!is.finite(barm)) .stopf("online local update produced invalid barm.")

  list(
    v_m = as.numeric(v_m),
    v_inv = as.numeric(v_inv),
    s_m = as.numeric(s_m),
    s_m2 = as.numeric(s_m2),
    barw = as.numeric(barw),
    barm = as.numeric(barm)
  )
}

.online_assert_state <- function(state) {
  if (!inherits(state, "exal_online_vbld_state")) {
    .stopf("state must inherit from 'exal_online_vbld_state'.")
  }
  invisible(TRUE)
}

.online_update_beta_from_natural <- function(state) {
  state$P <- 0.5 * (state$P + t(state$P))
  sol <- .solve_sympd(state$P, state$h, jitter = state$control$jitter %||% 1e-10)

  state$qbeta$m <- as.numeric(sol$x)
  state$qbeta$V <- as.matrix(sol$inv)
  state$chol_P <- sol$chol %||% NULL

  state
}

.online_backfit_window <- function(state, idx, n_passes = 1L) {
  idx <- as.integer(idx)
  if (!length(idx)) return(state)
  n_passes <- max(1L, as.integer(n_passes)[1L])

  for (pp in seq_len(n_passes)) {
    for (ii in idx) {
      x_i <- state$history$X[ii, , drop = TRUE]
      y_i <- state$history$y[ii]

      old_barw <- state$history$barw[ii]
      old_barm <- state$history$barm[ii]

      loc <- .online_local_update_one(
        y_t = y_i,
        x_t = x_i,
        qbeta = state$qbeta,
        xis = state$xis,
        n_alt = state$control$L_loc,
        s_init = state$history$s_m[ii],
        s2_init = state$history$s_m2[ii]
      )

      state$history$v_m[ii] <- loc$v_m
      state$history$v_inv[ii] <- loc$v_inv
      state$history$s_m[ii] <- loc$s_m
      state$history$s_m2[ii] <- loc$s_m2
      state$history$barw[ii] <- loc$barw
      state$history$barm[ii] <- loc$barm

      d_barw <- loc$barw - old_barw
      d_barm <- loc$barm - old_barm

      state$S <- state$S + d_barw * tcrossprod(x_i)
      state$g <- state$g + d_barm * x_i
    }
  }

  state$h <- as.numeric(state$g)
  state$P <- state$S + diag(state$prec_diag, state$k)
  state <- .online_update_beta_from_natural(state)

  state$refresh_counts$window_backfit <- as.integer(state$refresh_counts$window_backfit %||% 0L) + 1L
  state
}

.online_refresh_sigmagam <- function(state, idx) {
  idx <- as.integer(idx)
  if (!length(idx)) return(state)

  X <- state$history$X[idx, , drop = FALSE]
  y <- state$history$y[idx]

  mv_inv <- state$history$v_inv[idx]
  mv <- state$history$v_m[idx]
  ms <- state$history$s_m[idx]
  ms2 <- state$history$s_m2[idx]

  xb <- as.numeric(X %*% state$qbeta$m)
  t_i <- y - xb
  q_i <- rowSums((X %*% state$qbeta$V) * X)

  S1 <- sum(mv_inv * (t_i^2 + q_i))
  S2 <- sum(t_i)
  S3 <- sum(mv)
  S4 <- sum(ms * mv_inv * t_i)
  S5 <- sum(ms2 * mv_inv)
  S6 <- sum(ms)

  n_eff <- length(idx)

  p0 <- state$p0
  L <- state$gamma_bounds[1L]
  U <- state$gamma_bounds[2L]
  a_sigma <- as.numeric(state$prior_sigma$a %||% 1)[1L]
  b_sigma <- as.numeric(state$prior_sigma$b %||% 1)[1L]

  eta_lo <- state$eta_bounds[1L]
  eta_hi <- state$eta_bounds[2L]
  ell_lo <- state$ell_bounds[1L]
  ell_hi <- state$ell_bounds[2L]

  log_prior_gamma_fun <- state$log_prior_gamma_fun

  log_qsiggam <- function(par) {
    eta <- as.numeric(par[1L])
    ell <- as.numeric(par[2L])

    s <- plogis(eta)
    gamma <- L + (U - L) * s
    sigma <- exp(ell)

    abc <- exal_get_ABC(p0 = p0, gamma = gamma)
    A <- as.numeric(abc$A)
    B <- pmax(as.numeric(abc$B), 1e-12)
    lam <- as.numeric(abc$C) * abs(gamma)

    if (!is.finite(B) || B <= 0 || !is.finite(sigma) || sigma <= 0) return(-Inf)

    term1 <- - (1 / (2 * B * sigma)) * (S1 - 2 * A * S2 + (A * A) * S3)
    term2 <- - (S3 + b_sigma) / sigma
    term3 <- + (lam / B) * (S4 - A * S6)
    term4 <- - ((lam * lam) / (2 * B)) * sigma * S5

    log_prior_g <- as.numeric(log_prior_gamma_fun(gamma))
    log_det <- - (n_eff / 2) * log(B) - (a_sigma + (3 * n_eff) / 2) * ell +
      (.online_log_sigmoid(eta) + .online_log_sigmoid(-eta))

    out <- log_prior_g + log_det + term1 + term2 + term3 + term4
    if (!is.finite(out)) -Inf else out
  }

  fn_neg <- function(z) {
    val <- log_qsiggam(z)
    if (is.finite(val)) -val else 1e100
  }

  par0 <- c(state$qsiggam$eta_hat, state$qsiggam$ell_hat)
  par0[1L] <- min(max(par0[1L], eta_lo), eta_hi)
  par0[2L] <- min(max(par0[2L], ell_lo), ell_hi)

  opt <- try(
    optim(
      par = par0,
      fn = fn_neg,
      method = "L-BFGS-B",
      lower = c(eta_lo, ell_lo),
      upper = c(eta_hi, ell_hi),
      control = list(maxit = as.integer(state$control$maxit_sigmagam %||% 500L))
    ),
    silent = TRUE
  )

  if (inherits(opt, "try-error") || any(!is.finite(opt$par))) {
    state$diagnostics$last_sigmagam_refresh_ok <- FALSE
    return(state)
  }

  H <- try(numDeriv::hessian(function(z) fn_neg(z), x = opt$par), silent = TRUE)
  if (inherits(H, "try-error") || any(!is.finite(H))) {
    H <- diag(1e-6, 2L)
  }
  H <- 0.5 * (H + t(H))

  eg <- eigen(H, symmetric = TRUE)
  vals <- pmax(eg$values, 1e-8)
  Hpd <- eg$vectors %*% (diag(vals, 2L) %*% t(eg$vectors))
  Hpd <- 0.5 * (Hpd + t(Hpd))
  Sigma <- solve(Hpd)
  Sigma <- 0.5 * (Sigma + t(Sigma))

  eta_hat <- as.numeric(opt$par[1L])
  ell_hat <- as.numeric(opt$par[2L])

  xis <- .online_compute_xi(
    eta_hat = eta_hat,
    ell_hat = ell_hat,
    Sigma = Sigma,
    p0 = state$p0,
    gamma_bounds = state$gamma_bounds,
    log_prior_gamma_fun = state$log_prior_gamma_fun
  )

  state$qsiggam$eta_hat <- eta_hat
  state$qsiggam$ell_hat <- ell_hat
  state$qsiggam$Sigma <- Sigma
  state$qsiggam$gamma_mean <- state$gamma_bounds[1L] +
    (state$gamma_bounds[2L] - state$gamma_bounds[1L]) * plogis(eta_hat)
  state$qsiggam$sigma_mean <- exp(ell_hat)
  state$qsiggam$xi <- xis
  state$xis <- xis

  state$diagnostics$last_sigmagam_refresh_ok <- TRUE
  state$diagnostics$last_sigmagam_n <- as.integer(n_eff)
  state
}

#' Initialize online VB-LD state for single-quantile exAL readout
#'
#' Builds an online state from an initial batch fit (`exal_ldvb_fit`) and stores
#' sufficient statistics needed for streaming updates.
#'
#' @param y Numeric vector for initialization window.
#' @param X Numeric design matrix for initialization window.
#' @param p0 Single quantile in (0,1).
#' @param gamma_bounds Numeric length-2 bounds for gamma.
#' @param control List with online controls (`M`, `K`, `W`, `L_loc`,
#'   `window_passes`, `maxit_sigmagam`, `jitter`).
#' @param batch_fit Optional precomputed `exal_vb` fit from `exal_ldvb_fit`.
#' @param vb_control Batch VB control used only if `batch_fit` is `NULL`.
#' @param init Initial values list forwarded to `exal_ldvb_fit` if needed.
#' @param prior_gamma Gamma prior config (list).
#' @param prior_sigma Sigma prior config (list).
#' @param beta_prior_obj Beta prior object from `beta_prior()`.
#' @return Object of class `exal_online_vbld_state`.
#' @export
exal_online_init <- function(y, X, p0, gamma_bounds,
                             control = list(),
                             batch_fit = NULL,
                             vb_control = list(),
                             init = list(),
                             prior_gamma = list(mu0 = 0, s20 = 10),
                             prior_sigma = list(a = 1, b = 1),
                             beta_prior_obj = NULL) {
  assert_matrix(X, "X")
  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")

  gamma_bounds <- as.numeric(gamma_bounds)
  if (length(gamma_bounds) != 2L || !all(is.finite(gamma_bounds)) || !(gamma_bounds[1L] < gamma_bounds[2L])) {
    .stopf("gamma_bounds must be finite length-2 with lower < upper.")
  }

  n <- nrow(X)
  k <- ncol(X)

  ctrl <- list(
    M = .online_as_int(control$M, 5L),
    K = .online_as_int(control$K, 20L),
    W = .online_as_int(control$W, 0L),
    L_loc = .online_as_int(control$L_loc, 2L),
    window_passes = .online_as_int(control$window_passes, 1L),
    maxit_sigmagam = .online_as_int(control$maxit_sigmagam, 500L),
    jitter = .online_as_num(control$jitter, 1e-10)
  )
  if (ctrl$M < 0L) ctrl$M <- 0L
  if (ctrl$K < 0L) ctrl$K <- 0L
  if (ctrl$W < 0L) ctrl$W <- 0L
  if (ctrl$L_loc < 1L) ctrl$L_loc <- 1L
  if (ctrl$window_passes < 0L) ctrl$window_passes <- 0L
  if (!is.finite(ctrl$jitter) || ctrl$jitter <= 0) ctrl$jitter <- 1e-10

  if (is.null(beta_prior_obj)) {
    if (!is.null(batch_fit$beta_prior$type)) {
      if (identical(batch_fit$beta_prior$type, "rhs")) {
        beta_prior_obj <- beta_prior("rhs", rhs = batch_fit$beta_prior$hypers %||% list())
      } else {
        tau2 <- as.numeric(batch_fit$beta_prior$hypers$tau2 %||% 1e4)[1L]
        beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = tau2))
      }
    } else {
      beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = 1e4))
    }
  }

  if (is.null(batch_fit)) {
    vb_control <- modifyList(list(max_iter = 150L, tol = 1e-4, tol_par = 1e-4, verbose = FALSE), vb_control)
    batch_fit <- exal_ldvb_fit(
      y = y,
      X = X,
      p0 = p0,
      gamma_bounds = gamma_bounds,
      vb_control = vb_control,
      init = init %||% list(),
      prior_gamma = prior_gamma,
      prior_sigma = prior_sigma,
      beta_prior_obj = beta_prior_obj
    )
  }

  if (is.null(batch_fit$qbeta) || is.null(batch_fit$qsiggam)) {
    .stopf("batch_fit must be an exal_vb-like object with qbeta and qsiggam.")
  }

  qbeta <- list(m = as.numeric(batch_fit$qbeta$m), V = as.matrix(batch_fit$qbeta$V))
  if (length(qbeta$m) != k || !all(dim(qbeta$V) == c(k, k))) .stopf("batch_fit$qbeta has incompatible dimensions.")

  beta_state <- batch_fit$beta_prior$state %||% beta_prior_obj$init(k)
  prec_diag <- as.numeric(beta_prior_obj$expected_prec(beta_state, k))
  if (length(prec_diag) != k || any(!is.finite(prec_diag)) || any(prec_diag <= 0)) {
    .stopf("online init: invalid prior precision from beta_prior_obj$expected_prec.")
  }

  qsiggam <- list(
    eta_hat = as.numeric(batch_fit$qsiggam$eta_hat),
    ell_hat = as.numeric(batch_fit$qsiggam$ell_hat),
    Sigma = as.matrix(batch_fit$qsiggam$Sigma)
  )
  if (!all(dim(qsiggam$Sigma) == c(2L, 2L))) .stopf("batch_fit$qsiggam$Sigma must be 2x2.")

  log_prior_gamma_fun <- .online_build_log_prior_gamma(prior_gamma)
  xis <- batch_fit$qsiggam$xi %||% .online_compute_xi(
    eta_hat = qsiggam$eta_hat,
    ell_hat = qsiggam$ell_hat,
    Sigma = qsiggam$Sigma,
    p0 = p0,
    gamma_bounds = gamma_bounds,
    log_prior_gamma_fun = log_prior_gamma_fun
  )

  v_m <- as.numeric(batch_fit$qv$m %||% batch_fit$qv$E_v %||% rep(1, n))
  v_inv <- as.numeric(batch_fit$qv$m_inv %||% batch_fit$qv$E_inv_v %||% rep(1, n))
  s_m <- as.numeric(batch_fit$qs$m %||% batch_fit$qs$E_s %||% rep(sqrt(2 / pi), n))
  s_m2 <- as.numeric(batch_fit$qs$m2 %||% batch_fit$qs$E_s2 %||% rep(1, n))

  if (length(v_m) != n) v_m <- rep(1, n)
  if (length(v_inv) != n) v_inv <- rep(1, n)
  if (length(s_m) != n) s_m <- rep(sqrt(2 / pi), n)
  if (length(s_m2) != n) s_m2 <- rep(1, n)

  v_m <- pmax(v_m, 1e-12)
  v_inv <- pmax(v_inv, 1e-12)
  s_m <- pmax(s_m, 1e-12)
  s_m2 <- pmax(s_m2, s_m^2 + 1e-12)

  barw <- as.numeric(xis$xi1) * v_inv
  barm <- as.numeric(y * xis$xi1 * v_inv - xis$xi_lambda * s_m * v_inv - xis$xi_A)
  barw <- pmax(barw, 1e-16)

  Xw <- X * sqrt(barw)
  S <- crossprod(Xw)
  g <- as.numeric(crossprod(X, barm))

  P <- 0.5 * (S + t(S)) + diag(prec_diag, k)
  h <- as.numeric(g)

  y_scale <- stats::mad(y, constant = 1.4826)
  y_scale <- if (is.finite(y_scale) && y_scale > 0) y_scale else stats::sd(y)
  y_scale <- if (is.finite(y_scale) && y_scale > 0) y_scale else 1

  sigma_min <- max(1e-6, y_scale * 1e-3)
  sigma_max <- max(sigma_min * 10, y_scale * 1e3)

  state <- list(
    p0 = as.numeric(p0),
    gamma_bounds = gamma_bounds,
    eta_bounds = c(-12, 12),
    ell_bounds = c(log(sigma_min), log(sigma_max)),
    k = as.integer(k),
    t_current = as.integer(n),

    control = ctrl,

    prior_gamma = prior_gamma,
    prior_sigma = prior_sigma,
    log_prior_gamma_fun = log_prior_gamma_fun,

    beta_prior_obj = beta_prior_obj,
    beta_state = beta_state,
    prec_diag = prec_diag,

    qbeta = list(m = rep(0, k), V = diag(1, k)),
    qsiggam = list(
      eta_hat = qsiggam$eta_hat,
      ell_hat = qsiggam$ell_hat,
      Sigma = qsiggam$Sigma,
      gamma_mean = gamma_bounds[1L] + (gamma_bounds[2L] - gamma_bounds[1L]) * plogis(qsiggam$eta_hat),
      sigma_mean = exp(qsiggam$ell_hat)
    ),
    xis = xis,

    S = S,
    g = as.numeric(g),
    P = P,
    h = h,
    chol_P = NULL,

    history = list(
      y = as.numeric(y),
      X = as.matrix(X),
      v_m = as.numeric(v_m),
      v_inv = as.numeric(v_inv),
      s_m = as.numeric(s_m),
      s_m2 = as.numeric(s_m2),
      barw = as.numeric(barw),
      barm = as.numeric(barm)
    ),

    refresh_counts = list(rhs = 0L, sigmagam = 0L, window_backfit = 0L),
    diagnostics = list(
      last_sigmagam_refresh_ok = NA,
      last_sigmagam_n = NA_integer_,
      last_barw = tail(barw, 1L),
      last_barm = tail(barm, 1L)
    )
  )

  state <- .online_update_beta_from_natural(state)
  state$qsiggam$xi <- state$xis

  class(state) <- c("exal_online_vbld_state", "list")
  state
}

#' Single online VB-LD update step (single quantile)
#'
#' Updates local factors for one new datum, updates beta natural parameters,
#' and applies scheduled global refresh hooks for RHS and `(sigma,gamma)`.
#'
#' @param state Online state from `exal_online_init()`.
#' @param y_t New scalar response.
#' @param x_t New design row, length equal to readout dimension.
#' @param update_rhs Logical; whether to apply scheduled RHS refresh.
#' @param update_sigmagam Logical; whether to apply scheduled `(sigma,gamma)` refresh.
#' @return Updated `exal_online_vbld_state`.
#' @export
exal_online_step <- function(state, y_t, x_t,
                             update_rhs = TRUE,
                             update_sigmagam = TRUE) {
  .online_assert_state(state)

  x_t <- as.numeric(x_t)
  y_t <- as.numeric(y_t)[1L]
  if (!is.finite(y_t)) .stopf("online step requires finite y_t.")
  if (length(x_t) != state$k) .stopf("online step: x_t length mismatch (expected %d).", state$k)
  if (any(!is.finite(x_t))) .stopf("online step: x_t contains non-finite values.")

  loc <- .online_local_update_one(
    y_t = y_t,
    x_t = x_t,
    qbeta = state$qbeta,
    xis = state$xis,
    n_alt = state$control$L_loc
  )

  # Append new history point
  state$history$y <- c(state$history$y, y_t)
  state$history$X <- rbind(state$history$X, matrix(x_t, nrow = 1L))
  state$history$v_m <- c(state$history$v_m, loc$v_m)
  state$history$v_inv <- c(state$history$v_inv, loc$v_inv)
  state$history$s_m <- c(state$history$s_m, loc$s_m)
  state$history$s_m2 <- c(state$history$s_m2, loc$s_m2)
  state$history$barw <- c(state$history$barw, loc$barw)
  state$history$barm <- c(state$history$barm, loc$barm)

  # Natural sufficient-stat updates
  state$S <- state$S + loc$barw * tcrossprod(x_t)
  state$g <- state$g + loc$barm * x_t
  state$h <- as.numeric(state$g)

  state$P <- state$S + diag(state$prec_diag, state$k)
  state <- .online_update_beta_from_natural(state)

  t_new <- as.integer(state$t_current + 1L)

  # Scheduled RHS refresh (M)
  if (isTRUE(update_rhs) && state$control$M > 0L && (t_new %% state$control$M) == 0L) {
    old_prec <- as.numeric(state$prec_diag)

    state$beta_state <- state$beta_prior_obj$update(state$beta_state, state$qbeta)
    new_prec <- as.numeric(state$beta_prior_obj$expected_prec(state$beta_state, state$k))
    if (length(new_prec) != state$k || any(!is.finite(new_prec)) || any(new_prec <= 0)) {
      .stopf("online RHS refresh produced invalid precision vector.")
    }

    state$prec_diag <- pmax(new_prec, 1e-16)
    dprec <- state$prec_diag - old_prec

    state$P <- state$P + diag(dprec, state$k)
    state$S <- state$P - diag(state$prec_diag, state$k)
    state$h <- as.numeric(state$g)
    state <- .online_update_beta_from_natural(state)

    state$refresh_counts$rhs <- as.integer(state$refresh_counts$rhs %||% 0L) + 1L
  }

  # Scheduled (sigma,gamma) refresh (K) with optional rolling window backfit
  if (isTRUE(update_sigmagam) && state$control$K > 0L && (t_new %% state$control$K) == 0L) {
    n_hist <- length(state$history$y)
    idx_refresh <- seq_len(n_hist)

    if (state$control$W > 0L) {
      w_use <- min(state$control$W, n_hist)
      idx_refresh <- seq.int(n_hist - w_use + 1L, n_hist)

      if (state$control$window_passes > 0L) {
        state <- .online_backfit_window(state, idx_refresh, n_passes = state$control$window_passes)
      }
    }

    state <- .online_refresh_sigmagam(state, idx_refresh)
    state$refresh_counts$sigmagam <- as.integer(state$refresh_counts$sigmagam %||% 0L) + 1L
  }

  state$t_current <- t_new
  state$diagnostics$last_barw <- as.numeric(loc$barw)
  state$diagnostics$last_barm <- as.numeric(loc$barm)

  class(state) <- c("exal_online_vbld_state", "list")
  state
}

#' Predict quantile location from online state
#'
#' Returns `x_t^T E_q[beta]` under the current online state.
#'
#' @param state Online state from `exal_online_init()`.
#' @param x_t Design row vector.
#' @return Numeric scalar predicted conditional quantile location.
#' @export
exal_online_predict_quantile <- function(state, x_t) {
  .online_assert_state(state)
  x_t <- as.numeric(x_t)
  if (length(x_t) != state$k) .stopf("online predict: x_t length mismatch (expected %d).", state$k)
  as.numeric(sum(x_t * state$qbeta$m))
}

#' Run online VB-LD updates over a block of new observations
#'
#' Applies `exal_online_step()` sequentially for each row in `X_new` and the
#' matching element in `y_new`.
#'
#' @param state Online state from `exal_online_init()`.
#' @param y_new Numeric vector of new responses.
#' @param X_new Numeric matrix of new design rows.
#' @param update_rhs Logical; forwarded to `exal_online_step()`.
#' @param update_sigmagam Logical; forwarded to `exal_online_step()`.
#' @param keep_trace Logical; if `TRUE`, return per-step diagnostics trace.
#' @return If `keep_trace = FALSE`, updated state; otherwise a list with
#'   `state` and `trace`.
#' @export
exal_online_run <- function(state, y_new, X_new,
                            update_rhs = TRUE,
                            update_sigmagam = TRUE,
                            keep_trace = FALSE) {
  .online_assert_state(state)
  assert_matrix(X_new, "X_new")
  if (!is.numeric(y_new) || length(y_new) != nrow(X_new)) {
    .stopf("y_new length must match nrow(X_new).")
  }
  if (ncol(X_new) != state$k) {
    .stopf("X_new must have %d columns to match state dimension.", state$k)
  }

  tr <- NULL
  if (isTRUE(keep_trace)) {
    tr <- data.frame(
      t = integer(0),
      barw = numeric(0),
      barm = numeric(0),
      rhs_refreshed = integer(0),
      sigmagam_refreshed = integer(0),
      stringsAsFactors = FALSE
    )
  }

  for (ii in seq_len(nrow(X_new))) {
    rhs0 <- as.integer(state$refresh_counts$rhs %||% 0L)
    sg0 <- as.integer(state$refresh_counts$sigmagam %||% 0L)

    state <- exal_online_step(
      state = state,
      y_t = y_new[ii],
      x_t = X_new[ii, , drop = TRUE],
      update_rhs = update_rhs,
      update_sigmagam = update_sigmagam
    )

    if (isTRUE(keep_trace)) {
      rhs1 <- as.integer(state$refresh_counts$rhs %||% 0L)
      sg1 <- as.integer(state$refresh_counts$sigmagam %||% 0L)
      tr <- rbind(
        tr,
        data.frame(
          t = as.integer(state$t_current),
          barw = as.numeric(state$diagnostics$last_barw),
          barm = as.numeric(state$diagnostics$last_barm),
          rhs_refreshed = as.integer(rhs1 > rhs0),
          sigmagam_refreshed = as.integer(sg1 > sg0),
          stringsAsFactors = FALSE
        )
      )
    }
  }

  if (isTRUE(keep_trace)) return(list(state = state, trace = tr))
  state
}

#' Online VB-LD health check summary
#'
#' Returns a compact diagnostics summary for the current online state.
#'
#' @param state Online state from `exal_online_init()`.
#' @return Named list with finite checks, SPD check, dimensions, and refresh counters.
#' @export
exal_online_health_check <- function(state) {
  .online_assert_state(state)

  P <- 0.5 * (state$P + t(state$P))
  min_eig <- tryCatch(
    min(eigen(P, symmetric = TRUE, only.values = TRUE)$values),
    error = function(e) NA_real_
  )

  is_finite_beta <- all(is.finite(state$qbeta$m)) && all(is.finite(state$qbeta$V))
  is_finite_sigmagam <- all(is.finite(c(state$qsiggam$eta_hat, state$qsiggam$ell_hat)))
  barw_positive <- all(is.finite(state$history$barw)) && all(state$history$barw > 0)
  p_spd <- is.finite(min_eig) && (min_eig > 0)

  list(
    t_current = as.integer(state$t_current),
    n_history = as.integer(length(state$history$y)),
    k = as.integer(state$k),
    min_eig_P = as.numeric(min_eig),
    P_spd = isTRUE(p_spd),
    is_finite_beta = isTRUE(is_finite_beta),
    is_finite_sigmagam = isTRUE(is_finite_sigmagam),
    barw_positive = isTRUE(barw_positive),
    rhs_refreshes = as.integer(state$refresh_counts$rhs %||% 0L),
    sigmagam_refreshes = as.integer(state$refresh_counts$sigmagam %||% 0L),
    window_backfits = as.integer(state$refresh_counts$window_backfit %||% 0L)
  )
}
