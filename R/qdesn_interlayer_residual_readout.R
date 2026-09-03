# AL-VB readout and single-origin forecast for paired Q-DESN architectures.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

.qdesn_fit_readout_scale <- function(X, has_intercept = TRUE) {
  X <- as.matrix(X)
  center <- colMeans(X)
  scale <- apply(X, 2L, stats::sd)
  scale[!is.finite(scale) | scale < 1e-12] <- 1

  if (isTRUE(has_intercept) && ncol(X) >= 1L) {
    center[1L] <- 0
    scale[1L] <- 1
  }

  X_scaled <- sweep(sweep(X, 2L, center, "-"), 2L, scale, "/")
  list(
    X = X_scaled,
    center = as.numeric(center),
    scale = as.numeric(scale),
    has_intercept = isTRUE(has_intercept),
    scaled = TRUE
  )
}

.qdesn_apply_readout_scale <- function(x, scale_info) {
  x <- as.numeric(x)
  if (is.null(scale_info) || !isTRUE(scale_info$scaled)) return(x)
  center <- as.numeric(scale_info$center)
  scale <- as.numeric(scale_info$scale)
  if (length(x) != length(center) || length(x) != length(scale)) {
    stop("Readout scaling dimensions do not match the forecast feature vector.", call. = FALSE)
  }
  (x - center) / scale
}

.qdesn_process_lag_matrix_from_meta <- function(lag_matrix, meta) {
  lag_matrix <- as.matrix(lag_matrix)
  m <- nrow(lag_matrix)
  if (m == 0L) return(lag_matrix)

  center <- as.numeric(meta$lag_center %||% rep(0, m))
  scale <- as.numeric(meta$lag_scale %||% rep(1, m))
  if (length(center) == 1L) center <- rep(center, m)
  if (length(scale) == 1L) scale <- rep(scale, m)
  if (length(center) != m || length(scale) != m) {
    stop("Lag preprocessing metadata has incompatible dimensions.", call. = FALSE)
  }
  scale[!is.finite(scale) | abs(scale) < 1e-12] <- 1

  out <- lag_matrix
  if (isTRUE(meta$standardize_inputs %||% FALSE)) {
    out <- sweep(sweep(out, 1L, center, "-"), 1L, scale, "/")
  }

  lag_weights <- meta$win_scale_lags %||% NULL
  if (!is.null(lag_weights)) {
    lag_weights <- as.numeric(lag_weights)
    if (length(lag_weights) != m) {
      stop("win_scale_lags has incompatible dimensions.", call. = FALSE)
    }
    out <- sweep(out, 1L, lag_weights, "*")
  }

  input_bound <- tolower(as.character(meta$input_bound %||% "none")[1L])
  if (identical(input_bound, "tanh")) out <- base::tanh(out)
  if (!input_bound %in% c("none", "tanh")) {
    stop("Unsupported input_bound in residual forecast recursion.", call. = FALSE)
  }
  out
}

.qdesn_make_input_matrix_from_lags <- function(lag_matrix, meta, nd) {
  nd <- as.integer(nd)[1L]
  if (!is.finite(nd) || nd < 1L) stop("nd must be positive.", call. = FALSE)
  lag_matrix <- as.matrix(lag_matrix)
  if (ncol(lag_matrix) != nd) {
    stop("lag_matrix must have one column per predictive path.", call. = FALSE)
  }
  z <- .qdesn_process_lag_matrix_from_meta(lag_matrix, meta)
  u <- rbind(rep(1, nd), z)
  u[1L, ] <- u[1L, ] * as.numeric(meta$win_scale_bias %||% 1)
  if (nrow(u) > 1L) {
    u[-1L, ] <- u[-1L, , drop = FALSE] * as.numeric(meta$win_scale_global %||% 1)
  }
  u
}

.qdesn_apply_readout_scale_matrix <- function(X, scale_info) {
  X <- as.matrix(X)
  if (is.null(scale_info) || !isTRUE(scale_info$scaled)) return(X)
  center <- as.numeric(scale_info$center)
  scale <- as.numeric(scale_info$scale)
  if (nrow(X) != length(center) || nrow(X) != length(scale)) {
    stop("Readout scaling dimensions do not match the forecast feature matrix.", call. = FALSE)
  }
  sweep(sweep(X, 1L, center, "-"), 1L, scale, "/")
}

