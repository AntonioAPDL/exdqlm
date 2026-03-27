.static_prior_or <- function(x, alt) {
  if (!is.null(x)) x else alt
}

.static_is_rhs_family <- function(beta_prior_type) {
  tolower(as.character(beta_prior_type)[1]) %in% c("rhs", "rhs_ns")
}

.static_match_beta_prior <- function(beta_prior) {
  prior <- tolower(as.character(beta_prior)[1])
  if (!nzchar(prior)) prior <- "ridge"
  if (identical(prior, "gaussian")) prior <- "ridge"
  match.arg(prior, c("ridge", "rhs", "rhs_ns"))
}

.static_parse_beta_prior_controls <- function(beta_prior_controls = NULL, prior_type = c("rhs", "rhs_ns")) {
  prior_type <- match.arg(prior_type)

  default_n_inner <- if (identical(prior_type, "rhs_ns")) 2L else 1L
  ctrl <- list(
    tau0 = 1,
    nu = 4,
    s = NULL,
    s2 = 1,
    a_zeta = if (identical(prior_type, "rhs_ns")) 2 else NULL,
    b_zeta = if (identical(prior_type, "rhs_ns")) 1 else NULL,
    zeta2_fixed = NULL,
    shrink_intercept = FALSE,
    intercept_prec = 1e-16,
    n_inner = default_n_inner,
    freeze_tau_iters = 50L,
    freeze_tau_warmup_iters = NULL,
    update_every = 1L,
    update_every_warmup = 1L,
    update_every_warmup_iters = 0L,
    force_tau_after_warmup = TRUE,
    collapse_tau_ratio_tol = 1e-6,
    collapse_beta_max_abs_tol = 1e-6,
    collapse_invV_med_tol = 1e8,
    collapse_beta_l2_tol = 1e-6,
    collapse_small_beta_frac_tol = 0.95,
    small_beta_abs_tol = 1e-4,
    warn_on_collapse = TRUE,
    eta_bounds = list(
      lambda = c(-40, 40),
      tau = c(-40, 40),
      c2 = c(-40, 40)
    ),
    var_floor = 1e-16,
    h_curv = 1e-16,
    verbose = FALSE,
    init_lambda = 1,
    init_log_lambda = NULL,
    init_tau = NULL,
    init_log_tau = NULL,
    init_c2 = NULL,
    init_log_c2 = NULL,
    slice_width = 1,
    slice_max_steps = 20L
  )
  if (!is.null(beta_prior_controls)) {
    if (!is.list(beta_prior_controls)) stop("beta_prior_controls must be a list.")
    ctrl <- utils::modifyList(ctrl, beta_prior_controls)
  }

  input_names <- names(beta_prior_controls %||% list())
  has_input <- function(nm) nm %in% input_names

  tau0 <- as.numeric(ctrl$tau0)[1]
  nu <- as.numeric(ctrl$nu)[1]
  if (!is.finite(tau0) || tau0 <= 0) stop("beta_prior_controls$tau0 must be > 0.")
  if (!is.finite(nu) || nu <= 0) stop("beta_prior_controls$nu must be > 0.")

  has_s <- !is.null(ctrl$s)
  has_s2 <- !is.null(ctrl$s2)
  s_val <- if (has_s) as.numeric(ctrl$s)[1] else NA_real_
  s2_val <- if (has_s2) as.numeric(ctrl$s2)[1] else NA_real_
  if (has_s2) {
    s2 <- s2_val
    s <- sqrt(s2)
    s_source <- "s2"
  } else if (has_s) {
    s <- s_val
    s2 <- s^2
    s_source <- "s"
  } else {
    s2 <- 1
    s <- 1
    s_source <- "default"
  }
  if (!is.finite(s2) || s2 <= 0) stop("beta_prior_controls$s2 (or s^2) must be > 0.")

  if (has_s && has_s2) {
    s_from_s2 <- sqrt(s2_val)
    if (is.finite(s_val) && is.finite(s_from_s2)) {
      rel <- abs(s_val - s_from_s2) / max(1, abs(s_val), abs(s_from_s2))
      if (rel > 1e-8) {
        warning("beta_prior_controls supplied both s and s2 inconsistently; using s2 and resetting s=sqrt(s2).", call. = FALSE)
      }
    }
  }

  if (identical(prior_type, "rhs_ns")) {
    a_zeta <- as.numeric(ctrl$a_zeta)[1]
    b_zeta <- as.numeric(ctrl$b_zeta)[1]
    if ((has_input("a_zeta") || has_input("b_zeta")) && (!is.finite(a_zeta) || a_zeta <= 0 || !is.finite(b_zeta) || b_zeta <= 0)) {
      stop("beta_prior_controls$a_zeta and beta_prior_controls$b_zeta must be finite and > 0 when provided.")
    }

    explicit_ab <- has_input("a_zeta") || has_input("b_zeta")
    explicit_nu_s <- has_input("nu") || has_input("s") || has_input("s2")
    if (explicit_ab && !explicit_nu_s) {
      nu <- 2 * a_zeta
      s2 <- b_zeta / a_zeta
      s <- sqrt(s2)
      s_source <- "rhs_ns_ab"
    } else {
      a_from_rhs <- nu / 2
      b_from_rhs <- (nu * s2) / 2
      if (explicit_ab) {
        rel_a <- abs(a_zeta - a_from_rhs) / max(1, abs(a_zeta), abs(a_from_rhs))
        rel_b <- abs(b_zeta - b_from_rhs) / max(1, abs(b_zeta), abs(b_from_rhs))
        if (max(rel_a, rel_b) > 1e-8) {
          warning(
            "beta_prior_controls supplied both RHS and RHS_NS slab controls inconsistently; using nu/s/s2 and mapping to a_zeta/b_zeta.",
            call. = FALSE
          )
        }
      }
      a_zeta <- a_from_rhs
      b_zeta <- b_from_rhs
    }
    ctrl$a_zeta <- a_zeta
    ctrl$b_zeta <- b_zeta
  } else {
    ctrl$a_zeta <- NULL
    ctrl$b_zeta <- NULL
  }

  parse_bounds <- function(x, default) {
    x <- as.numeric(.static_prior_or(x, default))
    if (length(x) != 2L || any(!is.finite(x)) || x[1] >= x[2]) default else x
  }

  ctrl$tau0 <- tau0
  ctrl$nu <- nu
  ctrl$s <- s
  ctrl$s2 <- s2
  ctrl$s_source <- s_source
  zeta2_fixed <- .static_prior_or(ctrl$zeta2_fixed, ctrl$c2_fixed)
  if (!is.null(zeta2_fixed)) {
    zeta2_fixed <- as.numeric(zeta2_fixed)[1]
    if (!is.finite(zeta2_fixed) || zeta2_fixed <= 0) {
      stop("beta_prior_controls$zeta2_fixed must be finite and > 0 when provided.")
    }
  }
  ctrl$zeta2_fixed <- zeta2_fixed
  ctrl$prior_type <- prior_type
  ctrl$shrink_intercept <- isTRUE(ctrl$shrink_intercept)
  ctrl$intercept_prec <- as.numeric(ctrl$intercept_prec)[1]
  if (!is.finite(ctrl$intercept_prec) || ctrl$intercept_prec <= 0) ctrl$intercept_prec <- 1e-16
  if (is.null(ctrl$eta_bounds) || !is.list(ctrl$eta_bounds)) ctrl$eta_bounds <- list()
  ctrl$eta_bounds$lambda <- parse_bounds(.static_prior_or(ctrl$eta_bounds$lambda, ctrl$lambda_bounds), c(-40, 40))
  ctrl$eta_bounds$tau <- parse_bounds(.static_prior_or(ctrl$eta_bounds$tau, ctrl$tau_bounds), c(-40, 40))
  ctrl$eta_bounds$c2 <- parse_bounds(.static_prior_or(ctrl$eta_bounds$c2, ctrl$c2_bounds), c(-40, 40))
  ctrl$n_inner <- suppressWarnings(as.integer(ctrl$n_inner)[1])
  if (!is.finite(ctrl$n_inner) || ctrl$n_inner < 1L) ctrl$n_inner <- 1L
  ctrl$var_floor <- as.numeric(ctrl$var_floor)[1]
  if (!is.finite(ctrl$var_floor) || ctrl$var_floor <= 0) ctrl$var_floor <- 1e-16
  ctrl$h_curv <- as.numeric(ctrl$h_curv)[1]
  if (!is.finite(ctrl$h_curv) || ctrl$h_curv <= 0) ctrl$h_curv <- 1e-16
  ctrl$verbose <- isTRUE(ctrl$verbose)
  freeze_tau_iters <- suppressWarnings(as.integer(.static_prior_or(ctrl$freeze_tau_iters, ctrl$rhs_freeze_tau_iters))[1])
  if (!is.finite(freeze_tau_iters) || freeze_tau_iters < 0L) freeze_tau_iters <- 50L
  freeze_tau_warmup_iters <- suppressWarnings(as.integer(
    .static_prior_or(
      ctrl$freeze_tau_warmup_iters,
      .static_prior_or(ctrl$rhs_freeze_tau_warmup_iters, freeze_tau_iters)
    )[1]
  ))
  if (!is.finite(freeze_tau_warmup_iters) || freeze_tau_warmup_iters < 0L) {
    freeze_tau_warmup_iters <- freeze_tau_iters
  }
  update_every <- suppressWarnings(as.integer(.static_prior_or(ctrl$update_every, ctrl$rhs_update_every))[1])
  if (!is.finite(update_every) || update_every < 1L) update_every <- 1L
  update_every_warmup <- suppressWarnings(as.integer(
    .static_prior_or(ctrl$update_every_warmup, .static_prior_or(ctrl$rhs_update_every_warmup, update_every))[1]
  ))
  if (!is.finite(update_every_warmup) || update_every_warmup < 1L) update_every_warmup <- update_every
  update_every_warmup_iters <- suppressWarnings(as.integer(
    .static_prior_or(ctrl$update_every_warmup_iters, ctrl$rhs_update_every_warmup_iters)[1]
  ))
  if (!is.finite(update_every_warmup_iters) || update_every_warmup_iters < 0L) update_every_warmup_iters <- 0L
  ctrl$freeze_tau_iters <- freeze_tau_iters
  ctrl$freeze_tau_warmup_iters <- freeze_tau_warmup_iters
  ctrl$update_every <- update_every
  ctrl$update_every_warmup <- update_every_warmup
  ctrl$update_every_warmup_iters <- update_every_warmup_iters
  ctrl$force_tau_after_warmup <- isTRUE(.static_prior_or(ctrl$force_tau_after_warmup, ctrl$rhs_force_tau_after_warmup))
  ctrl$collapse_tau_ratio_tol <- as.numeric(ctrl$collapse_tau_ratio_tol)[1]
  if (!is.finite(ctrl$collapse_tau_ratio_tol) || ctrl$collapse_tau_ratio_tol <= 0) ctrl$collapse_tau_ratio_tol <- 1e-6
  ctrl$collapse_beta_max_abs_tol <- as.numeric(ctrl$collapse_beta_max_abs_tol)[1]
  if (!is.finite(ctrl$collapse_beta_max_abs_tol) || ctrl$collapse_beta_max_abs_tol <= 0) ctrl$collapse_beta_max_abs_tol <- 1e-6
  ctrl$warn_on_collapse <- isTRUE(ctrl$warn_on_collapse)
  ctrl$collapse_invV_med_tol <- as.numeric(ctrl$collapse_invV_med_tol)[1]
  if (!is.finite(ctrl$collapse_invV_med_tol) || ctrl$collapse_invV_med_tol <= 0) ctrl$collapse_invV_med_tol <- 1e8
  ctrl$collapse_beta_l2_tol <- as.numeric(ctrl$collapse_beta_l2_tol)[1]
  if (!is.finite(ctrl$collapse_beta_l2_tol) || ctrl$collapse_beta_l2_tol <= 0) ctrl$collapse_beta_l2_tol <- 1e-6
  ctrl$collapse_small_beta_frac_tol <- as.numeric(ctrl$collapse_small_beta_frac_tol)[1]
  if (!is.finite(ctrl$collapse_small_beta_frac_tol) || ctrl$collapse_small_beta_frac_tol <= 0 || ctrl$collapse_small_beta_frac_tol > 1) {
    ctrl$collapse_small_beta_frac_tol <- 0.95
  }
  ctrl$small_beta_abs_tol <- as.numeric(ctrl$small_beta_abs_tol)[1]
  if (!is.finite(ctrl$small_beta_abs_tol) || ctrl$small_beta_abs_tol <= 0) ctrl$small_beta_abs_tol <- 1e-4

  init_lambda <- if (!is.null(ctrl$init_log_lambda)) .static_rhs_safe_exp(ctrl$init_log_lambda) else ctrl$init_lambda
  init_lambda <- as.numeric(init_lambda)
  if (!length(init_lambda) || any(!is.finite(init_lambda)) || any(init_lambda <= 0)) {
    stop("beta_prior_controls$init_lambda must be finite and > 0 (scalar or length p).")
  }
  ctrl$init_lambda <- init_lambda

  has_init_log_tau <- !is.null(ctrl$init_log_tau)
  has_init_tau <- !is.null(ctrl$init_tau)
  if (has_init_log_tau) {
    resolved_init_log_tau <- as.numeric(ctrl$init_log_tau)[1]
    if (!is.finite(resolved_init_log_tau)) stop("beta_prior_controls$init_log_tau must be finite when provided.")
    resolved_init_tau <- .static_rhs_safe_exp(resolved_init_log_tau)
    init_tau_source <- "init_log_tau"
  } else if (has_init_tau) {
    resolved_init_tau <- as.numeric(ctrl$init_tau)[1]
    if (!is.finite(resolved_init_tau) || resolved_init_tau <= 0) stop("beta_prior_controls$init_tau must be finite and > 0 when provided.")
    resolved_init_log_tau <- log(resolved_init_tau)
    init_tau_source <- "init_tau"
  } else {
    # Guardrail: unset/null tau init defaults to log(1)=0, not tau0.
    resolved_init_log_tau <- 0
    resolved_init_tau <- 1
    init_tau_source <- "default_log_tau_0"
  }
  if (!is.finite(resolved_init_log_tau) || !is.finite(resolved_init_tau) || resolved_init_tau <= 0) {
    stop("Resolved RHS tau initialization is invalid; check init_log_tau/init_tau controls.")
  }
  ctrl$init_log_tau <- resolved_init_log_tau
  ctrl$init_tau <- resolved_init_tau
  ctrl$init_tau_source <- init_tau_source

  init_c2 <- if (!is.null(ctrl$init_log_c2)) .static_rhs_safe_exp(ctrl$init_log_c2) else ctrl$init_c2
  if (!is.null(init_c2)) {
    init_c2 <- as.numeric(init_c2)[1]
    if (!is.finite(init_c2) || init_c2 <= 0) stop("beta_prior_controls$init_c2 must be finite and > 0 when provided.")
  }
  if (!is.null(ctrl$zeta2_fixed)) {
    init_c2 <- as.numeric(ctrl$zeta2_fixed)[1]
  }
  ctrl$init_c2 <- init_c2
  ctrl$init_log_c2 <- if (!is.null(init_c2)) log(init_c2) else NULL
  ctrl$slice_width <- as.numeric(ctrl$slice_width)[1]
  if (!is.finite(ctrl$slice_width) || ctrl$slice_width <= 0) ctrl$slice_width <- 1
  ctrl$slice_max_steps <- suppressWarnings(as.integer(ctrl$slice_max_steps)[1])
  if (!is.finite(ctrl$slice_max_steps) || ctrl$slice_max_steps < 1L) ctrl$slice_max_steps <- 20L
  ctrl
}

