#' Fit exAL readout with MCMC and pluggable beta prior
#'
#' This is the MCMC counterpart to [exal_ldvb_fit()]. The initial implementation
#' supports the ridge beta prior and uses slice sampling for the nonconjugate
#' `gamma` block on a transformed coordinate. Closed-form Gibbs updates are used
#' for `beta`, `v`, and `s`. The `sigma` block can be sampled either via the
#' conjugate GIG draw (default) or a log-sigma slice sampler when enabled.
#'
#' The current implementation supports ridge, regularized horseshoe (`rhs`),
#' and Nishimura-Suchard-style augmented regularized horseshoe (`rhs_ns`)
#' readout priors. Under RHS, the MCMC kernel conditions on the exact current
#' local/global/slab scales and therefore uses the exact conditional precision
#' `1 / V_j = exp(-eta_c2) + exp(-2 eta_tau - 2 eta_lambda_j)` in the Gaussian
#' beta block; the delta-method approximation remains a VB-only moment device.
#'
#' @keywords internal
.exal_mcmc_sample_mvnorm_prec <- function(rhs, Prec, precision_beta_cfg = list(), context = list()) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  rhs <- as.numeric(rhs)
  Prec <- as.matrix(Prec)
  storage.mode(Prec) <- "double"
  p <- nrow(Prec)

  precision_beta_cfg <- precision_beta_cfg %||% list()
  enabled <- isTRUE(precision_beta_cfg$enabled %||% FALSE)
  symmetrize <- if (enabled) isTRUE(precision_beta_cfg$symmetrize %||% TRUE) else FALSE
  jitter_ladder <- as.numeric(precision_beta_cfg$jitter_ladder %||% c(0, 1e-10))
  jitter_ladder <- jitter_ladder[is.finite(jitter_ladder) & jitter_ladder >= 0]
  if (!length(jitter_ladder)) jitter_ladder <- c(0, 1e-10)
  jitter_ladder <- unique(jitter_ladder)
  eigen_fallback <- if (enabled) isTRUE(precision_beta_cfg$eigen_fallback %||% FALSE) else FALSE
  eigen_floor_abs <- as.numeric(precision_beta_cfg$eigen_floor_abs %||% 1e-6)[1L]
  if (!is.finite(eigen_floor_abs) || eigen_floor_abs <= 0) eigen_floor_abs <- 1e-6
  eigen_floor_rel <- as.numeric(precision_beta_cfg$eigen_floor_rel %||% 1e-8)[1L]
  if (!is.finite(eigen_floor_rel) || eigen_floor_rel <= 0) eigen_floor_rel <- 1e-8

  chol_fit <- .exal_mcmc_precision_beta_repair(
    Prec = Prec,
    symmetrize = symmetrize,
    jitter_ladder = jitter_ladder,
    eigen_fallback = eigen_fallback,
    eigen_floor_abs = eigen_floor_abs,
    eigen_floor_rel = eigen_floor_rel
  )
  if (is.null(chol_fit$Uc)) {
    .exal_mcmc_stop_precision_beta_error(
      parent = simpleError(chol_fit$info$error_message %||% "precision beta factorization failed"),
      context = context,
      failure_info = chol_fit$info
    )
  }

  Uc <- chol_fit$Uc
  mu <- backsolve(Uc, forwardsolve(t(Uc), rhs))
  list(
    draw = as.numeric(mu + backsolve(Uc, stats::rnorm(length(mu)))),
    info = chol_fit$info
  )
}

#' @keywords internal
.exal_mcmc_slice_sample_1d <- function(x0, logf, width = 1.0, max_steps_out = 100L,
                                       max_shrink = 1000L, lower = -Inf, upper = Inf) {
  logx0 <- logf(x0)
  if (!is.finite(logx0)) .stopf("slice sampler received a non-finite initial log density.")
  logy <- logx0 - stats::rexp(1L, rate = 1)

  u <- stats::runif(1L, 0, width)
  left <- x0 - u
  right <- x0 + (width - u)
  if (is.finite(lower)) left <- max(left, lower)
  if (is.finite(upper)) right <- min(right, upper)

  j <- as.integer(floor(stats::runif(1L, 0, max_steps_out + 1L)))
  k <- max_steps_out - j
  n_steps_out <- 0L

  while (j > 0L && left > lower) {
    val <- logf(left)
    if (!is.finite(val) || val <= logy) break
    left <- max(left - width, lower)
    j <- j - 1L
    n_steps_out <- n_steps_out + 1L
  }
  while (k > 0L && right < upper) {
    val <- logf(right)
    if (!is.finite(val) || val <= logy) break
    right <- min(right + width, upper)
    k <- k - 1L
    n_steps_out <- n_steps_out + 1L
  }

  n_shrink <- 0L
  repeat {
    x1 <- stats::runif(1L, left, right)
    logx1 <- logf(x1)
    if (is.finite(logx1) && logx1 >= logy) {
      return(list(x = x1, logf = logx1, n_steps_out = n_steps_out, n_shrink = n_shrink))
    }
    if (x1 < x0) {
      left <- x1
    } else {
      right <- x1
    }
    n_shrink <- n_shrink + 1L
    if (n_shrink >= max_shrink) {
      .stopf("slice sampler exceeded max_shrink=%d without finding an acceptable point.", max_shrink)
    }
  }
}

#' @keywords internal
.exal_mcmc_slice_line_bounds <- function(x0, direction, lower, upper) {
  x0 <- as.numeric(x0)
  direction <- as.numeric(direction)
  lower <- as.numeric(lower)
  upper <- as.numeric(upper)
  if (!(length(x0) == length(direction) && length(x0) == length(lower) && length(x0) == length(upper))) {
    .stopf("slice line bounds require equal-length vectors.")
  }

  z_lower <- -Inf
  z_upper <- Inf
  for (ii in seq_along(x0)) {
    di <- direction[[ii]]
    if (!is.finite(di) || abs(di) < 1e-14) {
      if (x0[[ii]] < lower[[ii]] || x0[[ii]] > upper[[ii]]) {
        return(list(lower = Inf, upper = -Inf))
      }
      next
    }
    zi1 <- (lower[[ii]] - x0[[ii]]) / di
    zi2 <- (upper[[ii]] - x0[[ii]]) / di
    z_lower <- max(z_lower, min(zi1, zi2))
    z_upper <- min(z_upper, max(zi1, zi2))
  }
  list(lower = z_lower, upper = z_upper)
}

#' @keywords internal
.exal_mcmc_safe_ess <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 3L) return(NA_real_)
  out <- tryCatch(coda::effectiveSize(coda::as.mcmc(x)), error = function(...) NA_real_)
  as.numeric(out)[1L]
}

#' @keywords internal
.exal_mcmc_safe_geweke_absz <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 10L) return(NA_real_)
  out <- tryCatch(coda::geweke.diag(coda::as.mcmc(x))$z, error = function(...) NA_real_)
  abs(as.numeric(out)[1L])
}

#' @keywords internal
.exal_mcmc_half_drift <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 8L) return(NA_real_)
  n1 <- floor(n / 2L)
  x1 <- x[seq_len(n1)]
  x2 <- x[seq.int(n1 + 1L, n)]
  s_full <- stats::sd(x)
  if (!is.finite(s_full) || s_full <= 1e-12) {
    return(if (isTRUE(all.equal(mean(x1), mean(x2), tolerance = 1e-12))) 0 else NA_real_)
  }
  abs(mean(x1) - mean(x2)) / s_full
}

#' @keywords internal
.exal_mcmc_multistart_score <- function(fit, cfg = list()) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  sigma <- as.numeric(fit$samp.sigma %||% numeric(0))
  gamma <- as.numeric(fit$samp.gamma %||% numeric(0))
  beta_draws <- as.matrix(fit$samp.beta %||% matrix(numeric(0), nrow = 0L))
  beta_norm <- if (nrow(beta_draws)) sqrt(rowSums(beta_draws * beta_draws)) else numeric(0)
  tau <- as.numeric(fit$samp.tau %||% numeric(0))
  c2 <- as.numeric(fit$samp.c2 %||% numeric(0))

  ess_vals <- c(
    .exal_mcmc_safe_ess(gamma),
    .exal_mcmc_safe_ess(sigma),
    .exal_mcmc_safe_ess(beta_norm),
    if (length(tau)) .exal_mcmc_safe_ess(tau) else NA_real_,
    if (length(c2)) .exal_mcmc_safe_ess(c2) else NA_real_
  )
  geweke_vals <- c(
    .exal_mcmc_safe_geweke_absz(gamma),
    .exal_mcmc_safe_geweke_absz(sigma),
    .exal_mcmc_safe_geweke_absz(beta_norm),
    if (length(tau)) .exal_mcmc_safe_geweke_absz(tau) else NA_real_,
    if (length(c2)) .exal_mcmc_safe_geweke_absz(c2) else NA_real_
  )
  drift_vals <- c(
    .exal_mcmc_half_drift(gamma),
    .exal_mcmc_half_drift(sigma),
    .exal_mcmc_half_drift(beta_norm),
    if (length(tau)) .exal_mcmc_half_drift(tau) else NA_real_,
    if (length(c2)) .exal_mcmc_half_drift(c2) else NA_real_
  )

  finite_ok <- all(is.finite(c(gamma, sigma, beta_norm)))
  domain_ok <- length(sigma) > 0L &&
    all(is.finite(sigma)) && all(sigma > 0) &&
    length(gamma) > 0L && all(is.finite(gamma))
  tau_med <- if (length(tau) && any(is.finite(tau))) stats::median(tau[is.finite(tau)]) else NA_real_
  beta_norm_med <- if (length(beta_norm) && any(is.finite(beta_norm))) stats::median(beta_norm[is.finite(beta_norm)]) else NA_real_
  collapse_tau_floor <- as.numeric(cfg$collapse_tau_floor %||% 1e-7)[1L]
  collapse_beta_floor <- as.numeric(cfg$collapse_beta_norm_floor %||% 1e-4)[1L]
  collapse_flag <- is.finite(tau_med) && is.finite(beta_norm_med) &&
    tau_med <= collapse_tau_floor && beta_norm_med <= collapse_beta_floor

  ess_min <- if (any(is.finite(ess_vals))) min(ess_vals[is.finite(ess_vals)]) else NA_real_
  geweke_max <- if (any(is.finite(geweke_vals))) max(geweke_vals[is.finite(geweke_vals)]) else NA_real_
  drift_max <- if (any(is.finite(drift_vals))) max(drift_vals[is.finite(drift_vals)]) else NA_real_

  ess_min_gate <- as.numeric(cfg$ess_min %||% 20)[1L]
  geweke_max_gate <- as.numeric(cfg$geweke_max %||% 3)[1L]
  drift_max_gate <- as.numeric(cfg$half_drift_max %||% 0.5)[1L]
  healthy <- isTRUE(finite_ok) &&
    isTRUE(domain_ok) &&
    !isTRUE(collapse_flag) &&
    (!is.finite(ess_min) || ess_min >= ess_min_gate) &&
    (!is.finite(geweke_max) || geweke_max <= geweke_max_gate) &&
    (!is.finite(drift_max) || drift_max <= drift_max_gate)

  score <- 0
  if (isTRUE(healthy)) score <- score + 10000
  if (is.finite(ess_min)) score <- score + ess_min
  if (is.finite(geweke_max)) score <- score - 10 * geweke_max
  if (is.finite(drift_max)) score <- score - 10 * drift_max
  if (isTRUE(collapse_flag)) score <- score - 1000
  if (!isTRUE(finite_ok)) score <- score - 1000
  if (!isTRUE(domain_ok)) score <- score - 1000

  list(
    healthy = isTRUE(healthy),
    finite_ok = isTRUE(finite_ok),
    domain_ok = isTRUE(domain_ok),
    collapse_flag = isTRUE(collapse_flag),
    ess_min = as.numeric(ess_min),
    geweke_max = as.numeric(geweke_max),
    half_drift_max = as.numeric(drift_max),
    tau_median = as.numeric(tau_med),
    beta_norm_median = as.numeric(beta_norm_med),
    score = as.numeric(score)
  )
}

#' @keywords internal
.exal_mcmc_clamp <- function(x, lo, hi) {
  x <- as.numeric(x)
  pmin(pmax(x, lo), hi)
}

#' @keywords internal
.exal_mcmc_numeric_summary <- function(x) {
  x <- as.numeric(x)
  finite <- is.finite(x)
  x_fin <- x[finite]
  list(
    n = as.integer(length(x)),
    n_finite = as.integer(sum(finite)),
    n_nonfinite = as.integer(sum(!finite)),
    min = if (length(x_fin)) min(x_fin) else NA_real_,
    max = if (length(x_fin)) max(x_fin) else NA_real_,
    mean = if (length(x_fin)) mean(x_fin) else NA_real_,
    median = if (length(x_fin)) stats::median(x_fin) else NA_real_
  )
}

#' @keywords internal
.exal_mcmc_symmetry_max_abs_diff <- function(mat) {
  mat <- as.matrix(mat)
  if (!nrow(mat) || !ncol(mat)) return(NA_real_)
  as.numeric(max(abs(mat - t(mat))))
}

#' @keywords internal
.exal_mcmc_precision_beta_repair <- function(Prec,
                                             symmetrize = FALSE,
                                             jitter_ladder = c(0, 1e-10),
                                             eigen_fallback = FALSE,
                                             eigen_floor_abs = 1e-6,
                                             eigen_floor_rel = 1e-8) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  Prec <- as.matrix(Prec)
  storage.mode(Prec) <- "double"
  p <- nrow(Prec)
  if (!p || ncol(Prec) != p) {
    return(list(
      Uc = NULL,
      info = list(
        strategy = "invalid_matrix",
        matrix_dim = as.integer(p),
        error_message = "precision beta matrix must be square"
      )
    ))
  }

  Prec_work <- if (isTRUE(symmetrize)) (Prec + t(Prec)) / 2 else Prec
  diag_summary <- .exal_mcmc_numeric_summary(diag(Prec_work))
  symmetry_max_abs_diff <- .exal_mcmc_symmetry_max_abs_diff(Prec)
  jitter_ladder <- as.numeric(jitter_ladder)
  jitter_ladder <- jitter_ladder[is.finite(jitter_ladder) & jitter_ladder >= 0]
  if (!length(jitter_ladder)) jitter_ladder <- c(0, 1e-10)
  jitter_ladder <- unique(jitter_ladder)

  attempt_count <- 0L
  last_err <- NULL
  max_jitter_tried <- max(jitter_ladder)

  attempt_chol <- function(mat, jitter, strategy, min_eigen = NA_real_, eigen_attempted = FALSE, eigen_floor = NA_real_) {
    attempt_count <<- attempt_count + 1L
    cand <- tryCatch(chol(mat + diag(jitter, p)), error = function(e) {
      last_err <<- e
      NULL
    })
    if (is.null(cand)) return(NULL)
    list(
      Uc = cand,
      info = list(
        strategy = strategy,
        matrix_dim = as.integer(p),
        attempt_count = as.integer(attempt_count),
        jitter_used = as.numeric(jitter),
        max_jitter_tried = as.numeric(max_jitter_tried),
        eigen_attempted = isTRUE(eigen_attempted),
        eigen_floor = as.numeric(eigen_floor),
        min_eigen = as.numeric(min_eigen),
        diag_min = as.numeric(diag_summary$min),
        diag_mean = as.numeric(diag_summary$mean),
        diag_max = as.numeric(diag_summary$max),
        symmetry_max_abs_diff = as.numeric(symmetry_max_abs_diff),
        error_message = NA_character_
      )
    )
  }

  for (jitter in jitter_ladder) {
    strategy <- if (jitter <= 0) "direct" else "jitter"
    out <- attempt_chol(Prec_work, jitter, strategy = strategy)
    if (!is.null(out)) return(out)
  }

  min_eigen <- tryCatch({
    vals <- eigen(Prec_work, symmetric = TRUE, only.values = TRUE)$values
    as.numeric(min(vals))
  }, error = function(...) NA_real_)

  if (isTRUE(eigen_fallback)) {
    eig <- tryCatch(eigen(Prec_work, symmetric = TRUE), error = function(e) {
      last_err <<- e
      NULL
    })
    if (!is.null(eig) && length(eig$values) == p) {
      scale_ref <- max(1.0, max(abs(eig$values), na.rm = TRUE))
      floor_target <- max(as.numeric(eigen_floor_abs), as.numeric(eigen_floor_rel) * scale_ref)
      vals_repaired <- pmax(as.numeric(eig$values), floor_target)
      Prec_eig <- eig$vectors %*% (vals_repaired * t(eig$vectors))
      Prec_eig <- (Prec_eig + t(Prec_eig)) / 2
      for (jitter in jitter_ladder) {
        strategy <- if (jitter <= 0) "eigen_floor" else "eigen_floor_jitter"
        out <- attempt_chol(
          Prec_eig,
          jitter,
          strategy = strategy,
          min_eigen = min_eigen,
          eigen_attempted = TRUE,
          eigen_floor = floor_target
        )
        if (!is.null(out)) return(out)
      }
    }
  }

  list(
    Uc = NULL,
    info = list(
      strategy = "failure",
      matrix_dim = as.integer(p),
      attempt_count = as.integer(attempt_count),
      jitter_used = NA_real_,
      max_jitter_tried = as.numeric(max_jitter_tried),
      eigen_attempted = isTRUE(eigen_fallback),
      eigen_floor = if (isTRUE(eigen_fallback)) as.numeric(max(eigen_floor_abs, eigen_floor_rel)) else NA_real_,
      min_eigen = as.numeric(min_eigen),
      diag_min = as.numeric(diag_summary$min),
      diag_mean = as.numeric(diag_summary$mean),
      diag_max = as.numeric(diag_summary$max),
      symmetry_max_abs_diff = as.numeric(symmetry_max_abs_diff),
      error_message = conditionMessage(last_err %||% simpleError("precision beta factorization failed"))
    )
  )
}

#' @keywords internal
.exal_mcmc_rhs_current_hypers <- function(beta_prior_type, rhs_state) {
  out <- list(tau = NA_real_, c2 = NA_real_)
  if (is.null(rhs_state)) return(out)

  if (identical(beta_prior_type, "rhs")) {
    out$tau <- exp(as.numeric(rhs_state$eta_tau_hat %||% NA_real_)[1L])
    out$c2 <- exp(as.numeric(rhs_state$eta_c_hat %||% NA_real_)[1L])
    return(out)
  }

  if (identical(beta_prior_type, "rhs_ns")) {
    tau2 <- as.numeric(rhs_state$tau2 %||% NA_real_)[1L]
    out$tau <- if (is.finite(tau2) && tau2 > 0) sqrt(tau2) else NA_real_
    out$c2 <- as.numeric(rhs_state$zeta2 %||% NA_real_)[1L]
  }
  out
}

#' @keywords internal
.exal_mcmc_stop_precision_beta_error <- function(parent, context = list(), failure_info = list()) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  rhs_hypers <- .exal_mcmc_rhs_current_hypers(
    context$beta_prior_type %||% NA_character_,
    context$rhs_state %||% NULL
  )
  failure_state <- list(
    failure_family = "precision_beta_chol_failure",
    iteration = as.integer(context$iter %||% NA_integer_)[1L],
    phase = if (!is.null(context$iter) && !is.null(context$n_burn)) {
      if (as.integer(context$iter)[1L] <= as.integer(context$n_burn)[1L]) "burn" else "keep"
    } else {
      NA_character_
    },
    likelihood_family = as.character(context$likelihood_family %||% NA_character_)[1L],
    beta_prior_type = as.character(context$beta_prior_type %||% NA_character_)[1L],
    sigma = as.numeric(context$sigma %||% NA_real_)[1L],
    gamma = as.numeric(context$gamma %||% NA_real_)[1L],
    tau = as.numeric(rhs_hypers$tau %||% NA_real_)[1L],
    c2 = as.numeric(rhs_hypers$c2 %||% NA_real_)[1L],
    beta_norm = sqrt(sum(as.numeric(context$beta %||% 0) * as.numeric(context$beta %||% 0))),
    latent_v_update_reason = as.character(context$latent_v_reason %||% NA_character_)[1L],
    latent_v_warmup_active = isTRUE(context$latent_v_warmup_active),
    theta_update_reason = as.character(context$theta_reason %||% NA_character_)[1L],
    theta_warmup_active = isTRUE(context$theta_warmup_active),
    conditioning_mode = as.character(context$conditioning_mode %||% NA_character_)[1L],
    core_update_mode = as.character(context$core_update_mode %||% NA_character_)[1L],
    precision_strategy = as.character(failure_info$strategy %||% NA_character_)[1L],
    precision_attempt_count = as.integer(failure_info$attempt_count %||% NA_integer_)[1L],
    precision_jitter_used = as.numeric(failure_info$jitter_used %||% NA_real_)[1L],
    precision_max_jitter_tried = as.numeric(failure_info$max_jitter_tried %||% NA_real_)[1L],
    precision_eigen_attempted = isTRUE(failure_info$eigen_attempted),
    precision_eigen_floor = as.numeric(failure_info$eigen_floor %||% NA_real_)[1L],
    precision_min_eigen = as.numeric(failure_info$min_eigen %||% NA_real_)[1L],
    precision_matrix_dim = as.integer(failure_info$matrix_dim %||% NA_integer_)[1L],
    precision_diag_min = as.numeric(failure_info$diag_min %||% NA_real_)[1L],
    precision_diag_mean = as.numeric(failure_info$diag_mean %||% NA_real_)[1L],
    precision_diag_max = as.numeric(failure_info$diag_max %||% NA_real_)[1L],
    precision_symmetry_max_abs_diff = as.numeric(failure_info$symmetry_max_abs_diff %||% NA_real_)[1L],
    error_message = conditionMessage(parent)
  )
  failure_json <- tryCatch(
    jsonlite::toJSON(failure_state, auto_unbox = TRUE, null = "null"),
    error = function(...) NULL
  )
  if (!is.null(failure_json)) {
    message(sprintf("QDESN_PRECISION_BETA_FAILURE_JSON=%s", as.character(failure_json)[1L]))
  }
  cond <- structure(
    list(
      message = conditionMessage(parent),
      call = NULL,
      precision_beta_failure = failure_state,
      parent = parent
    ),
    class = c("qdesn_precision_beta_error", "error", "condition")
  )
  stop(cond)
}

