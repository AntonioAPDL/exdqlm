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

.exal_static_ld_controls <- function(ld_controls = NULL) {
  defaults <- list(
    xi_method = getOption("exdqlm.static.ldvb.xi_method", "delta"),
    optimizer_method = getOption("exdqlm.static.ldvb.optimizer_method", "lbfgsb"),
    direct_commit = getOption("exdqlm.static.ldvb.direct_commit", NULL),
    damping = getOption("exdqlm.static.ldvb.damping", NULL),
    xi_damping = getOption("exdqlm.static.ldvb.xi_damping", NULL),
    xi_mode = getOption("exdqlm.static.ldvb.xi_mode", "single"),
    xi_replicates = getOption("exdqlm.static.ldvb.xi_replicates", 1L),
    reuse_draws = getOption("exdqlm.static.ldvb.reuse_draws", TRUE),
    antithetic = getOption("exdqlm.static.ldvb.antithetic", TRUE),
    optimizer_maxit = getOption("exdqlm.static.ldvb.optimizer_maxit", NULL),
    eig_floor = getOption("exdqlm.static.ldvb.eig_floor", 1e-6),
    eig_cap = getOption("exdqlm.static.ldvb.eig_cap", NULL),
    step_cap_eta = getOption("exdqlm.static.ldvb.step_cap_eta", NULL),
    step_cap_ell = getOption("exdqlm.static.ldvb.step_cap_ell", NULL),
    eta_lo = getOption("exdqlm.static.ldvb.eta_lo", -12),
    eta_hi = getOption("exdqlm.static.ldvb.eta_hi", 12),
    sigma_bounds = getOption("exdqlm.static.ldvb.sigma_bounds", NULL),
    sigma_init_mode = getOption("exdqlm.static.ldvb.sigma_init_mode", "data_scale"),
    sigma_floor_abs = getOption("exdqlm.static.ldvb.sigma_floor_abs", 1e-6),
    sigma_min_mult = getOption("exdqlm.static.ldvb.sigma_min_mult", 1e-3),
    sigma_max_mult = getOption("exdqlm.static.ldvb.sigma_max_mult", 1e3),
    sigma_bound_ratio_min = getOption("exdqlm.static.ldvb.sigma_bound_ratio_min", 10),
    gamma_init_pad_frac = getOption("exdqlm.static.ldvb.gamma_init_pad_frac", 0.05),
    logit_eps = getOption("exdqlm.static.ldvb.logit_eps", 1e-8),
    init_cov_diag = getOption("exdqlm.static.ldvb.init_cov_diag", c(1e-2, 1e-2)),
    reuse_seed = getOption("exdqlm.static.ldvb.reuse_seed", NA_integer_),
    mode_grad_tol = getOption("exdqlm.static.ldvb.mode_grad_tol", 5e-3),
    mode_min_eig = getOption("exdqlm.static.ldvb.mode_min_eig", 1e-8),
    auto_stabilize = getOption("exdqlm.static.ldvb.auto_stabilize", TRUE),
    cycle_window = getOption("exdqlm.static.ldvb.cycle_window", 8L),
    cycle_lag1_max = getOption("exdqlm.static.ldvb.cycle_lag1_max", -0.8),
    cycle_lag2_min = getOption("exdqlm.static.ldvb.cycle_lag2_min", 0.95),
    cycle_gamma_min_amp = getOption("exdqlm.static.ldvb.cycle_gamma_min_amp", 1e-3),
    cycle_sigma_min_amp = getOption("exdqlm.static.ldvb.cycle_sigma_min_amp", 1e-3),
    cycle_s_min_amp = getOption("exdqlm.static.ldvb.cycle_s_min_amp", 1e-5),
    cycle_tau2_min_amp = getOption("exdqlm.static.ldvb.cycle_tau2_min_amp", 1e-5),
    stabilize_damping = getOption("exdqlm.static.ldvb.stabilize_damping", 0.25),
    stabilize_xi_damping = getOption("exdqlm.static.ldvb.stabilize_xi_damping", 0.25),
    stabilize_xi_method = getOption("exdqlm.static.ldvb.stabilize_xi_method", "mc"),
    stabilize_step_cap_eta = getOption("exdqlm.static.ldvb.stabilize_step_cap_eta", 2.0),
    stabilize_step_cap_ell = getOption("exdqlm.static.ldvb.stabilize_step_cap_ell", 0.75),
    reject_bad_mode_commit = getOption("exdqlm.static.ldvb.reject_bad_mode_commit", TRUE),
    store_trace = getOption("exdqlm.static.ldvb.store_trace", TRUE)
  )
  if (!is.null(ld_controls)) {
    defaults <- utils::modifyList(defaults, ld_controls)
  }

  defaults$xi_method <- match.arg(as.character(defaults$xi_method)[1], c("delta", "mc"))
  defaults$optimizer_method <- match.arg(as.character(defaults$optimizer_method)[1], c("lbfgsb", "bfgs"))
  if (is.null(defaults$direct_commit)) {
    defaults$direct_commit <- identical(defaults$optimizer_method, "lbfgsb")
  }
  defaults$direct_commit <- isTRUE(defaults$direct_commit)
  if (is.null(defaults$damping)) {
    defaults$damping <- if (defaults$direct_commit) 1 else 0.45
  }
  defaults$damping <- as.numeric(defaults$damping)[1]
  if (!is.finite(defaults$damping) || defaults$damping <= 0 || defaults$damping > 1) {
    defaults$damping <- if (defaults$direct_commit) 1 else 0.45
  }
  if (is.null(defaults$xi_damping)) {
    defaults$xi_damping <- if (identical(defaults$xi_method, "delta")) 1 else defaults$damping
  }
  defaults$xi_damping <- as.numeric(defaults$xi_damping)[1]
  if (!is.finite(defaults$xi_damping) || defaults$xi_damping <= 0 || defaults$xi_damping > 1) {
    defaults$xi_damping <- if (identical(defaults$xi_method, "delta")) 1 else defaults$damping
  }
  defaults$xi_mode <- match.arg(as.character(defaults$xi_mode)[1], c("single", "replicated"))
  defaults$xi_replicates <- suppressWarnings(as.integer(defaults$xi_replicates)[1])
  if (!is.finite(defaults$xi_replicates) || defaults$xi_replicates < 1L) defaults$xi_replicates <- 1L
  if (identical(defaults$xi_mode, "single")) defaults$xi_replicates <- 1L
  defaults$reuse_draws <- isTRUE(defaults$reuse_draws) && identical(defaults$xi_method, "mc")
  defaults$antithetic <- isTRUE(defaults$antithetic)
  if (is.null(defaults$optimizer_maxit)) {
    defaults$optimizer_maxit <- if (identical(defaults$optimizer_method, "lbfgsb")) 2000L else 200L
  }
  defaults$optimizer_maxit <- suppressWarnings(as.integer(defaults$optimizer_maxit)[1])
  if (!is.finite(defaults$optimizer_maxit) || defaults$optimizer_maxit < 20L) {
    defaults$optimizer_maxit <- if (identical(defaults$optimizer_method, "lbfgsb")) 2000L else 200L
  }
  defaults$eig_floor <- as.numeric(defaults$eig_floor)[1]
  if (!is.finite(defaults$eig_floor) || defaults$eig_floor <= 0) defaults$eig_floor <- 1e-6
  if (is.null(defaults$eig_cap)) {
    defaults$eig_cap <- if (defaults$direct_commit && identical(defaults$xi_method, "delta")) 1 else 25
  }
  defaults$eig_cap <- as.numeric(defaults$eig_cap)[1]
  if (!is.finite(defaults$eig_cap) || defaults$eig_cap <= defaults$eig_floor) {
    defaults$eig_cap <- if (defaults$direct_commit && identical(defaults$xi_method, "delta")) 1 else 25
  }
  if (is.null(defaults$step_cap_eta)) defaults$step_cap_eta <- if (defaults$direct_commit) Inf else 2.0
  defaults$step_cap_eta <- as.numeric(defaults$step_cap_eta)[1]
  if (is.na(defaults$step_cap_eta)) defaults$step_cap_eta <- if (defaults$direct_commit) Inf else 2.0
  if (is.null(defaults$step_cap_ell)) defaults$step_cap_ell <- if (defaults$direct_commit) Inf else 0.75
  defaults$step_cap_ell <- as.numeric(defaults$step_cap_ell)[1]
  if (is.na(defaults$step_cap_ell)) defaults$step_cap_ell <- if (defaults$direct_commit) Inf else 0.75
  defaults$eta_lo <- as.numeric(defaults$eta_lo)[1]
  defaults$eta_hi <- as.numeric(defaults$eta_hi)[1]
  if (!is.finite(defaults$eta_lo)) defaults$eta_lo <- -12
  if (!is.finite(defaults$eta_hi)) defaults$eta_hi <- 12
  if (defaults$eta_lo >= defaults$eta_hi) {
    defaults$eta_lo <- -12
    defaults$eta_hi <- 12
  }
  defaults$sigma_init_mode <- match.arg(as.character(defaults$sigma_init_mode)[1], c("data_scale", "fixed1"))
  defaults$sigma_floor_abs <- as.numeric(defaults$sigma_floor_abs)[1]
  if (!is.finite(defaults$sigma_floor_abs) || defaults$sigma_floor_abs <= 0) defaults$sigma_floor_abs <- 1e-6
  defaults$sigma_min_mult <- as.numeric(defaults$sigma_min_mult)[1]
  if (!is.finite(defaults$sigma_min_mult) || defaults$sigma_min_mult <= 0) defaults$sigma_min_mult <- 1e-3
  defaults$sigma_max_mult <- as.numeric(defaults$sigma_max_mult)[1]
  if (!is.finite(defaults$sigma_max_mult) || defaults$sigma_max_mult <= defaults$sigma_min_mult) defaults$sigma_max_mult <- 1e3
  defaults$sigma_bound_ratio_min <- as.numeric(defaults$sigma_bound_ratio_min)[1]
  if (!is.finite(defaults$sigma_bound_ratio_min) || defaults$sigma_bound_ratio_min <= 1) defaults$sigma_bound_ratio_min <- 10
  if (!is.null(defaults$sigma_bounds)) {
    defaults$sigma_bounds <- as.numeric(defaults$sigma_bounds)
    if (length(defaults$sigma_bounds) != 2L || any(!is.finite(defaults$sigma_bounds)) || defaults$sigma_bounds[1] <= 0 || defaults$sigma_bounds[1] >= defaults$sigma_bounds[2]) {
      defaults$sigma_bounds <- NULL
    }
  }
  defaults$gamma_init_pad_frac <- as.numeric(defaults$gamma_init_pad_frac)[1]
  if (!is.finite(defaults$gamma_init_pad_frac) || defaults$gamma_init_pad_frac < 0 || defaults$gamma_init_pad_frac >= 0.5) {
    defaults$gamma_init_pad_frac <- 0.05
  }
  defaults$logit_eps <- as.numeric(defaults$logit_eps)[1]
  if (!is.finite(defaults$logit_eps) || defaults$logit_eps <= 0 || defaults$logit_eps >= 0.25) defaults$logit_eps <- 1e-8
  defaults$init_cov_diag <- as.numeric(defaults$init_cov_diag)
  if (length(defaults$init_cov_diag) != 2L || any(!is.finite(defaults$init_cov_diag)) || any(defaults$init_cov_diag <= 0)) {
    defaults$init_cov_diag <- c(1e-2, 1e-2)
  }
  defaults$reuse_seed <- suppressWarnings(as.integer(defaults$reuse_seed)[1])
  if (!is.finite(defaults$reuse_seed)) defaults$reuse_seed <- NA_integer_
  defaults$mode_grad_tol <- as.numeric(defaults$mode_grad_tol)[1]
  if (!is.finite(defaults$mode_grad_tol) || defaults$mode_grad_tol <= 0) defaults$mode_grad_tol <- 5e-3
  defaults$mode_min_eig <- as.numeric(defaults$mode_min_eig)[1]
  if (!is.finite(defaults$mode_min_eig) || defaults$mode_min_eig <= 0) defaults$mode_min_eig <- 1e-8
  defaults$auto_stabilize <- isTRUE(defaults$auto_stabilize)
  defaults$cycle_window <- suppressWarnings(as.integer(defaults$cycle_window)[1])
  if (!is.finite(defaults$cycle_window) || defaults$cycle_window < 4L) defaults$cycle_window <- 8L
  defaults$cycle_lag1_max <- as.numeric(defaults$cycle_lag1_max)[1]
  if (!is.finite(defaults$cycle_lag1_max)) defaults$cycle_lag1_max <- -0.8
  defaults$cycle_lag2_min <- as.numeric(defaults$cycle_lag2_min)[1]
  if (!is.finite(defaults$cycle_lag2_min)) defaults$cycle_lag2_min <- 0.95
  defaults$cycle_gamma_min_amp <- as.numeric(defaults$cycle_gamma_min_amp)[1]
  if (!is.finite(defaults$cycle_gamma_min_amp) || defaults$cycle_gamma_min_amp < 0) defaults$cycle_gamma_min_amp <- 1e-3
  defaults$cycle_sigma_min_amp <- as.numeric(defaults$cycle_sigma_min_amp)[1]
  if (!is.finite(defaults$cycle_sigma_min_amp) || defaults$cycle_sigma_min_amp < 0) defaults$cycle_sigma_min_amp <- 1e-3
  defaults$cycle_s_min_amp <- as.numeric(defaults$cycle_s_min_amp)[1]
  if (!is.finite(defaults$cycle_s_min_amp) || defaults$cycle_s_min_amp < 0) defaults$cycle_s_min_amp <- 1e-5
  defaults$cycle_tau2_min_amp <- as.numeric(defaults$cycle_tau2_min_amp)[1]
  if (!is.finite(defaults$cycle_tau2_min_amp) || defaults$cycle_tau2_min_amp < 0) defaults$cycle_tau2_min_amp <- 1e-5
  defaults$stabilize_damping <- as.numeric(defaults$stabilize_damping)[1]
  if (!is.finite(defaults$stabilize_damping) || defaults$stabilize_damping <= 0 || defaults$stabilize_damping > 1) defaults$stabilize_damping <- 0.25
  defaults$stabilize_xi_damping <- as.numeric(defaults$stabilize_xi_damping)[1]
  if (!is.finite(defaults$stabilize_xi_damping) || defaults$stabilize_xi_damping <= 0 || defaults$stabilize_xi_damping > 1) defaults$stabilize_xi_damping <- 0.25
  defaults$stabilize_xi_method <- match.arg(as.character(defaults$stabilize_xi_method)[1], c("delta", "mc"))
  defaults$stabilize_step_cap_eta <- as.numeric(defaults$stabilize_step_cap_eta)[1]
  if (is.na(defaults$stabilize_step_cap_eta) || defaults$stabilize_step_cap_eta <= 0) defaults$stabilize_step_cap_eta <- 2.0
  defaults$stabilize_step_cap_ell <- as.numeric(defaults$stabilize_step_cap_ell)[1]
  if (is.na(defaults$stabilize_step_cap_ell) || defaults$stabilize_step_cap_ell <= 0) defaults$stabilize_step_cap_ell <- 0.75
  defaults$reject_bad_mode_commit <- isTRUE(defaults$reject_bad_mode_commit)
  defaults$store_trace <- isTRUE(defaults$store_trace)
  defaults
}

