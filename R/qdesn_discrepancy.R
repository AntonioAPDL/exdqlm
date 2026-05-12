#' Fit a source-indexed Q-DESN discrepancy readout
#'
#' This fitter is the package-side engine for applications that stack a
#' reference stream and a forecast-system stream on a fixed Q-DESN design. The
#' implemented kernels are asymmetric-Laplace MCMC and asymmetric-Laplace
#' mean-field VB with source-specific scales and a shared augmented readout.
#' exAL discrepancy kernels remain gated until the source-specific
#' scale--asymmetry blocks are implemented and validated.
#'
#' @param z Numeric stacked response vector.
#' @param H Numeric augmented design matrix. For the GloFAS application, rows
#'   have the form `[X, 0]` for the reference source and `[X, X]` for the
#'   forecast-system source.
#' @param source Source labels for rows of `z` and `H`.
#' @param p0 Target quantile level in `(0, 1)`.
#' @param method `"mcmc"` or `"vb"`.
#' @param likelihood_family Currently `"al"` for discrepancy fits.
#' @param beta_prior_type Coefficient prior. The default is `"rhs_ns"`.
#' @param source_levels Character vector giving source order.
#' @param intercept_index Coefficient indices that receive weak Gaussian
#'   intercept priors under RHS-family shrinkage.
#' @param vb_args,mcmc_args,control Named control lists. The VB route is an
#'   asymmetric-Laplace mean-field approximation and returns approximate
#'   posterior draws compatible with the MCMC prediction contract.
#'
#' @return A `qdesn_discrepancy_fit` object.
#' @export
qdesn_fit_discrepancy <- function(
  z,
  H,
  source,
  p0,
  method = c("mcmc", "vb"),
  likelihood_family = c("al", "exal"),
  beta_prior_type = "rhs_ns",
  source_levels = c("Y", "G"),
  intercept_index = integer(),
  vb_args = list(),
  mcmc_args = list(),
  control = list()
) {
  method <- match.arg(method)
  likelihood_family <- match.arg(likelihood_family)
  if (!identical(likelihood_family, "al")) {
    .stopf("qdesn_fit_discrepancy currently implements likelihood_family = 'al' only.")
  }

  if (identical(method, "mcmc")) {
    return(qdesn_fit_discrepancy_mcmc(
      z = z,
      H = H,
      source = source,
      p0 = p0,
      likelihood_family = likelihood_family,
      beta_prior_type = beta_prior_type,
      source_levels = source_levels,
      intercept_index = intercept_index,
      mcmc_args = mcmc_args,
      control = control
    ))
  }

  qdesn_fit_discrepancy_vb(
    z = z,
    H = H,
    source = source,
    p0 = p0,
    likelihood_family = likelihood_family,
    beta_prior_type = beta_prior_type,
    source_levels = source_levels,
    intercept_index = intercept_index,
    vb_args = vb_args,
    control = control
  )
}

