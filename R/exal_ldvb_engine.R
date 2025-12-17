#' Internal LDVB engine (skeleton; returns exal_vb-compatible object)
exal_ldvb_engine <- function(y, X, p0, gamma_bounds,
                             vb_control, init,
                             prior_gamma, prior_sigma,
                             beta_prior_obj) {

  assert_matrix(X, "X")
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt

  init        <- init        %||% list()
  prior_gamma <- prior_gamma %||% list()
  prior_sigma <- prior_sigma %||% list()

  # beta prior object must provide a minimal interface
  need_fields <- c("type","hypers","init","expected_prec","update","elbo")
  miss <- setdiff(need_fields, names(beta_prior_obj))
  if (length(miss)) .stopf("beta_prior_obj missing fields: %s", paste(miss, collapse = ", "))

  need_funs <- c("init","expected_prec","update","elbo")
  bad <- need_funs[!vapply(beta_prior_obj[need_funs], is.function, TRUE)]
  if (length(bad)) .stopf("beta_prior_obj fields not functions: %s", paste(bad, collapse = ", "))

  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")
  if (length(gamma_bounds) != 2L) .stopf("gamma_bounds must be length 2.")

  # VB control defaults (defensive)
  vb_control <- vb_control %||% list()
  vb_control$max_iter <- as.integer(vb_control$max_iter %||% 150L)
  vb_control$tol      <- as.numeric(vb_control$tol      %||% 1e-4)
  vb_control$tol_par  <- as.numeric(vb_control$tol_par  %||% vb_control$tol)
  vb_control$verbose  <- isTRUE(vb_control$verbose %||% FALSE)

  n <- length(y)
  p <- ncol(X)

  L <- as.numeric(gamma_bounds[1])
  U <- as.numeric(gamma_bounds[2])
  if (!is.finite(L) || !is.finite(U) || !(L < U)) .stopf("gamma_bounds must be finite with L < U.")

  # scale-based sigma bounds (wide but finite)
  y_scale  <- stats::mad(y, constant = 1.4826)
  y_scale  <- if (is.finite(y_scale) && y_scale > 0) y_scale else stats::sd(y)
  y_scale  <- if (is.finite(y_scale) && y_scale > 0) y_scale else 1

  sigma_min <- max(1e-6, y_scale * 1e-3)
  sigma_max <- max(sigma_min * 10, y_scale * 1e3)
  ell_lo <- log(sigma_min)
  ell_hi <- log(sigma_max)

  # keep eta bounded so gamma never gets *too* close to L/U
  eta_lo <- -12
  eta_hi <-  12

  clamp01 <- function(u, eps = 1e-8) pmin(pmax(u, eps), 1 - eps)

  # --- initialize q(beta) ---
  qbeta <- list(
    m = as.numeric(init$beta_m %||% rep(0, p)),
    V = as.matrix(init$beta_V %||% diag(1, p))
  )
  if (length(qbeta$m) != p) .stopf("init$beta_m must be length p=%d.", p)
  if (!all(dim(qbeta$V) == c(p,p))) .stopf("init$beta_V must be p x p.")

  # --- initialize q(sig, gam) in unconstrained space (eta, ell) ---
  gamma0 <- init$gamma %||% prior_gamma$mu0 %||% 0
  sigma0 <- init$sigma %||% 1

  # keep gamma0 away from bounds
  pad <- 0.05 * (U - L)
  gamma0 <- min(max(as.numeric(gamma0), L + pad), U - pad)

  # initialize sigma using data scale
  sigma0 <- init$sigma %||% y_scale
  sigma0 <- min(max(as.numeric(sigma0), sigma_min), sigma_max)

  u0 <- clamp01((gamma0 - L) / (U - L))
  eta_hat <- qlogis(u0)
  ell_hat <- log(sigma0)

  qsiggam <- list(
    eta_hat = as.numeric(eta_hat),
    ell_hat = as.numeric(ell_hat),
    Sigma   = as.matrix(init$siggam_Sigma %||% diag(c(1e-2, 1e-2), 2L))  # (eta, ell)
  )
  if (!all(dim(qsiggam$Sigma) == c(2,2))) .stopf("init$siggam_Sigma must be 2x2 if supplied.")

  # --- initialize q(v), q(s) moments (needed for beta + latent updates) ---
  v_inv0 <- init$v_inv %||% rep(1, n)
  v_m0   <- init$v_m   %||% rep(1, n)

  s_m0   <- init$s_m   %||% rep(sqrt(2/pi), n)
  s_m20  <- init$s_m2  %||% rep(1, n)   # half-normal has E[s^2]=1

  v_inv0 <- as.numeric(v_inv0); v_m0 <- as.numeric(v_m0)
  s_m0   <- as.numeric(s_m0);   s_m20 <- as.numeric(s_m20)

  if (length(v_inv0) != n) .stopf("init$v_inv must be length n=%d.", n)
  if (length(v_m0)   != n) .stopf("init$v_m must be length n=%d.", n)
  if (any(!is.finite(v_inv0)) || any(v_inv0 <= 0)) .stopf("init$v_inv must be finite and > 0.")
  if (any(!is.finite(v_m0))   || any(v_m0   <= 0)) .stopf("init$v_m must be finite and > 0.")

  if (length(s_m0) != n)   .stopf("init$s_m must be length n=%d.", n)
  if (length(s_m20) != n)  .stopf("init$s_m2 must be length n=%d.", n)
  if (any(!is.finite(s_m0))   || any(s_m0 <= 0))   .stopf("init$s_m must be finite and > 0.")
  if (any(!is.finite(s_m20))  || any(s_m20 <= 0))  .stopf("init$s_m2 must be finite and > 0.")

  qv <- list(
    m     = v_m0,       # E[v_t]
    m_inv = v_inv0,     # E[1/v_t]
    chi   = rep(NA_real_, n),
    psi   = NA_real_    # scalar in our approx
  )

  qs <- list(
    m   = s_m0,         # E[s_t]
    m2  = s_m20,        # E[s_t^2]
    m0  = rep(NA_real_, n),  # untruncated mean
    v0  = rep(NA_real_, n)   # untruncated var
  )


  # --- beta prior latent state (ridge or rhs) ---
  beta_state <- beta_prior_obj$init(p)

  elbo_trace     <- numeric(0)
  gamma_trace    <- numeric(0)
  sigma_trace    <- numeric(0)
  new_term_trace <- numeric(0)
  converged <- FALSE

  # helpers: current point estimates
  cur_gamma_hat <- function() L + (U - L) * plogis(qsiggam$eta_hat)
  cur_sigma_hat <- function() exp(qsiggam$ell_hat)

  # --------------------------------------------------------------------------
  # Helpers for LD on (eta, ell) and delta-method xis (matches exal_static_LDVB)
  # --------------------------------------------------------------------------

  # prior on gamma: prefer user-supplied log_prior if present, else Normal(mu0,s20), else flat
  log_prior_gamma_fun <- NULL
  if (!is.null(prior_gamma$log_prior) && is.function(prior_gamma$log_prior)) {
    log_prior_gamma_fun <- prior_gamma$log_prior
  } else if (!is.null(prior_gamma$mu0) && !is.null(prior_gamma$s20)) {
    mu0 <- as.numeric(prior_gamma$mu0)[1L]
    s20 <- max(as.numeric(prior_gamma$s20)[1L], 1e-12)
    log_prior_gamma_fun <- function(g) dnorm(g, mean = mu0, sd = sqrt(s20), log = TRUE)
  } else {
    log_prior_gamma_fun <- function(g) 0
  }

  # IG(a,b) prior on sigma with density p(sigma) ∝ sigma^{-(a+1)} exp(-b/sigma)
  a_sigma <- as.numeric(prior_sigma$a %||% 1)[1L]
  b_sigma <- as.numeric(prior_sigma$b %||% 1)[1L]
  if (!is.finite(a_sigma) || a_sigma <= 0) .stopf("prior_sigma$a must be > 0.")
  if (!is.finite(b_sigma) || b_sigma <= 0) .stopf("prior_sigma$b must be > 0.")

  # stable logs for sigmoid and 1-sigmoid
  log_sigmoid <- function(x) ifelse(x >= 0, -log1p(exp(-x)), x - log1p(exp(x)))
  log1m_sigmoid <- function(x) log_sigmoid(-x)

  # Jacobian log h'(eta) for gamma = L + (U-L)*sigmoid(eta), dropping constant log(U-L)
  log_hprime_noconst <- function(eta) log_sigmoid(eta) + log1m_sigmoid(eta)

  # map (eta, ell) -> (gamma, sigma) and exAL constants
  trans_par <- function(z) {
    eta <- z[1]; ell <- z[2]
    s   <- plogis(eta)
    gamma <- L + (U - L) * s
    sigma <- exp(ell)

    abc <- exal_get_ABC(p0 = p0, gamma = gamma)
    A <- abc$A
    B <- pmax(abc$B, 1e-12)
    lam <- abc$C * abs(gamma)  # lambda(gamma) = C(gamma)*|gamma|

    list(eta = eta, ell = ell, gamma = gamma, sigma = sigma, A = A, B = B, lam = lam,
         log_hprime = log_hprime_noconst(eta))
  }

  compute_xi_fast <- function(eta_hat, ell_hat, Sigma) {
  z0 <- c(eta_hat, ell_hat)

  g_vec <- function(z) {
    p <- trans_par(z)

    # core xis
    xi1        <- 1 / (p$B * p$sigma)
    xi_lambda  <- p$lam / p$B
    xi_lambda2 <- (p$lam^2) * p$sigma / p$B
    xi_A       <- p$A / (p$B * p$sigma)
    xi_A2      <- (p$A^2) / (p$B * p$sigma)
    zeta_lam   <- (p$lam * p$A) / p$B

    # ELBO zetas
    zeta_logB      <- log(pmax(p$B, 1e-300))
    zeta_logpi     <- log_prior_gamma_fun(p$gamma)
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

  # steps: scale to local uncertainty
  h1s <- 1e-3 * sqrt(pmax(Sigma[1,1], 1e-8))
  h2s <- 1e-3 * sqrt(pmax(Sigma[2,2], 1e-8))
  h1  <- max(1e-4 * (1 + abs(eta_hat)), h1s)
  h2  <- max(1e-4 * (1 + abs(ell_hat)), h2s)
  h1  <- min(max(h1, 1e-6), 1e-2)
  h2  <- min(max(h2, 1e-6), 1e-2)

  f00   <- g_vec(z0)
  f10   <- g_vec(z0 + c( h1,  0))
  f_10  <- g_vec(z0 + c(-h1,  0))
  f01   <- g_vec(z0 + c(  0, h2))
  f0_1  <- g_vec(z0 + c(  0,-h2))
  f11   <- g_vec(z0 + c( h1, h2))
  f1_1  <- g_vec(z0 + c( h1,-h2))
  f_11  <- g_vec(z0 + c(-h1, h2))
  f_1_1 <- g_vec(z0 + c(-h1,-h2))

  H11 <- (f10 - 2*f00 + f_10) / (h1^2)
  H22 <- (f01 - 2*f00 + f0_1) / (h2^2)
  H12 <- (f11 - f1_1 - f_11 + f_1_1) / (4*h1*h2)

  corr <- 0.5 * (H11 * Sigma[1,1] + 2 * H12 * Sigma[1,2] + H22 * Sigma[2,2])
  out <- f00 + corr

  # exact sigma-only moments under ell ~ N(ell_hat, Sigma[2,2])
  out <- c(out,
           xi_siginv      = exp(-ell_hat + 0.5 * Sigma[2,2]),
           zeta_logsigma  = ell_hat)

  as.list(out)
  }

  # Truncated normal moments for s ~ N(mu, tau2) truncated to (0, inf)
  tn_moments <- function(mu, tau2) {
    tau2 <- pmax(as.numeric(tau2), 1e-12)
    tau  <- sqrt(tau2)
    mu   <- as.numeric(mu)

    alpha  <- mu / tau
    logPhi <- pnorm(alpha, log.p = TRUE)
    logphi <- dnorm(alpha, log = TRUE)

    # Mills ratio: lambda = phi/Phi
    # Use asymptotic approximation when alpha is very negative to avoid overflow/0-division.
    lambda <- exp(pmin(logphi - logPhi, 700))   # cap exponent to avoid Inf

    idx <- (alpha < -8)
    if (any(idx)) {
      a <- -alpha[idx]
      # lambda ≈ a + 1/a + 2/a^3 (good enough)
      lambda[idx] <- a + 1/a + 2/(a^3)
    }

    Es  <- mu + tau * lambda
    # Truncation implies Es > 0; enforce numerical floor
    Es  <- pmax(Es, 1e-12)

    Es2 <- tau2 + mu^2 + tau * mu * lambda
    # enforce Es2 >= Es^2
    Es2 <- pmax(Es2, Es^2 + 1e-12)

    list(Es = Es, Es2 = Es2)
  }


  # log-kernel for q(eta, ell) up to additive constants (same structure as static core)
  log_qsiggam <- function(par) {
    eta <- as.numeric(par[1]); ell <- as.numeric(par[2])
    s <- plogis(eta)
    gamma <- L + (U - L) * s
    sigma <- exp(ell)

    abc <- exal_get_ABC(p0 = p0, gamma = gamma)
    A <- abc$A
    B <- pmax(abc$B, 1e-12)
    lam <- abc$C * abs(gamma)

    if (!is.finite(B) || B <= 0 || !is.finite(sigma) || sigma <= 0) return(-Inf)

    # data-dependent pieces collapsed
    term1 <- - (1 / (2 * B * sigma)) * (S1 - 2 * A * S2 + (A * A) * S3)
    term2 <- - (S3 + b_sigma) / sigma
    term3 <- + (lam / B) * (S4 - A * S6)
    term4 <- - ((lam * lam) / (2 * B)) * sigma * S5

    log_prior_g <- log_prior_gamma_fun(gamma)
    log_det <- - (n / 2) * log(B) - (a_sigma + (3 * n) / 2) * ell + log_hprime_noconst(eta)

    log_prior_g + log_det + term1 + term2 + term3 + term4
  }

  
  # LD mode/cov finder for (eta, ell)
 find_mode_ld <- function(eta0, ell0) {
    par0 <- c(eta0, ell0)
    par0[1] <- min(max(par0[1], eta_lo), eta_hi)
    par0[2] <- min(max(par0[2], ell_lo), ell_hi)

    fn_neg <- function(z) { val <- log_qsiggam(z); if (is.finite(val)) -val else 1e100 }

    opt <- optim(
      par = par0, fn = fn_neg, method = "L-BFGS-B",
      lower = c(eta_lo, ell_lo), upper = c(eta_hi, ell_hi),
      control = list(maxit = 2000)
    )

    # Hessian: compute numerically at optimum
    H <- try(numDeriv::hessian(function(z) fn_neg(z), x = opt$par), silent = TRUE)
    if (inherits(H, "try-error") || any(!is.finite(H))) H <- diag(1e-6, 2)
    H <- 0.5 * (H + t(H))

    Sigma_raw <- tryCatch(solve(H), error = function(e) MASS::ginv(H))
    Sigma_raw <- 0.5 * (Sigma_raw + t(Sigma_raw))

    eg <- eigen(Sigma_raw, symmetric = TRUE)
    vals <- pmax(eg$values, 1e-12)
    Sigma_pd <- eg$vectors %*% (diag(vals, 2) %*% t(eg$vectors))
    Sigma_pd <- 0.5 * (Sigma_pd + t(Sigma_pd))

    list(eta_hat = opt$par[1], ell_hat = opt$par[2], Sigma = Sigma_pd)
  }
 
  # --------------------------------------------------------------------------
  # Initialize moments required by (2.1)-(2.3)
  # --------------------------------------------------------------------------
  # qv keeps both E[v] and E[1/v]
  if (is.null(qv$m)) qv$m <- rep(1, n)
  # qs keeps both E[s] and E[s^2]
  if (is.null(qs$m2)) qs$m2 <- rep(1, n)

  # initial xis from current LD approximation
  xis <- compute_xi_fast(qsiggam$eta_hat, qsiggam$ell_hat, qsiggam$Sigma)
  xis$xi1        <- pmax(xis$xi1, 1e-12)
  xis$xi_A2      <- pmax(xis$xi_A2, 1e-12)
  xis$xi_lambda2 <- pmax(xis$xi_lambda2, 1e-12)

  iter_run <- 0L
  gamma_old <- cur_gamma_hat()
  sigma_old <- cur_sigma_hat()

  elbo_trace  <- numeric(0)
  elbo_old    <- -Inf
  min_iter_elbo <- as.integer(vb_control$min_iter_elbo %||% 10L)

  t0 <- proc.time()[3]
  for (iter in seq_len(vb_control$max_iter)) {
    iter_run <- iter

    # ------------------------------------------------------------------------
    # (2.1) UPDATE q(beta) using Delta xis (matches static core, mean=0 prior)
    # ------------------------------------------------------------------------
    W <- as.numeric(xis$xi1 * qv$m_inv)     # length n, positive
    if (any(!is.finite(W)) || any(W <= 0)) .stopf("W (xi1*E[1/v]) invalid.")

    prec_diag <- beta_prior_obj$expected_prec(beta_state, p)
    prec_diag <- as.numeric(prec_diag)
    if (length(prec_diag) != p) .stopf("beta prior expected_prec must return length p=%d.", p)
    if (any(!is.finite(prec_diag)) || any(prec_diag <= 0)) .stopf("beta prior expected_prec must be finite and > 0.")

    Xw <- X * sqrt(W)
    Prec <- crossprod(Xw) + diag(prec_diag, p)
    Prec <- 0.5 * (Prec + t(Prec))

    rhs <- as.numeric(crossprod(X, W * y) -
                        crossprod(X, (xis$xi_lambda * (qv$m_inv * qs$m))) -
                        xis$xi_A * colSums(X))

    sol <- .solve_sympd(Prec, rhs)
    qbeta$V <- sol$inv
    qbeta$m <- as.numeric(sol$x)

    # ------------------------------------------------------------------------
    # (2.2) UPDATE q(v): GIG(1/2, chi_i, psi)
    # ------------------------------------------------------------------------
    xb  <- as.numeric(X %*% qbeta$m)
    t_i <- y - xb
    q_i <- rowSums((X %*% qbeta$V) * X)

    psi <- as.numeric(xis$xi_A2 + 2 * xis$xi_siginv)
    psi <- pmax(psi, 1e-12)

    chi <- as.numeric(
      xis$xi1 * (t_i^2 + q_i) -
        2 * xis$xi_lambda * (y * qs$m) +
        xis$xi_lambda2 * qs$m2 +
        2 * xis$xi_lambda * (xb * qs$m)
    )
    chi <- pmax(chi, 1e-12)

    m_gig <- .gig_half_moments(chi = chi, psi = psi)
    qv$m     <- as.numeric(m_gig$m)
    qv$m_inv <- as.numeric(m_gig$m_inv)
    z_gig    <- as.numeric(m_gig$z)   # cache for ELBO (entropy normalizer)
    if (any(!is.finite(qv$m)) || any(qv$m <= 0)) .stopf("E[v] invalid in q(v) update.")
    if (any(!is.finite(qv$m_inv)) || any(qv$m_inv <= 0)) .stopf("E[1/v] invalid in q(v) update.")

    # ------------------------------------------------------------------------
    # (2.2) UPDATE q(s): TN(mu_s, tau2) on (0, inf)
    # ------------------------------------------------------------------------
    tau2 <- 1 / (1 + xis$xi_lambda2 * qv$m_inv)
    tau2 <- pmax(tau2, 1e-12)

    mu_s <- tau2 * (xis$xi_lambda * (qv$m_inv * (y - xb)) - xis$zeta_lam)
    moms <- tn_moments(mu_s, tau2)

    # qs$m  <- as.numeric(moms$Es)
    # qs$m2 <- as.numeric(moms$Es2)
    # if (any(!is.finite(qs$m))  || any(qs$m <= 0))  .stopf("E[s] invalid in q(s) update.")
    # if (any(!is.finite(qs$m2)) || any(qs$m2 <= 0)) .stopf("E[s^2] invalid in q(s) update.")
    qs$m  <- as.numeric(moms$Es)
    qs$m2 <- as.numeric(moms$Es2)

    bad_s <- which(!is.finite(qs$m) | qs$m <= 0)
    bad_s2 <- which(!is.finite(qs$m2) | qs$m2 <= 0)

    if (length(bad_s) || length(bad_s2)) {
      j <- if (length(bad_s)) bad_s[1] else bad_s2[1]

      dbg <- list(
        iter = iter,
        j = j,
        mu_s_j = mu_s[j],
        tau2_j = tau2[j],
        # recompute alpha for visibility
        alpha_j = mu_s[j] / sqrt(tau2[j]),
        qs_m_j  = qs$m[j],
        qs_m2_j = qs$m2[j],
        # current state that can cause extreme mu_s
        xis = xis,
        gamma_hat = cur_gamma_hat(),
        sigma_hat = cur_sigma_hat(),
        qv_m_inv_summary = summary(qv$m_inv),
        mu_s_summary = summary(mu_s),
        tau2_summary = summary(tau2)
      )

      saveRDS(dbg, file = sprintf("debug_qs_fail_iter_%04d.rds", iter))
      .stopf("E[s] invalid in q(s) update. Saved debug_qs_fail_iter_%04d.rds", iter)
    }

    # ------------------------------------------------------------------------
    # (2.3) UPDATE q(sigma, gamma) jointly via Laplace–Delta on (eta, ell)
    # ------------------------------------------------------------------------
    # Precompute stats for LD optimization (depends on current qbeta,qv,qs only)
    xb  <- as.numeric(X %*% qbeta$m)
    t_i <- y - xb
    q_i <- rowSums((X %*% qbeta$V) * X)

    mv_inv <- qv$m_inv
    mv     <- qv$m
    ms     <- qs$m
    ms2    <- qs$m2

    S1 <- sum(mv_inv * (t_i^2 + q_i))          # sum E[1/v] * E[(y-xb)^2]
    S2 <- sum(t_i)                             # sum (y-xb)
    S3 <- sum(mv)                              # sum E[v]
    S4 <- sum(ms * mv_inv * t_i)               # sum E[s]E[1/v](y-xb)
    S5 <- sum(ms2 * mv_inv)                    # sum E[s^2]E[1/v]
    S6 <- sum(ms)                              # sum E[s]

    ld <- find_mode_ld(qsiggam$eta_hat, qsiggam$ell_hat)
    qsiggam$eta_hat <- as.numeric(ld$eta_hat)
    qsiggam$ell_hat <- as.numeric(ld$ell_hat)
    qsiggam$Sigma   <- as.matrix(ld$Sigma)

    # refresh xis after LD update
    xis <- compute_xi_fast(qsiggam$eta_hat, qsiggam$ell_hat, qsiggam$Sigma)
    xi_vec <- unlist(xis)
    if (any(!is.finite(xi_vec))) {
      saveRDS(list(iter=iter, xis=xis, qsiggam=qsiggam),
              file = sprintf("debug_xis_nan_iter_%04d.rds", iter))
      .stopf("xis contains non-finite values (saved debug_xis_nan_iter_%04d.rds).", iter)
    }

    # These must be >0 in your algebra
    if (xis$xi1 <= 0 || xis$xi_lambda2 <= 0 || xis$xi_A2 <= 0 || xis$xi_siginv <= 0) {
      saveRDS(list(iter=iter, xis=xis, qsiggam=qsiggam),
              file = sprintf("debug_xis_bad_iter_%04d.rds", iter))
      .stopf("xis has invalid sign/scale (saved debug_xis_bad_iter_%04d.rds).", iter)
    }

    xis$xi1        <- pmax(as.numeric(xis$xi1),        1e-12)
    xis$xi_A2      <- pmax(as.numeric(xis$xi_A2),      1e-12)
    xis$xi_lambda2 <- pmax(as.numeric(xis$xi_lambda2), 1e-12)
    xis$xi_siginv  <- pmax(as.numeric(xis$xi_siginv),  1e-12)

    # ------------------------------------------------------------------------
    # beta-prior latent update (RHS etc) using NEW q(beta)
    # ------------------------------------------------------------------------
    beta_state <- beta_prior_obj$update(beta_state, qbeta)

    # ------------------------------------------------------------------------
    # ELBO (per-observation), computed using CURRENT q factors and CURRENT xis
    # ------------------------------------------------------------------------

    # Cached from this iter:
    # xb, t_i, q_i computed right after qbeta update (reuse)
    # chi, psi computed in qv update (reuse)
    # mu_s, tau2 computed in qs update (reuse)
    # xis computed after LD update (reuse)
    # z_gig from .gig_half_moments (reuse)

    # E[log v] under GIG(k=1/2, chi, psi) via derivative of log K_nu
    gig_E_log_half <- function(chi, psi) {
      chi <- pmax(as.numeric(chi), 1e-12)
      psi <- pmax(as.numeric(psi), 1e-12)
      z   <- sqrt(chi * psi)

      k <- 0.5
      dlogK <- .dlog_besselK_dnu(z, nu = k)

      0.5 * (log(chi) - log(psi)) + dlogK
    }


    mlogv <- gig_E_log_half(chi = chi, psi = psi)

    # (1) Likelihood normalizers
    lik_norm <- -(n/2) * log(2*pi) -
      (n/2) * as.numeric(xis$zeta_logB) -
      (n/2) * as.numeric(xis$zeta_logsigma) -
      0.5 * sum(mlogv)

    # (2) Likelihood quadratic in (y - x'beta) and A
    lik_quad1 <- -0.5 * sum(
      as.numeric(xis$xi1)    * qv$m_inv * (t_i^2 + q_i) -
        2 * as.numeric(xis$xi_A)       *  t_i +
        as.numeric(xis$xi_A2) * qv$m
    )

    # (3) Likelihood cross terms and s^2 term
    lik_cross <- sum(
      as.numeric(xis$xi_lambda)  * (qs$m * qv$m_inv * t_i) -
        as.numeric(xis$zeta_lam) *  qs$m -
        0.5 * as.numeric(xis$xi_lambda2) * (qs$m2 * qv$m_inv)
    )

    # (4) E log p(v | sigma): v_i ~ Exp(rate = 1/sigma)
    E_log_pv <- - n * as.numeric(xis$zeta_logsigma) -
      as.numeric(xis$xi_siginv) * sum(qv$m)

    # (5) E log p(s): s_i ~ N^+(0,1)
    E_log_ps <- n * log(2) - (n/2) * log(2*pi) - 0.5 * sum(qs$m2)

    # (6) beta prior contribution (NOT including H(qbeta))
    beta2 <- as.numeric(qbeta$m^2 + diag(qbeta$V))
    E_log_pb <- 0
    E_log_beta_latents <- 0

    if (beta_prior_obj$type == "ridge") {
      # reuse the same diag precision used in qbeta update this iter: `prec_diag`
      E_log_pb <- sum(0.5 * (log(prec_diag) - log(2*pi)) - 0.5 * prec_diag * beta2)
    } else if (beta_prior_obj$type == "rhs") {
      E_log_beta_latents <- as.numeric(beta_prior_obj$elbo(beta_state, qbeta)$elbo)
    }

    # (7) E log p(sigma): sigma ~ IG(a_sigma, b_sigma)
    E_log_psig <- a_sigma * log(b_sigma) - lgamma(a_sigma) -
      (a_sigma + 1) * as.numeric(xis$zeta_logsigma) -
      b_sigma * as.numeric(xis$xi_siginv)

    # (8) E log p(gamma)
    E_log_pgam <- as.numeric(xis$zeta_logpi)

    # (9) Entropy H(qbeta): use chol from the solve if available
    logdetVb <- NA_real_
    if (!is.null(sol$chol)) {
      logdetPrec <- 2 * sum(log(diag(sol$chol)))
      logdetVb <- -logdetPrec
    } else {
      logdetVb <- as.numeric(determinant(qbeta$V, logarithm = TRUE)$modulus)
    }
    H_qb <- 0.5 * ( p * (1 + log(2*pi)) + logdetVb )

    # (10) Entropy H(qv): GIG entropy formula, with k=1/2 and cached z
    k_gig <- 0.5
    z <- pmax(as.numeric(z_gig), 1e-16)

    # log K_{1/2}(z) in closed form: K_{1/2}(z)=sqrt(pi/(2z)) exp(-z)
    logKk <- 0.5 * (log(pi) - log(2) - log(z)) - z

    logC <- (k_gig/2) * (log(pmax(psi, 1e-16)) - log(pmax(chi, 1e-16))) - log(2) - logKk

    H_qv <- sum(
      -logC -
        (k_gig - 1) * mlogv +
        0.5 * (chi * qv$m_inv + psi * qv$m)
    )

    # (11) Entropy H(qs): truncated normal on (0,inf)
    tau  <- sqrt(pmax(tau2, 1e-16))
    alpha <- mu_s / tau
    Ztn  <- pmax(pnorm(alpha), 1e-16)

    E_center2 <- qs$m2 - 2 * mu_s * qs$m + mu_s^2

    H_qs <- sum(
      0.5 * log(2*pi) +
        0.5 * log(pmax(tau2, 1e-16)) +
        0.5 * E_center2 / pmax(tau2, 1e-16) +
        log(Ztn)
    )

    # (12) Entropy H(q_{sigma,gamma}) from LD Gaussian + Jacobian term
    Sig <- qsiggam$Sigma
    detSig <- Sig[1,1] * Sig[2,2] - Sig[1,2] * Sig[2,1]
    logdetSig <- log(pmax(detSig, 1e-12))

    H_qsg <- 0.5 * (2 * (1 + log(2*pi)) + logdetSig) +
      as.numeric(xis$zeta_logsigma) +
      as.numeric(xis$zeta_loghprime)

    elbo_new <- lik_norm + lik_quad1 + lik_cross +
      E_log_pv + E_log_ps +
      E_log_pb + E_log_beta_latents +
      E_log_psig + E_log_pgam +
      H_qb + H_qv + H_qs + H_qsg

    # per-observation ELBO (stable across n)
    elbo_new <- as.numeric(elbo_new / n)

    elbo_trace <- c(elbo_trace, elbo_new)

    # stopping rule uses ELBO + (gamma,sigma) stability
    if (iter == 1L) {
      rel_elbo <- Inf
    } else {
      rel_elbo <- (elbo_new - elbo_old) / (1e-16 + abs(elbo_old))
    }

    # keep your safeguard term (already computed earlier as new_term)
    # but now use it jointly with ELBO stabilization
    elbo_old <- elbo_new

    # ------------------------------------------------------------------------
    # traces + stopping (parameter-change safeguard; NO ELBO yet)
    # ------------------------------------------------------------------------
    gamma_hat <- cur_gamma_hat()
    sigma_hat <- cur_sigma_hat()
    # ---- parameter-change safeguard (match exal_static_LDVB_core logic) ----
    new_term <- if (iter == 1L) {
      Inf
    } else {
      abs(gamma_hat - gamma_old) + abs(sigma_hat - sigma_old)
    }
    new_term_trace <- c(new_term_trace, new_term)

    # update "old" holders for next iter
    gamma_old <- gamma_hat
    sigma_old <- sigma_hat

    gamma_trace <- c(gamma_trace, gamma_hat)
    sigma_trace <- c(sigma_trace, sigma_hat)

    if (iter >= min_iter_elbo &&
        is.finite(rel_elbo) &&
        abs(rel_elbo) < vb_control$tol &&
        is.finite(new_term) &&
        new_term < vb_control$tol_par) {
      converged <- TRUE
      break
    }

    gamma_old <- gamma_hat
    sigma_old <- sigma_hat

    if (isTRUE(vb_control$verbose) && (iter %% 25L == 0L)) {
      cat(sprintf("iter %4d | gamma≈%.4f sigma≈%.4f | new_term=%.3e\n",
                  iter, gamma_hat, sigma_hat, new_term))
    }
  }

  # Attach useful last-iteration objects for downstream steps
  new_term_trace <- as.numeric(new_term_trace)
  gamma_trace    <- as.numeric(gamma_trace)
  sigma_trace    <- as.numeric(sigma_trace)
  
  misc_elbo <- elbo_trace

  t_end <- proc.time()[3]

  structure(list(
    qbeta = qbeta,
    qv = list(chi = chi, psi = psi, E_v = qv$m, E_inv_v = qv$m_inv, m = qv$m, m_inv = qv$m_inv),
    qs = list(mu = mu_s, tau2 = tau2, E_s = qs$m, E_s2 = qs$m2, m = qs$m, m2 = qs$m2),
    qsiggam = list(
      eta_hat = qsiggam$eta_hat, ell_hat = qsiggam$ell_hat, Sigma = qsiggam$Sigma,
      gamma_mean = cur_gamma_hat(), sigma_mean = cur_sigma_hat(), xi = xis
    ),

    converged = converged,
    iter = iter_run,
    run.time = as.numeric(t_end - t0),

    beta_prior = list(type = beta_prior_obj$type, hypers = beta_prior_obj$hypers, state = beta_state),

    misc = list(
      p0 = p0, bounds = c(L = L, U = U), n = n, p = p,
      gamma_trace = gamma_trace, sigma_trace = sigma_trace, new_term_trace = new_term_trace,
      elbo = elbo_trace, elbo_trace = elbo_trace
    )
  ), class = "exal_vb")



}