.exal_static_ld_scale_setup <- function(y, L, U, init = NULL, ld_ctrl) {
  y_scale <- stats::mad(y, constant = 1.4826)
  y_scale <- if (is.finite(y_scale) && y_scale > 0) y_scale else stats::sd(y)
  y_scale <- if (is.finite(y_scale) && y_scale > 0) y_scale else 1

  if (!is.null(ld_ctrl$sigma_bounds)) {
    sigma_min <- ld_ctrl$sigma_bounds[1]
    sigma_max <- ld_ctrl$sigma_bounds[2]
  } else {
    sigma_min <- max(ld_ctrl$sigma_floor_abs, y_scale * ld_ctrl$sigma_min_mult)
    sigma_max <- max(sigma_min * ld_ctrl$sigma_bound_ratio_min, y_scale * ld_ctrl$sigma_max_mult)
  }
  ell_lo <- log(sigma_min)
  ell_hi <- log(sigma_max)

  gamma0 <- if (!is.null(init$gamma)) as.numeric(init$gamma)[1] else 0
  pad <- ld_ctrl$gamma_init_pad_frac * (U - L)
  gamma0 <- min(max(gamma0, L + pad), U - pad)

  sigma0_default <- if (identical(ld_ctrl$sigma_init_mode, "data_scale")) y_scale else 1
  sigma0 <- if (!is.null(init$sigma)) as.numeric(init$sigma)[1] else sigma0_default
  sigma0 <- min(max(sigma0, sigma_min), sigma_max)

  u0 <- pmin(pmax((gamma0 - L) / (U - L), ld_ctrl$logit_eps), 1 - ld_ctrl$logit_eps)

  list(
    y_scale = y_scale,
    sigma_min = sigma_min,
    sigma_max = sigma_max,
    ell_lo = ell_lo,
    ell_hi = ell_hi,
    gamma0 = gamma0,
    sigma0 = sigma0,
    eta0 = stats::qlogis(u0),
    ell0 = log(sigma0)
  )
}

.exal_static_ld_make_base_draws <- function(ns, antithetic = TRUE, seed = NA_integer_) {
  ns <- max(1L, suppressWarnings(as.integer(ns)[1]))
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  if (is.finite(seed)) set.seed(seed)
  on.exit({
    if (!is.null(old_seed)) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    }
  }, add = TRUE)

  if (isTRUE(antithetic) && ns > 1L) {
    half <- ceiling(ns / 2)
    z_half <- matrix(stats::rnorm(2L * half), nrow = 2L, ncol = half)
    z <- cbind(z_half, -z_half)[, seq_len(ns), drop = FALSE]
  } else {
    z <- matrix(stats::rnorm(2L * ns), nrow = 2L, ncol = ns)
  }
  z
}

.exal_static_ld_named_numeric <- function(x) {
  xx <- unlist(x, use.names = TRUE)
  out <- as.numeric(xx)
  names(out) <- names(xx)
  out
}

.exal_static_ld_make_base_draws_list <- function(ns, replicates = 1L, antithetic = TRUE, seed = NA_integer_) {
  replicates <- max(1L, suppressWarnings(as.integer(replicates)[1]))
  lapply(seq_len(replicates), function(i) {
    seed_i <- if (is.finite(seed)) seed + (i - 1L) else NA_integer_
    .exal_static_ld_make_base_draws(ns = ns, antithetic = antithetic, seed = seed_i)
  })
}

.exal_static_ld_regularize_cov <- function(Sigma, eig_floor = 1e-6, eig_cap = 25) {
  S <- suppressWarnings(as.matrix(Sigma))
  if (!all(dim(S) == c(2L, 2L))) S <- diag(c(1e-4, 1e-4))
  S[!is.finite(S)] <- 0
  S <- (S + t(S)) / 2
  eig <- eigen(S, symmetric = TRUE)
  vals_raw <- eig$values
  vals <- pmin(pmax(vals_raw, eig_floor), eig_cap)
  S_reg <- eig$vectors %*% diag(vals, 2L, 2L) %*% t(eig$vectors)
  S_reg <- (S_reg + t(S_reg)) / 2
  list(
    Sigma = S_reg,
    eig_raw = vals_raw,
    eig_reg = vals,
    condition_raw = if (all(is.finite(vals_raw)) && min(abs(vals_raw)) > 0) {
      max(abs(vals_raw)) / min(abs(vals_raw))
    } else {
      NA_real_
    },
    condition_reg = max(vals) / min(vals)
  )
}