#' @keywords internal
.exal_mcmc_stop_latent_v_error <- function(parent,
                                           iter,
                                           n_burn,
                                           likelihood_family,
                                           beta_prior_type,
                                           sigma,
                                           gamma,
                                           beta,
                                           s,
                                           rhs_state,
                                           latent_v_reason,
                                           latent_v_warmup_active,
                                           latent_v_hard_freeze_active,
                                           latent_v_sparse_window_active,
                                           latent_v_rescue_enabled,
                                           latent_v_rescue_strategy,
                                           latent_v_rescue_count,
                                           latent_v_rescue_consecutive,
                                           latent_s_reason,
                                           latent_s_warmup_active,
                                           latent_s_hard_freeze_active,
                                           latent_s_sparse_window_active,
                                           theta_reason,
                                           theta_warmup_active,
                                           theta_hard_freeze_active,
                                           theta_sparse_window_active,
                                           chi_v,
                                           psi_v,
                                           z_v) {
  rhs_hypers <- .exal_mcmc_rhs_current_hypers(beta_prior_type, rhs_state)
  failure_state <- list(
    failure_family = "latent_v_invalid_draws",
    iteration = as.integer(iter),
    phase = if (iter <= n_burn) "burn" else "keep",
    likelihood_family = as.character(likelihood_family)[1L],
    beta_prior_type = as.character(beta_prior_type)[1L],
    sigma = as.numeric(sigma)[1L],
    gamma = as.numeric(gamma)[1L],
    tau = as.numeric(rhs_hypers$tau)[1L],
    c2 = as.numeric(rhs_hypers$c2)[1L],
    beta_norm = sqrt(sum(as.numeric(beta) * as.numeric(beta))),
    s = .exal_mcmc_numeric_summary(s),
    latent_v_update_reason = as.character(latent_v_reason)[1L],
    latent_v_warmup_active = isTRUE(latent_v_warmup_active),
    latent_v_hard_freeze_active = isTRUE(latent_v_hard_freeze_active),
    latent_v_sparse_window_active = isTRUE(latent_v_sparse_window_active),
    latent_v_rescue_enabled = isTRUE(latent_v_rescue_enabled),
    latent_v_rescue_strategy = as.character(latent_v_rescue_strategy %||% NA_character_)[1L],
    latent_v_rescue_count = as.integer(latent_v_rescue_count %||% NA_integer_)[1L],
    latent_v_rescue_consecutive = as.integer(latent_v_rescue_consecutive %||% NA_integer_)[1L],
    latent_s_update_reason = as.character(latent_s_reason %||% NA_character_)[1L],
    latent_s_warmup_active = isTRUE(latent_s_warmup_active),
    latent_s_hard_freeze_active = isTRUE(latent_s_hard_freeze_active),
    latent_s_sparse_window_active = isTRUE(latent_s_sparse_window_active),
    theta_update_reason = as.character(theta_reason %||% NA_character_)[1L],
    theta_warmup_active = isTRUE(theta_warmup_active),
    theta_hard_freeze_active = isTRUE(theta_hard_freeze_active),
    theta_sparse_window_active = isTRUE(theta_sparse_window_active),
    chi_v = .exal_mcmc_numeric_summary(chi_v),
    psi_v = .exal_mcmc_numeric_summary(psi_v),
    z_v = .exal_mcmc_numeric_summary(z_v),
    error_message = conditionMessage(parent)
  )
  failure_json <- tryCatch(
    jsonlite::toJSON(failure_state, auto_unbox = TRUE, null = "null"),
    error = function(...) NULL
  )
  if (!is.null(failure_json)) {
    message(sprintf("QDESN_LATENT_V_FAILURE_JSON=%s", as.character(failure_json)[1L]))
  }
  cond <- structure(
    list(
      message = conditionMessage(parent),
      call = NULL,
      latent_v_failure = failure_state,
      parent = parent
    ),
    class = c("qdesn_latent_v_error", "error", "condition")
  )
  stop(cond)
}

#' @keywords internal
.exal_mcmc_rhs_prepare_state <- function(beta_prior_obj, p, init = list(), vb_warm = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (!identical(beta_prior_obj$type, "rhs")) return(NULL)

  state <- beta_prior_obj$init(p)
  rhs_state_init <- init$rhs_state %||% init$beta_prior_state %||% NULL
  vb_state <- vb_warm$beta_prior$state %||% NULL
  state_src <- rhs_state_init %||% vb_state

  if (!is.null(state_src)) {
    for (nm in intersect(names(state_src), names(state))) {
      state[[nm]] <- state_src[[nm]]
    }
    if (!is.null(state_src$eta_lambda_hat)) state$eta_lambda_hat <- as.numeric(state_src$eta_lambda_hat)
    if (!is.null(state_src$eta_tau_hat)) state$eta_tau_hat <- as.numeric(state_src$eta_tau_hat)[1L]
    if (!is.null(state_src$eta_c_hat)) state$eta_c_hat <- as.numeric(state_src$eta_c_hat)[1L]
    if (!is.null(state_src$lambda)) state$eta_lambda_hat <- log(pmax(as.numeric(state_src$lambda), 1e-16))
    if (!is.null(state_src$tau)) state$eta_tau_hat <- log(max(as.numeric(state_src$tau)[1L], 1e-16))
    if (!is.null(state_src$c2)) state$eta_c_hat <- log(max(as.numeric(state_src$c2)[1L], 1e-16))
  }

  if (length(state$eta_lambda_hat) != p) .stopf("RHS MCMC init requires eta_lambda_hat of length p=%d.", p)
  if (!is.finite(state$eta_tau_hat) || !is.finite(state$eta_c_hat)) {
    .stopf("RHS MCMC init requires finite eta_tau_hat and eta_c_hat.")
  }
  state$eta_lambda_hat <- as.numeric(state$eta_lambda_hat)
  state$eta_tau_hat <- as.numeric(state$eta_tau_hat)[1L]
  state$eta_c_hat <- as.numeric(state$eta_c_hat)[1L]
  state
}

#' @keywords internal
.exal_mcmc_rhs_precisions <- function(state, p) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (is.null(state) || !identical(as.integer(state$p), as.integer(p))) {
    .stopf("RHS MCMC state is missing or has incompatible dimension.")
  }

  eta_lambda <- as.numeric(state$eta_lambda_hat)
  eta_tau <- as.numeric(state$eta_tau_hat)[1L]
  eta_c2 <- as.numeric(state$eta_c_hat)[1L]
  log_invV <- .logsumexp2(-eta_c2, -2 * (eta_tau + eta_lambda))
  prec <- .safe_exp(log_invV)
  prec <- pmax(as.numeric(prec), 1e-16)
  if (!isTRUE(state$shrink_intercept)) {
    prec[1L] <- as.numeric(state$intercept_prec %||% 1e-16)[1L]
  }
  prec
}

#' @keywords internal
.exal_mcmc_rhs_slice_update <- function(state, beta, beta_prior_obj, slice_cfg, freeze_tau = FALSE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (!identical(beta_prior_obj$type, "rhs")) {
    return(list(
      state = state,
      stats = list(
        tau = NA_real_,
        c2 = NA_real_,
        lambda_mean = NA_real_,
        lambda_min = NA_real_,
        lambda_max = NA_real_,
        tau_steps_out = 0L,
        tau_shrink = 0L,
        c2_steps_out = 0L,
        c2_shrink = 0L,
        lambda_steps_out_mean = 0,
        lambda_steps_out_max = 0L,
        lambda_shrink_mean = 0,
        lambda_shrink_max = 0L,
        tau_frozen = isTRUE(freeze_tau),
        global_block_mode = as.character(slice_cfg$rhs_global_block_update %||% "coordinate"),
        global_block_used = FALSE,
        global_block_steps_out = 0L,
        global_block_shrink = 0L,
        global_block_dir_tau = 0,
        global_block_dir_c2 = 0,
        global_block_transformed_passes = 0L,
        transformed_z1_steps_out = 0L,
        transformed_z1_shrink = 0L,
        transformed_z2_steps_out = 0L,
        transformed_z2_shrink = 0L
      )
    ))
  }

  max_steps_out <- as.integer(slice_cfg$max_steps_out %||% 100L)
  max_shrink <- as.integer(slice_cfg$max_shrink %||% 1000L)
  width_lambda <- as.numeric(slice_cfg$width_rhs_lambda %||% slice_cfg$width_lambda %||% 1.0)[1L]
  width_tau <- as.numeric(slice_cfg$width_rhs_tau %||% slice_cfg$width_tau %||% 1.0)[1L]
  width_c2 <- as.numeric(slice_cfg$width_rhs_c2 %||% slice_cfg$width_c2 %||% 1.0)[1L]
  width_tau_c2_block <- as.numeric(slice_cfg$width_rhs_tau_c2_block %||% 1.0)[1L]
   width_tau_c2_transformed_z1 <- as.numeric(slice_cfg$width_rhs_tau_c2_transformed_z1 %||% width_tau_c2_block)[1L]
   width_tau_c2_transformed_z2 <- as.numeric(slice_cfg$width_rhs_tau_c2_transformed_z2 %||% width_tau_c2_block)[1L]
   transformed_block_passes <- max(1L, as.integer(slice_cfg$rhs_transformed_block_passes %||% 1L))
  global_block_mode <- tolower(trimws(as.character(slice_cfg$rhs_global_block_update %||% "coordinate")))[1L]
  if (!global_block_mode %in% c("coordinate", "directional_tau_c2", "transformed_tau_c2_block")) {
    .stopf("Unsupported RHS global block update mode '%s'.", global_block_mode)
  }
  if (!is.finite(width_lambda) || width_lambda <= 0) .stopf("RHS slice width_lambda must be positive.")
  if (!is.finite(width_tau) || width_tau <= 0) .stopf("RHS slice width_tau must be positive.")
  if (!is.finite(width_c2) || width_c2 <= 0) .stopf("RHS slice width_c2 must be positive.")
  if (!is.finite(width_tau_c2_block) || width_tau_c2_block <= 0) .stopf("RHS slice width_tau_c2_block must be positive.")
  if (!is.finite(width_tau_c2_transformed_z1) || width_tau_c2_transformed_z1 <= 0) {
    .stopf("RHS slice width_rhs_tau_c2_transformed_z1 must be positive.")
  }
  if (!is.finite(width_tau_c2_transformed_z2) || width_tau_c2_transformed_z2 <= 0) {
    .stopf("RHS slice width_rhs_tau_c2_transformed_z2 must be positive.")
  }

  tau0 <- as.numeric(beta_prior_obj$hypers$tau0 %||% 1)[1L]
  nu <- as.numeric(beta_prior_obj$hypers$nu %||% 4)[1L]
  s <- as.numeric(beta_prior_obj$hypers$s %||% 1)[1L]
  eta_bounds <- beta_prior_obj$control$eta_bounds %||% list()
  b_lam <- as.numeric(eta_bounds$lambda %||% c(-40, 40))
  b_tau <- as.numeric(eta_bounds$tau %||% c(-40, 40))
  b_c2 <- as.numeric(eta_bounds$c2 %||% c(-40, 40))

  eta_lam <- as.numeric(state$eta_lambda_hat)
  eta_tau <- as.numeric(state$eta_tau_hat)[1L]
  eta_c2 <- as.numeric(state$eta_c_hat)[1L]
  beta2 <- as.numeric(beta)^2

  active_idx <- if (isTRUE(state$shrink_intercept)) {
    seq_along(beta2)
  } else if (length(beta2) >= 2L) {
    seq.int(2L, length(beta2))
  } else {
    integer(0)
  }
  lambda_steps <- integer(length(active_idx))
  lambda_shrink <- integer(length(active_idx))

  if (length(active_idx)) {
    for (ii in seq_along(active_idx)) {
      j <- active_idx[[ii]]
      out <- .exal_mcmc_slice_sample_1d(
        x0 = eta_lam[j],
        logf = function(eta_j) {
          eta_now <- eta_lam
          eta_now[j] <- eta_j
          rhs_obj_eta(
            eta_now, eta_tau, eta_c2, beta2,
            tau0 = tau0, nu = nu, s = s,
            shrink_intercept = state$shrink_intercept
          )
        },
        width = width_lambda,
        max_steps_out = max_steps_out,
        max_shrink = max_shrink,
        lower = b_lam[1L],
        upper = b_lam[2L]
      )
      eta_lam[j] <- out$x
      lambda_steps[ii] <- out$n_steps_out
      lambda_shrink[ii] <- out$n_shrink
    }
  }

  global_block_used <- FALSE
  global_block_steps_out <- 0L
  global_block_shrink <- 0L
  global_block_dir_tau <- 0
  global_block_dir_c2 <- 0
  global_block_transformed_passes <- 0L
  transformed_z1_steps_out <- 0L
  transformed_z1_shrink <- 0L
  transformed_z2_steps_out <- 0L
  transformed_z2_shrink <- 0L

  if (isTRUE(freeze_tau)) {
    tau_out <- list(x = eta_tau, n_steps_out = 0L, n_shrink = 0L)
  } else {
    if (identical(global_block_mode, "directional_tau_c2")) {
      x0_block <- c(eta_tau, eta_c2)
      dir_seed <- stats::rnorm(2L)
      dir_norm <- sqrt(sum(dir_seed * dir_seed))
      if (!is.finite(dir_norm) || dir_norm <= 1e-12) dir_seed <- c(1, 0)
      dir_norm <- sqrt(sum(dir_seed * dir_seed))
      dir_unit <- dir_seed / dir_norm
      dir_vec <- c(width_tau, width_c2) * dir_unit
      line_bounds <- .exal_mcmc_slice_line_bounds(
        x0 = x0_block,
        direction = dir_vec,
        lower = c(b_tau[1L], b_c2[1L]),
        upper = c(b_tau[2L], b_c2[2L])
      )
      if (is.finite(line_bounds$lower) && is.finite(line_bounds$upper) &&
          (line_bounds$upper - line_bounds$lower) > 1e-10) {
        block_out <- .exal_mcmc_slice_sample_1d(
          x0 = 0,
          logf = function(z) {
            rhs_obj_eta(
              eta_lam,
              x0_block[1L] + z * dir_vec[1L],
              x0_block[2L] + z * dir_vec[2L],
              beta2,
              tau0 = tau0, nu = nu, s = s,
              shrink_intercept = state$shrink_intercept
            )
          },
          width = width_tau_c2_block,
          max_steps_out = max_steps_out,
          max_shrink = max_shrink,
          lower = line_bounds$lower,
          upper = line_bounds$upper
        )
        eta_tau <- x0_block[1L] + block_out$x * dir_vec[1L]
        eta_c2 <- x0_block[2L] + block_out$x * dir_vec[2L]
        tau_out <- list(x = eta_tau, n_steps_out = block_out$n_steps_out, n_shrink = block_out$n_shrink)
        c2_out <- list(x = eta_c2, n_steps_out = block_out$n_steps_out, n_shrink = block_out$n_shrink)
        global_block_used <- TRUE
        global_block_steps_out <- block_out$n_steps_out
        global_block_shrink <- block_out$n_shrink
        global_block_dir_tau <- dir_vec[1L]
        global_block_dir_c2 <- dir_vec[2L]
      } else {
        tau_out <- .exal_mcmc_slice_sample_1d(
          x0 = eta_tau,
          logf = function(etau) {
            rhs_obj_eta(
              eta_lam, etau, eta_c2, beta2,
              tau0 = tau0, nu = nu, s = s,
              shrink_intercept = state$shrink_intercept
            )
          },
          width = width_tau,
          max_steps_out = max_steps_out,
          max_shrink = max_shrink,
          lower = b_tau[1L],
          upper = b_tau[2L]
        )
        eta_tau <- tau_out$x
      }
    } else if (identical(global_block_mode, "transformed_tau_c2_block")) {
      inv_sqrt2 <- 1 / sqrt(2)
      any_block_used <- FALSE

      for (pass_idx in seq_len(transformed_block_passes)) {
        x0_block <- c(eta_tau, eta_c2)
        dir1 <- c(inv_sqrt2, inv_sqrt2)
        line1 <- .exal_mcmc_slice_line_bounds(
          x0 = x0_block,
          direction = dir1,
          lower = c(b_tau[1L], b_c2[1L]),
          upper = c(b_tau[2L], b_c2[2L])
        )
        if (is.finite(line1$lower) && is.finite(line1$upper) &&
            (line1$upper - line1$lower) > 1e-10) {
          out1 <- .exal_mcmc_slice_sample_1d(
            x0 = 0,
            logf = function(z) {
              rhs_obj_eta(
                eta_lam,
                x0_block[1L] + z * dir1[1L],
                x0_block[2L] + z * dir1[2L],
                beta2,
                tau0 = tau0, nu = nu, s = s,
                shrink_intercept = state$shrink_intercept
              )
            },
            width = width_tau_c2_transformed_z1,
            max_steps_out = max_steps_out,
            max_shrink = max_shrink,
            lower = line1$lower,
            upper = line1$upper
          )
          eta_tau <- x0_block[1L] + out1$x * dir1[1L]
          eta_c2 <- x0_block[2L] + out1$x * dir1[2L]
          transformed_z1_steps_out <- transformed_z1_steps_out + out1$n_steps_out
          transformed_z1_shrink <- transformed_z1_shrink + out1$n_shrink
          any_block_used <- TRUE
          global_block_transformed_passes <- global_block_transformed_passes + 1L
        }

        x1_block <- c(eta_tau, eta_c2)
        dir2 <- c(inv_sqrt2, -inv_sqrt2)
        line2 <- .exal_mcmc_slice_line_bounds(
          x0 = x1_block,
          direction = dir2,
          lower = c(b_tau[1L], b_c2[1L]),
          upper = c(b_tau[2L], b_c2[2L])
        )
        if (is.finite(line2$lower) && is.finite(line2$upper) &&
            (line2$upper - line2$lower) > 1e-10) {
          out2 <- .exal_mcmc_slice_sample_1d(
            x0 = 0,
            logf = function(z) {
              rhs_obj_eta(
                eta_lam,
                x1_block[1L] + z * dir2[1L],
                x1_block[2L] + z * dir2[2L],
                beta2,
                tau0 = tau0, nu = nu, s = s,
                shrink_intercept = state$shrink_intercept
              )
            },
            width = width_tau_c2_transformed_z2,
            max_steps_out = max_steps_out,
            max_shrink = max_shrink,
            lower = line2$lower,
            upper = line2$upper
          )
          eta_tau <- x1_block[1L] + out2$x * dir2[1L]
          eta_c2 <- x1_block[2L] + out2$x * dir2[2L]
          transformed_z2_steps_out <- transformed_z2_steps_out + out2$n_steps_out
          transformed_z2_shrink <- transformed_z2_shrink + out2$n_shrink
          any_block_used <- TRUE
          global_block_transformed_passes <- global_block_transformed_passes + 1L
        }
      }

      if (isTRUE(any_block_used)) {
        global_block_used <- TRUE
        global_block_steps_out <- transformed_z1_steps_out + transformed_z2_steps_out
        global_block_shrink <- transformed_z1_shrink + transformed_z2_shrink
        tau_out <- list(x = eta_tau, n_steps_out = global_block_steps_out, n_shrink = global_block_shrink)
        c2_out <- list(x = eta_c2, n_steps_out = global_block_steps_out, n_shrink = global_block_shrink)
      } else {
        tau_out <- .exal_mcmc_slice_sample_1d(
          x0 = eta_tau,
          logf = function(etau) {
            rhs_obj_eta(
              eta_lam, etau, eta_c2, beta2,
              tau0 = tau0, nu = nu, s = s,
              shrink_intercept = state$shrink_intercept
            )
          },
          width = width_tau,
          max_steps_out = max_steps_out,
          max_shrink = max_shrink,
          lower = b_tau[1L],
          upper = b_tau[2L]
        )
        eta_tau <- tau_out$x
      }
    } else {
      tau_out <- .exal_mcmc_slice_sample_1d(
        x0 = eta_tau,
        logf = function(etau) {
          rhs_obj_eta(
            eta_lam, etau, eta_c2, beta2,
            tau0 = tau0, nu = nu, s = s,
            shrink_intercept = state$shrink_intercept
          )
        },
        width = width_tau,
        max_steps_out = max_steps_out,
        max_shrink = max_shrink,
        lower = b_tau[1L],
        upper = b_tau[2L]
      )
      eta_tau <- tau_out$x
    }
  }

  if (!exists("c2_out", inherits = FALSE)) {
    c2_out <- .exal_mcmc_slice_sample_1d(
      x0 = eta_c2,
      logf = function(ec2) {
        rhs_obj_eta(
          eta_lam, eta_tau, ec2, beta2,
          tau0 = tau0, nu = nu, s = s,
          shrink_intercept = state$shrink_intercept
        )
      },
      width = width_c2,
      max_steps_out = max_steps_out,
      max_shrink = max_shrink,
      lower = b_c2[1L],
      upper = b_c2[2L]
    )
    eta_c2 <- c2_out$x
  }

  state$eta_lambda_hat <- eta_lam
  state$eta_tau_hat <- eta_tau
  state$eta_c_hat <- eta_c2

  lambda_now <- exp(eta_lam)
  lambda_active <- if (length(active_idx)) lambda_now[active_idx] else numeric(0)

  list(
    state = state,
    stats = list(
      tau = .safe_exp(eta_tau),
      c2 = .safe_exp(eta_c2),
      lambda_mean = if (length(lambda_active)) mean(lambda_active) else NA_real_,
      lambda_min = if (length(lambda_active)) min(lambda_active) else NA_real_,
      lambda_max = if (length(lambda_active)) max(lambda_active) else NA_real_,
      tau_steps_out = tau_out$n_steps_out,
      tau_shrink = tau_out$n_shrink,
      c2_steps_out = c2_out$n_steps_out,
      c2_shrink = c2_out$n_shrink,
      lambda_steps_out_mean = if (length(lambda_steps)) mean(lambda_steps) else 0,
      lambda_steps_out_max = if (length(lambda_steps)) max(lambda_steps) else 0L,
      lambda_shrink_mean = if (length(lambda_shrink)) mean(lambda_shrink) else 0,
      lambda_shrink_max = if (length(lambda_shrink)) max(lambda_shrink) else 0L,
      tau_frozen = isTRUE(freeze_tau),
      global_block_mode = global_block_mode,
      global_block_used = isTRUE(global_block_used),
      global_block_steps_out = as.integer(global_block_steps_out),
      global_block_shrink = as.integer(global_block_shrink),
      global_block_dir_tau = as.numeric(global_block_dir_tau),
      global_block_dir_c2 = as.numeric(global_block_dir_c2),
      global_block_transformed_passes = as.integer(global_block_transformed_passes),
      transformed_z1_steps_out = as.integer(transformed_z1_steps_out),
      transformed_z1_shrink = as.integer(transformed_z1_shrink),
      transformed_z2_steps_out = as.integer(transformed_z2_steps_out),
      transformed_z2_shrink = as.integer(transformed_z2_shrink)
    )
  )
}

