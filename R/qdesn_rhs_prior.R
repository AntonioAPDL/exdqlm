# ------------------------------------------------------------------------------
# Regularized Horseshoe (RHS) prior block for beta: coordinate-wise Laplace on log-scales
# Provides engine interface:
#   init(p), expected_prec(state,p), update(state,qbeta), elbo(state,qbeta)
# ------------------------------------------------------------------------------

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (!is.null(x)) x else y
}

# stable log(1+exp(x))
.log1p_exp <- function(x) {
  ifelse(x > 0, x + log1p(exp(-x)), log1p(exp(x)))
}

# stable log(exp(a)+exp(b)) with vector support
.logsumexp2 <- function(a, b) {
  m <- pmax(a, b)
  m + log(exp(a - m) + exp(b - m))
}

# coordinate-wise 1D maximize for a smooth objective f(eta)
# returns list(mode=..., var=...)
.opt_1d_laplace <- function(f, lo, hi, eta0 = NULL,
                           h_curv = 1e-4, var_floor = 1e-8) {
  if (!is.finite(lo) || !is.finite(hi) || !(lo < hi)) .stopf(".opt_1d_laplace: invalid bounds.")
  if (is.null(eta0) || !is.finite(eta0)) eta0 <- 0

  opt <- try(optimize(f, interval = c(lo, hi), maximum = TRUE), silent = TRUE)
  if (inherits(opt, "try-error") || !is.finite(opt$objective)) {
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
    mode <- if (inherits(opt2, "try-error") || !is.finite(opt2$value)) par0 else opt2$par
  } else {
    mode <- opt$maximum
  }
  mode <- pmin(pmax(mode, lo), hi)

  h <- as.numeric(h_curv)
  if (!is.finite(h) || h <= 0) h <- 1e-4
  h <- min(h, 0.1 * (hi - lo))

  f0  <- f(mode)
  f1  <- f(pmin(mode + h, hi))
  fm1 <- f(pmax(mode - h, lo))
  d2  <- (f1 - 2 * f0 + fm1) / (h^2)

  var <- if (is.finite(d2) && d2 < 0) 1 / (-d2) else var_floor
  var <- pmax(var, var_floor)

  list(mode = mode, var = var)
}

