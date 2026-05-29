if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.normal_desn_stop <- function(...) {
  stop(sprintf(...), call. = FALSE)
}

.normal_desn_assert_matrix <- function(X, name = "X") {
  X <- as.matrix(X)
  if (!length(dim(X)) || nrow(X) < 1L || ncol(X) < 1L || any(!is.finite(X))) {
    .normal_desn_stop("%s must be a finite matrix with positive dimensions.", name)
  }
  X
}

.normal_desn_assert_response <- function(y, n = NULL) {
  y <- as.numeric(y)
  if (!length(y) || any(!is.finite(y))) {
    .normal_desn_stop("y must be a finite numeric vector.")
  }
  if (!is.null(n) && length(y) != n) {
    .normal_desn_stop("length(y) must equal nrow(X).")
  }
  y
}

.normal_desn_normalize_omega_prior <- function(omega_prior) {
  omega_prior <- omega_prior %||% list()
  a <- as.numeric(omega_prior$a %||% omega_prior$shape %||% 2)[1L]
  b <- as.numeric(omega_prior$b %||% omega_prior$rate %||% 1)[1L]
  if (!is.finite(a) || a <= 0) .normal_desn_stop("omega_prior$a must be finite and > 0.")
  if (!is.finite(b) || b <= 0) .normal_desn_stop("omega_prior$b must be finite and > 0.")
  list(a = a, b = b, parameterization = "IG_rate")
}

.normal_desn_normalize_scaled_ridge_prior <- function(prior, p) {
  prior <- prior %||% list()
  p <- as.integer(p)[1L]

  P <- prior$precision %||% prior$P %||% NULL
  if (!is.null(P)) {
    P <- as.matrix(P)
    if (!all(dim(P) == c(p, p)) || any(!is.finite(P))) {
      .normal_desn_stop("prior$precision must be a finite p x p matrix.")
    }
    P <- 0.5 * (P + t(P))
  } else {
    tau2 <- as.numeric(prior$beta_ridge_tau2 %||% prior$tau2 %||% 1e4)[1L]
    if (!is.finite(tau2) || tau2 <= 0) {
      .normal_desn_stop("prior$beta_ridge_tau2 must be finite and > 0.")
    }
    intercept_var <- as.numeric(prior$intercept_var %||% 1e6)[1L]
    if (!is.finite(intercept_var) || intercept_var <= 0) {
      .normal_desn_stop("prior$intercept_var must be finite and > 0.")
    }
    prec <- rep(1 / tau2, p)
    if (isTRUE(prior$has_intercept %||% TRUE) && p >= 1L) {
      prec[1L] <- 1 / intercept_var
    }
    P <- diag(prec, p)
  }
  if (is.null(tryCatch(chol(P), error = function(e) NULL))) {
    .normal_desn_stop("scaled-ridge prior precision must be positive definite.")
  }

  b <- prior$mean %||% prior$b %||% rep(0, p)
  b <- as.numeric(b)
  if (length(b) == 1L) b <- rep(b, p)
  if (length(b) != p || any(!is.finite(b))) {
    .normal_desn_stop("prior mean must be finite with length ncol(X).")
  }
  if (!is.null(prior$intercept_mean) && p >= 1L) {
    b[1L] <- as.numeric(prior$intercept_mean)[1L]
  }

  list(type = "scaled_ridge", mean = b, precision = P)
}

.normal_desn_sym_solve <- function(P, h = NULL) {
  P <- 0.5 * (P + t(P))
  R <- tryCatch(chol(P), error = function(e) NULL)
  if (is.null(R)) {
    jitter <- sqrt(.Machine$double.eps) * max(1, mean(diag(P)))
    R <- tryCatch(chol(P + diag(jitter, nrow(P))), error = function(e) NULL)
  }
  if (is.null(R)) .normal_desn_stop("linear system is not positive definite.")
  inv <- chol2inv(R)
  out <- list(inv = 0.5 * (inv + t(inv)), chol = R, logdet = 2 * sum(log(diag(R))))
  if (!is.null(h)) out$x <- as.numeric(backsolve(R, forwardsolve(t(R), h)))
  out
}

.normal_desn_data_stats <- function(X, y) {
  list(
    n = nrow(X),
    p = ncol(X),
    XtX = crossprod(X),
    Xty = as.numeric(crossprod(X, y)),
    yty = as.numeric(crossprod(y))
  )
}

