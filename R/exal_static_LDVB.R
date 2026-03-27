#' Static exAL Regression — CAVI with Laplace–Delta for (sigma, gamma)
#'
#' Fits the static Extended Asymmetric Laplace (exAL) regression via a
#' coordinate-ascent variational inference (CAVI) scheme with a mean-field
#' factorization
#' \deqn{q(\beta)\ \prod_{i=1}^n q(v_i)\ q(s_i)\ q(\sigma,\gamma),}
#' where \eqn{q(\sigma,\gamma)} is handled jointly using a Laplace–Delta (LD)
#' approximation on the transformed parameters
#' \eqn{\eta=\mathrm{logit}((\gamma-L)/(U-L))} and \eqn{\ell=\log\sigma}.
#'
#' The updates implement the closed-form factors you derived:
#' * \eqn{q(\beta)=\mathcal{N}(m_\beta,V_\beta)}
#' * \eqn{q(v_i)=\mathrm{GIG}(1/2,\chi_i,\psi)}
#' * \eqn{q(s_i)=\mathcal{N}(\mu_{s_i},\tau_{s_i}^2)} truncated to \((0,\infty)\)
#' * \eqn{q(\sigma,\gamma)} via LD; the expectations
#'   \eqn{\{\xi_1,\xi_\lambda,\xi_{\lambda^2},\xi_A,\xi_{A^2},
#'         \xi_{\sigma^{-1}},\zeta_\lambda\}}
#'   are computed via a second-order Delta-method approximation under the
#'   Gaussian LD approximation for \((\eta,\ell)\).
#'
#' Priors are placed on the **natural scale** of the parameters:
#' \eqn{\sigma \sim IG(a_\sigma,b_\sigma)} and either a user-supplied
#' \code{log_prior_gamma()} or a Normal prior
#' \eqn{\gamma \sim N(\mu_{\gamma,0}, s^2_{\gamma,0})}.  Any log-scale priors
#' for \eqn{\log\sigma} are ignored and are kept only for backward
#' compatibility in the function signature.
#'
#' @param y Numeric vector (length n).
#' @param X Numeric matrix (n x p).
#' @param p0 Target quantile in (0,1).
#' @param max_iter Maximum CAVI iterations (default 1000).
#' @param tol Convergence tolerance on relative ELBO changes (default 1e-4).
#' @param tol_par Additional tolerance for the LD safeguard based on
#'   \eqn{|\mathbb{E}[\gamma]_{\text{old}}-\mathbb{E}[\gamma]_{\text{new}}|
#'   + |\mathbb{E}[\sigma]_{\text{old}}-\mathbb{E}[\sigma]_{\text{new}}|}
#'   (default: same as \code{tol}).
#' @param b0,V0 Prior mean and covariance for
#'   \eqn{\beta \sim \mathcal{N}(b_0,V_0)}.
#' @param a_sigma,b_sigma Shape and scale of the Inverse-Gamma prior
#'   \eqn{\sigma \sim IG(a_\sigma,b_\sigma)} with density
#'   \eqn{p(\sigma)\propto \sigma^{-(a_\sigma+1)} e^{-b_\sigma/\sigma}}.
#' @param gamma_bounds Two-vector \((L,U)\) support for \(\gamma\).
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Optional function \code{g -> log pi(gamma=g)}.
#'   If \code{prior_gamma_mu0} and \code{prior_gamma_s20} are supplied, they
#'   override \code{log_prior_gamma} with a Normal prior.
#' @param prior_gamma_mu0,prior_gamma_s20 Optional hyperparameters for the
#'   Normal prior on \eqn{\gamma}.
#' @param prior_log_sigma_mu0,prior_log_sigma_s20 Deprecated log-scale
#'   hyperparameters; they are accepted for compatibility but ignored.
#' @param init Optional list with starting values: \code{beta}, \code{sigma},
#'   \code{gamma}. If missing, reasonable defaults are used.
#' @param init_gamma Optional scalar overwrite for the initial \eqn{\gamma}.
#' @param init_log_sigma Optional scalar overwrite for the initial
#'   \eqn{\log\sigma}; internally converted to \eqn{\sigma=\exp(\ell)}.
#' @param n_samp_xi (Currently ignored; kept for backward compatibility.)
#'   VB–LD uses deterministic Delta-method approximations for the
#'   \eqn{\xi} expectations.
#' @param verbose Logical; print progress.
#'
#' @return A list with variational factors, LD approximation for
#'   \eqn{(\sigma,\gamma)}, convergence diagnostics, and \code{misc}.
exal_static_LDVB_core <- function(
  y, X, p0,
  max_iter = 1000, tol = 1e-4, tol_par = tol,
  b0 = NULL, V0 = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma      = NULL,
  prior_gamma_mu0      = NULL,
  prior_gamma_s20      = NULL,
  prior_log_sigma_mu0  = NULL,
  prior_log_sigma_s20  = NULL,
  init                 = NULL,
  init_gamma           = NULL,
  init_log_sigma       = NULL,
  n_samp_xi = 200,
  verbose   = TRUE,
  beta_prior_module = NULL,
  rhs_hypers = NULL,
  beta_prior_obj = NULL
){

  # --- checks ---------------------------------------------------------------
  y <- as.numeric(y)
  X <- as.matrix(X); storage.mode(X) <- "double"
  n <- length(y); p <- ncol(X)
  if (nrow(X) != n) stop("nrow(X) must match length(y).")
  if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")

  if (is.null(b0)) b0 <- rep(0, p)
  if (is.null(V0)) V0 <- diag(1e6, p)
  V0 <- as.matrix(V0)
  if (!all(dim(V0) == c(p, p))) stop("V0 must be p x p.")

  L <- gamma_bounds[1]; U <- gamma_bounds[2]
  if (!(L < U)) stop("gamma_bounds must satisfy L < U.")

  # --- priors for gamma and log(sigma) --------------------------------------
  # Gamma prior: hyperparameters override explicit log_prior_gamma()
  if (!is.null(prior_gamma_mu0) && !is.null(prior_gamma_s20)) {
    mu_g <- as.numeric(prior_gamma_mu0)[1L]
    s2_g <- max(as.numeric(prior_gamma_s20)[1L], 1e-12)
    log_prior_gamma_fun <- function(g) {
      sum(dnorm(g, mean = mu_g, sd = sqrt(s2_g), log = TRUE))
    }
  } else if (!is.null(log_prior_gamma)) {
    # user-supplied log prior
    log_prior_gamma_fun <- log_prior_gamma
  } else {
    # flat prior
    log_prior_gamma_fun <- function(g) 0
  }

  use_lsig_prior <- FALSE
  mu_lsig <- NA_real_
  s2_lsig <- NA_real_

  # --- A,B,C,lambda helpers -------------------------------------------------
  ABC_of <- function(g) exal_get_ABC(p0 = p0, gamma = g)
  A_of   <- function(g) ABC_of(g)$A
  B_of   <- function(g) ABC_of(g)$B
  C_of   <- function(g) ABC_of(g)$C
  lam_of <- function(g) C_of(g) * abs(g)

  # transform (eta,ell) <-> (gamma,sigma)
  g_from_eta <- function(eta) { s <- plogis(eta); L + (U - L) * s }
  sig_from_ell <- function(ell) exp(ell)

  # --- initialize variational parameters ------------------------------------
  # merge scalar inits into `init` list (no breakage for old callers)
  if (is.null(init)) init <- list()
  if (!is.null(init_gamma))      init$gamma <- init_gamma
  if (!is.null(init_log_sigma))  init$sigma <- exp(init_log_sigma)

  m_beta  <- if (is.null(init$beta)) rep(0, p) else as.numeric(init$beta)
  V_beta  <- V0
  sigma0  <- if (is.null(init$sigma)) 1 else as.numeric(init$sigma)[1]
  gamma0  <- if (is.null(init$gamma)) 0 else as.numeric(init$gamma)[1]
  gamma0  <- min(max(gamma0, L + 1e-10), U - 1e-10)

  # q(v): initialize moments (use 1 for both)
  E_inv_v <- rep(1, n)
  E_v     <- rep(1, n)

  # q(s): initialize moments (half-normal)
  qs_mu   <- rep(0, n)
  qs_tau2 <- rep(1, n)
  E_s     <- sqrt(2/pi) * rep(1, n)  # E[N^+(0,1)]
  E_s2    <- rep(1, n)               # Var + mean^2 = 1 + 2/pi (but ok to start at 1)

  # q(sigma,gamma): start at point mass to get xi's
  eta_hat <- qlogis((gamma0 - L) / (U - L))
  ell_hat <- log(sigma0)
  Sig_eta_ell <- diag(c(1e-16, 1e-16))  # tiny to start; inflated after first LD update

  # --- numerics helpers ------------------------------------------------------
  V0_inv <- tryCatch(solve(V0), error = function(e) MASS::ginv(V0))

  # --- beta prior object (new) ---------------------------------------------
  if (is.null(beta_prior_obj)) {
    # Backward compatibility: infer from old module args if present
    if (!is.null(beta_prior_module) && is.list(beta_prior_module) && !is.null(beta_prior_module$type)) {
      tp <- tolower(beta_prior_module$type)
      if (tp == "rhs") {
        beta_prior_obj <- beta_prior("rhs", rhs = rhs_hypers %||% beta_prior_module$hypers %||% list())
      } else if (tp == "rhs_ns") {
        beta_prior_obj <- beta_prior("rhs_ns", rhs = rhs_hypers %||% beta_prior_module$hypers %||% list())
      } else {
        tau2 <- if (is_diag_matrix(V0)) mean(diag(V0)) else 1e6
        beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = tau2))
      }
    } else if (!is.null(rhs_hypers)) {
      beta_prior_obj <- beta_prior("rhs", rhs = rhs_hypers)
    } else {
      tau2 <- if (is_diag_matrix(V0)) mean(diag(V0)) else 1e6
      beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = tau2))
    }
  }
  beta_state <- beta_prior_obj$init(p)

    # E[log V] for V ~ GIG(k, chi, psi)
    gig_E_log <- function(k, chi, psi) {
      chi <- pmax(as.numeric(chi), 1e-12)
      psi <- pmax(as.numeric(psi), 1e-12)
      z   <- sqrt(chi * psi)

      dlogK <- .dlog_besselK_dnu(z, nu = k)

      0.5 * (log(chi) - log(psi)) + dlogK
    }

  gig_moment <- function(k, chi, psi, r) {
    # E[v^r] = (sqrt(chi/psi))^r * K_{k+r}(sqrt(chi*psi))/K_k(sqrt(chi*psi))
    z <- sqrt(pmax(chi, 1e-12) * pmax(psi, 1e-12))
    num <- besselK(z, nu = k + r, expon.scaled = TRUE)
    den <- besselK(z, nu = k,     expon.scaled = TRUE)
    ratio <- num / den
    ratio[!is.finite(ratio)] <- 1
    pow   <- (sqrt(pmax(chi, 1e-12) / pmax(psi, 1e-12)))^r
    pmax(pow, 0) * pmax(ratio, 1e-300)
  }

  tn_moments <- function(mu, tau2) {
    tau <- sqrt(pmax(tau2, 1e-12))
    alpha <- mu / tau
    Phi <- pnorm(alpha)
    Phi <- pmax(Phi, 1e-12)
    phi <- dnorm(alpha)
    Lambda <- phi / Phi
    Es  <- mu + tau * Lambda
    Es2 <- tau2 + mu^2 + tau * mu * Lambda
    list(Es = Es, Es2 = Es2)
  }

  # Stable log(sigmoid(x)) and log(1 - sigmoid(x))
  log_sigmoid <- function(x) {
    ifelse(x >= 0,
          -log1p(exp(-x)),
          x - log1p(exp(x)))
  }
  log1m_sigmoid <- function(x) log_sigmoid(-x)

  # log h'(eta) for gamma = L + (U-L) sigmoid(eta):
  # h'(eta) = (U-L) s(1-s).  We DROP log(U-L) since it's a constant in eta.
  log_hprime_noconst <- function(eta) log_sigmoid(eta) + log1m_sigmoid(eta)

  # compute xi's from Gaussian approx in (eta,ell) via Delta method
  compute_xi <- function(eta_hat, ell_hat, Sigma) {
    z0 <- c(eta_hat, ell_hat)

    trans_par <- function(z) {
      eta <- z[1]
      ell <- z[2]
      s   <- plogis(eta)

      gamma <- L + (U - L) * s
      sigma <- exp(ell)

      A  <- A_of(gamma)
      B  <- pmax(B_of(gamma), 1e-12)
      lam <- lam_of(gamma)

      list(
        eta = eta, ell = ell,
        gamma = gamma, sigma = sigma,
        A = A, B = B, lam = lam,
        log_hprime = log_hprime_noconst(eta) # no constant log(U-L)
      )
    }

    delta_E <- function(g_fun) {
      g0 <- g_fun(z0)
      H  <- numDeriv::hessian(g_fun, z0)
      g0 + 0.5 * sum(H * Sigma)
    }

    g_xi1 <- function(z) { p <- trans_par(z); 1 / (p$B * p$sigma) }
    g_xi_lambda <- function(z) { p <- trans_par(z); p$lam / p$B }
    g_xi_lambda2 <- function(z) { p <- trans_par(z); (p$lam^2) * p$sigma / p$B }
    g_xi_A <- function(z) { p <- trans_par(z); p$A / (p$B * p$sigma) }
    g_xi_A2 <- function(z) { p <- trans_par(z); (p$A^2) / (p$B * p$sigma) }
    g_xi_siginv <- function(z) { p <- trans_par(z); 1 / p$sigma }
    g_zeta_lam <- function(z) { p <- trans_par(z); (p$lam * p$A) / p$B }

    g_zeta_logsigma <- function(z) z[2]  # exact: log sigma = ell
    g_zeta_logB <- function(z) { p <- trans_par(z); log(pmax(p$B, 1e-300)) }
    g_zeta_logpi <- function(z) { p <- trans_par(z); log_prior_gamma_fun(p$gamma) }
    g_zeta_loghprime <- function(z) { p <- trans_par(z); p$log_hprime }

    list(
      xi1           = delta_E(g_xi1),
      xi_lambda     = delta_E(g_xi_lambda),
      xi_lambda2    = delta_E(g_xi_lambda2),
      xi_A          = delta_E(g_xi_A),
      xi_A2         = delta_E(g_xi_A2),
      xi_siginv     = delta_E(g_xi_siginv),
      zeta_lam      = delta_E(g_zeta_lam),
      zeta_logsigma = delta_E(g_zeta_logsigma),
      zeta_logB     = delta_E(g_zeta_logB),
      zeta_logpi    = delta_E(g_zeta_logpi),
      zeta_loghprime = delta_E(g_zeta_loghprime)
    )
  }


  # log-kernel for q(sigma,gamma) as a function of (eta, ell)
  log_qsiggam <- function(par) {
    eta <- as.numeric(par[1]); ell <- as.numeric(par[2])
    gamma <- g_from_eta(eta)
    sigma <- sig_from_ell(ell)

    A <- A_of(gamma); B <- B_of(gamma); lam <- lam_of(gamma)
    if (!is.finite(B) || B <= 0 || !is.finite(sigma) || sigma <= 0) return(-Inf)

    xb  <- drop(X %*% m_beta)
    t_i <- y - xb
    q_i <- rowSums((X %*% V_beta) * X)

    mv_inv <- E_inv_v
    mv     <- E_v
    ms     <- E_s
    ms2    <- E_s2

    term1 <- - (1 / (2 * B * sigma)) * sum( mv_inv * (t_i^2 + q_i) - 2 * A * t_i + (A * A) * mv )
    term2 <- - (sum(mv) + b_sigma) / sigma
    term3 <- + (lam / B) * sum( ms * mv_inv * t_i - ms * A )
    term4 <- - ( (lam * lam) / (2 * B) ) * sigma * sum( ms2 * mv_inv )

    log_prior_g <- log_prior_gamma_fun(gamma)

    log_prior_lsig <- if (use_lsig_prior) {
      -0.5 * ((ell - mu_lsig)^2 / s2_lsig)
    } else 0

    # Jacobian: + ell + log h'(eta)  (drop constant log(U-L))
    log_hprime <- log_hprime_noconst(eta)

    # This is: -(n/2)log B - (a_sigma + 3n/2)*ell  (since +ell Jacobian cancels the "+1")
    log_det <- - (n / 2) * log(B) - (a_sigma + (3 * n) / 2) * ell + log_hprime

    log_prior_g + log_prior_lsig + log_det + term1 + term2 + term3 + term4
  }


  # find LD mode & covariance for (eta, ell)
  find_mode_ld <- function(eta0, ell0) {
    par0 <- c(eta0, ell0)
    fn_neg <- function(z) { val <- log_qsiggam(z); if (is.finite(val)) -val else 1e100 }
    opt <- try(optim(par = par0, fn = fn_neg, method = "BFGS",
                     control = list(maxit = 10000), hessian = TRUE), silent = TRUE)
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      # small grid around start
      cand <- rbind(
        par0,
        par0 + c(-1,0), par0 + c(1,0), par0 + c(0,-1), par0 + c(0,1),
        par0 + c(-2,0), par0 + c(2,0), par0 + c(0,-2), par0 + c(0,2)
      )
      vals <- apply(cand, 1, function(z) log_qsiggam(z))
      idx  <- which.max(vals)
      opt  <- optim(par = cand[idx,], fn = fn_neg, method = "BFGS",
                    control = list(maxit = 10000), hessian = TRUE)
    }
    H <- opt$hessian
    if (!all(is.finite(H)) || any(is.nan(H))) {
      # numeric Hessian as fallback
      H <- try(numDeriv::hessian(function(z) -log_qsiggam(z), x = opt$par), silent = TRUE)
      if (inherits(H, "try-error") || any(!is.finite(H))) {
        H <- diag(1) * 1e-12
      }
    }

    # covariance = inverse observed information (for fn_neg = -log q)
    Sigma_raw <- tryCatch(solve(H), error = function(e) MASS::ginv(H))
    Sigma_raw <- (Sigma_raw + t(Sigma_raw)) / 2  # symmetrize

    # Enforce positive definiteness via eigenvalue floor
    eig <- eigen(Sigma_raw, symmetric = TRUE)
    vals <- pmax(eig$values, 1e-12)  # floor tiny/negative eigenvalues
    Sigma_pd <- eig$vectors %*% (diag(vals, nrow = 2, ncol = 2) %*% t(eig$vectors))
    Sigma_pd <- (Sigma_pd + t(Sigma_pd)) / 2  # re-symmetrize

    list(eta_hat = opt$par[1], ell_hat = opt$par[2], Sigma = Sigma_pd)
  }

  # --- main loop -------------------------------------------------------------
  t0 <- proc.time()[3]
  converged <- FALSE
  if (verbose) {
    cat(sprintf(
      "Static exAL LDVB | n=%d, p=%d | max_iter=%d, tol=%.1e, tol_par=%.1e\n",
      n, p, max_iter, tol, tol_par
    ))
  }

  # initial xi from a tiny covariance (deterministic at first iter)
  xis <- compute_xi(eta_hat, ell_hat, Sig_eta_ell)

  elbo_trace    <- numeric(0)
  elbo_old      <- -Inf
  gamma_trace   <- numeric(0)
  sigma_trace   <- numeric(0)
  eta_trace     <- numeric(0)
  ell_trace     <- numeric(0)
  rel_mb_trace  <- numeric(0)
  rel_xi_trace  <- numeric(0)

  new_term_trace <- numeric(0)

  gamma_old <- g_from_eta(eta_hat)
  sigma_old <- exp(ell_hat)

  for (iter in 1:max_iter) {
    m_beta_old <- m_beta
    xis_old    <- xis
    
    # ---- (1) q(beta) = N(m,V)
    W  <- as.numeric(xis$xi1 * E_inv_v)
    Xw <- X * sqrt(W)

    if (beta_prior_obj$type == "ridge" && !is_diag_matrix(V0)) {
      # Full-matrix ridge: beta ~ N(b0, V0)
      V_inv <- crossprod(Xw) + V0_inv
      Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
      if (is.null(Uc)) Uc <- chol(V_inv + 1e-12 * diag(p))
      V_beta_new <- chol2inv(Uc)

      rhs <- crossprod(X, W * y) -
        crossprod(X, (xis$xi_lambda * (E_inv_v * E_s))) -
        (xis$xi_A) * colSums(X) +
        as.numeric(V0_inv %*% b0)

    } else {
      # Diagonal precision path:
      #   - ridge + diagonal V0: use exact diag(V0)
      #   - RHS: use beta_prior_obj expected precision
      if (beta_prior_obj$type == "ridge" && is_diag_matrix(V0)) {
        v0_diag  <- pmax(as.numeric(diag(V0)), 1e-12)
        prec_diag <- pmax(1 / v0_diag, 1e-12)
      } else {
        prec_diag <- as.numeric(beta_prior_obj$expected_prec(beta_state, p))
        prec_diag <- pmax(prec_diag, 1e-12)
      }

      V_inv <- crossprod(Xw) + diag(prec_diag, p)
      Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
      if (is.null(Uc)) Uc <- chol(V_inv + 1e-12 * diag(p))
      V_beta_new <- chol2inv(Uc)

      rhs <- crossprod(X, W * y) -
        crossprod(X, (xis$xi_lambda * (E_inv_v * E_s))) -
        (xis$xi_A) * colSums(X) +
        prec_diag * b0
    }

    m_beta_new <- as.numeric(V_beta_new %*% rhs)
 

    # ---- (2) q(v_i) = GIG(1/2, chi_i, psi)
    xb   <- drop(X %*% m_beta_new)
    t_i  <- y - xb
    q_i  <- rowSums((X %*% V_beta_new) * X)
    psi  <- xis$xi_A2 + 2 * xis$xi_siginv
    chi  <- xis$xi1 * (t_i^2 + q_i) -
            2 * xis$xi_lambda * (y * E_s) +
            xis$xi_lambda2 * E_s2 +
            2 * xis$xi_lambda * (xb * E_s)

    chi <- pmax(chi, 1e-12)
    psi <- max(psi, 1e-12)

    # moments
    E_v_new    <- gig_moment(k = 0.5, chi = chi, psi = psi, r = 1)
    E_inv_v_new<- gig_moment(k = 0.5, chi = chi, psi = psi, r = -1)

    # ---- (3) q(s_i) = TN(μ, τ^2) on (0,∞)
    tau2  <- 1 / (1 + xis$xi_lambda2 * E_inv_v_new)
    mu_s  <- tau2 * ( xis$xi_lambda * (E_inv_v_new * (y - xb)) - xis$zeta_lam )
    s_mom <- tn_moments(mu_s, tau2)

    # commit beta/v/s so LD sees current factors
    m_beta  <- as.numeric(m_beta_new);  V_beta  <- V_beta_new
    E_v     <- as.numeric(E_v_new);     E_inv_v <- as.numeric(E_inv_v_new)
    qs_mu   <- as.numeric(mu_s);        qs_tau2 <- as.numeric(tau2)
    E_s     <- as.numeric(s_mom$Es);    E_s2    <- as.numeric(s_mom$Es2)
    beta_state <- beta_prior_obj$update(beta_state, list(m = m_beta, V = V_beta))

    # diagnostics that need old vs new:
    rel_mb <- sqrt(sum((m_beta_new - m_beta_old)^2)) / (1e-12 + sqrt(sum(m_beta_old^2)))

    # ---- (4) q(sigma,gamma) via LD (now sees current state)
    ld <- find_mode_ld(eta_hat, ell_hat)
    eta_hat <- ld$eta_hat
    ell_hat <- ld$ell_hat
    Sig_eta_ell <- ld$Sigma

    # current LD point (mode) on natural scale (used for printing + safeguard)
    ghat <- g_from_eta(eta_hat)
    shat <- exp(ell_hat)

    xis_new <- compute_xi(eta_hat, ell_hat, Sig_eta_ell)

    delta_xi <- unlist(xis_new) - unlist(xis_old)
    rel_xi   <- max(abs(delta_xi)) / (1e-12 + max(1, max(abs(unlist(xis_old)))))
    xis <- xis_new
    if (verbose && (iter %% 50 == 0)) {
      cat(sprintf("iter %4d | rel(mb)=%.2e rel(xi)=%.2e | gamma≈%.3f sigma≈%.3f\n",
                  iter, rel_mb, rel_xi, ghat, shat))
    }

    xb  <- drop(X %*% m_beta)
    t_i <- y - xb
    q_i <- rowSums((X %*% V_beta) * X)

    # GIG bits
    k_gig <- 0.5
    mlogv <- gig_E_log(k_gig, chi, psi)

    lik_norm <- -(n/2) * log(2*pi) -
                (n/2) * xis$zeta_logB -
                (n/2) * xis$zeta_logsigma -
                0.5   * sum(mlogv)

    lik_quad1 <- -0.5 * sum(
    xis$xi1     * E_inv_v * (t_i^2 + q_i) -
    2 * xis$xi_A          *  t_i           +
        xis$xi_A2 * E_v
    )

    lik_cross <- sum(
    xis$xi_lambda  * (E_s * E_inv_v * t_i) -
    xis$zeta_lam   *  E_s                   -
    0.5 * xis$xi_lambda2 * (E_s2 * E_inv_v)
    )

    E_log_pv <- - n * xis$zeta_logsigma - xis$xi_siginv * sum(E_v)

    E_log_ps <- n * log(2) - (n/2) * log(2*pi) - 0.5 * sum(E_s2)

    logdetV0 <- as.numeric(determinant(V0, logarithm = TRUE)$modulus)
    E_log_pb <- 0
    E_log_beta_latents <- 0

    if (beta_prior_obj$type == "ridge") {
      logdetV0 <- as.numeric(determinant(V0, logarithm = TRUE)$modulus)
      E_log_pb <- - (p/2) * log(2*pi) - 0.5 * logdetV0 -
        0.5 * ( sum(V0_inv * V_beta) +
                drop(crossprod(m_beta - b0, V0_inv %*% (m_beta - b0))) )
    } else if (beta_prior_obj$type %in% c("rhs", "rhs_ns")) {
      E_log_beta_latents <- beta_prior_obj$elbo(beta_state, list(m = m_beta, V = V_beta))$elbo
    }

    E_log_psig <- a_sigma * log(b_sigma) - lgamma(a_sigma) -
                (a_sigma + 1) * xis$zeta_logsigma - b_sigma * xis$xi_siginv

    E_log_plsig <- 0
    if (use_lsig_prior) {
      v_ell   <- Sig_eta_ell[2, 2]                    # Var(log sigma)
      mean_sq <- (ell_hat - mu_lsig)^2 + v_ell        # E[(ell - mu)^2]
      # again drop the normalizing constant; only quadratic term matters
      E_log_plsig <- -0.5 * mean_sq / s2_lsig
    }

    E_log_pgam <- xis$zeta_logpi

    logdetVb <- as.numeric(determinant(V_beta, logarithm = TRUE)$modulus)
    H_qb <- 0.5 * ( p * (1 + log(2*pi)) + logdetVb )

    z      <- sqrt(pmax(chi, 1e-16) * pmax(psi, 1e-16))
    logKk  <- log(pmax(besselK(z, nu = k_gig, expon.scaled = TRUE), 1e-300)) - z
    logC   <- (k_gig/2) * (log(pmax(psi,1e-16)) - log(pmax(chi,1e-16))) - log(2) - logKk
    H_qv   <- sum( -logC - (k_gig - 1) * mlogv + 0.5 * (chi * E_inv_v + psi * E_v) )

    # q(s) = [1/Z] N(μ,τ^2) 1{s>0}, with Z = Φ(μ/τ)
    tau   <- sqrt(pmax(qs_tau2, 1e-16))
    alpha <- qs_mu / tau
    Z     <- pmax(pnorm(alpha), 1e-16)   # Z = Φ(alpha)

    # E[(s-μ)^2] = E[s^2] - 2μE[s] + μ^2
    E_center2 <- E_s2 - 2 * qs_mu * E_s + qs_mu^2

    # H = -E log q = 0.5 log(2π) + log τ + (1/(2τ^2))E[(s-μ)^2] + log Z
    H_qs <- sum(
      0.5 * log(2*pi) +
      0.5 * log(pmax(qs_tau2, 1e-16)) +
      0.5 * E_center2 / pmax(qs_tau2, 1e-16) +
      log(Z)
    )

    # logdet for LD Gaussian
    logdetSig <- as.numeric(determinant(Sig_eta_ell, logarithm = TRUE)$modulus)

    # H(q_{sigma,gamma}) = H(N(eta,ell)) + E[ ell + log h'(eta) ]
    H_qsg <- 0.5 * ( 2 * (1 + log(2*pi)) + logdetSig ) +
            xis$zeta_logsigma + xis$zeta_loghprime
    # Put it together
    elbo_new <- lik_norm + lik_quad1 + lik_cross +
      E_log_pv + E_log_ps + E_log_pb +
      E_log_beta_latents +
      E_log_psig + E_log_plsig + E_log_pgam +
      H_qb + H_qv + H_qs + H_qsg

    elbo_new <- elbo_new/n

    # traces
    elbo_trace    <- c(elbo_trace, elbo_new)
    gamma_trace   <- c(gamma_trace, ghat)
    sigma_trace   <- c(sigma_trace, shat)
    eta_trace     <- c(eta_trace, eta_hat)
    ell_trace     <- c(ell_trace, ell_hat)
    rel_mb_trace  <- c(rel_mb_trace, rel_mb)
    rel_xi_trace  <- c(rel_xi_trace, rel_xi)
    # -------- Stopping rule (ELBO + (gamma,sigma) stability) ----------
    if (iter == 1) {
      inc      <- Inf
      rel_elbo <- Inf
      new_term <- Inf
    } else {
      inc      <- elbo_new - elbo_old
      rel_elbo <- inc / (1e-16 + abs(elbo_old))
      # NEW: safeguard term based on LD means of (gamma, sigma)
      # new_term = |old E[gamma] - new E[gamma]| + |old E[sigma] - new E[sigma]|
      new_term <- abs(ghat - gamma_old) + abs(shat - sigma_old)
    }

    new_term_trace <- c(new_term_trace, new_term)

    # Optional: print both absolute and relative changes + parameter term
    if (verbose && (iter %% 50 == 0)) {
      cat(sprintf(
        "    ELBO=%.6f | Δ=%.3e | Δrel=%.2e | new_term=%.3e\n",
        elbo_new, inc, rel_elbo, new_term
      ))
    }

    min_iter_elbo <- 10L
    if (iter >= min_iter_elbo &&
        abs(rel_elbo) < tol &&
        inc >= 0 &&
        new_term < tol_par) {
      converged <- TRUE
      # update "old" holders for completeness (not strictly needed if we break)
      gamma_old <- ghat
      sigma_old <- shat
      elbo_old  <- elbo_new
      break
    }

    # If not converged, update "old" state for next iteration
    elbo_old  <- elbo_new
    gamma_old <- ghat
    sigma_old <- shat

  }

  t1 <- proc.time()[3]

  # approximate means for gamma, sigma from LD mode
  gamma_mean <- g_from_eta(eta_hat)
  sigma_mean <- exp(ell_hat)

  ret <- list(
    qbeta = list(m = m_beta, V = V_beta),
    qv    = list(chi = chi, psi = psi, E_v = E_v, E_inv_v = E_inv_v),
    qs    = list(mu = qs_mu, tau2 = qs_tau2, E_s = E_s, E_s2 = E_s2),
    qsiggam = list(
      eta_hat = eta_hat, ell_hat = ell_hat, Sigma = Sig_eta_ell,
      gamma_mean = gamma_mean, sigma_mean = sigma_mean,
      xi = xis
    ),
    converged = converged,
    iter = iter,
    run.time = as.numeric(t1 - t0),
    misc = list(
      p0    = p0,
      bounds = c(L = L, U = U),
      n     = n,
      p     = p,
      elbo          = elbo_trace,
      gamma_trace   = gamma_trace,
      sigma_trace   = sigma_trace,
      eta_trace     = eta_trace,
      ell_trace     = ell_trace,
      rel_mb_trace  = rel_mb_trace,
      rel_xi_trace  = rel_xi_trace,
      new_term_trace = new_term_trace,
      tol_elbo      = tol,
      tol_par       = tol_par,
      init_gamma           = init_gamma,
      init_log_sigma       = init_log_sigma,
      prior_gamma_mu0      = prior_gamma_mu0,
      prior_gamma_s20      = prior_gamma_s20,
      prior_log_sigma_mu0  = prior_log_sigma_mu0,
      prior_log_sigma_s20  = prior_log_sigma_s20
    )
  )
  class(ret) <- "exal_vb"
  if (verbose) {
    cat(sprintf("LDVB %s in %d iters (%.2fs): gamma≈%.3f, sigma≈%.3f\n",
                ifelse(converged, "converged", "stopped"),
                iter, ret$run.time, ret$qsiggam$gamma_mean, ret$qsiggam$sigma_mean))
  }
  ret
}

