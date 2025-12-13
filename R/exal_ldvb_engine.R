#' Internal LDVB engine (skeleton; returns exal_vb-compatible object)
exal_ldvb_engine <- function(y, X, p0, gamma_bounds,
                             vb_control, init,
                             prior_gamma, prior_sigma,
                             beta_prior_obj) {

  assert_matrix(X, "X")
    # local null-coalescing (avoid relying on global %||%)
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

  clamp01 <- function(u, eps = 1e-10) pmin(pmax(u, eps), 1 - eps)

  # --- initialize q(beta) ---
  qbeta <- list(
    m = rep(0, p),
    V = diag(1, p)
  )

  # --- initialize q(sig, gam) in unconstrained space (eta, ell) ---
  gamma0 <- init$gamma %||% prior_gamma$mu0 %||% 0
  sigma0 <- init$sigma %||% 1

  u0 <- clamp01((gamma0 - L) / (U - L))
  eta_hat <- qlogis(u0)
  ell_hat <- log(sigma0)

  qsiggam <- list(
    eta_hat = as.numeric(eta_hat),
    ell_hat = as.numeric(ell_hat),
    Sigma   = diag(c(1e-2, 1e-2), 2L)
  )

  # --- beta prior latent state (ridge or rhs) ---
  beta_state <- beta_prior_obj$init(p)

  elbo_trace     <- numeric(0)
  gamma_trace    <- numeric(0)
  sigma_trace    <- numeric(0)
  new_term_trace <- numeric(0)
  converged <- FALSE

  # helper: current E[gamma], E[sigma] from (eta_hat, ell_hat)
  cur_gamma <- function() L + (U - L) * plogis(qsiggam$eta_hat)
  cur_sigma <- function() exp(qsiggam$ell_hat)

  iter_run <- 0L
  for (iter in seq_len(vb_control$max_iter)) {
    iter_run <- iter
    # 1) expected likelihood weights / sufficient stats
    # TODO (algebra later)

    # 2) update q(beta)
    prec_diag <- beta_prior_obj$expected_prec(beta_state, p)
    if (length(prec_diag) != p) .stopf("beta prior expected_prec must return length p=%d.", p)

    # TODO (algebra later): update qbeta$m and qbeta$V using prec_diag + exAL stats

    # 3) update q(sigma,gamma) (eta_hat, ell_hat)
    # TODO (algebra later)

    # 4) update beta prior latents (RHS etc)
    beta_state <- beta_prior_obj$update(beta_state, qbeta)

    # 5) ELBO (placeholder until algebra is wired)
    # NOTE: keep as NA for now; your stopping rule can use tol_par in the meantime.
    elbo <- NA_real_

    elbo_trace  <- c(elbo_trace, elbo)
    gamma_trace <- c(gamma_trace, cur_gamma())
    sigma_trace <- c(sigma_trace, cur_sigma())

    if (iter >= 2L) {
      new_term <- abs(gamma_trace[iter] - gamma_trace[iter - 1L]) +
                  abs(sigma_trace[iter] - sigma_trace[iter - 1L])
      new_term_trace <- c(new_term_trace, new_term)
    } else {
      new_term_trace <- c(new_term_trace, NA_real_)
    }

    # 6) stopping rule (parameter-change safeguard until ELBO is wired)
    if (iter >= 2L && is.finite(new_term_trace[iter]) && new_term_trace[iter] < vb_control$tol_par) {
      converged <- TRUE
      break
    }
  }

  structure(list(
    qbeta   = qbeta,
    qsiggam = qsiggam,
    beta_prior = list(type = beta_prior_obj$type, hypers = beta_prior_obj$hypers, state = beta_state),
    misc = list(
      p0 = p0,
      bounds = c(L = L, U = U),
      elbo = elbo_trace,
      gamma_trace = gamma_trace,
      sigma_trace = sigma_trace,
      new_term_trace = new_term_trace,
      converged = converged,
      iter_run = iter_run
    )
  ), class = "exal_vb")
}