#' @keywords internal
.exal_mcmc_rhs_ns_prepare_state <- function(beta_prior_obj, p, init = list(), vb_warm = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (!identical(beta_prior_obj$type, "rhs_ns")) return(NULL)

  state <- beta_prior_obj$init(p)
  ns_state_init <- init$rhs_ns_state %||% init$rhs_state %||% init$beta_prior_state %||% NULL
  vb_state <- vb_warm$beta_prior$state %||% NULL
  state_src <- ns_state_init %||% vb_state

  if (!is.null(state_src) && is.list(state_src)) {
    for (nm in intersect(names(state_src), names(state))) {
      state[[nm]] <- state_src[[nm]]
    }
    if (!is.null(state_src$lambda)) state$lambda2 <- pmax(as.numeric(state_src$lambda)^2, 1e-16)
    if (!is.null(state_src$lambda2)) state$lambda2 <- pmax(as.numeric(state_src$lambda2), 1e-16)
    if (!is.null(state_src$nu)) state$nu <- pmax(as.numeric(state_src$nu), 1e-16)
    if (!is.null(state_src$tau)) state$tau2 <- max(as.numeric(state_src$tau)[1L]^2, 1e-16)
    if (!is.null(state_src$tau2)) state$tau2 <- max(as.numeric(state_src$tau2)[1L], 1e-16)
    if (!is.null(state_src$xi)) state$xi <- max(as.numeric(state_src$xi)[1L], 1e-16)
    if (!is.null(state_src$zeta2)) state$zeta2 <- max(as.numeric(state_src$zeta2)[1L], 1e-16)
    if (!is.null(state_src$c2)) state$zeta2 <- max(as.numeric(state_src$c2)[1L], 1e-16)
    if (!is.null(state_src$zeta2_fixed)) state$zeta2_fixed <- as.numeric(state_src$zeta2_fixed)[1L]
    if (!is.null(state_src$zeta2_is_fixed)) state$zeta2_is_fixed <- isTRUE(state_src$zeta2_is_fixed)
  }

  if (length(state$lambda2) != p) .stopf("RHS_NS MCMC init requires lambda2 of length p=%d.", p)
  if (length(state$nu) != p) .stopf("RHS_NS MCMC init requires nu of length p=%d.", p)
  state$lambda2 <- pmax(as.numeric(state$lambda2), 1e-16)
  state$nu <- pmax(as.numeric(state$nu), 1e-16)
  state$tau2 <- max(as.numeric(state$tau2)[1L], 1e-16)
  state$xi <- max(as.numeric(state$xi)[1L], 1e-16)
  if (isTRUE(state$zeta2_is_fixed)) {
    state$zeta2 <- max(as.numeric(state$zeta2_fixed)[1L], 1e-16)
  } else {
    state$zeta2 <- max(as.numeric(state$zeta2)[1L], 1e-16)
  }
  state
}

#' @keywords internal
.exal_mcmc_rhs_ns_precisions <- function(state, p) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (is.null(state) || !identical(as.integer(state$p), as.integer(p))) {
    .stopf("RHS_NS MCMC state is missing or has incompatible dimension.")
  }

  lambda2 <- pmax(as.numeric(state$lambda2), 1e-16)
  tau2 <- max(as.numeric(state$tau2)[1L], 1e-16)
  zeta2 <- if (isTRUE(state$zeta2_is_fixed)) {
    max(as.numeric(state$zeta2_fixed)[1L], 1e-16)
  } else {
    max(as.numeric(state$zeta2)[1L], 1e-16)
  }

  prec <- 1.0 / (tau2 * lambda2) + 1.0 / zeta2
  prec <- pmax(as.numeric(prec), 1e-16)
  if (!isTRUE(state$shrink_intercept)) {
    prec[1L] <- as.numeric(state$intercept_prec %||% 1e-16)[1L]
  }
  prec
}

#' @keywords internal
.exal_mcmc_rhs_ns_gibbs_update <- function(state, beta, beta_prior_obj, freeze_tau = FALSE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (!identical(beta_prior_obj$type, "rhs_ns")) {
    return(list(
      state = state,
      stats = list(
        tau = NA_real_,
        c2 = NA_real_,
        lambda_mean = NA_real_,
        lambda_min = NA_real_,
        lambda_max = NA_real_,
        tau_steps_out = 0L,
        tau_shrink = 0L,
        c2_steps_out = 0L,
        c2_shrink = 0L,
        lambda_steps_out_mean = 0,
        lambda_steps_out_max = 0L,
        lambda_shrink_mean = 0,
        lambda_shrink_max = 0L,
        tau_frozen = isTRUE(freeze_tau),
        global_block_mode = "gibbs",
        global_block_used = FALSE,
        global_block_steps_out = 0L,
        global_block_shrink = 0L,
        global_block_dir_tau = 0,
        global_block_dir_c2 = 0,
        global_block_transformed_passes = 0L,
        transformed_z1_steps_out = 0L,
        transformed_z1_shrink = 0L,
        transformed_z2_steps_out = 0L,
        transformed_z2_shrink = 0L
      )
    ))
  }

  p <- as.integer(state$p)
  beta <- as.numeric(beta)
  if (length(beta) != p) .stopf("RHS_NS Gibbs update: beta length mismatch.")

  tau0 <- as.numeric(beta_prior_obj$hypers$tau0 %||% 1.0)[1L]
  a_zeta0 <- as.numeric(beta_prior_obj$hypers$a_zeta %||% 2.0)[1L]
  b_zeta0 <- as.numeric(beta_prior_obj$hypers$b_zeta %||% 1.0)[1L]

  lambda2 <- pmax(as.numeric(state$lambda2), 1e-16)
  nu <- pmax(as.numeric(state$nu), 1e-16)
  tau2 <- max(as.numeric(state$tau2)[1L], 1e-16)
  xi <- max(as.numeric(state$xi)[1L], 1e-16)
  zeta2 <- if (isTRUE(state$zeta2_is_fixed)) {
    max(as.numeric(state$zeta2_fixed)[1L], 1e-16)
  } else {
    max(as.numeric(state$zeta2)[1L], 1e-16)
  }

  active_idx <- if (isTRUE(state$shrink_intercept)) {
    seq_len(p)
  } else if (p >= 2L) {
    seq.int(2L, p)
  } else {
    integer(0)
  }
  beta2 <- beta^2

  if (length(active_idx)) {
    for (j in active_idx) {
      rate_lambda <- 0.5 * beta2[j] / tau2 + 1.0 / nu[j]
      rate_lambda <- max(as.numeric(rate_lambda), 1e-16)
      lambda2[j] <- 1.0 / stats::rgamma(1L, shape = 1.0, rate = rate_lambda)
      lambda2[j] <- max(lambda2[j], 1e-16)

      rate_nu <- 1.0 + 1.0 / lambda2[j]
      rate_nu <- max(as.numeric(rate_nu), 1e-16)
      nu[j] <- 1.0 / stats::rgamma(1L, shape = 1.0, rate = rate_nu)
      nu[j] <- max(nu[j], 1e-16)
    }

    if (!isTRUE(freeze_tau)) {
      shape_tau <- (length(active_idx) + 1.0) / 2.0
      rate_tau <- 0.5 * sum(beta2[active_idx] / lambda2[active_idx]) + 1.0 / xi
      rate_tau <- max(as.numeric(rate_tau), 1e-16)
      tau2 <- 1.0 / stats::rgamma(1L, shape = shape_tau, rate = rate_tau)
      tau2 <- max(tau2, 1e-16)

      rate_xi <- (1.0 / (tau0^2)) + 1.0 / tau2
      rate_xi <- max(as.numeric(rate_xi), 1e-16)
      xi <- 1.0 / stats::rgamma(1L, shape = 1.0, rate = rate_xi)
      xi <- max(xi, 1e-16)
    }

    if (!isTRUE(state$zeta2_is_fixed)) {
      shape_zeta <- a_zeta0 + length(active_idx) / 2.0
      rate_zeta <- b_zeta0 + 0.5 * sum(beta2[active_idx])
      rate_zeta <- max(as.numeric(rate_zeta), 1e-16)
      zeta2 <- 1.0 / stats::rgamma(1L, shape = shape_zeta, rate = rate_zeta)
      zeta2 <- max(zeta2, 1e-16)
    }
  }

  state$lambda2 <- lambda2
  state$nu <- nu
  state$tau2 <- tau2
  state$xi <- xi
  state$zeta2 <- zeta2

  # keep prior-object moments aligned for diagnostics/warm restarts
  state$E_inv_lambda2 <- 1.0 / pmax(lambda2, 1e-16)
  state$E_inv_nu <- 1.0 / pmax(nu, 1e-16)
  state$E_inv_tau2 <- 1.0 / max(tau2, 1e-16)
  state$E_inv_xi <- 1.0 / max(xi, 1e-16)
  state$E_inv_zeta2 <- 1.0 / max(zeta2, 1e-16)

  lambda_now <- sqrt(lambda2)
  lambda_active <- if (length(active_idx)) lambda_now[active_idx] else numeric(0)
  list(
    state = state,
    stats = list(
      tau = sqrt(tau2),
      c2 = zeta2,
      lambda_mean = if (length(lambda_active)) mean(lambda_active) else NA_real_,
      lambda_min = if (length(lambda_active)) min(lambda_active) else NA_real_,
      lambda_max = if (length(lambda_active)) max(lambda_active) else NA_real_,
      tau_steps_out = 0L,
      tau_shrink = 0L,
      c2_steps_out = 0L,
      c2_shrink = 0L,
      lambda_steps_out_mean = 0,
      lambda_steps_out_max = 0L,
      lambda_shrink_mean = 0,
      lambda_shrink_max = 0L,
      tau_frozen = isTRUE(freeze_tau),
      global_block_mode = "gibbs",
      global_block_used = FALSE,
      global_block_steps_out = 0L,
      global_block_shrink = 0L,
      global_block_dir_tau = 0,
      global_block_dir_c2 = 0,
      global_block_transformed_passes = 0L,
      transformed_z1_steps_out = 0L,
      transformed_z1_shrink = 0L,
      transformed_z2_steps_out = 0L,
      transformed_z2_shrink = 0L
    )
  )
}