.exal_static_ld_cov_from_precision <- function(H, eig_floor = 1e-6, eig_cap = 25) {
  precision_floor <- 1 / max(eig_cap, eig_floor)
  precision_cap <- 1 / min(eig_floor, eig_cap)

  P <- suppressWarnings(as.matrix(H))
  if (!all(dim(P) == c(2L, 2L))) P <- diag(precision_floor, 2L)
  P[!is.finite(P)] <- 0
  P <- (P + t(P)) / 2

  eig <- eigen(P, symmetric = TRUE)
  vals_raw <- eig$values
  vals_reg <- pmin(pmax(vals_raw, precision_floor), precision_cap)
  cov_vals <- 1 / vals_reg
  Sigma <- eig$vectors %*% diag(cov_vals, 2L, 2L) %*% t(eig$vectors)
  Sigma <- (Sigma + t(Sigma)) / 2

  cov_raw <- ifelse(is.finite(vals_raw) & vals_raw > 0, 1 / vals_raw, NA_real_)
  list(
    Sigma = Sigma,
    precision_eig_raw = vals_raw,
    precision_eig_reg = vals_reg,
    cov_eig_raw = cov_raw,
    cov_eig_reg = cov_vals,
    condition_raw = if (all(is.finite(vals_raw)) && min(vals_raw) > 0) {
      max(vals_raw) / min(vals_raw)
    } else {
      NA_real_
    },
    condition_reg = max(cov_vals) / min(cov_vals),
    used_floor = any(!is.finite(vals_raw)) || any(abs(vals_reg - vals_raw) > 0)
  )
}

.exal_static_ld_rel_change <- function(new, old) {
  new <- as.numeric(new)
  old <- as.numeric(old)
  keep <- is.finite(new) & is.finite(old)
  if (!any(keep)) return(NA_real_)
  max(abs(new[keep] - old[keep]) / pmax(1e-8, abs(new[keep]), abs(old[keep]), 1))
}

.exal_static_ld_mix_step <- function(old, new, damping, step_cap) {
  old <- as.numeric(old)[1]
  new <- as.numeric(new)[1]
  delta <- new - old
  if (is.finite(step_cap)) {
    delta <- min(max(delta, -step_cap), step_cap)
  }
  old + damping * delta
}

.exal_static_ld_mix_numeric_lists <- function(old, new, damping) {
  out <- old
  nm <- union(names(old), names(new))
  for (k in nm) {
    x_old <- old[[k]]
    x_new <- new[[k]]
    if (is.numeric(x_old) && is.numeric(x_new) && length(x_old) == length(x_new)) {
      out[[k]] <- x_old + damping * (x_new - x_old)
    } else if (!is.null(x_new)) {
      out[[k]] <- x_new
    }
  }
  out
}

.exal_static_ld_cycle_metrics <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 4L || length(unique(x)) < 2L) {
    return(list(
      lag1 = NA_real_,
      lag2 = NA_real_,
      mean_abs_diff = if (n >= 2L) mean(abs(diff(x))) else NA_real_,
      range = if (n >= 1L) diff(range(x)) else NA_real_
    ))
  }
  list(
    lag1 = stats::cor(x[-1L], x[-n]),
    lag2 = stats::cor(x[-(1:2)], x[-((n - 1L):n)]),
    mean_abs_diff = mean(abs(diff(x))),
    range = diff(range(x))
  )
}

.exal_static_ld_cycle_detect <- function(ld_trace, s_trace, candidate, ld_ctrl) {
  if (!isTRUE(ld_ctrl$auto_stabilize)) {
    return(list(triggered = FALSE, reason = NA_character_, metrics = list(), flags = logical()))
  }
  window <- max(4L, suppressWarnings(as.integer(ld_ctrl$cycle_window)[1]))
  if (nrow(ld_trace) < max(2L, window - 1L) || nrow(s_trace) < max(2L, window - 1L)) {
    return(list(triggered = FALSE, reason = NA_character_, metrics = list(), flags = logical()))
  }

  tail_with_candidate <- function(df, col, value) {
    tail(c(df[[col]], value), window)
  }

  metrics <- list(
    gamma = .exal_static_ld_cycle_metrics(tail_with_candidate(ld_trace, "gamma", candidate$gamma)),
    sigma = .exal_static_ld_cycle_metrics(tail_with_candidate(ld_trace, "sigma", candidate$sigma)),
    s_mean = .exal_static_ld_cycle_metrics(tail_with_candidate(s_trace, "s_mean", candidate$s_mean)),
    tau2_mean = .exal_static_ld_cycle_metrics(tail_with_candidate(s_trace, "tau2_mean", candidate$tau2_mean))
  )

  trig <- function(m, amp_min) {
    is.finite(m$lag1) &&
      is.finite(m$lag2) &&
      is.finite(m$range) &&
      m$lag1 <= ld_ctrl$cycle_lag1_max &&
      m$lag2 >= ld_ctrl$cycle_lag2_min &&
      m$range >= amp_min
  }

  flags <- c(
    gamma = trig(metrics$gamma, ld_ctrl$cycle_gamma_min_amp),
    sigma = trig(metrics$sigma, ld_ctrl$cycle_sigma_min_amp),
    s_mean = trig(metrics$s_mean, ld_ctrl$cycle_s_min_amp),
    tau2_mean = trig(metrics$tau2_mean, ld_ctrl$cycle_tau2_min_amp)
  )

  triggered <- (isTRUE(flags[["gamma"]]) && isTRUE(flags[["sigma"]])) ||
    ((isTRUE(flags[["gamma"]]) || isTRUE(flags[["sigma"]])) &&
      isTRUE(flags[["s_mean"]]) && isTRUE(flags[["tau2_mean"]]))

  reason <- if (triggered) {
    paste0("cycle_detected:", paste(names(flags)[flags], collapse = "+"))
  } else {
    NA_character_
  }

  list(triggered = triggered, reason = reason, metrics = metrics, flags = flags)
}

.exal_static_ld_mode_quality <- function(log_q_fn, par, grad_tol = 5e-3, min_eig = 1e-8) {
  grad <- try(numDeriv::grad(log_q_fn, x = as.numeric(par)), silent = TRUE)
  grad <- if (inherits(grad, "try-error")) rep(NA_real_, length(par)) else as.numeric(grad)

  neg_hess <- try(-numDeriv::hessian(log_q_fn, x = as.numeric(par)), silent = TRUE)
  neg_hess <- if (inherits(neg_hess, "try-error")) {
    matrix(NA_real_, nrow = length(par), ncol = length(par))
  } else {
    hh <- as.matrix(neg_hess)
    (hh + t(hh)) / 2
  }

  eig <- try(eigen(neg_hess, symmetric = TRUE, only.values = TRUE)$values, silent = TRUE)
  eig <- if (inherits(eig, "try-error")) rep(NA_real_, length(par)) else as.numeric(eig)

  grad_inf_norm <- if (all(is.finite(grad))) max(abs(grad)) else NA_real_
  neg_hess_min_eig <- if (any(is.finite(eig))) min(eig, na.rm = TRUE) else NA_real_
  neg_hess_max_eig <- if (any(is.finite(eig))) max(eig, na.rm = TRUE) else NA_real_
  neg_hess_condition <- if (is.finite(neg_hess_min_eig) && is.finite(neg_hess_max_eig) && neg_hess_min_eig > 0) {
    neg_hess_max_eig / neg_hess_min_eig
  } else {
    NA_real_
  }

  list(
    gradient = grad,
    grad_inf_norm = grad_inf_norm,
    neg_hess = neg_hess,
    neg_hess_min_eig = neg_hess_min_eig,
    neg_hess_max_eig = neg_hess_max_eig,
    neg_hess_condition = neg_hess_condition,
    local_mode_pass = is.finite(grad_inf_norm) &&
      grad_inf_norm <= grad_tol &&
      is.finite(neg_hess_min_eig) &&
      neg_hess_min_eig > min_eig
  )
}

