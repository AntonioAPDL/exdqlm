# Internal helpers for static LDVB transformed (sigma, gamma) block.
.exal_static_ld_log_jacobian <- function(eta, ell, L, U) {
  s <- stats::plogis(eta)
  s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
  log(pmax(U - L, 1e-12)) + log(s) + log1p(-s) + ell
}

.exal_static_ld_log_qsiggam <- function(par, state, include_jacobian = TRUE) {
  eta <- as.numeric(par[1])
  ell <- as.numeric(par[2])
  gamma <- state$g_from_eta(eta)
  sigma <- state$sig_from_ell(ell)

  A <- state$A_of(gamma)
  B <- state$B_of(gamma)
  lam <- state$lam_of(gamma)
  if (!is.finite(B) || B <= 0 || !is.finite(sigma) || sigma <= 0) {
    return(-Inf)
  }

  xb <- drop(state$X %*% state$m_beta)
  t_i <- state$y - xb
  q_i <- rowSums((state$X %*% state$V_beta) * state$X)

  term1 <- - (1 / (2 * B * sigma)) * sum(
    state$E_inv_v * (t_i^2 + q_i) - 2 * A * t_i + (A * A) * state$E_v
  )
  term2 <- - (sum(state$E_v) + state$b_sigma) / sigma
  term3 <- + (lam / B) * sum(state$E_s * state$E_inv_v * t_i - state$E_s * A)
  term4 <- - ((lam * lam) / (2 * B)) * sigma * sum(state$E_s2 * state$E_inv_v)

  log_prior <- state$log_prior_gamma(gamma)
  log_det <- - (state$n / 2) * log(B) - (((3 * state$n) / 2) + state$a_sigma + 1) * ell
  val <- log_prior + log_det + term1 + term2 + term3 + term4

  if (isTRUE(include_jacobian)) {
    val <- val + .exal_static_ld_log_jacobian(eta, ell, state$L, state$U)
  }

  val
}