.normal_desn_fit_scaled_ridge <- function(X, y, prior, omega_prior) {
  stats <- .normal_desn_data_stats(X, y)
  P0 <- prior$precision
  b0 <- prior$mean
  h_n <- as.numeric(P0 %*% b0 + stats$Xty)
  P_n <- P0 + stats$XtX
  sol_n <- .normal_desn_sym_solve(P_n, h_n)
  m_n <- sol_n$x

  a_n <- omega_prior$a + stats$n / 2
  bPb <- as.numeric(crossprod(b0, P0 %*% b0))
  mPm <- as.numeric(crossprod(m_n, P_n %*% m_n))
  B_n <- omega_prior$b + 0.5 * (stats$yty + bPb - mPm)
  B_n <- max(B_n, .Machine$double.eps)
  beta_scale_cov <- (B_n / a_n) * sol_n$inv
  beta_cov <- if (a_n > 1) (B_n / (a_n - 1)) * sol_n$inv else matrix(NA_real_, stats$p, stats$p)

  sol_0 <- .normal_desn_sym_solve(P0)
  log_marginal <- -0.5 * stats$n * log(2 * pi) +
    0.5 * sol_0$logdet - 0.5 * sol_n$logdet +
    omega_prior$a * log(omega_prior$b) - a_n * log(B_n) +
    lgamma(a_n) - lgamma(omega_prior$a)

  list(
    type = "scaled_ridge_exact",
    beta = list(
      mean = m_n,
      cov = beta_cov,
      scale_cov = beta_scale_cov,
      precision = P_n,
      precision_inv = sol_n$inv,
      df = 2 * a_n
    ),
    qbeta = list(
      m = m_n,
      V = beta_cov,
      covariance_approximation = "student_t_marginal"
    ),
    omega2 = list(
      a = a_n,
      b = B_n,
      mean = if (a_n > 1) B_n / (a_n - 1) else NA_real_,
      mode = B_n / (a_n + 1)
    ),
    prior = list(type = "scaled_ridge", mean = b0, precision = P0),
    stats = stats,
    log_marginal = as.numeric(log_marginal),
    exact_closed_form = TRUE,
    uses_vb = FALSE
  )
}

.normal_desn_normalize_vb_control <- function(control) {
  control <- control %||% list()
  max_iter <- as.integer(control$max_iter %||% 200L)[1L]
  min_iter <- as.integer(control$min_iter %||% 5L)[1L]
  tol <- as.numeric(control$tol %||% 1e-6)[1L]
  verbose <- isTRUE(control$verbose %||% FALSE)
  if (!is.finite(max_iter) || max_iter < 1L) .normal_desn_stop("control$max_iter must be a positive integer.")
  if (!is.finite(min_iter) || min_iter < 1L) .normal_desn_stop("control$min_iter must be a positive integer.")
  if (!is.finite(tol) || tol < 0) .normal_desn_stop("control$tol must be finite and >= 0.")
  if (!is.null(control$chunking) && isTRUE(control$chunking$enabled)) {
    .normal_desn_stop("Normal DESN VB chunking is not implemented yet.")
  }
  list(max_iter = max_iter, min_iter = min_iter, tol = tol, verbose = verbose)
}

.normal_desn_make_rhs_prior <- function(beta_prior_type, rhs) {
  rhs <- rhs %||% list()
  rhs <- .qdesn_enforce_rhs_controls(rhs, context = "normal_desn_fit")
  beta_prior(beta_prior_type, rhs = rhs)
}

