#' Fit fixed-design RQR with exact Gibbs MCMC
#'
#' This fits the generalized-Bayes RQR interval readout for a fixed design
#' matrix. It is not a likelihood for the original response and does not define
#' posterior predictive response draws.
#'
#' @param y Response vector.
#' @param X Design matrix.
#' @param coverage_level Interval coverage level in `(0, 1)`.
#' @param learning_rate Positive generalized-Bayes learning rate.
#' @param loss_reference_scale Positive scale dividing the RQR loss before
#'   applying `learning_rate` or learned `lambda`. The default `1` reproduces
#'   the existing raw-loss target.
#' @param learning_rate_mode Learning-rate treatment. `"fixed"` preserves the
#'   existing fixed generalized-Bayes target. `"learned_scale"` samples the
#'   recommended inverse-loss scale from the generalized posterior proportional
#'   to `lambda^T exp(-lambda L_c)`. `"learned_pure"` is a diagnostic target
#'   proportional to `exp(-lambda L_c)`.
#' @param lambda_prior Gamma prior for learned `lambda`, as a list with
#'   positive `shape` and `rate`. The optional `power` field defaults to one
#'   for `"learned_scale"` and zero for `"learned_pure"`.
#' @param beta_prior_obj Beta prior object from [beta_prior()]. Version 1
#'   supports `"ridge"` and `"rhs_ns"`.
#' @param mcmc_control Named list with `n_burn`, `n_mcmc`, `thin`, `seed`,
#'   `verbose`, `progress_every`, `precision_beta`, and `store_latent_draws`.
#' @param init Optional initial values.
#' @param ... Reserved.
#' @return An `rqr_mcmc` object.
#' @export
rqr_mcmc_fit <- function(y, X, coverage_level, learning_rate = 1,
                         loss_reference_scale = 1,
                         learning_rate_mode = c("fixed", "learned_scale", "learned_pure"),
                         lambda_prior = list(shape = 4, rate = 4),
                         beta_prior_obj = NULL,
                         mcmc_control = list(),
                         init = list(),
                         ...) {
  dat <- .rqr_assert_xy(y, X)
  y <- dat$y
  X <- dat$X
  n <- nrow(X)
  p <- ncol(X)
  learning_rate_mode <- .rqr_learning_rate_mode(learning_rate_mode)
  lambda_prior <- .rqr_lambda_prior(lambda_prior, learning_rate_mode)
  lambda_current <- as.numeric(init$lambda %||% init$learning_rate %||% learning_rate)[1L]
  if (!is.finite(lambda_current) || lambda_current <= 0) {
    stop("Initial learning_rate/lambda must be finite and positive.", call. = FALSE)
  }
  loss_reference_scale <- as.numeric(loss_reference_scale %||% 1)[1L]
  if (!is.finite(loss_reference_scale) || loss_reference_scale <= 0) {
    stop("loss_reference_scale must be finite and positive.", call. = FALSE)
  }
  constants <- rqr_constants(coverage_level, lambda_current / loss_reference_scale)
  learn_lambda <- !identical(learning_rate_mode, "fixed")

  if (is.null(beta_prior_obj)) {
    beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = 1e4))
  }
  if (!is.list(beta_prior_obj) || is.null(beta_prior_obj$type)) {
    stop("beta_prior_obj must be a beta prior object.", call. = FALSE)
  }
  beta_prior_type <- as.character(beta_prior_obj$type)[1L]
  if (!beta_prior_type %in% c("ridge", "rhs_ns")) {
    stop("rqr_mcmc_fit supports beta_prior_obj$type in {'ridge','rhs_ns'}.", call. = FALSE)
  }
  if (identical(beta_prior_type, "rhs_ns")) {
    .qdesn_assert_rhs_prior_obj_intercept_policy(beta_prior_obj, context = "rqr_mcmc_fit")
  }

  if (!is.list(mcmc_control)) stop("mcmc_control must be a list.", call. = FALSE)
  n_burn <- max(0L, as.integer(mcmc_control$n_burn %||% 1000L))
  n_keep <- max(1L, as.integer(mcmc_control$n_mcmc %||% 1000L))
  thin <- max(1L, as.integer(mcmc_control$thin %||% 1L))
  seed <- mcmc_control$seed %||% mcmc_control$rng_seed %||% NULL
  if (!is.null(seed)) set.seed(as.integer(seed)[1L])
  verbose <- isTRUE(mcmc_control$verbose %||% FALSE)
  progress_every <- max(1L, as.integer(mcmc_control$progress_every %||% 100L))
  store_latent_draws <- isTRUE(mcmc_control$store_latent_draws %||% FALSE)
  precision_beta_cfg <- .exal_normalize_mcmc_precision_beta_cfg(
    mcmc_control$precision_beta %||% mcmc_control$precision %||% list()
  )

  init_roots <- .rqr_init_roots(y, X, coverage_level, init = init)
  beta1 <- init_roots$beta1
  beta2 <- init_roots$beta2
  eta1 <- drop(X %*% beta1)
  eta2 <- drop(X %*% beta2)
  e <- rqr_residual_product(y, eta1, eta2)
  V <- as.numeric(init$latent_v %||% init$V %||% rep(constants$sigma, n))
  if (length(V) != n || any(!is.finite(V)) || any(V <= 0)) {
    V <- rep(constants$sigma, n)
  }

  state1 <- .rqr_prior_state_init(beta_prior_obj, p, init_state = init$beta_prior_state1 %||% init$rhs_ns_state1)
  state2 <- .rqr_prior_state_init(beta_prior_obj, p, init_state = init$beta_prior_state2 %||% init$rhs_ns_state2)

  beta1_draws <- matrix(NA_real_, n_keep, p)
  beta2_draws <- matrix(NA_real_, n_keep, p)
  colnames(beta1_draws) <- colnames(X)
  colnames(beta2_draws) <- colnames(X)
  latent_v_draws <- if (store_latent_draws) matrix(NA_real_, n_keep, n) else NULL
  lambda_draws <- numeric(n_keep)
  loss_trace <- numeric(n_burn + n_keep * thin)
  lambda_trace <- numeric(n_burn + n_keep * thin)
  effective_learning_rate_trace <- numeric(n_burn + n_keep * thin)
  lambda_post_shape_trace <- rep(NA_real_, n_burn + n_keep * thin)
  lambda_post_rate_trace <- rep(NA_real_, n_burn + n_keep * thin)
  precision_strategy_root1 <- character(n_burn + n_keep * thin)
  precision_strategy_root2 <- character(n_burn + n_keep * thin)
  rhs_stats1 <- vector("list", n_keep)
  rhs_stats2 <- vector("list", n_keep)

  total_iter <- n_burn + n_keep * thin
  save_idx <- 0L
  for (iter in seq_len(total_iter)) {
    eta1 <- drop(X %*% beta1)
    eta2 <- drop(X %*% beta2)
    e <- rqr_residual_product(y, eta1, eta2)
    if (learn_lambda) {
      loss_for_lambda <- sum(rqr_check_loss(e, constants$alpha)) / loss_reference_scale
      lambda_post <- .rqr_lambda_posterior_params(
        loss_sum = loss_for_lambda,
        n = n,
        lambda_prior = lambda_prior,
        learning_rate_mode = learning_rate_mode
      )
      lambda_post_shape_trace[iter] <- lambda_post$shape
      lambda_post_rate_trace[iter] <- lambda_post$rate
      lambda_current <- stats::rgamma(1L, shape = lambda_post$shape, rate = lambda_post$rate)
      constants <- rqr_constants(coverage_level, lambda_current / loss_reference_scale)
    }
    gp <- rqr_gig_params(e, coverage_level = constants$alpha, learning_rate = constants$omega)
    V <- as.numeric(.sample_gig_devroye_required(
      1L,
      p = gp$p,
      a = gp$a,
      b_vec = gp$b,
      context = "rqr_mcmc_fit::latent_v"
    )[1L, ])

    prior_prec1 <- .rqr_prior_precision(beta_prior_obj, state1, p = p)
    upd1 <- .rqr_beta_update(
      y = y,
      X = X,
      beta_other = beta2,
      V = V,
      constants = constants,
      prior_prec = prior_prec1,
      precision_beta_cfg = precision_beta_cfg,
      context = list(
        iter = iter,
        n_burn = n_burn,
        likelihood_family = "rqr_generalized_bayes",
        beta_prior_type = beta_prior_type,
        root = "root1"
      )
    )
    beta1 <- upd1$draw
    pstats1 <- upd1$info %||% list()
    pr_upd1 <- .rqr_prior_state_update(beta_prior_obj, state1, beta1)
    state1 <- pr_upd1$state

    prior_prec2 <- .rqr_prior_precision(beta_prior_obj, state2, p = p)
    upd2 <- .rqr_beta_update(
      y = y,
      X = X,
      beta_other = beta1,
      V = V,
      constants = constants,
      prior_prec = prior_prec2,
      precision_beta_cfg = precision_beta_cfg,
      context = list(
        iter = iter,
        n_burn = n_burn,
        likelihood_family = "rqr_generalized_bayes",
        beta_prior_type = beta_prior_type,
        root = "root2"
      )
    )
    beta2 <- upd2$draw
    pstats2 <- upd2$info %||% list()
    pr_upd2 <- .rqr_prior_state_update(beta_prior_obj, state2, beta2)
    state2 <- pr_upd2$state

    eta1 <- drop(X %*% beta1)
    eta2 <- drop(X %*% beta2)
    loss_trace[iter] <- sum(rqr_check_loss(rqr_residual_product(y, eta1, eta2), constants$alpha))
    lambda_trace[iter] <- lambda_current
    effective_learning_rate_trace[iter] <- constants$omega
    precision_strategy_root1[iter] <- as.character(pstats1$strategy %||% "direct")
    precision_strategy_root2[iter] <- as.character(pstats2$strategy %||% "direct")

    if (iter > n_burn && ((iter - n_burn) %% thin == 0L)) {
      save_idx <- save_idx + 1L
      beta1_draws[save_idx, ] <- beta1
      beta2_draws[save_idx, ] <- beta2
      lambda_draws[save_idx] <- lambda_current
      if (store_latent_draws) latent_v_draws[save_idx, ] <- V
      rhs_stats1[[save_idx]] <- pr_upd1$stats %||% list()
      rhs_stats2[[save_idx]] <- pr_upd2$stats %||% list()
    }

    if (verbose && (iter %% progress_every == 0L || iter == total_iter)) {
      message(sprintf("[rqr_mcmc_fit] iter %d/%d loss=%.6g", iter, total_iter, loss_trace[iter]))
    }
  }

  summary <- .rqr_fit_summary(y, X, beta1_draws, beta2_draws)
  lambda_summary <- .rqr_lambda_summary(lambda_draws)
  effective_learning_rate_summary <- .rqr_lambda_summary(lambda_draws / loss_reference_scale)
  learning_rate_report <- if (learn_lambda) lambda_summary$mean else lambda_current
  out <- list(
    method = "mcmc",
    family = "rqr_desn",
    model_spec = list(
      family = "rqr_desn",
      parameterization = "two_root_readouts",
      coverage_level = constants$alpha,
      learning_rate = learning_rate_report,
      learning_rate_initial = as.numeric(init$lambda %||% init$learning_rate %||% learning_rate)[1L],
      loss_reference_scale = loss_reference_scale,
      effective_learning_rate = if (learn_lambda) effective_learning_rate_summary$mean else constants$omega,
      effective_learning_rate_summary = effective_learning_rate_summary,
      learning_rate_mode = learning_rate_mode,
      learned_inverse_loss_scale = learn_lambda,
      lambda_prior = lambda_prior,
      lambda_power = if (learn_lambda) lambda_prior$power * n else 0,
      lambda_power_per_observation = if (learn_lambda) lambda_prior$power else 0,
      lambda_summary = lambda_summary,
      sigma = if (learn_lambda) effective_learning_rate_summary$implied_sigma_mean else constants$sigma,
      inference = "mcmc",
      generalized_bayes = TRUE,
      response_likelihood = FALSE
    ),
    y = y,
    X = X,
    samp.beta_root1 = beta1_draws,
    samp.beta_root2 = beta2_draws,
    samp.lambda = lambda_draws,
    samp.latent_v = latent_v_draws,
    summary = summary,
    diagnostics = list(
      loss_trace = loss_trace,
      scaled_loss_trace = loss_trace / loss_reference_scale,
      weighted_loss_trace = lambda_trace * loss_trace / loss_reference_scale,
      lambda_trace = lambda_trace,
      effective_learning_rate_trace = effective_learning_rate_trace,
      lambda_post_shape_trace = lambda_post_shape_trace,
      lambda_post_rate_trace = lambda_post_rate_trace,
      precision_strategy_root1 = precision_strategy_root1,
      precision_strategy_root2 = precision_strategy_root2,
      precision_beta = precision_beta_cfg,
      rhs_stats_root1 = rhs_stats1,
      rhs_stats_root2 = rhs_stats2
    ),
    beta_prior = list(type = beta_prior_type, hypers = beta_prior_obj$hypers),
    last = list(
      beta_root1 = beta1,
      beta_root2 = beta2,
      lambda = lambda_current,
      effective_learning_rate = constants$omega,
      beta_prior_state1 = state1,
      beta_prior_state2 = state2,
      latent_v = V
    ),
    misc = list(
      n_burn = n_burn,
      n_mcmc = n_keep,
      thin = thin,
      seed = seed,
      constants = constants,
      column_names = colnames(X),
      note = "RQR is a generalized-Bayes interval readout, not a response likelihood."
    )
  )
  class(out) <- c("rqr_mcmc", "rqr_fit")
  out
}