#' Fit an AL-VB readout to an architecture design
#'
#' Reuses the existing `exal_ldvb_fit()` implementation and fixes the exAL
#' shape at zero, yielding the asymmetric Laplace working likelihood.  The
#' regularized horseshoe prior is not tuned; only its global scale `tau0` is
#' supplied, with default 0.1 for this ablation.
#'
#' @param design A design returned by
#'   [qdesn_build_paired_architecture_designs()].
#' @param p0 Target quantile.
#' @param tau0 Global RHS-NS half-Cauchy scale.
#' @param standardize_readout Standardize non-intercept columns using the
#'   fitting rows only.
#' @param vb_control Optional overrides for the existing VB control.
#' @param fit_seed Optional deterministic seed for stochastic VB components.
#' @return A `qdesn_fit` object.
#' @export
qdesn_fit_al_vb_from_design <- function(
    design,
    p0,
    tau0 = 0.1,
    standardize_readout = TRUE,
    vb_control = list(),
    fit_seed = NULL) {
  if (is.null(design$X) || is.null(design$y_fit) || is.null(design$reservoir)) {
    stop("design is not a valid Q-DESN architecture design.", call. = FALSE)
  }
  p0 <- as.numeric(p0)[1L]
  if (!is.finite(p0) || p0 <= 0 || p0 >= 1) {
    stop("p0 must lie strictly between 0 and 1.", call. = FALSE)
  }
  tau0 <- as.numeric(tau0)[1L]
  if (!is.finite(tau0) || tau0 <= 0) stop("tau0 must be positive.", call. = FALSE)
  if (!is.null(fit_seed)) set.seed(as.integer(fit_seed)[1L])

  X_raw <- as.matrix(design$X_raw %||% design$X)
  scale_info <- if (isTRUE(standardize_readout)) {
    .qdesn_fit_readout_scale(X_raw, has_intercept = isTRUE(design$meta$add_bias %||% FALSE))
  } else {
    list(
      X = X_raw,
      center = rep(0, ncol(X_raw)),
      scale = rep(1, ncol(X_raw)),
      has_intercept = isTRUE(design$meta$add_bias %||% FALSE),
      scaled = FALSE
    )
  }
  X_fit <- scale_info$X
  y_fit <- as.numeric(design$y_fit)

  prior <- beta_prior(
    type = "rhs_ns",
    rhs = list(
      tau0 = tau0,
      shrink_intercept = FALSE
    )
  )

  control_defaults <- list(
    max_iter = 200L,
    min_iter_elbo = 20L,
    tol = 1e-4,
    tol_par = 1e-4,
    n_samp_xi = 500L,
    verbose = FALSE
  )
  control <- utils::modifyList(control_defaults, vb_control %||% list())

  fit <- exal_ldvb_fit(
    y = y_fit,
    X = X_fit,
    p0 = p0,
    gamma_bounds = c(L.fn(p0), U.fn(p0)),
    vb_control = control,
    init = list(gamma = 0, sigma = 1),
    prior_gamma = list(mu0 = 0, s20 = 10),
    prior_sigma = list(a = 1, b = 1),
    beta_prior_obj = prior,
    likelihood_family = "al",
    al_fixed_gamma = 0
  )
  if (!identical(tolower(as.character(fit$likelihood_family)[1L]), "al") ||
      !isTRUE(all.equal(as.numeric(fit$misc$al_fixed_gamma)[1L], 0, tolerance = 0))) {
    stop("The existing VB engine did not preserve the requested AL contract.", call. = FALSE)
  }
  fitted_tau0 <- as.numeric(fit$beta_prior$hypers$tau0 %||% NA_real_)[1L]
  if (!isTRUE(all.equal(fitted_tau0, tau0, tolerance = 0))) {
    stop("The existing VB engine did not preserve the requested RHS tau0.", call. = FALSE)
  }

  out <- design
  out$fit <- fit
  out$X_raw <- X_raw
  out$X <- X_fit
  out$y_fit <- y_fit
  out$mu_hat <- as.numeric(X_fit %*% fit$qbeta$m)
  out$meta$p0 <- p0
  out$meta$likelihood_family <- "al"
  out$meta$al_fixed_gamma <- 0
  out$meta$rhs_tau0 <- tau0
  out$meta$readout_scale <- scale_info
  out$meta$standardize_readout <- isTRUE(standardize_readout)
  out$meta$fit_seed <- if (is.null(fit_seed)) NA_integer_ else as.integer(fit_seed)[1L]
  class(out) <- "qdesn_fit"
  out
}