.normal_desn_fit_rhs_vb <- function(X, y, beta_prior_type, rhs, omega_prior, control) {
  stats <- .normal_desn_data_stats(X, y)
  beta_prior_obj <- .normal_desn_make_rhs_prior(beta_prior_type, rhs)
  state <- beta_prior_obj$init(stats$p)

  ridge_start <- .normal_desn_fit_scaled_ridge(
    X, y,
    .normal_desn_normalize_scaled_ridge_prior(list(beta_ridge_tau2 = 1e4, intercept_var = 1e6), stats$p),
    omega_prior
  )
  m <- ridge_start$beta$mean
  V <- ridge_start$beta$cov
  sigma_a <- omega_prior$a + stats$n / 2
  sigma_b <- ridge_start$omega2$b
  trace <- data.frame(iter = integer(), sigma2_mean = numeric(), beta_max_abs_delta = numeric())

  for (iter in seq_len(control$max_iter)) {
    m_old <- m
    sig_old <- if (sigma_a > 1) sigma_b / (sigma_a - 1) else sigma_b / sigma_a
    e_inv_sigma2 <- sigma_a / sigma_b
    prec_diag <- beta_prior_obj$expected_prec(state, stats$p)
    if (length(prec_diag) != stats$p || any(!is.finite(prec_diag)) || any(prec_diag <= 0)) {
      .normal_desn_stop("RHS expected beta precision must be finite and positive.")
    }

    Pn <- e_inv_sigma2 * stats$XtX + diag(as.numeric(prec_diag), stats$p)
    hn <- e_inv_sigma2 * stats$Xty
    sol <- .normal_desn_sym_solve(Pn, hn)
    m <- sol$x
    V <- sol$inv

    Emm <- V + tcrossprod(m)
    sse <- stats$yty - 2 * as.numeric(crossprod(m, stats$Xty)) + sum(stats$XtX * Emm)
    sse <- max(as.numeric(sse), .Machine$double.eps)
    sigma_a <- omega_prior$a + stats$n / 2
    sigma_b <- omega_prior$b + 0.5 * sse

    qbeta <- list(m = m, V = V)
    state <- beta_prior_obj$update(state, qbeta)

    sig_new <- if (sigma_a > 1) sigma_b / (sigma_a - 1) else sigma_b / sigma_a
    delta <- max(abs(m - m_old), abs(sig_new - sig_old) / max(1, abs(sig_old)))
    trace <- rbind(trace, data.frame(
      iter = as.integer(iter),
      sigma2_mean = as.numeric(sig_new),
      beta_max_abs_delta = as.numeric(delta)
    ))
    if (iter >= control$min_iter && delta <= control$tol) break
  }

  list(
    type = paste0(beta_prior_type, "_vb"),
    beta = list(mean = m, cov = V, precision = .normal_desn_sym_solve(V)$inv, df = Inf),
    qbeta = list(m = m, V = V, covariance_approximation = "full"),
    omega2 = list(
      a = sigma_a,
      b = sigma_b,
      mean = if (sigma_a > 1) sigma_b / (sigma_a - 1) else NA_real_,
      mode = sigma_b / (sigma_a + 1)
    ),
    beta_prior = list(type = beta_prior_type, hypers = beta_prior_obj$hypers, state = state),
    stats = stats,
    trace = trace,
    converged = if (nrow(trace)) utils::tail(trace$beta_max_abs_delta, 1L) <= control$tol else FALSE,
    exact_closed_form = FALSE,
    uses_vb = TRUE
  )
}

#' Fit a fixed-design Normal DESN readout
#'
#' Fits a Gaussian readout to an already constructed DESN design matrix. The
#' `scaled_ridge` prior uses the exact Normal-inverse-gamma posterior. The
#' `rhs` and `rhs_ns` priors use a global mean-field VB approximation and are
#' intentionally labeled approximate.
#'
#' @param X Numeric design matrix.
#' @param y Numeric response vector.
#' @param beta_prior_type One of `"scaled_ridge"`, `"ridge"`, `"rhs"`, or `"rhs_ns"`.
#'   `"ridge"` is accepted as an alias for `"scaled_ridge"`.
#' @param prior List of scaled-ridge prior controls.
#' @param omega_prior List with inverse-gamma `a` and `b`.
#' @param rhs List of RHS/RHS_NS controls when `beta_prior_type` is an RHS family.
#' @param control VB controls for RHS/RHS_NS.
#' @return A `normal_desn_readout` object.
#' @export
normal_desn_fit <- function(X, y,
                            beta_prior_type = c("scaled_ridge", "ridge", "rhs", "rhs_ns"),
                            prior = list(),
                            omega_prior = list(a = 2, b = 1),
                            rhs = list(),
                            control = list()) {
  X <- .normal_desn_assert_matrix(X)
  y <- .normal_desn_assert_response(y, nrow(X))
  beta_prior_type <- tolower(match.arg(beta_prior_type))
  if (identical(beta_prior_type, "ridge")) beta_prior_type <- "scaled_ridge"
  omega_prior <- .normal_desn_normalize_omega_prior(omega_prior)

  if (identical(beta_prior_type, "scaled_ridge")) {
    prior <- .normal_desn_normalize_scaled_ridge_prior(prior, ncol(X))
    fit <- .normal_desn_fit_scaled_ridge(X, y, prior, omega_prior)
    target_label <- "normal_scaled_ridge_exact"
  } else {
    control <- .normal_desn_normalize_vb_control(control)
    fit <- .normal_desn_fit_rhs_vb(X, y, beta_prior_type, rhs, omega_prior, control)
    target_label <- paste0("normal_", beta_prior_type, "_vb_approx")
  }

  mu_hat <- as.numeric(X %*% fit$beta$mean)
  out <- c(fit, list(
    X = X,
    y = y,
    mu_hat = mu_hat,
    residual = y - mu_hat,
    likelihood_family = "normal",
    target = "conditional_mean",
    target_label = target_label,
    preserves_full_data_target = TRUE,
    misc = list(
      beta_prior_type = beta_prior_type,
      omega_prior = omega_prior,
      exact_closed_form = isTRUE(fit$exact_closed_form),
      uses_vb = isTRUE(fit$uses_vb),
      package_sha = .qdesn_vb_package_sha(),
      package_version = .qdesn_vb_package_version()
    )
  ))
  class(out) <- c("normal_desn_readout", "list")
  out
}