#' @export
rqr_posterior_draws.rqr_mcmc <- function(object, nd = NULL, seed = NULL, ...) {
  if (!inherits(object, "rqr_mcmc")) stop("Expected an rqr_mcmc object.", call. = FALSE)
  if (!is.null(seed)) set.seed(as.integer(seed)[1L])
  b1 <- as.matrix(object$samp.beta_root1)
  b2 <- as.matrix(object$samp.beta_root2)
  n_save <- nrow(b1)
  lambda_all <- as.numeric(object$samp.lambda %||% rep(object$model_spec$learning_rate %||% NA_real_, n_save))
  if (is.null(nd) || is.na(nd)) {
    idx <- seq_len(n_save)
  } else {
    nd <- max(1L, as.integer(nd)[1L])
    idx <- sample.int(n_save, size = nd, replace = nd > n_save)
  }
  list(
    beta_root1 = b1[idx, , drop = FALSE],
    beta_root2 = b2[idx, , drop = FALSE],
    lambda = lambda_all[idx],
    nd = length(idx)
  )
}

#' @export
predict_interval.rqr_mcmc <- function(object, X_new, nd = NULL, draws = NULL, seed = NULL, ...) {
  if (!inherits(object, "rqr_mcmc")) stop("Expected an rqr_mcmc object.", call. = FALSE)
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
print.rqr_mcmc <- function(x, ...) {
  cat("RQR fixed-design MCMC fit\n")
  cat(sprintf("  coverage_level: %.4f\n", x$model_spec$coverage_level))
  cat(sprintf("  learning_rate:  %.4f\n", x$model_spec$learning_rate))
  cat(sprintf("  rate_mode:      %s\n", x$model_spec$learning_rate_mode %||% "fixed"))
  if (isTRUE(x$model_spec$learned_inverse_loss_scale)) {
    cat(sprintf("  lambda_mean:    %.4f\n", x$model_spec$lambda_summary$mean))
  }
  cat(sprintf("  draws:          %d\n", nrow(x$samp.beta_root1)))
  cat("  interpretation: generalized-Bayes interval readout, not response likelihood\n")
  invisible(x)
}
