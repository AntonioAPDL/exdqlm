.rqr_vb_latent_mean <- function(e, coverage_level, learning_rate) {
  gp <- rqr_gig_params(e, coverage_level, learning_rate)
  b <- pmax(as.numeric(gp$b), .exal_gig_floor())
  a <- as.numeric(gp$a)[1L]
  sqrt(b / a) + 1 / a
}

.rqr_vb_root_update <- function(y, X, beta_other, V_mean, constants, prior_prec) {
  eta_other <- drop(X %*% beta_other)
  A <- X * as.numeric(y - eta_other)
  z <- y^2 - y * eta_other - constants$xi * V_mean
  W <- 1 / (constants$phi * constants$sigma * V_mean)
  Prec <- crossprod(A * sqrt(W)) + diag(as.numeric(prior_prec), ncol(X))
  rhs <- as.numeric(crossprod(A, W * z))
  mean <- .rqr_precision_mean(Prec, rhs)
  list(mean = mean, precision = Prec, rhs = rhs)
}

#' Fit fixed-design RQR with a coordinate-Gaussian VB approximation
#'
#' This is a fast approximation to the RQR generalized posterior. MCMC remains
#' the reference backend; VB uncertainty should not be treated as calibrated
#' unless separately validated.
#'
#' @param y Response vector.
#' @param X Design matrix.
#' @param coverage_level Interval coverage level in `(0, 1)`.
#' @param learning_rate Positive generalized-Bayes learning rate.
#' @param beta_prior_obj Beta prior object. The initial VB backend supports
#'   ridge priors.
#' @param vb_control Named list with `max_iter`, `tol`, `verbose`, `seed`, and
#'   `n_draws`.
#' @param init Optional initial values.
#' @param ... Reserved.
#' @return An `rqr_vb` object.
#' @export
rqr_vb_fit <- function(y, X, coverage_level, learning_rate = 1,
                       beta_prior_obj = NULL,
                       vb_control = list(),
                       init = list(),
                       ...) {
  dat <- .rqr_assert_xy(y, X)
  y <- dat$y
  X <- dat$X
  p <- ncol(X)
  constants <- rqr_constants(coverage_level, learning_rate)
  if (!is.list(vb_control)) stop("vb_control must be a list.", call. = FALSE)
  seed <- vb_control$seed %||% vb_control$rng_seed %||% NULL
  if (!is.null(seed)) set.seed(as.integer(seed)[1L])
  max_iter <- max(1L, as.integer(vb_control$max_iter %||% 200L))
  tol <- as.numeric(vb_control$tol %||% 1e-5)[1L]
  if (!is.finite(tol) || tol <= 0) tol <- 1e-5
  verbose <- isTRUE(vb_control$verbose %||% FALSE)
  n_draws <- max(20L, as.integer(vb_control$n_draws %||% 1000L))

  if (is.null(beta_prior_obj)) {
    beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = vb_control$beta_ridge_tau2 %||% vb_control$tau2 %||% 1e4))
  }
  beta_prior_type <- as.character(beta_prior_obj$type %||% "ridge")[1L]
  if (!identical(beta_prior_type, "ridge")) {
    stop("rqr_vb_fit currently supports ridge beta priors; use MCMC for RHS_NS.", call. = FALSE)
  }
  prior_prec <- .rqr_prior_precision(beta_prior_obj, list(), p = p)

  init_roots <- .rqr_init_roots(y, X, coverage_level, init = init)
  m1 <- init_roots$beta1
  m2 <- init_roots$beta2
  Prec1 <- diag(prior_prec, p)
  Prec2 <- diag(prior_prec, p)
  objective <- numeric(max_iter)
  delta <- rep(NA_real_, max_iter)

  for (iter in seq_len(max_iter)) {
    old <- c(m1, m2)
    eta1 <- drop(X %*% m1)
    eta2 <- drop(X %*% m2)
    e <- rqr_residual_product(y, eta1, eta2)
    V_mean <- .rqr_vb_latent_mean(e, coverage_level = constants$alpha, learning_rate = constants$omega)

    up1 <- .rqr_vb_root_update(y, X, beta_other = m2, V_mean = V_mean,
                               constants = constants, prior_prec = prior_prec)
    m1 <- up1$mean
    Prec1 <- up1$precision

    eta1 <- drop(X %*% m1)
    e <- rqr_residual_product(y, eta1, eta2)
    V_mean <- .rqr_vb_latent_mean(e, coverage_level = constants$alpha, learning_rate = constants$omega)
    up2 <- .rqr_vb_root_update(y, X, beta_other = m1, V_mean = V_mean,
                               constants = constants, prior_prec = prior_prec)
    m2 <- up2$mean
    Prec2 <- up2$precision

    eta1 <- drop(X %*% m1)
    eta2 <- drop(X %*% m2)
    objective[iter] <- -constants$omega * sum(rqr_check_loss(rqr_residual_product(y, eta1, eta2), constants$alpha)) -
      0.5 * sum(prior_prec * m1^2) - 0.5 * sum(prior_prec * m2^2)
    delta[iter] <- max(abs(c(m1, m2) - old))
    if (verbose) message(sprintf("[rqr_vb_fit] iter %d objective=%.6g delta=%.3g", iter, objective[iter], delta[iter]))
    if (is.finite(delta[iter]) && delta[iter] < tol) {
      objective <- objective[seq_len(iter)]
      delta <- delta[seq_len(iter)]
      break
    }
  }

  rhs1 <- as.numeric(Prec1 %*% m1)
  rhs2 <- as.numeric(Prec2 %*% m2)
  beta1_draws <- matrix(NA_real_, n_draws, p)
  beta2_draws <- matrix(NA_real_, n_draws, p)
  for (ii in seq_len(n_draws)) {
    beta1_draws[ii, ] <- .exal_mcmc_sample_mvnorm_prec(rhs1, Prec1)$draw
    beta2_draws[ii, ] <- .exal_mcmc_sample_mvnorm_prec(rhs2, Prec2)$draw
  }
  colnames(beta1_draws) <- colnames(X)
  colnames(beta2_draws) <- colnames(X)
  summary <- .rqr_fit_summary(y, X, beta1_draws, beta2_draws)

  out <- list(
    method = "vb",
    family = "rqr_desn",
    approximation = "coordinate_gaussian_vb",
    model_spec = list(
      family = "rqr_desn",
      parameterization = "two_root_readouts",
      coverage_level = constants$alpha,
      learning_rate = constants$omega,
      sigma = constants$sigma,
      inference = "vb",
      approximation = "coordinate_gaussian_vb",
      generalized_bayes = TRUE,
      response_likelihood = FALSE,
      calibrated_uncertainty = FALSE
    ),
    y = y,
    X = X,
    qbeta_root1 = list(mean = m1, precision = Prec1),
    qbeta_root2 = list(mean = m2, precision = Prec2),
    draws = list(beta_root1 = beta1_draws, beta_root2 = beta2_draws),
    summary = summary,
    diagnostics = list(
      objective_trace = objective,
      delta_trace = delta,
      converged = is.finite(tail(delta, 1L)) && tail(delta, 1L) < tol,
      warning = "VB is an approximation to the RQR generalized posterior and is not calibrated by default."
    ),
    beta_prior = list(type = beta_prior_type, hypers = beta_prior_obj$hypers),
    misc = list(
      max_iter = max_iter,
      tol = tol,
      seed = seed,
      constants = constants,
      column_names = colnames(X)
    )
  )
  class(out) <- c("rqr_vb", "rqr_fit")
  out
}