.static_rhs_opt_1d_mode <- function(f, lo, hi, eta0 = NULL) {
  if (!is.finite(lo) || !is.finite(hi) || lo >= hi) stop("Invalid optimization bounds.")
  if (is.null(eta0) || !is.finite(eta0)) eta0 <- 0
  opt <- try(stats::optimize(f, interval = c(lo, hi), maximum = TRUE), silent = TRUE)
  if (!inherits(opt, "try-error") && is.finite(opt$objective)) {
    return(pmin(pmax(opt$maximum, lo), hi))
  }
  grid <- seq(lo, hi, length.out = 31L)
  vals <- vapply(grid, f, numeric(1))
  idx <- which.max(vals)
  par0 <- grid[idx]
  fn_neg <- function(z) {
    v <- f(z)
    if (!is.finite(v)) 1e100 else -v
  }
  opt2 <- try(stats::optim(par = par0, fn = fn_neg, method = "BFGS", control = list(maxit = 2000L)), silent = TRUE)
  if (inherits(opt2, "try-error") || !is.finite(opt2$value)) {
    return(par0)
  }
  pmin(pmax(as.numeric(opt2$par)[1], lo), hi)
}

.static_rhs_active_idx <- function(p, shrink_intercept) {
  if (isTRUE(shrink_intercept)) {
    seq_len(p)
  } else if (p >= 2L) {
    2L:p
  } else {
    integer(0)
  }
}

