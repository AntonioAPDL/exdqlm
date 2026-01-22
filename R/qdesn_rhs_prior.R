# ------------------------------------------------------------------------------
# Regularized Horseshoe (RHS) prior block for beta: coordinate-wise Laplace on log-scales
# Engine interface (unchanged):
#   init(p), expected_prec(state,p), update(state,qbeta), elbo(state,qbeta)
#
# IMPORTANT CHANGE (2025-12-17):
#   Diagonal curvature (second derivatives) is computed in CLOSED FORM.
#   No finite-difference second derivatives are used.
#   Optimization (optimize / fallback optim) is still used to find modes.
# ------------------------------------------------------------------------------

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (!is.null(x)) x else y
}
if (!exists(".stopf", mode = "function")) {
  .stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)
}

# stable log(1+.safe_exp(x)) without ifelse() double-eval
.log1p_exp <- function(x) {
  x <- as.numeric(x)
  out <- numeric(length(x))
  pos <- x > 0
  out[pos]  <- x[pos] + log1p(.safe_exp(-x[pos]))
  out[!pos] <- log1p(.safe_exp(x[!pos]))
  out
}

# safe exp with clamping to avoid overflow/underflow
.safe_exp <- function(x) {
  x <- as.numeric(x)
  # log(.Machine$double.xmax) ~ 709.78, log(.Machine$double.xmin) ~ -708.39
  exp(pmin(pmax(x, -745), 709))
}


# stable log(.safe_exp(a)+.safe_exp(b)) with vector support
.logsumexp2 <- function(a, b) {
  m <- pmax(a, b)
  m + log(.safe_exp(a - m) + .safe_exp(b - m))
}

# ---- 1D maximize (mode only) ----
# (keeps the same "optimize then fallback optim" behavior as before, but no curvature FD)
.opt_1d_mode <- function(f, lo, hi, eta0 = NULL, diag_env = NULL, tag = NULL) {
  if (!is.finite(lo) || !is.finite(hi) || !(lo < hi)) .stopf(".opt_1d_mode: invalid bounds.")
  if (is.null(eta0) || !is.finite(eta0)) eta0 <- 0

  if (!is.null(diag_env)) {
    diag_env$n_calls <- (diag_env$n_calls %||% 0L) + 1L
  }

  obj0 <- try(f(eta0), silent = TRUE)
  if (inherits(obj0, "try-error") || !is.finite(obj0)) obj0 <- NA_real_

  used_fallback <- FALSE
  opt_method <- "optimize"
  opt <- try(optimize(f, interval = c(lo, hi), maximum = TRUE), silent = TRUE)
  if (inherits(opt, "try-error") || !is.finite(opt$objective)) {
    used_fallback <- TRUE
    opt_method <- "optim_bfgs"
    if (!is.null(diag_env)) {
      diag_env$n_fallback <- (diag_env$n_fallback %||% 0L) + 1L
      diag_env$n_grid <- (diag_env$n_grid %||% 0L) + 1L
    }
    grid <- seq(lo, hi, length.out = 31)
    vals <- vapply(grid, f, numeric(1))
    j0 <- which.max(vals)
    par0 <- grid[j0]

    fn_neg <- function(z) {
      v <- f(z)
      if (!is.finite(v)) 1e100 else -v
    }
    opt2 <- try(optim(par = par0, fn = fn_neg, method = "BFGS",
                      control = list(maxit = 2000)), silent = TRUE)
    mode_raw <- if (inherits(opt2, "try-error") || !is.finite(opt2$value)) par0 else opt2$par
  } else {
    mode_raw <- opt$maximum
  }

  mode <- pmin(pmax(mode_raw, lo), hi)
  tol <- 1e-8
  hit_bounds <- abs(mode - lo) <= tol || abs(mode - hi) <= tol
  clipped <- is.finite(mode_raw) && is.finite(mode) && (mode_raw != mode)

  obj_mode <- try(f(mode), silent = TRUE)
  if (inherits(obj_mode, "try-error") || !is.finite(obj_mode)) obj_mode <- NA_real_

  if (!is.null(diag_env)) {
    if (hit_bounds) {
      diag_env$n_hit_bounds <- (diag_env$n_hit_bounds %||% 0L) + 1L
    }
    if (!is.null(tag)) {
      entry <- list(
        tag = tag,
        eta0 = eta0,
        lo = lo,
        hi = hi,
        obj0 = obj0,
        mode_raw = mode_raw,
        mode = mode,
        obj_mode = obj_mode,
        obj_improved = if (is.finite(obj_mode) && is.finite(obj0)) (obj_mode > obj0) else NA,
        method = opt_method,
        used_fallback = used_fallback,
        hit_bounds = hit_bounds,
        clipped = clipped,
        clip_before_eval = clipped,
        n_iter = NA_integer_,
        n_backtrack = NA_integer_,
        n_step_halving = NA_integer_
      )
      diag_env$last_by_tag <- diag_env$last_by_tag %||% list()
      diag_env$last_by_tag[[tag]] <- entry
    }
  }
  mode
}