.qdesn_forward_architecture_one <- function(h_prev, u_vec, reservoir) {
  D <- as.integer(reservoir$D)[1L]
  f_act <- .qdesn_residual_activation(reservoir$act_f)
  k_act <- .qdesn_residual_activation(reservoir$act_k)
  alpha <- as.numeric(reservoir$alpha)
  if (length(alpha) == 1L) alpha <- rep(alpha, D)
  Q_is_identity <- reservoir$Q_is_identity %||% rep(FALSE, max(0L, D - 1L))

  h_new <- vector("list", D)
  h_tilde <- if (D > 1L) vector("list", D - 1L) else list()

  pre1 <- reservoir$W[[1L]] %*% h_prev[[1L]] + reservoir$Win[[1L]] %*% u_vec
  omega1 <- as.numeric(f_act(pre1))
  h_new[[1L]] <- (1 - alpha[1L]) * h_prev[[1L]] + alpha[1L] * omega1

  if (D > 1L) {
    h_tilde[[1L]] <- if (isTRUE(Q_is_identity[1L])) {
      as.numeric(h_new[[1L]])
    } else {
      as.numeric(reservoir$Q[[1L]] %*% h_new[[1L]])
    }

    for (d in seq.int(2L, D)) {
      pre_d <- reservoir$W[[d]] %*% h_prev[[d]] +
        reservoir$Win[[d]] %*% h_tilde[[d - 1L]]
      omega_d <- .qdesn_layer_candidate(
        preactivation = pre_d,
        h_tilde = h_tilde[[d - 1L]],
        layer = d,
        reservoir = reservoir,
        activation = f_act
      )
      h_new[[d]] <- (1 - alpha[d]) * h_prev[[d]] + alpha[d] * omega_d
      if (d < D) {
        h_tilde[[d]] <- if (isTRUE(Q_is_identity[d])) {
          as.numeric(h_new[[d]])
        } else {
          as.numeric(reservoir$Q[[d]] %*% h_new[[d]])
        }
      }
    }
  }

  x_raw <- if (D == 1L) {
    as.numeric(h_new[[1L]])
  } else {
    lower <- unlist(lapply(seq_len(D - 1L), function(d) {
      as.numeric(k_act(h_tilde[[d]]))
    }), use.names = FALSE)
    c(as.numeric(h_new[[D]]), lower)
  }
  list(h = h_new, x_raw = x_raw)
}

.qdesn_forward_architecture_paths <- function(h_prev, u_matrix, reservoir) {
  D <- as.integer(reservoir$D)[1L]
  f_act <- .qdesn_residual_activation(reservoir$act_f)
  k_act <- .qdesn_residual_activation(reservoir$act_k)
  alpha <- as.numeric(reservoir$alpha)
  if (length(alpha) == 1L) alpha <- rep(alpha, D)
  Q_is_identity <- reservoir$Q_is_identity %||% rep(FALSE, max(0L, D - 1L))
  nd <- ncol(u_matrix)

  if (!is.list(h_prev) || length(h_prev) != D ||
      any(vapply(h_prev, ncol, integer(1L)) != nd)) {
    stop("Path states must be matrices with one column per predictive path.", call. = FALSE)
  }

  h_new <- vector("list", D)
  h_tilde <- if (D > 1L) vector("list", D - 1L) else list()

  pre1 <- reservoir$W[[1L]] %*% h_prev[[1L]] + reservoir$Win[[1L]] %*% u_matrix
  omega1 <- f_act(pre1)
  h_new[[1L]] <- (1 - alpha[1L]) * h_prev[[1L]] + alpha[1L] * omega1

  if (D > 1L) {
    h_tilde[[1L]] <- if (isTRUE(Q_is_identity[1L])) {
      h_new[[1L]]
    } else {
      reservoir$Q[[1L]] %*% h_new[[1L]]
    }

    for (d in seq.int(2L, D)) {
      pre_d <- reservoir$W[[d]] %*% h_prev[[d]] +
        reservoir$Win[[d]] %*% h_tilde[[d - 1L]]
      omega_d <- f_act(pre_d)
      if (identical(reservoir$connection_type %||% "plain", "interlayer_residual")) {
        P_layer <- (reservoir$Pskip %||% list())[[d - 1L]] %||% NULL
        if (is.null(P_layer)) {
          stop("Residual projection is missing for layer ", d, ".", call. = FALSE)
        }
        omega_d <- omega_d +
          as.numeric(reservoir$skip_scale %||% 1) *
          (P_layer %*% h_tilde[[d - 1L]])
      }
      h_new[[d]] <- (1 - alpha[d]) * h_prev[[d]] + alpha[d] * omega_d
      if (d < D) {
        h_tilde[[d]] <- if (isTRUE(Q_is_identity[d])) {
          h_new[[d]]
        } else {
          reservoir$Q[[d]] %*% h_new[[d]]
        }
      }
    }
  }

  x_raw <- if (D == 1L) {
    h_new[[1L]]
  } else {
    lower <- do.call(rbind, lapply(seq_len(D - 1L), function(d) k_act(h_tilde[[d]])))
    rbind(h_new[[D]], lower)
  }
  list(h = h_new, x_raw = x_raw)
}