.static_rhs_safe_exp <- function(x) {
  exp(pmin(pmax(as.numeric(x), -745), 709))
}

.static_rhs_preflight_config <- function(ctrl) {
  cfg <- list(
    prior_type = as.character(.static_prior_or(ctrl$prior_type, "rhs"))[1],
    tau0 = as.numeric(ctrl$tau0)[1],
    nu = as.numeric(ctrl$nu)[1],
    s = as.numeric(ctrl$s)[1],
    s2 = as.numeric(ctrl$s2)[1],
    a_zeta = as.numeric(.static_prior_or(ctrl$a_zeta, NA_real_))[1],
    b_zeta = as.numeric(.static_prior_or(ctrl$b_zeta, NA_real_))[1],
    zeta2_fixed = as.numeric(.static_prior_or(ctrl$zeta2_fixed, NA_real_))[1],
    init_log_tau = as.numeric(ctrl$init_log_tau)[1],
    init_tau = as.numeric(ctrl$init_tau)[1],
    init_tau_source = as.character(.static_prior_or(ctrl$init_tau_source, "unknown"))[1],
    eta_bounds_tau = as.numeric(ctrl$eta_bounds$tau),
    shrink_intercept = isTRUE(ctrl$shrink_intercept)
  )
  if (!is.finite(cfg$init_log_tau) || !is.finite(cfg$init_tau) || cfg$init_tau <= 0) {
    stop("RHS preflight failed: resolved init_log_tau/init_tau must be finite with init_tau > 0.")
  }
  if (length(cfg$eta_bounds_tau) != 2L || any(!is.finite(cfg$eta_bounds_tau)) || cfg$eta_bounds_tau[1] >= cfg$eta_bounds_tau[2]) {
    stop("RHS preflight failed: eta_bounds$tau must be finite and ordered.")
  }
  cfg
}

.static_rhs_preflight_emit <- function(cfg, context = "rhs") {
  msg <- sprintf(
    "[%s] RHS preflight | tau0=%.6g nu=%.6g s=%.6g s2=%.6g init_log_tau=%.6g init_tau=%.6g init_source=%s eta_bounds_tau=[%.6g, %.6g] shrink_intercept=%s",
    context,
    cfg$tau0, cfg$nu, cfg$s, cfg$s2, cfg$init_log_tau, cfg$init_tau, cfg$init_tau_source,
    cfg$eta_bounds_tau[1], cfg$eta_bounds_tau[2], ifelse(cfg$shrink_intercept, "TRUE", "FALSE")
  )
  message(msg)
  invisible(msg)
}

.static_rhs_log1p_exp <- function(x) {
  x <- as.numeric(x)
  out <- numeric(length(x))
  pos <- x > 0
  out[pos] <- x[pos] + log1p(.static_rhs_safe_exp(-x[pos]))
  out[!pos] <- log1p(.static_rhs_safe_exp(x[!pos]))
  out
}

.static_rhs_logsumexp2 <- function(a, b) {
  m <- pmax(a, b)
  m + log(.static_rhs_safe_exp(a - m) + .static_rhs_safe_exp(b - m))
}

.static_rhs_obj_eta <- function(eta_lambda, eta_tau, eta_c2, beta2, ctrl) {
  idx <- .static_rhs_active_idx(length(beta2), ctrl$shrink_intercept)
  eta_lambda_use <- eta_lambda[idx]
  beta2_use <- beta2[idx]

  u <- 2 * eta_tau + 2 * eta_lambda_use
  log_invV <- .static_rhs_logsumexp2(-eta_c2, -u)
  invV <- .static_rhs_safe_exp(log_invV)
  logV <- eta_c2 + u - .static_rhs_logsumexp2(eta_c2, u)
  quad <- beta2_use * invV
  quad[!is.finite(quad)] <- .Machine$double.xmax

  like <- -0.5 * sum(logV + quad)
  lp_lam <- sum(eta_lambda_use - .static_rhs_log1p_exp(2 * eta_lambda_use))
  lp_tau <- eta_tau - .static_rhs_log1p_exp(2 * (eta_tau - log(ctrl$tau0)))
  lp_c2 <- -(ctrl$nu / 2) * eta_c2 - (ctrl$nu * ctrl$s2) / (2 * .static_rhs_safe_exp(eta_c2))

  out <- like + lp_lam + lp_tau + lp_c2
  if (!is.finite(out)) -1e300 else out
}

.static_rhs_d2_lambda_j <- function(eta_lambda_j, eta_tau, eta_c2, beta2_j) {
  u <- 2 * (eta_tau + eta_lambda_j)
  a <- eta_c2
  ld <- .static_rhs_logsumexp2(a, u)
  w <- .static_rhs_safe_exp(u - ld)
  w1w <- w * (1 - w)
  t <- .static_rhs_safe_exp(-u)
  d2_like <- 2 * w1w - 2 * beta2_j * t
  s <- stats::plogis(2 * eta_lambda_j)
  d2_prior <- -4 * s * (1 - s)
  d2_like + d2_prior
}