#' Static exAL regression with ridge prior on beta (user-facing wrapper).
#'
#' This is a thin wrapper around `exal_static_LDVB_core()` that constructs a
#' simple ridge prior module and forwards all arguments. All computations are
#' still implemented inside the core; the `beta_prior` object is provided so
#' you can later move the beta-block updates behind a generic interface.
#'
#' @export
exal_static_LDVB <- function(
  y, X, p0,
  max_iter = 1000, tol = 1e-4, tol_par = tol,
  b0 = NULL, V0 = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma      = NULL,
  prior_gamma_mu0      = NULL,
  prior_gamma_s20      = NULL,
  prior_log_sigma_mu0  = NULL,
  prior_log_sigma_s20  = NULL,
  init                 = NULL,
  init_gamma           = NULL,
  init_log_sigma       = NULL,
  n_samp_xi = 200,
  verbose   = TRUE
){
  beta_prior <- ridge_prior_module(b0 = b0, V0 = V0)

  exal_static_LDVB_core(
    y = y, X = X, p0 = p0,
    max_iter = max_iter, tol = tol, tol_par = tol_par,
    b0 = b0, V0 = V0,
    a_sigma = a_sigma, b_sigma = b_sigma,
    gamma_bounds = gamma_bounds,
    log_prior_gamma     = log_prior_gamma,
    prior_gamma_mu0     = prior_gamma_mu0,
    prior_gamma_s20     = prior_gamma_s20,
    prior_log_sigma_mu0 = prior_log_sigma_mu0,
    prior_log_sigma_s20 = prior_log_sigma_s20,
    init           = init,
    init_gamma     = init_gamma,
    init_log_sigma = init_log_sigma,
    n_samp_xi = n_samp_xi,
    verbose   = verbose,
    beta_prior_module  = beta_prior,
    rhs_hypers = NULL
  )
}

