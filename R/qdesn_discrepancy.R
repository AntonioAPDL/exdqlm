#' Fit a source-indexed Q-DESN discrepancy readout
#'
#' This fitter is the package-side engine for applications that stack a
#' reference stream and a forecast-system stream on a fixed Q-DESN design. The
#' first implemented kernel is an asymmetric-Laplace working likelihood with
#' source-specific scales and a shared augmented readout. The exAL and VB-LD
#' variants are intentionally left unimplemented until the AL MCMC path passes
#' synthetic validation.
#'
#' @param z Numeric stacked response vector.
#' @param H Numeric augmented design matrix. For the GloFAS application, rows
#'   have the form `[X, 0]` for the reference source and `[X, X]` for the
#'   forecast-system source.
#' @param source Source labels for rows of `z` and `H`.
#' @param p0 Target quantile level in `(0, 1)`.
#' @param method Currently only `"mcmc"` is implemented.
#' @param likelihood_family Currently only `"al"` is implemented.
#' @param beta_prior_type Coefficient prior. The default is `"rhs_ns"`.
#' @param source_levels Character vector giving source order.
#' @param intercept_index Coefficient indices that receive weak Gaussian
#'   intercept priors under RHS-family shrinkage.
#' @param vb_args,mcmc_args,control Named control lists. `vb_args` is reserved
#'   for the future VB-LD implementation.
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
  if (!identical(method, "mcmc")) {
    .stopf("qdesn_fit_discrepancy currently implements method = 'mcmc' only.")
  }
  if (!identical(likelihood_family, "al")) {
    .stopf("qdesn_fit_discrepancy currently implements likelihood_family = 'al' only.")
  }
  if (length(vb_args)) {
    warning("qdesn_fit_discrepancy: vb_args are ignored until the VB-LD path is implemented.", call. = FALSE)
  }

  qdesn_fit_discrepancy_mcmc(
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
  )
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