.static_rhs_d2_tau <- function(eta_lambda_use, eta_tau, eta_c2, beta2_use, tau0) {
  u <- 2 * eta_tau + 2 * eta_lambda_use
  a <- eta_c2
  ld <- .static_rhs_logsumexp2(a, u)
  w <- .static_rhs_safe_exp(u - ld)
  w1w <- w * (1 - w)
  t <- .static_rhs_safe_exp(-u)
  d2_like <- sum(2 * w1w - 2 * beta2_use * t)
  s <- stats::plogis(2 * (eta_tau - log(tau0)))
  d2_prior <- -4 * s * (1 - s)
  d2_like + d2_prior
}

.static_rhs_d2_c2 <- function(eta_lambda_use, eta_tau, eta_c2, beta2_use, nu, s2) {
  u <- 2 * eta_tau + 2 * eta_lambda_use
  a <- eta_c2
  ld <- .static_rhs_logsumexp2(a, u)
  w <- .static_rhs_safe_exp(u - ld)
  w1w <- w * (1 - w)
  r <- .static_rhs_safe_exp(-eta_c2)
  d2_like <- 0.5 * sum(w1w) - 0.5 * r * sum(beta2_use)
  d2_prior <- -(nu * s2) / 2 * r
  d2_like + d2_prior
}

.static_rhs_hess_active <- function(eta_lambda, eta_tau, eta_c2, beta2, ctrl) {
  idx <- .static_rhs_active_idx(length(beta2), ctrl$shrink_intercept)
  k <- length(idx)
  d <- k + 2L
  H <- matrix(0, d, d)
  itau <- k + 1L
  ikap <- k + 2L
  logr <- -eta_c2
  r <- .static_rhs_safe_exp(logr)
  s_tau <- stats::plogis(2 * (eta_tau - log(ctrl$tau0)))
  d2_tau_prior <- -4 * s_tau * (1 - s_tau)
  d2_kap_prior <- -(ctrl$nu * ctrl$s2) / 2 * r

  for (a in seq_len(k)) {
    j <- idx[a]
    uj <- eta_lambda[j]
    Sj <- beta2[j]
    logt <- -2 * (uj + eta_tau)
    t <- .static_rhs_safe_exp(logt)
    logg <- .static_rhs_logsumexp2(logt, logr)
    w_t <- .static_rhs_safe_exp(logt - logg)
    w_r <- .static_rhs_safe_exp(logr - logg)
    a_wr <- w_t * w_r

    h11_log <- 2 * a_wr
    h12_log <- 2 * a_wr
    h13_log <- -a_wr
    h22_log <- 2 * a_wr
    h23_log <- -a_wr
    h33_log <- 0.5 * a_wr

    h11_g <- -0.5 * Sj * (4 * t)
    h12_g <- -0.5 * Sj * (4 * t)
    h22_g <- -0.5 * Sj * (4 * t)
    h33_g <- -0.5 * Sj * r

    sj <- stats::plogis(2 * uj)
    d2_lam_prior <- -4 * sj * (1 - sj)

    ia <- a
    H[ia, ia] <- H[ia, ia] + h11_log + h11_g + d2_lam_prior
    H[ia, itau] <- H[ia, itau] + h12_log + h12_g
    H[itau, ia] <- H[ia, itau]
    H[ia, ikap] <- H[ia, ikap] + h13_log
    H[ikap, ia] <- H[ia, ikap]
    H[itau, itau] <- H[itau, itau] + h22_log + h22_g
    H[itau, ikap] <- H[itau, ikap] + h23_log
    H[ikap, itau] <- H[itau, ikap]
    H[ikap, ikap] <- H[ikap, ikap] + h33_log + h33_g
  }

  H[itau, itau] <- H[itau, itau] + d2_tau_prior
  H[ikap, ikap] <- H[ikap, ikap] + d2_kap_prior
  H <- 0.5 * (H + t(H))
  list(H = H, idx = idx)
}

.static_rhs_inv_spd_with_jitter <- function(K, var_floor, max_tries = 12L) {
  d <- nrow(K)
  jitter <- 0
  for (tt in seq_len(max_tries)) {
    KK <- K
    if (jitter > 0) diag(KK) <- diag(KK) + jitter
    R <- try(chol(KK), silent = TRUE)
    if (!inherits(R, "try-error")) {
      inv <- chol2inv(R)
      return(list(inv = inv, logdet = 2 * sum(log(diag(R)))))
    }
    jitter <- if (tt == 1L) max(var_floor, 1e-16) else jitter * 10
  }
  KK <- K + diag(max(1e-16, var_floor), d)
  ev <- eigen(KK, symmetric = TRUE, only.values = TRUE)$values
  ev <- pmax(ev, 1e-300)
  list(inv = solve(KK), logdet = sum(log(ev)))
}

.static_rhs_embed_sigma_full <- function(Sigma_active, idx, p, var_floor) {
  Sigma_full <- diag(var_floor, p + 2L)
  k <- length(idx)
  itauA <- k + 1L
  ikapA <- k + 2L
  if (k > 0) {
    Sigma_full[idx, idx] <- Sigma_active[seq_len(k), seq_len(k), drop = FALSE]
    Sigma_full[idx, p + 1L] <- Sigma_active[seq_len(k), itauA]
    Sigma_full[p + 1L, idx] <- Sigma_active[itauA, seq_len(k)]
    Sigma_full[idx, p + 2L] <- Sigma_active[seq_len(k), ikapA]
    Sigma_full[p + 2L, idx] <- Sigma_active[ikapA, seq_len(k)]
  }
  Sigma_full[p + 1L, p + 1L] <- Sigma_active[itauA, itauA]
  Sigma_full[p + 2L, p + 2L] <- Sigma_active[ikapA, ikapA]
  Sigma_full[p + 1L, p + 2L] <- Sigma_active[itauA, ikapA]
  Sigma_full[p + 2L, p + 1L] <- Sigma_active[ikapA, itauA]
  Sigma_full
}

.static_rhs_init_vb_state <- function(p, ctrl) {
  lam0 <- ctrl$init_lambda
  if (length(lam0) == 1L) lam0 <- rep(lam0, p)
  lam0 <- pmax(as.numeric(lam0), 1e-16)
  if (length(lam0) != p) stop("beta_prior_controls$init_lambda must be scalar or length p.")
  tau0 <- as.numeric(ctrl$init_tau)[1]
  c20 <- if (!is.null(ctrl$init_c2)) ctrl$init_c2 else ctrl$s2
  list(
    p = p,
    shrink_intercept = ctrl$shrink_intercept,
    intercept_prec = ctrl$intercept_prec,
    eta_lambda_hat = log(lam0),
    eta_tau_hat = log(pmax(tau0, 1e-16)),
    eta_c_hat = log(pmax(c20, 1e-16)),
    Sigma_full = diag(ctrl$var_floor, p + 2L),
    Sigma_diag = rep(ctrl$var_floor, p + 2L),
    iter = 0L,
    freeze_tau = FALSE,
    update_tau_only = FALSE,
    tau_update_count = 0L,
    has_post_warmup_tau_update = FALSE,
    last_schedule = list(),
    collapse_diag = NULL
  )
}