#' Generate a single-origin recursive AL-VB Q-DESN forecast
#'
#' The future observations are never teacher-forced.  Each posterior draw has
#' its own recursive response path, which is fed back into the output-lag input
#' vector.  For paired architecture comparisons, pass identical `fit_seed` and
#' `noise_draws` to both arms.
#'
#' @param object A fitted object from [qdesn_fit_al_vb_from_design()].
#' @param y_history Observed response history through the single forecast
#'   origin.
#' @param H Forecast horizon.
#' @param nd Number of posterior-predictive paths.
#' @param posterior_seed Seed used by the existing VB posterior-draw helper.
#' @param noise_draws Optional list with `exp` and `z`, each an H by nd matrix
#'   of standard exponential and standard normal draws.
#' @return Forecast paths, location paths, and the empirical target-quantile
#'   path.
#' @export
qdesn_forecast_single_origin_al_vb <- function(
    object,
    y_history,
    H = 100L,
    nd = 1000L,
    posterior_seed = NULL,
    noise_draws = NULL) {
  if (is.null(object$fit) || is.null(object$reservoir) || is.null(object$states$H_all)) {
    stop("object is not a fitted architecture object.", call. = FALSE)
  }
  if (!identical(tolower(object$meta$likelihood_family %||% ""), "al")) {
    stop("Single-origin residual forecast requires an AL fit.", call. = FALSE)
  }
  H <- as.integer(H)[1L]
  nd <- as.integer(nd)[1L]
  if (!is.finite(H) || H < 1L || !is.finite(nd) || nd < 1L) {
    stop("H and nd must be positive integers.", call. = FALSE)
  }
  y_history <- as.numeric(y_history)
  if (any(!is.finite(y_history))) stop("y_history must be finite.", call. = FALSE)

  m_input <- as.integer(object$meta$m_input %||% object$meta$m %||% 0L)[1L]
  if (length(y_history) < m_input) {
    stop("y_history is shorter than the reservoir lag requirement.", call. = FALSE)
  }
  if (!is.null(posterior_seed)) set.seed(as.integer(posterior_seed)[1L])
  draws <- exal_posterior_draws(object$fit, nd = nd)
  beta_draws <- as.matrix(draws$beta)
  sigma_draws <- as.numeric(draws$sigma)
  gamma_draws <- as.numeric(draws$gamma)
  nd_eff <- nrow(beta_draws)
  if (length(sigma_draws) != nd_eff || length(gamma_draws) != nd_eff) {
    stop("Posterior draw dimensions are inconsistent.", call. = FALSE)
  }
  if (any(!is.finite(gamma_draws)) || max(abs(gamma_draws)) > 1e-12) {
    stop("AL posterior draws must have gamma fixed at zero.", call. = FALSE)
  }

  if (is.null(noise_draws)) {
    e_draws <- matrix(stats::rexp(H * nd_eff), nrow = H, ncol = nd_eff)
    z_draws <- matrix(stats::rnorm(H * nd_eff), nrow = H, ncol = nd_eff)
  } else {
    e_draws <- as.matrix(noise_draws$exp %||% noise_draws$e)
    z_draws <- as.matrix(noise_draws$z)
    if (!all(dim(e_draws) == c(H, nd_eff)) || !all(dim(z_draws) == c(H, nd_eff))) {
      stop("noise_draws$exp and noise_draws$z must both be H by nd.", call. = FALSE)
    }
    if (any(!is.finite(e_draws)) || any(e_draws <= 0) || any(!is.finite(z_draws))) {
      stop("noise_draws contain invalid values.", call. = FALSE)
    }
  }

  p0 <- as.numeric(object$meta$p0 %||% object$fit$misc$p0)[1L]
  A <- (1 - 2 * p0) / (p0 * (1 - p0))
  B <- 2 / (p0 * (1 - p0))
  reservoir <- object$reservoir
  add_bias <- isTRUE(object$meta$add_bias %||% FALSE)
  scale_info <- object$meta$readout_scale %||% NULL
  origin_state <- lapply(object$states$H_all, function(Hd) as.numeric(Hd[nrow(Hd), ]))
  h_now <- lapply(origin_state, function(x) {
    matrix(x, nrow = length(x), ncol = nd_eff)
  })
  lag_matrix <- if (m_input > 0L) {
    lag0 <- rev(tail(y_history, m_input))
    matrix(lag0, nrow = m_input, ncol = nd_eff)
  } else {
    matrix(numeric(0), nrow = 0L, ncol = nd_eff)
  }
  beta_path_matrix <- t(beta_draws)

  yrep <- matrix(NA_real_, nrow = H, ncol = nd_eff)
  mu_draws <- matrix(NA_real_, nrow = H, ncol = nd_eff)

  # Vectorize over posterior paths. Only the 100 forecast horizons remain as
  # an explicit loop, which is substantially faster than path-by-path state
  # propagation while preserving each draw's own recursive response history.
  for (h in seq_len(H)) {
    u_h <- .qdesn_make_input_matrix_from_lags(lag_matrix, object$meta, nd_eff)
    step <- .qdesn_forward_architecture_paths(h_now, u_h, reservoir)
    h_now <- step$h

    x_raw <- step$x_raw
    if (add_bias) x_raw <- rbind(rep(1, nd_eff), x_raw)
    x_row <- .qdesn_apply_readout_scale_matrix(x_raw, scale_info)
    if (nrow(x_row) != nrow(beta_path_matrix)) {
      stop("Forecast readout dimension does not match beta draws.", call. = FALSE)
    }

    mu_h <- colSums(x_row * beta_path_matrix)
    v_h <- sigma_draws * e_draws[h, ]
    y_h <- mu_h + A * v_h + sqrt(B * sigma_draws * v_h) * z_draws[h, ]
    mu_draws[h, ] <- mu_h
    yrep[h, ] <- y_h

    if (m_input > 0L) {
      lag_matrix <- if (m_input == 1L) {
        matrix(y_h, nrow = 1L)
      } else {
        rbind(y_h, lag_matrix[seq_len(m_input - 1L), , drop = FALSE])
      }
    }
  }

  qhat <- apply(yrep, 1L, stats::quantile, probs = p0, names = FALSE, type = 8)
  list(
    yrep = yrep,
    mu_draws = mu_draws,
    qhat = as.numeric(qhat),
    p0 = p0,
    H = H,
    nd = nd_eff,
    connection_type = reservoir$connection_type %||% "plain"
  )
}