#' Report implemented Q-DESN discrepancy kernels
#'
#' The article workflow uses this capability table to fail closed before
#' launching unsupported discrepancy fits.
#'
#' @return A data frame with one row per method and likelihood-family pair.
#' @export
qdesn_discrepancy_capabilities <- function() {
  data.frame(
    method = c("mcmc", "vb", "mcmc", "vb"),
    likelihood_family = c("al", "al", "exal", "exal"),
    fit_supported = c(TRUE, TRUE, FALSE, FALSE),
    support_status = c(
      "implemented",
      "implemented",
      "not_yet_implemented",
      "not_yet_implemented"
    ),
    notes = c(
      "AL discrepancy fit with source-specific scales and posterior simulation.",
      "AL discrepancy fit with source-specific scales, mean-field VB, and approximate posterior draws.",
      "exAL discrepancy MCMC requires source-specific scale-asymmetry block updates.",
      "exAL discrepancy VB-LD requires source-specific scale-asymmetry block approximations."
    ),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
.qdesn_discrepancy_validate_inputs <- function(
  z,
  H,
  source,
  p0,
  source_levels = c("Y", "G")
) {
  z <- as.numeric(z)
  H <- as.matrix(H)
  storage.mode(H) <- "double"
  if (!length(z) || any(!is.finite(z))) .stopf("z must be a finite numeric vector.")
  if (nrow(H) != length(z) || !ncol(H) || any(!is.finite(H))) {
    .stopf("H must be a finite numeric matrix with one row per element of z.")
  }
  if (!is.finite(p0) || length(p0) != 1L || p0 <= 0 || p0 >= 1) {
    .stopf("p0 must be a scalar in (0, 1).")
  }
  source_levels <- as.character(source_levels)
  if (!length(source_levels) || any(!nzchar(source_levels))) {
    .stopf("source_levels must contain non-empty source labels.")
  }
  source <- factor(as.character(source), levels = source_levels)
  if (length(source) != length(z) || anyNA(source)) {
    .stopf("source must have one valid source label per row.")
  }
  list(
    z = z,
    H = H,
    source = source,
    source_levels = source_levels,
    src_id = as.integer(source),
    idx_by_source = split(seq_along(z), as.integer(source))
  )
}

#' @keywords internal
.qdesn_discrepancy_prior_sigma <- function(prior_sigma, C, default_a = 1, default_b = 1) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  a <- as.numeric(prior_sigma$a %||% default_a)
  b <- as.numeric(prior_sigma$b %||% default_b)
  if (length(a) == 1L) a <- rep(a, C)
  if (length(b) == 1L) b <- rep(b, C)
  if (length(a) != C || length(b) != C) {
    .stopf("prior_sigma$a and prior_sigma$b must be scalars or have one entry per source level.")
  }
  if (any(!is.finite(a)) || any(a <= 0) || any(!is.finite(b)) || any(b <= 0)) {
    .stopf("prior_sigma must define positive finite a and b values.")
  }
  list(a = a, b = b)
}

#' @keywords internal
.qdesn_discrepancy_beta_prior <- function(args, beta_prior_type, intercept_index, context) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  get_exact <- function(x, name, default = NULL) {
    if (!is.list(x)) return(default)
    out <- x[[name, exact = TRUE]]
    if (is.null(out)) default else out
  }
  beta_prior_obj <- get_exact(args, "beta_prior_obj", NULL)
  beta_prior_type <- tolower(as.character(beta_prior_type %||% get_exact(args, "beta_prior_type", "rhs_ns"))[1L])
  if (identical(beta_prior_type, "rhs")) beta_prior_type <- "rhs_ns"
  if (is.null(beta_prior_obj)) {
    rhs_list <- modifyList(get_exact(args, "rhs", list()), get_exact(args, "beta_rhs", list()))
    if (beta_prior_type %in% c("rhs_ns")) {
      rhs_list <- .qdesn_enforce_rhs_controls(rhs_list, context = context)
      rhs_list$intercept_index <- intercept_index
    }
    beta_prior_obj <- exal_make_beta_prior(
      type = beta_prior_type,
      tau2 = get_exact(args, "beta_ridge_tau2", get_exact(args, "tau2", 1e4)),
      rhs = rhs_list
    )
  }
  if (!identical(beta_prior_obj$type, "rhs_ns") && !identical(beta_prior_obj$type, "ridge")) {
    .stopf("qdesn_fit_discrepancy currently supports beta_prior_type in {'rhs_ns','ridge'}.")
  }
  beta_prior_obj
}

#' @keywords internal
.qdesn_discrepancy_quad_diag <- function(H, V, block_size = 512L) {
  n <- nrow(H)
  out <- numeric(n)
  block_size <- max(1L, as.integer(block_size)[1L])
  starts <- seq.int(1L, n, by = block_size)
  for (start in starts) {
    idx <- start:min(n, start + block_size - 1L)
    HV <- H[idx, , drop = FALSE] %*% V
    out[idx] <- rowSums(HV * H[idx, , drop = FALSE])
  }
  pmax(out, 0)
}

#' @keywords internal
.qdesn_discrepancy_chol_psd <- function(V) {
  V <- 0.5 * (V + t(V))
  U <- tryCatch(chol(V), error = function(e) NULL)
  if (!is.null(U)) return(U)
  eg <- eigen(V, symmetric = TRUE)
  vals <- pmax(eg$values, 0)
  eg$vectors %*% diag(sqrt(vals), nrow(V)) %*% t(eg$vectors)
}

#' @keywords internal
.qdesn_discrepancy_mvrnorm <- function(n, mean, V) {
  mean <- as.numeric(mean)
  p <- length(mean)
  U <- .qdesn_discrepancy_chol_psd(V)
  Z <- matrix(stats::rnorm(n * p), n, p)
  sweep(Z %*% U, 2L, mean, "+")
}

#' @keywords internal
.qdesn_discrepancy_ig_entropy <- function(shape, scale) {
  shape <- pmax(as.numeric(shape), 1e-12)
  scale <- pmax(as.numeric(scale), 1e-12)
  shape + log(scale) + lgamma(shape) - (1 + shape) * digamma(shape)
}

#' @keywords internal
.qdesn_discrepancy_gig_half_elog <- function(chi, psi, eps = 1e-12) {
  chi <- pmax(as.numeric(chi), eps)
  psi <- pmax(as.numeric(psi), eps)
  z <- pmax(sqrt(chi * psi), eps)
  0.5 * log(chi / psi) + .dlog_besselK_dnu(z, nu = 0.5)
}