#' Fit exAL regression with MCMC
#'
#' `mcmc_control$precision_beta` optionally enables code-level repair for the
#' Gaussian beta precision draw. The recommended preset is
#' `exal_make_precision_beta_control("ladder_v2")`; the stronger fallback is
#' `exal_make_precision_beta_control("eigen_v1")`.
#' The rest of the advanced warmup blocks can be built with
#' [exal_make_mcmc_control()], [exal_make_mcmc_sigmagam_control()],
#' [exal_make_mcmc_theta_control()], [exal_make_mcmc_latent_v_control()],
#' [exal_make_mcmc_latent_s_control()], and
#' [exal_make_mcmc_rhs_control()].
#'
#' @param y Response vector.
#' @param X Design matrix.
#' @param p0 Target quantile.
#' @param gamma_bounds Length-2 numeric vector with lower/upper bounds for
#'   `gamma`.
#' @param mcmc_control Named list of MCMC controls. `mcmc_control$precision_beta`
#'   accepts either a preset string such as `"ladder_v2"` / `"eigen_v1"` or a
#'   fully specified list produced by [exal_make_precision_beta_control()].
#'   For the full advanced block surface, prefer [exal_make_mcmc_control()].
#' @param n_burn,n_mcmc,thin Optional scalar overrides for the retained MCMC
#'   control counts.
#' @param verbose Optional logical override for verbose progress output.
#' @param likelihood_family One of `"exal"` or `"al"`.
#' @param al_fixed_gamma Optional fixed gamma value for the AL special case.
#' @param init Initial values list.
#' @param prior_gamma Optional normal prior control list for `gamma`.
#' @param prior_gamma_mu0,prior_gamma_s20 Optional scalar shorthands for
#'   `prior_gamma`.
#' @param log_prior_gamma Optional custom log prior for `gamma`.
#' @param prior_sigma Optional inverse-gamma prior control list for `sigma`.
#' @param a_sigma,b_sigma Optional scalar shorthands for `prior_sigma`.
#' @param beta_prior_obj Beta prior object, typically created with the package's
#'   beta-prior constructors such as `exal_make_beta_prior()`.
#' @param ... Reserved for forward compatibility.
#'
#' @return An `exal_mcmc` fit object.
#' @export
exal_mcmc_fit <- function(y, X, p0, gamma_bounds,
                          mcmc_control = NULL,
                          n_burn = NULL, n_mcmc = NULL, thin = NULL,
                          verbose = NULL,
                          likelihood_family = c("exal", "al"),
                          al_fixed_gamma = NULL,
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

  `%||%` <- function(a, b) if (is.null(a)) b else a
  likelihood_family <- match.arg(tolower(as.character(likelihood_family)[1L]), c("exal", "al"))
  is_al <- identical(likelihood_family, "al")

  assert_matrix(X, "X")
  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")

  if (!is.numeric(gamma_bounds) || length(gamma_bounds) != 2L) {
    .stopf("gamma_bounds must be a numeric vector of length 2.")
  }
  gamma_bounds <- as.numeric(gamma_bounds)
  if (!all(is.finite(gamma_bounds)) || gamma_bounds[1] >= gamma_bounds[2]) {
    .stopf("gamma_bounds must be finite with lower < upper.")
  }
  if (!is.list(init)) .stopf("init must be a list.")

  if (is.null(mcmc_control)) mcmc_control <- list()
  if (!is.list(mcmc_control)) .stopf("mcmc_control must be a list.")
  if (!is.null(n_burn))  mcmc_control$n_burn  <- as.integer(n_burn)[1L]
  if (!is.null(n_mcmc))  mcmc_control$n_mcmc  <- as.integer(n_mcmc)[1L]
  if (!is.null(thin))    mcmc_control$thin    <- as.integer(thin)[1L]
  if (!is.null(verbose)) mcmc_control$verbose <- isTRUE(verbose)

  n_burn <- max(0L, as.integer(mcmc_control$n_burn %||% 2000L))
  n_keep <- max(1L, as.integer(mcmc_control$n_mcmc %||% 1500L))
  thin <- max(1L, as.integer(mcmc_control$thin %||% 1L))
  verbose <- isTRUE(mcmc_control$verbose %||% FALSE)
  progress_every <- max(1L, as.integer(mcmc_control$progress_every %||% 100L))
  normalize_seed <- function(seed) {
    if (is.null(seed)) return(NULL)
    s <- suppressWarnings(as.integer(seed)[1L])
    if (!is.finite(s) || is.na(s)) return(NULL)
    # Keep seed in valid R integer RNG range and avoid zero.
    s <- abs(s %% 2147483647L)
    if (s == 0L) s <- 1L
    s
  }
  rng_seed <- normalize_seed(mcmc_control$rng_seed %||% mcmc_control$seed %||% NULL)
  vb_warm_start_seed <- normalize_seed(
    mcmc_control$vb_warm_start_seed %||%
      if (!is.null(rng_seed)) rng_seed + 104729L else NULL
  )
  init_from_vb <- isTRUE(mcmc_control$init_from_vb %||% FALSE)
  store_latent_draws <- isTRUE(mcmc_control$store_latent_draws %||% FALSE)
  store_rhs_draws <- isTRUE(mcmc_control$store_rhs_draws %||% FALSE)
  sigmagam_warm_cfg <- mcmc_control$sigmagam %||% list()
  sigmagam_freeze_burnin_iters <- max(0L, as.integer(
    sigmagam_warm_cfg$freeze_burnin_iters %||%
      sigmagam_warm_cfg$freeze_sigmagam_burnin_iters %||%
      0L
  ))
  sigmagam_freeze_only_during_burn <- if (is.null(sigmagam_warm_cfg$freeze_only_during_burn)) TRUE else isTRUE(sigmagam_warm_cfg$freeze_only_during_burn)
  sigmagam_force_after_warmup <- if (is.null(sigmagam_warm_cfg$force_after_warmup)) TRUE else isTRUE(sigmagam_warm_cfg$force_after_warmup)
  sigmagam_delay_adapt_until_after_warmup <- if (is.null(sigmagam_warm_cfg$delay_adapt_until_after_warmup)) TRUE else isTRUE(sigmagam_warm_cfg$delay_adapt_until_after_warmup)
  sigmagam_delay_laplace_refresh_until_after_warmup <- if (is.null(sigmagam_warm_cfg$delay_laplace_refresh_until_after_warmup)) TRUE else isTRUE(sigmagam_warm_cfg$delay_laplace_refresh_until_after_warmup)
  theta_cfg <- mcmc_control$theta %||% mcmc_control$beta %||% list()
  theta_enabled <- isTRUE(
    theta_cfg$enabled %||%
      (
        as.integer(theta_cfg$freeze_burnin_iters %||% 0L) > 0L ||
          (
            as.integer(theta_cfg$sparse_update_every %||% 1L) > 1L &&
              as.integer(theta_cfg$sparse_update_until_iter %||% 0L) > 0L
          )
      )
  )
  theta_freeze_burnin_iters <- max(0L, as.integer(
    theta_cfg$freeze_burnin_iters %||%
      theta_cfg$freeze_theta_burnin_iters %||%
      theta_cfg$freeze_beta_burnin_iters %||%
      0L
  ))
  theta_freeze_only_during_burn <- if (is.null(theta_cfg$freeze_only_during_burn)) TRUE else isTRUE(theta_cfg$freeze_only_during_burn)
  theta_sparse_update_every <- max(1L, as.integer(
    theta_cfg$sparse_update_every %||%
      theta_cfg$update_every_warmup %||%
      1L
  ))
  theta_sparse_update_until_iter <- max(0L, as.integer(
    theta_cfg$sparse_update_until_iter %||%
      theta_cfg$update_every_warmup_iters %||%
      0L
  ))
  theta_force_first_postwarmup_update <- if (is.null(theta_cfg$force_first_postwarmup_update)) TRUE else isTRUE(theta_cfg$force_first_postwarmup_update)
  theta_trace_enabled <- if (is.null(theta_cfg$trace)) TRUE else isTRUE(theta_cfg$trace)
  latent_v_cfg <- mcmc_control$latent_v %||% list()
  latent_v_enabled <- isTRUE(
    latent_v_cfg$enabled %||%
      (
        as.integer(latent_v_cfg$freeze_burnin_iters %||% 0L) > 0L ||
          (
            as.integer(latent_v_cfg$sparse_update_every %||% 1L) > 1L &&
              as.integer(latent_v_cfg$sparse_update_until_iter %||% 0L) > 0L
          )
      )
  )
  latent_v_freeze_burnin_iters <- max(0L, as.integer(
    latent_v_cfg$freeze_burnin_iters %||%
      latent_v_cfg$freeze_latent_v_burnin_iters %||%
      0L
  ))
  latent_v_freeze_only_during_burn <- if (is.null(latent_v_cfg$freeze_only_during_burn)) TRUE else isTRUE(latent_v_cfg$freeze_only_during_burn)
  latent_v_sparse_update_every <- max(1L, as.integer(
    latent_v_cfg$sparse_update_every %||%
      latent_v_cfg$update_every_warmup %||%
      1L
  ))
  latent_v_sparse_update_until_iter <- max(0L, as.integer(
    latent_v_cfg$sparse_update_until_iter %||%
      latent_v_cfg$update_every_warmup_iters %||%
      0L
  ))
  latent_v_force_first_postwarmup_update <- if (is.null(latent_v_cfg$force_first_postwarmup_update)) TRUE else isTRUE(latent_v_cfg$force_first_postwarmup_update)
  latent_v_rescue_on_invalid <- if (is.null(latent_v_cfg$rescue_on_invalid)) FALSE else isTRUE(latent_v_cfg$rescue_on_invalid)
  latent_v_rescue_strategy <- tolower(trimws(as.character(latent_v_cfg$rescue_strategy %||% "previous_state")))[1L]
  if (!latent_v_rescue_strategy %in% c("previous_state")) {
    .stopf(
      "Unsupported mcmc_control$latent_v$rescue_strategy '%s'. Expected 'previous_state'.",
      latent_v_rescue_strategy
    )
  }
  latent_v_rescue_max_consecutive <- max(0L, as.integer(latent_v_cfg$rescue_max_consecutive %||% 0L))
  latent_v_rescue_burn_only <- if (is.null(latent_v_cfg$rescue_burn_only)) FALSE else isTRUE(latent_v_cfg$rescue_burn_only)
  latent_v_rescue_force_retry_next_iter <- if (is.null(latent_v_cfg$rescue_force_retry_next_iter)) TRUE else isTRUE(latent_v_cfg$rescue_force_retry_next_iter)
  latent_v_record_rescue_trace <- if (is.null(latent_v_cfg$record_rescue_trace)) TRUE else isTRUE(latent_v_cfg$record_rescue_trace)
  latent_v_trace_enabled <- if (is.null(latent_v_cfg$trace)) TRUE else isTRUE(latent_v_cfg$trace)
  latent_s_cfg <- mcmc_control$latent_s %||% list()
  latent_s_enabled <- isTRUE(
    latent_s_cfg$enabled %||%
      (
        as.integer(latent_s_cfg$freeze_burnin_iters %||% 0L) > 0L ||
          (
            as.integer(latent_s_cfg$sparse_update_every %||% 1L) > 1L &&
              as.integer(latent_s_cfg$sparse_update_until_iter %||% 0L) > 0L
          )
      )
  )
  latent_s_freeze_burnin_iters <- max(0L, as.integer(
    latent_s_cfg$freeze_burnin_iters %||%
      latent_s_cfg$freeze_latent_s_burnin_iters %||%
      0L
  ))
  latent_s_freeze_only_during_burn <- if (is.null(latent_s_cfg$freeze_only_during_burn)) TRUE else isTRUE(latent_s_cfg$freeze_only_during_burn)
  latent_s_sparse_update_every <- max(1L, as.integer(
    latent_s_cfg$sparse_update_every %||%
      latent_s_cfg$update_every_warmup %||%
      1L
  ))
  latent_s_sparse_update_until_iter <- max(0L, as.integer(
    latent_s_cfg$sparse_update_until_iter %||%
      latent_s_cfg$update_every_warmup_iters %||%
      0L
  ))
  latent_s_force_first_postwarmup_update <- if (is.null(latent_s_cfg$force_first_postwarmup_update)) TRUE else isTRUE(latent_s_cfg$force_first_postwarmup_update)
  latent_s_trace_enabled <- if (is.null(latent_s_cfg$trace)) TRUE else isTRUE(latent_s_cfg$trace)
  rhs_warm_cfg <- mcmc_control$rhs %||% list()
  rhs_freeze_tau_iters <- max(0L, as.integer(rhs_warm_cfg$freeze_tau_burnin_iters %||% rhs_warm_cfg$freeze_tau_iters %||% 0L))
  rhs_freeze_tau_only_during_burn <- if (is.null(rhs_warm_cfg$freeze_tau_only_during_burn)) TRUE else isTRUE(rhs_warm_cfg$freeze_tau_only_during_burn)
  width_adapt_cfg <- rhs_warm_cfg$width_adapt %||% list()
  width_adapt_enabled <- isTRUE(width_adapt_cfg$enabled %||% FALSE)
  width_adapt_warmup_iters <- max(0L, as.integer(width_adapt_cfg$warmup_iters %||% min(200L, n_burn)))
  width_adapt_only_during_burn <- if (is.null(width_adapt_cfg$only_during_burn)) TRUE else isTRUE(width_adapt_cfg$only_during_burn)
  width_adapt_target_score_low <- as.numeric(width_adapt_cfg$target_score_low %||% -1.5)[1L]
  width_adapt_target_score_high <- as.numeric(width_adapt_cfg$target_score_high %||% 1.5)[1L]
  width_adapt_step_size <- as.numeric(width_adapt_cfg$step_size %||% 0.05)[1L]
  width_adapt_min <- as.numeric(width_adapt_cfg$width_min %||% 0.02)[1L]
  width_adapt_max <- as.numeric(width_adapt_cfg$width_max %||% 2.5)[1L]
  multi_start_cfg <- mcmc_control$multi_start %||% list()
  multi_start_enabled <- isTRUE(multi_start_cfg$enabled %||% FALSE)
  multi_start_internal <- isTRUE(mcmc_control[["_multi_start_internal"]] %||% FALSE)

  slice_cfg <- mcmc_control$slice %||% list()
  gamma_slice_width <- as.numeric(slice_cfg$width_gamma %||% 1.0)[1L]
  gamma_slice_max_steps_out <- as.integer(slice_cfg$max_steps_out %||% 100L)
  gamma_slice_max_shrink <- as.integer(slice_cfg$max_shrink %||% 1000L)
  core_extra_passes <- max(0L, as.integer(slice_cfg$core_extra_passes %||% 0L))
  core_update_mode <- tolower(trimws(as.character(slice_cfg$core_update_mode %||% "sigma_then_gamma")))[1L]

  transform_cfg <- mcmc_control$transforms %||% mcmc_control$transform %||% list()
  use_log_sigma <- isTRUE(transform_cfg$use_log_sigma %||% transform_cfg$use_transformed_sigma %||% FALSE)
  sigma_eta_bounds <- transform_cfg$sigma_eta_bounds %||% c(-20, 20)
  sigma_eta_bounds <- as.numeric(sigma_eta_bounds)
  if (length(sigma_eta_bounds) != 2L || any(!is.finite(sigma_eta_bounds))) {
    sigma_eta_bounds <- c(-Inf, Inf)
  }
  if (is.finite(sigma_eta_bounds[1L]) && is.finite(sigma_eta_bounds[2L]) &&
      sigma_eta_bounds[1L] >= sigma_eta_bounds[2L]) {
    .stopf("mcmc_control$transforms$sigma_eta_bounds must have lower < upper.")
  }
  sigma_slice_width <- as.numeric(slice_cfg$width_sigma %||% slice_cfg$width_log_sigma %||% 0.35)[1L]
  sigma_slice_max_steps_out <- as.integer(slice_cfg$max_steps_out_sigma %||% slice_cfg$max_steps_out %||% 100L)
  sigma_slice_max_shrink <- as.integer(slice_cfg$max_shrink_sigma %||% slice_cfg$max_shrink %||% 1000L)
  conditioning_cfg <- mcmc_control$conditioning %||% list()
  conditioning_mode <- tolower(trimws(as.character(conditioning_cfg$mode %||% conditioning_cfg$type %||% "none")))[1L]
  if (conditioning_mode %in% c("scale_only", "diag_standardize")) conditioning_mode <- "diag_scale"
  if (conditioning_mode %in% c("qr", "whiten", "qr_precondition")) conditioning_mode <- "qr_whiten"
  conditioning_scale_metric <- tolower(trimws(as.character(conditioning_cfg$scale_metric %||% "sd")))[1L]
  conditioning_scale_floor <- as.numeric(conditioning_cfg$scale_floor %||% 1e-8)[1L]
  conditioning_intercept_column <- suppressWarnings(as.integer(conditioning_cfg$intercept_column %||% 1L))[1L]
  conditioning_constant_tol <- as.numeric(conditioning_cfg$constant_tol %||% 1e-12)[1L]
  conditioning_gram_ridge <- as.numeric(conditioning_cfg$gram_ridge %||% 1e-8)[1L]
  precision_beta_cfg <- .exal_normalize_mcmc_precision_beta_cfg(
    mcmc_control$precision_beta %||% mcmc_control$precision %||% list()
  )
  precision_beta_preset <- as.character(precision_beta_cfg$preset %||% "off")[1L]
  precision_beta_enabled <- isTRUE(precision_beta_cfg$enabled %||% FALSE)
  precision_beta_symmetrize <- isTRUE(precision_beta_cfg$symmetrize %||% TRUE)
  precision_beta_jitter_ladder <- as.numeric(precision_beta_cfg$jitter_ladder %||% c(0, 1e-10, 1e-8, 1e-6, 1e-4, 1e-2))
  precision_beta_jitter_ladder <- precision_beta_jitter_ladder[
    is.finite(precision_beta_jitter_ladder) & precision_beta_jitter_ladder >= 0
  ]
  if (!length(precision_beta_jitter_ladder)) precision_beta_jitter_ladder <- c(0, 1e-10, 1e-8, 1e-6, 1e-4, 1e-2)
  precision_beta_jitter_ladder <- unique(precision_beta_jitter_ladder)
  precision_beta_eigen_fallback <- isTRUE(precision_beta_cfg$eigen_fallback %||% FALSE)
  precision_beta_eigen_floor_abs <- as.numeric(precision_beta_cfg$eigen_floor_abs %||% 1e-6)[1L]
  if (!is.finite(precision_beta_eigen_floor_abs) || precision_beta_eigen_floor_abs <= 0) {
    precision_beta_eigen_floor_abs <- 1e-6
  }
  precision_beta_eigen_floor_rel <- as.numeric(precision_beta_cfg$eigen_floor_rel %||% 1e-8)[1L]
  if (!is.finite(precision_beta_eigen_floor_rel) || precision_beta_eigen_floor_rel <= 0) {
    precision_beta_eigen_floor_rel <- 1e-8
  }
  precision_beta_trace_enabled <- isTRUE(precision_beta_cfg$trace %||% TRUE)

  if (!is.finite(gamma_slice_width) || gamma_slice_width <= 0) {
    .stopf("mcmc_control$slice$width_gamma must be positive.")
  }
  if (!is.finite(core_extra_passes) || core_extra_passes < 0L) core_extra_passes <- 0L
  if (!core_update_mode %in% c("sigma_then_gamma", "gamma_sigma_gamma")) {
    .stopf(
      "Unsupported mcmc_control$slice$core_update_mode '%s'. Expected 'sigma_then_gamma' or 'gamma_sigma_gamma'.",
      core_update_mode
    )
  }
  if (use_log_sigma && (!is.finite(sigma_slice_width) || sigma_slice_width <= 0)) {
    .stopf("mcmc_control$slice$width_sigma must be positive when using log-sigma sampling.")
  }
  if (!conditioning_mode %in% c("none", "diag_scale", "qr_whiten")) {
    .stopf(
      "Unsupported mcmc_control$conditioning$mode '%s'. Expected 'none', 'diag_scale', or 'qr_whiten'.",
      conditioning_mode
    )
  }
  if (!conditioning_scale_metric %in% c("sd", "rms")) {
    .stopf(
      "Unsupported mcmc_control$conditioning$scale_metric '%s'. Expected 'sd' or 'rms'.",
      conditioning_scale_metric
    )
  }
  if (!is.finite(conditioning_scale_floor) || conditioning_scale_floor <= 0) {
    conditioning_scale_floor <- 1e-8
  }
  if (!is.finite(conditioning_constant_tol) || conditioning_constant_tol <= 0) {
    conditioning_constant_tol <- 1e-12
  }
  if (!is.finite(conditioning_gram_ridge) || conditioning_gram_ridge <= 0) {
    conditioning_gram_ridge <- 1e-8
  }
  if (!is.finite(width_adapt_target_score_low)) width_adapt_target_score_low <- -1.5
  if (!is.finite(width_adapt_target_score_high)) width_adapt_target_score_high <- 1.5
  if (width_adapt_target_score_low >= width_adapt_target_score_high) {
    .stopf("mcmc_control$rhs$width_adapt target_score_low must be < target_score_high.")
  }
  if (!is.finite(width_adapt_step_size) || width_adapt_step_size <= 0) {
    width_adapt_step_size <- 0.05
  }
  if (!is.finite(width_adapt_min) || width_adapt_min <= 0) width_adapt_min <- 0.02
  if (!is.finite(width_adapt_max) || width_adapt_max <= width_adapt_min) {
    width_adapt_max <- max(2.5, width_adapt_min * 10)
  }

  if (is.null(prior_gamma)) prior_gamma <- list(mu0 = 0, s20 = 10)
  if (!is.list(prior_gamma)) .stopf("prior_gamma must be a list.")
  if (!is.null(prior_gamma_mu0)) prior_gamma$mu0 <- as.numeric(prior_gamma_mu0)[1L]
  if (!is.null(prior_gamma_s20)) prior_gamma$s20 <- as.numeric(prior_gamma_s20)[1L]
  if (is.null(prior_sigma)) prior_sigma <- list(a = 1, b = 1)
  if (!is.list(prior_sigma)) .stopf("prior_sigma must be a list.")
  if (!is.null(a_sigma)) prior_sigma$a <- as.numeric(a_sigma)[1L]
  if (!is.null(b_sigma)) prior_sigma$b <- as.numeric(b_sigma)[1L]

  if (is.null(log_prior_gamma)) {
    mu0 <- as.numeric(prior_gamma$mu0 %||% 0)
    s20 <- as.numeric(prior_gamma$s20 %||% 10)
    if (!is.finite(mu0) || !is.finite(s20) || s20 <= 0) {
      .stopf("prior_gamma must define finite mu0 and positive s20.")
    }
    log_prior_gamma <- function(g) {
      stats::dnorm(g, mean = mu0, sd = sqrt(s20), log = TRUE)
    }
  }

  if (is.null(beta_prior_obj)) {
    beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = 1e4))
  }
  beta_prior_type <- as.character(beta_prior_obj$type %||% NA_character_)[1L]
  if (!beta_prior_type %in% c("ridge", "rhs", "rhs_ns")) {
    .stopf("exal_mcmc_fit supports beta_prior_obj$type in {'ridge','rhs','rhs_ns'}; got '%s'.",
           beta_prior_type)
  }
  is_rhs <- identical(beta_prior_type, "rhs")
  is_rhs_ns <- identical(beta_prior_type, "rhs_ns")
  is_rhs_family <- is_rhs || is_rhs_ns
  ridge_tau2 <- if (identical(beta_prior_type, "ridge")) {
    as.numeric(beta_prior_obj$hypers$tau2 %||% NA_real_)[1L]
  } else {
    NA_real_
  }
  if (identical(beta_prior_type, "ridge") && (!is.finite(ridge_tau2) || ridge_tau2 <= 0)) {
    .stopf("ridge tau2 must be positive.")
  }

  y <- as.numeric(y)
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  n <- nrow(X)
  p <- ncol(X)

  .safe_matrix_kappa <- function(mat) {
    tryCatch({
      if (!is.matrix(mat) || !nrow(mat) || !ncol(mat)) return(NA_real_)
      if (nrow(mat) < 2L) return(NA_real_)
      as.numeric(kappa(mat, exact = FALSE))
    }, error = function(...) NA_real_)
  }
  .stable_chol <- function(mat, ridge_start = 1e-8, max_tries = 8L) {
    ridge_now <- max(as.numeric(ridge_start)[1L], 1e-12)
    for (ii in seq_len(max(1L, as.integer(max_tries)[1L]))) {
      cand <- tryCatch(chol(mat + diag(ridge_now, ncol(mat))), error = function(...) NULL)
      if (!is.null(cand)) {
        return(list(R = cand, ridge = ridge_now))
      }
      ridge_now <- ridge_now * 10
    }
    NULL
  }
  .build_beta_conditioning_state <- function(X, mode, scale_metric, scale_floor, intercept_column, constant_tol) {
    p <- ncol(X)
    col_names <- colnames(X)
    beta_scale <- rep(1, p)
    raw_metric <- rep(NA_real_, p)
    transform <- diag(p)
    transform_inv <- diag(p)
    intercept_idx <- if (length(intercept_column) &&
      is.finite(intercept_column) &&
      intercept_column >= 1L &&
      intercept_column <= p) {
      as.integer(intercept_column)[1L]
    } else {
      NA_integer_
    }
    scale_idx <- seq_len(p)
    if (is.finite(intercept_idx)) scale_idx <- setdiff(scale_idx, intercept_idx)

    if (identical(mode, "diag_scale") && length(scale_idx)) {
      for (jj in scale_idx) {
        xj <- as.numeric(X[, jj])
        metric_j <- if (identical(scale_metric, "rms")) {
          sqrt(mean(xj * xj))
        } else {
          stats::sd(xj)
        }
        if (!is.finite(metric_j) || metric_j <= constant_tol) metric_j <- 1
        raw_metric[jj] <- metric_j
        beta_scale[jj] <- max(metric_j, scale_floor)
      }
      transform <- diag(beta_scale, p)
      transform_inv <- diag(1 / beta_scale, p)
    } else if (identical(mode, "qr_whiten") && length(scale_idx)) {
      X_ns <- X[, scale_idx, drop = FALSE]
      gram_ns <- crossprod(X_ns) / max(1, nrow(X_ns))
      raw_metric[scale_idx] <- sqrt(pmax(diag(gram_ns), 0))
      chol_fit <- .stable_chol(gram_ns, ridge_start = conditioning_gram_ridge)
      if (is.null(chol_fit)) {
        .stopf("mcmc_control$conditioning qr_whiten could not factor the non-intercept Gram matrix.")
      }
      transform_ns <- chol_fit$R
      transform_inv_ns <- backsolve(transform_ns, diag(ncol(transform_ns)))
      transform[scale_idx, scale_idx] <- transform_ns
      transform_inv[scale_idx, scale_idx] <- transform_inv_ns
      beta_scale[scale_idx] <- diag(transform_ns)
    }

    active <- FALSE
    if (length(scale_idx)) {
      if (identical(mode, "diag_scale")) {
        active <- any(abs(beta_scale[scale_idx] - 1) > 1e-12)
      } else if (identical(mode, "qr_whiten")) {
        active <- TRUE
      }
    }
    X_work <- if (isTRUE(active)) X %*% transform_inv else X
    raw_kappa <- .safe_matrix_kappa(X)
    work_kappa <- .safe_matrix_kappa(X_work)
    gain_ratio <- if (is.finite(raw_kappa) && is.finite(work_kappa) && work_kappa > 0) {
      raw_kappa / work_kappa
    } else {
      NA_real_
    }
    scale_vals <- if (length(scale_idx)) beta_scale[scale_idx] else numeric(0)

    list(
      mode = mode,
      active = isTRUE(active),
      scale_metric = scale_metric,
      scale_floor = scale_floor,
      constant_tol = constant_tol,
      intercept_column = if (is.finite(intercept_idx)) intercept_idx else NA_integer_,
      beta_scale = beta_scale,
      beta_scale_sq = beta_scale * beta_scale,
      transform = transform,
      transform_inv = transform_inv,
      X_work = X_work,
      raw_metric = raw_metric,
      raw_kappa = raw_kappa,
      work_kappa = work_kappa,
      gain_ratio = gain_ratio,
      scaled_columns_n = if (length(scale_idx)) sum(abs(beta_scale[scale_idx] - 1) > 1e-12) else 0L,
      scale_min = if (length(scale_vals)) min(scale_vals) else NA_real_,
      scale_max = if (length(scale_vals)) max(scale_vals) else NA_real_,
      column_names = col_names
    )
  }
  conditioning_state <- .build_beta_conditioning_state(
    X = X,
    mode = conditioning_mode,
    scale_metric = conditioning_scale_metric,
    scale_floor = conditioning_scale_floor,
    intercept_column = conditioning_intercept_column,
    constant_tol = conditioning_constant_tol
  )
  beta_draw_design <- conditioning_state$X_work
  beta_draw_scale <- as.numeric(conditioning_state$beta_scale)
  beta_draw_scale_sq <- as.numeric(conditioning_state$beta_scale_sq)
  beta_draw_transform_inv <- as.matrix(conditioning_state$transform_inv)

  L <- gamma_bounds[1L]
  U <- gamma_bounds[2L]
  resolve_al_gamma <- function(g, L, U) {
    g <- as.numeric(g)[1L]
    if (!is.finite(g) || g <= L || g >= U) {
      if (L < 0 && U > 0) {
        g <- 0
      } else {
        g <- 0.5 * (L + U)
      }
    }
    eps <- 1e-8 * max(1, abs(U - L))
    min(max(g, L + eps), U - eps)
  }
  al_gamma_fixed <- if (is_al) {
    resolve_al_gamma(al_fixed_gamma %||% init$gamma %||% 0, L = L, U = U)
  } else {
    NA_real_
  }

  g_from_eta <- function(eta) {
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    L + (U - L) * s
  }
  eta_from_g <- function(g) {
    z <- (g - L) / (U - L)
    z <- pmin(pmax(z, 1e-12), 1 - 1e-12)
    stats::qlogis(z)
  }
  log_jac_gamma <- function(eta) {
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    log(U - L) + log(s) + log1p(-s)
  }

  A_of <- function(g) A.fn(p0, g)
  B_of <- function(g) B.fn(p0, g)
  Cabs_of <- function(g) C.fn(p0, g) * abs(g)

  logpost_eta_gamma <- function(eta, beta, sigma, v, s_vec) {
    if (is_al) return(-Inf)
    if (!is.finite(eta) || sigma <= 0 || any(!is.finite(beta)) || any(v <= 0) ||
        any(!is.finite(v)) || any(s_vec < 0) || any(!is.finite(s_vec))) {
      return(-Inf)
    }
    g <- g_from_eta(eta)
    A <- as.numeric(A_of(g))[1L]
    B <- as.numeric(B_of(g))[1L]
    Cabs <- as.numeric(Cabs_of(g))[1L]
    if (!is.finite(A) || !is.finite(B) || !is.finite(Cabs) || B <= 0) return(-Inf)

    mu <- drop(X %*% beta) + Cabs * sigma * s_vec + A * v
    res <- y - mu
    quad <- sum((res * res) / (B * sigma * v))
    if (!is.finite(quad)) return(-Inf)

    -(n / 2) * log(B) - 0.5 * quad + log_prior_gamma(g) + log_jac_gamma(eta)
  }

  vb_warm <- NULL
  if (init_from_vb) {
    if (!is.null(vb_warm_start_seed)) set.seed(vb_warm_start_seed)
    vb_warm <- exal_ldvb_fit(
      y = y,
      X = X,
      p0 = p0,
      gamma_bounds = gamma_bounds,
      vb_control = modifyList(list(
        max_iter = 50L,
        min_iter_elbo = 10L,
        tol = 1e-3,
        tol_par = 1e-3,
        n_samp_xi = 200L,
        verbose = FALSE
      ), mcmc_control$vb_warm_start_control %||% list()),
      init = init,
      likelihood_family = likelihood_family,
      prior_gamma = prior_gamma,
      prior_sigma = prior_sigma,
      log_prior_gamma = log_prior_gamma,
      beta_prior_obj = beta_prior_obj
    )
  }

  beta <- as.numeric(init$beta %||% if (!is.null(vb_warm)) vb_warm$qbeta$m else rep(0, p))
  sigma <- as.numeric(init$sigma %||% if (!is.null(vb_warm)) vb_warm$qsiggam$sigma_mean else 1)[1L]
  eta_sigma <- log(max(as.numeric(sigma)[1L], 1e-12))
  gamma <- if (is_al) {
    as.numeric(al_gamma_fixed)
  } else {
    g0 <- as.numeric(init$gamma %||% if (!is.null(vb_warm)) vb_warm$qsiggam$gamma_mean else 0)[1L]
    min(max(g0, L + 1e-6), U - 1e-6)
  }
  eta_gamma <- eta_from_g(gamma)

  v <- as.numeric(init$v %||% if (!is.null(vb_warm)) vb_warm$qv$E_v else rep(1, n))
  if (length(v) != n) v <- rep(v[1L], n)
  v <- pmax(v, 1e-12)

  s <- as.numeric(init$s %||% if (!is.null(vb_warm)) vb_warm$qs$E_s else abs(stats::rnorm(n)))
  if (length(s) != n) s <- rep(s[1L], n)
  s <- pmax(s, 0)

  rhs_state <- if (is_rhs) {
    .exal_mcmc_rhs_prepare_state(beta_prior_obj, p = p, init = init, vb_warm = vb_warm)
  } else if (is_rhs_ns) {
    .exal_mcmc_rhs_ns_prepare_state(beta_prior_obj, p = p, init = init, vb_warm = vb_warm)
  } else {
    NULL
  }
  beta_prec_diag <- if (is_rhs) {
    .exal_mcmc_rhs_precisions(rhs_state, p = p)
  } else if (is_rhs_ns) {
    .exal_mcmc_rhs_ns_precisions(rhs_state, p = p)
  } else {
    rep(1 / ridge_tau2, p)
  }

  # Multi-start pilot selection for hard RHS roots:
  # run short pilots from VB-init and perturbed transformed starts,
  # then continue from the healthiest/highest-score pilot endpoint.
  if (is_rhs && isTRUE(multi_start_enabled) && !isTRUE(multi_start_internal)) {
    n_starts <- max(1L, as.integer(multi_start_cfg$n_starts %||% 4L))
    pilot_n_burn <- max(0L, as.integer(multi_start_cfg$pilot_n_burn %||% min(120L, n_burn)))
    pilot_n_mcmc <- max(10L, as.integer(multi_start_cfg$pilot_n_mcmc %||% min(160L, n_keep)))
    pilot_seed_base <- normalize_seed(multi_start_cfg$pilot_seed %||% rng_seed %||% 1L)
    perturb_sd_tau <- as.numeric(multi_start_cfg$perturb_sd_log_tau %||% 0.35)[1L]
    perturb_sd_c2 <- as.numeric(multi_start_cfg$perturb_sd_log_c2 %||% 0.35)[1L]
    perturb_sd_lambda <- as.numeric(multi_start_cfg$perturb_sd_log_lambda %||% 0.20)[1L]
    perturb_sd_beta <- as.numeric(multi_start_cfg$perturb_sd_beta %||% 0.05)[1L]

    eta_bounds <- beta_prior_obj$control$eta_bounds %||% list()
    b_lam <- as.numeric(eta_bounds$lambda %||% c(-40, 40))
    b_tau <- as.numeric(eta_bounds$tau %||% c(-40, 40))
    b_c2 <- as.numeric(eta_bounds$c2 %||% c(-40, 40))

    init_base <- list(
      beta = beta,
      sigma = sigma,
      gamma = gamma,
      v = v,
      s = s,
      rhs_state = rhs_state,
      beta_prior_state = rhs_state
    )
    candidate_inits <- list(init_base)
    candidate_ids <- c(if (isTRUE(init_from_vb)) "vb_init" else "provided_init")
    if (n_starts >= 2L) {
      for (kk in 2L:n_starts) {
        st <- init_base$rhs_state
        st$eta_tau_hat <- .exal_mcmc_clamp(st$eta_tau_hat + stats::rnorm(1L, sd = perturb_sd_tau), b_tau[1L], b_tau[2L])
        st$eta_c_hat <- .exal_mcmc_clamp(st$eta_c_hat + stats::rnorm(1L, sd = perturb_sd_c2), b_c2[1L], b_c2[2L])
        if (length(st$eta_lambda_hat)) {
          st$eta_lambda_hat <- .exal_mcmc_clamp(
            as.numeric(st$eta_lambda_hat) + stats::rnorm(length(st$eta_lambda_hat), sd = perturb_sd_lambda),
            b_lam[1L],
            b_lam[2L]
          )
        }
        init_k <- init_base
        init_k$rhs_state <- st
        init_k$beta_prior_state <- st
        init_k$beta <- as.numeric(init_base$beta) + stats::rnorm(length(init_base$beta), sd = perturb_sd_beta)
        candidate_inits[[length(candidate_inits) + 1L]] <- init_k
        candidate_ids[[length(candidate_ids) + 1L]] <- sprintf("perturb_%02d", kk - 1L)
      }
    }

    pilot_rows <- list()
    pilot_fits <- vector("list", length(candidate_inits))
    for (ii in seq_along(candidate_inits)) {
      pilot_control <- mcmc_control
      pilot_control$n_burn <- pilot_n_burn
      pilot_control$n_mcmc <- pilot_n_mcmc
      pilot_control$thin <- 1L
      pilot_control$verbose <- FALSE
      pilot_control$progress_every <- max(10L, floor((pilot_n_burn + pilot_n_mcmc) / 2L))
      pilot_control$init_from_vb <- FALSE
      pilot_control$multi_start <- modifyList(multi_start_cfg, list(enabled = FALSE))
      pilot_control[["_multi_start_internal"]] <- TRUE
      pilot_control$rng_seed <- normalize_seed(pilot_seed_base + as.integer(ii) * 7919L)

      pilot_fit <- exal_mcmc_fit(
        y = y,
        X = X,
        p0 = p0,
        gamma_bounds = gamma_bounds,
        likelihood_family = likelihood_family,
        al_fixed_gamma = al_fixed_gamma,
        mcmc_control = pilot_control,
        init = candidate_inits[[ii]],
        prior_gamma = prior_gamma,
        log_prior_gamma = log_prior_gamma,
        prior_sigma = prior_sigma,
        beta_prior_obj = beta_prior_obj
      )
      pilot_fits[[ii]] <- pilot_fit
      score <- .exal_mcmc_multistart_score(pilot_fit, cfg = multi_start_cfg$diagnostics %||% list())
      pilot_rows[[ii]] <- data.frame(
        start_id = candidate_ids[[ii]],
        rank = ii,
        healthy = isTRUE(score$healthy),
        finite_ok = isTRUE(score$finite_ok),
        domain_ok = isTRUE(score$domain_ok),
        collapse_flag = isTRUE(score$collapse_flag),
        ess_min = as.numeric(score$ess_min),
        geweke_max = as.numeric(score$geweke_max),
        half_drift_max = as.numeric(score$half_drift_max),
        tau_median = as.numeric(score$tau_median),
        beta_norm_median = as.numeric(score$beta_norm_median),
        score = as.numeric(score$score),
        stringsAsFactors = FALSE
      )
    }
    pilot_df <- do.call(rbind, pilot_rows)
    ord_pilot <- with(
      pilot_df,
      order(!as.logical(healthy), !as.logical(finite_ok), !as.logical(domain_ok), as.logical(collapse_flag), -as.numeric(score), -as.numeric(ess_min))
    )
    best_idx <- as.integer(ord_pilot[1L])
    best_fit <- pilot_fits[[best_idx]]

    init_final <- list(
      beta = as.numeric(best_fit$last$beta),
      sigma = as.numeric(best_fit$last$sigma),
      gamma = as.numeric(best_fit$last$gamma),
      v = as.numeric(best_fit$last$v),
      s = as.numeric(best_fit$last$s),
      rhs_state = best_fit$last$beta_prior_state,
      beta_prior_state = best_fit$last$beta_prior_state
    )
    final_control <- mcmc_control
    final_control$init_from_vb <- FALSE
    final_control$multi_start <- modifyList(multi_start_cfg, list(enabled = FALSE))
    final_control[["_multi_start_internal"]] <- TRUE

    fit_final <- exal_mcmc_fit(
      y = y,
      X = X,
      p0 = p0,
      gamma_bounds = gamma_bounds,
      likelihood_family = likelihood_family,
      al_fixed_gamma = al_fixed_gamma,
      mcmc_control = final_control,
      init = init_final,
      prior_gamma = prior_gamma,
      log_prior_gamma = log_prior_gamma,
      prior_sigma = prior_sigma,
      beta_prior_obj = beta_prior_obj
    )
    fit_final$control$multi_start <- list(
      enabled = TRUE,
      n_starts = n_starts,
      pilot_n_burn = pilot_n_burn,
      pilot_n_mcmc = pilot_n_mcmc,
      selected_start_id = as.character(pilot_df$start_id[best_idx]),
      selected_rank = as.integer(best_idx)
    )
    fit_final$misc$multi_start_pilot_summary <- pilot_df
    return(fit_final)
  }

  if (!is.null(rng_seed)) {
    set.seed(rng_seed)
  }

  adapt_width_one <- function(width, score, step_now) {
    width <- as.numeric(width)[1L]
    score <- as.numeric(score)[1L]
    if (!is.finite(width) || width <= 0 || !is.finite(score) || !is.finite(step_now) || step_now <= 0) {
      return(width)
    }
    if (score > width_adapt_target_score_high) {
      width <- width * exp(step_now)
    } else if (score < width_adapt_target_score_low) {
      width <- width * exp(-step_now)
    }
    .exal_mcmc_clamp(width, width_adapt_min, width_adapt_max)
  }

  update_sigma_only <- function(beta_now, v_now, s_now, sigma_now, eta_sigma_now, eta_gamma_now) {
    gamma_now <- if (is_al) as.numeric(al_gamma_fixed) else g_from_eta(eta_gamma_now)
    A_now <- as.numeric(A_of(gamma_now))[1L]
    B_now <- as.numeric(B_of(gamma_now))[1L]
    Cabs_now <- as.numeric(Cabs_of(gamma_now))[1L]

    r_sigma <- y - drop(X %*% beta_now) - A_now * v_now
    chi_sigma <- sum((r_sigma * r_sigma) / (B_now * v_now)) + 2 * sum(v_now) + 2 * as.numeric(prior_sigma$b)
    psi_sigma <- (Cabs_now * Cabs_now / B_now) * sum((s_now * s_now) / v_now)
    k_sigma <- -(as.numeric(prior_sigma$a) + 1.5 * n)
    chi_sigma_safe <- if (is.finite(chi_sigma) && chi_sigma > 0) chi_sigma else 1e-12
    psi_sigma_safe <- if (is.finite(psi_sigma) && psi_sigma >= 0) psi_sigma else 0
    k_sigma_safe <- if (is.finite(k_sigma)) k_sigma else -(as.numeric(prior_sigma$a) + 1.5 * n)

    if (isTRUE(use_log_sigma)) {
      sigma_slice <- .exal_mcmc_slice_sample_1d(
        x0 = eta_sigma_now,
        logf = function(eta) {
          if (!is.finite(eta)) return(-Inf)
          sig <- .safe_exp(eta)
          if (!is.finite(sig) || sig <= 0) return(-Inf)
          k_sigma_safe * eta - 0.5 * (psi_sigma_safe * sig + chi_sigma_safe / sig)
        },
        width = sigma_slice_width,
        max_steps_out = sigma_slice_max_steps_out,
        max_shrink = sigma_slice_max_shrink,
        lower = sigma_eta_bounds[1L],
        upper = sigma_eta_bounds[2L]
      )
      eta_sigma_now <- sigma_slice$x
      sigma_now <- .safe_exp(eta_sigma_now)
    } else {
      sigma_new <- tryCatch(
        as.numeric(.sample_gig_devroye_required(
          1L, p = k_sigma_safe, a = psi_sigma_safe, b_vec = chi_sigma_safe,
          context = "exal_mcmc_fit::sigma_update"
        )[1L, 1L]),
        error = function(e) NA_real_
      )
      if (is.finite(sigma_new) && sigma_new > 0) {
        sigma_now <- sigma_new
        eta_sigma_now <- log(max(as.numeric(sigma_now)[1L], 1e-12))
      } else {
        sigma_slice <- .exal_mcmc_slice_sample_1d(
          x0 = eta_sigma_now,
          logf = function(eta) {
            if (!is.finite(eta)) return(-Inf)
            sig <- .safe_exp(eta)
            if (!is.finite(sig) || sig <= 0) return(-Inf)
            k_sigma_safe * eta - 0.5 * (psi_sigma_safe * sig + chi_sigma_safe / sig)
          },
          width = sigma_slice_width,
          max_steps_out = sigma_slice_max_steps_out,
          max_shrink = sigma_slice_max_shrink,
          lower = sigma_eta_bounds[1L],
          upper = sigma_eta_bounds[2L]
        )
        eta_sigma_now <- sigma_slice$x
        sigma_now <- .safe_exp(eta_sigma_now)
      }
    }

    list(
      sigma = sigma_now,
      eta_sigma = eta_sigma_now
    )
  }

  update_gamma_only <- function(beta_now, v_now, s_now, sigma_now, eta_gamma_now) {
    if (!is_al) {
      slice_gamma <- .exal_mcmc_slice_sample_1d(
        x0 = eta_gamma_now,
        logf = function(eta) logpost_eta_gamma(eta, beta = beta_now, sigma = sigma_now, v = v_now, s_vec = s_now),
        width = gamma_slice_width,
        max_steps_out = gamma_slice_max_steps_out,
        max_shrink = gamma_slice_max_shrink
      )
      eta_gamma_now <- slice_gamma$x
      gamma_now <- g_from_eta(eta_gamma_now)
      gamma_steps_out <- as.integer(slice_gamma$n_steps_out)
      gamma_shrink <- as.integer(slice_gamma$n_shrink)
    } else {
      eta_gamma_now <- eta_from_g(as.numeric(al_gamma_fixed))
      gamma_now <- as.numeric(al_gamma_fixed)
      gamma_steps_out <- 0L
      gamma_shrink <- 0L
    }

    list(
      gamma = gamma_now,
      eta_gamma = eta_gamma_now,
      gamma_steps_out = gamma_steps_out,
      gamma_shrink = gamma_shrink
    )
  }

  update_sigma_gamma_once <- function(beta_now, v_now, s_now, sigma_now, eta_sigma_now, eta_gamma_now) {
    if (identical(core_update_mode, "gamma_sigma_gamma") && !is_al) {
      gamma_upd_pre <- update_gamma_only(
        beta_now = beta_now,
        v_now = v_now,
        s_now = s_now,
        sigma_now = sigma_now,
        eta_gamma_now = eta_gamma_now
      )
      sigma_upd <- update_sigma_only(
        beta_now = beta_now,
        v_now = v_now,
        s_now = s_now,
        sigma_now = sigma_now,
        eta_sigma_now = eta_sigma_now,
        eta_gamma_now = gamma_upd_pre$eta_gamma
      )
      gamma_upd_post <- update_gamma_only(
        beta_now = beta_now,
        v_now = v_now,
        s_now = s_now,
        sigma_now = sigma_upd$sigma,
        eta_gamma_now = gamma_upd_pre$eta_gamma
      )

      return(list(
        sigma = sigma_upd$sigma,
        eta_sigma = sigma_upd$eta_sigma,
        gamma = gamma_upd_post$gamma,
        eta_gamma = gamma_upd_post$eta_gamma,
        gamma_steps_out = as.integer(gamma_upd_pre$gamma_steps_out) + as.integer(gamma_upd_post$gamma_steps_out),
        gamma_shrink = as.integer(gamma_upd_pre$gamma_shrink) + as.integer(gamma_upd_post$gamma_shrink)
      ))
    }

    sigma_upd <- update_sigma_only(
      beta_now = beta_now,
      v_now = v_now,
      s_now = s_now,
      sigma_now = sigma_now,
      eta_sigma_now = eta_sigma_now,
      eta_gamma_now = eta_gamma_now
    )
    gamma_upd <- update_gamma_only(
      beta_now = beta_now,
      v_now = v_now,
      s_now = s_now,
      sigma_now = sigma_upd$sigma,
      eta_gamma_now = eta_gamma_now
    )

    list(
      sigma = sigma_upd$sigma,
      eta_sigma = sigma_upd$eta_sigma,
      gamma = gamma_upd$gamma,
      eta_gamma = gamma_upd$eta_gamma,
      gamma_steps_out = gamma_upd$gamma_steps_out,
      gamma_shrink = gamma_upd$gamma_shrink
    )
  }

  slice_cfg_runtime <- slice_cfg
  rhs_slice_widths_initial <- list()
  if (is_rhs) {
    slice_cfg_runtime$width_rhs_lambda <- as.numeric(slice_cfg_runtime$width_rhs_lambda %||% slice_cfg_runtime$width_lambda %||% 1.0)[1L]
    slice_cfg_runtime$width_rhs_tau <- as.numeric(slice_cfg_runtime$width_rhs_tau %||% slice_cfg_runtime$width_tau %||% 1.0)[1L]
    slice_cfg_runtime$width_rhs_c2 <- as.numeric(slice_cfg_runtime$width_rhs_c2 %||% slice_cfg_runtime$width_c2 %||% 1.0)[1L]
    slice_cfg_runtime$width_rhs_tau_c2_block <- as.numeric(slice_cfg_runtime$width_rhs_tau_c2_block %||% 1.0)[1L]
    slice_cfg_runtime$width_rhs_tau_c2_transformed_z1 <- as.numeric(
      slice_cfg_runtime$width_rhs_tau_c2_transformed_z1 %||% slice_cfg_runtime$width_rhs_tau_c2_block
    )[1L]
    slice_cfg_runtime$width_rhs_tau_c2_transformed_z2 <- as.numeric(
      slice_cfg_runtime$width_rhs_tau_c2_transformed_z2 %||% slice_cfg_runtime$width_rhs_tau_c2_block
    )[1L]
    slice_cfg_runtime$rhs_global_block_update <- as.character(slice_cfg_runtime$rhs_global_block_update %||% "coordinate")[1L]
    slice_cfg_runtime$rhs_transformed_block_passes <- max(1L, as.integer(slice_cfg_runtime$rhs_transformed_block_passes %||% 1L))

    rhs_slice_widths_initial <- list(
      width_rhs_lambda = slice_cfg_runtime$width_rhs_lambda,
      width_rhs_tau = slice_cfg_runtime$width_rhs_tau,
      width_rhs_c2 = slice_cfg_runtime$width_rhs_c2,
      width_rhs_tau_c2_block = slice_cfg_runtime$width_rhs_tau_c2_block,
      width_rhs_tau_c2_transformed_z1 = slice_cfg_runtime$width_rhs_tau_c2_transformed_z1,
      width_rhs_tau_c2_transformed_z2 = slice_cfg_runtime$width_rhs_tau_c2_transformed_z2
    )
  }

  n_total <- n_burn + n_keep * thin
  beta_draws <- matrix(NA_real_, nrow = n_keep, ncol = p)
  sigma_draws <- numeric(n_keep)
  gamma_draws <- numeric(n_keep)
  gamma_trace <- rep(NA_real_, n_total)
  sigma_trace <- rep(NA_real_, n_total)
  sigmagam_frozen_trace <- rep(FALSE, n_total)
  sigmagam_forced_postwarmup_trace <- rep(FALSE, n_total)
  sigmagam_update_performed_trace <- rep(FALSE, n_total)
  sigmagam_update_reason_trace <- rep(NA_character_, n_total)
  sigmagam_update_count_trace <- integer(n_total)
  sigmagam_first_active_iter <- NA_integer_
  sigmagam_update_count <- 0L
  sigmagam_postwarmup_update_count <- 0L
  sigmagam_updates_burn <- 0L
  sigmagam_updates_keep <- 0L
  theta_warmup_active_trace <- rep(FALSE, n_total)
  theta_hard_freeze_trace <- rep(FALSE, n_total)
  theta_sparse_window_trace <- rep(FALSE, n_total)
  theta_force_update_trace <- rep(FALSE, n_total)
  theta_update_performed_trace <- rep(FALSE, n_total)
  theta_update_reason_trace <- rep(NA_character_, n_total)
  theta_update_count_trace <- integer(n_total)
  theta_first_postwarmup_update_iter <- NA_integer_
  theta_update_count <- 0L
  theta_updates_burn <- 0L
  theta_updates_keep <- 0L
  precision_beta_direct_successes <- 0L
  precision_beta_jitter_successes <- 0L
  precision_beta_eigen_successes <- 0L
  precision_beta_rescue_count <- 0L
  precision_beta_first_rescue_iter <- NA_integer_
  precision_beta_max_jitter_used <- 0
  theta_force_pending <- isTRUE(theta_enabled && theta_freeze_burnin_iters > 0L && theta_force_first_postwarmup_update)
  latent_v_warmup_active_trace <- rep(FALSE, n_total)
  latent_v_hard_freeze_trace <- rep(FALSE, n_total)
  latent_v_sparse_window_trace <- rep(FALSE, n_total)
  latent_v_force_update_trace <- rep(FALSE, n_total)
  latent_v_update_performed_trace <- rep(FALSE, n_total)
  latent_v_update_reason_trace <- rep(NA_character_, n_total)
  latent_v_update_count_trace <- integer(n_total)
  latent_v_rescue_applied_trace <- rep(FALSE, n_total)
  latent_v_rescue_strategy_trace <- rep(NA_character_, n_total)
  latent_v_rescue_count_trace <- integer(n_total)
  latent_v_rescue_consecutive_trace <- integer(n_total)
  latent_v_first_postwarmup_update_iter <- NA_integer_
  latent_v_update_count <- 0L
  latent_v_updates_burn <- 0L
  latent_v_updates_keep <- 0L
  latent_v_rescue_count <- 0L
  latent_v_rescue_consecutive <- 0L
  latent_v_rescues_burn <- 0L
  latent_v_rescues_keep <- 0L
  latent_v_rescue_max_streak <- 0L
  latent_v_force_pending <- isTRUE(latent_v_enabled && latent_v_freeze_burnin_iters > 0L && latent_v_force_first_postwarmup_update)
  latent_s_warmup_active_trace <- rep(FALSE, n_total)
  latent_s_hard_freeze_trace <- rep(FALSE, n_total)
  latent_s_sparse_window_trace <- rep(FALSE, n_total)
  latent_s_force_update_trace <- rep(FALSE, n_total)
  latent_s_update_performed_trace <- rep(FALSE, n_total)
  latent_s_update_reason_trace <- rep(NA_character_, n_total)
  latent_s_update_count_trace <- integer(n_total)
  latent_s_first_postwarmup_update_iter <- NA_integer_
  latent_s_update_count <- 0L
  latent_s_updates_burn <- 0L
  latent_s_updates_keep <- 0L
  latent_s_force_pending <- isTRUE(latent_s_enabled && latent_s_freeze_burnin_iters > 0L && latent_s_force_first_postwarmup_update)
  if (store_latent_draws) {
    v_draws <- matrix(NA_real_, nrow = n_keep, ncol = n)
    s_draws <- matrix(NA_real_, nrow = n_keep, ncol = n)
  } else {
    v_draws <- NULL
    s_draws <- NULL
  }
  gamma_steps_out <- rep(NA_integer_, n_total)
  gamma_shrink <- rep(NA_integer_, n_total)
  if (is_rhs_family) {
    rhs_tau_trace <- rep(NA_real_, n_total)
    rhs_c2_trace <- rep(NA_real_, n_total)
    rhs_lambda_mean_trace <- rep(NA_real_, n_total)
    rhs_lambda_min_trace <- rep(NA_real_, n_total)
    rhs_lambda_max_trace <- rep(NA_real_, n_total)
    rhs_tau_steps_out <- integer(n_total)
    rhs_tau_shrink <- integer(n_total)
    rhs_c2_steps_out <- integer(n_total)
    rhs_c2_shrink <- integer(n_total)
    rhs_lambda_steps_out_mean <- numeric(n_total)
    rhs_lambda_steps_out_max <- integer(n_total)
    rhs_lambda_shrink_mean <- numeric(n_total)
    rhs_lambda_shrink_max <- integer(n_total)
    rhs_tau_frozen_trace <- logical(n_total)
    rhs_global_block_used_trace <- logical(n_total)
    rhs_global_block_steps_out <- integer(n_total)
    rhs_global_block_shrink <- integer(n_total)
    rhs_global_block_dir_tau <- numeric(n_total)
    rhs_global_block_dir_c2 <- numeric(n_total)
    rhs_global_block_transformed_passes <- integer(n_total)
    rhs_transformed_z1_steps_out <- integer(n_total)
    rhs_transformed_z1_shrink <- integer(n_total)
    rhs_transformed_z2_steps_out <- integer(n_total)
    rhs_transformed_z2_shrink <- integer(n_total)
    rhs_width_lambda_trace <- rep(NA_real_, n_total)
    rhs_width_tau_trace <- rep(NA_real_, n_total)
    rhs_width_c2_trace <- rep(NA_real_, n_total)
    rhs_width_tau_c2_block_trace <- rep(NA_real_, n_total)
    rhs_width_tau_c2_transformed_z1_trace <- rep(NA_real_, n_total)
    rhs_width_tau_c2_transformed_z2_trace <- rep(NA_real_, n_total)
    rhs_width_adapt_active_trace <- rep(FALSE, n_total)
    rhs_width_adapt_iter <- 0L
    tau_draws <- numeric(n_keep)
    c2_draws <- numeric(n_keep)
    lambda_mean_draws <- numeric(n_keep)
    lambda_min_draws <- numeric(n_keep)
    lambda_max_draws <- numeric(n_keep)
    if (store_rhs_draws) {
      lambda_draws <- matrix(NA_real_, nrow = n_keep, ncol = p)
    } else {
      lambda_draws <- NULL
    }
  } else {
    rhs_tau_trace <- NULL
    rhs_c2_trace <- NULL
    rhs_lambda_mean_trace <- NULL
    rhs_lambda_min_trace <- NULL
    rhs_lambda_max_trace <- NULL
    rhs_tau_steps_out <- NULL
    rhs_tau_shrink <- NULL
    rhs_c2_steps_out <- NULL
    rhs_c2_shrink <- NULL
    rhs_lambda_steps_out_mean <- NULL
    rhs_lambda_steps_out_max <- NULL
    rhs_lambda_shrink_mean <- NULL
    rhs_lambda_shrink_max <- NULL
    rhs_tau_frozen_trace <- NULL
    rhs_global_block_used_trace <- NULL
    rhs_global_block_steps_out <- NULL
    rhs_global_block_shrink <- NULL
    rhs_global_block_dir_tau <- NULL
    rhs_global_block_dir_c2 <- NULL
    rhs_global_block_transformed_passes <- NULL
    rhs_transformed_z1_steps_out <- NULL
    rhs_transformed_z1_shrink <- NULL
    rhs_transformed_z2_steps_out <- NULL
    rhs_transformed_z2_shrink <- NULL
    rhs_width_lambda_trace <- NULL
    rhs_width_tau_trace <- NULL
    rhs_width_c2_trace <- NULL
    rhs_width_tau_c2_block_trace <- NULL
    rhs_width_tau_c2_transformed_z1_trace <- NULL
    rhs_width_tau_c2_transformed_z2_trace <- NULL
    rhs_width_adapt_active_trace <- NULL
    rhs_width_adapt_iter <- 0L
    tau_draws <- NULL
    c2_draws <- NULL
    lambda_mean_draws <- NULL
    lambda_min_draws <- NULL
    lambda_max_draws <- NULL
    lambda_draws <- NULL
  }

  t0 <- proc.time()[3L]
  save_idx <- 0L
  core_passes_total <- 1L + as.integer(core_extra_passes)
  .mean_or_na <- function(x) if (!length(x) || all(!is.finite(x))) NA_real_ else mean(x[is.finite(x)])
  .max_or_na <- function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) return(NA_real_)
    max(x)
  }
  for (iter in seq_len(n_total)) {
    A <- as.numeric(A_of(gamma))[1L]
    B <- as.numeric(B_of(gamma))[1L]
    Cabs <- as.numeric(Cabs_of(gamma))[1L]

    theta_hard_freeze_active <- isTRUE(
      theta_enabled &&
        theta_freeze_burnin_iters > 0L &&
        iter <= theta_freeze_burnin_iters &&
        (!theta_freeze_only_during_burn || iter <= n_burn)
    )
    theta_sparse_window_active <- isTRUE(
      theta_enabled &&
        !theta_hard_freeze_active &&
        theta_sparse_update_every > 1L &&
        iter <= theta_sparse_update_until_iter &&
        (!theta_freeze_only_during_burn || iter <= n_burn)
    )
    theta_sparse_update_now <- isTRUE(
      theta_sparse_window_active &&
        ((iter - theta_freeze_burnin_iters - 1L) %% theta_sparse_update_every == 0L)
    )
    theta_force_now <- isTRUE(!theta_hard_freeze_active && theta_force_pending)
    theta_update_reason <- if (isTRUE(theta_hard_freeze_active)) {
      "warmup_freeze"
    } else if (isTRUE(theta_force_now)) {
      "force_after_warmup"
    } else if (isTRUE(theta_sparse_window_active) && !isTRUE(theta_sparse_update_now)) {
      "sparse_hold"
    } else if (isTRUE(theta_sparse_window_active)) {
      "sparse_update"
    } else {
      "scheduled"
    }
    theta_update_now <- !isTRUE(theta_hard_freeze_active) &&
      (isTRUE(theta_force_now) || !isTRUE(theta_sparse_window_active) || isTRUE(theta_sparse_update_now))
    theta_warmup_active_trace[iter] <- isTRUE(theta_hard_freeze_active || theta_sparse_window_active)
    theta_hard_freeze_trace[iter] <- isTRUE(theta_hard_freeze_active)
    theta_sparse_window_trace[iter] <- isTRUE(theta_sparse_window_active)
    theta_force_update_trace[iter] <- isTRUE(theta_force_now)
    theta_update_reason_trace[iter] <- theta_update_reason

    latent_s_hard_freeze_active <- isTRUE(
      latent_s_enabled &&
        latent_s_freeze_burnin_iters > 0L &&
        iter <= latent_s_freeze_burnin_iters &&
        (!latent_s_freeze_only_during_burn || iter <= n_burn)
    )
    latent_s_sparse_window_active <- isTRUE(
      latent_s_enabled &&
        !latent_s_hard_freeze_active &&
        latent_s_sparse_update_every > 1L &&
        iter <= latent_s_sparse_update_until_iter &&
        (!latent_s_freeze_only_during_burn || iter <= n_burn)
    )
    latent_s_sparse_update_now <- isTRUE(
      latent_s_sparse_window_active &&
        ((iter - latent_s_freeze_burnin_iters - 1L) %% latent_s_sparse_update_every == 0L)
    )
    latent_s_force_now <- isTRUE(!latent_s_hard_freeze_active && latent_s_force_pending)
    latent_s_update_reason <- if (isTRUE(latent_s_hard_freeze_active)) {
      "warmup_freeze"
    } else if (isTRUE(latent_s_force_now)) {
      "force_after_warmup"
    } else if (isTRUE(latent_s_sparse_window_active) && !isTRUE(latent_s_sparse_update_now)) {
      "sparse_hold"
    } else if (isTRUE(latent_s_sparse_window_active)) {
      "sparse_update"
    } else {
      "scheduled"
    }
    latent_s_update_now <- !isTRUE(latent_s_hard_freeze_active) &&
      (isTRUE(latent_s_force_now) || !isTRUE(latent_s_sparse_window_active) || isTRUE(latent_s_sparse_update_now))
    latent_s_warmup_active_trace[iter] <- isTRUE(latent_s_hard_freeze_active || latent_s_sparse_window_active)
    latent_s_hard_freeze_trace[iter] <- isTRUE(latent_s_hard_freeze_active)
    latent_s_sparse_window_trace[iter] <- isTRUE(latent_s_sparse_window_active)
    latent_s_force_update_trace[iter] <- isTRUE(latent_s_force_now)
    latent_s_update_reason_trace[iter] <- latent_s_update_reason

    latent_v_hard_freeze_active <- isTRUE(
      latent_v_enabled &&
        latent_v_freeze_burnin_iters > 0L &&
        iter <= latent_v_freeze_burnin_iters &&
        (!latent_v_freeze_only_during_burn || iter <= n_burn)
    )
    latent_v_sparse_window_active <- isTRUE(
      latent_v_enabled &&
        !latent_v_hard_freeze_active &&
        latent_v_sparse_update_every > 1L &&
        iter <= latent_v_sparse_update_until_iter &&
        (!latent_v_freeze_only_during_burn || iter <= n_burn)
    )
    latent_v_sparse_update_now <- isTRUE(
      latent_v_sparse_window_active &&
        ((iter - latent_v_freeze_burnin_iters - 1L) %% latent_v_sparse_update_every == 0L)
    )
    latent_v_force_now <- isTRUE(!latent_v_hard_freeze_active && latent_v_force_pending)
    latent_v_update_reason <- if (isTRUE(latent_v_hard_freeze_active)) {
      "warmup_freeze"
    } else if (isTRUE(latent_v_force_now)) {
      "force_after_warmup"
    } else if (isTRUE(latent_v_sparse_window_active) && !isTRUE(latent_v_sparse_update_now)) {
      "sparse_hold"
    } else if (isTRUE(latent_v_sparse_window_active)) {
      "sparse_update"
    } else {
      "scheduled"
    }
    latent_v_update_now <- !isTRUE(latent_v_hard_freeze_active) &&
      (isTRUE(latent_v_force_now) || !isTRUE(latent_v_sparse_window_active) || isTRUE(latent_v_sparse_update_now))
    latent_v_warmup_active_trace[iter] <- isTRUE(latent_v_hard_freeze_active || latent_v_sparse_window_active)
    latent_v_hard_freeze_trace[iter] <- isTRUE(latent_v_hard_freeze_active)
    latent_v_sparse_window_trace[iter] <- isTRUE(latent_v_sparse_window_active)
    latent_v_force_update_trace[iter] <- isTRUE(latent_v_force_now)
    latent_v_update_reason_trace[iter] <- latent_v_update_reason

    z_v <- y - drop(X %*% beta) - Cabs * sigma * s
    chi_v <- (z_v * z_v) / (B * sigma)
    psi_v <- (A * A) / (B * sigma) + (2 / sigma)
    if (isTRUE(latent_v_update_now)) {
      prev_v <- as.numeric(v)
      sampled_v <- tryCatch(
        as.numeric(.sample_gig_devroye_required(
          1L, p = 0.5, a = psi_v, b_vec = chi_v,
          context = "exal_mcmc_fit::latent_v"
        )[1L, ]),
        error = function(e) e
      )
      if (inherits(sampled_v, "error")) {
        latent_v_rescue_allowed_now <- isTRUE(
          latent_v_rescue_on_invalid &&
            latent_v_rescue_strategy %in% c("previous_state") &&
            (!latent_v_rescue_burn_only || iter <= n_burn) &&
            latent_v_rescue_max_consecutive > 0L &&
            latent_v_rescue_consecutive < latent_v_rescue_max_consecutive &&
            length(prev_v) == n &&
            all(is.finite(prev_v))
        )
        if (isTRUE(latent_v_rescue_allowed_now)) {
          v <- pmax(prev_v, 1e-12)
          latent_v_rescue_applied_trace[iter] <- TRUE
          latent_v_rescue_strategy_trace[iter] <- latent_v_rescue_strategy
          latent_v_rescue_count <- latent_v_rescue_count + 1L
          latent_v_rescue_consecutive <- latent_v_rescue_consecutive + 1L
          latent_v_rescue_max_streak <- max(latent_v_rescue_max_streak, latent_v_rescue_consecutive)
          latent_v_rescue_count_trace[iter] <- latent_v_rescue_count
          latent_v_rescue_consecutive_trace[iter] <- latent_v_rescue_consecutive
          if (iter > n_burn) {
            latent_v_rescues_keep <- latent_v_rescues_keep + 1L
          } else {
            latent_v_rescues_burn <- latent_v_rescues_burn + 1L
          }
          if (isTRUE(latent_v_rescue_force_retry_next_iter)) latent_v_force_pending <- TRUE
        } else {
          .exal_mcmc_stop_latent_v_error(
            parent = sampled_v,
            iter = iter,
            n_burn = n_burn,
            likelihood_family = likelihood_family,
            beta_prior_type = beta_prior_type,
            sigma = sigma,
            gamma = gamma,
            beta = beta,
            s = s,
            rhs_state = rhs_state,
            latent_v_reason = latent_v_update_reason,
            latent_v_warmup_active = latent_v_warmup_active_trace[iter],
            latent_v_hard_freeze_active = latent_v_hard_freeze_trace[iter],
            latent_v_sparse_window_active = latent_v_sparse_window_trace[iter],
            latent_v_rescue_enabled = latent_v_rescue_on_invalid,
            latent_v_rescue_strategy = latent_v_rescue_strategy,
            latent_v_rescue_count = latent_v_rescue_count,
            latent_v_rescue_consecutive = latent_v_rescue_consecutive,
            latent_s_reason = latent_s_update_reason,
            latent_s_warmup_active = latent_s_warmup_active_trace[iter],
            latent_s_hard_freeze_active = latent_s_hard_freeze_trace[iter],
            latent_s_sparse_window_active = latent_s_sparse_window_trace[iter],
            theta_reason = theta_update_reason,
            theta_warmup_active = theta_warmup_active_trace[iter],
            theta_hard_freeze_active = theta_hard_freeze_trace[iter],
            theta_sparse_window_active = theta_sparse_window_trace[iter],
            chi_v = chi_v,
            psi_v = psi_v,
            z_v = z_v
          )
        }
      } else {
        v <- pmax(sampled_v, 1e-12)
        latent_v_update_performed_trace[iter] <- TRUE
        latent_v_update_count <- latent_v_update_count + 1L
        latent_v_rescue_consecutive <- 0L
        if (iter > n_burn) {
          latent_v_updates_keep <- latent_v_updates_keep + 1L
        } else {
          latent_v_updates_burn <- latent_v_updates_burn + 1L
        }
        if (isTRUE(latent_v_force_now) && is.na(latent_v_first_postwarmup_update_iter)) {
          latent_v_first_postwarmup_update_iter <- as.integer(iter)
        }
        if (isTRUE(latent_v_force_now)) latent_v_force_pending <- FALSE
      }
      latent_v_update_count_trace[iter] <- latent_v_update_count
      latent_v_rescue_count_trace[iter] <- latent_v_rescue_count
      latent_v_rescue_consecutive_trace[iter] <- latent_v_rescue_consecutive
    } else {
      latent_v_update_count_trace[iter] <- latent_v_update_count
      latent_v_rescue_count_trace[iter] <- latent_v_rescue_count
      latent_v_rescue_consecutive_trace[iter] <- latent_v_rescue_consecutive
    }

    r_s <- y - drop(X %*% beta) - A * v
    tau2_s <- 1 / (1 + (Cabs * Cabs) * sigma / (B * v))
    tau2_s <- pmax(tau2_s, 1e-12)
    mu_s <- tau2_s * (Cabs * r_s) / (B * v)
    if (isTRUE(latent_s_update_now)) {
      s <- as.numeric(sample_truncnorm(1L, n, sts_mu = mu_s, sts_sig2 = tau2_s)[1L, ])
      s <- pmax(s, 0)
      latent_s_update_performed_trace[iter] <- TRUE
      latent_s_update_count <- latent_s_update_count + 1L
      if (iter > n_burn) {
        latent_s_updates_keep <- latent_s_updates_keep + 1L
      } else {
        latent_s_updates_burn <- latent_s_updates_burn + 1L
      }
      if (isTRUE(latent_s_force_now) && is.na(latent_s_first_postwarmup_update_iter)) {
        latent_s_first_postwarmup_update_iter <- as.integer(iter)
      }
      if (isTRUE(latent_s_force_now)) latent_s_force_pending <- FALSE
    }
    latent_s_update_count_trace[iter] <- latent_s_update_count

    W_diag <- 1 / (B * sigma * v)
    y_star <- y - Cabs * sigma * s - A * v
    if (isTRUE(theta_update_now)) {
      beta_prec_diag_work <- sweep(beta_draw_transform_inv, 1L, beta_prec_diag, `*`)
      prior_prec_work <- crossprod(beta_draw_transform_inv, beta_prec_diag_work)
      Prec_beta <- crossprod(beta_draw_design * sqrt(W_diag)) + prior_prec_work
      rhs_beta <- crossprod(beta_draw_design, W_diag * y_star)
      beta_draw <- .exal_mcmc_sample_mvnorm_prec(
        rhs_beta,
        Prec_beta,
        precision_beta_cfg = list(
          enabled = precision_beta_enabled,
          symmetrize = precision_beta_symmetrize,
          jitter_ladder = precision_beta_jitter_ladder,
          eigen_fallback = precision_beta_eigen_fallback,
          eigen_floor_abs = precision_beta_eigen_floor_abs,
          eigen_floor_rel = precision_beta_eigen_floor_rel,
          trace = precision_beta_trace_enabled
        ),
        context = list(
          iter = iter,
          n_burn = n_burn,
          likelihood_family = likelihood_family,
          beta_prior_type = beta_prior_type,
          rhs_state = rhs_state,
          sigma = sigma,
          gamma = gamma,
          beta = beta,
          latent_v_reason = latent_v_update_reason,
          latent_v_warmup_active = latent_v_warmup_active_trace[iter],
          theta_reason = theta_update_reason,
          theta_warmup_active = theta_warmup_active_trace[iter],
          conditioning_mode = conditioning_mode,
          core_update_mode = core_update_mode
        )
      )
      beta_work <- beta_draw$draw
      beta <- as.numeric(beta_draw_transform_inv %*% beta_work)
      beta_draw_info <- beta_draw$info %||% list()
      strategy <- as.character(beta_draw_info$strategy %||% "direct")[1L]
      jitter_used <- as.numeric(beta_draw_info$jitter_used %||% 0)[1L]
      if (identical(strategy, "direct")) {
        precision_beta_direct_successes <- precision_beta_direct_successes + 1L
      } else if (grepl("^eigen", strategy)) {
        precision_beta_eigen_successes <- precision_beta_eigen_successes + 1L
        precision_beta_rescue_count <- precision_beta_rescue_count + 1L
      } else {
        precision_beta_jitter_successes <- precision_beta_jitter_successes + 1L
        precision_beta_rescue_count <- precision_beta_rescue_count + 1L
      }
      if (!identical(strategy, "direct") && is.na(precision_beta_first_rescue_iter)) {
        precision_beta_first_rescue_iter <- as.integer(iter)
      }
      if (is.finite(jitter_used)) {
        precision_beta_max_jitter_used <- max(precision_beta_max_jitter_used, jitter_used)
      }
      theta_update_performed_trace[iter] <- TRUE
      theta_update_count <- theta_update_count + 1L
      if (iter > n_burn) {
        theta_updates_keep <- theta_updates_keep + 1L
      } else {
        theta_updates_burn <- theta_updates_burn + 1L
      }
      if (isTRUE(theta_force_now) && is.na(theta_first_postwarmup_update_iter)) {
        theta_first_postwarmup_update_iter <- as.integer(iter)
      }
      if (isTRUE(theta_force_now)) theta_force_pending <- FALSE
    }
    theta_update_count_trace[iter] <- theta_update_count

    rhs_stats <- NULL
    if (is_rhs_family) {
      freeze_tau_now <- isTRUE(
        rhs_freeze_tau_iters > 0L &&
          iter <= rhs_freeze_tau_iters &&
          (!rhs_freeze_tau_only_during_burn || iter <= n_burn)
      )
      rhs_upd <- if (is_rhs) {
        .exal_mcmc_rhs_slice_update(
          state = rhs_state,
          beta = beta,
          beta_prior_obj = beta_prior_obj,
          slice_cfg = slice_cfg_runtime,
          freeze_tau = freeze_tau_now
        )
      } else {
        .exal_mcmc_rhs_ns_gibbs_update(
          state = rhs_state,
          beta = beta,
          beta_prior_obj = beta_prior_obj,
          freeze_tau = freeze_tau_now
        )
      }
      rhs_state <- rhs_upd$state
      rhs_stats <- rhs_upd$stats
      beta_prec_diag <- if (is_rhs) {
        .exal_mcmc_rhs_precisions(rhs_state, p = p)
      } else {
        .exal_mcmc_rhs_ns_precisions(rhs_state, p = p)
      }

      rhs_tau_trace[iter] <- rhs_stats$tau
      rhs_c2_trace[iter] <- rhs_stats$c2
      rhs_lambda_mean_trace[iter] <- rhs_stats$lambda_mean
      rhs_lambda_min_trace[iter] <- rhs_stats$lambda_min
      rhs_lambda_max_trace[iter] <- rhs_stats$lambda_max
      rhs_tau_steps_out[iter] <- rhs_stats$tau_steps_out
      rhs_tau_shrink[iter] <- rhs_stats$tau_shrink
      rhs_c2_steps_out[iter] <- rhs_stats$c2_steps_out
      rhs_c2_shrink[iter] <- rhs_stats$c2_shrink
      rhs_lambda_steps_out_mean[iter] <- rhs_stats$lambda_steps_out_mean
      rhs_lambda_steps_out_max[iter] <- rhs_stats$lambda_steps_out_max
      rhs_lambda_shrink_mean[iter] <- rhs_stats$lambda_shrink_mean
      rhs_lambda_shrink_max[iter] <- rhs_stats$lambda_shrink_max
      rhs_tau_frozen_trace[iter] <- isTRUE(rhs_stats$tau_frozen)
      rhs_global_block_used_trace[iter] <- isTRUE(rhs_stats$global_block_used)
      rhs_global_block_steps_out[iter] <- as.integer(rhs_stats$global_block_steps_out %||% 0L)
      rhs_global_block_shrink[iter] <- as.integer(rhs_stats$global_block_shrink %||% 0L)
      rhs_global_block_dir_tau[iter] <- as.numeric(rhs_stats$global_block_dir_tau %||% 0)
      rhs_global_block_dir_c2[iter] <- as.numeric(rhs_stats$global_block_dir_c2 %||% 0)
      rhs_global_block_transformed_passes[iter] <- as.integer(rhs_stats$global_block_transformed_passes %||% 0L)
      rhs_transformed_z1_steps_out[iter] <- as.integer(rhs_stats$transformed_z1_steps_out %||% 0L)
      rhs_transformed_z1_shrink[iter] <- as.integer(rhs_stats$transformed_z1_shrink %||% 0L)
      rhs_transformed_z2_steps_out[iter] <- as.integer(rhs_stats$transformed_z2_steps_out %||% 0L)
      rhs_transformed_z2_shrink[iter] <- as.integer(rhs_stats$transformed_z2_shrink %||% 0L)

      width_adapt_active_now <- isTRUE(
        is_rhs &&
          width_adapt_enabled &&
          iter <= width_adapt_warmup_iters &&
          (!width_adapt_only_during_burn || iter <= n_burn)
      )
      rhs_width_adapt_active_trace[iter] <- width_adapt_active_now
      if (isTRUE(width_adapt_active_now)) {
        rhs_width_adapt_iter <- rhs_width_adapt_iter + 1L
        step_now <- width_adapt_step_size / sqrt(rhs_width_adapt_iter)
        score_lambda <- as.numeric(rhs_stats$lambda_steps_out_mean) - as.numeric(rhs_stats$lambda_shrink_mean)
        score_tau <- as.numeric(rhs_stats$tau_steps_out) - as.numeric(rhs_stats$tau_shrink)
        score_c2 <- as.numeric(rhs_stats$c2_steps_out) - as.numeric(rhs_stats$c2_shrink)
        slice_cfg_runtime$width_rhs_lambda <- adapt_width_one(slice_cfg_runtime$width_rhs_lambda, score_lambda, step_now)
        slice_cfg_runtime$width_rhs_tau <- adapt_width_one(slice_cfg_runtime$width_rhs_tau, score_tau, step_now)
        slice_cfg_runtime$width_rhs_c2 <- adapt_width_one(slice_cfg_runtime$width_rhs_c2, score_c2, step_now)

        if (identical(as.character(rhs_stats$global_block_mode), "directional_tau_c2") && isTRUE(rhs_stats$global_block_used)) {
          score_block <- as.numeric(rhs_stats$global_block_steps_out) - as.numeric(rhs_stats$global_block_shrink)
          slice_cfg_runtime$width_rhs_tau_c2_block <- adapt_width_one(slice_cfg_runtime$width_rhs_tau_c2_block, score_block, step_now)
        }
        if (identical(as.character(rhs_stats$global_block_mode), "transformed_tau_c2_block")) {
          score_z1 <- as.numeric(rhs_stats$transformed_z1_steps_out) - as.numeric(rhs_stats$transformed_z1_shrink)
          score_z2 <- as.numeric(rhs_stats$transformed_z2_steps_out) - as.numeric(rhs_stats$transformed_z2_shrink)
          if (is.finite(score_z1)) {
            slice_cfg_runtime$width_rhs_tau_c2_transformed_z1 <- adapt_width_one(
              slice_cfg_runtime$width_rhs_tau_c2_transformed_z1,
              score_z1,
              step_now
            )
          }
          if (is.finite(score_z2)) {
            slice_cfg_runtime$width_rhs_tau_c2_transformed_z2 <- adapt_width_one(
              slice_cfg_runtime$width_rhs_tau_c2_transformed_z2,
              score_z2,
              step_now
            )
          }
        }
      }
      rhs_width_lambda_trace[iter] <- as.numeric(slice_cfg_runtime$width_rhs_lambda %||% NA_real_)
      rhs_width_tau_trace[iter] <- as.numeric(slice_cfg_runtime$width_rhs_tau %||% NA_real_)
      rhs_width_c2_trace[iter] <- as.numeric(slice_cfg_runtime$width_rhs_c2 %||% NA_real_)
      rhs_width_tau_c2_block_trace[iter] <- as.numeric(slice_cfg_runtime$width_rhs_tau_c2_block %||% NA_real_)
      rhs_width_tau_c2_transformed_z1_trace[iter] <- as.numeric(slice_cfg_runtime$width_rhs_tau_c2_transformed_z1 %||% NA_real_)
      rhs_width_tau_c2_transformed_z2_trace[iter] <- as.numeric(slice_cfg_runtime$width_rhs_tau_c2_transformed_z2 %||% NA_real_)
      if (is_rhs_ns) {
        rhs_width_lambda_trace[iter] <- NA_real_
        rhs_width_tau_trace[iter] <- NA_real_
        rhs_width_c2_trace[iter] <- NA_real_
        rhs_width_tau_c2_block_trace[iter] <- NA_real_
        rhs_width_tau_c2_transformed_z1_trace[iter] <- NA_real_
        rhs_width_tau_c2_transformed_z2_trace[iter] <- NA_real_
      }
    }

    sigmagam_warmup_active <- isTRUE(
      sigmagam_freeze_burnin_iters > 0L &&
        iter <= sigmagam_freeze_burnin_iters &&
        (!sigmagam_freeze_only_during_burn || iter <= n_burn)
    )
    sigmagam_force_now <- isTRUE(
      !sigmagam_warmup_active &&
        sigmagam_freeze_burnin_iters > 0L &&
        sigmagam_force_after_warmup &&
        sigmagam_postwarmup_update_count <= 0L
    )
    sigmagam_update_reason <- if (isTRUE(sigmagam_warmup_active)) {
      "warmup"
    } else if (isTRUE(sigmagam_force_now)) {
      "force_after_warmup"
    } else {
      "scheduled"
    }
    sigmagam_frozen_trace[iter] <- isTRUE(sigmagam_warmup_active)

    if (!isTRUE(sigmagam_warmup_active)) {
      gamma_steps_iter <- 0L
      gamma_shrink_iter <- 0L
      for (core_pass in seq_len(core_passes_total)) {
        core_upd <- update_sigma_gamma_once(
          beta_now = beta,
          v_now = v,
          s_now = s,
          sigma_now = sigma,
          eta_sigma_now = eta_sigma,
          eta_gamma_now = eta_gamma
        )
        sigma <- as.numeric(core_upd$sigma)[1L]
        eta_sigma <- as.numeric(core_upd$eta_sigma)[1L]
        gamma <- as.numeric(core_upd$gamma)[1L]
        eta_gamma <- as.numeric(core_upd$eta_gamma)[1L]
        gamma_steps_iter <- gamma_steps_iter + as.integer(core_upd$gamma_steps_out)
        gamma_shrink_iter <- gamma_shrink_iter + as.integer(core_upd$gamma_shrink)
      }
      gamma_steps_out[iter] <- gamma_steps_iter
      gamma_shrink[iter] <- gamma_shrink_iter
      sigmagam_update_performed_trace[iter] <- TRUE
      sigmagam_update_count <- sigmagam_update_count + 1L
      sigmagam_update_count_trace[iter] <- sigmagam_update_count
      if (is.na(sigmagam_first_active_iter)) sigmagam_first_active_iter <- as.integer(iter)
      if (iter > n_burn) {
        sigmagam_updates_keep <- sigmagam_updates_keep + 1L
      } else {
        sigmagam_updates_burn <- sigmagam_updates_burn + 1L
      }
      if (sigmagam_freeze_burnin_iters > 0L) {
        sigmagam_postwarmup_update_count <- sigmagam_postwarmup_update_count + 1L
      }
      sigmagam_forced_postwarmup_trace[iter] <- isTRUE(sigmagam_force_now)
    } else {
      sigmagam_update_count_trace[iter] <- sigmagam_update_count
      sigmagam_forced_postwarmup_trace[iter] <- FALSE
    }
    sigmagam_update_reason_trace[iter] <- sigmagam_update_reason
    gamma_trace[iter] <- as.numeric(gamma)[1L]
    sigma_trace[iter] <- as.numeric(sigma)[1L]

    if (iter > n_burn && ((iter - n_burn) %% thin == 0L)) {
      save_idx <- save_idx + 1L
      beta_draws[save_idx, ] <- beta
      sigma_draws[save_idx] <- sigma
      gamma_draws[save_idx] <- gamma
      if (store_latent_draws) {
        v_draws[save_idx, ] <- v
        s_draws[save_idx, ] <- s
      }
      if (is_rhs_family) {
        tau_draws[save_idx] <- rhs_stats$tau
        c2_draws[save_idx] <- rhs_stats$c2
        lambda_mean_draws[save_idx] <- rhs_stats$lambda_mean
        lambda_min_draws[save_idx] <- rhs_stats$lambda_min
        lambda_max_draws[save_idx] <- rhs_stats$lambda_max
        if (store_rhs_draws) {
          if (is_rhs) {
            lambda_draws[save_idx, ] <- exp(as.numeric(rhs_state$eta_lambda_hat))
          } else {
            lambda_draws[save_idx, ] <- sqrt(pmax(as.numeric(rhs_state$lambda2), 1e-16))
          }
        }
      }
    }

    if (verbose && (iter %% progress_every == 0L)) {
      if (is_rhs_family) {
        cat(sprintf("%s iteration %d | sigma=%.3f | gamma=%.3f | tau=%.3f | c2=%.3f\n",
                    ifelse(iter <= n_burn, "burn-in", "MCMC"), iter, sigma, gamma,
                    rhs_stats$tau, rhs_stats$c2))
      } else {
        cat(sprintf("%s iteration %d | sigma=%.3f | gamma=%.3f\n",
                    ifelse(iter <= n_burn, "burn-in", "MCMC"), iter, sigma, gamma))
      }
    }
  }
  runtime <- as.numeric(proc.time()[3L] - t0)

  beta_mean <- colMeans(beta_draws)
  beta_median <- apply(beta_draws, 2L, stats::median)
  sigma_mean <- mean(sigma_draws)
  gamma_mean <- mean(gamma_draws)
  summary_out <- list(
    beta_mean = beta_mean,
    beta_median = beta_median,
    sigma_mean = sigma_mean,
    gamma_mean = gamma_mean
  )
    diagnostics_out <- list(
    core_update_mode = core_update_mode,
    core_sigma_gamma_passes_per_iter = as.integer(core_passes_total),
    core_gamma_refreshes_per_iter = as.integer(
      if (is_al) 0L else if (identical(core_update_mode, "gamma_sigma_gamma")) 2L * core_passes_total else core_passes_total
    ),
    gamma_slice_steps_out_mean = .mean_or_na(gamma_steps_out),
    gamma_slice_steps_out_max = .max_or_na(gamma_steps_out),
    gamma_slice_shrink_mean = .mean_or_na(gamma_shrink),
    gamma_slice_shrink_max = .max_or_na(gamma_shrink),
    latent_v = list(
      enabled = isTRUE(latent_v_enabled),
      freeze_burnin_iters = as.integer(latent_v_freeze_burnin_iters),
      freeze_only_during_burn = isTRUE(latent_v_freeze_only_during_burn),
      sparse_update_every = as.integer(latent_v_sparse_update_every),
      sparse_update_until_iter = as.integer(latent_v_sparse_update_until_iter),
      force_first_postwarmup_update = isTRUE(latent_v_force_first_postwarmup_update),
      rescue_on_invalid = isTRUE(latent_v_rescue_on_invalid),
      rescue_strategy = latent_v_rescue_strategy,
      rescue_max_consecutive = as.integer(latent_v_rescue_max_consecutive),
      rescue_burn_only = isTRUE(latent_v_rescue_burn_only),
      rescue_force_retry_next_iter = isTRUE(latent_v_rescue_force_retry_next_iter),
      first_postwarmup_update_iter = if (is.na(latent_v_first_postwarmup_update_iter)) NA_integer_ else as.integer(latent_v_first_postwarmup_update_iter),
      updates_burn = as.integer(latent_v_updates_burn),
      updates_keep = as.integer(latent_v_updates_keep),
      update_count = as.integer(latent_v_update_count),
      rescues_burn = as.integer(latent_v_rescues_burn),
      rescues_keep = as.integer(latent_v_rescues_keep),
      rescue_count = as.integer(latent_v_rescue_count),
      rescue_max_streak = as.integer(latent_v_rescue_max_streak),
      frozen_burn_rate = if (n_burn > 0L) mean(latent_v_hard_freeze_trace[seq_len(n_burn)]) else NA_real_,
      sparse_hold_burn_rate = if (n_burn > 0L) {
        mean(latent_v_sparse_window_trace[seq_len(n_burn)] & !latent_v_update_performed_trace[seq_len(n_burn)])
      } else {
        NA_real_
      },
      rescue_burn_rate = if (n_burn > 0L) {
        mean(latent_v_rescue_applied_trace[seq_len(n_burn)])
      } else {
        NA_real_
      }
    ),
    latent_s = list(
      enabled = isTRUE(latent_s_enabled),
      freeze_burnin_iters = as.integer(latent_s_freeze_burnin_iters),
      freeze_only_during_burn = isTRUE(latent_s_freeze_only_during_burn),
      sparse_update_every = as.integer(latent_s_sparse_update_every),
      sparse_update_until_iter = as.integer(latent_s_sparse_update_until_iter),
      force_first_postwarmup_update = isTRUE(latent_s_force_first_postwarmup_update),
      first_postwarmup_update_iter = if (is.na(latent_s_first_postwarmup_update_iter)) NA_integer_ else as.integer(latent_s_first_postwarmup_update_iter),
      updates_burn = as.integer(latent_s_updates_burn),
      updates_keep = as.integer(latent_s_updates_keep),
      update_count = as.integer(latent_s_update_count),
      frozen_burn_rate = if (n_burn > 0L) mean(latent_s_hard_freeze_trace[seq_len(n_burn)]) else NA_real_,
      sparse_hold_burn_rate = if (n_burn > 0L) {
        mean(latent_s_sparse_window_trace[seq_len(n_burn)] & !latent_s_update_performed_trace[seq_len(n_burn)])
      } else {
        NA_real_
      }
    ),
    theta = list(
      enabled = isTRUE(theta_enabled),
      target = "beta",
      freeze_burnin_iters = as.integer(theta_freeze_burnin_iters),
      freeze_only_during_burn = isTRUE(theta_freeze_only_during_burn),
      sparse_update_every = as.integer(theta_sparse_update_every),
      sparse_update_until_iter = as.integer(theta_sparse_update_until_iter),
      force_first_postwarmup_update = isTRUE(theta_force_first_postwarmup_update),
      first_postwarmup_update_iter = if (is.na(theta_first_postwarmup_update_iter)) NA_integer_ else as.integer(theta_first_postwarmup_update_iter),
      updates_burn = as.integer(theta_updates_burn),
      updates_keep = as.integer(theta_updates_keep),
      update_count = as.integer(theta_update_count),
      frozen_burn_rate = if (n_burn > 0L) mean(theta_hard_freeze_trace[seq_len(n_burn)]) else NA_real_,
      sparse_hold_burn_rate = if (n_burn > 0L) {
        mean(theta_sparse_window_trace[seq_len(n_burn)] & !theta_update_performed_trace[seq_len(n_burn)])
      } else {
        NA_real_
      }
    ),
    sigmagam = list(
      freeze_burnin_iters = as.integer(sigmagam_freeze_burnin_iters),
      freeze_only_during_burn = isTRUE(sigmagam_freeze_only_during_burn),
      force_after_warmup = isTRUE(sigmagam_force_after_warmup),
      delay_adapt_until_after_warmup = isTRUE(sigmagam_delay_adapt_until_after_warmup),
      delay_laplace_refresh_until_after_warmup = isTRUE(sigmagam_delay_laplace_refresh_until_after_warmup),
      first_active_iter = if (is.na(sigmagam_first_active_iter)) NA_integer_ else as.integer(sigmagam_first_active_iter),
      updates_burn = as.integer(sigmagam_updates_burn),
      updates_keep = as.integer(sigmagam_updates_keep),
      update_count = as.integer(sigmagam_update_count),
      postwarmup_update_count = as.integer(sigmagam_postwarmup_update_count),
      frozen_burn_rate = if (n_burn > 0L) mean(sigmagam_frozen_trace[seq_len(n_burn)]) else NA_real_
    ),
    conditioning = list(
      mode = conditioning_state$mode,
      active = isTRUE(conditioning_state$active),
      scale_metric = conditioning_state$scale_metric,
      scale_floor = as.numeric(conditioning_state$scale_floor),
      constant_tol = as.numeric(conditioning_state$constant_tol),
      intercept_column = as.integer(conditioning_state$intercept_column),
      scaled_columns_n = as.integer(conditioning_state$scaled_columns_n),
      gram_ridge = as.numeric(conditioning_gram_ridge),
      raw_condition_kappa = as.numeric(conditioning_state$raw_kappa),
      conditioned_condition_kappa = as.numeric(conditioning_state$work_kappa),
      condition_gain_ratio = as.numeric(conditioning_state$gain_ratio),
      scale_min = as.numeric(conditioning_state$scale_min),
      scale_max = as.numeric(conditioning_state$scale_max)
    ),
    precision_beta = list(
      preset = as.character(precision_beta_preset),
      enabled = isTRUE(precision_beta_enabled),
      symmetrize = isTRUE(precision_beta_symmetrize),
      jitter_ladder = as.numeric(precision_beta_jitter_ladder),
      eigen_fallback = isTRUE(precision_beta_eigen_fallback),
      eigen_floor_abs = as.numeric(precision_beta_eigen_floor_abs),
      eigen_floor_rel = as.numeric(precision_beta_eigen_floor_rel),
      direct_successes = as.integer(precision_beta_direct_successes),
      jitter_successes = as.integer(precision_beta_jitter_successes),
      eigen_successes = as.integer(precision_beta_eigen_successes),
      rescue_count = as.integer(precision_beta_rescue_count),
      first_rescue_iter = if (is.na(precision_beta_first_rescue_iter)) NA_integer_ else as.integer(precision_beta_first_rescue_iter),
      max_jitter_used = as.numeric(precision_beta_max_jitter_used)
    )
  )
  beta_prior_out <- list(type = beta_prior_obj$type, hypers = beta_prior_obj$hypers)

  if (is_rhs_family) {
    summary_out$rhs <- list(
      tau_mean = mean(tau_draws),
      c2_mean = mean(c2_draws),
      lambda_mean = .mean_or_na(lambda_mean_draws),
      lambda_min = .mean_or_na(lambda_min_draws),
      lambda_max = .mean_or_na(lambda_max_draws)
    )
    diagnostics_out$rhs <- list(
      tau_slice_steps_out_mean = mean(rhs_tau_steps_out),
      tau_slice_steps_out_max = max(rhs_tau_steps_out),
      tau_slice_shrink_mean = mean(rhs_tau_shrink),
      tau_slice_shrink_max = max(rhs_tau_shrink),
      c2_slice_steps_out_mean = mean(rhs_c2_steps_out),
      c2_slice_steps_out_max = max(rhs_c2_steps_out),
      c2_slice_shrink_mean = mean(rhs_c2_shrink),
      c2_slice_shrink_max = max(rhs_c2_shrink),
      lambda_slice_steps_out_mean = mean(rhs_lambda_steps_out_mean),
      lambda_slice_steps_out_max = max(rhs_lambda_steps_out_max),
      lambda_slice_shrink_mean = mean(rhs_lambda_shrink_mean),
      lambda_slice_shrink_max = max(rhs_lambda_shrink_max),
      global_block_update_mode = if (is_rhs) {
        as.character(slice_cfg_runtime$rhs_global_block_update %||% "coordinate")
      } else {
        "gibbs"
      },
      global_block_used_rate = mean(rhs_global_block_used_trace),
      global_block_steps_out_mean = mean(rhs_global_block_steps_out),
      global_block_steps_out_max = max(rhs_global_block_steps_out),
      global_block_shrink_mean = mean(rhs_global_block_shrink),
      global_block_shrink_max = max(rhs_global_block_shrink),
      global_block_transformed_passes_mean = mean(rhs_global_block_transformed_passes),
      transformed_z1_steps_out_mean = mean(rhs_transformed_z1_steps_out),
      transformed_z1_shrink_mean = mean(rhs_transformed_z1_shrink),
      transformed_z2_steps_out_mean = mean(rhs_transformed_z2_steps_out),
      transformed_z2_shrink_mean = mean(rhs_transformed_z2_shrink),
      width_adapt_enabled = isTRUE(is_rhs && width_adapt_enabled),
      width_adapt_warmup_iters = as.integer(width_adapt_warmup_iters),
      width_adapt_active_rate = mean(rhs_width_adapt_active_trace),
      width_rhs_lambda_initial = as.numeric(rhs_slice_widths_initial$width_rhs_lambda %||% NA_real_),
      width_rhs_tau_initial = as.numeric(rhs_slice_widths_initial$width_rhs_tau %||% NA_real_),
      width_rhs_c2_initial = as.numeric(rhs_slice_widths_initial$width_rhs_c2 %||% NA_real_),
      width_rhs_tau_c2_block_initial = as.numeric(rhs_slice_widths_initial$width_rhs_tau_c2_block %||% NA_real_),
      width_rhs_tau_c2_transformed_z1_initial = as.numeric(rhs_slice_widths_initial$width_rhs_tau_c2_transformed_z1 %||% NA_real_),
      width_rhs_tau_c2_transformed_z2_initial = as.numeric(rhs_slice_widths_initial$width_rhs_tau_c2_transformed_z2 %||% NA_real_),
      width_rhs_lambda_final = as.numeric(slice_cfg_runtime$width_rhs_lambda %||% NA_real_),
      width_rhs_tau_final = as.numeric(slice_cfg_runtime$width_rhs_tau %||% NA_real_),
      width_rhs_c2_final = as.numeric(slice_cfg_runtime$width_rhs_c2 %||% NA_real_),
      width_rhs_tau_c2_block_final = as.numeric(slice_cfg_runtime$width_rhs_tau_c2_block %||% NA_real_),
      width_rhs_tau_c2_transformed_z1_final = as.numeric(slice_cfg_runtime$width_rhs_tau_c2_transformed_z1 %||% NA_real_),
      width_rhs_tau_c2_transformed_z2_final = as.numeric(slice_cfg_runtime$width_rhs_tau_c2_transformed_z2 %||% NA_real_)
    )
    beta_prior_out$state <- rhs_state
  }

  structure(list(
    method = "mcmc",
    control = list(
      likelihood_family = likelihood_family,
      al_fixed_gamma = if (is_al) as.numeric(al_gamma_fixed) else NA_real_,
      n_burn = n_burn,
      n_mcmc = n_keep,
      thin = thin,
      rng_seed = if (is.null(rng_seed)) NA_integer_ else rng_seed,
      verbose = verbose,
      progress_every = progress_every,
      init_from_vb = init_from_vb,
      vb_warm_start_seed = if (is.null(vb_warm_start_seed)) NA_integer_ else vb_warm_start_seed,
      vb_warm_start_control = mcmc_control$vb_warm_start_control %||% list(),
      theta = list(
        enabled = isTRUE(theta_enabled),
        target = "beta",
        freeze_burnin_iters = as.integer(theta_freeze_burnin_iters),
        freeze_only_during_burn = isTRUE(theta_freeze_only_during_burn),
        sparse_update_every = as.integer(theta_sparse_update_every),
        sparse_update_until_iter = as.integer(theta_sparse_update_until_iter),
        force_first_postwarmup_update = isTRUE(theta_force_first_postwarmup_update),
        trace = isTRUE(theta_trace_enabled)
      ),
      latent_v = list(
        enabled = isTRUE(latent_v_enabled),
        freeze_burnin_iters = as.integer(latent_v_freeze_burnin_iters),
        freeze_only_during_burn = isTRUE(latent_v_freeze_only_during_burn),
        sparse_update_every = as.integer(latent_v_sparse_update_every),
        sparse_update_until_iter = as.integer(latent_v_sparse_update_until_iter),
        force_first_postwarmup_update = isTRUE(latent_v_force_first_postwarmup_update),
        rescue_on_invalid = isTRUE(latent_v_rescue_on_invalid),
        rescue_strategy = latent_v_rescue_strategy,
        rescue_max_consecutive = as.integer(latent_v_rescue_max_consecutive),
        rescue_burn_only = isTRUE(latent_v_rescue_burn_only),
        rescue_force_retry_next_iter = isTRUE(latent_v_rescue_force_retry_next_iter),
        record_rescue_trace = isTRUE(latent_v_record_rescue_trace),
        trace = isTRUE(latent_v_trace_enabled)
      ),
      latent_s = list(
        enabled = isTRUE(latent_s_enabled),
        freeze_burnin_iters = as.integer(latent_s_freeze_burnin_iters),
        freeze_only_during_burn = isTRUE(latent_s_freeze_only_during_burn),
        sparse_update_every = as.integer(latent_s_sparse_update_every),
        sparse_update_until_iter = as.integer(latent_s_sparse_update_until_iter),
        force_first_postwarmup_update = isTRUE(latent_s_force_first_postwarmup_update),
        trace = isTRUE(latent_s_trace_enabled)
      ),
      sigmagam = list(
        freeze_burnin_iters = as.integer(sigmagam_freeze_burnin_iters),
        freeze_only_during_burn = isTRUE(sigmagam_freeze_only_during_burn),
        force_after_warmup = isTRUE(sigmagam_force_after_warmup),
        delay_adapt_until_after_warmup = isTRUE(sigmagam_delay_adapt_until_after_warmup),
        delay_laplace_refresh_until_after_warmup = isTRUE(sigmagam_delay_laplace_refresh_until_after_warmup)
      ),
      multi_start = list(
        enabled = isTRUE(multi_start_enabled) && !isTRUE(multi_start_internal),
        internal = isTRUE(multi_start_internal),
        n_starts = as.integer(multi_start_cfg$n_starts %||% NA_integer_),
        pilot_n_burn = as.integer(multi_start_cfg$pilot_n_burn %||% NA_integer_),
        pilot_n_mcmc = as.integer(multi_start_cfg$pilot_n_mcmc %||% NA_integer_)
      ),
      store_latent_draws = store_latent_draws,
      store_rhs_draws = store_rhs_draws,
      transforms = list(
        use_log_sigma = isTRUE(use_log_sigma),
        sigma_eta_bounds = as.numeric(sigma_eta_bounds)
      ),
      conditioning = list(
        mode = conditioning_state$mode,
        active = isTRUE(conditioning_state$active),
        scale_metric = conditioning_state$scale_metric,
        scale_floor = as.numeric(conditioning_state$scale_floor),
        constant_tol = as.numeric(conditioning_state$constant_tol),
        intercept_column = as.integer(conditioning_state$intercept_column),
        gram_ridge = as.numeric(conditioning_gram_ridge)
      ),
      precision_beta = list(
        preset = as.character(precision_beta_preset),
        enabled = isTRUE(precision_beta_enabled),
        symmetrize = isTRUE(precision_beta_symmetrize),
        jitter_ladder = as.numeric(precision_beta_jitter_ladder),
        eigen_fallback = isTRUE(precision_beta_eigen_fallback),
        eigen_floor_abs = as.numeric(precision_beta_eigen_floor_abs),
        eigen_floor_rel = as.numeric(precision_beta_eigen_floor_rel),
        trace = isTRUE(precision_beta_trace_enabled)
      ),
      rhs = list(
        freeze_tau_burnin_iters = rhs_freeze_tau_iters,
        freeze_tau_only_during_burn = rhs_freeze_tau_only_during_burn,
        width_adapt = list(
          enabled = isTRUE(width_adapt_enabled),
          warmup_iters = as.integer(width_adapt_warmup_iters),
          only_during_burn = isTRUE(width_adapt_only_during_burn),
          target_score_low = as.numeric(width_adapt_target_score_low),
          target_score_high = as.numeric(width_adapt_target_score_high),
          step_size = as.numeric(width_adapt_step_size),
          width_min = as.numeric(width_adapt_min),
          width_max = as.numeric(width_adapt_max)
        )
      ),
      slice = list(
        core_update_mode = core_update_mode,
        width_gamma = gamma_slice_width,
        width_sigma = if (isTRUE(use_log_sigma)) sigma_slice_width else NA_real_,
        width_rhs_lambda = as.numeric(slice_cfg_runtime$width_rhs_lambda %||% slice_cfg_runtime$width_lambda %||% 1.0)[1L],
        width_rhs_tau = as.numeric(slice_cfg_runtime$width_rhs_tau %||% slice_cfg_runtime$width_tau %||% 1.0)[1L],
        width_rhs_c2 = as.numeric(slice_cfg_runtime$width_rhs_c2 %||% slice_cfg_runtime$width_c2 %||% 1.0)[1L],
        width_rhs_tau_c2_block = as.numeric(slice_cfg_runtime$width_rhs_tau_c2_block %||% 1.0)[1L],
        width_rhs_tau_c2_transformed_z1 = as.numeric(slice_cfg_runtime$width_rhs_tau_c2_transformed_z1 %||% slice_cfg_runtime$width_rhs_tau_c2_block %||% 1.0)[1L],
        width_rhs_tau_c2_transformed_z2 = as.numeric(slice_cfg_runtime$width_rhs_tau_c2_transformed_z2 %||% slice_cfg_runtime$width_rhs_tau_c2_block %||% 1.0)[1L],
        rhs_global_block_update = as.character(slice_cfg_runtime$rhs_global_block_update %||% "coordinate"),
        rhs_transformed_block_passes = as.integer(slice_cfg_runtime$rhs_transformed_block_passes %||% 1L),
        core_extra_passes = as.integer(core_extra_passes),
        max_steps_out = gamma_slice_max_steps_out,
        max_shrink = gamma_slice_max_shrink,
        max_steps_out_sigma = if (isTRUE(use_log_sigma)) sigma_slice_max_steps_out else gamma_slice_max_steps_out,
        max_shrink_sigma = if (isTRUE(use_log_sigma)) sigma_slice_max_shrink else gamma_slice_max_shrink
      )
    ),
    run.time = runtime,
    X = X,
    bounds = c(L = L, U = U),
    p0 = p0,
    likelihood_family = likelihood_family,
    samp.beta = coda::as.mcmc(beta_draws),
    samp.sigma = coda::as.mcmc(sigma_draws),
    samp.gamma = coda::as.mcmc(gamma_draws),
    samp.v = if (!is.null(v_draws)) coda::as.mcmc(v_draws) else NULL,
    samp.s = if (!is.null(s_draws)) coda::as.mcmc(s_draws) else NULL,
    samp.tau = if (!is.null(tau_draws)) coda::as.mcmc(tau_draws) else NULL,
    samp.c2 = if (!is.null(c2_draws)) coda::as.mcmc(c2_draws) else NULL,
    samp.lambda = if (!is.null(lambda_draws)) coda::as.mcmc(lambda_draws) else NULL,
    samp.lambda_mean = if (!is.null(lambda_mean_draws)) coda::as.mcmc(lambda_mean_draws) else NULL,
    samp.lambda_min = if (!is.null(lambda_min_draws)) coda::as.mcmc(lambda_min_draws) else NULL,
    samp.lambda_max = if (!is.null(lambda_max_draws)) coda::as.mcmc(lambda_max_draws) else NULL,
    beta_prior = beta_prior_out,
    summary = summary_out,
    diagnostics = diagnostics_out,
    misc = list(
      p0 = p0,
      likelihood_family = likelihood_family,
      al_fixed_gamma = if (is_al) as.numeric(al_gamma_fixed) else NA_real_,
      bounds = c(L = L, U = U),
      n = n,
      p = p,
      method = "mcmc",
      gamma_trace = gamma_trace,
      sigma_trace = sigma_trace,
      theta_warmup_active_trace = if (isTRUE(theta_trace_enabled)) theta_warmup_active_trace else NULL,
      theta_hard_freeze_trace = if (isTRUE(theta_trace_enabled)) theta_hard_freeze_trace else NULL,
      theta_sparse_window_trace = if (isTRUE(theta_trace_enabled)) theta_sparse_window_trace else NULL,
      theta_force_update_trace = if (isTRUE(theta_trace_enabled)) theta_force_update_trace else NULL,
      theta_update_performed_trace = if (isTRUE(theta_trace_enabled)) theta_update_performed_trace else NULL,
      theta_update_reason_trace = if (isTRUE(theta_trace_enabled)) theta_update_reason_trace else NULL,
      theta_update_count_trace = if (isTRUE(theta_trace_enabled)) theta_update_count_trace else NULL,
      theta_first_postwarmup_update_iter = if (is.na(theta_first_postwarmup_update_iter)) NA_integer_ else as.integer(theta_first_postwarmup_update_iter),
      theta_update_count = as.integer(theta_update_count),
      theta_updates_burn = as.integer(theta_updates_burn),
      theta_updates_keep = as.integer(theta_updates_keep),
      latent_v_warmup_active_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_warmup_active_trace else NULL,
      latent_v_hard_freeze_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_hard_freeze_trace else NULL,
      latent_v_sparse_window_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_sparse_window_trace else NULL,
      latent_v_force_update_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_force_update_trace else NULL,
      latent_v_update_performed_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_update_performed_trace else NULL,
      latent_v_update_reason_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_update_reason_trace else NULL,
      latent_v_update_count_trace = if (isTRUE(latent_v_trace_enabled)) latent_v_update_count_trace else NULL,
      latent_v_rescue_applied_trace = if (isTRUE(latent_v_trace_enabled) && isTRUE(latent_v_record_rescue_trace)) latent_v_rescue_applied_trace else NULL,
      latent_v_rescue_strategy_trace = if (isTRUE(latent_v_trace_enabled) && isTRUE(latent_v_record_rescue_trace)) latent_v_rescue_strategy_trace else NULL,
      latent_v_rescue_count_trace = if (isTRUE(latent_v_trace_enabled) && isTRUE(latent_v_record_rescue_trace)) latent_v_rescue_count_trace else NULL,
      latent_v_rescue_consecutive_trace = if (isTRUE(latent_v_trace_enabled) && isTRUE(latent_v_record_rescue_trace)) latent_v_rescue_consecutive_trace else NULL,
      latent_v_first_postwarmup_update_iter = if (is.na(latent_v_first_postwarmup_update_iter)) NA_integer_ else as.integer(latent_v_first_postwarmup_update_iter),
      latent_v_update_count = as.integer(latent_v_update_count),
      latent_v_updates_burn = as.integer(latent_v_updates_burn),
      latent_v_updates_keep = as.integer(latent_v_updates_keep),
      latent_v_rescue_count = as.integer(latent_v_rescue_count),
      latent_v_rescues_burn = as.integer(latent_v_rescues_burn),
      latent_v_rescues_keep = as.integer(latent_v_rescues_keep),
      latent_v_rescue_max_streak = as.integer(latent_v_rescue_max_streak),
      latent_s_warmup_active_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_warmup_active_trace else NULL,
      latent_s_hard_freeze_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_hard_freeze_trace else NULL,
      latent_s_sparse_window_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_sparse_window_trace else NULL,
      latent_s_force_update_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_force_update_trace else NULL,
      latent_s_update_performed_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_update_performed_trace else NULL,
      latent_s_update_reason_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_update_reason_trace else NULL,
      latent_s_update_count_trace = if (isTRUE(latent_s_trace_enabled)) latent_s_update_count_trace else NULL,
      latent_s_first_postwarmup_update_iter = if (is.na(latent_s_first_postwarmup_update_iter)) NA_integer_ else as.integer(latent_s_first_postwarmup_update_iter),
      latent_s_update_count = as.integer(latent_s_update_count),
      latent_s_updates_burn = as.integer(latent_s_updates_burn),
      latent_s_updates_keep = as.integer(latent_s_updates_keep),
      sigmagam_frozen_trace = sigmagam_frozen_trace,
      sigmagam_update_reason_trace = sigmagam_update_reason_trace,
      sigmagam_forced_postwarmup_trace = sigmagam_forced_postwarmup_trace,
      sigmagam_update_performed_trace = sigmagam_update_performed_trace,
      sigmagam_update_count_trace = sigmagam_update_count_trace,
      sigmagam_first_active_iter = if (is.na(sigmagam_first_active_iter)) NA_integer_ else as.integer(sigmagam_first_active_iter),
      sigmagam_update_count = as.integer(sigmagam_update_count),
      sigmagam_postwarmup_update_count = as.integer(sigmagam_postwarmup_update_count),
      sigmagam_updates_burn = as.integer(sigmagam_updates_burn),
      sigmagam_updates_keep = as.integer(sigmagam_updates_keep),
      sigmagam_frozen_burn_rate = if (n_burn > 0L) mean(sigmagam_frozen_trace[seq_len(n_burn)]) else NA_real_,
      gamma_slice_steps_out = gamma_steps_out,
      gamma_slice_shrink = gamma_shrink,
      beta_prec_last = beta_prec_diag,
      rhs_tau_trace = rhs_tau_trace,
      rhs_c2_trace = rhs_c2_trace,
      rhs_lambda_mean_trace = rhs_lambda_mean_trace,
      rhs_lambda_min_trace = rhs_lambda_min_trace,
      rhs_lambda_max_trace = rhs_lambda_max_trace,
      rhs_tau_steps_out = rhs_tau_steps_out,
      rhs_tau_shrink = rhs_tau_shrink,
      rhs_c2_steps_out = rhs_c2_steps_out,
      rhs_c2_shrink = rhs_c2_shrink,
      rhs_lambda_steps_out_mean = rhs_lambda_steps_out_mean,
      rhs_lambda_steps_out_max = rhs_lambda_steps_out_max,
      rhs_lambda_shrink_mean = rhs_lambda_shrink_mean,
      rhs_lambda_shrink_max = rhs_lambda_shrink_max,
      rhs_tau_frozen_trace = rhs_tau_frozen_trace,
      rhs_global_block_used_trace = rhs_global_block_used_trace,
      rhs_global_block_steps_out = rhs_global_block_steps_out,
      rhs_global_block_shrink = rhs_global_block_shrink,
      rhs_global_block_dir_tau = rhs_global_block_dir_tau,
      rhs_global_block_dir_c2 = rhs_global_block_dir_c2,
      rhs_global_block_transformed_passes = rhs_global_block_transformed_passes,
      rhs_transformed_z1_steps_out = rhs_transformed_z1_steps_out,
      rhs_transformed_z1_shrink = rhs_transformed_z1_shrink,
      rhs_transformed_z2_steps_out = rhs_transformed_z2_steps_out,
      rhs_transformed_z2_shrink = rhs_transformed_z2_shrink,
      rhs_width_lambda_trace = rhs_width_lambda_trace,
      rhs_width_tau_trace = rhs_width_tau_trace,
      rhs_width_c2_trace = rhs_width_c2_trace,
      rhs_width_tau_c2_block_trace = rhs_width_tau_c2_block_trace,
      rhs_width_tau_c2_transformed_z1_trace = rhs_width_tau_c2_transformed_z1_trace,
      rhs_width_tau_c2_transformed_z2_trace = rhs_width_tau_c2_transformed_z2_trace,
      rhs_width_adapt_active_trace = rhs_width_adapt_active_trace,
      conditioning = list(
        mode = conditioning_state$mode,
        active = isTRUE(conditioning_state$active),
        scale_metric = conditioning_state$scale_metric,
        intercept_column = as.integer(conditioning_state$intercept_column),
        beta_scale = stats::setNames(as.numeric(conditioning_state$beta_scale), conditioning_state$column_names %||% seq_along(conditioning_state$beta_scale)),
        raw_metric = stats::setNames(as.numeric(conditioning_state$raw_metric), conditioning_state$column_names %||% seq_along(conditioning_state$raw_metric)),
        transform_diag = stats::setNames(as.numeric(diag(conditioning_state$transform)), conditioning_state$column_names %||% seq_len(ncol(conditioning_state$transform))),
        raw_condition_kappa = as.numeric(conditioning_state$raw_kappa),
        conditioned_condition_kappa = as.numeric(conditioning_state$work_kappa),
        condition_gain_ratio = as.numeric(conditioning_state$gain_ratio),
        scaled_columns_n = as.integer(conditioning_state$scaled_columns_n),
        scale_min = as.numeric(conditioning_state$scale_min),
        scale_max = as.numeric(conditioning_state$scale_max)
      )
    ),
    last = list(
      beta = beta,
      beta_work = as.numeric(beta_work %||% (conditioning_state$transform %*% beta)),
      sigma = sigma,
      gamma = gamma,
      v = v,
      s = s,
      beta_prec_diag = beta_prec_diag,
      beta_prior_state = rhs_state
    )
  ), class = c("exal_mcmc", "exalStaticMCMC"))
}

