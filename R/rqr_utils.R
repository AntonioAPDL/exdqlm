# RQR utilities deliberately keep their own fallback for the package's common
# null-coalescing idiom so source load order cannot affect the new backend.
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' RQR loss constants
#'
#' @param coverage_level Interval coverage level in `(0, 1)`.
#' @param learning_rate Positive generalized-Bayes learning rate.
#' @return A named list with `alpha`, `omega`, `sigma`, `xi`, and `phi`.
#' @export
rqr_constants <- function(coverage_level, learning_rate = 1) {
  alpha <- as.numeric(coverage_level)[1L]
  omega <- as.numeric(learning_rate)[1L]
  if (!is.finite(alpha) || alpha <= 0 || alpha >= 1) {
    stop("coverage_level must be a finite scalar in (0, 1).", call. = FALSE)
  }
  if (!is.finite(omega) || omega <= 0) {
    stop("learning_rate must be a finite positive scalar.", call. = FALSE)
  }
  list(
    alpha = alpha,
    omega = omega,
    sigma = 1 / omega,
    xi = (1 - 2 * alpha) / (alpha * (1 - alpha)),
    phi = 2 / (alpha * (1 - alpha))
  )
}

#' RQR check loss
#'
#' @param u Numeric residual product.
#' @param coverage_level Interval coverage level.
#' @return Numeric vector of RQR check losses.
#' @export
rqr_check_loss <- function(u, coverage_level) {
  alpha <- rqr_constants(coverage_level)$alpha
  u <- as.numeric(u)
  u * (alpha - as.numeric(u < 0))
}

#' RQR root residual product
#'
#' @param y Response vector.
#' @param eta1,eta2 Numeric root ordinates.
#' @return Numeric vector `(y - eta1) * (y - eta2)`.
#' @export
rqr_residual_product <- function(y, eta1, eta2) {
  y <- as.numeric(y)
  eta1 <- as.numeric(eta1)
  eta2 <- as.numeric(eta2)
  if (length(y) != length(eta1) || length(y) != length(eta2)) {
    stop("y, eta1, and eta2 must have the same length.", call. = FALSE)
  }
  (y - eta1) * (y - eta2)
}

#' RQR pseudo residual from the transformed AL representation
#'
#' @param y Response vector.
#' @param eta1,eta2 Numeric root ordinates.
#' @return Numeric vector `y^2 - y * (eta1 + eta2) + eta1 * eta2`.
#' @export
rqr_pseudo_residual <- function(y, eta1, eta2) {
  y <- as.numeric(y)
  eta1 <- as.numeric(eta1)
  eta2 <- as.numeric(eta2)
  if (length(y) != length(eta1) || length(y) != length(eta2)) {
    stop("y, eta1, and eta2 must have the same length.", call. = FALSE)
  }
  y^2 - y * (eta1 + eta2) + eta1 * eta2
}

#' RQR ordered endpoints
#'
#' @param eta1,eta2 Numeric root ordinates.
#' @return A list with `lower`, `upper`, `midpoint`, and `width`.
#' @export
rqr_order_endpoints <- function(eta1, eta2) {
  eta1 <- as.numeric(eta1)
  eta2 <- as.numeric(eta2)
  if (length(eta1) != length(eta2)) {
    stop("eta1 and eta2 must have the same length.", call. = FALSE)
  }
  lower <- pmin(eta1, eta2)
  upper <- pmax(eta1, eta2)
  list(
    lower = lower,
    upper = upper,
    midpoint = 0.5 * (lower + upper),
    width = upper - lower
  )
}

#' RQR GIG parameters for latent pseudo-AL scales
#'
#' The returned `a` and `b` match the package GIG convention proportional to
#' `x^(p - 1) exp(-(a * x + b / x) / 2)`.
#'
#' @param e Residual product.
#' @param coverage_level Interval coverage level.
#' @param learning_rate Positive generalized-Bayes learning rate.
#' @return A list with `p`, `a`, and `b`.
#' @export
rqr_gig_params <- function(e, coverage_level, learning_rate = 1) {
  cc <- rqr_constants(coverage_level, learning_rate)
  e <- as.numeric(e)
  list(
    p = 0.5,
    a = 1 / (2 * cc$sigma * cc$alpha * (1 - cc$alpha)),
    b = cc$alpha * (1 - cc$alpha) * e^2 / (2 * cc$sigma)
  )
}

.rqr_assert_xy <- function(y, X) {
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  y <- as.numeric(y)
  if (!length(y) || !nrow(X) || length(y) != nrow(X)) {
    stop("y must be numeric with length equal to nrow(X).", call. = FALSE)
  }
  if (!ncol(X)) stop("X must have at least one column.", call. = FALSE)
  if (any(!is.finite(y)) || any(!is.finite(X))) {
    stop("y and X must contain only finite values.", call. = FALSE)
  }
  list(y = y, X = X)
}

.rqr_intercept_index <- function(X, tol = 1e-12) {
  X <- as.matrix(X)
  for (j in seq_len(ncol(X))) {
    xj <- X[, j]
    if (all(is.finite(xj)) && max(abs(xj - xj[1L])) <= tol && abs(xj[1L] - 1) <= tol) {
      return(j)
    }
  }
  NA_integer_
}