.static_rhs_init_mcmc_state <- function(p, ctrl) {
  lam0 <- ctrl$init_lambda
  if (length(lam0) == 1L) lam0 <- rep(lam0, p)
  lam0 <- pmax(as.numeric(lam0), 1e-16)
  if (length(lam0) != p) stop("beta_prior_controls$init_lambda must be scalar or length p.")
  tau0 <- as.numeric(ctrl$init_tau)[1]
  c20 <- if (!is.null(ctrl$init_c2)) ctrl$init_c2 else ctrl$s2
  list(
    p = p,
    shrink_intercept = ctrl$shrink_intercept,
    intercept_prec = ctrl$intercept_prec,
    lambda = lam0,
    tau = pmax(as.numeric(tau0)[1], 1e-16),
    c2 = pmax(as.numeric(c20)[1], 1e-16)
  )
}

.static_rhs_expected_prec_vb <- function(state, ctrl) {
  p <- state$p
  mu_lam <- as.numeric(state$eta_lambda_hat)
  mu_tau <- as.numeric(state$eta_tau_hat)
  mu_c <- as.numeric(state$eta_c_hat)
  Sigma_full <- state$Sigma_full
  if (is.null(Sigma_full) || !all(dim(Sigma_full) == c(p + 2L, p + 2L))) {
    Sigma_full <- diag(pmax(state$Sigma_diag, ctrl$var_floor), p + 2L)
  }
  var_kap <- max(Sigma_full[p + 2L, p + 2L], 0)
  r_hat <- .static_rhs_safe_exp(-mu_c)
  prec <- numeric(p)
  for (j in seq_len(p)) {
    if (!isTRUE(ctrl$shrink_intercept) && j == 1L) {
      prec[j] <- ctrl$intercept_prec
      next
    }
    t_hat <- .static_rhs_safe_exp(-2 * (mu_lam[j] + mu_tau))
    v_sum <- Sigma_full[j, j] + Sigma_full[p + 1L, p + 1L] + 2 * Sigma_full[j, p + 1L]
    v_sum <- max(v_sum, 0)
    delta <- 0.5 * (4 * t_hat * v_sum + r_hat * var_kap)
    prec[j] <- t_hat + r_hat + delta
  }
  pmax(prec, 1e-16)
}

.static_rhs_vb_schedule <- function(state, ctrl, iter_now) {
  tau_warmup <- isTRUE(ctrl$freeze_tau_warmup_iters > 0L && iter_now <= ctrl$freeze_tau_warmup_iters)
  update_every_eff <- ctrl$update_every
  if (ctrl$update_every_warmup_iters > 0L && iter_now <= ctrl$update_every_warmup_iters) {
    update_every_eff <- ctrl$update_every_warmup
  }
  scheduled_rhs_update <- (update_every_eff <= 1L) || ((iter_now %% update_every_eff) == 0L)
  force_tau_now <- !tau_warmup &&
    isTRUE(ctrl$force_tau_after_warmup) &&
    isTRUE(ctrl$freeze_tau_warmup_iters > 0L) &&
    !isTRUE(state$has_post_warmup_tau_update)
  do_update <- isTRUE(scheduled_rhs_update || force_tau_now)
  update_tau_only <- isTRUE(force_tau_now && !scheduled_rhs_update)
  reason <- if (tau_warmup) {
    "warmup"
  } else if (update_tau_only) {
    "force_after_warmup"
  } else if (scheduled_rhs_update) {
    "scheduled"
  } else {
    "rhs_update_skipped"
  }
  list(
    iter = iter_now,
    tau_warmup = tau_warmup,
    update_every_eff = update_every_eff,
    scheduled_rhs_update = scheduled_rhs_update,
    force_tau_now = force_tau_now,
    do_update = do_update,
    update_tau_only = update_tau_only,
    reason = reason
  )
}

.static_rhs_collapse_diag <- function(state, qbeta, ctrl) {
  idx <- .static_rhs_active_idx(state$p, ctrl$shrink_intercept)
  beta_use <- if (length(idx)) as.numeric(qbeta$m)[idx] else numeric(0)
  tau <- .static_rhs_safe_exp(state$eta_tau_hat)
  log_tau <- as.numeric(state$eta_tau_hat)[1]
  tau0 <- max(as.numeric(ctrl$tau0)[1], 1e-16)
  tau_ratio <- tau / tau0
  slope_l2 <- if (length(beta_use)) sqrt(sum(beta_use^2)) else NA_real_
  slope_max_abs <- if (length(beta_use)) max(abs(beta_use)) else NA_real_
  small_beta_abs_tol <- as.numeric(ctrl$small_beta_abs_tol)[1]
  small_beta_frac <- if (length(beta_use)) {
    mean(abs(beta_use) <= small_beta_abs_tol)
  } else {
    NA_real_
  }
  E_invV <- .static_rhs_expected_prec_vb(state, ctrl)
  E_invV_use <- if (length(idx)) as.numeric(E_invV)[idx] else numeric(0)
  E_invV_med <- if (length(E_invV_use) && any(is.finite(E_invV_use))) stats::median(E_invV_use[is.finite(E_invV_use)]) else NA_real_
  tau_near_zero <- isTRUE(is.finite(tau_ratio) && tau_ratio <= ctrl$collapse_tau_ratio_tol) ||
    isTRUE(abs(as.numeric(state$eta_tau_hat) - ctrl$eta_bounds$tau[1]) <= 1e-6)
  slope_collapse <- isTRUE(is.finite(slope_max_abs) && slope_max_abs <= ctrl$collapse_beta_max_abs_tol)
  precision_beta_pattern <- isTRUE(
    is.finite(E_invV_med) && E_invV_med >= ctrl$collapse_invV_med_tol &&
      is.finite(slope_l2) && slope_l2 <= ctrl$collapse_beta_l2_tol &&
      is.finite(small_beta_frac) && small_beta_frac >= ctrl$collapse_small_beta_frac_tol
  )
  collapse_flag <- isTRUE((tau_near_zero && slope_collapse) || precision_beta_pattern)
  warning_msg <- if (collapse_flag) {
    if (isTRUE(precision_beta_pattern) && !isTRUE(tau_near_zero && slope_collapse)) {
      paste(
        "RHS shrinkage-collapse detected from precision/beta pattern",
        "(large E_invV + tiny beta norm + high near-zero-beta fraction).",
        "Consider revising tau initialization and RHS controls."
      )
    } else {
      paste(
        "RHS global scale collapsed near zero and active coefficients collapsed toward zero.",
        "Consider a larger tau0 and/or RHS tau warmup/freeze tuning."
      )
    }
  } else {
    NA_character_
  }
  list(
    collapse_flag = collapse_flag,
    precision_beta_pattern = precision_beta_pattern,
    tau_near_zero = tau_near_zero,
    slope_collapse = slope_collapse,
    beta_collapse = slope_collapse,
    tau = tau,
    log_tau = log_tau,
    tau0 = tau0,
    tau_ratio = tau_ratio,
    E_invV_med = E_invV_med,
    slope_l2 = slope_l2,
    beta_l2 = slope_l2,
    slope_max_abs = slope_max_abs,
    small_beta_frac = small_beta_frac,
    small_beta_abs_tol = small_beta_abs_tol,
    active_count = length(idx),
    eta_tau = as.numeric(state$eta_tau_hat)[1],
    eta_tau_lower = ctrl$eta_bounds$tau[1],
    at_tau_lower_bound = isTRUE(abs(as.numeric(state$eta_tau_hat)[1] - ctrl$eta_bounds$tau[1]) <= 1e-6),
    warning = warning_msg
  )
}