# ---- RHS objective in eta-space ----
# eta_lambda_j = log lambda_j
# eta_tau      = log tau
# eta_c2       = log c^2
#
# This matches your document:
#   g_j = .safe_exp(-eta_c2) + .safe_exp(-u_j), with u_j = 2(eta_tau + eta_lambda_j)
#   f_j contributes: 0.5 log g_j - 0.5 S_j g_j + (log prior terms on eta)
rhs_obj_eta <- function(eta_lambda, eta_tau, eta_c2, beta2,
                        tau0 = 1.0, nu = 4.0, s = 1.0,
                        shrink_intercept = TRUE) {

  if (!isTRUE(shrink_intercept)) {
    if (length(beta2) >= 2L) {
      eta_lambda <- eta_lambda[-1L]
      beta2      <- beta2[-1L]
    } else {
      eta_lambda <- numeric(0)
      beta2      <- numeric(0)
    }
  }

  u <- 2 * eta_tau + 2 * eta_lambda

  # logV = log( tau^2 * c^2 * lambda^2 / (c^2 + tau^2 lambda^2) )
  ld   <- .logsumexp2(eta_c2, u)
  logV <- eta_c2 + u - ld

  # invV = .safe_exp(-eta_c2) + .safe_exp(-u) computed stably via log-sum-exp
  log_invV <- .logsumexp2(-eta_c2, -u)
  invV <- .safe_exp(log_invV)

  # guard: beta2 * invV can overflow in extreme cases
  term_quad <- beta2 * invV
  term_quad[!is.finite(term_quad)] <- .Machine$double.xmax

  like <- -0.5 * sum(logV + term_quad)

  # Half-Cauchy on lambda: lp = eta - log(1+.safe_exp(2 eta)) (+const)
  lp_lam <- sum(eta_lambda - .log1p_exp(2 * eta_lambda))

  # Half-Cauchy on tau with scale tau0: lp = eta_tau - log(1+.safe_exp(2(eta_tau-logtau0))) (+const)
  logtau0 <- log(tau0)
  lp_tau <- eta_tau - .log1p_exp(2 * (eta_tau - logtau0))

  # IG on c^2 with shape nu/2 and scale nu*s^2/2, on eta=log c^2:
  # lp = -(nu/2) eta - (nu s^2)/(2 .safe_exp(eta)) (+const)
  lp_c2 <- -(nu / 2) * eta_c2 - (nu * s^2) / (2 * .safe_exp(eta_c2))

  out <- like + lp_lam + lp_tau + lp_c2
  if (!is.finite(out)) out <- -1e300
  out

}

# ---- Closed-form diagonal second derivatives (curvature) ----
# These match the objective above and your derivations.
rhs_d2_lambda_j <- function(eta_lambda_j, eta_tau, eta_c2, beta2_j) {
  u  <- 2 * (eta_tau + eta_lambda_j)
  a  <- eta_c2
  ld <- .logsumexp2(a, u)
  w  <- .safe_exp(u - ld)            # w = .safe_exp(u)/(.safe_exp(a)+.safe_exp(u))
  w1w <- w * (1 - w)
  t  <- .safe_exp(-u)                # .safe_exp(-u) = 1/(tau^2 lambda^2)

  # From -0.5 logV term: + 2*w(1-w)
  # From -0.5 beta2 invV term: - 2*beta2*.safe_exp(-u)
  d2_like <- 2 * w1w - 2 * beta2_j * t

  # Half-Cauchy on lambda: d2 = -4 * sigmoid(2eta) * (1-sigmoid(2eta))
  s <- plogis(2 * eta_lambda_j)
  d2_prior <- -4 * s * (1 - s)

  d2_like + d2_prior
}

rhs_d2_tau <- function(eta_lambda, eta_tau, eta_c2, beta2, tau0) {
  u  <- 2 * eta_tau + 2 * eta_lambda
  a  <- eta_c2
  ld <- .logsumexp2(a, u)
  w  <- .safe_exp(u - ld)
  w1w <- w * (1 - w)
  t  <- .safe_exp(-u)

  d2_like <- sum(2 * w1w - 2 * beta2 * t)

  logtau0 <- log(tau0)
  s <- plogis(2 * (eta_tau - logtau0))
  d2_prior <- -4 * s * (1 - s)

  d2_like + d2_prior
}

