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

.online_nonneg_scalar <- function(x, default = NA_real_, cap = Inf) {
  v <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(v) || v < 0) return(as.numeric(default))
  cap <- suppressWarnings(as.numeric(cap)[1L])
  if (is.finite(cap) && cap > 0 && v > cap) return(as.numeric(default))
  as.numeric(v)
}

.online_pinball_scalar <- function(y, mu, p0) {
  u <- as.numeric(y) - as.numeric(mu)
  as.numeric(u * (p0 - as.numeric(u < 0)))
}

.online_rolling_mean <- function(x, window) {
  x <- as.numeric(x)
  n <- length(x)
  if (!n) return(numeric(0))
  w <- max(1L, as.integer(window)[1L])
  cs <- c(0, cumsum(x))
  i <- seq_len(n)
  l <- pmax(1L, i - w + 1L)
  (cs[i + 1L] - cs[l]) / as.numeric(i - l + 1L)
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

.online_local_update_one <- function(y_t, x_t, qbeta, xis,
                                     n_alt = 2L,
                                     s_init = sqrt(2 / pi),
                                     s2_init = 1) {
  x_t <- as.numeric(x_t)
  y_t <- as.numeric(y_t)[1L]

  xb <- as.numeric(sum(x_t * qbeta$m))
  qx <- as.numeric(t(x_t) %*% (qbeta$V %*% x_t))

  s_m <- pmax(as.numeric(s_init)[1L], 1e-12)
  s_m2 <- pmax(as.numeric(s2_init)[1L], s_m^2 + 1e-12)

  n_alt <- max(1L, as.integer(n_alt)[1L])

  v_m <- 1
  v_inv <- 1
  for (ii in seq_len(n_alt)) {
    qv_up <- .exal_local_qv_update(
      y = y_t,
      xb = xb,
      q_i = qx,
      qs_m = s_m,
      qs_m2 = s_m2,
      xis = xis
    )
    v_m <- as.numeric(qv_up$m)
    v_inv <- as.numeric(qv_up$m_inv)

    qs_up <- .exal_local_qs_update(
      y = y_t,
      xb = xb,
      qv_m_inv = v_inv,
      xis = xis
    )
    s_m <- as.numeric(qs_up$m)
    s_m2 <- as.numeric(qs_up$m2)
  }

  eff <- .exal_effective_barw_barm(
    y = y_t,
    xis = xis,
    qv_m_inv = v_inv,
    qs_m = s_m
  )
  barw <- as.numeric(eff$barw)
  barm <- as.numeric(eff$barm)

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

  diag <- state$diagnostics %||% list()
  diag$solve_calls <- as.integer(diag$solve_calls %||% 0L) + 1L
  diag$solve_fallbacks <- as.integer(diag$solve_fallbacks %||% 0L)
  if (identical(sol$method %||% NA_character_, "eigen_fallback")) {
    diag$solve_fallbacks <- as.integer(diag$solve_fallbacks) + 1L
  }
  eps_cap <- 1e50
  eps_raw <- suppressWarnings(as.numeric(sol$jitter_eps %||% NA_real_))
  eps <- .online_nonneg_scalar(eps_raw, default = NA_real_, cap = eps_cap)

  diag$n_jitter <- as.integer(diag$n_jitter %||% 0L)
  if (is.finite(eps) && eps > 0) {
    diag$n_jitter <- as.integer(diag$n_jitter) + 1L
  }

  diag$jitter_out_of_range <- as.integer(diag$jitter_out_of_range %||% 0L)
  if (is.finite(eps_raw) && (eps_raw < 0 || eps_raw > eps_cap)) {
    diag$jitter_out_of_range <- as.integer(diag$jitter_out_of_range) + 1L
  }

  diag$max_jitter_eps <- .online_nonneg_scalar(diag$max_jitter_eps %||% 0, default = 0, cap = eps_cap)
  if (is.finite(eps)) diag$max_jitter_eps <- max(diag$max_jitter_eps, eps)
  diag$last_solver_method <- as.character(sol$method %||% NA_character_)
  diag$last_jitter_eps <- eps
  state$diagnostics <- diag

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

  nat <- .exal_beta_natural_stats(
    X = X,
    y = y,
    xis = xis,
    qv_m_inv = v_inv,
    qs_m = s_m,
    prec_diag = prec_diag
  )
  barw <- as.numeric(nat$barw)
  barm <- as.numeric(nat$barm)
  S <- as.matrix(nat$S)
  g <- as.numeric(nat$g)
  P <- as.matrix(nat$P)
  h <- as.numeric(nat$h)

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
      last_barm = tail(barm, 1L),
      solve_calls = 0L,
      solve_fallbacks = 0L,
      n_jitter = 0L,
      max_jitter_eps = 0,
      jitter_out_of_range = 0L,
      last_solver_method = NA_character_,
      last_jitter_eps = NA_real_
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
#' @param keep_trace Logical; if `TRUE`, return per-step diagnostics trace
#'   including pre-update predictive diagnostics.
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
      y_t = numeric(0),
      yhat_pre = numeric(0),
      check_loss_pre = numeric(0),
      covered_pre = integer(0),
      barw = numeric(0),
      barm = numeric(0),
      solver_method = character(0),
      solver_fallback = integer(0),
      jitter_eps = numeric(0),
      rhs_refreshed = integer(0),
      sigmagam_refreshed = integer(0),
      stringsAsFactors = FALSE
    )
  }

  for (ii in seq_len(nrow(X_new))) {
    x_i <- X_new[ii, , drop = TRUE]
    y_i <- as.numeric(y_new[ii])
    yhat_pre <- exal_online_predict_quantile(state, x_i)
    check_loss_pre <- .online_pinball_scalar(y = y_i, mu = yhat_pre, p0 = state$p0)
    covered_pre <- as.integer(y_i <= yhat_pre)

    rhs0 <- as.integer(state$refresh_counts$rhs %||% 0L)
    sg0 <- as.integer(state$refresh_counts$sigmagam %||% 0L)

    state <- exal_online_step(
      state = state,
      y_t = y_i,
      x_t = x_i,
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
          y_t = as.numeric(y_i),
          yhat_pre = as.numeric(yhat_pre),
          check_loss_pre = as.numeric(check_loss_pre),
          covered_pre = as.integer(covered_pre),
          barw = as.numeric(state$diagnostics$last_barw),
          barm = as.numeric(state$diagnostics$last_barm),
          solver_method = as.character(state$diagnostics$last_solver_method %||% NA_character_),
          solver_fallback = as.integer(
            identical(state$diagnostics$last_solver_method %||% NA_character_, "eigen_fallback")
          ),
          jitter_eps = as.numeric(state$diagnostics$last_jitter_eps %||% NA_real_),
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

#' Summarize online predictive diagnostics from a trace
#'
#' Computes empirical coverage and check-loss summaries, including rolling-window
#' diagnostics, from a trace produced by `exal_online_run(keep_trace = TRUE)`.
#'
#' @param trace Data frame trace from `exal_online_run()`.
#' @param p0 Target quantile level in (0,1).
#' @param rolling_window Rolling window size for diagnostic summaries.
#' @param target_coverage Optional target coverage. If `NULL`, uses `p0`.
#' @return Named list with aggregate and rolling diagnostic summaries.
#' @export
exal_online_trace_diagnostics <- function(trace, p0, rolling_window = 50L, target_coverage = NULL) {
  if (!is.data.frame(trace)) .stopf("trace must be a data.frame from exal_online_run().")
  req <- c("check_loss_pre", "covered_pre")
  miss <- setdiff(req, names(trace))
  if (length(miss)) {
    .stopf("trace is missing required columns: %s", paste(miss, collapse = ", "))
  }
  assert_scalar_numeric(p0, "p0")
  if (!(p0 > 0 && p0 < 1)) .stopf("p0 must be in (0,1).")

  cl <- as.numeric(trace$check_loss_pre)
  cv <- as.numeric(trace$covered_pre)
  ok <- is.finite(cl) & is.finite(cv)
  cl <- cl[ok]
  cv <- cv[ok]
  n <- length(cl)
  if (!n) {
    return(list(
      n = 0L,
      coverage_mean = NA_real_,
      coverage_target = as.numeric(target_coverage %||% p0),
      coverage_gap = NA_real_,
      check_loss_mean = NA_real_,
      rolling_window = as.integer(max(1L, as.integer(rolling_window)[1L])),
      rolling_coverage_current = NA_real_,
      rolling_check_loss_current = NA_real_,
      rolling_coverage_last = numeric(0),
      rolling_check_loss_last = numeric(0)
    ))
  }

  cv <- pmax(pmin(cv, 1), 0)
  target <- as.numeric(target_coverage %||% p0)[1L]
  rw <- max(1L, as.integer(rolling_window)[1L])

  roll_cov <- .online_rolling_mean(cv, rw)
  roll_cl <- .online_rolling_mean(cl, rw)
  tail_n <- min(5L, n)

  list(
    n = as.integer(n),
    coverage_mean = as.numeric(mean(cv)),
    coverage_target = target,
    coverage_gap = as.numeric(mean(cv) - target),
    check_loss_mean = as.numeric(mean(cl)),
    rolling_window = as.integer(rw),
    rolling_coverage_current = as.numeric(tail(roll_cov, 1L)),
    rolling_check_loss_current = as.numeric(tail(roll_cl, 1L)),
    rolling_coverage_last = as.numeric(tail(roll_cov, tail_n)),
    rolling_check_loss_last = as.numeric(tail(roll_cl, tail_n))
  )
}

#' Online VB-LD health check summary
#'
#' Returns a compact diagnostics summary for the current online state.
#'
#' @param state Online state from `exal_online_init()`.
#' @param trace Optional trace from `exal_online_run(keep_trace=TRUE)`.
#' @param p0 Optional quantile level for trace diagnostics (defaults to `state$p0`).
#' @param rolling_window Rolling window for trace diagnostics.
#' @return Named list with finite checks, SPD check, dimensions, and refresh counters.
#' @export
exal_online_health_check <- function(state, trace = NULL, p0 = state$p0, rolling_window = 50L) {
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
  eps_cap <- 1e50

  solve_calls <- as.integer(state$diagnostics$solve_calls %||% 0L)
  solve_fallbacks <- as.integer(state$diagnostics$solve_fallbacks %||% 0L)
  n_jitter <- as.integer(state$diagnostics$n_jitter %||% 0L)
  jitter_out_of_range <- as.integer(state$diagnostics$jitter_out_of_range %||% 0L)
  max_jitter_eps <- .online_nonneg_scalar(state$diagnostics$max_jitter_eps %||% NA_real_, default = NA_real_, cap = eps_cap)
  last_jitter_eps <- .online_nonneg_scalar(state$diagnostics$last_jitter_eps %||% NA_real_, default = NA_real_, cap = eps_cap)

  out <- list(
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
    window_backfits = as.integer(state$refresh_counts$window_backfit %||% 0L),
    solve_calls = solve_calls,
    solve_fallbacks = solve_fallbacks,
    solve_fallback_rate = as.numeric(
      solve_fallbacks / pmax(1, solve_calls)
    ),
    n_jitter = n_jitter,
    jitter_out_of_range = jitter_out_of_range,
    max_jitter_eps = max_jitter_eps,
    last_solver_method = as.character(state$diagnostics$last_solver_method %||% NA_character_),
    last_jitter_eps = last_jitter_eps
  )

  if (!is.null(trace)) {
    out$trace_diag <- exal_online_trace_diagnostics(
      trace = trace,
      p0 = p0,
      rolling_window = rolling_window
    )
  }

  out
}

.online_pick_warm_start_n <- function(n, k, warm_start_n = NULL, warm_start_frac = 0.7) {
  n <- as.integer(n)[1L]
  k <- as.integer(k)[1L]
  if (!is.finite(n) || n < 2L) return(NA_integer_)

  min_t0 <- max(8L, k + 2L)
  if (n <= (min_t0 + 1L)) return(NA_integer_)

  t0 <- NA_integer_
  if (!is.null(warm_start_n) && length(warm_start_n)) {
    t0_raw <- suppressWarnings(as.integer(warm_start_n)[1L])
    if (is.finite(t0_raw)) t0 <- t0_raw
  }
  if (!is.finite(t0)) {
    frac <- suppressWarnings(as.numeric(warm_start_frac)[1L])
    if (!is.finite(frac) || frac <= 0 || frac >= 1) frac <- 0.7
    t0 <- as.integer(floor(frac * n))
  }

  t0 <- max(min_t0, min(t0, n - 1L))
  as.integer(t0)
}

.online_state_to_exal_vb <- function(state, p0, gamma_bounds, fit_init = NULL,
                                     trace = NULL, run_time = NA_real_,
                                     t0 = NA_integer_, control = list(),
                                     health = NULL) {
  .online_assert_state(state)
  n <- as.integer(length(state$history$y))
  k <- as.integer(state$k)

  qv <- list(
    chi = rep(NA_real_, n),
    psi = rep(NA_real_, n),
    E_v = as.numeric(state$history$v_m),
    E_inv_v = as.numeric(state$history$v_inv),
    m = as.numeric(state$history$v_m),
    m_inv = as.numeric(state$history$v_inv)
  )
  qs <- list(
    mu = rep(NA_real_, n),
    tau2 = rep(NA_real_, n),
    E_s = as.numeric(state$history$s_m),
    E_s2 = as.numeric(state$history$s_m2),
    m = as.numeric(state$history$s_m),
    m2 = as.numeric(state$history$s_m2)
  )
  qsiggam <- list(
    eta_hat = as.numeric(state$qsiggam$eta_hat),
    ell_hat = as.numeric(state$qsiggam$ell_hat),
    Sigma = as.matrix(state$qsiggam$Sigma),
    gamma_mean = as.numeric(state$qsiggam$gamma_mean),
    sigma_mean = as.numeric(state$qsiggam$sigma_mean),
    xi = state$xis
  )

  misc <- fit_init$misc %||% list()
  misc$p0 <- as.numeric(p0)[1L]
  misc$bounds <- c(L = as.numeric(gamma_bounds[1L]), U = as.numeric(gamma_bounds[2L]))
  misc$n <- n
  misc$p <- k

  online_mode <- if ((as.integer(control$W %||% 0L) > 0L) && !isTRUE(control$strict %||% FALSE)) {
    "windowed"
  } else {
    "strict"
  }
  online_misc <- list(
    enabled = TRUE,
    mode = online_mode,
    t0 = as.integer(t0),
    t_stream = as.integer(max(0L, n - as.integer(t0))),
    control = control,
    refresh_counts = state$refresh_counts,
    diagnostics = state$diagnostics
  )
  if (!is.null(health)) online_misc$health <- health
  if (!is.null(trace)) online_misc$trace <- trace
  misc$online <- online_misc

  structure(list(
    qbeta = list(m = as.numeric(state$qbeta$m), V = as.matrix(state$qbeta$V)),
    qv = qv,
    qs = qs,
    qsiggam = qsiggam,
    converged = TRUE,
    iter = n,
    run.time = as.numeric(run_time),
    beta_prior = list(
      type = state$beta_prior_obj$type,
      hypers = state$beta_prior_obj$hypers,
      state = state$beta_state
    ),
    misc = misc
  ), class = "exal_vb")
}

#' Fit exAL with optional online VB-LD updates (single quantile)
#'
#' This wrapper preserves the batch interface from `exal_ldvb_fit()` and adds an
#' optional online path controlled by `control$enabled`. When online mode is
#' enabled, the function:
#' 1) runs batch LDVB on an initialization prefix,
#' 2) streams the remaining observations through `exal_online_run()`,
#' 3) returns an `exal_vb`-compatible object so downstream offline code remains unchanged.
#'
#' @param y Numeric response vector.
#' @param X Numeric design matrix.
#' @param p0 Quantile level in (0,1).
#' @param gamma_bounds Numeric length-2 bounds for gamma.
#' @param control Online controls list:
#'   `enabled`, `strict`, `M`, `K`, `W`, `L_loc`, `window_passes`,
#'   `maxit_sigmagam`, `jitter`, `warm_start_n`, `warm_start_frac`,
#'   `keep_trace`, `update_rhs`, `update_sigmagam`.
#' @param vb_control,max_iter,tol,tol_par,n_samp_xi,verbose,init,prior_gamma,
#'   prior_gamma_mu0,prior_gamma_s20,log_prior_gamma,prior_sigma,a_sigma,b_sigma,
#'   beta_prior_obj,... Same as `exal_ldvb_fit()`.
#' @return `exal_vb` object. If online mode is enabled, diagnostics are stored
#'   in `fit$misc$online`.
#' @export
exal_online_fit <- function(y, X, p0, gamma_bounds,
                            control = list(),
                            vb_control = NULL,
                            max_iter = NULL, tol = NULL, tol_par = NULL,
                            n_samp_xi = NULL, verbose = NULL,
                            init = list(),
                            prior_gamma = NULL,
                            prior_gamma_mu0 = NULL,
                            prior_gamma_s20 = NULL,
                            log_prior_gamma = NULL,
                            prior_sigma = NULL,
                            a_sigma = NULL,
                            b_sigma = NULL,
                            beta_prior_obj = NULL,
                            ...) {
  assert_matrix(X, "X")
  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")
  gamma_bounds <- as.numeric(gamma_bounds)
  if (length(gamma_bounds) != 2L || !all(is.finite(gamma_bounds)) || !(gamma_bounds[1L] < gamma_bounds[2L])) {
    .stopf("gamma_bounds must be finite length-2 with lower < upper.")
  }
  if (!is.list(control)) .stopf("control must be a list.")

  dots <- list(...)
  fit_args <- list(
    y = y,
    X = X,
    p0 = p0,
    gamma_bounds = gamma_bounds,
    vb_control = vb_control,
    max_iter = max_iter,
    tol = tol,
    tol_par = tol_par,
    n_samp_xi = n_samp_xi,
    verbose = verbose,
    init = init,
    prior_gamma = prior_gamma,
    prior_gamma_mu0 = prior_gamma_mu0,
    prior_gamma_s20 = prior_gamma_s20,
    log_prior_gamma = log_prior_gamma,
    prior_sigma = prior_sigma,
    a_sigma = a_sigma,
    b_sigma = b_sigma,
    beta_prior_obj = beta_prior_obj
  )
  if (length(dots)) {
    for (nm in names(dots)) fit_args[[nm]] <- dots[[nm]]
  }

  ctrl <- list(
    enabled = isTRUE(control$enabled),
    strict = if (is.null(control$strict)) FALSE else isTRUE(control$strict),
    M = .online_as_int(control$M, 10L),
    K = .online_as_int(control$K, 40L),
    W = .online_as_int(control$W, 100L),
    L_loc = .online_as_int(control$L_loc, 2L),
    window_passes = .online_as_int(control$window_passes, 1L),
    maxit_sigmagam = .online_as_int(control$maxit_sigmagam, 500L),
    jitter = .online_as_num(control$jitter, 1e-10),
    warm_start_n = control$warm_start_n %||% NULL,
    warm_start_frac = .online_as_num(control$warm_start_frac, 0.7),
    keep_trace = isTRUE(control$keep_trace),
    update_rhs = if (is.null(control$update_rhs)) TRUE else isTRUE(control$update_rhs),
    update_sigmagam = if (is.null(control$update_sigmagam)) TRUE else isTRUE(control$update_sigmagam)
  )
  if (ctrl$strict) ctrl$W <- 0L
  if (!is.finite(ctrl$jitter) || ctrl$jitter <= 0) ctrl$jitter <- 1e-10
  ctrl$M <- max(0L, as.integer(ctrl$M))
  ctrl$K <- max(0L, as.integer(ctrl$K))
  ctrl$W <- max(0L, as.integer(ctrl$W))
  ctrl$L_loc <- max(1L, as.integer(ctrl$L_loc))
  ctrl$window_passes <- max(0L, as.integer(ctrl$window_passes))
  if (ctrl$K < ctrl$M) ctrl$K <- ctrl$M

  if (!isTRUE(ctrl$enabled)) {
    fit <- do.call(exal_ldvb_fit, fit_args)
    if (is.null(fit$misc)) fit$misc <- list()
    fit$misc$online <- list(
      enabled = FALSE,
      reason = "disabled",
      control = ctrl
    )
    return(fit)
  }

  n <- as.integer(nrow(X))
  k <- as.integer(ncol(X))
  t0 <- .online_pick_warm_start_n(
    n = n,
    k = k,
    warm_start_n = ctrl$warm_start_n,
    warm_start_frac = ctrl$warm_start_frac
  )
  if (!is.finite(t0)) {
    fit <- do.call(exal_ldvb_fit, fit_args)
    if (is.null(fit$misc)) fit$misc <- list()
    fit$misc$online <- list(
      enabled = FALSE,
      reason = "insufficient_n_for_streaming",
      control = ctrl
    )
    return(fit)
  }

  fit_init_args <- fit_args
  fit_init_args$y <- y[seq_len(t0)]
  fit_init_args$X <- X[seq_len(t0), , drop = FALSE]

  prior_gamma_use <- prior_gamma %||% list()
  if (!is.list(prior_gamma_use)) prior_gamma_use <- list()
  if (!is.null(prior_gamma_mu0)) prior_gamma_use$mu0 <- as.numeric(prior_gamma_mu0)[1L]
  if (!is.null(prior_gamma_s20)) prior_gamma_use$s20 <- as.numeric(prior_gamma_s20)[1L]
  if (!is.null(log_prior_gamma) && is.function(log_prior_gamma)) {
    prior_gamma_use$log_prior <- log_prior_gamma
  }

  prior_sigma_use <- prior_sigma %||% list()
  if (!is.list(prior_sigma_use)) prior_sigma_use <- list()
  if (!is.null(a_sigma)) prior_sigma_use$a <- as.numeric(a_sigma)[1L]
  if (!is.null(b_sigma)) prior_sigma_use$b <- as.numeric(b_sigma)[1L]
  if (is.null(prior_sigma_use$a)) prior_sigma_use$a <- 1
  if (is.null(prior_sigma_use$b)) prior_sigma_use$b <- 1

  t_start <- proc.time()[3]
  fit_init <- do.call(exal_ldvb_fit, fit_init_args)
  st <- exal_online_init(
    y = y[seq_len(t0)],
    X = X[seq_len(t0), , drop = FALSE],
    p0 = p0,
    gamma_bounds = gamma_bounds,
    control = list(
      M = ctrl$M,
      K = ctrl$K,
      W = ctrl$W,
      L_loc = ctrl$L_loc,
      window_passes = ctrl$window_passes,
      maxit_sigmagam = ctrl$maxit_sigmagam,
      jitter = ctrl$jitter
    ),
    batch_fit = fit_init,
    prior_gamma = prior_gamma_use,
    prior_sigma = prior_sigma_use,
    beta_prior_obj = beta_prior_obj
  )

  idx_new <- if (t0 < n) seq.int(t0 + 1L, n) else integer(0)
  trace <- NULL
  if (length(idx_new)) {
    run_out <- exal_online_run(
      state = st,
      y_new = y[idx_new],
      X_new = X[idx_new, , drop = FALSE],
      update_rhs = ctrl$update_rhs,
      update_sigmagam = ctrl$update_sigmagam,
      keep_trace = ctrl$keep_trace
    )
    if (isTRUE(ctrl$keep_trace)) {
      st <- run_out$state
      trace <- run_out$trace
    } else {
      st <- run_out
    }
  }
  run_time <- as.numeric(proc.time()[3] - t_start)

  health <- exal_online_health_check(
    state = st,
    trace = trace,
    p0 = p0,
    rolling_window = max(10L, min(100L, n - t0))
  )
  fit <- .online_state_to_exal_vb(
    state = st,
    p0 = p0,
    gamma_bounds = gamma_bounds,
    fit_init = fit_init,
    trace = trace,
    run_time = run_time,
    t0 = t0,
    control = ctrl,
    health = health
  )
  fit
}