.exal_static_ld_committed_stability <- function(ld_trace_df, conv_ctrl, tail_n = 50L) {
  if (!is.data.frame(ld_trace_df) || !nrow(ld_trace_df)) {
    return(list(
      tail_n = 0L,
      cycle_rate = NA_real_,
      objective_gap_median = NA_real_,
      xi_drift_median = NA_real_,
      delta_state_median = NA_real_,
      delta_sigma_median = NA_real_,
      delta_gamma_median = NA_real_,
      candidate_local_pass_rate = NA_real_,
      committed_stable = FALSE
    ))
  }
  metric_vec <- function(df, col) {
    if (!col %in% names(df)) {
      return(rep(NA_real_, nrow(df)))
    }
    vals <- df[[col]]
    if (is.null(vals)) {
      return(rep(NA_real_, nrow(df)))
    }
    if (is.logical(vals)) {
      return(as.numeric(vals))
    }
    if (is.factor(vals)) {
      vals <- as.character(vals)
    }
    suppressWarnings(as.numeric(vals))
  }
  tail_n <- max(1L, min(as.integer(tail_n)[1], nrow(ld_trace_df)))
  tail_df <- utils::tail(ld_trace_df, tail_n)
  cycle_vals <- metric_vec(tail_df, "ld_cycle_detected")
  gap_vals <- metric_vec(tail_df, "ld_objective_gap")
  xi_vals <- metric_vec(tail_df, "xi_rel_drift")
  state_vals <- metric_vec(tail_df, "delta_state")
  sigma_vals <- metric_vec(tail_df, "delta_sigma")
  gamma_vals <- metric_vec(tail_df, "delta_gamma")
  local_pass_vals <- metric_vec(tail_df, "ld_mode_local_pass_candidate")
  out <- list(
    tail_n = tail_n,
    cycle_rate = mean(as.logical(cycle_vals), na.rm = TRUE),
    objective_gap_median = stats::median(abs(gap_vals), na.rm = TRUE),
    xi_drift_median = stats::median(abs(xi_vals), na.rm = TRUE),
    delta_state_median = stats::median(abs(state_vals), na.rm = TRUE),
    delta_sigma_median = stats::median(abs(sigma_vals), na.rm = TRUE),
    delta_gamma_median = stats::median(abs(gamma_vals), na.rm = TRUE),
    candidate_local_pass_rate = mean(as.logical(local_pass_vals), na.rm = TRUE)
  )
  out$committed_stable <- isTRUE(out$candidate_local_pass_rate >= 0.80) &&
    isTRUE(out$cycle_rate <= 0.05) &&
    isTRUE(out$objective_gap_median <= 1e-3) &&
    isTRUE(out$delta_state_median <= conv_ctrl$tol_state) &&
    isTRUE(out$delta_sigma_median <= conv_ctrl$tol_sigma) &&
    isTRUE(out$delta_gamma_median <= conv_ctrl$tol_gamma)
  out
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
#' @param beta_prior Coefficient prior type: \code{"ridge"} (default) or
#'   \code{"rhs"} for the regularized horseshoe.
#' @param beta_prior_controls Optional list of prior-specific controls. For
#'   \code{beta_prior = "rhs"}, supported keys follow the qdesn implementation:
#'   \code{tau0}, \code{nu}, \code{s} or \code{s2}, \code{shrink_intercept},
#'   \code{intercept_prec}, \code{n_inner}, \code{eta_bounds},
#'   \code{freeze_tau_iters}, \code{freeze_tau_warmup_iters},
#'   \code{update_every}, \code{update_every_warmup},
#'   \code{update_every_warmup_iters}, \code{force_tau_after_warmup},
#'   \code{collapse_tau_ratio_tol}, \code{collapse_beta_max_abs_tol},
#'   \code{warn_on_collapse}, \code{var_floor}, \code{h_curv},
#'   \code{verbose}, \code{init_lambda}, \code{init_log_lambda},
#'   \code{init_tau}, \code{init_log_tau}, \code{init_c2},
#'   and \code{init_log_c2}. When \code{beta_prior = "rhs"},
#'   \code{b0} and \code{V0} are retained only for backward-compatible ridge
#'   behavior and are ignored for the shrunk coefficients.
#' @param a_sigma,b_sigma Prior for \eqn{\sigma \sim IG(a_\sigma,b_\sigma)} with
#'   density \eqn{p(\sigma)\propto \sigma^{-(a_\sigma+1)} e^{-b_\sigma/\sigma}}.
#' @param gamma_bounds Two-vector (L, U) support for \code{gamma}.
#'   Defaults to \code{c(L.fn(p0), U.fn(p0))}.
#' @param log_prior_gamma Function \code{g -> log pi(gamma=g)}. Default is a
#'   truncated Student-t prior centered at 0 on the admissible \code{gamma}
#'   support.
#' @param init Optional list with starting values: \code{beta}, \code{sigma},
#'   \code{gamma}; if missing, reasonable defaults are used.
#' @param dqlm.ind Logical; if \code{TRUE}, fit the reduced AL model (DQLM, \code{gamma=0})
#'   using conjugate CAVI updates for \code{q(beta)}, \code{q(v)} and \code{q(sigma)}.
#' @param n_samp_xi Integer; number of Gaussian draws used only when
#'   \code{ld_controls$xi_method = "mc"} for the \eqn{\xi} expectations in
#'   \eqn{q(\sigma,\gamma)} (default 200).
#' @param ld_controls Optional list of controls for the Laplace-Delta block.
#'   Supported keys include \code{xi_method} (\code{"delta"} or \code{"mc"}),
#'   \code{optimizer_method} (\code{"lbfgsb"} or \code{"bfgs"}),
#'   \code{direct_commit}, \code{damping}, \code{xi_damping},
#'   \code{xi_mode}, \code{xi_replicates}, \code{reuse_draws},
#'   \code{antithetic}, \code{optimizer_maxit}, \code{eig_floor},
#'   \code{eig_cap}, \code{step_cap_eta}, \code{step_cap_ell},
#'   \code{eta_lo}, \code{eta_hi}, \code{sigma_bounds},
#'   \code{sigma_init_mode}, \code{sigma_floor_abs}, \code{sigma_min_mult},
#'   \code{sigma_max_mult}, \code{sigma_bound_ratio_min},
#'   \code{gamma_init_pad_frac}, \code{logit_eps}, \code{init_cov_diag},
#'   \code{reuse_seed}, \code{mode_grad_tol}, \code{mode_min_eig},
#'   \code{auto_stabilize}, \code{cycle_window}, \code{cycle_lag1_max},
#'   \code{cycle_lag2_min}, \code{cycle_gamma_min_amp},
#'   \code{cycle_sigma_min_amp}, \code{cycle_s_min_amp},
#'   \code{cycle_tau2_min_amp}, \code{stabilize_damping},
#'   \code{stabilize_xi_damping}, \code{stabilize_step_cap_eta},
#'   \code{stabilize_step_cap_ell}, and \code{store_trace}.
#' @param verbose Logical; print progress.
#'
#' @return A object of class "\code{exal_ldvb}" containing:
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
#'   \item \code{beta_prior}: prior metadata and, for RHS, posterior summaries of
#'         the shrinkage hyperparameters, including warmup/freeze-aware
#'         \code{tau} summaries and collapse diagnostics
#'         (\code{collapse_flag}, \code{tau_near_zero}, \code{beta_collapse},
#'         and \code{warning} when triggered).
#'   \item \code{diagnostics}: ELBO and joint-convergence diagnostics
#'         (state/sigma/gamma/ELBO deltas, stopping reason, and
#'         Laplace-Delta block trace diagnostics, including replicated-\code{xi}
#'         controls, automatic stabilization / cycle-detection fields, and
#'         final local-mode quality checks).
#' }
#'
#' @details
#' Mean-field factorization:
#' \deqn{q(\beta)\ \prod_{i=1}^n q(v_i)\ q(s_i)\ q(\sigma,\gamma).}
#' The LD block is parameterized in transformed coordinates
#' \eqn{\eta=\mathrm{logit}((\gamma-L)/(U-L))} and \eqn{\ell=\log\sigma}.
#' The \code{xi} expectations used in CAVI updates can be computed either from a
#' deterministic second-order Delta approximation in \eqn{(\eta,\ell)} or from a
#' Gaussian Monte Carlo sample. The Laplace-Delta controls also allow bounded
#' optimization in the transformed \eqn{(\eta,\ell)} block to better mimic the
#' stabilized qdesn readout implementation. When \code{beta_prior = "rhs"}, the
#' prior block uses qdesn-style \code{tau} warmup/freeze scheduling to avoid the
#' early-collapse regime where global shrinkage drives all slope coefficients
#' toward zero before the likelihood-side variational factors stabilize.
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
  beta_prior = c("ridge", "rhs"),
  beta_prior_controls = NULL,
  a_sigma = 1, b_sigma = 1,
  gamma_bounds = c(L.fn(p0), U.fn(p0)),
  log_prior_gamma = NULL,
  init = NULL,
  dqlm.ind = FALSE,
  n_samp_xi = 200,
  ld_controls = NULL,
  verbose = TRUE
){
  # --- checks ---------------------------------------------------------------
  y <- as.numeric(y)
  X <- as.matrix(X); storage.mode(X) <- "double"
  n <- length(y); p <- ncol(X)
  if (nrow(X) != n) stop("nrow(X) must match length(y).")
  if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")

  b0_missing <- is.null(b0)
  V0_missing <- is.null(V0)
  if (is.null(b0)) b0 <- rep(0, p)
  if (is.null(V0)) V0 <- diag(1e6, p)
  V0 <- as.matrix(V0)
  if (!all(dim(V0) == c(p, p))) stop("V0 must be p x p.")
  beta_prior_obj <- .static_beta_prior_make(
    beta_prior = beta_prior,
    p = p,
    b0 = b0,
    V0 = V0,
    beta_prior_controls = beta_prior_controls,
    warn_rhs_b0 = !b0_missing,
    warn_rhs_V0 = !V0_missing
  )

  # Reduced AL / DQLM branch: no gamma, no s, no LD block.
  if (isTRUE(dqlm.ind)) {
    ret <- .run_static_dqlm_cavi(
      y = y,
      X = X,
      p0 = p0,
      max_iter = max_iter,
      tol = tol,
      b0 = b0,
      V0 = V0,
      beta_prior_obj = beta_prior_obj,
      a_sigma = a_sigma,
      b_sigma = b_sigma,
      init = init,
      verbose = verbose
    )
    class(ret) <- "exal_vb"
    return(ret)
  }

  L <- gamma_bounds[1]; U <- gamma_bounds[2]
  if (!(L < U)) stop("gamma_bounds must satisfy L < U.")
  if (is.null(log_prior_gamma)) {
    log_prior_gamma <- function(g) .gamma_log_prior_trunc_t(g, bounds = c(L, U))
  }

  # --- A,B,C,lambda helpers -------------------------------------------------
  A_of   <- function(g) A.fn(p0, g)
  B_of   <- function(g) B.fn(p0, g)
  C_of   <- function(g) C.fn(p0, g)
  lam_of <- function(g) C_of(g) * abs(g)

  # transform (eta,ell) <-> (gamma,sigma)
  g_from_eta <- function(eta) {
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    L + (U - L) * s
  }
  sig_from_ell <- function(ell) exp(ell)

  ld_ctrl <- .exal_static_ld_controls(ld_controls)
  ld_setup <- .exal_static_ld_scale_setup(y = y, L = L, U = U, init = init, ld_ctrl = ld_ctrl)

  # --- initialize variational parameters ------------------------------------
  m_beta  <- if (is.null(init$beta)) rep(0, p) else as.numeric(init$beta)
  V_beta  <- V0
  sigma0  <- ld_setup$sigma0
  gamma0  <- ld_setup$gamma0
  beta_state <- beta_prior_obj$init_vb()

  # q(v): initialize moments (use 1 for both)
  E_inv_v <- rep(1, n)
  E_v     <- rep(1, n)

  # q(s): initialize moments (half-normal)
  qs_mu   <- rep(0, n)
  qs_tau2 <- rep(1, n)
  E_s     <- sqrt(2/pi) * rep(1, n)  # E[N^+(0,1)]
  E_s2    <- rep(1, n)               # Var + mean^2 = 1 + 2/pi (but ok to start at 1)

  # q(sigma,gamma): initialize in transformed coordinates
  eta_hat <- ld_setup$eta0
  ell_hat <- ld_setup$ell0
  Sig_eta_ell <- diag(ld_ctrl$init_cov_diag, 2L)
  ld_base_draws <- if (ld_ctrl$reuse_draws) {
    .exal_static_ld_make_base_draws_list(
      ns = max(50L, as.integer(n_samp_xi)),
      replicates = ld_ctrl$xi_replicates,
      antithetic = ld_ctrl$antithetic,
      seed = ld_ctrl$reuse_seed
    )
  } else {
    NULL
  }

  # --- numerics helpers ------------------------------------------------------
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
    moms <- .exdqlm_pos_truncnorm_moments(mu, tau2)
    list(Es = moms$mean, Es2 = moms$second, sd = moms$sd)
  }

  trans_par <- function(z) {
    eta <- as.numeric(z[1])
    ell <- as.numeric(z[2])
    gamma <- g_from_eta(eta)
    sigma <- sig_from_ell(ell)
    A <- A_of(gamma)
    B <- pmax(B_of(gamma), 1e-12)
    lam <- lam_of(gamma)
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    log_hprime <- log(s) + log1p(-s)

    list(
      eta = eta,
      ell = ell,
      gamma = gamma,
      sigma = sigma,
      A = A,
      B = B,
      lam = lam,
      log_hprime = log_hprime
    )
  }

  # compute xi's from Gaussian approx in (eta,ell)
  compute_xi_mc_single <- function(eta_hat, ell_hat, Sigma, ns = n_samp_xi, base_Z = NULL) {
    ns <- max(1L, as.integer(ns))

    # draw (eta, ell) ~ N([eta_hat, ell_hat], Sigma)
    chol_U <- tryCatch(chol(Sigma), error = function(e) NULL)
    if (is.null(chol_U)) chol_U <- chol(Sigma + 1e-8 * diag(2))

    if (!is.null(base_Z)) {
      if (nrow(base_Z) != 2L) stop("base_Z must be a 2 x ns matrix.")
      if (ncol(base_Z) < ns) stop("base_Z does not contain enough draws.")
      Z <- base_Z[, seq_len(ns), drop = FALSE]
    } else {
      Z <- matrix(stats::rnorm(2 * ns), nrow = 2, ncol = ns)   # 2 x ns
    }
    pars <- sweep(chol_U %*% Z, 1, c(eta_hat, ell_hat), "+")  # 2 x ns
    eta  <- pars[1, ]
    ell  <- pars[2, ]

    gamma <- g_from_eta(eta)
    sigma <- sig_from_ell(ell)

    A   <- A_of(gamma)
    B   <- pmax(B_of(gamma), 1e-12)
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

  compute_xi_mc <- function(eta_hat, ell_hat, Sigma, ns = n_samp_xi, base_Z = NULL) {
    rep_count <- if (identical(ld_ctrl$xi_mode, "replicated")) {
      ld_ctrl$xi_replicates
    } else {
      1L
    }
    if (is.null(base_Z)) {
      base_list <- vector("list", rep_count)
    } else if (is.list(base_Z)) {
      base_list <- base_Z
    } else {
      base_list <- replicate(rep_count, base_Z, simplify = FALSE)
    }
    vals <- lapply(seq_len(rep_count), function(i) {
      compute_xi_mc_single(
        eta_hat = eta_hat,
        ell_hat = ell_hat,
        Sigma = Sigma,
        ns = ns,
        base_Z = if (length(base_list) >= i) base_list[[i]] else NULL
      )
    })
    val_mat <- do.call(rbind, lapply(vals, .exal_static_ld_named_numeric))
    center <- colMeans(val_mat)
    mcse <- if (nrow(val_mat) >= 2L) {
      matrixStats::colSds(val_mat) / sqrt(nrow(val_mat))
    } else {
      rep(NA_real_, ncol(val_mat))
    }
    names(mcse) <- colnames(val_mat)
    list(
      value = as.list(center),
      mcse = as.list(mcse),
      replicate_count = nrow(val_mat),
      mcse_mean = if (all(is.na(mcse))) NA_real_ else mean(mcse, na.rm = TRUE),
      mcse_max = if (all(is.na(mcse))) NA_real_ else max(mcse, na.rm = TRUE)
    )
  }

  compute_xi_delta <- function(eta_hat, ell_hat, Sigma) {
    z0 <- c(eta_hat, ell_hat)

    g_vec <- function(z) {
      p <- trans_par(z)
      c(
        xi1 = 1 / (p$B * p$sigma),
        xi_lambda = p$lam / p$B,
        xi_lambda2 = (p$lam^2) * p$sigma / p$B,
        xi_A = p$A / (p$B * p$sigma),
        xi_A2 = (p$A^2) / (p$B * p$sigma),
        zeta_lam = (p$lam * p$A) / p$B,
        zeta_logB = log(pmax(p$B, 1e-300)),
        zeta_logpi = log_prior_gamma(p$gamma),
        zeta_loghprime = p$log_hprime
      )
    }

    h1s <- 1e-3 * sqrt(pmax(Sigma[1, 1], 1e-8))
    h2s <- 1e-3 * sqrt(pmax(Sigma[2, 2], 1e-8))
    h1 <- max(1e-4 * (1 + abs(eta_hat)), h1s)
    h2 <- max(1e-4 * (1 + abs(ell_hat)), h2s)
    h1 <- min(max(h1, 1e-6), 1e-2)
    h2 <- min(max(h2, 1e-6), 1e-2)

    f00 <- g_vec(z0)
    f10 <- g_vec(z0 + c(h1, 0))
    f_10 <- g_vec(z0 + c(-h1, 0))
    f01 <- g_vec(z0 + c(0, h2))
    f0_1 <- g_vec(z0 + c(0, -h2))
    f11 <- g_vec(z0 + c(h1, h2))
    f1_1 <- g_vec(z0 + c(h1, -h2))
    f_11 <- g_vec(z0 + c(-h1, h2))
    f_1_1 <- g_vec(z0 + c(-h1, -h2))

    H11 <- (f10 - 2 * f00 + f_10) / (h1^2)
    H22 <- (f01 - 2 * f00 + f0_1) / (h2^2)
    H12 <- (f11 - f1_1 - f_11 + f_1_1) / (4 * h1 * h2)

    corr <- 0.5 * (H11 * Sigma[1, 1] + 2 * H12 * Sigma[1, 2] + H22 * Sigma[2, 2])
    out <- f00 + corr
    out <- c(
      out,
      xi_siginv = exp(-ell_hat + 0.5 * Sigma[2, 2]),
      zeta_logsigma = ell_hat
    )

    out_named <- as.list(out)
    out_named$zeta_logJ <- log(pmax(U - L, 1e-12)) + as.numeric(out_named$zeta_loghprime) + ell_hat
    out_named$zeta_loghprime <- NULL
    out_named
  }

  compute_xi <- function(eta_hat, ell_hat, Sigma, ns = n_samp_xi, base_Z = NULL, method = ld_ctrl$xi_method) {
    method <- match.arg(as.character(method)[1], c("delta", "mc"))
    if (identical(method, "delta")) {
      xi_val <- compute_xi_delta(eta_hat = eta_hat, ell_hat = ell_hat, Sigma = Sigma)
      return(list(
        value = xi_val,
        mcse = as.list(stats::setNames(rep(NA_real_, length(xi_val)), names(xi_val))),
        replicate_count = 0L,
        mcse_mean = NA_real_,
        mcse_max = NA_real_
      ))
    }
    compute_xi_mc(eta_hat = eta_hat, ell_hat = ell_hat, Sigma = Sigma, ns = ns, base_Z = base_Z)
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
    par0 <- c(eta0, ell0)
    par0[1] <- min(max(par0[1], ld_ctrl$eta_lo), ld_ctrl$eta_hi)
    par0[2] <- min(max(par0[2], ld_setup$ell_lo), ld_setup$ell_hi)
    par_start <- par0
    used_optim_fallback <- FALSE
    used_numeric_hessian <- FALSE
    used_identity_hessian <- FALSE

    opt <- if (identical(ld_ctrl$optimizer_method, "lbfgsb")) {
      try(
        optim(
          par = par_start,
          fn = fn_neg,
          method = "L-BFGS-B",
          lower = c(ld_ctrl$eta_lo, ld_setup$ell_lo),
          upper = c(ld_ctrl$eta_hi, ld_setup$ell_hi),
          control = list(maxit = ld_ctrl$optimizer_maxit)
        ),
        silent = TRUE
      )
    } else {
      cand <- rbind(
        par0,
        par0 + c(-1, 0), par0 + c(1, 0), par0 + c(0, -1), par0 + c(0, 1),
        par0 + c(-2, 0), par0 + c(2, 0), par0 + c(0, -2), par0 + c(0, 2)
      )
      vals <- apply(cand, 1, function(z) log_qsiggam(z))
      idx <- which(is.finite(vals))
      par_start <- if (length(idx)) cand[idx[which.max(vals[idx])], ] else par0
      try(
        optim(
          par = par_start,
          fn = fn_neg,
          method = "BFGS",
          control = list(maxit = ld_ctrl$optimizer_maxit),
          hessian = TRUE
        ),
        silent = TRUE
      )
    }
    if (inherits(opt, "try-error") || !is.finite(opt$value)) {
      used_optim_fallback <- TRUE
      opt <- list(par = as.numeric(par_start), value = fn_neg(par_start), hessian = diag(2) * 1e-2, convergence = 1L)
    }
    H <- opt$hessian
    if (is.null(H)) {
      H <- matrix(NA_real_, nrow = 2L, ncol = 2L)
    } else {
      H <- suppressWarnings(as.matrix(H))
      if (!all(dim(H) == c(2L, 2L))) {
        H <- matrix(NA_real_, nrow = 2L, ncol = 2L)
      }
    }
    if (!all(is.finite(H)) || any(is.nan(H))) {
      # numeric Hessian as fallback
      H_num <- try(numDeriv::hessian(function(z) -log_qsiggam(z), x = opt$par), silent = TRUE)
      if (inherits(H_num, "try-error") || any(!is.finite(H_num))) {
        used_identity_hessian <- TRUE
        H <- diag(2) * 1e-2
      } else {
        used_numeric_hessian <- TRUE
        H <- H_num
      }
    }
    H <- (H + t(H)) / 2
    reg <- .exal_static_ld_cov_from_precision(
      H,
      eig_floor = ld_ctrl$eig_floor,
      eig_cap = ld_ctrl$eig_cap
    )
    list(
      eta_hat = as.numeric(opt$par[1]),
      ell_hat = as.numeric(opt$par[2]),
      Sigma = reg$Sigma,
      objective = as.numeric(log_qsiggam(opt$par)),
      optim_convergence = if (!is.null(opt$convergence)) as.integer(opt$convergence)[1] else NA_integer_,
      optimizer_method = ld_ctrl$optimizer_method,
      used_optim_fallback = used_optim_fallback,
      used_numeric_hessian = used_numeric_hessian,
      used_identity_hessian = used_identity_hessian,
      used_cov_floor = isTRUE(reg$used_floor),
      used_fallback = used_optim_fallback || used_numeric_hessian || used_identity_hessian || isTRUE(reg$used_floor),
      hess_condition = reg$condition_raw,
      cov_condition = reg$condition_reg,
      cov_eig_min = min(reg$cov_eig_reg),
      cov_eig_max = max(reg$cov_eig_reg),
      cov_eig_raw_min = if (length(reg$cov_eig_raw)) min(reg$cov_eig_raw, na.rm = TRUE) else NA_real_,
      cov_eig_raw_max = if (length(reg$cov_eig_raw)) max(reg$cov_eig_raw, na.rm = TRUE) else NA_real_
    )
  }

  # --- main loop -------------------------------------------------------------
  t0 <- proc.time()[3]
  if (verbose) {
    cat(sprintf("Static exAL LDVB | n=%d, p=%d | max_iter=%d, tol=%.1e\n",
                n, p, max_iter, tol))
  }

  # initial xi from a tiny covariance (deterministic when base draws are reused)
  xis_eval <- compute_xi(
    eta_hat,
    ell_hat,
    Sig_eta_ell,
    ns = max(50L, floor(n_samp_xi / 2)),
    base_Z = ld_base_draws
  )
  xis <- xis_eval$value
  elbo_trace <- numeric(0)
  elbo_old   <- -Inf
  delta_beta <- numeric(0)
  delta_sigma <- numeric(0)
  delta_gamma <- numeric(0)
  delta_s <- numeric(0)
  delta_elbo <- numeric(0)
  ld_trace_rows <- vector("list", max_iter)
  s_trace_rows <- vector("list", max_iter)
  gamma_hist <- numeric(0)
  sigma_hist <- numeric(0)
  s_mean_hist <- numeric(0)
  tau2_mean_hist <- numeric(0)
  stabilize_active <- FALSE
  stabilize_since_iter <- NA_integer_
  stabilize_reason_active <- NA_character_
  stabilize_xi_method_active <- ld_ctrl$xi_method
  stable_count <- 0L
  conv_ctrl <- .vb_joint_controls(tol_state = tol, has_gamma = TRUE)
  stop_reason <- "max_iter"
  converged <- FALSE
  for (iter in 1:max_iter) {
    prev_m_beta <- m_beta
    gamma_prev <- g_from_eta(eta_hat)
    sigma_prev <- exp(ell_hat)

    # ---- (1) q(beta) = N(m,V)
    # V = (V0^{-1} + xi1 * X^T diag(E[1/v]) X)^{-1}
    W <- xis$xi1 * E_inv_v
    Xw <- X * sqrt(W)
    prior_sys <- beta_prior_obj$beta_system_vb(beta_state)
    V_inv <- crossprod(Xw) + prior_sys$Prec
    Uc <- tryCatch(chol(V_inv), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(V_inv + 1e-10 * diag(p))
    V_beta_new <- chol2inv(Uc)

    # m = V ( V0^{-1} b0 + X^T [ xi1 diag(E[1/v]) y - xi_lambda (E[1/v] * E[s]) - xi_A 1 ] )
    rhs <- crossprod(X, W * y) -
           crossprod(X, (xis$xi_lambda * (E_inv_v * E_s))) 

    # Careful: The xi_A * 1_n term multiplies X^T * 1_n
    rhs <- rhs + prior_sys$h - (xis$xi_A) * colSums(X)

    m_beta_new <- V_beta_new %*% rhs
    beta_state_new <- beta_prior_obj$update_vb(
      beta_state,
      list(m = as.numeric(m_beta_new), V = V_beta_new)
    )

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
    eta_prev <- eta_hat
    ell_prev <- ell_hat
    Sigma_prev <- Sig_eta_ell
    ld <- find_mode_ld(eta_hat, ell_hat)
    candidate <- list(
      gamma = g_from_eta(ld$eta_hat),
      sigma = exp(ld$ell_hat),
      s_mean = mean(s_mom$Es),
      tau2_mean = mean(tau2)
    )
    ld_hist_df <- if (length(gamma_hist)) {
      data.frame(gamma = gamma_hist, sigma = sigma_hist)
    } else {
      data.frame(gamma = numeric(0), sigma = numeric(0))
    }
    s_hist_df <- if (length(s_mean_hist)) {
      data.frame(s_mean = s_mean_hist, tau2_mean = tau2_mean_hist)
    } else {
      data.frame(s_mean = numeric(0), tau2_mean = numeric(0))
    }
    cycle_info <- .exal_static_ld_cycle_detect(ld_hist_df, s_hist_df, candidate, ld_ctrl)
    ld_cycle_detected <- isTRUE(cycle_info$triggered)
    ld_stabilized <- FALSE
    ld_stabilize_reason <- NA_character_
    ld_candidate_mode_quality_iter <- if (isTRUE(ld_ctrl$auto_stabilize) || isTRUE(ld_ctrl$reject_bad_mode_commit)) {
      .exal_static_ld_mode_quality(
        log_q_fn = log_qsiggam,
        par = c(ld$eta_hat, ld$ell_hat),
        grad_tol = ld_ctrl$mode_grad_tol,
        min_eig = ld_ctrl$mode_min_eig
      )
    } else {
      NULL
    }
    ld_bad_mode_iter <- !is.null(ld_candidate_mode_quality_iter) && !isTRUE(ld_candidate_mode_quality_iter$local_mode_pass)
    if (isTRUE(ld_ctrl$auto_stabilize)) {
      if (isTRUE(ld_ctrl$direct_commit) &&
          (!isTRUE(stabilize_active)) &&
          (isTRUE(ld_cycle_detected) ||
            isTRUE(ld$used_fallback) ||
            (!is.na(ld$optim_convergence) && ld$optim_convergence != 0L) ||
            isTRUE(ld_bad_mode_iter))) {
        stabilize_active <- TRUE
        stabilize_since_iter <- iter
        stabilize_reason_active <- if (isTRUE(ld_cycle_detected)) {
          cycle_info$reason
        } else if (isTRUE(ld$used_fallback)) {
          "ld_used_fallback"
        } else if (isTRUE(ld_bad_mode_iter)) {
          "ld_bad_mode"
        } else {
          sprintf("ld_optim_convergence_%s", ld$optim_convergence)
        }
        stabilize_xi_method_active <- ld_ctrl$stabilize_xi_method
      }
      if (isTRUE(stabilize_active)) {
        ld_stabilized <- TRUE
        ld_stabilize_reason <- stabilize_reason_active
      }
    }
    xi_damping_use <- if (isTRUE(ld_stabilized)) ld_ctrl$stabilize_xi_damping else ld_ctrl$xi_damping
    active_xi_method <- if (isTRUE(ld_stabilized)) stabilize_xi_method_active else ld_ctrl$xi_method
    use_direct_commit <- isTRUE(ld_ctrl$direct_commit) && !isTRUE(ld_stabilized) &&
      !(isTRUE(ld_ctrl$reject_bad_mode_commit) && isTRUE(ld_bad_mode_iter))
    ld_commit_mode <- if (use_direct_commit) "direct" else "damped"
    if (use_direct_commit) {
      eta_hat <- as.numeric(ld$eta_hat)
      ell_hat <- as.numeric(ld$ell_hat)
      Sig_eta_ell <- .exal_static_ld_regularize_cov(
        ld$Sigma,
        eig_floor = ld_ctrl$eig_floor,
        eig_cap = ld_ctrl$eig_cap
      )$Sigma
    } else {
      damping_use <- if (isTRUE(ld_stabilized)) ld_ctrl$stabilize_damping else ld_ctrl$damping
      step_cap_eta_use <- if (isTRUE(ld_stabilized)) min(ld_ctrl$step_cap_eta, ld_ctrl$stabilize_step_cap_eta) else ld_ctrl$step_cap_eta
      step_cap_ell_use <- if (isTRUE(ld_stabilized)) min(ld_ctrl$step_cap_ell, ld_ctrl$stabilize_step_cap_ell) else ld_ctrl$step_cap_ell
      eta_hat <- .exal_static_ld_mix_step(
        old = eta_prev,
        new = ld$eta_hat,
        damping = damping_use,
        step_cap = step_cap_eta_use
      )
      ell_hat <- .exal_static_ld_mix_step(
        old = ell_prev,
        new = ld$ell_hat,
        damping = damping_use,
        step_cap = step_cap_ell_use
      )
      Sigma_mix <- (1 - damping_use) * Sigma_prev + damping_use * ld$Sigma
      Sig_eta_ell <- .exal_static_ld_regularize_cov(
        Sigma_mix,
        eig_floor = ld_ctrl$eig_floor,
        eig_cap = ld_ctrl$eig_cap
      )$Sigma
    }
    ld_committed_objective <- as.numeric(log_qsiggam(c(eta_hat, ell_hat)))
    ld_committed_mode_quality_iter <- if (use_direct_commit && !isTRUE(ld_stabilized) &&
      is.null(ld_candidate_mode_quality_iter)) {
      NULL
    } else if (use_direct_commit && !isTRUE(ld_stabilized)) {
      ld_candidate_mode_quality_iter
    } else {
      .exal_static_ld_mode_quality(
        log_q_fn = log_qsiggam,
        par = c(eta_hat, ell_hat),
        grad_tol = ld_ctrl$mode_grad_tol,
        min_eig = ld_ctrl$mode_min_eig
      )
    }

    # update xi via MC under Gaussian (eta,ell)
    xi_base_draws_use <- if (identical(active_xi_method, "mc")) ld_base_draws else NULL
    xis_eval_raw <- compute_xi(
      eta_hat,
      ell_hat,
      Sig_eta_ell,
      ns = n_samp_xi,
      base_Z = xi_base_draws_use,
      method = active_xi_method
    )
    xis_raw <- xis_eval_raw$value
    xis_new <- .exal_static_ld_mix_numeric_lists(xis, xis_raw, damping = xi_damping_use)

    # ---- check convergence
    rel_mb <- sqrt(sum((m_beta_new - m_beta)^2)) / (1e-8 + sqrt(sum(m_beta^2)))
    rel_xi <- .exal_static_ld_rel_change(
      .exal_static_ld_named_numeric(xis_raw),
      .exal_static_ld_named_numeric(xis)
    )
    eta_step_raw <- as.numeric(ld$eta_hat - eta_prev)
    ell_step_raw <- as.numeric(ld$ell_hat - ell_prev)
    eta_step_used <- as.numeric(eta_hat - eta_prev)
    ell_step_used <- as.numeric(ell_hat - ell_prev)

    if (verbose && (iter %% 50 == 0)) {
      ghat <- g_from_eta(eta_hat); shat <- exp(ell_hat)
      cat(sprintf(
        "iter %4d | rel(mb)=%.2e rel(xi)=%.2e | gamma~%.3f sigma~%.3f | ld(raw)=%.2e/%.2e used=%.2e/%.2e | stabilize=%s xi=%s bad_mode=%s\n",
        iter, rel_mb, rel_xi, ghat, shat, eta_step_raw, ell_step_raw, eta_step_used, ell_step_used,
        ifelse(ld_stabilized, ld_stabilize_reason, "none"),
        active_xi_method,
        ifelse(ld_bad_mode_iter, "yes", "no")
      ))
    }

    # commit new values
    m_beta <- as.numeric(m_beta_new); V_beta <- V_beta_new
    beta_state <- beta_state_new
    E_v    <- as.numeric(E_v_new);    E_inv_v <- as.numeric(E_inv_v_new)
    qs_mu  <- as.numeric(mu_s);       qs_tau2 <- as.numeric(tau2)
    E_s    <- as.numeric(s_mom$Es);   E_s2    <- as.numeric(s_mom$Es2)
    xis    <- xis_new
    gamma_hist <- c(gamma_hist, gamma_cur <- g_from_eta(eta_hat))
    sigma_hist <- c(sigma_hist, sigma_cur <- exp(ell_hat))
    s_mean_hist <- c(s_mean_hist, mean(E_s))
    tau2_mean_hist <- c(tau2_mean_hist, mean(qs_tau2))

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

    # (6) E[log p(beta)] : prior contribution (ridge or RHS)
    E_log_pb <- beta_prior_obj$elbo_vb(
      beta_state,
      list(m = m_beta, V = V_beta)
    )

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

    d_beta <- max(abs(m_beta_new - prev_m_beta))
    d_sigma <- abs(sigma_cur - sigma_prev)
    d_gamma <- abs(gamma_cur - gamma_prev)
    d_s <- .exal_static_ld_rel_change(s_mom$Es, E_s)
    d_elbo <- if (iter >= 2L) elbo_new - elbo_old else NA_real_
    use_elbo_gate <- !(isTRUE(ld_stabilized) && identical(active_xi_method, "mc"))
    step <- .vb_joint_step(
      iter = iter,
      d_state = d_beta,
      d_sigma = d_sigma,
      d_gamma = d_gamma,
      d_elbo = d_elbo,
      controls = conv_ctrl,
      compute_elbo = use_elbo_gate,
      stable_count = stable_count
    )
    stable_count <- step$stable_count
    delta_beta <- c(delta_beta, d_beta)
    delta_sigma <- c(delta_sigma, d_sigma)
    delta_gamma <- c(delta_gamma, d_gamma)
    delta_s <- c(delta_s, d_s)
    delta_elbo <- c(delta_elbo, d_elbo)
    if (isTRUE(ld_ctrl$store_trace)) {
      s_stats <- .exdqlm_trace_summary(s_mom$Es)
      tau2_stats <- .exdqlm_trace_summary(tau2)
      cycle_gamma_lag1 <- if (!is.null(cycle_info$metrics$gamma$lag1)) cycle_info$metrics$gamma$lag1 else NA_real_
      cycle_gamma_lag2 <- if (!is.null(cycle_info$metrics$gamma$lag2)) cycle_info$metrics$gamma$lag2 else NA_real_
      cycle_sigma_lag1 <- if (!is.null(cycle_info$metrics$sigma$lag1)) cycle_info$metrics$sigma$lag1 else NA_real_
      cycle_sigma_lag2 <- if (!is.null(cycle_info$metrics$sigma$lag2)) cycle_info$metrics$sigma$lag2 else NA_real_
      cycle_s_lag1 <- if (!is.null(cycle_info$metrics$s_mean$lag1)) cycle_info$metrics$s_mean$lag1 else NA_real_
      cycle_s_lag2 <- if (!is.null(cycle_info$metrics$s_mean$lag2)) cycle_info$metrics$s_mean$lag2 else NA_real_
      cycle_tau2_lag1 <- if (!is.null(cycle_info$metrics$tau2_mean$lag1)) cycle_info$metrics$tau2_mean$lag1 else NA_real_
      cycle_tau2_lag2 <- if (!is.null(cycle_info$metrics$tau2_mean$lag2)) cycle_info$metrics$tau2_mean$lag2 else NA_real_
      ld_trace_rows[[iter]] <- data.frame(
        iter = iter,
        eta = eta_hat,
        ell = ell_hat,
        gamma = gamma_cur,
        sigma = sigma_cur,
        eta_raw = ld$eta_hat,
        ell_raw = ld$ell_hat,
        gamma_raw = candidate$gamma,
        sigma_raw = candidate$sigma,
        eta_step_raw = eta_step_raw,
        ell_step_raw = ell_step_raw,
        eta_step_used = eta_step_used,
        ell_step_used = ell_step_used,
        xi_rel_drift = rel_xi,
        xi_method = active_xi_method,
        xi_mcse_mean = as.numeric(xis_eval_raw$mcse_mean)[1],
        xi_mcse_max = as.numeric(xis_eval_raw$mcse_max)[1],
        xi_replicates = as.integer(xis_eval_raw$replicate_count)[1],
        ld_objective_candidate = ld$objective,
        ld_objective_committed = ld_committed_objective,
        ld_objective_gap = ld_committed_objective - ld$objective,
        ld_optim_convergence = ld$optim_convergence,
        ld_optimizer_method = ld$optimizer_method,
        ld_used_fallback = isTRUE(ld$used_fallback),
        ld_used_optim_fallback = isTRUE(ld$used_optim_fallback),
        ld_used_numeric_hessian = isTRUE(ld$used_numeric_hessian),
        ld_used_identity_hessian = isTRUE(ld$used_identity_hessian),
        ld_used_cov_floor = isTRUE(ld$used_cov_floor),
        ld_commit_mode = ld_commit_mode,
        ld_bad_mode = ld_bad_mode_iter,
        ld_mode_grad_inf_norm_candidate = if (!is.null(ld_candidate_mode_quality_iter)) ld_candidate_mode_quality_iter$grad_inf_norm else NA_real_,
        ld_mode_neg_hess_min_eig_candidate = if (!is.null(ld_candidate_mode_quality_iter)) ld_candidate_mode_quality_iter$neg_hess_min_eig else NA_real_,
        ld_mode_local_pass_candidate = if (!is.null(ld_candidate_mode_quality_iter)) isTRUE(ld_candidate_mode_quality_iter$local_mode_pass) else NA,
        ld_mode_grad_inf_norm_committed = if (!is.null(ld_committed_mode_quality_iter)) ld_committed_mode_quality_iter$grad_inf_norm else NA_real_,
        ld_mode_neg_hess_min_eig_committed = if (!is.null(ld_committed_mode_quality_iter)) ld_committed_mode_quality_iter$neg_hess_min_eig else NA_real_,
        ld_mode_local_pass_committed = if (!is.null(ld_committed_mode_quality_iter)) isTRUE(ld_committed_mode_quality_iter$local_mode_pass) else NA,
        ld_cycle_detected = ld_cycle_detected,
        ld_stabilized = ld_stabilized,
        ld_stabilize_reason = if (!is.na(ld_stabilize_reason)) ld_stabilize_reason else "",
        ld_stabilize_active = stabilize_active,
        ld_stabilize_since_iter = if (is.finite(stabilize_since_iter)) stabilize_since_iter else NA_integer_,
        ld_cycle_gamma_lag1 = cycle_gamma_lag1,
        ld_cycle_gamma_lag2 = cycle_gamma_lag2,
        ld_cycle_sigma_lag1 = cycle_sigma_lag1,
        ld_cycle_sigma_lag2 = cycle_sigma_lag2,
        ld_cycle_s_lag1 = cycle_s_lag1,
        ld_cycle_s_lag2 = cycle_s_lag2,
        ld_cycle_tau2_lag1 = cycle_tau2_lag1,
        ld_cycle_tau2_lag2 = cycle_tau2_lag2,
        ld_hess_condition = ld$hess_condition,
        ld_cov_condition = ld$cov_condition,
        ld_cov_eig_min = ld$cov_eig_min,
        ld_cov_eig_max = ld$cov_eig_max,
        delta_state = d_beta,
        delta_sigma = d_sigma,
        delta_gamma = d_gamma,
        delta_s = d_s,
        delta_elbo = d_elbo,
        s_mean = s_stats[["mean"]],
        s_sd = s_stats[["sd"]],
        s_q05 = s_stats[["q05"]],
        s_q50 = s_stats[["median"]],
        s_q95 = s_stats[["q95"]],
        s_min = s_stats[["min"]],
        s_max = s_stats[["max"]],
        stringsAsFactors = FALSE
      )
      s_trace_rows[[iter]] <- data.frame(
        iter = iter,
        phase = "vb",
        s_mean = s_stats[["mean"]],
        s_sd = s_stats[["sd"]],
        s_q05 = s_stats[["q05"]],
        s_q50 = s_stats[["median"]],
        s_q95 = s_stats[["q95"]],
        s_min = s_stats[["min"]],
        s_max = s_stats[["max"]],
        tau2_mean = tau2_stats[["mean"]],
        tau2_sd = tau2_stats[["sd"]],
        tau2_q05 = tau2_stats[["q05"]],
        tau2_q50 = tau2_stats[["median"]],
        tau2_q95 = tau2_stats[["q95"]],
        tau2_min = tau2_stats[["min"]],
        tau2_max = tau2_stats[["max"]],
        delta_s = d_s,
        ld_cycle_detected = ld_cycle_detected,
        ld_stabilized = ld_stabilized,
        ld_stabilize_reason = if (!is.na(ld_stabilize_reason)) ld_stabilize_reason else "",
        xi_method = active_xi_method,
        stringsAsFactors = FALSE
      )
    }

    if (verbose && (iter %% 50 == 0)) {
      cat(sprintf(
        "    ELBO=%.6f | d_beta=%.3e d_sigma=%.3e d_gamma=%.3e d_elbo=%.3e | cond=%.3e stable=%d/%d\n",
        elbo_new, d_beta, d_sigma, d_gamma, d_elbo, ld$cov_condition, stable_count, conv_ctrl$patience
      ))
    }

    if (step$stop_now) {
      converged <- TRUE
      stop_reason <- "joint_converged"
      break
    }

    elbo_old <- elbo_new

  }

  t1 <- proc.time()[3]

  # approximate means for gamma, sigma from LD mode
  gamma_mean <- g_from_eta(eta_hat)
  sigma_mean <- exp(ell_hat)
  mode_quality <- .exal_static_ld_mode_quality(
    log_q_fn = log_qsiggam,
    par = c(eta_hat, ell_hat),
    grad_tol = ld_ctrl$mode_grad_tol,
    min_eig = ld_ctrl$mode_min_eig
  )
  ld_trace_df <- if (isTRUE(ld_ctrl$store_trace)) {
    keep <- Filter(Negate(is.null), ld_trace_rows[seq_len(iter)])
    if (length(keep)) do.call(rbind, keep) else data.frame()
  } else {
    data.frame()
  }
  s_trace_df <- if (isTRUE(ld_ctrl$store_trace)) {
    keep <- Filter(Negate(is.null), s_trace_rows[seq_len(iter)])
    if (length(keep)) do.call(rbind, keep) else data.frame()
  } else {
    data.frame()
  }

  ld_signoff_summary <- if (nrow(ld_trace_df)) {
    base <- {
      tail_n <- min(50L, nrow(ld_trace_df))
      tail_df <- utils::tail(ld_trace_df, tail_n)
      list(
        tail_n = tail_n,
        candidate_local_pass_rate = mean(as.logical(tail_df$ld_mode_local_pass_candidate), na.rm = TRUE),
        committed_local_pass_rate = mean(as.logical(tail_df$ld_mode_local_pass_committed), na.rm = TRUE),
        candidate_grad_inf_median = stats::median(tail_df$ld_mode_grad_inf_norm_candidate, na.rm = TRUE),
        committed_grad_inf_median = stats::median(tail_df$ld_mode_grad_inf_norm_committed, na.rm = TRUE),
        candidate_min_eig_median = stats::median(tail_df$ld_mode_neg_hess_min_eig_candidate, na.rm = TRUE),
        committed_min_eig_median = stats::median(tail_df$ld_mode_neg_hess_min_eig_committed, na.rm = TRUE),
        stabilized_rate = mean(as.logical(tail_df$ld_stabilized), na.rm = TRUE),
        fallback_rate = mean(as.logical(tail_df$ld_used_fallback), na.rm = TRUE),
        optim_fallback_rate = mean(as.logical(tail_df$ld_used_optim_fallback), na.rm = TRUE),
        numeric_hessian_rate = mean(as.logical(tail_df$ld_used_numeric_hessian), na.rm = TRUE),
        identity_hessian_rate = mean(as.logical(tail_df$ld_used_identity_hessian), na.rm = TRUE),
        cov_floor_rate = mean(as.logical(tail_df$ld_used_cov_floor), na.rm = TRUE),
        direct_commit_rate = mean(tail_df$ld_commit_mode == "direct", na.rm = TRUE),
        damped_commit_rate = mean(tail_df$ld_commit_mode == "damped", na.rm = TRUE),
        objective_gap_median = stats::median(tail_df$ld_objective_gap, na.rm = TRUE)
      )
    }
    c(base, .exal_static_ld_committed_stability(ld_trace_df, conv_ctrl))
  } else {
    list()
  }
  if (!converged && identical(stop_reason, "max_iter") && isTRUE(ld_signoff_summary$committed_stable)) {
    converged <- TRUE
    stop_reason <- "joint_converged_stabilized"
  }

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
    beta_prior = list(
      type = beta_prior_obj$type,
      controls = beta_prior_obj$controls,
      summary = beta_prior_obj$summary_vb(beta_state),
      state = if (identical(beta_prior_obj$type, "rhs")) beta_state else NULL
    ),
    misc = list(p0 = p0, bounds = c(L = L, U = U), n = n, p = p, elbo = elbo_trace),
    diagnostics = list(
      elbo = elbo_trace,
      convergence = list(
        converged = converged,
        stop_reason = stop_reason,
        iter = iter,
        stable_count = stable_count,
        criteria = conv_ctrl,
        final = list(
          delta_state = if (length(delta_beta)) utils::tail(delta_beta, 1L) else NA_real_,
          delta_sigma = if (length(delta_sigma)) utils::tail(delta_sigma, 1L) else NA_real_,
          delta_gamma = if (length(delta_gamma)) utils::tail(delta_gamma, 1L) else NA_real_,
          delta_s = if (length(delta_s)) utils::tail(delta_s, 1L) else NA_real_,
          delta_elbo = if (length(delta_elbo)) utils::tail(delta_elbo, 1L) else NA_real_
        )
      ),
      deltas = list(
        state = delta_beta,
        sigma = delta_sigma,
        gamma = delta_gamma,
        s = delta_s,
        elbo = delta_elbo
      ),
      s_block = list(
        trace = s_trace_df,
        final = if (nrow(s_trace_df)) {
          as.list(s_trace_df[nrow(s_trace_df), , drop = FALSE])
        } else {
          list()
        }
      ),
      ld_block = list(
        controls = ld_ctrl,
        setup = ld_setup,
        trace = ld_trace_df,
        stabilization = list(
          active_final = stabilize_active,
          since_iter = stabilize_since_iter,
          reason = stabilize_reason_active,
          cycle_detect_count = if (nrow(ld_trace_df)) sum(ld_trace_df$ld_cycle_detected, na.rm = TRUE) else 0L,
          stabilized_iter_count = if (nrow(ld_trace_df)) sum(ld_trace_df$ld_stabilized, na.rm = TRUE) else 0L
        ),
        xi = list(
          method = ld_ctrl$xi_method,
          mode = if (identical(ld_ctrl$xi_method, "delta")) "delta" else ld_ctrl$xi_mode,
          replicates = if (identical(ld_ctrl$xi_method, "delta")) 0L else ld_ctrl$xi_replicates,
          reuse_draws = ld_ctrl$reuse_draws,
          reuse_seed = ld_ctrl$reuse_seed
        ),
        mode_quality = mode_quality,
        signoff_summary = ld_signoff_summary
      )
    )
  )
  if (identical(beta_prior_obj$type, "rhs")) {
    .static_rhs_maybe_warn_collapse(ret$beta_prior$summary, beta_prior_obj$controls)
  }
  class(ret) <- "exal_ldvb"
  if (verbose) {
    cat(sprintf("LDVB %s in %d iters (%.2fs): gamma~%.3f, sigma~%.3f\n",
                ifelse(converged, "converged", "stopped"),
                iter, ret$run.time, ret$qsiggam$gamma_mean, ret$qsiggam$sigma_mean))
  }
  ret
}