#' Static exAL regression with regularized horseshoe (RHS) prior on beta.
#'
#' This function is meant to have the same interface as `exal_static_LDVB`,
#' plus a `rhs_hypers` list.
#'
#' @export
exal_static_LDVB_rhs <- function(
  y, X, p0,
  max_iter = 1000, tol = 1e-4, tol_par = tol,
  b0 = NULL, V0 = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma      = NULL,
  prior_gamma_mu0      = NULL,
  prior_gamma_s20      = NULL,
  prior_log_sigma_mu0  = NULL,
  prior_log_sigma_s20  = NULL,
  init                 = NULL,
  init_gamma           = NULL,
  init_log_sigma       = NULL,
  n_samp_xi = 200,
  verbose   = TRUE,
  rhs_hypers = NULL,
  beta_prior_obj = NULL
){
  if (is.null(rhs_hypers)) rhs_hypers <- list()
  if (is.null(beta_prior_obj)) beta_prior_obj <- beta_prior("rhs", rhs = rhs_hypers)

  exal_static_LDVB_core(
    y = y, X = X, p0 = p0,
    max_iter = max_iter, tol = tol, tol_par = tol_par,
    b0 = b0, V0 = V0,
    a_sigma = a_sigma, b_sigma = b_sigma,
    gamma_bounds = gamma_bounds,
    log_prior_gamma     = log_prior_gamma,
    prior_gamma_mu0     = prior_gamma_mu0,
    prior_gamma_s20     = prior_gamma_s20,
    prior_log_sigma_mu0 = prior_log_sigma_mu0,
    prior_log_sigma_s20 = prior_log_sigma_s20,
    init           = init,
    init_gamma     = init_gamma,
    init_log_sigma = init_log_sigma,
    n_samp_xi = n_samp_xi,
    verbose   = verbose,
    beta_prior_module = list(type = "rhs", hypers = beta_prior_obj$hypers),
    rhs_hypers = rhs_hypers,
    beta_prior_obj = beta_prior_obj
  )
}

# Simple prior "module" for a ridge prior on beta.
# For now this is just a container; the VB core still implements all
# ridge updates internally. Later you can move the beta-block updates
# behind a generic interface that uses this object.
ridge_prior_module <- function(b0, V0) {
  list(
    type = "ridge",
    b0   = b0,
    V0   = V0
  )
}