rhs_d2_c2 <- function(eta_lambda, eta_tau, eta_c2, beta2, nu, s) {
  u  <- 2 * eta_tau + 2 * eta_lambda
  a  <- eta_c2
  ld <- .logsumexp2(a, u)
  w  <- .safe_exp(u - ld)
  w1w <- w * (1 - w)

  r <- .safe_exp(-eta_c2)  # .safe_exp(-eta_c2) = 1/c^2

  # From -0.5 logV term: +0.5*w(1-w)
  # From -0.5 beta2 invV term: -0.5*beta2*.safe_exp(-eta_c2)
  d2_like <- 0.5 * sum(w1w) - 0.5 * r * sum(beta2)

  # IG prior term second derivative: -(nu s^2)/2 * .safe_exp(-eta_c2)
  d2_prior <- -(nu * s^2) / 2 * r

  d2_like + d2_prior
}

# ---- First derivative wrt eta_tau (for diagnostics) ----
rhs_grad_tau <- function(eta_lambda, eta_tau, eta_c2, beta2, tau0) {
  u  <- 2 * eta_tau + 2 * eta_lambda
  a  <- eta_c2
  w  <- .safe_exp(u - .logsumexp2(a, u))
  t  <- .safe_exp(-u)
  logtau0 <- log(tau0)
  s <- plogis(2 * (eta_tau - logtau0))
  -sum(1 - w) + sum(beta2 * t) + (1 - 2 * s)
}

# ---- Full Hessian (closed form) for f(eta) in (u_j, u_tau, u_kappa) space ----
# Matches your document:
#   g_j = .safe_exp(-2u_j-2u_tau) + .safe_exp(-u_kappa) = T_j + R
#   f_j = 0.5 log g_j - 0.5 S_j g_j - log(1+.safe_exp(2u_j)) + u_j
#   f_global adds only to (u_tau,u_tau) and (u_kappa,u_kappa)
#
# We build the FULL Hessian in the active coordinates and invert -H.

.rhs_hess_active <- function(eta_lambda, eta_tau, eta_c2, S,
                             tau0, nu, s,
                             shrink_intercept = TRUE) {
  p <- length(eta_lambda)
  if (length(S) != p) .stopf(".rhs_hess_active: S length mismatch.")

  # active lambdas (drop intercept scale if not shrunk)
  idx <- if (isTRUE(shrink_intercept)) seq_len(p) else if (p >= 2L) 2L:p else integer(0)
  k <- length(idx)
  d <- k + 2L

  H <- matrix(0, d, d)

  # global indices within active block
  itau <- k + 1L
  ikap <- k + 2L

  # constants for global tau prior
  logtau0 <- log(tau0)

  # shared logr for R = .safe_exp(-u_kappa)
  logr <- -eta_c2
  r <- .safe_exp(logr)

  # global prior second derivatives
  s_tau <- plogis(2 * (eta_tau - logtau0))
  d2_tau_prior <- -4 * s_tau * (1 - s_tau)

  d2_kap_prior <- -(nu * s^2) / 2 * r

  # loop over active j
  for (a in seq_len(k)) {
    j <- idx[a]
    uj <- eta_lambda[j]
    Sj <- S[j]

    # T_j = .safe_exp(-2u_j-2u_tau)
    logt <- -2 * (uj + eta_tau)
    t <- .safe_exp(logt)

    # g = t + r via log-sum-exp
    logg <- .logsumexp2(logt, logr)
    g <- .safe_exp(logg)

    # weights w_t = t/g, w_r = r/g in a stable way
    w_t <- .safe_exp(logt - logg)
    w_r <- .safe_exp(logr - logg)
    a_wr <- w_t * w_r  # in [0,1/4]

    # Hessian pieces for this j in coordinates (u_j, u_tau, u_kappa)
    # From 0.5 * log g:
    #   H_log = 0.5 * a_wr * [[4,4,-2],[4,4,-2],[-2,-2,1]]
    h11_log <- 2 * a_wr
    h12_log <- 2 * a_wr
    h13_log <- -1 * a_wr
    h22_log <- 2 * a_wr
    h23_log <- -1 * a_wr
    h33_log <- 0.5 * a_wr

    # From -0.5 * S_j * g:
    #   Hess(g) block = [[4t,4t,0],[4t,4t,0],[0,0,r]]
    h11_g <- -0.5 * Sj * (4 * t)
    h12_g <- -0.5 * Sj * (4 * t)
    h22_g <- -0.5 * Sj * (4 * t)
    h33_g <- -0.5 * Sj * r

    # From u_j - log(1+.safe_exp(2u_j)) prior term:
    sj <- plogis(2 * uj)
    d2_lam_prior <- -4 * sj * (1 - sj)

    # assemble local 3x3
    h11 <- h11_log + h11_g + d2_lam_prior
    h12 <- h12_log + h12_g
    h13 <- h13_log              # g term cross is 0
    h22 <- h22_log + h22_g
    h23 <- h23_log              # g term cross is 0
    h33 <- h33_log + h33_g

    # place into H
    ia <- a
    H[ia, ia]     <- H[ia, ia]     + h11
    H[ia, itau]   <- H[ia, itau]   + h12
    H[itau, ia]   <- H[itau, ia]   + h12
    H[ia, ikap]   <- H[ia, ikap]   + h13
    H[ikap, ia]   <- H[ikap, ia]   + h13

    H[itau, itau] <- H[itau, itau] + h22
    H[itau, ikap] <- H[itau, ikap] + h23
    H[ikap, itau] <- H[ikap, itau] + h23

    H[ikap, ikap] <- H[ikap, ikap] + h33
  }

  # add global priors (tau, kappa) second derivatives
  H[itau, itau] <- H[itau, itau] + d2_tau_prior
  H[ikap, ikap] <- H[ikap, ikap] + d2_kap_prior

  # symmetrize hard (numerical noise)
  H <- 0.5 * (H + t(H))

  list(H = H, idx = idx, k = k)
}