.normal_desn_draw_beta <- function(mean, cov, nd) {
  p <- length(mean)
  U <- .chol_psd(cov)
  Z <- matrix(stats::rnorm(nd * p), nd, p)
  sweep(Z %*% U, 2L, mean, `+`)
}

#' Draw from a Normal DESN readout posterior
#'
#' @param fit A `normal_desn_readout` or `qdesn_normal_fit`.
#' @param nd Number of draws.
#' @param seed Optional seed.
#' @return List with `beta`, `omega2`, and `nd`.
#' @export
normal_desn_posterior_draws <- function(fit, nd = 1000L, seed = NULL) {
  if (inherits(fit, "qdesn_normal_fit")) fit <- fit$fit
  if (!inherits(fit, "normal_desn_readout")) {
    .normal_desn_stop("normal_desn_posterior_draws() requires a normal_desn_readout or qdesn_normal_fit.")
  }
  nd <- as.integer(nd)[1L]
  if (!is.finite(nd) || nd < 1L) .normal_desn_stop("nd must be a positive integer.")
  if (!is.null(seed)) {
    old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) .Random.seed else NULL
    on.exit({
      if (is.null(old_seed)) {
        if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
      } else {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(seed)[1L])
  }

  omega2 <- 1 / stats::rgamma(nd, shape = fit$omega2$a, rate = fit$omega2$b)
  if (isTRUE(fit$misc$exact_closed_form)) {
    p <- length(fit$beta$mean)
    U <- .chol_psd(fit$beta$precision_inv)
    Z <- matrix(stats::rnorm(nd * p), nd, p)
    beta <- matrix(NA_real_, nd, p)
    for (i in seq_len(nd)) beta[i, ] <- fit$beta$mean + sqrt(omega2[i]) * as.numeric(Z[i, ] %*% U)
  } else {
    beta <- .normal_desn_draw_beta(fit$beta$mean, fit$beta$cov, nd)
  }
  colnames(beta) <- colnames(fit$X)
  list(beta = beta, omega2 = omega2, nd = nd, target = fit$target_label)
}

#' Posterior predictive draws for a Normal DESN readout
#'
#' @param fit A `normal_desn_readout` or `qdesn_normal_fit`.
#' @param X_new Optional design matrix. Defaults to the training design.
#' @param nd Number of draws.
#' @param seed Optional seed.
#' @param draws Optional result from [normal_desn_posterior_draws()].
#' @return List with `yrep`, `mu_draws`, `beta`, and `omega2`.
#' @export
normal_desn_posterior_predict <- function(fit, X_new = NULL, nd = 1000L,
                                          seed = NULL, draws = NULL) {
  if (!is.null(seed)) {
    old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) .Random.seed else NULL
    on.exit({
      if (is.null(old_seed)) {
        if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
      } else {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(seed)[1L])
  }
  readout <- if (inherits(fit, "qdesn_normal_fit")) fit$fit else fit
  if (!inherits(readout, "normal_desn_readout")) {
    .normal_desn_stop("normal_desn_posterior_predict() requires a normal_desn_readout or qdesn_normal_fit.")
  }
  X_use <- if (is.null(X_new)) readout$X else .normal_desn_assert_matrix(X_new, "X_new")
  if (ncol(X_use) != length(readout$beta$mean)) {
    .normal_desn_stop("ncol(X_new) must match the fitted Normal DESN readout.")
  }
  if (is.null(draws)) draws <- normal_desn_posterior_draws(readout, nd = nd, seed = NULL)
  beta <- draws$beta
  omega2 <- draws$omega2
  mu_draws <- X_use %*% t(beta)
  noise <- matrix(stats::rnorm(nrow(X_use) * nrow(beta)), nrow(X_use), nrow(beta))
  yrep <- mu_draws + sweep(noise, 2L, sqrt(omega2), `*`)
  list(yrep = yrep, mu_draws = mu_draws, beta = beta, omega2 = omega2, nd = nrow(beta))
}

#' Fit a Normal DESN using the existing Q-DESN feature builder
#'
#' @param p0 Quantile-level placeholder forwarded to [qdesn_fit_vb()] for DESN
#'   construction compatibility. Normal DESN targets the conditional mean and
#'   does not use `p0` in the Gaussian readout.
#' @param ... Arguments forwarded to [qdesn_fit_vb()] for DESN construction.
#' @param normal_args Named list forwarded to [normal_desn_fit()].
#' @param fit_readout Logical. If `FALSE`, returns the design-only object.
#' @return A `qdesn_normal_fit` object.
#' @export
qdesn_fit_normal <- function(..., p0 = 0.5, normal_args = list(), fit_readout = TRUE) {
  if (!is.list(normal_args)) .normal_desn_stop("normal_args must be a list.")
  design_fit <- do.call(qdesn_fit_vb, c(list(p0 = p0, fit_readout = FALSE, vb_args = list()), list(...)))
  if (!isTRUE(fit_readout)) return(design_fit)
  readout <- do.call(normal_desn_fit, c(list(X = design_fit$X, y = design_fit$y_fit), normal_args))
  design_fit$fit <- readout
  design_fit$mu_hat <- readout$mu_hat
  design_fit$meta$inference_method <- if (isTRUE(readout$misc$exact_closed_form)) "normal_exact" else "normal_vb"
  design_fit$meta$likelihood_family <- "normal"
  design_fit$meta$target <- "conditional_mean"
  design_fit$meta$target_label <- readout$target_label
  design_fit$meta$normal <- list(
    beta_prior_type = readout$misc$beta_prior_type,
    exact_closed_form = readout$misc$exact_closed_form,
    uses_vb = readout$misc$uses_vb,
    design_hash = .qdesn_vb_design_hash(design_fit$X),
    feature_settings_hash = .qdesn_vb_feature_settings_hash(design_fit$meta),
    package_sha = .qdesn_vb_package_sha(),
    package_version = .qdesn_vb_package_version()
  )
  class(design_fit) <- c("qdesn_normal_fit", "list")
  design_fit
}

#' Predict fitted means from a Normal Q-DESN fit
#'
#' @param object A `qdesn_normal_fit`.
#' @return Numeric vector aligned with `object$y_fit`.
#' @export
predict_mu.qdesn_normal_fit <- function(object) {
  if (!inherits(object, "qdesn_normal_fit") || is.null(object$fit)) {
    .normal_desn_stop("predict_mu.qdesn_normal_fit() requires a fitted qdesn_normal_fit.")
  }
  as.numeric(object$X %*% object$fit$beta$mean)
}

#' Posterior predictive draws for a Normal Q-DESN fit
#'
#' @param object A `qdesn_normal_fit`.
#' @param nd Number of draws.
#' @param X_new Optional fixed design matrix.
#' @param seed Optional seed.
#' @param draws Optional posterior draws.
#' @return Posterior predictive draw list.
#' @export
posterior_predict.qdesn_normal_fit <- function(object, nd = 1000L, X_new = NULL,
                                               seed = NULL, draws = NULL) {
  X_use <- if (is.null(X_new)) object$X else as.matrix(X_new)
  normal_desn_posterior_predict(object$fit, X_new = X_use, nd = nd, seed = seed, draws = draws)
}

#' Build an AL/exAL VB initializer from a Normal DESN fit
#'
#' @param normal_fit A `normal_desn_readout` or `qdesn_normal_fit`.
#' @param likelihood_family Target family, `"al"` or `"exal"`.
#' @param beta_prior_type Target beta prior family.
#' @param p0 Quantile level recorded for AL/exAL initialization metadata.
#' @param eps Positive covariance jitter used for validation metadata only.
#' @return A list suitable as `vb_args$init` for [qdesn_fit_vb()].
#' @export
qdesn_normal_to_vb_init <- function(normal_fit,
                                    likelihood_family = c("al", "exal"),
                                    beta_prior_type = c("ridge", "rhs", "rhs_ns"),
                                    p0 = 0.5,
                                    eps = 1e-8) {
  readout <- if (inherits(normal_fit, "qdesn_normal_fit")) normal_fit$fit else normal_fit
  if (!inherits(readout, "normal_desn_readout")) {
    .normal_desn_stop("qdesn_normal_to_vb_init() requires a Normal DESN fit.")
  }
  likelihood_family <- match.arg(likelihood_family)
  beta_prior_type <- match.arg(beta_prior_type)
  eps <- as.numeric(eps)[1L]
  if (!is.finite(eps) || eps < 0) .normal_desn_stop("eps must be finite and >= 0.")
  beta_cov <- readout$beta$cov + diag(eps, length(readout$beta$mean))
  sigma <- sqrt(readout$omega2$mean %||% readout$omega2$mode)
  list(
    beta_m = as.numeric(readout$beta$mean),
    beta_V = beta_cov,
    qbeta = list(m = as.numeric(readout$beta$mean), V = beta_cov),
    beta_mean = as.numeric(readout$beta$mean),
    beta_cov = beta_cov,
    sigma = sigma,
    source = list(
      type = "qdesn_normal_vb_init",
      normal_target = readout$target_label,
      likelihood_family = likelihood_family,
      beta_prior_type = beta_prior_type,
      p0 = as.numeric(p0),
      design_hash = .qdesn_vb_design_hash(readout$X),
      package_sha = .qdesn_vb_package_sha()
    )
  )
}

#' Build an AL/exAL MCMC initializer from a Normal DESN fit
#'
#' @param normal_fit A `normal_desn_readout` or `qdesn_normal_fit`.
#' @param likelihood_family Target family, `"al"` or `"exal"`.
#' @param beta_prior_type Target beta prior family.
#' @param p0 Quantile level recorded in initialization metadata.
#' @param gamma Initial gamma for exAL. Ignored for AL when `al_fixed_gamma` is supplied.
#' @param al_fixed_gamma Fixed AL gamma, usually zero.
#' @return A list suitable as `mcmc_args$init` for [qdesn_fit_mcmc()].
#' @export
qdesn_normal_to_mcmc_init <- function(normal_fit,
                                      likelihood_family = c("al", "exal"),
                                      beta_prior_type = c("ridge", "rhs", "rhs_ns"),
                                      p0 = 0.5,
                                      gamma = 0,
                                      al_fixed_gamma = 0) {
  readout <- if (inherits(normal_fit, "qdesn_normal_fit")) normal_fit$fit else normal_fit
  if (!inherits(readout, "normal_desn_readout")) {
    .normal_desn_stop("qdesn_normal_to_mcmc_init() requires a Normal DESN fit.")
  }
  likelihood_family <- match.arg(likelihood_family)
  beta_prior_type <- match.arg(beta_prior_type)
  sigma <- sqrt(readout$omega2$mean %||% readout$omega2$mode)
  gamma_init <- if (identical(likelihood_family, "al")) {
    as.numeric(al_fixed_gamma)[1L]
  } else {
    as.numeric(gamma)[1L]
  }
  if (!is.finite(sigma) || sigma <= 0) sigma <- sqrt(readout$omega2$mode)
  if (!is.finite(gamma_init)) gamma_init <- 0
  list(
    beta = as.numeric(readout$beta$mean),
    sigma = as.numeric(sigma),
    gamma = as.numeric(gamma_init),
    source = list(
      type = "qdesn_normal_mcmc_init",
      normal_target = readout$target_label,
      likelihood_family = likelihood_family,
      beta_prior_type = beta_prior_type,
      p0 = as.numeric(p0),
      design_hash = .qdesn_vb_design_hash(readout$X),
      package_sha = .qdesn_vb_package_sha()
    )
  )
}