#' Measure empirical state forgetting for one architecture
#'
#' Runs the same observed input history from zero and unit initial states and
#' reports their final discrepancy.  This is a diagnostic, not a formal proof
#' of the echo-state property.
#'
#' @param design Architecture design object.
#' @param y Observed history used to drive the reservoir.
#' @return Layerwise and aggregate final-state discrepancies.
#' @export
qdesn_architecture_forgetting_diagnostic <- function(design, y) {
  reservoir <- design$reservoir
  D <- as.integer(reservoir$D)[1L]
  n <- as.integer(reservoir$n)
  conn <- reservoir$connection_type %||% design$meta$connection_type %||% "plain"
  skip_scale <- as.numeric(reservoir$skip_scale %||% design$meta$skip_scale %||% 0)[1L]

  zero_fit <- .qdesn_roll_architecture_states(
    y = y,
    base_fit = design,
    connection_type = conn,
    skip_scale = skip_scale,
    initial_states = lapply(n, numeric)
  )
  one_fit <- .qdesn_roll_architecture_states(
    y = y,
    base_fit = design,
    connection_type = conn,
    skip_scale = skip_scale,
    initial_states = lapply(n, function(nd) rep(1, nd))
  )

  layer_distance <- vapply(seq_len(D), function(d) {
    a <- zero_fit$states$H_all[[d]][length(y), ]
    b <- one_fit$states$H_all[[d]][length(y), ]
    sqrt(sum((a - b)^2))
  }, numeric(1L))

  data.frame(
    connection_type = conn,
    layer = seq_len(D),
    final_l2_distance = layer_distance,
    aggregate_final_l2_distance = sqrt(sum(layer_distance^2)),
    stringsAsFactors = FALSE
  )
}