.inv_spd_with_jitter <- function(K, var_floor, max_tries = 12L) {
  # K should be SPD. If not, add diagonal jitter until chol succeeds.
  d <- nrow(K)
  if (!all(dim(K) == c(d, d))) .stopf(".inv_spd_with_jitter: K not square.")

  jitter <- 0
  for (tt in seq_len(max_tries)) {
    KK <- K
    if (jitter > 0) diag(KK) <- diag(KK) + jitter

    R <- try(chol(KK), silent = TRUE)
    if (!inherits(R, "try-error")) {
      inv <- chol2inv(R)
      dR <- diag(R)
      logdet <- 2 * sum(log(dR))
      return(list(inv = inv, logdet = logdet, jitter = jitter,
                  chol_diag_min = min(dR), chol_diag_max = max(dR)))
    }

    # escalate jitter
    jitter <- if (tt == 1L) max(var_floor, 1e-16) else jitter * 10
  }

  # last resort: add a big ridge and do a generic solve
  KK <- K + diag(max(1e-16, var_floor), d)
  inv <- solve(KK)
  # logdet via eigen (fallback)
  ev <- eigen(KK, symmetric = TRUE, only.values = TRUE)$values
  ev <- pmax(ev, 1e-300)
  logdet <- sum(log(ev))
  list(inv = inv, logdet = logdet, jitter = NA_real_,
       chol_diag_min = NA_real_, chol_diag_max = NA_real_)
}

.embed_sigma_full <- function(Sigma_active, idx, p, var_floor) {
  # Full Sigma in coordinates (u_1..u_p, u_tau, u_kappa) => (p+2)x(p+2)
  Sigma_full <- matrix(0, p + 2L, p + 2L)
  diag(Sigma_full) <- var_floor

  k <- length(idx)
  itauA <- k + 1L
  ikapA <- k + 2L

  # map active lambda block
  if (k > 0) {
    Sigma_full[idx, idx] <- Sigma_active[seq_len(k), seq_len(k), drop = FALSE]

    # cov with tau
    Sigma_full[idx, p + 1L] <- Sigma_active[seq_len(k), itauA]
    Sigma_full[p + 1L, idx] <- Sigma_active[itauA, seq_len(k)]

    # cov with kappa
    Sigma_full[idx, p + 2L] <- Sigma_active[seq_len(k), ikapA]
    Sigma_full[p + 2L, idx] <- Sigma_active[ikapA, seq_len(k)]
  }

  # tau/kappa 2x2
  Sigma_full[p + 1L, p + 1L] <- Sigma_active[itauA, itauA]
  Sigma_full[p + 2L, p + 2L] <- Sigma_active[ikapA, ikapA]
  Sigma_full[p + 1L, p + 2L] <- Sigma_active[itauA, ikapA]
  Sigma_full[p + 2L, p + 1L] <- Sigma_active[ikapA, itauA]

  Sigma_full
}

