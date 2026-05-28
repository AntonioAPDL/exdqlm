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

.qdesn_rolling_fit_summary <- function(fit, origin_id, origin, idx, target_label) {
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
#' prior, and unchunked or exact chunked full-data VB. Posterior-as-prior,
#' RHS/RHS_NS rolling shrinkage, exAL rolling, stochastic/hybrid rolling, and
#' article adapters remain gated until their state-handoff contracts are tested.
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
#' @param posterior_as_prior Logical; currently must be `FALSE`.
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
  if (isTRUE(posterior_as_prior)) {
    stop("posterior_as_prior is not implemented; use independent rolling-window refits for this stage.", call. = FALSE)
  }
  if (!is.list(desn_args)) stop("desn_args must be a list.", call. = FALSE)
  forbidden_desn <- intersect(names(desn_args), c("y", "p0", "vb_args", "fit_readout"))
  if (length(forbidden_desn)) {
    stop(sprintf("desn_args must not contain: %s.", paste(forbidden_desn, collapse = ", ")), call. = FALSE)
  }
  vb_args <- .qdesn_rolling_check_vb_args(vb_args)

  target_label <- if (identical(mode, "rolling")) "rolling_window_full_data_vb" else "expanding_window_full_data_vb"
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
  for (i in seq_along(windows)) {
    idx <- windows[[i]]
    fit_args <- c(
      list(y = y[idx], p0 = p0, fit_readout = TRUE),
      desn_args,
      list(vb_args = vb_args)
    )
    fit <- do.call(qdesn_fit_vb, fit_args)
    summaries[[i]] <- .qdesn_rolling_fit_summary(
      fit = fit,
      origin_id = i,
      origin = origins[[i]],
      idx = idx,
      target_label = target_label
    )
    if (isTRUE(keep_fits)) fits[[i]] <- fit
  }

  out <- list(
    target = list(
      type = target_label,
      preserves_full_data_target = FALSE,
      posterior_as_prior = FALSE,
      no_future_leakage = !any(windows_df$uses_future_rows),
      note = "Each origin is an independent same-window full-data VB fit; rolling/expanding windows change the data target."
    ),
    mode = mode,
    p0 = as.numeric(p0),
    y_length = as.integer(length(y)),
    origins = as.integer(origins),
    window_size = if (is.null(window_size)) NA_integer_ else as.integer(window_size)[1L],
    windows = windows_df,
    summary = do.call(rbind, summaries),
    fits = if (isTRUE(keep_fits)) fits else NULL,
    controls = list(desn_args = desn_args, vb_args = vb_args),
    package = list(sha = .qdesn_vb_package_sha(), version = .qdesn_vb_package_version())
  )
  class(out) <- c("qdesn_vb_rolling_fit", "list")
  out
}