#' @export
rqr_posterior_draws.rqr_vb <- function(object, nd = NULL, seed = NULL, ...) {
  if (!inherits(object, "rqr_vb")) stop("Expected an rqr_vb object.", call. = FALSE)
  if (!is.null(seed)) set.seed(as.integer(seed)[1L])
  b1 <- as.matrix(object$draws$beta_root1)
  b2 <- as.matrix(object$draws$beta_root2)
  n_save <- nrow(b1)
  if (is.null(nd) || is.na(nd)) {
    idx <- seq_len(n_save)
  } else {
    nd <- max(1L, as.integer(nd)[1L])
    idx <- sample.int(n_save, size = nd, replace = nd > n_save)
  }
  list(beta_root1 = b1[idx, , drop = FALSE], beta_root2 = b2[idx, , drop = FALSE], nd = length(idx))
}

#' @export
predict_interval.rqr_vb <- function(object, X_new, nd = NULL, draws = NULL, seed = NULL, ...) {
  if (!inherits(object, "rqr_vb")) stop("Expected an rqr_vb object.", call. = FALSE)
  X_new <- as.matrix(X_new)
  if (ncol(X_new) != ncol(object$X)) {
    stop("X_new must have the same number of columns as the fitted design.", call. = FALSE)
  }
  if (is.null(draws)) draws <- rqr_posterior_draws(object, nd = nd, seed = seed)
  eta1 <- X_new %*% t(draws$beta_root1)
  eta2 <- X_new %*% t(draws$beta_root2)
  lower <- pmin(eta1, eta2)
  upper <- pmax(eta1, eta2)
  list(
    lower_draws = lower,
    upper_draws = upper,
    midpoint_draws = 0.5 * (lower + upper),
    width_draws = upper - lower,
    lower_mean = rowMeans(lower),
    upper_mean = rowMeans(upper),
    midpoint_mean = rowMeans(0.5 * (lower + upper)),
    width_mean = rowMeans(upper - lower),
    draws = draws,
    model_spec = object$model_spec
  )
}

#' @export
print.rqr_vb <- function(x, ...) {
  cat("RQR fixed-design VB fit\n")
  cat(sprintf("  coverage_level: %.4f\n", x$model_spec$coverage_level))
  cat(sprintf("  learning_rate:  %.4f\n", x$model_spec$learning_rate))
  cat(sprintf("  approximation:  %s\n", x$approximation))
  cat("  warning:        approximate generalized posterior; not calibrated by default\n")
  invisible(x)
}