.rqr_init_roots <- function(y, X, coverage_level, init = list()) {
  p <- ncol(X)
  b1 <- init$beta1 %||% init$beta_root1 %||% NULL
  b2 <- init$beta2 %||% init$beta_root2 %||% NULL
  if (!is.null(b1) || !is.null(b2)) {
    if (is.null(b1) || is.null(b2)) stop("init must provide both beta1 and beta2.", call. = FALSE)
    b1 <- as.numeric(b1)
    b2 <- as.numeric(b2)
    if (length(b1) != p || length(b2) != p) stop("Initial beta vectors must have ncol(X) entries.", call. = FALSE)
    return(list(beta1 = b1, beta2 = b2))
  }
  alpha <- rqr_constants(coverage_level)$alpha
  probs <- c((1 - alpha) / 2, 1 - (1 - alpha) / 2)
  qs <- as.numeric(stats::quantile(y, probs = probs, names = FALSE, type = 8))
  beta1 <- rep(0, p)
  beta2 <- rep(0, p)
  jj <- .rqr_intercept_index(X)
  if (is.na(jj)) jj <- 1L
  beta1[jj] <- qs[1L]
  beta2[jj] <- qs[2L]
  list(beta1 = beta1, beta2 = beta2)
}

.rqr_prior_precision <- function(beta_prior_obj, state, p) {
  if (is.null(beta_prior_obj)) {
    return(rep(1 / 1e4, p))
  }
  type <- as.character(beta_prior_obj$type %||% "ridge")[1L]
  if (identical(type, "ridge")) {
    tau2 <- as.numeric(beta_prior_obj$hypers$tau2 %||% 1e4)[1L]
    if (!is.finite(tau2) || tau2 <= 0) stop("ridge tau2 must be positive.", call. = FALSE)
    return(rep(1 / tau2, p))
  }
  if (identical(type, "rhs_ns")) {
    return(.exal_mcmc_rhs_ns_precisions(state, p = p))
  }
  stop("RQR currently supports beta_prior_obj$type in {'ridge','rhs_ns'}.", call. = FALSE)
}

.rqr_prior_state_init <- function(beta_prior_obj, p, init_state = NULL) {
  type <- as.character(beta_prior_obj$type %||% "ridge")[1L]
  if (identical(type, "ridge")) return(list())
  if (identical(type, "rhs_ns")) {
    st <- .exal_mcmc_rhs_ns_prepare_state(beta_prior_obj, p = p, init = list(beta_prior_state = init_state))
    return(st)
  }
  stop("RQR currently supports beta_prior_obj$type in {'ridge','rhs_ns'}.", call. = FALSE)
}

.rqr_prior_state_update <- function(beta_prior_obj, state, beta, freeze_tau = FALSE) {
  type <- as.character(beta_prior_obj$type %||% "ridge")[1L]
  if (identical(type, "ridge")) {
    return(list(state = state, stats = list()))
  }
  if (identical(type, "rhs_ns")) {
    return(.exal_mcmc_rhs_ns_gibbs_update(state, beta, beta_prior_obj, freeze_tau = freeze_tau))
  }
  stop("RQR currently supports beta_prior_obj$type in {'ridge','rhs_ns'}.", call. = FALSE)
}

.rqr_beta_update <- function(y, X, beta_other, V, constants, prior_prec,
                             precision_beta_cfg = list(), context = list()) {
  eta_other <- drop(X %*% beta_other)
  A <- X * as.numeric(y - eta_other)
  z <- y^2 - y * eta_other - constants$xi * V
  W <- 1 / (constants$phi * constants$sigma * V)
  Prec <- crossprod(A * sqrt(W)) + diag(as.numeric(prior_prec), ncol(X))
  rhs <- crossprod(A, W * z)
  .exal_mcmc_sample_mvnorm_prec(
    rhs = as.numeric(rhs),
    Prec = Prec,
    precision_beta_cfg = precision_beta_cfg,
    context = context
  )
}

.rqr_precision_mean <- function(Prec, rhs) {
  Uc <- chol((Prec + t(Prec)) / 2)
  as.numeric(backsolve(Uc, forwardsolve(t(Uc), rhs)))
}

.rqr_fit_summary <- function(y, X, beta1_draws, beta2_draws) {
  eta1 <- X %*% t(beta1_draws)
  eta2 <- X %*% t(beta2_draws)
  lower <- pmin(eta1, eta2)
  upper <- pmax(eta1, eta2)
  list(
    beta_root1_mean = colMeans(beta1_draws),
    beta_root2_mean = colMeans(beta2_draws),
    lower_mean = rowMeans(lower),
    upper_mean = rowMeans(upper),
    midpoint_mean = rowMeans(0.5 * (lower + upper)),
    width_mean = rowMeans(upper - lower),
    coverage_in_sample = mean(y >= rowMeans(lower) & y <= rowMeans(upper)),
    width_mean_scalar = mean(rowMeans(upper - lower))
  )
}

#' Draw posterior beta samples from an RQR fit
#'
#' @param object An RQR fit object.
#' @param nd Number of draws. `NULL` keeps all available MCMC draws.
#' @param seed Optional RNG seed.
#' @param ... Reserved.
#' @return A list with `beta_root1`, `beta_root2`, and `nd`.
#' @export
rqr_posterior_draws <- function(object, nd = NULL, seed = NULL, ...) {
  UseMethod("rqr_posterior_draws")
}

#' Predict RQR intervals
#'
#' @param object An RQR fit object.
#' @param ... Method-specific arguments.
#' @return A list of interval draws and summaries.
#' @export
predict_interval <- function(object, ...) {
  UseMethod("predict_interval")
}