#' Draw posterior samples from an exAL fit
#'
#' Dispatches across the currently supported exAL inference backends.
#'
#' @export
exal_posterior_draws <- function(fit_exal, nd = 1000L, seed = NULL) {
  if (inherits(fit_exal, "exal_vb")) {
    return(exal_vb_posterior_draws(fit_exal, nd = nd))
  }
  if (inherits(fit_exal, "exal_mcmc")) {
    return(exal_mcmc_posterior_draws(fit_exal, nd = nd, seed = seed))
  }
  .stopf("Unsupported fit class for exal_posterior_draws().")
}

#' Posterior predictive samples from an exAL fit
#'
#' Dispatches across the currently supported exAL inference backends.
#'
#' @export
exal_posterior_predict <- function(fit_exal, X_new, nd = 1000L, chunk = 200L, draws = NULL, seed = NULL) {
  if (inherits(fit_exal, "exal_vb")) {
    return(exal_vb_posterior_predict(fit_exal, X_new = X_new, nd = nd, chunk = chunk, draws = draws))
  }
  if (inherits(fit_exal, "exal_mcmc")) {
    return(exal_mcmc_posterior_predict(fit_exal, X_new = X_new, nd = nd, chunk = chunk, draws = draws, seed = seed))
  }
  .stopf("Unsupported fit class for exal_posterior_predict().")
}