#' Static exAL Regression - CAVI with Laplace-Delta for (sigma, gamma)
#'
#' The function applies a coordinate-ascent variational inference (CAVI)
#' algorithm to static Extended Asymmetric Laplace (exAL) regression, using a
#' Laplace-Delta approximation for the joint \eqn{(\sigma,\gamma)} block.
#'
#' @param y Numeric vector (length n).
#' @param X Numeric matrix (n x p).
#' @param p0 Target quantile in (0,1).
#' @param max_iter Integer; maximum CAVI iterations (default 1000).
#' @param tol Numeric; convergence tolerance based on relative ELBO changes (default 1e-4).
#' @param b0,V0 Prior mean and covariance for \eqn{\beta \sim \mathcal{N}(b_0,V_0)}.
#' @param a_sigma,b_sigma Prior for \eqn{\sigma \sim IG(a_\sigma,b_\sigma)} with
#'   density \eqn{p(\sigma)\propto \sigma^{-(a_\sigma+1)} e^{-b_\sigma/\sigma}}.
#' @param gamma_bounds Two-vector (L, U) support for \code{gamma}.
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Function \code{g -> log pi(gamma=g)} (default flat).
#' @param init Optional list with starting values: \code{beta}, \code{sigma},
#'   \code{gamma}; if missing, reasonable defaults are used.
#' @param n_samp_xi Integer; number of MC draws used to compute the xi expectations for
#'   \eqn{q(\sigma,\gamma)} (default 200).
#' @param verbose Logical; print progress.
#'
#' @return A object of class "\code{exal_vb}" containing:
#' \itemize{
#'   \item \code{qbeta}: list with \code{m}, \code{V}.
#'   \item \code{qv}: list with \code{chi} (length n), \code{psi} (scalar),
#'         \code{E_v} and \code{E_inv_v} (moments).
#'   \item \code{qs}: list with \code{mu} (length n), \code{tau2} (length n),
#'         \code{E_s}, \code{E_s2}.
#'   \item \code{qsiggam}: list with \code{eta_hat}, \code{ell_hat},
#'         \code{Sigma} (2x2), approximate means
#'         \code{gamma_mean}, \code{sigma_mean}, and the \code{xi} expectations.
#'   \item \code{converged}, \code{iter}, \code{run.time}, and
#'         \code{misc} (including \code{p0}, bounds \code{L,U}, dimensions, and ELBO trace).
#' }
#'
#' @details
#' Mean-field factorization:
#' \deqn{q(\beta)\ \prod_{i=1}^n q(v_i)\ q(s_i)\ q(\sigma,\gamma).}
#' The LD block is parameterized in transformed coordinates
#' \eqn{\eta=\mathrm{logit}((\gamma-L)/(U-L))} and \eqn{\ell=\log\sigma}.
#' The \code{xi} expectations used in CAVI updates are approximated from a small
#' Gaussian Monte Carlo sample in \eqn{(\eta,\ell)}.
#'
#' @examples
#' \donttest{
#' set.seed(123)
#' n <- 60
#' X <- cbind(1, seq(-1, 1, length.out = n))
#' y <- as.numeric(X %*% c(0.2, -0.1) + rnorm(n, sd = 0.15))
#' fit <- exal_static_LDVB(y = y, X = X, p0 = 0.5, max_iter = 100, tol = 1e-3, verbose = FALSE)
#' fit$converged
#' }
#' @export
exal_static_LDVB <- function(
  y, X, p0,
  max_iter = 1000, tol = 1e-4,
  b0 = NULL, V0 = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma = function(g) 0,
  init = NULL,
  n_samp_xi = 200,
  verbose = TRUE
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

  # --- A,B,C,lambda helpers -------------------------------------------------
  A_of   <- function(g) A.fn(p0, g)
  B_of   <- function(g) B.fn(p0, g)
  C_of   <- function(g) C.fn(p0, g)
  lam_of <- function(g) C_of(g) * abs(g)

  # transform (eta,ell) <-> (gamma,sigma)
  g_from_eta <- function(eta) { s <- stats::plogis(eta); L + (U - L) * s }
  sig_from_ell <- function(ell) exp(ell)

  # --- initialize variational parameters ------------------------------------
  m_beta  <- if (is.null(init$beta)) rep(0, p) else as.numeric(init$beta)
  V_beta  <- V0
  sigma0  <- if (is.null(init$sigma)) 1 else as.numeric(init$sigma)[1]
  gamma0  <- if (is.null(init$gamma)) 0 else as.numeric(init$gamma)[1]
  gamma0  <- min(max(gamma0, L + 1e-6), U - 1e-6)

  # q(v): initialize moments (use 1 for both)
  E_inv_v <- rep(1, n)
  E_v     <- rep(1, n)

  # q(s): initialize moments (half-normal)
  qs_mu   <- rep(0, n)
  qs_tau2 <- rep(1, n)
  E_s     <- sqrt(2/pi) * rep(1, n)  # E[N^+(0,1)]
  E_s2    <- rep(1, n)               # Var + mean^2 = 1 + 2/pi (but ok to start at 1)

  # q(sigma,gamma): start at point mass to get xi's
  eta_hat <- stats::qlogis((gamma0 - L) / (U - L))
  ell_hat <- log(sigma0)
  Sig_eta_ell <- diag(c(1e-4, 1e-4))  # tiny to start; inflated after first LD update

  # --- numerics helpers ------------------------------------------------------
  V0_inv <- tryCatch(
    solve(V0),
    error = function(e) solve(V0 + 1e-8 * diag(p))
  )

    # E[log V] for V ~ GIG(k, chi, psi)
    gig_E_log <- function(k, chi, psi) {
    chi <- pmax(chi, 1e-14); psi <- pmax(psi, 1e-14)
    z   <- sqrt(chi * psi)
    eps <- 1e-6
    logK <- function(nu) {
        val <- besselK(z, nu = nu, expon.scaled = TRUE)
        log(pmax(val, 1e-300)) - z   # undo expon.scaled
    }
    dlogK <- (logK(k + eps) - logK(k - eps)) / (2 * eps)
    0.5 * (log(chi) - log(psi)) + dlogK
    }

  gig_moment <- function(k, chi, psi, r) {
    # E[v^r] = (sqrt(chi/psi))^r * K_{k+r}(sqrt(chi*psi))/K_k(sqrt(chi*psi))
    z <- sqrt(pmax(chi, 1e-14) * pmax(psi, 1e-14))
    num <- besselK(z, nu = k + r, expon.scaled = TRUE)
    den <- besselK(z, nu = k,     expon.scaled = TRUE)
    ratio <- num / den
    ratio[!is.finite(ratio)] <- 1
    pow   <- (sqrt(pmax(chi, 1e-14) / pmax(psi, 1e-14)))^r
    pmax(pow, 0) * pmax(ratio, 1e-300)
  }

  tn_moments <- function(mu, tau2) {
    tau <- sqrt(pmax(tau2, 1e-14))
    alpha <- mu / tau
    Phi <- stats::pnorm(alpha)
    Phi <- pmax(Phi, 1e-12)
    phi <- stats::dnorm(alpha)
    Lambda <- phi / Phi
    Es  <- mu + tau * Lambda
    Es2 <- tau2 + mu^2 + tau * mu * Lambda
    list(Es = Es, Es2 = Es2)
  }

  # compute xi's from Gaussian approx in (eta,ell)
    compute_xi <- function(eta_hat, ell_hat, Sigma, ns = n_samp_xi) {
    ns <- max(1L, as.integer(ns))

    # draw (eta, ell) ~ N([eta_hat, ell_hat], Sigma)
    chol_U <- tryCatch(chol(Sigma), error = function(e) NULL)
    if (is.null(chol_U)) chol_U <- chol(Sigma + 1e-8 * diag(2))

    Z    <- matrix(stats::rnorm(2 * ns), nrow = 2, ncol = ns)   # 2 x ns
    pars <- sweep(chol_U %*% Z, 1, c(eta_hat, ell_hat), "+")  # 2 x ns
    eta  <- pars[1, ]
    ell  <- pars[2, ]

    gamma <- g_from_eta(eta)
    sigma <- sig_from_ell(ell)

    A   <- A_of(gamma)
    B   <- B_of(gamma)
    lam <- lam_of(gamma)

    xi1        <- mean(1 / (B * sigma))
    xi_lambda  <- mean(lam / B)
    xi_lambda2 <- mean((lam * lam) * sigma / B)
    xi_A       <- mean(A / (B * sigma))
    xi_A2      <- mean((A * A) / (B * sigma))
    xi_siginv  <- mean(exp(-ell))               # E[1/sigma]
    zeta_lam   <- mean((lam * A) / B)
    zeta_logJ     <- mean(.exal_static_ld_log_jacobian(eta, ell, L, U))
    zeta_logsigma <- mean(ell)
    zeta_logB     <- mean(log(pmax(B, 1e-300)))
    zeta_logpi    <- mean(vapply(gamma, log_prior_gamma, numeric(1)))

    list(
    xi1 = xi1,
    xi_lambda = xi_lambda,
    xi_lambda2 = xi_lambda2,
    xi_A = xi_A,
    xi_A2 = xi_A2,
    xi_siginv = xi_siginv,
    zeta_lam = zeta_lam,
    zeta_logJ = zeta_logJ,
    zeta_logsigma = zeta_logsigma,
    zeta_logB = zeta_logB,
    zeta_logpi = zeta_logpi
    )

    }

  # log-kernel for q(sigma,gamma) as a function of (eta, ell)
  log_qsiggam <- function(par) {
    .exal_static_ld_log_qsiggam(
      par = par,
      state = list(
        y = y,
        X = X,
        n = n,
        m_beta = m_beta,
        V_beta = V_beta,
        E_inv_v = E_inv_v,
        E_v = E_v,
        E_s = E_s,
        E_s2 = E_s2,
        a_sigma = a_sigma,
        b_sigma = b_sigma,
        L = L,
        U = U,
        A_of = A_of,
        B_of = B_of,
        lam_of = lam_of,
        g_from_eta = g_from_eta,
        sig_from_ell = sig_from_ell,
        log_prior_gamma = log_prior_gamma
      ),
      include_jacobian = TRUE
    )
  }

  # find LD mode & covariance for (eta, ell)
  find_mode_ld <- function(eta0, ell0) {
    par0 <- c(eta0, ell0)
    fn_neg <- function(z) { val <- log_qsiggam(z); if (is.finite(val)) -val else 1e50 }
    opt <- try(optim(par = par0, fn = fn_neg, method = "BFGS",
                     control = list(maxit = 200), hessian = TRUE), silent = TRUE)
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
                    control = list(maxit = 200), hessian = TRUE)
    }
    H <- opt$hessian
    if (!all(is.finite(H)) || any(is.nan(H))) {
      # numeric Hessian as fallback
      H <- try(numDeriv::hessian(function(z) -log_qsiggam(z), x = opt$par), silent = TRUE)
      if (inherits(H, "try-error") || any(!is.finite(H))) {
        H <- diag(2) * 1e-2
      }
    }
    # covariance = inverse observed information
    Sigma <- tryCatch(
      solve(H),
      error = function(e) solve(H + 1e-8 * diag(nrow(H)))
    )
    # symmetrize & guard
    Sigma <- (Sigma + t(Sigma))/2
    list(eta_hat = opt$par[1], ell_hat = opt$par[2], Sigma = Sigma)
  }

  # --- main loop -------------------------------------------------------------
  t0 <- proc.time()[3]
  converged <- FALSE
  if (verbose) {
    cat(sprintf("Static exAL LDVB | n=%d, p=%d | max_iter=%d, tol=%.1e\n",
                n, p, max_iter, tol))
  }

  # initial xi from a tiny covariance (deterministic at first iter)
  xis <- compute_xi(eta_hat, ell_hat, Sig_eta_ell, ns = max(50, floor(n_samp_xi/2)))
  elbo_trace <- numeric(0)
  elbo_old   <- -Inf
  for (iter in 1:max_iter) {

    # ---- (1) q(beta) = N(m,V)
    # V = (V0^{-1} + xi1 * X^T diag(E[1/v]) X)^{-1}
    W <- xis$xi1 * E_inv_v
    Xw <- X * sqrt(W)
    V_inv <- crossprod(Xw) + V0_inv
    Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
    V_beta_new <- chol2inv(Uc)

    # m = V ( V0^{-1} b0 + X^T [ xi1 diag(E[1/v]) y - xi_lambda (E[1/v] * E[s]) - xi_A 1 ] )
    rhs <- crossprod(X, W * y) -
           crossprod(X, (xis$xi_lambda * (E_inv_v * E_s))) 

    # Careful: The xi_A * 1_n term multiplies X^T * 1_n
    rhs <- rhs + (V0_inv %*% b0) - (xis$xi_A) * colSums(X)

    m_beta_new <- V_beta_new %*% rhs

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

    # ---- (3) q(s_i) = TN(mu, tau^2) on (0, Inf)
    tau2  <- 1 / (1 + xis$xi_lambda2 * E_inv_v_new)
    mu_s  <- tau2 * ( xis$xi_lambda * (E_inv_v_new * (y - xb)) - xis$zeta_lam )
    s_mom <- tn_moments(mu_s, tau2)

    # ---- (4) q(sigma,gamma) via LD
    ld <- find_mode_ld(eta_hat, ell_hat)
    eta_hat <- ld$eta_hat
    ell_hat <- ld$ell_hat
    Sig_eta_ell <- ld$Sigma

    # update xi via MC under Gaussian (eta,ell)
    xis_new <- compute_xi(eta_hat, ell_hat, Sig_eta_ell, ns = n_samp_xi)

    # ---- check convergence
    rel_mb <- sqrt(sum((m_beta_new - m_beta)^2)) / (1e-8 + sqrt(sum(m_beta^2)))
    rel_xi <- max(abs(unlist(xis_new)) - abs(unlist(xis)))
    rel_xi <- abs(rel_xi) / (1e-8 + max(1, max(abs(unlist(xis)))))

    if (verbose && (iter %% 50 == 0)) {
      ghat <- g_from_eta(eta_hat); shat <- exp(ell_hat)
      cat(sprintf("iter %4d | rel(mb)=%.2e rel(xi)=%.2e | gamma~%.3f sigma~%.3f\n",
                  iter, rel_mb, rel_xi, ghat, shat))
    }

    # commit new values
    m_beta <- as.numeric(m_beta_new); V_beta <- V_beta_new
    E_v    <- as.numeric(E_v_new);    E_inv_v <- as.numeric(E_inv_v_new)
    qs_mu  <- as.numeric(mu_s);       qs_tau2 <- as.numeric(tau2)
    E_s    <- as.numeric(s_mom$Es);   E_s2    <- as.numeric(s_mom$Es2)
    xis    <- xis_new

    ## ---------- ELBO (term-by-term) ------------------------------------------
    # Precompute residual pieces
    xb  <- drop(X %*% m_beta)
    t_i <- y - xb
    q_i <- rowSums((X %*% V_beta) * X)

    # GIG bits
    k_gig <- 0.5
    mlogv <- gig_E_log(k_gig, chi, psi)

    # (1) Likelihood: normalizers
    lik_norm <- -(n/2) * log(2*pi) -
                (n/2) * xis$zeta_logB -
                (n/2) * xis$zeta_logsigma -
                0.5   * sum(mlogv)

    # (2) Likelihood: quadratic part 1
    lik_quad1 <- -0.5 * sum(
    xis$xi1     * E_inv_v * (t_i^2 + q_i) -
    2 * xis$xi_A          *  t_i           +
        xis$xi_A2 * E_v
    )

    # (3) Likelihood: cross & s^2 terms
    lik_cross <- sum(
    xis$xi_lambda  * (E_s * E_inv_v * t_i) -
    xis$zeta_lam   *  E_s                   -
    0.5 * xis$xi_lambda2 * (E_s2 * E_inv_v)
    )

    # (4) E[log p(v | sigma)] with v_i ~ Exp(rate = 1/sigma)
    E_log_pv <- - n * xis$zeta_logsigma - xis$xi_siginv * sum(E_v)

    # (5) E[log p(s)] for s_i ~ N^+(0,1)
    E_log_ps <- n * log(2) - (n/2) * log(2*pi) - 0.5 * sum(E_s2)

    # (6) E[log p(beta)] : Normal(b0, V0)
    logdetV0 <- as.numeric(determinant(V0, logarithm = TRUE)$modulus)
    E_log_pb <- - (p/2) * log(2*pi) - 0.5 * logdetV0 -
                0.5 * ( sum(V0_inv * V_beta) +
                        drop(crossprod(m_beta - b0, V0_inv %*% (m_beta - b0))) )

    # (7) E[log p(sigma)] : IG(a_sigma, b_sigma)
    E_log_psig <- a_sigma * log(b_sigma) - lgamma(a_sigma) -
                (a_sigma + 1) * xis$zeta_logsigma - b_sigma * xis$xi_siginv

    # (8) E[log p(gamma)]
    E_log_pgam <- xis$zeta_logpi

    # (9) Entropy H(q(beta))
    logdetVb <- as.numeric(determinant(V_beta, logarithm = TRUE)$modulus)
    H_qb <- 0.5 * ( p * (1 + log(2*pi)) + logdetVb )

    # (10) Entropy H(q(v))
    z      <- sqrt(pmax(chi, 1e-14) * pmax(psi, 1e-14))
    logKk  <- log(pmax(besselK(z, nu = k_gig, expon.scaled = TRUE), 1e-300)) - z
    logC   <- (k_gig/2) * (log(pmax(psi,1e-14)) - log(pmax(chi,1e-14))) - log(2) - logKk
    H_qv   <- sum( -logC - (k_gig - 1) * mlogv + 0.5 * (chi * E_inv_v + psi * E_v) )

    # (11) Entropy H(q(s)) for TN(mu, tau^2) on (0, Inf)
    tau    <- sqrt(pmax(qs_tau2, 1e-14))
    alpha  <- qs_mu / tau
    Phi    <- pmax(stats::pnorm(alpha), 1e-12)
    Lambda <- stats::dnorm(alpha) / Phi
    H_qs   <- sum( 0.5 * log(2*pi * qs_tau2) + log(Phi) + 0.5 * (1 + alpha * Lambda) )

    # (12) H(q(sigma,gamma)) = H(q(eta,ell)) + E_q[log|J(eta,ell)|]
    # for sigma=exp(ell), gamma=L+(U-L)logit^{-1}(eta).
    logdetSig <- as.numeric(determinant(Sig_eta_ell, logarithm = TRUE)$modulus)
    H_qsg     <- 0.5 * ( 2 * (1 + log(2*pi)) + logdetSig ) + xis$zeta_logJ

    # Put it together
    elbo_new <- lik_norm + lik_quad1 + lik_cross +
                E_log_pv + E_log_ps + E_log_pb + E_log_psig + E_log_pgam +
                H_qb + H_qv + H_qs + H_qsg
    elbo_trace <- c(elbo_trace, elbo_new)

    # -------- Stopping rule (ELBO-based) ----------
    if (iter == 1) {
    inc <- Inf; rel_elbo <- Inf
    } else {
    inc <- elbo_new - elbo_old
    rel_elbo <- inc / (1e-8 + abs(elbo_old))
    }

    # Optional: print both absolute and relative changes
    if (verbose && (iter %% 50 == 0)) {
    cat(sprintf("    ELBO=%.6f | delta=%.3e | delta_rel=%.2e\n", elbo_new, inc, rel_elbo))
    }

    # Require ELBO to have *stabilized* (small absolute relative change), and
    # NEVER stop on a negative jump. Also wait a few iterations before checking.
    min_iter_elbo <- 10L
    if (iter >= min_iter_elbo && abs(rel_elbo) < tol && inc >= 0) {
    converged <- TRUE
    break
    }

    elbo_old <- elbo_new

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
    misc = list(p0 = p0, bounds = c(L = L, U = U), n = n, p = p, elbo = elbo_trace)
  )
  class(ret) <- "exal_vb"
  if (verbose) {
    cat(sprintf("LDVB %s in %d iters (%.2fs): gamma~%.3f, sigma~%.3f\n",
                ifelse(converged, "converged", "stopped"),
                iter, ret$run.time, ret$qsiggam$gamma_mean, ret$qsiggam$sigma_mean))
  }
  ret
}