qdesn_rhs_prior_obj <- function(
  hypers = list(tau0 = 1, nu = 4, s = 1,
                shrink_intercept = TRUE,
                intercept_prec = 1e-16),
  init = list(lambda = 1, tau = NULL, c2 = NULL),
  control = list(n_inner = 1L,
                 eta_bounds = list(lambda = c(-40, 40),
                                   tau    = c(-40, 40),
                                   c2     = c(-40, 40)),
                 h_curv = 1e-16,      # unused, kept for compatibility
                 var_floor = 1e-16,
                 verbose = FALSE)
) {
  tau0 <- as.numeric(hypers$tau0 %||% 1)[1]
  nu   <- as.numeric(hypers$nu   %||% 4)[1]
  s    <- as.numeric(hypers$s    %||% 1)[1]

  if (!is.finite(tau0) || tau0 <= 0) .stopf("RHS hypers$tau0 must be > 0.")
  if (!is.finite(nu)   || nu   <= 0) .stopf("RHS hypers$nu must be > 0.")
  if (!is.finite(s)    || s    <= 0) .stopf("RHS hypers$s must be > 0.")

  shrink_intercept <- isTRUE(hypers$shrink_intercept %||% TRUE)
  intercept_prec   <- as.numeric(hypers$intercept_prec %||% 1e-16)[1]
  if (!is.finite(intercept_prec) || intercept_prec <= 0) intercept_prec <- 1e-16

  n_inner   <- as.integer(control$n_inner %||% 1L)
  verbose   <- isTRUE(control$verbose %||% FALSE)
  var_floor <- as.numeric(control$var_floor %||% 1e-16)[1]
  if (!is.finite(var_floor) || var_floor <= 0) var_floor <- 1e-16

  # keep but do not use (compat)
  h_curv <- as.numeric(control$h_curv %||% 1e-16)[1]

  bnds  <- control$eta_bounds %||% list()
  b_lam <- as.numeric(bnds$lambda %||% c(-40, 40))
  b_tau <- as.numeric(bnds$tau    %||% c(-40, 40))
  b_c2  <- as.numeric(bnds$c2     %||% c(-40, 40))
  if (length(b_lam) != 2) b_lam <- c(-40, 40)
  if (length(b_tau) != 2) b_tau <- c(-40, 40)
  if (length(b_c2)  != 2) b_c2  <- c(-40, 40)

  obj <- list(
    type = "rhs",
    hypers = list(tau0 = tau0, nu = nu, s = s,
                  shrink_intercept = shrink_intercept,
                  intercept_prec = intercept_prec),
    control = list(n_inner = n_inner,
                   eta_bounds = list(lambda = b_lam, tau = b_tau, c2 = b_c2),
                   h_curv = h_curv,            # unused
                   var_floor = var_floor,
                   verbose = verbose),

    init = function(p) {
      p <- as.integer(p)
      if (!is.finite(p) || p <= 0) .stopf("rhs_prior$init: p must be positive integer.")

      lam0 <- init$lambda %||% 1
      if (length(lam0) == 1) lam0 <- rep(lam0, p)
      lam0 <- as.numeric(lam0)
      if (length(lam0) != p) .stopf("rhs_prior$init: init$lambda must be length p or scalar.")
      lam0 <- pmax(lam0, 1e-16)

      tau_init <- as.numeric(init$tau %||% tau0)[1]
      if (!is.finite(tau_init) || tau_init <= 0) tau_init <- tau0

      c2_init <- as.numeric(init$c2 %||% (s^2))[1]
      if (!is.finite(c2_init) || c2_init <= 0) c2_init <- s^2

      list(
        p = p,
        eta_lambda_hat = log(lam0),
        eta_tau_hat    = log(tau_init),
        eta_c_hat      = log(c2_init),
        Sigma_diag     = rep(var_floor, p + 2L),
        Sigma_full     = diag(var_floor, p + 2L),
        diag_on        = FALSE,
        rhs_diag       = NULL,
        shrink_intercept = shrink_intercept,
        intercept_prec   = intercept_prec
      )
    },

    expected_prec = function(state, p) {
      if (is.null(state$p)) .stopf("rhs_prior$expected_prec: state missing p.")
      p0 <- state$p
      if (as.integer(p) != as.integer(p0)) .stopf("rhs_prior$expected_prec: p mismatch.")

      mu_lam <- as.numeric(state$eta_lambda_hat)
      mu_tau <- as.numeric(state$eta_tau_hat)
      mu_c   <- as.numeric(state$eta_c_hat)

      v <- as.numeric(state$Sigma_diag)
      if (length(v) != p0 + 2L) .stopf("rhs_prior$expected_prec: Sigma_diag wrong length.")
      v_lam <- v[seq_len(p0)]
      v_tau <- v[p0 + 1L]
      v_c   <- v[p0 + 2L]

      # Prefer full covariance if available (Laplace: Sigma_eta = -H^{-1})
      Sigma_full <- state$Sigma_full
      if (is.null(Sigma_full) || !all(dim(Sigma_full) == c(p0 + 2L, p0 + 2L))) {
        # fallback to diagonal only (legacy)
        Sigma_full <- diag(v, p0 + 2L)
      }

      # Delta-method for D_j = E[g_j] with g_j = .safe_exp(-2u_j-2u_tau) + .safe_exp(-u_kappa)
      # Using your document: D_j ≈ g(mu) + 0.5 tr( Hess(g)(mu) * Sigma_sub )
      var_kap <- max(Sigma_full[p0 + 2L, p0 + 2L], 0)
      r_hat <- .safe_exp(-mu_c)

      prec <- numeric(p0)
      for (j in seq_len(p0)) {
        if (!isTRUE(state$shrink_intercept) && j == 1L) {
          prec[j] <- state$intercept_prec
          next
        }

        t_hat <- .safe_exp(-2 * (mu_lam[j] + mu_tau))

        # Var(u_j + u_tau) uses covariance
        v_sum <- Sigma_full[j, j] + Sigma_full[p0 + 1L, p0 + 1L] + 2 * Sigma_full[j, p0 + 1L]
        v_sum <- max(v_sum, 0)

        # 0.5 tr(H_g Sigma) where H_g block = [[4t,4t,0],[4t,4t,0],[0,0,r]]
        # => 0.5*(4t*(Var(u_j+u_tau)) + r*Var(u_kappa)) *2? expanded:
        # trace = 4t*(Sigma_jj + 2Sigma_jtau + Sigma_tautau) + r*Sigma_kk = 4t*v_sum + r*var_kap
        delta <- 0.5 * (4 * t_hat * v_sum + r_hat * var_kap)

        Dj <- (t_hat + r_hat) + delta
        prec[j] <- Dj
      }

      prec <- pmax(prec, 1e-16)

      if (!isTRUE(state$shrink_intercept)) {
        prec[1] <- state$intercept_prec
      }
      prec
    },

    update = function(state, qbeta) {
      p <- state$p
      if (is.null(qbeta$m) || is.null(qbeta$V)) .stopf("rhs_prior$update: qbeta must have m and V.")
      if (length(qbeta$m) != p) .stopf("rhs_prior$update: qbeta$m length mismatch.")
      if (!all(dim(qbeta$V) == c(p, p))) .stopf("rhs_prior$update: qbeta$V dim mismatch.")

      beta2 <- as.numeric(qbeta$m^2 + diag(qbeta$V))

      eta_lam <- as.numeric(state$eta_lambda_hat)
      eta_tau <- as.numeric(state$eta_tau_hat)
      eta_c2  <- as.numeric(state$eta_c_hat)

      diag_env <- NULL
      if (isTRUE(state$diag_on)) {
        diag_env <- new.env(parent = emptyenv())
        diag_env$n_calls <- 0L
        diag_env$n_fallback <- 0L
        diag_env$n_grid <- 0L
        diag_env$n_hit_bounds <- 0L
        diag_env$last_by_tag <- list()
        diag_env$log_detail <- isTRUE(state$diag_deep)
      }

      v_old <- as.numeric(state$Sigma_diag %||% rep(var_floor, p + 2L))
      if (length(v_old) != p + 2L) v_old <- rep(var_floor, p + 2L)

      var_lam <- v_old[seq_len(p)]
      var_tau <- v_old[p + 1L]
      var_c2  <- v_old[p + 2L]

      for (inner in seq_len(n_inner)) {

        # ---- lambda_j ----
        for (j in seq_len(p)) {
          if (!isTRUE(state$shrink_intercept) && j == 1L) next

          f_j <- function(eta_j) {
            et <- eta_lam
            et[j] <- eta_j
            rhs_obj_eta(et, eta_tau, eta_c2, beta2,
                        tau0 = tau0, nu = nu, s = s,
                        shrink_intercept = state$shrink_intercept)
          }

          mode_j <- .opt_1d_mode(f_j, lo = b_lam[1], hi = b_lam[2], eta0 = eta_lam[j],
                                 diag_env = diag_env, tag = NULL)
          eta_lam[j] <- mode_j

          d2 <- rhs_d2_lambda_j(mode_j, eta_tau, eta_c2, beta2[j])
          var_lam[j] <- if (is.finite(d2) && d2 < 0) max(1 / (-d2), var_floor) else var_floor
        }

        # ---- tau ----
        f_tau <- function(etau) rhs_obj_eta(eta_lam, etau, eta_c2, beta2,
                                            tau0 = tau0, nu = nu, s = s,
                                            shrink_intercept = state$shrink_intercept)
        eta_tau_start <- eta_tau
        grad_tau_start <- if (!isTRUE(state$shrink_intercept)) {
          if (p >= 2L) rhs_grad_tau(eta_lam[-1L], eta_tau_start, eta_c2, beta2[-1L], tau0 = tau0) else NA_real_
        } else {
          rhs_grad_tau(eta_lam, eta_tau_start, eta_c2, beta2, tau0 = tau0)
        }
        eta_tau <- .opt_1d_mode(f_tau, lo = b_tau[1], hi = b_tau[2], eta0 = eta_tau,
                                diag_env = diag_env, tag = "tau")
        grad_tau_end <- if (!isTRUE(state$shrink_intercept)) {
          if (p >= 2L) rhs_grad_tau(eta_lam[-1L], eta_tau, eta_c2, beta2[-1L], tau0 = tau0) else NA_real_
        } else {
          rhs_grad_tau(eta_lam, eta_tau, eta_c2, beta2, tau0 = tau0)
        }

        if (!isTRUE(state$shrink_intercept)) {
          d2_tau <- rhs_d2_tau(eta_lam[-1L], eta_tau, eta_c2, beta2[-1L], tau0 = tau0)
        } else {
          d2_tau <- rhs_d2_tau(eta_lam, eta_tau, eta_c2, beta2, tau0 = tau0)
        }
        var_tau <- if (is.finite(d2_tau) && d2_tau < 0) max(1 / (-d2_tau), var_floor) else var_floor

        # ---- c^2 ----
        f_c2 <- function(ec) rhs_obj_eta(eta_lam, eta_tau, ec, beta2,
                                         tau0 = tau0, nu = nu, s = s,
                                         shrink_intercept = state$shrink_intercept)
        eta_c2 <- .opt_1d_mode(f_c2, lo = b_c2[1], hi = b_c2[2], eta0 = eta_c2,
                               diag_env = diag_env, tag = "c2")

        if (!isTRUE(state$shrink_intercept)) {
          d2_c2 <- rhs_d2_c2(eta_lam[-1L], eta_tau, eta_c2, beta2[-1L], nu = nu, s = s)
        } else {
          d2_c2 <- rhs_d2_c2(eta_lam, eta_tau, eta_c2, beta2, nu = nu, s = s)
        }
        var_c2 <- if (is.finite(d2_c2) && d2_c2 < 0) max(1 / (-d2_c2), var_floor) else var_floor
      }

      # --- Full Laplace covariance: Sigma_eta = -[H_f(eta_hat)]^{-1} ---
      Svec <- beta2  # matches S_j = E[beta_j^2]

      hess <- .rhs_hess_active(
        eta_lambda = eta_lam,
        eta_tau    = eta_tau,
        eta_c2     = eta_c2,
        S          = Svec,
        tau0       = tau0,
        nu         = nu,
        s          = s,
        shrink_intercept = state$shrink_intercept
      )
      Hact <- hess$H
      idx  <- hess$idx

      # K = -H should be SPD
      K <- -Hact
      invK <- .inv_spd_with_jitter(K, var_floor = var_floor)
      Sigma_act <- invK$inv

      Sigma_full <- .embed_sigma_full(Sigma_act, idx = idx, p = p, var_floor = var_floor)

      state$eta_lambda_hat <- eta_lam
      state$eta_tau_hat    <- eta_tau
      state$eta_c_hat      <- eta_c2

      state$Sigma_full <- Sigma_full
      state$Sigma_diag <- diag(Sigma_full)
      state$Sigma_diag <- pmax(state$Sigma_diag, var_floor)

      if (isTRUE(state$diag_on)) {
        state$rhs_diag <- list(
          opt_calls      = diag_env$n_calls %||% 0L,
          opt_fallback   = diag_env$n_fallback %||% 0L,
          opt_grid       = diag_env$n_grid %||% 0L,
          opt_hit_bounds = diag_env$n_hit_bounds %||% 0L,
          hess_jitter    = invK$jitter,
          chol_diag_min  = invK$chol_diag_min,
          chol_diag_max  = invK$chol_diag_max,
          tau_update     = diag_env$last_by_tag[["tau"]] %||% NULL,
          c2_update      = diag_env$last_by_tag[["c2"]] %||% NULL,
          grad_tau_start = as.numeric(grad_tau_start %||% NA_real_),
          grad_tau_end   = as.numeric(grad_tau_end %||% NA_real_)
        )
      }


      if (isTRUE(verbose)) {
        cat(sprintf("[RHS] tau=%.4g (eta_tau=%.3f), c2=%.4g (eta_c2=%.3f)\n",
                    .safe_exp(eta_tau), eta_tau, .safe_exp(eta_c2), eta_c2))
      }

      state
    },

    # returns list(elbo=scalar) to match old contract
    elbo = function(state, qbeta) {
      p <- as.integer(state$p)
      if (is.null(qbeta$m) || is.null(qbeta$V)) .stopf("rhs_prior$elbo: qbeta must have m and V.")
      if (length(qbeta$m) != p) .stopf("rhs_prior$elbo: qbeta$m length mismatch.")
      if (!all(dim(qbeta$V) == c(p, p))) .stopf("rhs_prior$elbo: qbeta$V dim mismatch.")

      beta2 <- as.numeric(qbeta$m^2 + diag(qbeta$V))

      eta_lam <- as.numeric(state$eta_lambda_hat)
      eta_tau <- as.numeric(state$eta_tau_hat)
      eta_c2  <- as.numeric(state$eta_c_hat)

      v <- as.numeric(state$Sigma_diag)
      if (length(v) != p + 2L) .stopf("rhs_prior$elbo: Sigma_diag wrong length.")
      var_lam <- v[seq_len(p)]
      var_tau <- v[p + 1L]
      var_c2  <- v[p + 2L]

      # f at the mode
      f0 <- rhs_obj_eta(eta_lam, eta_tau, eta_c2, beta2,
                        tau0 = tau0, nu = nu, s = s,
                        shrink_intercept = state$shrink_intercept)

      # effective vectors excluding intercept lambda_1 when not shrunk
      if (!isTRUE(state$shrink_intercept)) {
        if (p >= 2L) {
          lam_eff  <- eta_lam[-1L]
          b2_eff   <- beta2[-1L]
          vlam_eff <- var_lam[-1L]
        } else {
          lam_eff  <- numeric(0)
          b2_eff   <- numeric(0)
          vlam_eff <- numeric(0)
        }
      } else {
        lam_eff  <- eta_lam
        b2_eff   <- beta2
        vlam_eff <- var_lam
      }

      # Full Hessian at the mode in the active block
      hess <- .rhs_hess_active(
        eta_lambda = eta_lam,
        eta_tau    = eta_tau,
        eta_c2     = eta_c2,
        S          = beta2,
        tau0       = tau0,
        nu         = nu,
        s          = s,
        shrink_intercept = state$shrink_intercept
      )
      Hact <- hess$H

      idx <- if (isTRUE(state$shrink_intercept)) seq_len(p) else if (p >= 2L) 2L:p else integer(0)
      act <- c(idx, p + 1L, p + 2L)

      Sigma_full <- state$Sigma_full
      if (is.null(Sigma_full) || !all(dim(Sigma_full) == c(p + 2L, p + 2L))) {
        Sigma_full <- diag(pmax(state$Sigma_diag, var_floor), p + 2L)
      }
      Sigma_act <- Sigma_full[act, act, drop = FALSE]

      # Laplace-Delta: E[f] ≈ f(mode) + 0.5 tr(H * Sigma)
      trHS <- sum(Hact * Sigma_act)
      E_log_joint <- f0 + 0.5 * trHS

      # Entropy of Gaussian q_eta with FULL covariance in the active block
      Sigma_full <- state$Sigma_full
      if (is.null(Sigma_full) || !all(dim(Sigma_full) == c(p + 2L, p + 2L))) {
        # fallback: diagonal-only
        Sigma_full <- diag(pmax(state$Sigma_diag, var_floor), p + 2L)
      }

      # active indices in the eta block used by f (drop intercept lambda if not shrunk)
      idx <- if (isTRUE(state$shrink_intercept)) seq_len(p) else if (p >= 2L) 2L:p else integer(0)
      act <- c(idx, p + 1L, p + 2L)
      Sigma_act <- Sigma_full[act, act, drop = FALSE]

      # ensure SPD for logdet
      invK <- .inv_spd_with_jitter(Sigma_act + diag(0, nrow(Sigma_act)), var_floor = var_floor)
      # NOTE: inv_spd_with_jitter expects SPD and returns inv+logdet; here we only need logdet.
      # The "inv" is not used; we reuse its logdet computation by passing Sigma_act itself as K.
      # So call with K = Sigma_act:
      ld <- .inv_spd_with_jitter(Sigma_act, var_floor = var_floor)$logdet

      d_act <- nrow(Sigma_act)
      H_qeta <- 0.5 * (d_act * (1 + log(2 * pi)) + ld)


      # If intercept is not shrunk, add its standalone Normal prior term
      E_log_intercept <- 0
      if (!isTRUE(state$shrink_intercept) && p >= 1L) {
        prec0 <- as.numeric(state$intercept_prec %||% 1e-16)[1L]
        prec0 <- if (is.finite(prec0) && prec0 > 0) prec0 else 1e-16
        E_log_intercept <- 0.5 * (log(prec0) - log(2 * pi)) - 0.5 * prec0 * beta2[1L]
      }

      list(elbo = as.numeric(E_log_joint + H_qeta + E_log_intercept))
    }
  )

  class(obj) <- c("qdesn_beta_prior_rhs", "list")
  obj
}