.static_rhs_collapse_diag_mcmc <- function(state, beta, ctrl) {
  idx <- .static_rhs_active_idx(state$p, ctrl$shrink_intercept)
  beta_use <- if (length(idx)) as.numeric(beta)[idx] else numeric(0)
  tau <- pmax(as.numeric(state$tau)[1], 1e-16)
  log_tau <- log(tau)
  tau0 <- max(as.numeric(ctrl$tau0)[1], 1e-16)
  tau_ratio <- tau / tau0
  slope_l2 <- if (length(beta_use)) sqrt(sum(beta_use^2)) else NA_real_
  slope_max_abs <- if (length(beta_use)) max(abs(beta_use)) else NA_real_
  small_beta_abs_tol <- as.numeric(ctrl$small_beta_abs_tol)[1]
  small_beta_frac <- if (length(beta_use)) mean(abs(beta_use) <= small_beta_abs_tol) else NA_real_
  invV <- .static_rhs_prec_mcmc(state, ctrl)
  invV_use <- if (length(idx)) as.numeric(invV)[idx] else numeric(0)
  E_invV_med <- if (length(invV_use) && any(is.finite(invV_use))) stats::median(invV_use[is.finite(invV_use)]) else NA_real_
  tau_near_zero <- isTRUE(is.finite(tau_ratio) && tau_ratio <= ctrl$collapse_tau_ratio_tol) ||
    isTRUE(log_tau <= (ctrl$eta_bounds$tau[1] + 1e-6))
  slope_collapse <- isTRUE(is.finite(slope_max_abs) && slope_max_abs <= ctrl$collapse_beta_max_abs_tol)
  precision_beta_pattern <- isTRUE(
    is.finite(E_invV_med) && E_invV_med >= ctrl$collapse_invV_med_tol &&
      is.finite(slope_l2) && slope_l2 <= ctrl$collapse_beta_l2_tol &&
      is.finite(small_beta_frac) && small_beta_frac >= ctrl$collapse_small_beta_frac_tol
  )
  collapse_flag <- isTRUE((tau_near_zero && slope_collapse) || precision_beta_pattern)
  warning_msg <- if (collapse_flag) {
    if (isTRUE(precision_beta_pattern) && !isTRUE(tau_near_zero && slope_collapse)) {
      paste(
        "RHS shrinkage-collapse detected from precision/beta pattern",
        "(large E_invV + tiny beta norm + high near-zero-beta fraction).",
        "Consider revising tau initialization and RHS controls."
      )
    } else {
      paste(
        "RHS global scale collapsed near zero and active coefficients collapsed toward zero.",
        "Consider a larger tau0 and/or RHS tau warmup/freeze tuning."
      )
    }
  } else {
    NA_character_
  }
  list(
    collapse_flag = collapse_flag,
    precision_beta_pattern = precision_beta_pattern,
    tau_near_zero = tau_near_zero,
    slope_collapse = slope_collapse,
    beta_collapse = slope_collapse,
    tau = tau,
    log_tau = log_tau,
    tau0 = tau0,
    tau_ratio = tau_ratio,
    E_invV_med = E_invV_med,
    slope_l2 = slope_l2,
    beta_l2 = slope_l2,
    slope_max_abs = slope_max_abs,
    small_beta_frac = small_beta_frac,
    small_beta_abs_tol = small_beta_abs_tol,
    active_count = length(idx),
    eta_tau_lower = ctrl$eta_bounds$tau[1],
    at_tau_lower_bound = isTRUE(log_tau <= (ctrl$eta_bounds$tau[1] + 1e-6)),
    warning = warning_msg
  )
}

.static_rhs_maybe_warn_collapse <- function(rhs_summary, ctrl) {
  if (!isTRUE(ctrl$warn_on_collapse) || is.null(rhs_summary) || !isTRUE(rhs_summary$collapse_flag)) return(invisible(FALSE))
  warning(rhs_summary$warning, call. = FALSE)
  invisible(TRUE)
}

.static_rhs_update_vb <- function(state, qbeta, ctrl) {
  p <- state$p
  beta2 <- as.numeric(qbeta$m^2 + diag(qbeta$V))
  eta_lam <- as.numeric(state$eta_lambda_hat)
  eta_tau <- as.numeric(state$eta_tau_hat)
  eta_c2 <- as.numeric(state$eta_c_hat)
  if (!is.null(ctrl$zeta2_fixed)) eta_c2 <- log(as.numeric(ctrl$zeta2_fixed)[1])
  active_idx <- .static_rhs_active_idx(p, ctrl$shrink_intercept)
  iter_now <- as.integer(.static_prior_or(state$iter, 0L)) + 1L
  sched <- .static_rhs_vb_schedule(state, ctrl, iter_now)
  tau_updated <- FALSE

  if (isTRUE(sched$do_update)) {
    update_tau_only <- isTRUE(sched$update_tau_only)
    for (inner in seq_len(ctrl$n_inner)) {
      if (!isTRUE(update_tau_only)) {
        for (j in active_idx) {
          f_j <- function(eta_j) {
            et <- eta_lam
            et[j] <- eta_j
            .static_rhs_obj_eta(et, eta_tau, eta_c2, beta2, ctrl)
          }
          eta_lam[j] <- .static_rhs_opt_1d_mode(
            f_j,
            lo = ctrl$eta_bounds$lambda[1],
            hi = ctrl$eta_bounds$lambda[2],
            eta0 = eta_lam[j]
          )
        }
      }

      if (!isTRUE(sched$tau_warmup)) {
        f_tau <- function(etau) .static_rhs_obj_eta(eta_lam, etau, eta_c2, beta2, ctrl)
        eta_tau <- .static_rhs_opt_1d_mode(
          f_tau,
          lo = ctrl$eta_bounds$tau[1],
          hi = ctrl$eta_bounds$tau[2],
          eta0 = eta_tau
        )
        tau_updated <- TRUE
      }

      if (!isTRUE(update_tau_only) && is.null(ctrl$zeta2_fixed)) {
        f_c2 <- function(ec) .static_rhs_obj_eta(eta_lam, eta_tau, ec, beta2, ctrl)
        eta_c2 <- .static_rhs_opt_1d_mode(
          f_c2,
          lo = ctrl$eta_bounds$c2[1],
          hi = ctrl$eta_bounds$c2[2],
          eta0 = eta_c2
        )
      }
    }

    hess <- .static_rhs_hess_active(eta_lam, eta_tau, eta_c2, beta2, ctrl)
    invK <- .static_rhs_inv_spd_with_jitter(-hess$H, ctrl$var_floor)
    Sigma_full <- .static_rhs_embed_sigma_full(invK$inv, idx = hess$idx, p = p, var_floor = ctrl$var_floor)
    state$Sigma_full <- Sigma_full
    state$Sigma_diag <- diag(Sigma_full)
  }

  state$eta_lambda_hat <- eta_lam
  state$eta_tau_hat <- eta_tau
  state$eta_c_hat <- if (!is.null(ctrl$zeta2_fixed)) log(as.numeric(ctrl$zeta2_fixed)[1]) else eta_c2
  state$iter <- iter_now
  state$freeze_tau <- isTRUE(sched$tau_warmup)
  state$update_tau_only <- isTRUE(sched$update_tau_only)
  state$tau_update_count <- as.integer(.static_prior_or(state$tau_update_count, 0L)) + if (tau_updated) 1L else 0L
  state$has_post_warmup_tau_update <- isTRUE(.static_prior_or(state$has_post_warmup_tau_update, FALSE) || tau_updated)
  state$last_schedule <- c(
    sched,
    list(
      tau_updated = tau_updated,
      tau_update_count = state$tau_update_count
    )
  )
  state$collapse_diag <- .static_rhs_collapse_diag(state, qbeta, ctrl)
  state
}