#' Fit exAL readout with either VB or MCMC
#'
#' @export
exal_fit <- function(..., method = c("vb", "mcmc"), likelihood_family = c("exal", "al")) {
  method <- match.arg(method)
  likelihood_family <- match.arg(tolower(as.character(likelihood_family)[1L]), c("exal", "al"))
  if (identical(method, "vb")) {
    return(exal_ldvb_fit(..., likelihood_family = likelihood_family))
  }
  exal_mcmc_fit(..., likelihood_family = likelihood_family)
}

#' Draw posterior samples of (beta, sigma, gamma) from an exAL MCMC fit
#'
#' @export
exal_mcmc_posterior_draws <- function(fit_exal, nd = NULL, seed = NULL) {
  stopifnot(inherits(fit_exal, "exal_mcmc"))
  if (!is.null(seed)) set.seed(seed)

  beta <- as.matrix(fit_exal$samp.beta)
  sigma <- as.numeric(fit_exal$samp.sigma)
  gamma <- as.numeric(fit_exal$samp.gamma)
  n_save <- nrow(beta)
  if (length(sigma) != n_save || length(gamma) != n_save) {
    .stopf("MCMC draw lengths do not match beta chain rows.")
  }

  if (is.null(nd) || is.na(nd)) {
    idx <- seq_len(n_save)
  } else {
    nd <- as.integer(nd)[1L]
    if (nd < 1L) .stopf("nd must be >= 1.")
    idx <- sample.int(n_save, size = nd, replace = (nd > n_save))
  }

  list(
    beta = beta[idx, , drop = FALSE],
    sigma = sigma[idx],
    gamma = gamma[idx],
    nd = length(idx)
  )
}