qdesn_rhs_prior_obj <- function(
  hypers = list(tau0 = 1, nu = 4, s = 1,
                shrink_intercept = TRUE,
                intercept_prec = 1e-12),
  init = list(lambda = 1, tau = NULL, c2 = NULL),
  control = list(n_inner = 1L,
                 eta_bounds = list(lambda = c(-12, 12),
                                   tau    = c(-12, 12),
                                   c2     = c(-12, 12)),
                 h_curv = 1e-4,
                 var_floor = 1e-8,
                 verbose = FALSE)
) {
  tau0 <- as.numeric(hypers$tau0 %||% 1)[1]
  nu   <- as.numeric(hypers$nu   %||% 4)[1]
  s    <- as.numeric(hypers$s    %||% 1)[1]

  if (!is.finite(tau0) || tau0 <= 0) .stopf("RHS hypers$tau0 must be > 0.")
  if (!is.finite(nu)   || nu   <= 0) .stopf("RHS hypers$nu must be > 0.")
  if (!is.finite(s)    || s    <= 0) .stopf("RHS hypers$s must be > 0.")

  shrink_intercept <- isTRUE(hypers$shrink_intercept %||% TRUE)
  intercept_prec   <- as.numeric(hypers$intercept_prec %||% 1e-12)[1]
  if (!is.finite(intercept_prec) || intercept_prec <= 0) intercept_prec <- 1e-12

  n_inner   <- as.integer(control$n_inner %||% 1L)
  verbose   <- isTRUE(control$verbose %||% FALSE)
  var_floor <- as.numeric(control$var_floor %||% 1e-8)[1]
  h_curv    <- as.numeric(control$h_curv %||% 1e-4)[1]

  bnds  <- control$eta_bounds %||% list()
  b_lam <- as.numeric(bnds$lambda %||% c(-12, 12))
  b_tau <- as.numeric(bnds$tau    %||% c(-12, 12))
  b_c2  <- as.numeric(bnds$c2     %||% c(-12, 12))
  if (length(b_lam) != 2) b_lam <- c(-12, 12)
  if (length(b_tau) != 2) b_tau <- c(-12, 12)
  if (length(b_c2)  != 2) b_c2  <- c(-12, 12)

  logtau0 <- log(tau0)

  # eta = (eta_lambda_1..eta_lambda_p, eta_tau, eta_c2)
  rhs_obj_eta <- function(eta_lambda, eta_tau, eta_c, beta2) {

    # If intercept is not shrunk, remove it from the RHS objective entirely
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
    log_denom <- .logsumexp2(eta_c, u)
    logV <- eta_c + u - log_denom

    invV <- exp(-eta_c) + exp(-u)
    like <- -0.5 * sum(logV + beta2 * invV)

    lp_lam <- sum(eta_lambda - .log1p_exp(2 * eta_lambda))
    lp_tau <- eta_tau - .log1p_exp(2 * (eta_tau - logtau0))
    lp_c2  <- -(nu / 2) * eta_c - (nu * s^2) / (2 * exp(eta_c))

    like + lp_lam + lp_tau + lp_c2
  }


  obj <- list(
    type = "rhs",
    hypers = list(tau0 = tau0, nu = nu, s = s,
                  shrink_intercept = shrink_intercept,
                  intercept_prec = intercept_prec),

    init = function(p) {
      p <- as.integer(p)
      if (!is.finite(p) || p <= 0) .stopf("rhs_prior$init: p must be positive integer.")

      lam0 <- init$lambda %||% 1
      if (length(lam0) == 1) lam0 <- rep(lam0, p)
      lam0 <- as.numeric(lam0)
      if (length(lam0) != p) .stopf("rhs_prior$init: init$lambda must be length p or scalar.")
      lam0 <- pmax(lam0, 1e-12)

      tau_init <- as.numeric(init$tau %||% tau0)[1]
      if (!is.finite(tau_init) || tau_init <= 0) tau_init <- tau0

      c2_init <- as.numeric(init$c2 %||% (s^2))[1]
      if (!is.finite(c2_init) || c2_init <= 0) c2_init <- s^2

      state <- list(
        p = p,
        eta_lambda_hat = log(lam0),
        eta_tau_hat    = log(tau_init),
        eta_c_hat      = log(c2_init),
        Sigma_diag     = rep(var_floor, p + 2L),
        shrink_intercept = shrink_intercept,
        intercept_prec   = intercept_prec
      )
      state
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

      # E[1/c2] = exp(-mu_c + 0.5 v_c)
      E_cinv <- exp(-mu_c + 0.5 * v_c)

      # E[1/(tau^2 lambda_j^2)] = exp(-2(mu_tau+mu_lam_j) + 2(v_tau+v_lam_j))
      E_binv <- exp(-2 * (mu_tau + mu_lam) + 2 * (v_tau + v_lam))

      prec <- pmax(E_cinv + E_binv, 1e-24)

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
      eta_c   <- as.numeric(state$eta_c_hat)

      if (length(eta_lam) != p) .stopf("rhs_prior$update: eta_lambda_hat length mismatch.")

      v_old <- as.numeric(state$Sigma_diag %||% rep(var_floor, p + 2L))
      if (length(v_old) != p + 2L) v_old <- rep(var_floor, p + 2L)

      var_lam <- v_old[seq_len(p)]
      var_tau <- v_old[p + 1L]
      var_c   <- v_old[p + 2L]

      for (inner in seq_len(n_inner)) {

        for (j in seq_len(p)) {
          if (!isTRUE(state$shrink_intercept) && j == 1L) next

          f_j <- function(eta_j) {
            et <- eta_lam
            et[j] <- eta_j
            rhs_obj_eta(et, eta_tau, eta_c, beta2)
          }

          optj <- .opt_1d_laplace(f_j, lo = b_lam[1], hi = b_lam[2],
                                 eta0 = eta_lam[j], h_curv = h_curv,
                                 var_floor = var_floor)
          eta_lam[j] <- optj$mode
          var_lam[j] <- optj$var
        }

        f_tau <- function(etau) rhs_obj_eta(eta_lam, etau, eta_c, beta2)
        optt <- .opt_1d_laplace(f_tau, lo = b_tau[1], hi = b_tau[2],
                               eta0 = eta_tau, h_curv = h_curv,
                               var_floor = var_floor)
        eta_tau <- optt$mode
        var_tau <- optt$var

        f_c <- function(ec) rhs_obj_eta(eta_lam, eta_tau, ec, beta2)
        optc <- .opt_1d_laplace(f_c, lo = b_c2[1], hi = b_c2[2],
                               eta0 = eta_c, h_curv = h_curv,
                               var_floor = var_floor)
        eta_c <- optc$mode
        var_c <- optc$var
      }

      state$eta_lambda_hat <- eta_lam
      state$eta_tau_hat    <- eta_tau
      state$eta_c_hat      <- eta_c
      state$Sigma_diag     <- c(var_lam, var_tau, var_c)

      if (isTRUE(verbose)) {
        cat(sprintf("[RHS] tau=%.4g (eta_tau=%.3f), c2=%.4g (eta_c=%.3f)\n",
                    exp(eta_tau), eta_tau, exp(eta_c), eta_c))
      }

      state
    },

    # keep contract: return list(elbo=scalar)
    # Approximate ELBO contribution of the RHS block:
    #   E_q[ log p(beta | eta) + log p(eta) ]  - E_q[log q(eta)]
    # using the same Laplace-Gaussian approximation you already use for updates.
    # This EXCLUDES H(q(beta)) which is handled in the main engine.
    elbo = function(state, qbeta) {
      p <- as.integer(state$p)
      if (is.null(qbeta$m) || is.null(qbeta$V)) .stopf("rhs_prior$elbo: qbeta must have m and V.")
      if (length(qbeta$m) != p) .stopf("rhs_prior$elbo: qbeta$m length mismatch.")
      if (!all(dim(qbeta$V) == c(p, p))) .stopf("rhs_prior$elbo: qbeta$V dim mismatch.")

      beta2 <- as.numeric(qbeta$m^2 + diag(qbeta$V))

      eta_lam <- as.numeric(state$eta_lambda_hat)
      eta_tau <- as.numeric(state$eta_tau_hat)
      eta_c   <- as.numeric(state$eta_c_hat)

      v <- as.numeric(state$Sigma_diag)
      if (length(v) != p + 2L) .stopf("rhs_prior$elbo: Sigma_diag wrong length.")
      var_lam <- v[seq_len(p)]
      var_tau <- v[p + 1L]
      var_c   <- v[p + 2L]

      # Effective dimension and variance vector (exclude intercept lambda if not shrunk)
      if (!isTRUE(state$shrink_intercept)) {
        if (p >= 2L) {
          var_eff <- c(var_lam[2:p], var_tau, var_c)
          d_eff <- (p - 1L) + 2L
        } else {
          var_eff <- c(var_tau, var_c)
          d_eff <- 2L
        }
      } else {
        var_eff <- c(var_lam, var_tau, var_c)
        d_eff <- p + 2L
      }
      var_eff <- pmax(var_eff, 1e-16)

      # f(mode) (rhs_obj_eta() already removes intercept internally if shrink_intercept=FALSE)
      f0 <- rhs_obj_eta(eta_lam, eta_tau, eta_c, beta2)

      # Delta/Laplace correction under q(eta)=N(mode, Var):  f0 + 0.5 tr(H Var)
      # With Var ~= (-H)^{-1} (coordinate Laplace), tr(H Var) ~= -d_eff
      E_log_joint <- f0 - 0.5 * d_eff

      # Entropy of q(eta): independent normals
      H_qeta <- 0.5 * sum(1 + log(2 * pi) + log(var_eff))

      # If intercept is not shrunk, add its standalone Normal prior term (precision intercept_prec)
      E_log_intercept <- 0
      if (!isTRUE(state$shrink_intercept) && p >= 1L) {
        prec0 <- as.numeric(state$intercept_prec %||% 1e-12)[1L]
        prec0 <- if (is.finite(prec0) && prec0 > 0) prec0 else 1e-12
        E_log_intercept <- 0.5 * (log(prec0) - log(2 * pi)) - 0.5 * prec0 * beta2[1L]
      }

      list(elbo = as.numeric(E_log_joint + E_log_intercept + H_qeta))
    }

  )

  class(obj) <- c("qdesn_beta_prior_rhs", "list")
  obj
}