.static_rhs_elbo_vb <- function(state, qbeta, ctrl) {
  p <- state$p
  beta2 <- as.numeric(qbeta$m^2 + diag(qbeta$V))
  eta_lam <- as.numeric(state$eta_lambda_hat)
  eta_tau <- as.numeric(state$eta_tau_hat)
  eta_c2 <- as.numeric(state$eta_c_hat)
  f0 <- .static_rhs_obj_eta(eta_lam, eta_tau, eta_c2, beta2, ctrl)
  hess <- .static_rhs_hess_active(eta_lam, eta_tau, eta_c2, beta2, ctrl)
  act <- c(hess$idx, p + 1L, p + 2L)
  Sigma_full <- state$Sigma_full
  if (is.null(Sigma_full) || !all(dim(Sigma_full) == c(p + 2L, p + 2L))) {
    Sigma_full <- diag(pmax(state$Sigma_diag, ctrl$var_floor), p + 2L)
  }
  Sigma_act <- Sigma_full[act, act, drop = FALSE]
  trHS <- sum(hess$H * Sigma_act)
  ld <- .static_rhs_inv_spd_with_jitter(Sigma_act, ctrl$var_floor)$logdet
  H_qeta <- 0.5 * (nrow(Sigma_act) * (1 + log(2 * pi)) + ld)
  f0 + 0.5 * trHS + H_qeta
}

.static_rhs_prec_mcmc <- function(state, ctrl) {
  p <- state$p
  invV <- 1 / (state$tau^2 * state$lambda^2) + 1 / state$c2
  invV <- pmax(invV, 1e-16)
  if (!isTRUE(ctrl$shrink_intercept) && p >= 1L) invV[1] <- ctrl$intercept_prec
  invV
}

.static_rhs_logtarget_eta <- function(eta_lambda, eta_tau, eta_c2, beta2, ctrl) {
  .static_rhs_obj_eta(eta_lambda, eta_tau, eta_c2, beta2, ctrl)
}

.static_rhs_update_mcmc <- function(state, beta, ctrl, slice_width = 1, slice_max_steps = 20) {
  beta2 <- as.numeric(beta)^2
  eta_lam <- log(pmax(state$lambda, 1e-16))
  eta_tau <- log(pmax(state$tau, 1e-16))
  eta_c2 <- log(pmax(state$c2, 1e-16))
  if (!is.null(ctrl$zeta2_fixed)) eta_c2 <- log(as.numeric(ctrl$zeta2_fixed)[1])

  for (j in .static_rhs_active_idx(length(beta2), ctrl$shrink_intercept)) {
    log_density_j <- function(eta_j) {
      et <- eta_lam
      et[j] <- eta_j
      .static_rhs_logtarget_eta(et, eta_tau, eta_c2, beta2, ctrl)
    }
    eta_lam[j] <- .exdqlm_uni_slice_bounded(
        x0 = eta_lam[j],
        log_density = log_density_j,
        w = slice_width,
        m = slice_max_steps,
        lower = ctrl$eta_bounds$lambda[1],
        upper = ctrl$eta_bounds$lambda[2]
      )$value
  }

  eta_tau <- .exdqlm_uni_slice_bounded(
    x0 = eta_tau,
    log_density = function(etau) .static_rhs_logtarget_eta(eta_lam, etau, eta_c2, beta2, ctrl),
    w = slice_width,
    m = slice_max_steps,
    lower = ctrl$eta_bounds$tau[1],
    upper = ctrl$eta_bounds$tau[2]
  )$value

  if (is.null(ctrl$zeta2_fixed)) {
    eta_c2 <- .exdqlm_uni_slice_bounded(
      x0 = eta_c2,
      log_density = function(ec) .static_rhs_logtarget_eta(eta_lam, eta_tau, ec, beta2, ctrl),
      w = slice_width,
      m = slice_max_steps,
      lower = ctrl$eta_bounds$c2[1],
      upper = ctrl$eta_bounds$c2[2]
    )$value
  } else {
    eta_c2 <- log(as.numeric(ctrl$zeta2_fixed)[1])
  }

  state$lambda <- .static_rhs_safe_exp(eta_lam)
  state$tau <- .static_rhs_safe_exp(eta_tau)
  state$c2 <- if (!is.null(ctrl$zeta2_fixed)) as.numeric(ctrl$zeta2_fixed)[1] else .static_rhs_safe_exp(eta_c2)
  state
}

