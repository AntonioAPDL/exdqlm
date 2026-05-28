if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.qdesn_rolling_int <- function(x, name) {
  out <- suppressWarnings(as.integer(x))
  if (!length(out) || anyNA(out) || any(!is.finite(out))) {
    stop(sprintf("%s must be finite integer values.", name), call. = FALSE)
  }
  out
}

.qdesn_rolling_window_indices <- function(origin, n_total, mode, window_size = NULL) {
  origin <- as.integer(origin)[1L]
  n_total <- as.integer(n_total)[1L]
  if (!is.finite(origin) || origin < 1L || origin > n_total) {
    stop("rolling origin must be in 1:length(y).", call. = FALSE)
  }
  if (identical(mode, "expanding")) {
    start <- 1L
  } else {
    window_size <- as.integer(window_size)[1L]
    if (!is.finite(window_size) || window_size < 1L) {
      stop("window_size must be a positive integer for rolling mode.", call. = FALSE)
    }
    start <- max(1L, origin - window_size + 1L)
  }
  seq.int(start, origin)
}

.qdesn_rolling_check_vb_args <- function(vb_args) {
  if (!is.list(vb_args)) stop("vb_args must be a list.", call. = FALSE)
  likelihood_family <- tolower(as.character(vb_args$likelihood_family %||% "al")[1L])
  if (!identical(likelihood_family, "al")) {
    stop("qdesn_vb_fit_rolling() currently supports likelihood_family = 'al' only.", call. = FALSE)
  }
  beta_prior_type <- tolower(as.character(vb_args$beta_prior_type %||% "ridge")[1L])
  if (!identical(beta_prior_type, "ridge")) {
    stop("qdesn_vb_fit_rolling() currently supports beta_prior_type = 'ridge' only.", call. = FALSE)
  }
  if (!is.null(vb_args$warm_start)) {
    stop("qdesn_vb_fit_rolling() does not use warm_start; posterior-as-prior handoff is a separate gated mode.", call. = FALSE)
  }
  chunking <- vb_args$chunking %||% (vb_args$vb_control %||% list())$chunking %||% NULL
  if (is.list(chunking) && isTRUE(chunking$enabled)) {
    mode <- tolower(as.character(chunking$mode %||% "exact")[1L])
    if (!identical(mode, "exact")) {
      stop("qdesn_vb_fit_rolling() currently allows only unchunked or exact chunked VB.", call. = FALSE)
    }
  }
  vb_args$likelihood_family <- "al"
  vb_args$al_fixed_gamma <- vb_args$al_fixed_gamma %||% 0
  vb_args$beta_prior_type <- "ridge"
  vb_args
}

.qdesn_rolling_normalize_posterior_as_prior <- function(posterior_as_prior) {
  if (is.null(posterior_as_prior) || identical(posterior_as_prior, FALSE)) {
    return(list(enabled = FALSE))
  }
  if (identical(posterior_as_prior, TRUE)) {
    posterior_as_prior <- list(enabled = TRUE)
  }
  if (!is.list(posterior_as_prior)) {
    stop("posterior_as_prior must be logical or a list.", call. = FALSE)
  }
  enabled <- if (is.null(posterior_as_prior$enabled)) TRUE else isTRUE(posterior_as_prior$enabled)
  if (!enabled) return(list(enabled = FALSE))
  mode <- tolower(as.character(posterior_as_prior$mode %||% "gaussian_beta")[1L])
  if (!identical(mode, "gaussian_beta")) {
    stop("posterior_as_prior mode must be 'gaussian_beta'.", call. = FALSE)
  }
  prior_strength <- as.numeric(posterior_as_prior$prior_strength %||% 1)[1L]
  if (!is.finite(prior_strength) || prior_strength <= 0) {
    stop("posterior_as_prior$prior_strength must be finite and > 0.", call. = FALSE)
  }
  jitter <- as.numeric(posterior_as_prior$jitter %||% 1e-8)[1L]
  if (!is.finite(jitter) || jitter < 0) {
    stop("posterior_as_prior$jitter must be finite and >= 0.", call. = FALSE)
  }
  list(
    enabled = TRUE,
    mode = mode,
    prior_strength = prior_strength,
    jitter = jitter,
    validate_feature_settings = isTRUE(posterior_as_prior$validate_feature_settings %||% TRUE)
  )
}