#' @keywords internal
.qdesn_discrepancy_gig_half_entropy <- function(chi, psi, Ev, Einvv, Elogv, eps = 1e-12) {
  chi <- pmax(as.numeric(chi), eps)
  psi <- pmax(as.numeric(psi), eps)
  z <- pmax(sqrt(chi * psi), eps)
  lambda <- 0.5
  elogq <- lambda / 2 * log(psi / chi) -
    log(2) - .log_besselK(z, nu = lambda) +
    (lambda - 1) * Elogv -
    0.5 * (chi * Einvv + psi * Ev)
  -sum(elogq)
}

#' @keywords internal
.qdesn_discrepancy_vb_elbo <- function(
  z,
  H,
  src_id,
  A,
  B,
  qbeta,
  beta_prior_obj,
  beta_state,
  beta_prec_diag,
  qv,
  qsigma,
  prior_sigma
) {
  eta <- z - drop(H %*% qbeta$m)
  resid2 <- eta * eta + .qdesn_discrepancy_quad_diag(H, qbeta$V)
  E_inv_sigma <- qsigma$E_inv_sigma[src_id]
  E_log_sigma <- qsigma$E_log_sigma[src_id]
  Elogv <- .qdesn_discrepancy_gig_half_elog(qv$chi, qv$psi)
  resid_term <- resid2 * qv$E_inv_v - 2 * A * eta + A * A * qv$E_v

  E_log_yv <- sum(
    -0.5 * log(2 * pi * B) -
      1.5 * E_log_sigma -
      0.5 * Elogv -
      0.5 * E_inv_sigma * resid_term / B -
      E_inv_sigma * qv$E_v
  )

  beta2 <- as.numeric(qbeta$m)^2 + diag(qbeta$V)
  if (identical(beta_prior_obj$type, "ridge")) {
    prior_beta <- sum(
      0.5 * (log(beta_prec_diag) - log(2 * pi)) -
        0.5 * beta_prec_diag * beta2
    )
  } else {
    prior_beta <- as.numeric(beta_prior_obj$elbo(beta_state, qbeta)$elbo)
  }
  logdetV <- tryCatch(
    as.numeric(determinant(qbeta$V, logarithm = TRUE)$modulus),
    error = function(e) NA_real_
  )
  if (!is.finite(logdetV)) logdetV <- 0
  H_beta <- 0.5 * (length(qbeta$m) * (1 + log(2 * pi)) + logdetV)

  E_log_sigma_prior <- sum(
    prior_sigma$a * log(prior_sigma$b) - lgamma(prior_sigma$a) -
      (prior_sigma$a + 1) * qsigma$E_log_sigma -
      prior_sigma$b * qsigma$E_inv_sigma
  )
  H_sigma <- sum(.qdesn_discrepancy_ig_entropy(qsigma$shape, qsigma$scale))
  H_v <- .qdesn_discrepancy_gig_half_entropy(
    chi = qv$chi,
    psi = qv$psi,
    Ev = qv$E_v,
    Einvv = qv$E_inv_v,
    Elogv = Elogv
  )

  as.numeric(E_log_yv + prior_beta + H_beta + E_log_sigma_prior + H_sigma + H_v)
}