.static_beta_prior_make <- function(beta_prior = c("ridge", "rhs", "rhs_ns"), p, b0, V0, beta_prior_controls = NULL,
                                    warn_rhs_b0 = FALSE, warn_rhs_V0 = FALSE) {
  beta_prior <- .static_match_beta_prior(beta_prior)
  V0_inv <- tryCatch(solve(V0), error = function(e) solve(V0 + 1e-8 * diag(ncol(V0))))
  logdetV0 <- as.numeric(determinant(V0, logarithm = TRUE)$modulus)

  if (identical(beta_prior, "ridge")) {
    return(list(
      type = "ridge",
      controls = NULL,
      init_vb = function() list(),
      init_mcmc = function() list(),
      beta_system_vb = function(state) list(Prec = V0_inv, h = drop(V0_inv %*% b0)),
      beta_system_mcmc = function(state) list(Prec = V0_inv, h = drop(V0_inv %*% b0)),
      update_vb = function(state, qbeta) state,
      update_mcmc = function(state, beta, ...) state,
      elbo_vb = function(state, qbeta) {
        - (p / 2) * log(2 * pi) - 0.5 * logdetV0 -
          0.5 * (sum(V0_inv * qbeta$V) + drop(crossprod(qbeta$m - b0, V0_inv %*% (qbeta$m - b0))))
      },
      summary_vb = function(state) NULL,
      summary_mcmc = function(state, beta = NULL) NULL
    ))
  }

  ctrl <- .static_parse_beta_prior_controls(beta_prior_controls, prior_type = beta_prior)
  if (warn_rhs_b0 || warn_rhs_V0) {
    warning(
      sprintf(
        "beta_prior = '%s' ignores b0/V0 for the shrunk coefficients; they are only retained for backward-compatible ridge behavior.",
        beta_prior
      ),
      call. = FALSE
    )
  }

  list(
    type = beta_prior,
    controls = ctrl,
    init_vb = function() .static_rhs_init_vb_state(p, ctrl),
    init_mcmc = function() .static_rhs_init_mcmc_state(p, ctrl),
    beta_system_vb = function(state) {
      prec <- .static_rhs_expected_prec_vb(state, ctrl)
      list(Prec = diag(prec, p), h = rep(0, p), prec_diag = prec)
    },
    beta_system_mcmc = function(state) {
      prec <- .static_rhs_prec_mcmc(state, ctrl)
      list(Prec = diag(prec, p), h = rep(0, p), prec_diag = prec)
    },
    update_vb = function(state, qbeta) .static_rhs_update_vb(state, qbeta, ctrl),
    update_mcmc = function(state, beta, slice_width = NULL, slice_max_steps = NULL) {
      .static_rhs_update_mcmc(
        state,
        beta,
        ctrl,
        slice_width = .static_prior_or(slice_width, ctrl$slice_width),
        slice_max_steps = .static_prior_or(slice_max_steps, ctrl$slice_max_steps)
      )
    },
    elbo_vb = function(state, qbeta) .static_rhs_elbo_vb(state, qbeta, ctrl),
    summary_vb = function(state) {
      idx <- .static_rhs_active_idx(state$p, ctrl$shrink_intercept)
      lam <- .static_rhs_safe_exp(state$eta_lambda_hat[idx])
      collapse_diag <- .static_prior_or(state$collapse_diag, list())
      list(
        tau = .static_rhs_safe_exp(state$eta_tau_hat),
        log_tau = as.numeric(state$eta_tau_hat)[1],
        c2 = .static_rhs_safe_exp(state$eta_c_hat),
        zeta2 = .static_rhs_safe_exp(state$eta_c_hat),
        lambda = lam,
        lambda_mean = if (length(lam)) mean(lam) else NA_real_,
        lambda_min = if (length(lam)) min(lam) else NA_real_,
        lambda_max = if (length(lam)) max(lam) else NA_real_,
        shrink_intercept = ctrl$shrink_intercept,
        tau0 = ctrl$tau0,
        nu = ctrl$nu,
        s = ctrl$s,
        s2 = ctrl$s2,
        a_zeta = as.numeric(.static_prior_or(ctrl$a_zeta, NA_real_))[1],
        b_zeta = as.numeric(.static_prior_or(ctrl$b_zeta, NA_real_))[1],
        zeta2_fixed = as.numeric(.static_prior_or(ctrl$zeta2_fixed, NA_real_))[1],
        rhs_iter = as.integer(.static_prior_or(state$iter, NA_integer_)),
        rhs_tau_update_count = as.integer(.static_prior_or(state$tau_update_count, NA_integer_)),
        rhs_tau_warmup_last = isTRUE(.static_prior_or(state$last_schedule$tau_warmup, FALSE)),
        rhs_update_reason_last = as.character(.static_prior_or(state$last_schedule$reason, NA_character_))[1],
        rhs_update_every_last = as.integer(.static_prior_or(state$last_schedule$update_every_eff, NA_integer_)),
        collapse_flag = isTRUE(collapse_diag$collapse_flag),
        collapse_pattern = isTRUE(collapse_diag$precision_beta_pattern),
        collapse_tau_near_zero = isTRUE(collapse_diag$tau_near_zero),
        collapse_beta = isTRUE(collapse_diag$slope_collapse),
        collapse_tau_ratio = as.numeric(collapse_diag$tau_ratio)[1],
        collapse_E_invV_med = as.numeric(collapse_diag$E_invV_med)[1],
        collapse_beta_l2 = as.numeric(collapse_diag$beta_l2)[1],
        collapse_small_beta_frac = as.numeric(collapse_diag$small_beta_frac)[1],
        collapse_small_beta_abs_tol = as.numeric(collapse_diag$small_beta_abs_tol)[1],
        collapse_slope_l2 = as.numeric(collapse_diag$slope_l2)[1],
        collapse_slope_max_abs = as.numeric(collapse_diag$slope_max_abs)[1],
        collapse_warning = as.character(.static_prior_or(collapse_diag$warning, NA_character_))[1],
        init_log_tau_resolved = as.numeric(ctrl$init_log_tau)[1],
        init_tau_resolved = as.numeric(ctrl$init_tau)[1],
        init_tau_source = as.character(ctrl$init_tau_source)[1],
        eta_tau_lower = as.numeric(ctrl$eta_bounds$tau[1]),
        eta_tau_upper = as.numeric(ctrl$eta_bounds$tau[2])
      )
    },
    summary_mcmc = function(state, beta = NULL) {
      idx <- .static_rhs_active_idx(state$p, ctrl$shrink_intercept)
      lam <- state$lambda[idx]
      collapse_diag <- if (!is.null(beta)) {
        .static_rhs_collapse_diag_mcmc(state, beta, ctrl)
      } else {
        list()
      }
      list(
        tau = state$tau,
        log_tau = log(pmax(as.numeric(state$tau)[1], 1e-16)),
        c2 = state$c2,
        zeta2 = state$c2,
        lambda = lam,
        lambda_mean = if (length(lam)) mean(lam) else NA_real_,
        lambda_min = if (length(lam)) min(lam) else NA_real_,
        lambda_max = if (length(lam)) max(lam) else NA_real_,
        shrink_intercept = ctrl$shrink_intercept,
        tau0 = ctrl$tau0,
        nu = ctrl$nu,
        s = ctrl$s,
        s2 = ctrl$s2,
        a_zeta = as.numeric(.static_prior_or(ctrl$a_zeta, NA_real_))[1],
        b_zeta = as.numeric(.static_prior_or(ctrl$b_zeta, NA_real_))[1],
        zeta2_fixed = as.numeric(.static_prior_or(ctrl$zeta2_fixed, NA_real_))[1],
        collapse_flag = if (!is.null(collapse_diag$collapse_flag)) isTRUE(collapse_diag$collapse_flag) else NA,
        collapse_pattern = if (!is.null(collapse_diag$precision_beta_pattern)) isTRUE(collapse_diag$precision_beta_pattern) else NA,
        collapse_tau_near_zero = if (!is.null(collapse_diag$tau_near_zero)) isTRUE(collapse_diag$tau_near_zero) else NA,
        collapse_beta = if (!is.null(collapse_diag$slope_collapse)) isTRUE(collapse_diag$slope_collapse) else NA,
        collapse_tau_ratio = as.numeric(.static_prior_or(collapse_diag$tau_ratio, NA_real_))[1],
        collapse_E_invV_med = as.numeric(.static_prior_or(collapse_diag$E_invV_med, NA_real_))[1],
        collapse_beta_l2 = as.numeric(.static_prior_or(collapse_diag$beta_l2, NA_real_))[1],
        collapse_small_beta_frac = as.numeric(.static_prior_or(collapse_diag$small_beta_frac, NA_real_))[1],
        collapse_small_beta_abs_tol = as.numeric(.static_prior_or(collapse_diag$small_beta_abs_tol, ctrl$small_beta_abs_tol))[1],
        collapse_warning = as.character(.static_prior_or(collapse_diag$warning, NA_character_))[1],
        init_log_tau_resolved = as.numeric(ctrl$init_log_tau)[1],
        init_tau_resolved = as.numeric(ctrl$init_tau)[1],
        init_tau_source = as.character(ctrl$init_tau_source)[1],
        eta_tau_lower = as.numeric(ctrl$eta_bounds$tau[1]),
        eta_tau_upper = as.numeric(ctrl$eta_bounds$tau[2])
      )
    }
  )
}