.qdesn_rolling_posterior_state <- function(fit, origin_id, origin, idx,
                                           prior_strength = 1,
                                           jitter = 1e-8) {
  readout <- fit$fit
  qbeta_m <- as.numeric(readout$qbeta$m)
  qbeta_V <- as.matrix(readout$qbeta$V)
  p <- length(qbeta_m)
  if (!all(dim(qbeta_V) == c(p, p)) || any(!is.finite(qbeta_V))) {
    stop("posterior-as-prior handoff requires a finite p x p beta covariance.", call. = FALSE)
  }
  qbeta_V <- 0.5 * (qbeta_V + t(qbeta_V))
  if (jitter > 0) {
    qbeta_V <- qbeta_V + diag(jitter, p)
  }
  chol_V <- tryCatch(chol(qbeta_V), error = function(e) NULL)
  if (is.null(chol_V)) {
    stop("posterior-as-prior handoff beta covariance is not positive definite.", call. = FALSE)
  }
  precision <- prior_strength * chol2inv(chol_V)
  precision <- 0.5 * (precision + t(precision))
  natural <- as.numeric(precision %*% qbeta_m)
  feature_hash <- .qdesn_vb_feature_settings_hash(fit$meta %||% list())
  design_hash <- .qdesn_vb_design_hash(fit$X)
  state_hash <- .qdesn_vb_hash_object(list(
    type = "qdesn_vb_posterior_as_prior_state",
    version = "0.1",
    origin = as.integer(origin),
    n_features = as.integer(p),
    beta_mean = qbeta_m,
    beta_cov = qbeta_V,
    feature_settings_hash = feature_hash,
    package_sha = .qdesn_vb_package_sha()
  ))
  list(
    type = "qdesn_vb_posterior_as_prior_state",
    version = "0.1",
    origin_id = as.integer(origin_id),
    origin = as.integer(origin),
    window_start = as.integer(idx[1L]),
    window_end = as.integer(idx[length(idx)]),
    n_features = as.integer(p),
    design_hash = design_hash,
    feature_settings_hash = feature_hash,
    state_hash = state_hash,
    precision = precision,
    natural = natural,
    beta_mean = qbeta_m,
    beta_cov = qbeta_V,
    prior_strength = as.numeric(prior_strength),
    jitter = as.numeric(jitter)
  )
}