#' @keywords internal
qdesn_fit_discrepancy_vb <- function(
  z,
  H,
  source,
  p0,
  likelihood_family = "al",
  beta_prior_type = "rhs_ns",
  source_levels = c("Y", "G"),
  intercept_index = integer(),
  vb_args = list(),
  control = list()
) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  get_exact <- function(x, name, default = NULL) {
    if (!is.list(x)) return(default)
    out <- x[[name, exact = TRUE]]
    if (is.null(out)) default else out
  }

  likelihood_family <- match.arg(likelihood_family, c("al", "exal"))
  if (!identical(likelihood_family, "al")) {
    .stopf("qdesn_fit_discrepancy_vb currently implements AL only.")
  }

  dat <- .qdesn_discrepancy_validate_inputs(z, H, source, p0, source_levels)
  z <- dat$z
  H <- dat$H
  source <- dat$source
  source_levels <- dat$source_levels
  src_id <- dat$src_id
  idx_by_source <- dat$idx_by_source

  vb_args <- modifyList(control %||% list(), vb_args %||% list())
  max_iter <- as.integer(get_exact(vb_args, "max_iter", 1000L))[1L]
  min_iter <- as.integer(get_exact(vb_args, "min_iter_elbo", get_exact(vb_args, "min_iter", 10L)))[1L]
  tol <- as.numeric(get_exact(vb_args, "tol", 1e-4))[1L]
  tol_par <- as.numeric(get_exact(vb_args, "tol_par", tol))[1L]
  n_draws <- as.integer(get_exact(vb_args, "n_draws", 1000L))[1L]
  seed <- get_exact(vb_args, "seed", NULL)
  if (!is.finite(max_iter) || max_iter < 1L) .stopf("vb_args$max_iter must be positive.")
  if (!is.finite(min_iter) || min_iter < 1L) min_iter <- 1L
  if (!is.finite(tol) || tol <= 0) tol <- 1e-4
  if (!is.finite(tol_par) || tol_par <= 0) tol_par <- tol
  if (!is.finite(n_draws) || n_draws < 1L) .stopf("vb_args$n_draws must be positive.")
  time_start <- proc.time()[["elapsed"]]

  beta_prior_obj <- .qdesn_discrepancy_beta_prior(
    args = vb_args,
    beta_prior_type = beta_prior_type,
    intercept_index = intercept_index,
    context = "qdesn_fit_discrepancy_vb"
  )
  prior_sigma <- .qdesn_discrepancy_prior_sigma(
    get_exact(vb_args, "prior_sigma", list(a = 1, b = 1)),
    C = length(source_levels),
    default_a = get_exact(vb_args, "a_sigma", 1),
    default_b = get_exact(vb_args, "b_sigma", 1)
  )

  gamma_bounds <- as.numeric(get_exact(vb_args, "gamma_bounds", c(L.fn(p0), U.fn(p0))))
  al_fixed_gamma <- as.numeric(get_exact(vb_args, "al_fixed_gamma", 0))[1L]
  if (!is.finite(al_fixed_gamma) || al_fixed_gamma <= gamma_bounds[1L] || al_fixed_gamma >= gamma_bounds[2L]) {
    al_fixed_gamma <- if (gamma_bounds[1L] < 0 && gamma_bounds[2L] > 0) 0 else mean(gamma_bounds)
  }
  A <- as.numeric(A.fn(p0, al_fixed_gamma))[1L]
  B <- as.numeric(B.fn(p0, al_fixed_gamma))[1L]
  if (!is.finite(A) || !is.finite(B) || B <= 0) .stopf("Invalid AL constants for p0 and al_fixed_gamma.")

  n <- length(z)
  p <- ncol(H)
  C <- length(source_levels)
  coln_theta <- colnames(H) %||% paste0("theta_", seq_len(p))

  beta_state <- beta_prior_obj$init(p)
  beta_prec_diag <- beta_prior_obj$expected_prec(beta_state, p)
  theta_init <- tryCatch(
    as.numeric(solve(crossprod(H) + diag(pmax(beta_prec_diag, 1e-8), p), crossprod(H, z))),
    error = function(e) rep(0, p)
  )
  qbeta <- list(m = theta_init, V = diag(1 / pmax(beta_prec_diag, 1e-8), p))

  resid_init <- z - drop(H %*% qbeta$m)
  sigma_init <- rep(stats::var(resid_init) %||% 1, C)
  for (cc in seq_len(C)) {
    idx <- idx_by_source[[as.character(cc)]]
    if (length(idx)) sigma_init[cc] <- stats::var(resid_init[idx]) %||% sigma_init[cc]
  }
  sigma_init[!is.finite(sigma_init) | sigma_init <= 0] <- 1
  qsigma <- list(
    shape = prior_sigma$a + 1.5 * as.numeric(table(source)[source_levels]),
    scale = prior_sigma$b + prior_sigma$a * sigma_init,
    E_sigma = sigma_init,
    E_inv_sigma = 1 / pmax(sigma_init, 1e-12),
    E_log_sigma = log(pmax(sigma_init, 1e-12))
  )
  qv <- list(
    E_v = rep(1, n),
    E_inv_v = rep(1, n),
    chi = rep(1, n),
    psi = rep(1, n)
  )

  update_qbeta <- function(qbeta, beta_prec_diag, qv, qsigma) {
    E_inv_sigma_i <- qsigma$E_inv_sigma[src_id]
    W_diag <- E_inv_sigma_i * qv$E_inv_v / B
    Prec <- crossprod(H * sqrt(W_diag)) + diag(beta_prec_diag, p)
    rhs <- crossprod(H, E_inv_sigma_i * (z * qv$E_inv_v - A) / B)
    sol <- .solve_sympd(Prec, rhs)
    list(m = sol$x, V = sol$inv, solve = sol)
  }

  update_qv <- function(qbeta, qsigma) {
    eta <- z - drop(H %*% qbeta$m)
    resid2 <- eta * eta + .qdesn_discrepancy_quad_diag(H, qbeta$V)
    E_inv_sigma_i <- qsigma$E_inv_sigma[src_id]
    chi <- E_inv_sigma_i * resid2 / B
    psi <- E_inv_sigma_i * (A * A / B + 2)
    moments <- .gig_half_moments(chi = chi, psi = psi)
    list(
      E_v = pmax(moments$m, 1e-12),
      E_inv_v = pmax(moments$m_inv, 1e-12),
      chi = pmax(chi, 1e-12),
      psi = pmax(psi, 1e-12),
      resid2 = resid2,
      eta = eta
    )
  }

  update_qsigma <- function(qbeta, qv) {
    eta <- z - drop(H %*% qbeta$m)
    resid2 <- eta * eta + .qdesn_discrepancy_quad_diag(H, qbeta$V)
    shape <- numeric(C)
    scale <- numeric(C)
    for (cc in seq_len(C)) {
      idx <- idx_by_source[[as.character(cc)]]
      n_c <- length(idx)
      shape[cc] <- prior_sigma$a[cc] + 1.5 * n_c
      scale[cc] <- prior_sigma$b[cc] +
        sum(qv$E_v[idx]) +
        0.5 * sum(qv$E_inv_v[idx] * resid2[idx]) / B -
        A * sum(eta[idx]) / B +
        0.5 * A * A * sum(qv$E_v[idx]) / B
      scale[cc] <- max(scale[cc], 1e-12)
    }
    E_inv_sigma <- shape / scale
    E_sigma <- ifelse(shape > 1, scale / pmax(shape - 1, 1e-12), scale / shape)
    E_log_sigma <- log(scale) - digamma(shape)
    list(
      shape = shape,
      scale = scale,
      E_sigma = E_sigma,
      E_inv_sigma = E_inv_sigma,
      E_log_sigma = E_log_sigma
    )
  }

  elbo_trace <- rep(NA_real_, max_iter)
  max_par_trace <- rep(NA_real_, max_iter)
  rel_trace <- rep(NA_real_, max_iter)
  converged <- FALSE
  iter_done <- max_iter

  for (iter in seq_len(max_iter)) {
    old_m <- qbeta$m
    old_sig <- qsigma$E_sigma
    old_elbo <- if (iter == 1L) NA_real_ else elbo_trace[iter - 1L]

    qbeta <- update_qbeta(qbeta, beta_prec_diag, qv, qsigma)
    if (!identical(beta_prior_obj$type, "ridge")) {
      beta_state <- beta_prior_obj$update(beta_state, qbeta)
      beta_prec_diag <- beta_prior_obj$expected_prec(beta_state, p)
      qbeta <- update_qbeta(qbeta, beta_prec_diag, qv, qsigma)
    }
    qv <- update_qv(qbeta, qsigma)
    qsigma <- update_qsigma(qbeta, qv)

    elbo <- .qdesn_discrepancy_vb_elbo(
      z = z,
      H = H,
      src_id = src_id,
      A = A,
      B = B,
      qbeta = qbeta,
      beta_prior_obj = beta_prior_obj,
      beta_state = beta_state,
      beta_prec_diag = beta_prec_diag,
      qv = qv,
      qsigma = qsigma,
      prior_sigma = prior_sigma
    )
    elbo_trace[iter] <- elbo
    max_par <- max(abs(qbeta$m - old_m), abs(log(pmax(qsigma$E_sigma, 1e-12)) - log(pmax(old_sig, 1e-12))))
    max_par_trace[iter] <- max_par
    rel <- if (is.finite(old_elbo)) abs(elbo - old_elbo) / (1 + abs(old_elbo)) else Inf
    rel_trace[iter] <- rel

    if (iter >= min_iter && is.finite(rel) && rel < tol && is.finite(max_par) && max_par < tol_par) {
      converged <- TRUE
      iter_done <- iter
      break
    }
  }

  elbo_trace <- elbo_trace[seq_len(iter_done)]
  max_par_trace <- max_par_trace[seq_len(iter_done)]
  rel_trace <- rel_trace[seq_len(iter_done)]

  if (!is.null(seed)) set.seed(as.integer(seed)[1L])
  theta_draws <- .qdesn_discrepancy_mvrnorm(n_draws, qbeta$m, qbeta$V)
  colnames(theta_draws) <- coln_theta
  sigma_draws <- matrix(NA_real_, n_draws, C)
  for (cc in seq_len(C)) {
    sigma_draws[, cc] <- 1 / stats::rgamma(n_draws, shape = qsigma$shape[cc], rate = qsigma$scale[cc])
  }
  colnames(sigma_draws) <- paste0("sigma_", source_levels)
  gamma_draws <- matrix(al_fixed_gamma, n_draws, C)
  colnames(gamma_draws) <- paste0("gamma_", source_levels)

  theta_mean <- as.numeric(qbeta$m)
  names(theta_mean) <- coln_theta
  theta_median <- apply(theta_draws, 2L, stats::median)
  sigma_mean <- as.numeric(qsigma$E_sigma)
  names(sigma_mean) <- paste0("sigma_", source_levels)
  sigma_median <- apply(sigma_draws, 2L, stats::median)
  fitted_mean <- as.numeric(H %*% theta_mean)
  fitted_median <- as.numeric(H %*% theta_median)

  vb_diagnostics <- list(
    converged = converged,
    iterations = iter_done,
    runtime_seconds = as.numeric(proc.time()[["elapsed"]] - time_start),
    elbo_trace = elbo_trace,
    elbo_final = tail(elbo_trace, 1L),
    elbo_relative_change = tail(rel_trace, 1L),
    max_parameter_change = tail(max_par_trace, 1L),
    max_parameter_change_trace = max_par_trace,
    relative_change_trace = rel_trace,
    ld_block_active = FALSE,
    finite = all(is.finite(theta_draws)) && all(is.finite(sigma_draws)),
    source_counts = table(source)
  )

  out <- list(
    z = z,
    H = H,
    source = source,
    source_levels = source_levels,
    p0 = p0,
    method = "vb",
    likelihood_family = likelihood_family,
    al_fixed_gamma = al_fixed_gamma,
    constants = list(A = A, B = B),
    qbeta = qbeta,
    qv = qv,
    qsigma = qsigma,
    draws = list(theta = theta_draws, sigma = sigma_draws, gamma = gamma_draws),
    samp.theta = theta_draws,
    samp.sigma = sigma_draws,
    samp.gamma = gamma_draws,
    summary = list(
      theta_mean = theta_mean,
      theta_median = theta_median,
      theta_sd = apply(theta_draws, 2L, stats::sd),
      sigma_mean = sigma_mean,
      sigma_median = sigma_median,
      sigma_sd = apply(sigma_draws, 2L, stats::sd),
      fitted_mean = fitted_mean,
      fitted_median = fitted_median
    ),
    beta_prior = list(
      type = beta_prior_obj$type,
      hypers = beta_prior_obj$hypers,
      state = beta_state,
      intercept_index = intercept_index
    ),
    vb_diagnostics = vb_diagnostics,
    diagnostics = vb_diagnostics,
    last = list(theta = theta_mean, sigma = sigma_mean, v = qv$E_v, beta_prior_state = beta_state)
  )
  class(out) <- c("qdesn_discrepancy_fit", "list")
  out
}