.exal_posterior_predict_from_draws <- function(fit_exal, X_new, draws, chunk = 200L) {
  X_new <- as.matrix(X_new)
  n <- nrow(X_new)

  Bdraw <- draws$beta
  sdraw <- draws$sigma
  gdraw <- draws$gamma
  if (is.null(Bdraw) || !is.matrix(Bdraw)) .stopf("posterior_predict: missing beta draws.")
  if (length(sdraw) != nrow(Bdraw) || length(gdraw) != nrow(Bdraw)) {
    .stopf("posterior_predict: draw lengths do not match beta draws.")
  }
  nd_eff <- nrow(Bdraw)

  p0 <- fit_exal$misc$p0
  A_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$A, numeric(1))
  B_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$B, numeric(1))
  lam_d <- vapply(gdraw, function(g) {
    abc <- exal_get_ABC(p0 = p0, gamma = g)
    abc$C * abs(g)
  }, numeric(1))

  yrep <- matrix(NA_real_, n, nd_eff)
  mu_draws <- matrix(NA_real_, n, nd_eff)
  ids_list <- split(seq_len(nd_eff), ceiling(seq_len(nd_eff) / as.integer(chunk)))
  for (ids in ids_list) {
    mm <- length(ids)
    Bc <- t(Bdraw[ids, , drop = FALSE])
    mu <- X_new %*% Bc
    mu_draws[, ids] <- mu

    s_mat <- matrix(abs(stats::rnorm(n * mm)), n, mm)
    v_mat <- matrix(stats::rexp(n * mm, rate = rep(1 / sdraw[ids], each = n)), n, mm)
    z_mat <- matrix(stats::rnorm(n * mm), n, mm)

    term_s <- sweep(s_mat, 2L, lam_d[ids] * sdraw[ids], `*`)
    term_v <- sweep(v_mat, 2L, A_d[ids], `*`)
    sd_mat <- sqrt(sweep(v_mat, 2L, B_d[ids] * sdraw[ids], `*`))

    yrep[, ids] <- mu + term_s + term_v + sd_mat * z_mat
  }

  list(yrep = yrep, mu_draws = mu_draws,
       beta = Bdraw, sigma = sdraw, gamma = gdraw)
}

#' Posterior predictive samples for an exAL MCMC fit
#'
#' @export
exal_mcmc_posterior_predict <- function(fit_exal, X_new, nd = 1000L, chunk = 200L, draws = NULL, seed = NULL) {
  stopifnot(inherits(fit_exal, "exal_mcmc"))
  if (!is.null(seed)) set.seed(seed)
  if (is.null(draws)) draws <- exal_mcmc_posterior_draws(fit_exal, nd = nd)
  .exal_posterior_predict_from_draws(fit_exal, X_new = X_new, draws = draws, chunk = chunk)
}