.qdesn_rolling_validate_handoff <- function(state, fit, validate_feature_settings = TRUE) {
  if (is.null(state)) return(invisible(TRUE))
  p <- ncol(fit$X)
  if (!identical(as.integer(state$n_features), as.integer(p))) {
    stop("posterior-as-prior state dimension does not match the current Q-DESN design.", call. = FALSE)
  }
  if (isTRUE(validate_feature_settings)) {
    current_hash <- .qdesn_vb_feature_settings_hash(fit$meta %||% list())
    state_hash <- as.character(state$feature_settings_hash %||% NA_character_)[1L]
    if (is.na(current_hash) || is.na(state_hash) || !identical(current_hash, state_hash)) {
      stop("posterior-as-prior feature settings hash does not match the current Q-DESN design.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

.qdesn_rolling_prior_from_state <- function(state) {
  if (is.null(state)) return(NULL)
  beta_prior(
    "gaussian_natural",
    gaussian = list(
      precision = state$precision,
      natural = state$natural
    )
  )
}

.qdesn_rolling_fit_summary <- function(fit, origin_id, origin, idx, target_label,
                                       posterior_as_prior = FALSE,
                                       prior_state = NULL) {
  readout <- fit$fit
  data.frame(
    origin_id = as.integer(origin_id),
    origin = as.integer(origin),
    window_start = as.integer(idx[1L]),
    window_end = as.integer(idx[length(idx)]),
    window_n = as.integer(length(idx)),
    effective_rows = as.integer(nrow(fit$X)),
    target_label = target_label,
    likelihood_family = as.character(readout$likelihood_family %||% readout$misc$likelihood_family %||% NA_character_)[1L],
    beta_prior_type = as.character(readout$beta_prior$type %||% NA_character_)[1L],
    posterior_as_prior = isTRUE(posterior_as_prior),
    previous_state_hash = as.character((prior_state %||% list())$state_hash %||% NA_character_)[1L],
    prior_natural_norm = as.numeric(if (is.null(prior_state)) NA_real_ else sqrt(sum(prior_state$natural^2))),
    prior_precision_dim = as.integer(if (is.null(prior_state)) NA_integer_ else nrow(prior_state$precision)),
    handoff_from_origin = as.integer(if (is.null(prior_state)) NA_integer_ else prior_state$origin),
    chunking_mode = as.character((readout$misc$chunking %||% list())$mode %||% "none")[1L],
    converged = isTRUE(readout$converged %||% FALSE),
    iter = as.integer(readout$iter %||% length(readout$misc$elbo_trace %||% numeric(0))),
    finite_qbeta = all(is.finite(readout$qbeta$m)) && all(is.finite(readout$qbeta$V)),
    finite_sigma_gamma = is.finite(readout$qsiggam$sigma_mean) && is.finite(readout$qsiggam$gamma_mean),
    beta_l2 = as.numeric(sqrt(sum(as.numeric(readout$qbeta$m)^2))),
    sigma_mean = as.numeric(readout$qsiggam$sigma_mean),
    gamma_mean = as.numeric(readout$qsiggam$gamma_mean),
    design_hash = .qdesn_vb_design_hash(fit$X),
    stringsAsFactors = FALSE
  )
}

#' Fit Q-DESN VB over explicit rolling or expanding windows
#'
#' This is a target-changing workflow wrapper, not a new approximation. Each
#' origin is fit independently using only `y[window_start:origin]`, so no future
#' responses enter the fixed DESN feature construction or VB readout fit.
#'
#' The first supported stage is deliberately narrow: AL likelihood, ridge beta
#' prior, and unchunked or exact chunked full-data VB. Optional
#' posterior-as-prior mode uses the previous origin's beta posterior as the next
#' Gaussian beta prior. RHS/RHS_NS rolling shrinkage, exAL rolling,
#' stochastic/hybrid rolling, and article adapters remain gated until their
#' state-handoff contracts are tested.
#'
#' @param y Numeric univariate response series.
#' @param p0 Quantile level in `(0, 1)`.
#' @param origins Integer training-origin indices. Each origin is the last row
#'   allowed in that fit.
#' @param window_size Positive integer window size when `mode = "rolling"`.
#' @param mode Either `"rolling"` or `"expanding"`.
#' @param desn_args List of Q-DESN feature arguments forwarded to
#'   [qdesn_fit_vb()]. Do not include `y`, `p0`, `vb_args`, or `fit_readout`.
#' @param vb_args List of VB readout arguments forwarded to [qdesn_fit_vb()].
#'   This first stage supports only `likelihood_family = "al"` and
#'   `beta_prior_type = "ridge"`.
#' @param posterior_as_prior Logical or list. When enabled, carry each origin's
#'   beta posterior forward as the next origin's Gaussian beta prior. This is a
#'   target-changing workflow and is currently AL + ridge only.
#' @param keep_fits Logical; if `TRUE`, retain each `qdesn_fit` object.
#' @return A `qdesn_vb_rolling_fit` list with window metadata, per-origin
#'   summaries, and optionally the fitted objects.
#' @export
qdesn_vb_fit_rolling <- function(y, p0, origins, window_size = NULL,
                                 mode = c("rolling", "expanding"),
                                 desn_args = list(), vb_args = list(),
                                 posterior_as_prior = FALSE,
                                 keep_fits = TRUE) {
  y <- as.numeric(y)
  if (!length(y) || anyNA(y) || any(!is.finite(y))) {
    stop("y must be a finite numeric vector with at least one observation.", call. = FALSE)
  }
  if (!is.numeric(p0) || length(p0) != 1L || !is.finite(p0) || p0 <= 0 || p0 >= 1) {
    stop("p0 must be a finite scalar in (0, 1).", call. = FALSE)
  }
  mode <- match.arg(mode)
  origins <- unique(.qdesn_rolling_int(origins, "origins"))
  if (!length(origins)) stop("origins must contain at least one origin.", call. = FALSE)
  if (any(origins < 1L | origins > length(y))) {
    stop("origins must lie in 1:length(y).", call. = FALSE)
  }
  posterior_as_prior_cfg <- .qdesn_rolling_normalize_posterior_as_prior(posterior_as_prior)
  if (!is.list(desn_args)) stop("desn_args must be a list.", call. = FALSE)
  forbidden_desn <- intersect(names(desn_args), c("y", "p0", "vb_args", "fit_readout"))
  if (length(forbidden_desn)) {
    stop(sprintf("desn_args must not contain: %s.", paste(forbidden_desn, collapse = ", ")), call. = FALSE)
  }
  vb_args <- .qdesn_rolling_check_vb_args(vb_args)
  if (isTRUE(posterior_as_prior_cfg$enabled) && !is.null(vb_args$beta_prior_obj)) {
    stop("posterior-as-prior manages beta_prior_obj internally; supply ridge controls, not beta_prior_obj.", call. = FALSE)
  }

  target_label <- if (isTRUE(posterior_as_prior_cfg$enabled)) {
    "posterior_as_prior_al_ridge"
  } else if (identical(mode, "rolling")) {
    "rolling_window_full_data_vb"
  } else {
    "expanding_window_full_data_vb"
  }
  windows <- lapply(origins, .qdesn_rolling_window_indices,
                    n_total = length(y), mode = mode, window_size = window_size)
  windows_df <- do.call(rbind, lapply(seq_along(windows), function(i) {
    idx <- windows[[i]]
    data.frame(
      origin_id = as.integer(i),
      origin = as.integer(origins[[i]]),
      window_start = as.integer(idx[1L]),
      window_end = as.integer(idx[length(idx)]),
      window_n = as.integer(length(idx)),
      uses_future_rows = any(idx > origins[[i]]),
      stringsAsFactors = FALSE
    )
  }))

  fits <- vector("list", length(windows))
  summaries <- vector("list", length(windows))
  handoffs <- vector("list", length(windows))
  previous_state <- NULL
  for (i in seq_along(windows)) {
    idx <- windows[[i]]
    vb_args_i <- vb_args
    prior_state <- previous_state
    if (isTRUE(posterior_as_prior_cfg$enabled) && !is.null(prior_state)) {
      vb_args_i$beta_prior_obj <- .qdesn_rolling_prior_from_state(prior_state)
    }
    fit_args <- c(
      list(y = y[idx], p0 = p0, fit_readout = TRUE),
      desn_args,
      list(vb_args = vb_args_i)
    )
    fit <- do.call(qdesn_fit_vb, fit_args)
    .qdesn_rolling_validate_handoff(
      state = prior_state,
      fit = fit,
      validate_feature_settings = posterior_as_prior_cfg$validate_feature_settings
    )
    summaries[[i]] <- .qdesn_rolling_fit_summary(
      fit = fit,
      origin_id = i,
      origin = origins[[i]],
      idx = idx,
      target_label = target_label,
      posterior_as_prior = posterior_as_prior_cfg$enabled,
      prior_state = prior_state
    )
    if (isTRUE(posterior_as_prior_cfg$enabled)) {
      output_state <- .qdesn_rolling_posterior_state(
        fit = fit,
        origin_id = i,
        origin = origins[[i]],
        idx = idx,
        prior_strength = posterior_as_prior_cfg$prior_strength,
        jitter = posterior_as_prior_cfg$jitter
      )
      handoffs[[i]] <- data.frame(
        origin_id = as.integer(i),
        origin = as.integer(origins[[i]]),
        input_state_hash = as.character((prior_state %||% list())$state_hash %||% NA_character_)[1L],
        input_from_origin = as.integer(if (is.null(prior_state)) NA_integer_ else prior_state$origin),
        input_natural_norm = as.numeric(if (is.null(prior_state)) NA_real_ else sqrt(sum(prior_state$natural^2))),
        output_state_hash = as.character(output_state$state_hash),
        output_natural_norm = as.numeric(sqrt(sum(output_state$natural^2))),
        output_precision_dim = as.integer(nrow(output_state$precision)),
        design_hash = as.character(output_state$design_hash),
        feature_settings_hash = as.character(output_state$feature_settings_hash),
        stringsAsFactors = FALSE
      )
      previous_state <- output_state
    }
    if (isTRUE(keep_fits)) fits[[i]] <- fit
  }

  out <- list(
    target = list(
      type = target_label,
      preserves_full_data_target = FALSE,
      posterior_as_prior = isTRUE(posterior_as_prior_cfg$enabled),
      no_future_leakage = !any(windows_df$uses_future_rows),
      note = if (isTRUE(posterior_as_prior_cfg$enabled)) {
        "Each origin uses only its window rows and carries the previous beta posterior forward as the next Gaussian beta prior; this changes the posterior target."
      } else {
        "Each origin is an independent same-window full-data VB fit; rolling/expanding windows change the data target."
      }
    ),
    mode = mode,
    p0 = as.numeric(p0),
    y_length = as.integer(length(y)),
    origins = as.integer(origins),
    window_size = if (is.null(window_size)) NA_integer_ else as.integer(window_size)[1L],
    windows = windows_df,
    summary = do.call(rbind, summaries),
    state_handoffs = if (isTRUE(posterior_as_prior_cfg$enabled)) do.call(rbind, handoffs) else NULL,
    fits = if (isTRUE(keep_fits)) fits else NULL,
    controls = list(desn_args = desn_args, vb_args = vb_args, posterior_as_prior = posterior_as_prior_cfg),
    package = list(sha = .qdesn_vb_package_sha(), version = .qdesn_vb_package_version())
  )
  class(out) <- c("qdesn_vb_rolling_fit", "list")
  out
}