#' @keywords internal
qdesn_fit_discrepancy_mcmc <- function(
  z,
  H,
  source,
  p0,
  likelihood_family = "al",
  beta_prior_type = "rhs_ns",
  source_levels = c("Y", "G"),
  intercept_index = integer(),
  mcmc_args = list(),
  control = list()
) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  get_exact <- function(x, name, default = NULL) {
    if (!is.list(x)) return(default)
    out <- x[[name, exact = TRUE]]
    if (is.null(out)) default else out
  }

  z <- as.numeric(z)
  H <- as.matrix(H)
  storage.mode(H) <- "double"
  if (!length(z) || any(!is.finite(z))) .stopf("z must be a finite numeric vector.")
  if (nrow(H) != length(z) || !ncol(H) || any(!is.finite(H))) {
    .stopf("H must be a finite numeric matrix with one row per element of z.")
  }
  if (!is.finite(p0) || length(p0) != 1L || p0 <= 0 || p0 >= 1) {
    .stopf("p0 must be a scalar in (0, 1).")
  }
  source_levels <- as.character(source_levels)
  if (!length(source_levels) || any(!nzchar(source_levels))) {
    .stopf("source_levels must contain non-empty source labels.")
  }
  source <- factor(as.character(source), levels = source_levels)
  if (length(source) != length(z) || anyNA(source)) {
    .stopf("source must have one valid source label per row.")
  }

  likelihood_family <- match.arg(likelihood_family, c("al", "exal"))
  if (!identical(likelihood_family, "al")) {
    .stopf("qdesn_fit_discrepancy_mcmc currently implements AL only.")
  }

  mcmc_args <- modifyList(control %||% list(), mcmc_args %||% list())
  n_burn <- as.integer(get_exact(mcmc_args, "n_burn", get_exact(mcmc_args, "burn_in", 1000L)))[1L]
  n_mcmc <- as.integer(get_exact(mcmc_args, "n_mcmc", get_exact(mcmc_args, "n_iter", 1000L)))[1L]
  thin <- as.integer(get_exact(mcmc_args, "thin", 1L))[1L]
  if (!is.finite(n_burn) || n_burn < 0L) .stopf("mcmc_args$n_burn must be non-negative.")
  if (!is.finite(n_mcmc) || n_mcmc < 1L) .stopf("mcmc_args$n_mcmc must be positive.")
  if (!is.finite(thin) || thin < 1L) .stopf("mcmc_args$thin must be positive.")
  n_total <- n_burn + n_mcmc * thin
  if (!is.null(get_exact(mcmc_args, "seed", NULL))) set.seed(as.integer(get_exact(mcmc_args, "seed")))

  beta_prior_obj <- get_exact(mcmc_args, "beta_prior_obj", NULL)
  beta_prior_type <- tolower(as.character(beta_prior_type %||% get_exact(mcmc_args, "beta_prior_type", "rhs_ns"))[1L])
  if (identical(beta_prior_type, "rhs")) beta_prior_type <- "rhs_ns"
  if (is.null(beta_prior_obj)) {
    rhs_list <- get_exact(mcmc_args, "beta_rhs", get_exact(mcmc_args, "rhs", list()))
    if (beta_prior_type %in% c("rhs_ns")) {
      rhs_list <- .qdesn_enforce_rhs_controls(rhs_list, context = "qdesn_fit_discrepancy")
      rhs_list$intercept_index <- intercept_index
    }
    beta_prior_obj <- exal_make_beta_prior(
      type = beta_prior_type,
      tau2 = get_exact(mcmc_args, "beta_ridge_tau2", get_exact(mcmc_args, "tau2", 1e4)),
      rhs = rhs_list
    )
  }
  if (!identical(beta_prior_obj$type, "rhs_ns") && !identical(beta_prior_obj$type, "ridge")) {
    .stopf("qdesn_fit_discrepancy currently supports beta_prior_type in {'rhs_ns','ridge'}.")
  }

  prior_sigma <- get_exact(mcmc_args, "prior_sigma", list(a = 1, b = 1))
  a_sigma <- as.numeric(prior_sigma$a %||% get_exact(mcmc_args, "a_sigma", 1))[1L]
  b_sigma <- as.numeric(prior_sigma$b %||% get_exact(mcmc_args, "b_sigma", 1))[1L]
  if (!is.finite(a_sigma) || a_sigma <= 0 || !is.finite(b_sigma) || b_sigma <= 0) {
    .stopf("prior_sigma must define positive a and b.")
  }

  gamma_bounds <- as.numeric(get_exact(mcmc_args, "gamma_bounds", c(L.fn(p0), U.fn(p0))))
  al_fixed_gamma <- as.numeric(get_exact(mcmc_args, "al_fixed_gamma", 0))[1L]
  if (!is.finite(al_fixed_gamma) || al_fixed_gamma <= gamma_bounds[1L] || al_fixed_gamma >= gamma_bounds[2L]) {
    al_fixed_gamma <- if (gamma_bounds[1L] < 0 && gamma_bounds[2L] > 0) 0 else mean(gamma_bounds)
  }
  A <- as.numeric(A.fn(p0, al_fixed_gamma))[1L]
  B <- as.numeric(B.fn(p0, al_fixed_gamma))[1L]
  if (!is.finite(A) || !is.finite(B) || B <= 0) .stopf("Invalid AL constants for p0 and al_fixed_gamma.")

  n <- length(z)
  p <- ncol(H)
  C <- length(source_levels)
  src_id <- as.integer(source)
  idx_by_source <- split(seq_len(n), src_id)

  init <- get_exact(mcmc_args, "init", list())
  theta <- as.numeric(init$theta %||% init$beta %||% rep(NA_real_, p))
  if (length(theta) != p || any(!is.finite(theta))) {
    theta <- tryCatch(
      as.numeric(solve(crossprod(H) + diag(1e-6, p), crossprod(H, z))),
      error = function(e) rep(0, p)
    )
  }
  sigma <- as.numeric(init$sigma %||% rep(stats::sd(z), C))
  if (length(sigma) == 1L) sigma <- rep(sigma, C)
  if (length(sigma) != C) .stopf("init$sigma must be scalar or have one entry per source level.")
  sigma[!is.finite(sigma) | sigma <= 0] <- 1
  v <- as.numeric(init$v %||% rep(1, n))
  if (length(v) != n) v <- rep(1, n)
  v <- pmax(v, 1e-12)

  rhs_state <- NULL
  beta_prec_diag <- rep(1, p)
  if (identical(beta_prior_obj$type, "rhs_ns")) {
    rhs_state <- .exal_mcmc_rhs_ns_prepare_state(beta_prior_obj, p = p, init = init, vb_warm = NULL)
    beta_prec_diag <- .exal_mcmc_rhs_ns_precisions(rhs_state, p = p)
  } else {
    tau2 <- as.numeric(beta_prior_obj$hypers$tau2 %||% 1e4)[1L]
    beta_prec_diag <- rep(1 / tau2, p)
  }

  n_keep <- n_mcmc
  theta_draws <- matrix(NA_real_, n_keep, p)
  sigma_draws <- matrix(NA_real_, n_keep, C)
  colnames(theta_draws) <- colnames(H) %||% paste0("theta_", seq_len(p))
  colnames(sigma_draws) <- paste0("sigma_", source_levels)
  tau_draws <- rep(NA_real_, n_keep)
  zeta2_draws <- rep(NA_real_, n_keep)
  keep_idx <- 0L

  precision_beta_cfg <- get_exact(
    mcmc_args,
    "precision_beta",
    list(enabled = TRUE, symmetrize = TRUE, jitter_ladder = c(0, 1e-10, 1e-8), eigen_fallback = TRUE)
  )

  for (iter in seq_len(n_total)) {
    sigma_i <- sigma[src_id]
    z_v <- z - drop(H %*% theta)
    chi_v <- (z_v * z_v) / (B * sigma_i)
    for (cc in seq_len(C)) {
      idx <- idx_by_source[[as.character(cc)]]
      if (!length(idx)) next
      psi_c <- (A * A) / (B * sigma[cc]) + (2 / sigma[cc])
      v[idx] <- as.numeric(.sample_gig_devroye_required(
        1L,
        p = 0.5,
        a = psi_c,
        b_vec = pmax(chi_v[idx], 1e-14),
        context = "qdesn_fit_discrepancy::latent_v"
      )[1L, ])
    }
    v <- pmax(v, 1e-12)

    W_diag <- 1 / (B * sigma_i * v)
    y_star <- z - A * v
    Prec <- crossprod(H * sqrt(W_diag)) + diag(beta_prec_diag, p)
    rhs <- crossprod(H, W_diag * y_star)
    theta_draw <- .exal_mcmc_sample_mvnorm_prec(
      rhs,
      Prec,
      precision_beta_cfg = precision_beta_cfg,
      context = list(iter = iter, likelihood_family = likelihood_family, beta_prior_type = beta_prior_obj$type)
    )
    theta <- theta_draw$draw

    for (cc in seq_len(C)) {
      idx <- idx_by_source[[as.character(cc)]]
      if (!length(idx)) next
      r_c <- z[idx] - drop(H[idx, , drop = FALSE] %*% theta) - A * v[idx]
      chi_sigma <- sum((r_c * r_c) / (B * v[idx])) + 2 * sum(v[idx]) + 2 * b_sigma
      shape_sigma <- a_sigma + 1.5 * length(idx)
      sigma[cc] <- 1 / stats::rgamma(1L, shape = shape_sigma, rate = max(chi_sigma / 2, 1e-12))
      sigma[cc] <- max(sigma[cc], 1e-12)
    }

    if (identical(beta_prior_obj$type, "rhs_ns")) {
      upd <- .exal_mcmc_rhs_ns_gibbs_update(rhs_state, theta, beta_prior_obj, freeze_tau = FALSE)
      rhs_state <- upd$state
      beta_prec_diag <- .exal_mcmc_rhs_ns_precisions(rhs_state, p = p)
    }

    if (iter > n_burn && ((iter - n_burn) %% thin == 0L)) {
      keep_idx <- keep_idx + 1L
      theta_draws[keep_idx, ] <- theta
      sigma_draws[keep_idx, ] <- sigma
      if (!is.null(rhs_state)) {
        tau_draws[keep_idx] <- sqrt(max(as.numeric(rhs_state$tau2)[1L], 1e-16))
        zeta2_draws[keep_idx] <- max(as.numeric(rhs_state$zeta2)[1L], 1e-16)
      }
    }
  }

  theta_mean <- colMeans(theta_draws)
  theta_median <- apply(theta_draws, 2L, stats::median)
  sigma_mean <- colMeans(sigma_draws)
  sigma_median <- apply(sigma_draws, 2L, stats::median)
  fitted_mean <- as.numeric(H %*% theta_mean)
  fitted_median <- as.numeric(H %*% theta_median)

  out <- list(
    z = z,
    H = H,
    source = source,
    source_levels = source_levels,
    p0 = p0,
    method = "mcmc",
    likelihood_family = likelihood_family,
    al_fixed_gamma = al_fixed_gamma,
    constants = list(A = A, B = B),
    draws = list(theta = theta_draws, sigma = sigma_draws),
    samp.theta = theta_draws,
    samp.sigma = sigma_draws,
    samp.tau = tau_draws,
    samp.zeta2 = zeta2_draws,
    summary = list(
      theta_mean = theta_mean,
      theta_median = theta_median,
      sigma_mean = sigma_mean,
      sigma_median = sigma_median,
      fitted_mean = fitted_mean,
      fitted_median = fitted_median
    ),
    beta_prior = list(
      type = beta_prior_obj$type,
      hypers = beta_prior_obj$hypers,
      state = rhs_state,
      intercept_index = intercept_index
    ),
    diagnostics = list(
      n_burn = n_burn,
      n_mcmc = n_mcmc,
      thin = thin,
      n_total = n_total,
      finite = all(is.finite(theta_draws)) && all(is.finite(sigma_draws)),
      source_counts = table(source)
    ),
    last = list(theta = theta, sigma = sigma, v = v, beta_prior_state = rhs_state)
  )
  class(out) <- c("qdesn_discrepancy_fit", "list")
  out
}
