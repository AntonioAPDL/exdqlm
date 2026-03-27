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
  vb_control$rhs_trace <- isTRUE(vb_control$rhs_trace %||% FALSE)
  vb_control$rhs_deep <- isTRUE(vb_control$rhs_deep %||% FALSE)
  vb_control$rhs_trace_top_k <- as.integer(vb_control$rhs_trace_top_k %||% 20L)
  vb_control$rhs_trace_thresholds <- as.numeric(vb_control$rhs_trace_thresholds %||% c(1e3, 1e6, 1e9))
  vb_control$rhs_trace_eps <- as.numeric(vb_control$rhs_trace_eps %||% c(1e-6, 1e-4, 1e-2))
  vb_control$rhs_freeze_tau_iters <- as.integer(vb_control$rhs_freeze_tau_iters %||% 0L)
  vb_control$rhs_update_every <- as.integer(vb_control$rhs_update_every %||% 1L)
  vb_control$rhs_update_every_warmup <- as.integer(vb_control$rhs_update_every_warmup %||% 1L)
  vb_control$rhs_update_every_warmup_iters <- as.integer(vb_control$rhs_update_every_warmup_iters %||% 0L)
  vb_control$rhs_beta_presteps <- as.integer(vb_control$rhs_beta_presteps %||% 1L)
  vb_control$rhs_beta_presteps_iters <- as.integer(vb_control$rhs_beta_presteps_iters %||% 0L)
  vb_control$rhs_gradcheck <- isTRUE(vb_control$rhs_gradcheck %||% FALSE)
  vb_control$rhs_gradcheck_iters <- as.integer(vb_control$rhs_gradcheck_iters %||% c(1L, 5L))
  vb_control$rhs_gradcheck_h <- as.numeric(vb_control$rhs_gradcheck_h %||% 1e-5)
  vb_control$rhs_freeze_tau_warmup_iters <- as.integer(
    vb_control$rhs_freeze_tau_warmup_iters %||% vb_control$rhs_freeze_tau_iters %||% 0L
  )
  vb_control$rhs_tau_local_tol <- as.numeric(vb_control$rhs_tau_local_tol %||% NA_real_)
  vb_control$rhs_min_tau_updates <- as.integer(vb_control$rhs_min_tau_updates %||% 1L)
  vb_control$rhs_max_tau_updates <- vb_control$rhs_max_tau_updates %||% NA
  vb_control$rhs_force_tau_after_warmup <- isTRUE(vb_control$rhs_force_tau_after_warmup %||% TRUE)
  vb_control$rhs_recompute_elbo_after_tau_update <- isTRUE(
    vb_control$rhs_recompute_elbo_after_tau_update %||% TRUE
  )

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
    Sigma   = as.matrix(init$siggam_Sigma %||% diag(c(1e-16, 1e-16), 2L))  # (eta, ell)
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


  # --- beta prior latent state (ridge or rhs family) ---
  beta_state <- beta_prior_obj$init(p)
  beta_prior_type <- as.character(beta_prior_obj$type %||% "")
  is_rhs <- identical(beta_prior_type, "rhs")
  is_rhs_ns <- identical(beta_prior_type, "rhs_ns")
  is_rhs_family <- is_rhs || is_rhs_ns

  rhs_trace_on <- isTRUE(vb_control$rhs_trace) && is_rhs_family
  rhs_deep_on  <- isTRUE(vb_control$rhs_deep) && is_rhs
  if (rhs_deep_on && !rhs_trace_on) rhs_trace_on <- TRUE
  rhs_trace_top_k <- as.integer(vb_control$rhs_trace_top_k %||% 20L)
  if (!is.finite(rhs_trace_top_k) || rhs_trace_top_k < 0L) rhs_trace_top_k <- 0L
  rhs_trace_thresholds <- as.numeric(vb_control$rhs_trace_thresholds %||% c(1e3, 1e6, 1e9))
  rhs_trace_thresholds <- rhs_trace_thresholds[is.finite(rhs_trace_thresholds) & rhs_trace_thresholds > 0]
  rhs_trace_thresholds <- sort(unique(rhs_trace_thresholds))
  rhs_trace_eps <- as.numeric(vb_control$rhs_trace_eps %||% c(1e-6, 1e-4, 1e-2))
  rhs_trace_eps <- rhs_trace_eps[is.finite(rhs_trace_eps) & rhs_trace_eps > 0]
  rhs_trace_eps <- sort(unique(rhs_trace_eps))
  rhs_freeze_tau_warmup_iters <- max(0L, as.integer(
    vb_control$rhs_freeze_tau_warmup_iters %||% vb_control$rhs_freeze_tau_iters %||% 0L
  ))
  rhs_update_every <- as.integer(vb_control$rhs_update_every %||% 1L)
  if (!is.finite(rhs_update_every) || rhs_update_every < 1L) rhs_update_every <- 1L
  rhs_update_every_warmup <- as.integer(vb_control$rhs_update_every_warmup %||% rhs_update_every)
  if (!is.finite(rhs_update_every_warmup) || rhs_update_every_warmup < 1L) rhs_update_every_warmup <- rhs_update_every
  rhs_update_every_warmup_iters <- max(0L, as.integer(vb_control$rhs_update_every_warmup_iters %||% 0L))
  rhs_beta_presteps <- as.integer(vb_control$rhs_beta_presteps %||% 1L)
  if (!is.finite(rhs_beta_presteps) || rhs_beta_presteps < 1L) rhs_beta_presteps <- 1L
  rhs_beta_presteps_iters <- max(0L, as.integer(vb_control$rhs_beta_presteps_iters %||% 0L))
  rhs_gradcheck_on <- isTRUE(vb_control$rhs_gradcheck %||% FALSE)
  rhs_gradcheck_iters <- as.integer(vb_control$rhs_gradcheck_iters %||% c(1L, 5L))
  rhs_gradcheck_iters <- rhs_gradcheck_iters[rhs_gradcheck_iters > 0]
  rhs_gradcheck_h <- as.numeric(vb_control$rhs_gradcheck_h %||% 1e-5)
  if (!is.finite(rhs_gradcheck_h) || rhs_gradcheck_h <= 0) rhs_gradcheck_h <- 1e-5

  rhs_tau_local_tol <- as.numeric(vb_control$rhs_tau_local_tol %||% NA_real_)
  if (!is.finite(rhs_tau_local_tol)) rhs_tau_local_tol <- NA_real_
  rhs_min_tau_updates <- max(0L, as.integer(vb_control$rhs_min_tau_updates %||% 1L))
  rhs_max_tau_updates <- vb_control$rhs_max_tau_updates %||% NA_integer_
  if (length(rhs_max_tau_updates) == 0L) rhs_max_tau_updates <- NA_integer_
  if (!is.na(rhs_max_tau_updates)) rhs_max_tau_updates <- as.integer(rhs_max_tau_updates)
  rhs_force_tau_after_warmup <- isTRUE(vb_control$rhs_force_tau_after_warmup %||% TRUE)
  rhs_recompute_elbo_after_tau_update <- isTRUE(
    vb_control$rhs_recompute_elbo_after_tau_update %||% TRUE
  )

  if (rhs_trace_on) beta_state$diag_on <- TRUE
  if (rhs_deep_on) beta_state$diag_deep <- TRUE

  elbo_trace     <- numeric(0)
  gamma_trace    <- numeric(0)
  sigma_trace    <- numeric(0)
  new_term_trace <- numeric(0)
  rhs_tau_trace        <- numeric(0)
  rhs_c2_trace         <- numeric(0)
  rhs_lambda_mean_trace <- numeric(0)
  rhs_lambda_min_trace  <- numeric(0)
  rhs_lambda_max_trace  <- numeric(0)
  converged <- FALSE

  # helpers: current point estimates
  cur_gamma_hat <- function() L + (U - L) * plogis(qsiggam$eta_hat)
  cur_sigma_hat <- function() exp(qsiggam$ell_hat)
  exp_safe <- function(x) exp(pmin(pmax(as.numeric(x), -745), 709))

  log1p_exp <- function(x) {
    x <- as.numeric(x)
    out <- numeric(length(x))
    pos <- x > 0
    out[pos]  <- x[pos] + log1p(exp_safe(-x[pos]))
    out[!pos] <- log1p(exp_safe(x[!pos]))
    out
  }
  logsumexp2 <- function(a, b) {
    m <- pmax(a, b)
    m + log(exp_safe(a - m) + exp_safe(b - m))
  }
  summ_stats <- function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) return(c(min = NA_real_, median = NA_real_, max = NA_real_))
    c(min = min(x), median = stats::median(x), max = max(x))
  }
  top_k_idx <- function(x, k) {
    k <- as.integer(k)
    if (!length(x) || k <= 0L) return(integer(0))
    x <- as.numeric(x)
    x[!is.finite(x)] <- -Inf
    k <- min(k, length(x))
    order(x, decreasing = TRUE)[seq_len(k)]
  }

  rhs_make_snapshot <- function(beta_state, qbeta, beta_prior_obj) {
    list(
      iter = NA_integer_,
      eta_lambda = as.numeric(beta_state$eta_lambda_hat),
      eta_tau = as.numeric(beta_state$eta_tau_hat),
      eta_c2 = as.numeric(beta_state$eta_c_hat),
      beta2 = as.numeric(qbeta$m^2 + diag(qbeta$V)),
      shrink_intercept = isTRUE(beta_state$shrink_intercept),
      tau0 = as.numeric(beta_prior_obj$hypers$tau0 %||% 1),
      nu = as.numeric(beta_prior_obj$hypers$nu %||% 4),
      s = as.numeric(beta_prior_obj$hypers$s %||% 1)
    )
  }

  rhs_profile_logtau_snapshot <- function(snap, eta_grid) {
    eta_lam <- as.numeric(snap$eta_lambda)
    eta_tau0 <- as.numeric(snap$eta_tau)
    eta_c2  <- as.numeric(snap$eta_c2)
    beta2 <- as.numeric(snap$beta2)
    shrink_intercept <- isTRUE(snap$shrink_intercept)

    if (!shrink_intercept) {
      if (length(beta2) >= 2L) {
        eta_lam <- eta_lam[-1L]
        beta2 <- beta2[-1L]
      } else {
        eta_lam <- numeric(0)
        beta2 <- numeric(0)
      }
    }

    loglam <- eta_lam
    a <- eta_c2
    logtau0 <- log(as.numeric(snap$tau0 %||% 1))
    nu <- as.numeric(snap$nu %||% 4)
    s_used <- as.numeric(snap$s %||% 1)

    term_lambda_const <- sum(loglam - log1p_exp(2 * loglam))
    term_c2_const <- -(nu / 2) * a - (nu * s_used^2) / (2 * exp_safe(a))

    out <- lapply(eta_grid, function(eta_tau) {
      u <- 2 * eta_tau + 2 * loglam
      ld <- logsumexp2(a, u)
      logV <- a + u - ld
      log_invV <- logsumexp2(-a, -u)
      invV <- exp_safe(log_invV)
      term_logV <- -0.5 * sum(logV)
      term_quad <- -0.5 * sum(beta2 * invV)
      term_tau <- eta_tau - log1p_exp(2 * (eta_tau - logtau0))
      obj_total <- term_logV + term_quad + term_lambda_const + term_tau + term_c2_const

      w <- exp_safe(u - logsumexp2(a, u))
      t <- exp_safe(-u)
      s_tau <- plogis(2 * (eta_tau - logtau0))
      grad_tau <- -sum(1 - w) + sum(beta2 * t) + (1 - 2 * s_tau)

      data.frame(
        eta_tau = eta_tau,
        tau = exp_safe(eta_tau),
        obj_total = obj_total,
        term_logV = term_logV,
        term_quad = term_quad,
        term_tau = term_tau,
        term_lambda = term_lambda_const,
        term_c2 = term_c2_const,
        grad_eta_tau = grad_tau
      )
    })

    prof <- do.call(rbind, out)
    prof$eta_tau_center <- eta_tau0
    prof
  }

  rhs_diag_collect <- function(iter, beta_state, qbeta, prec_diag, term_names = NULL,
                               prev_log_tau = NA_real_, log_tau_bounds = NULL,
                               rhs_update_skipped = FALSE,
                               tau_update_allowed = NA,
                               tau_update_performed = NA,
                               tau_update_reason = NA_character_,
                               delta_L_local = NA_real_,
                               tau_warmup = NA,
                               u_tau = NA_integer_,
                               t_last_tau = NA_integer_,
                               tau_local_tol = NA_real_,
                               gradcheck_on = FALSE, gradcheck_iters = integer(0), gradcheck_h = 1e-5) {
    prev_log_tau_scalar <- if (length(prev_log_tau) >= 1L) as.numeric(prev_log_tau[1L]) else NA_real_
    prior_type <- as.character(beta_prior_obj$type %||% "")
    if (identical(prior_type, "rhs_ns")) {
      p_state <- as.integer(beta_state$p %||% length(qbeta$m))
      if (!is.finite(p_state) || p_state <= 0L) p_state <- as.integer(length(qbeta$m))
      shrink_intercept <- isTRUE(beta_state$shrink_intercept)
      idx <- if (shrink_intercept) seq_len(p_state) else if (p_state >= 2L) 2L:p_state else integer(0)
      if (!length(idx)) {
        return(list(row = data.frame(iter = iter), detail = list()))
      }

      beta_mean <- as.numeric(qbeta$m)
      beta_var <- as.numeric(diag(qbeta$V))
      beta_mean_use <- beta_mean[idx]
      beta_var_use <- beta_var[idx]
      beta2_use <- beta_mean_use^2 + beta_var_use

      lambda2 <- as.numeric(beta_state$lambda2 %||% rep(NA_real_, p_state))
      if (length(lambda2) == 1L && p_state > 1L) lambda2 <- rep(lambda2, p_state)
      if (length(lambda2) != p_state) lambda2 <- rep(NA_real_, p_state)
      e_inv_lambda <- as.numeric(beta_state$E_inv_lambda2 %||% rep(NA_real_, p_state))
      if (length(e_inv_lambda) == 1L && p_state > 1L) e_inv_lambda <- rep(e_inv_lambda, p_state)
      if (length(e_inv_lambda) != p_state) e_inv_lambda <- rep(NA_real_, p_state)

      lambda_hat <- sqrt(pmax(lambda2, 1e-24))
      bad_lambda <- !is.finite(lambda_hat) | lambda_hat <= 0
      if (any(bad_lambda)) {
        lam_fallback <- sqrt(1 / pmax(e_inv_lambda, 1e-24))
        lambda_hat[bad_lambda] <- lam_fallback[bad_lambda]
      }
      lambda_hat <- pmax(as.numeric(lambda_hat[idx]), 1e-24)
      loglam <- log(lambda_hat)

      e_inv_tau <- as.numeric(beta_state$E_inv_tau2 %||% NA_real_)[1L]
      tau2 <- as.numeric(beta_state$tau2 %||% NA_real_)[1L]
      if (!is.finite(tau2) || tau2 <= 0) {
        tau2 <- if (is.finite(e_inv_tau) && e_inv_tau > 0) 1 / e_inv_tau else NA_real_
      }
      tau2 <- pmax(as.numeric(tau2), 1e-24)
      tau_hat <- sqrt(tau2)
      log_tau <- log(tau_hat)
      if (!is.finite(e_inv_tau) || e_inv_tau <= 0) e_inv_tau <- 1 / tau2

      e_inv_zeta <- as.numeric(beta_state$E_inv_zeta2 %||% NA_real_)[1L]
      c2_hat <- as.numeric(beta_state$zeta2 %||% NA_real_)[1L]
      if (!is.finite(c2_hat) || c2_hat <= 0) {
        c2_hat <- if (is.finite(e_inv_zeta) && e_inv_zeta > 0) 1 / e_inv_zeta else NA_real_
      }
      if (!is.finite(c2_hat) || c2_hat <= 0) {
        c2_hat <- as.numeric(beta_prior_obj$hypers$s2 %||% 1.0)[1L]
      }
      c2_hat <- pmax(as.numeric(c2_hat), 1e-24)
      log_c2 <- log(c2_hat)
      if (!is.finite(e_inv_zeta) || e_inv_zeta <= 0) e_inv_zeta <- 1 / c2_hat

      prec_use <- as.numeric(prec_diag[idx])
      e_inv_lambda_use <- pmax(as.numeric(e_inv_lambda[idx]), 1e-24)
      prec_fallback <- e_inv_tau * e_inv_lambda_use + e_inv_zeta
      bad_prec <- !is.finite(prec_use) | prec_use <= 0
      if (any(bad_prec)) {
        prec_use[bad_prec] <- prec_fallback[bad_prec]
      }
      prec_use <- pmax(as.numeric(prec_use), 1e-16)
      invV <- prec_use
      V <- 1 / invV

      n_prec_gt <- vapply(rhs_trace_thresholds, function(th) sum(prec_use > th, na.rm = TRUE), integer(1))
      names(n_prec_gt) <- paste0("n_prec_gt_", format(rhs_trace_thresholds, scientific = TRUE))

      n_beta_small <- vapply(rhs_trace_eps, function(eps) sum(abs(beta_mean_use) < eps, na.rm = TRUE), integer(1))
      names(n_beta_small) <- paste0("n_beta_abs_lt_", format(rhs_trace_eps, scientific = TRUE))

      beta_l2 <- sqrt(sum(beta_mean_use^2))
      beta_absmax <- if (length(beta_mean_use)) max(abs(beta_mean_use)) else NA_real_
      D_rhs <- length(beta2_use)
      R_val <- sum(beta2_use * invV)
      R_over_D <- if (D_rhs > 0) R_val / D_rhs else NA_real_

      rhs_diag <- beta_state$rhs_diag %||% list()
      tau_up <- rhs_diag$tau_update %||% list()
      s2_used <- as.numeric(beta_prior_obj$hypers$s2 %||% NA_real_)[1L]
      s_used <- if (is.finite(s2_used) && s2_used > 0) sqrt(s2_used) else NA_real_

      row <- data.frame(
        iter = iter,
        tau = tau_hat,
        log_tau = log_tau,
        delta_log_tau = if (is.finite(prev_log_tau_scalar)) (log_tau - prev_log_tau_scalar) else NA_real_,
        log_tau_clipped = NA,
        log_tau_clip_side = NA_character_,
        rhs_update_skipped = isTRUE(rhs_update_skipped),
        tau_update_allowed = as.logical(tau_update_allowed),
        tau_update_performed = as.logical(tau_update_performed),
        tau_update_reason = as.character(tau_update_reason %||% NA_character_),
        delta_L_local = as.numeric(delta_L_local),
        tau_warmup = as.logical(tau_warmup),
        u_tau = as.integer(u_tau),
        t_last_tau = as.integer(t_last_tau),
        tau_local_tol = as.numeric(tau_local_tol),
        tau0 = as.numeric(beta_prior_obj$hypers$tau0 %||% NA_real_),
        c2 = c2_hat,
        log_c2 = log_c2,
        s = s_used,
        s2 = s2_used,
        nu = as.numeric(beta_prior_obj$hypers$nu %||% NA_real_),
        lambda_min = summ_stats(lambda_hat)[1],
        lambda_med = summ_stats(lambda_hat)[2],
        lambda_max = summ_stats(lambda_hat)[3],
        log_lambda_min = summ_stats(loglam)[1],
        log_lambda_med = summ_stats(loglam)[2],
        log_lambda_max = summ_stats(loglam)[3],
        V_min = summ_stats(V)[1],
        V_med = summ_stats(V)[2],
        V_max = summ_stats(V)[3],
        invV_min = summ_stats(invV)[1],
        invV_med = summ_stats(invV)[2],
        invV_max = summ_stats(invV)[3],
        E_invV_min = summ_stats(prec_use)[1],
        E_invV_med = summ_stats(prec_use)[2],
        E_invV_max = summ_stats(prec_use)[3],
        R = R_val,
        R_over_D = R_over_D,
        D_rhs = D_rhs,
        beta_l2 = beta_l2,
        beta_var_sum = sum(beta_var_use),
        beta_var_mean = mean(beta_var_use),
        beta2_sum = sum(beta2_use),
        beta2_mean = mean(beta2_use),
        beta_absmax = beta_absmax,
        term_logV = NA_real_,
        term_quad = NA_real_,
        term_lambda = NA_real_,
        term_tau = NA_real_,
        term_c2 = NA_real_,
        obj_total = NA_real_,
        grad_tau = NA_real_,
        grad_tau_fd = NA_real_,
        grad_tau_fd_rel_err = NA_real_,
        grad_inf = NA_real_,
        hess_jitter = as.numeric(rhs_diag$hess_jitter %||% NA_real_),
        chol_diag_min = as.numeric(rhs_diag$chol_diag_min %||% NA_real_),
        chol_diag_max = as.numeric(rhs_diag$chol_diag_max %||% NA_real_),
        opt_calls = as.integer(rhs_diag$opt_calls %||% NA_integer_),
        opt_fallback = as.integer(rhs_diag$opt_fallback %||% NA_integer_),
        opt_grid = as.integer(rhs_diag$opt_grid %||% NA_integer_),
        opt_hit_bounds = as.integer(rhs_diag$opt_hit_bounds %||% NA_integer_),
        tau_eta_start = as.numeric(tau_up$eta0 %||% NA_real_),
        tau_eta_end = as.numeric(tau_up$mode %||% NA_real_),
        tau_obj_start = as.numeric(tau_up$obj0 %||% NA_real_),
        tau_obj_end = as.numeric(tau_up$obj_mode %||% NA_real_),
        tau_obj_improved = as.logical(tau_up$obj_improved %||% NA),
        tau_opt_method = as.character(tau_up$method %||% NA_character_),
        tau_opt_used_fallback = as.logical(tau_up$used_fallback %||% NA),
        tau_opt_hit_bounds = as.logical(tau_up$hit_bounds %||% NA),
        tau_opt_lo = as.numeric(tau_up$lo %||% NA_real_),
        tau_opt_hi = as.numeric(tau_up$hi %||% NA_real_),
        tau_opt_clipped = as.logical(tau_up$clipped %||% NA),
        tau_opt_n_iter = as.integer(tau_up$n_iter %||% NA_integer_),
        tau_opt_n_backtrack = as.integer(tau_up$n_backtrack %||% NA_integer_),
        tau_opt_n_step_halving = as.integer(tau_up$n_step_halving %||% NA_integer_),
        grad_tau_start = as.numeric(rhs_diag$grad_tau_start %||% NA_real_),
        grad_tau_end = as.numeric(rhs_diag$grad_tau_end %||% NA_real_),
        stringsAsFactors = FALSE
      )
      for (nm in names(n_prec_gt)) row[[nm]] <- n_prec_gt[[nm]]
      for (nm in names(n_beta_small)) row[[nm]] <- n_beta_small[[nm]]

      names_use <- if (!is.null(term_names) && length(term_names) >= max(idx)) term_names[idx] else NULL
      top_prec_idx <- top_k_idx(prec_use, rhs_trace_top_k)
      top_beta_idx <- top_k_idx(abs(beta_mean_use), rhs_trace_top_k)
      detail <- list(
        top_prec = list(
          idx = idx[top_prec_idx],
          name = if (!is.null(names_use)) names_use[top_prec_idx] else NULL,
          value = prec_use[top_prec_idx]
        ),
        top_abs_beta = list(
          idx = idx[top_beta_idx],
          name = if (!is.null(names_use)) names_use[top_beta_idx] else NULL,
          value = beta_mean_use[top_beta_idx]
        )
      )

      return(list(row = row, detail = detail))
    }

    eta_lam <- as.numeric(beta_state$eta_lambda_hat)
    eta_tau <- as.numeric(beta_state$eta_tau_hat)
    eta_c2  <- as.numeric(beta_state$eta_c_hat)
    shrink_intercept <- isTRUE(beta_state$shrink_intercept)

    idx <- if (shrink_intercept) seq_along(eta_lam) else if (length(eta_lam) >= 2L) 2L:length(eta_lam) else integer(0)
    if (!length(idx)) {
      return(list(row = data.frame(iter = iter), detail = list()))
    }

    beta_mean <- as.numeric(qbeta$m)
    beta_var  <- as.numeric(diag(qbeta$V))
    beta_mean_use <- beta_mean[idx]
    beta_var_use  <- beta_var[idx]
    beta2_use <- beta_mean_use^2 + beta_var_use

    loglam <- eta_lam[idx]
    lam <- exp_safe(loglam)

    u <- 2 * eta_tau + 2 * loglam
    a <- eta_c2
    logV <- a + u - logsumexp2(a, u)
    V <- exp_safe(logV)
    log_invV <- logsumexp2(-a, -u)
    invV <- exp_safe(log_invV)

    prec_use <- as.numeric(prec_diag[idx])

    n_prec_gt <- vapply(rhs_trace_thresholds, function(th) sum(prec_use > th, na.rm = TRUE), integer(1))
    names(n_prec_gt) <- paste0("n_prec_gt_", format(rhs_trace_thresholds, scientific = TRUE))

    n_beta_small <- vapply(rhs_trace_eps, function(eps) sum(abs(beta_mean_use) < eps, na.rm = TRUE), integer(1))
    names(n_beta_small) <- paste0("n_beta_abs_lt_", format(rhs_trace_eps, scientific = TRUE))

    term_logV <- -0.5 * sum(logV)
    term_quad <- -0.5 * sum(beta2_use * invV)
    term_lambda <- sum(loglam - log1p_exp(2 * loglam))
    logtau0 <- log(as.numeric(beta_prior_obj$hypers$tau0 %||% 1))
    term_tau <- eta_tau - log1p_exp(2 * (eta_tau - logtau0))
    nu <- as.numeric(beta_prior_obj$hypers$nu %||% 4)
    s_used <- as.numeric(beta_prior_obj$hypers$s %||% 1)
    term_c2 <- -(nu / 2) * eta_c2 - (nu * s_used^2) / (2 * exp_safe(eta_c2))
    obj_total <- term_logV + term_quad + term_lambda + term_tau + term_c2

    w <- exp_safe(u - logsumexp2(a, u))
    t <- exp_safe(-u)
    r <- exp_safe(-a)
    s_lam <- plogis(2 * loglam)
    grad_lam <- -(1 - w) + beta2_use * t + (1 - 2 * s_lam)
    s_tau <- plogis(2 * (eta_tau - logtau0))
    grad_tau <- -sum(1 - w) + sum(beta2_use * t) + (1 - 2 * s_tau)
    grad_c2 <- -0.5 * sum(w) + 0.5 * sum(beta2_use) * r +
      (-(nu / 2) + (nu * s_used^2) / 2 * r)
    grad_inf <- max(abs(c(grad_lam, grad_tau, grad_c2)))

    beta_l2 <- sqrt(sum(beta_mean_use^2))
    beta_absmax <- if (length(beta_mean_use)) max(abs(beta_mean_use)) else NA_real_

    rhs_diag <- beta_state$rhs_diag %||% list()
    tau_up <- rhs_diag$tau_update %||% list()

    D_rhs <- length(beta2_use)
    V_safe <- pmax(V, 1e-16)
    R_val <- sum(beta2_use / V_safe)
    R_over_D <- if (D_rhs > 0) R_val / D_rhs else NA_real_

    log_tau_clipped <- NA
    log_tau_clip_side <- NA_character_
    if (!is.null(log_tau_bounds) && length(log_tau_bounds) == 2L &&
        all(is.finite(log_tau_bounds))) {
      tol <- 1e-3
      if (eta_tau <= log_tau_bounds[1] + tol) {
        log_tau_clipped <- TRUE
        log_tau_clip_side <- "lo"
      } else if (eta_tau >= log_tau_bounds[2] - tol) {
        log_tau_clipped <- TRUE
        log_tau_clip_side <- "hi"
      } else {
        log_tau_clipped <- FALSE
      }
    }

    grad_tau_fd <- NA_real_
    grad_tau_fd_rel_err <- NA_real_
    if (isTRUE(gradcheck_on) && length(gradcheck_iters) && iter %in% gradcheck_iters) {
      h <- gradcheck_h
      f_tau_only <- function(etau) {
        u_fd <- 2 * etau + 2 * loglam
        ld_fd <- logsumexp2(a, u_fd)
        logV_fd <- a + u_fd - ld_fd
        log_invV_fd <- logsumexp2(-a, -u_fd)
        invV_fd <- exp_safe(log_invV_fd)
        term_logV_fd <- -0.5 * sum(logV_fd)
        term_quad_fd <- -0.5 * sum(beta2_use * invV_fd)
        term_tau_fd <- etau - log1p_exp(2 * (etau - logtau0))
        term_logV_fd + term_quad_fd + term_lambda + term_tau_fd + term_c2
      }
      fp <- f_tau_only(eta_tau + h)
      fm <- f_tau_only(eta_tau - h)
      grad_tau_fd <- (fp - fm) / (2 * h)
      if (is.finite(grad_tau) && abs(grad_tau) > 0) {
        grad_tau_fd_rel_err <- abs(grad_tau_fd - grad_tau) / abs(grad_tau)
      }
    }

    row <- data.frame(
      iter = iter,
      tau = exp_safe(eta_tau),
      log_tau = eta_tau,
      delta_log_tau = if (is.finite(prev_log_tau_scalar)) (eta_tau - prev_log_tau_scalar) else NA_real_,
      log_tau_clipped = log_tau_clipped,
      log_tau_clip_side = log_tau_clip_side,
      rhs_update_skipped = isTRUE(rhs_update_skipped),
      tau_update_allowed = as.logical(tau_update_allowed),
      tau_update_performed = as.logical(tau_update_performed),
      tau_update_reason = as.character(tau_update_reason %||% NA_character_),
      delta_L_local = as.numeric(delta_L_local),
      tau_warmup = as.logical(tau_warmup),
      u_tau = as.integer(u_tau),
      t_last_tau = as.integer(t_last_tau),
      tau_local_tol = as.numeric(tau_local_tol),
      tau0 = as.numeric(beta_prior_obj$hypers$tau0 %||% NA_real_),
      c2 = exp_safe(eta_c2),
      log_c2 = eta_c2,
      s = s_used,
      s2 = as.numeric(beta_prior_obj$hypers$s2 %||% NA_real_),
      s_source = as.character(beta_prior_obj$hypers$s_source %||% NA_character_),
      s_provided = as.numeric(beta_prior_obj$hypers$s_provided %||% NA_real_),
      s2_provided = as.numeric(beta_prior_obj$hypers$s2_provided %||% NA_real_),
      nu = nu,
      lambda_min = summ_stats(lam)[1],
      lambda_med = summ_stats(lam)[2],
      lambda_max = summ_stats(lam)[3],
      log_lambda_min = summ_stats(loglam)[1],
      log_lambda_med = summ_stats(loglam)[2],
      log_lambda_max = summ_stats(loglam)[3],
      V_min = summ_stats(V)[1],
      V_med = summ_stats(V)[2],
      V_max = summ_stats(V)[3],
      invV_min = summ_stats(invV)[1],
      invV_med = summ_stats(invV)[2],
      invV_max = summ_stats(invV)[3],
      E_invV_min = summ_stats(prec_use)[1],
      E_invV_med = summ_stats(prec_use)[2],
      E_invV_max = summ_stats(prec_use)[3],
      R = R_val,
      R_over_D = R_over_D,
      D_rhs = D_rhs,
      beta_l2 = beta_l2,
      beta_var_sum = sum(beta_var_use),
      beta_var_mean = mean(beta_var_use),
      beta2_sum = sum(beta2_use),
      beta2_mean = mean(beta2_use),
      beta_absmax = beta_absmax,
      term_logV = term_logV,
      term_quad = term_quad,
      term_lambda = term_lambda,
      term_tau = term_tau,
      term_c2 = term_c2,
      obj_total = obj_total,
      grad_tau = grad_tau,
      grad_tau_fd = as.numeric(grad_tau_fd),
      grad_tau_fd_rel_err = as.numeric(grad_tau_fd_rel_err),
      grad_inf = grad_inf,
      hess_jitter = as.numeric(rhs_diag$hess_jitter %||% NA_real_),
      chol_diag_min = as.numeric(rhs_diag$chol_diag_min %||% NA_real_),
      chol_diag_max = as.numeric(rhs_diag$chol_diag_max %||% NA_real_),
      opt_calls = as.integer(rhs_diag$opt_calls %||% NA_integer_),
      opt_fallback = as.integer(rhs_diag$opt_fallback %||% NA_integer_),
      opt_grid = as.integer(rhs_diag$opt_grid %||% NA_integer_),
      opt_hit_bounds = as.integer(rhs_diag$opt_hit_bounds %||% NA_integer_),
      tau_eta_start = as.numeric(tau_up$eta0 %||% NA_real_),
      tau_eta_end = as.numeric(tau_up$mode %||% NA_real_),
      tau_obj_start = as.numeric(tau_up$obj0 %||% NA_real_),
      tau_obj_end = as.numeric(tau_up$obj_mode %||% NA_real_),
      tau_obj_improved = as.logical(tau_up$obj_improved %||% NA),
      tau_opt_method = as.character(tau_up$method %||% NA_character_),
      tau_opt_used_fallback = as.logical(tau_up$used_fallback %||% NA),
      tau_opt_hit_bounds = as.logical(tau_up$hit_bounds %||% NA),
      tau_opt_lo = as.numeric(tau_up$lo %||% NA_real_),
      tau_opt_hi = as.numeric(tau_up$hi %||% NA_real_),
      tau_opt_clipped = as.logical(tau_up$clipped %||% NA),
      tau_opt_n_iter = as.integer(tau_up$n_iter %||% NA_integer_),
      tau_opt_n_backtrack = as.integer(tau_up$n_backtrack %||% NA_integer_),
      tau_opt_n_step_halving = as.integer(tau_up$n_step_halving %||% NA_integer_),
      grad_tau_start = as.numeric(rhs_diag$grad_tau_start %||% NA_real_),
      grad_tau_end = as.numeric(rhs_diag$grad_tau_end %||% NA_real_)
    )
    for (nm in names(n_prec_gt)) row[[nm]] <- n_prec_gt[[nm]]
    for (nm in names(n_beta_small)) row[[nm]] <- n_beta_small[[nm]]

    names_use <- if (!is.null(term_names) && length(term_names) >= max(idx)) term_names[idx] else NULL
    top_prec_idx <- top_k_idx(prec_use, rhs_trace_top_k)
    top_beta_idx <- top_k_idx(abs(beta_mean_use), rhs_trace_top_k)
    detail <- list(
      top_prec = list(
        idx = idx[top_prec_idx],
        name = if (!is.null(names_use)) names_use[top_prec_idx] else NULL,
        value = prec_use[top_prec_idx]
      ),
      top_abs_beta = list(
        idx = idx[top_beta_idx],
        name = if (!is.null(names_use)) names_use[top_beta_idx] else NULL,
        value = beta_mean_use[top_beta_idx]
      )
    )

    list(row = row, detail = detail)
  }

  rhs_trace_rows <- if (rhs_trace_on) vector("list", vb_control$max_iter) else NULL
  rhs_trace_detail <- if (rhs_trace_on) vector("list", vb_control$max_iter) else NULL
  rhs_profiles <- if (rhs_deep_on) list() else NULL
  rhs_profile_grid <- seq(-20, 8, by = 0.5)
  rhs_profile_targets <- c(1L, 5L)
  rhs_profile_pending <- integer(0)
  rhs_collapse_iter <- NA_integer_
  prev_log_tau <- NA_real_
  prev_snapshot <- NULL
  term_names <- colnames(X)

  sol_chol <- NULL
  update_qbeta <- function() {
    prec_diag <<- beta_prior_obj$expected_prec(beta_state, p)
    prec_diag <<- as.numeric(prec_diag)
    if (length(prec_diag) != p) .stopf("beta prior expected_prec must return length p=%d.", p)
    if (any(!is.finite(prec_diag)) || any(prec_diag <= 0)) .stopf("beta prior expected_prec must be finite and > 0.")

    nat <- .exal_beta_natural_stats(
      X = X,
      y = y,
      xis = xis,
      qv_m_inv = qv$m_inv,
      qs_m = qs$m,
      prec_diag = prec_diag
    )
    W <<- as.numeric(nat$barw)
    Prec <- as.matrix(nat$P)
    rhs <- as.numeric(nat$h)

    sol <- .solve_sympd(Prec, rhs)
    qbeta$V <<- sol$inv
    qbeta$m <<- as.numeric(sol$x)
    sol_chol <<- sol$chol %||% NULL
  }

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

  core_pos <- c("xi1", "xi_lambda2", "xi_A2")
  if (any(!is.finite(out[core_pos])) || any(out[core_pos] <= 0)) {
    damp_grid <- c(0.5, 0.25, 0.1, 0)
    repaired <- FALSE
    for (w in damp_grid) {
      cand <- f00 + w * corr
      if (all(is.finite(cand[core_pos])) && all(cand[core_pos] > 0)) {
        out <- cand
        repaired <- TRUE
        break
      }
    }
    if (!repaired) {
      out <- f00
    }
  }

  # exact sigma-only moments under ell ~ N(ell_hat, Sigma[2,2])
  out <- c(out,
           xi_siginv      = exp(-ell_hat + 0.5 * Sigma[2,2]),
           zeta_logsigma  = ell_hat)

  as.list(out)
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
  t_last_tau <- 0L
  u_tau <- 0L
  elbo_at_last_tau <- NA_real_

  t0 <- proc.time()[3]
  for (iter in seq_len(vb_control$max_iter)) {
    iter_run <- iter

    # ------------------------------------------------------------------------
    # (2.1) UPDATE q(beta) using Delta xis (matches static core, mean=0 prior)
    # ------------------------------------------------------------------------
    update_qbeta()

    # ------------------------------------------------------------------------
    # (2.2) UPDATE q(v): GIG(1/2, chi_i, psi)
    # ------------------------------------------------------------------------
    xb  <- as.numeric(X %*% qbeta$m)
    t_i <- y - xb
    q_i <- rowSums((X %*% qbeta$V) * X)

    qv_up <- .exal_local_qv_update(
      y = y,
      xb = xb,
      q_i = q_i,
      qs_m = qs$m,
      qs_m2 = qs$m2,
      xis = xis
    )
    chi <- as.numeric(qv_up$chi)
    psi <- as.numeric(qv_up$psi)
    qv$m <- as.numeric(qv_up$m)
    qv$m_inv <- as.numeric(qv_up$m_inv)
    z_gig <- as.numeric(qv_up$z)   # cache for ELBO (entropy normalizer)

    # ------------------------------------------------------------------------
    # (2.2) UPDATE q(s): TN(mu_s, tau2) on (0, inf)
    # ------------------------------------------------------------------------
    qs_up <- .exal_local_qs_update(
      y = y,
      xb = xb,
      qv_m_inv = qv$m_inv,
      xis = xis
    )
    tau2 <- as.numeric(qs_up$tau2)
    mu_s <- as.numeric(qs_up$mu)
    qs$m <- as.numeric(qs_up$m)
    qs$m2 <- as.numeric(qs_up$m2)

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

    # Optional: extra q(beta) refinement before RHS update (path-only)
    if (rhs_beta_presteps > 1L && iter <= rhs_beta_presteps_iters) {
      for (kk in seq_len(rhs_beta_presteps - 1L)) {
        update_qbeta()
      }
    }

    tau_warmup <- isTRUE(rhs_freeze_tau_warmup_iters > 0L && iter <= rhs_freeze_tau_warmup_iters)
    tau_local_tol_on <- is.finite(rhs_tau_local_tol)
    delta_L_local <- NA_real_
    tau_update_allowed <- FALSE
    tau_update_performed <- FALSE
    tau_update_reason <- NA_character_

    # ------------------------------------------------------------------------
    # beta-prior latent update (RHS etc) using NEW q(beta)
    # ------------------------------------------------------------------------
    update_every_eff <- rhs_update_every
    if (rhs_update_every_warmup_iters > 0L && iter <= rhs_update_every_warmup_iters) {
      update_every_eff <- rhs_update_every_warmup
    }
    do_rhs_update <- (update_every_eff <= 1L) || ((iter %% update_every_eff) == 0L)

    is_rhs <- identical(beta_prior_type, "rhs")
    do_prior_update <- if (is_rhs) isTRUE(do_rhs_update) else TRUE

    if (is_rhs && isTRUE(do_rhs_update)) {
      beta_state$freeze_tau <- isTRUE(tau_warmup || tau_local_tol_on)
      beta_state$update_tau_only <- FALSE
    }

    if (do_prior_update) {
      beta_state <- beta_prior_obj$update(beta_state, qbeta)
    }
    # RHS traces are collected after any tau gating below.

    # ------------------------------------------------------------------------
    # ELBO (per-observation), computed using CURRENT q factors and CURRENT xis
    # ------------------------------------------------------------------------
    compute_elbo_current <- function() {

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
    } else if (beta_prior_obj$type %in% c("rhs", "rhs_ns")) {
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
    if (!is.null(sol_chol)) {
      logdetPrec <- 2 * sum(log(diag(sol_chol)))
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
    as.numeric(elbo_new / n)
    }

    elbo_pre <- compute_elbo_current()
    elbo_new <- elbo_pre

    # --- tau update gating (local ELBO) ------------------------------------
    if (identical(beta_prior_obj$type, "rhs")) {
      if (!isTRUE(tau_local_tol_on)) {
        if (isTRUE(do_rhs_update) && !isTRUE(tau_warmup)) {
          tau_update_allowed <- TRUE
          tau_update_performed <- TRUE
          tau_update_reason <- "no_local_tol"
          u_tau <- u_tau + 1L
          t_last_tau <- iter
          elbo_at_last_tau <- elbo_new
        } else {
          tau_update_reason <- if (!isTRUE(do_rhs_update)) "rhs_update_skipped" else "warmup"
        }
      } else {
        if (!isTRUE(do_rhs_update)) {
          tau_update_reason <- "rhs_update_skipped"
        } else if (isTRUE(tau_warmup)) {
          tau_update_reason <- "warmup"
        } else {
          if (is.finite(elbo_at_last_tau)) {
            delta_L_local <- elbo_pre - elbo_at_last_tau
            if (is.finite(delta_L_local) && delta_L_local < rhs_tau_local_tol) {
              tau_update_allowed <- TRUE
              tau_update_reason <- "local_tol"
            } else {
              tau_update_reason <- "local_not_met"
            }
          } else {
            tau_update_reason <- "no_elbo_ref"
          }

          if (!isTRUE(tau_update_allowed) && isTRUE(rhs_force_tau_after_warmup) &&
              u_tau < rhs_min_tau_updates) {
            tau_update_allowed <- TRUE
            tau_update_reason <- "force_after_warmup"
          }

          if (!is.na(rhs_max_tau_updates) && u_tau >= rhs_max_tau_updates) {
            tau_update_allowed <- FALSE
            tau_update_reason <- "max_updates"
          }

          if (isTRUE(tau_update_allowed)) {
            beta_state$freeze_tau <- FALSE
            beta_state$update_tau_only <- TRUE
            beta_state <- beta_prior_obj$update(beta_state, qbeta)
            tau_update_performed <- TRUE
            u_tau <- u_tau + 1L
            t_last_tau <- iter
            if (isTRUE(rhs_recompute_elbo_after_tau_update)) {
              elbo_new <- compute_elbo_current()
            }
            elbo_at_last_tau <- elbo_new
          }
        }
      }
    }

    # --- RHS traces after final tau state ----------------------------------
    if (is_rhs_family) {
      if (is_rhs) {
        eta_lam <- as.numeric(beta_state$eta_lambda_hat)
        eta_tau <- as.numeric(beta_state$eta_tau_hat)
        eta_c2  <- as.numeric(beta_state$eta_c_hat)

        tau_hat <- exp_safe(eta_tau)
        c2_hat  <- exp_safe(eta_c2)

        if (!isTRUE(beta_state$shrink_intercept)) {
          eta_lam_use <- if (length(eta_lam) >= 2L) eta_lam[-1L] else numeric(0)
        } else {
          eta_lam_use <- eta_lam
        }
        lam_hat <- exp_safe(eta_lam_use)
      } else {
        p_state <- as.integer(beta_state$p %||% length(qbeta$m))
        if (!is.finite(p_state) || p_state <= 0L) p_state <- as.integer(length(qbeta$m))
        idx <- if (isTRUE(beta_state$shrink_intercept)) seq_len(p_state) else if (p_state >= 2L) 2L:p_state else integer(0)
        tau2 <- as.numeric(beta_state$tau2 %||% NA_real_)[1L]
        if (!is.finite(tau2) || tau2 <= 0) {
          e_inv_tau <- as.numeric(beta_state$E_inv_tau2 %||% NA_real_)[1L]
          if (is.finite(e_inv_tau) && e_inv_tau > 0) tau2 <- 1 / e_inv_tau
        }
        tau_hat <- sqrt(pmax(as.numeric(tau2), 1e-24))
        c2_hat <- as.numeric(beta_state$zeta2 %||% NA_real_)[1L]
        if (!is.finite(c2_hat) || c2_hat <= 0) {
          e_inv_zeta <- as.numeric(beta_state$E_inv_zeta2 %||% NA_real_)[1L]
          if (is.finite(e_inv_zeta) && e_inv_zeta > 0) c2_hat <- 1 / e_inv_zeta
        }
        if (!is.finite(c2_hat) || c2_hat <= 0) c2_hat <- as.numeric(beta_prior_obj$hypers$s2 %||% 1.0)[1L]
        c2_hat <- pmax(c2_hat, 1e-24)

        lambda2 <- as.numeric(beta_state$lambda2 %||% rep(NA_real_, p_state))
        if (length(lambda2) == 1L && p_state > 1L) lambda2 <- rep(lambda2, p_state)
        if (length(lambda2) != p_state) lambda2 <- rep(NA_real_, p_state)
        lam_hat <- sqrt(pmax(lambda2, 1e-24))
        bad_lam <- !is.finite(lam_hat) | lam_hat <= 0
        if (any(bad_lam)) {
          e_inv_lambda <- as.numeric(beta_state$E_inv_lambda2 %||% rep(NA_real_, p_state))
          if (length(e_inv_lambda) == 1L && p_state > 1L) e_inv_lambda <- rep(e_inv_lambda, p_state)
          if (length(e_inv_lambda) == p_state) {
            lam_hat[bad_lam] <- sqrt(1 / pmax(e_inv_lambda[bad_lam], 1e-24))
          }
        }
        if (length(idx)) {
          lam_hat <- as.numeric(lam_hat[idx])
        } else {
          lam_hat <- numeric(0)
        }
        lam_hat <- lam_hat[is.finite(lam_hat) & lam_hat > 0]
      }

      rhs_tau_trace <- c(rhs_tau_trace, tau_hat)
      rhs_c2_trace  <- c(rhs_c2_trace, c2_hat)

      if (length(lam_hat)) {
        rhs_lambda_mean_trace <- c(rhs_lambda_mean_trace, mean(lam_hat))
        rhs_lambda_min_trace  <- c(rhs_lambda_min_trace, min(lam_hat))
        rhs_lambda_max_trace  <- c(rhs_lambda_max_trace, max(lam_hat))
      } else {
        rhs_lambda_mean_trace <- c(rhs_lambda_mean_trace, NA_real_)
        rhs_lambda_min_trace  <- c(rhs_lambda_min_trace, NA_real_)
        rhs_lambda_max_trace  <- c(rhs_lambda_max_trace, NA_real_)
      }

      if (rhs_trace_on) {
        prec_diag_now <- as.numeric(beta_prior_obj$expected_prec(beta_state, p))
        tau_bounds <- beta_prior_obj$control$eta_bounds$tau %||% NULL
        diag_out <- rhs_diag_collect(iter, beta_state, qbeta, prec_diag_now,
                                     term_names = term_names,
                                     prev_log_tau = prev_log_tau,
                                     log_tau_bounds = tau_bounds,
                                     rhs_update_skipped = !do_rhs_update,
                                     tau_update_allowed = tau_update_allowed,
                                     tau_update_performed = tau_update_performed,
                                     tau_update_reason = tau_update_reason,
                                     delta_L_local = delta_L_local,
                                     tau_warmup = tau_warmup,
                                     u_tau = u_tau,
                                     t_last_tau = t_last_tau,
                                     tau_local_tol = rhs_tau_local_tol,
                                     gradcheck_on = rhs_gradcheck_on,
                                     gradcheck_iters = rhs_gradcheck_iters,
                                     gradcheck_h = rhs_gradcheck_h)
        rhs_trace_rows[[iter]] <- diag_out$row
        rhs_trace_detail[[iter]] <- diag_out$detail
        if (identical(beta_prior_obj$type, "rhs")) {
          prev_log_tau <- as.numeric(beta_state$eta_tau_hat)[1L]
        } else if (identical(beta_prior_obj$type, "rhs_ns")) {
          tau2_now <- as.numeric(beta_state$tau2 %||% NA_real_)[1L]
          if (!is.finite(tau2_now) || tau2_now <= 0) {
            e_inv_tau_now <- as.numeric(beta_state$E_inv_tau2 %||% NA_real_)[1L]
            if (is.finite(e_inv_tau_now) && e_inv_tau_now > 0) tau2_now <- 1 / e_inv_tau_now
          }
          prev_log_tau <- if (is.finite(tau2_now) && tau2_now > 0) (0.5 * log(tau2_now)) else NA_real_
        } else {
          prev_log_tau <- NA_real_
        }
      }

      if (rhs_deep_on) {
        tau_bounds <- beta_prior_obj$control$eta_bounds$tau %||% NULL
        eta_tau_now <- as.numeric(beta_state$eta_tau_hat)
        clipped_now <- FALSE
        if (!is.null(tau_bounds) && length(tau_bounds) == 2L &&
            all(is.finite(tau_bounds))) {
          tol <- 1e-3
          clipped_now <- (eta_tau_now <= tau_bounds[1] + tol) || (eta_tau_now >= tau_bounds[2] - tol)
        }

        snap_now <- rhs_make_snapshot(beta_state, qbeta, beta_prior_obj)
        snap_now$iter <- iter

        if (iter %in% rhs_profile_targets || iter %in% rhs_profile_pending) {
          if (is.null(rhs_profiles[[as.character(iter)]])) {
            prof <- rhs_profile_logtau_snapshot(snap_now, rhs_profile_grid)
            prof$iter <- iter
            rhs_profiles[[as.character(iter)]] <- prof
          }
          rhs_profile_pending <- setdiff(rhs_profile_pending, iter)
        }

        if (is.na(rhs_collapse_iter) && isTRUE(clipped_now)) {
          rhs_collapse_iter <- iter
          if (!is.null(prev_snapshot) && identical(prev_snapshot$iter, iter - 1L)) {
            if (is.null(rhs_profiles[[as.character(iter - 1L)]])) {
              prof <- rhs_profile_logtau_snapshot(prev_snapshot, rhs_profile_grid)
              prof$iter <- iter - 1L
              rhs_profiles[[as.character(iter - 1L)]] <- prof
            }
          }
          if (is.null(rhs_profiles[[as.character(iter)]])) {
            prof <- rhs_profile_logtau_snapshot(snap_now, rhs_profile_grid)
            prof$iter <- iter
            rhs_profiles[[as.character(iter)]] <- prof
          }
          rhs_profile_pending <- unique(c(rhs_profile_pending, iter + 1L))
        }

        prev_snapshot <- snap_now
      }
    }

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

    min_tau_ok <- TRUE
    if (identical(beta_prior_obj$type, "rhs") && rhs_min_tau_updates > 0L) {
      min_tau_ok <- (u_tau >= rhs_min_tau_updates)
    }

    if (iter >= min_iter_elbo &&
        is.finite(rel_elbo) &&
        abs(rel_elbo) < vb_control$tol &&
        is.finite(new_term) &&
        new_term < vb_control$tol_par &&
        isTRUE(min_tau_ok)) {
      converged <- TRUE
      break
    }

    gamma_old <- gamma_hat
    sigma_old <- sigma_hat

    if (isTRUE(vb_control$verbose) && (iter %% 25L == 0L)) {
      if (identical(beta_prior_obj$type, "rhs")) {
        eta_tau_now <- as.numeric(beta_state$eta_tau_hat %||% NA_real_)
        tau_now <- exp_safe(eta_tau_now)
        tau_bounds_now <- beta_prior_obj$control$eta_bounds$tau %||% c(NA_real_, NA_real_)
        tau_lo <- if (length(tau_bounds_now) >= 1L) as.numeric(tau_bounds_now[1L]) else NA_real_
        tau_hi <- if (length(tau_bounds_now) >= 2L) as.numeric(tau_bounds_now[2L]) else NA_real_
        near_lo <- isTRUE(is.finite(eta_tau_now) && is.finite(tau_lo) && abs(eta_tau_now - tau_lo) < 1e-3)
        near_hi <- isTRUE(is.finite(eta_tau_now) && is.finite(tau_hi) && abs(eta_tau_now - tau_hi) < 1e-3)

        e_invv_med <- NA_real_
        beta_l2_now <- NA_real_
        r_over_d <- NA_real_
        beta_small_frac_1e4 <- NA_real_
        tau_reason <- NA_character_
        tau_performed <- NA
        u_tau_now <- NA_integer_
        if (isTRUE(rhs_trace_on) && !is.null(rhs_trace_rows[[iter]])) {
          row_now <- rhs_trace_rows[[iter]]
          e_invv_med <- as.numeric(row_now$E_invV_med %||% NA_real_)
          beta_l2_now <- as.numeric(row_now$beta_l2 %||% NA_real_)
          r_over_d <- as.numeric(row_now$R_over_D %||% NA_real_)
          d_rhs_now <- as.numeric(row_now$D_rhs %||% NA_real_)
          n_small_1e4 <- as.numeric(row_now[["n_beta_abs_lt_1e-04"]] %||% NA_real_)
          if (is.finite(d_rhs_now) && d_rhs_now > 0 && is.finite(n_small_1e4)) {
            beta_small_frac_1e4 <- n_small_1e4 / d_rhs_now
          }
          tau_reason <- as.character(row_now$tau_update_reason %||% NA_character_)
          tau_performed <- as.logical(row_now$tau_update_performed %||% NA)
          u_tau_now <- as.integer(row_now$u_tau %||% NA_integer_)
        }

        collapse_proxy_bound <- isTRUE(near_lo) &&
          isTRUE(is.finite(e_invv_med) && e_invv_med > 1e8) &&
          isTRUE(is.finite(beta_l2_now) && beta_l2_now < 1e-3)
        collapse_proxy_shrink <- isTRUE(is.finite(e_invv_med) && e_invv_med > 1e6) &&
          isTRUE(is.finite(beta_l2_now) && beta_l2_now < 1e-2) &&
          isTRUE(is.finite(beta_small_frac_1e4) && beta_small_frac_1e4 > 0.95)
        collapse_proxy <- isTRUE(collapse_proxy_bound) || isTRUE(collapse_proxy_shrink)

        cat(sprintf(
          "iter %4d | gamma≈%.4f sigma≈%.4f | new_term=%.3e | RHS_MONITOR tau=%.3e log_tau=%.3f bounds=[%.3f,%.3f] near_lo=%s near_hi=%s E_invV_med=%.3e beta_l2=%.3e beta_small_frac_1e4=%.3f R_over_D=%.3f tau_update=%s/%s u_tau=%s collapse_flag_bound=%s collapse_flag_shrink=%s collapse_flag=%s\n",
          iter, gamma_hat, sigma_hat, new_term,
          tau_now, eta_tau_now, tau_lo, tau_hi,
          if (near_lo) "TRUE" else "FALSE",
          if (near_hi) "TRUE" else "FALSE",
          e_invv_med, beta_l2_now, beta_small_frac_1e4, r_over_d,
          ifelse(is.na(tau_performed), "NA", ifelse(isTRUE(tau_performed), "YES", "NO")),
          ifelse(is.na(tau_reason) || !nzchar(tau_reason), "NA", tau_reason),
          ifelse(is.na(u_tau_now), "NA", as.character(u_tau_now)),
          if (collapse_proxy_bound) "TRUE" else "FALSE",
          if (collapse_proxy_shrink) "TRUE" else "FALSE",
          if (collapse_proxy) "TRUE" else "FALSE"
        ))
      } else {
        cat(sprintf("iter %4d | gamma≈%.4f sigma≈%.4f | new_term=%.3e\n",
                    iter, gamma_hat, sigma_hat, new_term))
      }
    }
  }

  # Attach useful last-iteration objects for downstream steps
  new_term_trace <- as.numeric(new_term_trace)
  gamma_trace    <- as.numeric(gamma_trace)
  sigma_trace    <- as.numeric(sigma_trace)
  
  misc_elbo <- elbo_trace

  rhs_trace_df <- NULL
  rhs_trace_detail_out <- NULL
  rhs_trace_settings <- NULL
  rhs_profiles_out <- NULL
  if (rhs_trace_on && length(rhs_trace_rows)) {
    rhs_trace_rows <- rhs_trace_rows[seq_len(iter_run)]
    rhs_trace_df <- do.call(rbind, rhs_trace_rows)
    rhs_trace_detail_out <- rhs_trace_detail[seq_len(iter_run)]
    rhs_trace_settings <- list(
      thresholds = rhs_trace_thresholds,
      eps = rhs_trace_eps,
      top_k = rhs_trace_top_k,
      s_source = beta_prior_obj$hypers$s_source %||% NA_character_,
      s_provided = beta_prior_obj$hypers$s_provided %||% NA_real_,
      s2_provided = beta_prior_obj$hypers$s2_provided %||% NA_real_,
      rhs_freeze_tau_warmup_iters = rhs_freeze_tau_warmup_iters,
      rhs_update_every = rhs_update_every,
      rhs_update_every_warmup = rhs_update_every_warmup,
      rhs_update_every_warmup_iters = rhs_update_every_warmup_iters,
      rhs_beta_presteps = rhs_beta_presteps,
      rhs_beta_presteps_iters = rhs_beta_presteps_iters,
      rhs_gradcheck = rhs_gradcheck_on,
      rhs_gradcheck_iters = rhs_gradcheck_iters,
      rhs_gradcheck_h = rhs_gradcheck_h,
      rhs_tau_local_tol = rhs_tau_local_tol,
      rhs_min_tau_updates = rhs_min_tau_updates,
      rhs_max_tau_updates = rhs_max_tau_updates,
      rhs_force_tau_after_warmup = rhs_force_tau_after_warmup,
      rhs_recompute_elbo_after_tau_update = rhs_recompute_elbo_after_tau_update
    )
  }
  if (rhs_deep_on && length(rhs_profiles)) {
    rhs_profiles_out <- rhs_profiles
  }

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
      elbo = elbo_trace, elbo_trace = elbo_trace,
      rhs_tau_trace = rhs_tau_trace,
      rhs_c2_trace = rhs_c2_trace,
      rhs_lambda_mean_trace = rhs_lambda_mean_trace,
      rhs_lambda_min_trace = rhs_lambda_min_trace,
      rhs_lambda_max_trace = rhs_lambda_max_trace,
      rhs_trace = rhs_trace_df,
      rhs_trace_detail = rhs_trace_detail_out,
      rhs_trace_settings = rhs_trace_settings,
      rhs_logtau_profiles = rhs_profiles_out,
      rhs_logtau_grid = rhs_profile_grid,
      rhs_collapse_iter = rhs_collapse_iter
    )
  ), class = "exal_vb")



}
