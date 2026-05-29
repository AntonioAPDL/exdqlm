.qdesn_normal_extract_readout <- function(object, X = NULL, meta = NULL) {
  if (inherits(object, "qdesn_normal_fit")) {
    readout <- object$fit
    X <- X %||% object$X
    meta <- meta %||% object$meta %||% list()
  } else {
    readout <- object
    meta <- meta %||% list()
  }
  if (!inherits(readout, "normal_desn_readout")) {
    .normal_desn_stop("qdesn_normal_make_warm_start() requires a qdesn_normal_fit or normal_desn_readout.")
  }
  X <- X %||% readout$X
  if (is.null(X)) {
    .normal_desn_stop("qdesn_normal_make_warm_start(): X is required when the input does not store a design matrix.")
  }
  list(readout = readout, X = .normal_desn_assert_matrix(X, "X"), meta = meta)
}

.qdesn_normal_readout_exact_status <- function(readout) {
  if (isTRUE(readout$misc$exact_closed_form)) {
    if (identical(readout$target_label, "normal_scaled_ridge_exact_chunked")) {
      "exact_chunked"
    } else {
      "exact"
    }
  } else {
    "approximate_vb"
  }
}

.qdesn_normal_safe_created_at <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

.qdesn_normal_validate_cov <- function(V, p, name = "beta covariance") {
  V <- as.matrix(V)
  if (!all(dim(V) == c(p, p)) || any(!is.finite(V))) {
    .normal_desn_stop("%s must be a finite %d x %d matrix.", name, p, p)
  }
  if (max(abs(V - t(V))) > 1e-8 * max(1, max(abs(V)))) {
    .normal_desn_stop("%s must be symmetric.", name)
  }
  V <- 0.5 * (V + t(V))
  if (is.null(tryCatch(chol(V), error = function(e) NULL))) {
    .normal_desn_stop("%s must be positive definite.", name)
  }
  V
}

.qdesn_normal_state_as_readout <- function(warm_start) {
  readout <- list(
    beta = list(
      mean = as.numeric(warm_start$beta$mean),
      cov = as.matrix(warm_start$beta$cov)
    ),
    omega2 = list(
      a = as.numeric(warm_start$omega2$a %||% warm_start$omega2$shape)[1L],
      b = as.numeric(warm_start$omega2$b %||% warm_start$omega2$rate)[1L],
      mean = as.numeric(warm_start$omega2$mean)[1L],
      mode = as.numeric(warm_start$omega2$mode)[1L]
    ),
    X = matrix(0, nrow = as.integer(warm_start$design$n_rows), ncol = as.integer(warm_start$design$n_features)),
    target_label = as.character(warm_start$target$label)[1L],
    misc = list(
      exact_closed_form = identical(as.character(warm_start$target$exact_status)[1L], "exact") ||
        identical(as.character(warm_start$target$exact_status)[1L], "exact_chunked")
    )
  )
  colnames(readout$X) <- warm_start$design$colnames %||% NULL
  class(readout) <- c("normal_desn_readout", "list")
  readout
}

#' Create a Normal DESN warm-start state
#'
#' @param object A `qdesn_normal_fit` or `normal_desn_readout`.
#' @param X Optional design matrix. Required when `object` does not store one.
#' @param package_sha Optional package commit SHA to record.
#' @return A `qdesn_normal_warm_start` list.
#' @export
qdesn_normal_make_warm_start <- function(object, X = NULL, package_sha = NULL) {
  ext <- .qdesn_normal_extract_readout(object, X = X)
  readout <- ext$readout
  X <- ext$X
  meta <- ext$meta
  p <- ncol(X)
  if (length(readout$beta$mean) != p) {
    .normal_desn_stop("Normal warm start beta dimension does not match ncol(X).")
  }
  beta_cov <- .qdesn_normal_validate_cov(readout$beta$cov, p)
  omega_mean <- as.numeric(readout$omega2$mean %||% NA_real_)[1L]
  omega_mode <- as.numeric(readout$omega2$mode %||% NA_real_)[1L]
  if ((!is.finite(omega_mean) || omega_mean <= 0) && (!is.finite(omega_mode) || omega_mode <= 0)) {
    .normal_desn_stop("Normal warm start omega2 mean or mode must be finite and positive.")
  }
  prior_state <- readout$beta_prior$state %||% NULL
  target_label <- as.character(readout$target_label %||% "normal_unknown")[1L]
  exact_status <- .qdesn_normal_readout_exact_status(readout)

  state <- list(
    type = "qdesn_normal_warm_start",
    version = "0.1",
    target = list(
      family = "normal",
      label = target_label,
      exact_status = exact_status,
      preserves_full_data_target = isTRUE(readout$preserves_full_data_target %||% TRUE)
    ),
    readout = list(
      class = class(readout),
      likelihood_family = "normal"
    ),
    beta = list(
      mean = as.numeric(readout$beta$mean),
      cov = beta_cov,
      dim = as.integer(p)
    ),
    omega2 = list(
      a = as.numeric(readout$omega2$a %||% readout$omega2$shape %||% NA_real_)[1L],
      b = as.numeric(readout$omega2$b %||% readout$omega2$rate %||% NA_real_)[1L],
      shape = as.numeric(readout$omega2$a %||% readout$omega2$shape %||% NA_real_)[1L],
      rate = as.numeric(readout$omega2$b %||% readout$omega2$rate %||% NA_real_)[1L],
      mean = omega_mean,
      mode = omega_mode
    ),
    prior = list(
      family = as.character(readout$misc$beta_prior_type %||% readout$prior$type %||% readout$beta_prior$type %||% "unknown")[1L],
      hypers = readout$beta_prior$hypers %||% list(),
      rhs_state = prior_state,
      shrink_intercept = isTRUE((prior_state %||% list())$shrink_intercept)
    ),
    design = list(
      n_rows = as.integer(nrow(X)),
      n_features = as.integer(p),
      design_hash = .qdesn_vb_design_hash(X),
      colnames = colnames(X)
    ),
    qdesn = list(
      feature_settings_hash = .qdesn_vb_feature_settings_hash(meta),
      reservoir_metadata = meta[intersect(names(meta), c(
        "D", "n", "n_tilde", "m", "m_input", "add_bias", "p_res",
        "input_mode", "input_mode_effective", "washout"
      ))]
    ),
    package = list(
      sha = package_sha %||% .qdesn_vb_package_sha(),
      version = .qdesn_vb_package_version()
    ),
    control = list(source = "normal_desn", mode = exact_status),
    created_at = .qdesn_normal_safe_created_at()
  )
  class(state) <- c("qdesn_normal_warm_start", "list")
  state
}

#' Validate a Normal DESN warm-start state
#'
#' @param warm_start A `qdesn_normal_warm_start` object.
#' @param X Optional design matrix for design-hash validation.
#' @param meta Optional Q-DESN metadata for feature-settings validation.
#' @param strict Logical; require core metadata fields.
#' @param validate_design_hash Logical.
#' @param validate_feature_settings_hash Logical.
#' @param validate_package_sha Logical.
#' @return Invisibly returns `TRUE`.
#' @export
qdesn_normal_validate_warm_start <- function(warm_start,
                                             X = NULL,
                                             meta = NULL,
                                             strict = TRUE,
                                             validate_design_hash = TRUE,
                                             validate_feature_settings_hash = TRUE,
                                             validate_package_sha = FALSE) {
  if (!is.list(warm_start) ||
      !identical(as.character(warm_start$type %||% "")[1L], "qdesn_normal_warm_start")) {
    .normal_desn_stop("Normal warm start state must have type 'qdesn_normal_warm_start'.")
  }
  if (!identical(as.character(warm_start$version %||% "")[1L], "0.1")) {
    .normal_desn_stop("Unsupported Normal warm start version.")
  }
  if (isTRUE(strict)) {
    if (!identical(as.character(warm_start$target$family %||% "")[1L], "normal")) {
      .normal_desn_stop("Normal warm start target family must be 'normal'.")
    }
    if (!nzchar(as.character(warm_start$target$label %||% "")[1L])) {
      .normal_desn_stop("Normal warm start target label is required.")
    }
    if (!nzchar(as.character(warm_start$prior$family %||% "")[1L])) {
      .normal_desn_stop("Normal warm start prior family is required.")
    }
  }
  p <- as.integer(warm_start$beta$dim %||% length(warm_start$beta$mean))[1L]
  if (!is.finite(p) || p < 1L) .normal_desn_stop("Normal warm start beta dimension must be positive.")
  beta_mean <- as.numeric(warm_start$beta$mean)
  if (length(beta_mean) != p || any(!is.finite(beta_mean))) {
    .normal_desn_stop("Normal warm start beta mean must be finite with the recorded dimension.")
  }
  .qdesn_normal_validate_cov(warm_start$beta$cov, p)
  omega_mean <- as.numeric(warm_start$omega2$mean %||% NA_real_)[1L]
  omega_mode <- as.numeric(warm_start$omega2$mode %||% NA_real_)[1L]
  if ((!is.finite(omega_mean) || omega_mean <= 0) && (!is.finite(omega_mode) || omega_mode <= 0)) {
    .normal_desn_stop("Normal warm start omega2 mean or mode must be finite and positive.")
  }
  if (!is.null(X) && isTRUE(validate_design_hash)) {
    X <- .normal_desn_assert_matrix(X, "X")
    if (ncol(X) != p) .normal_desn_stop("Normal warm start design has incompatible ncol(X).")
    observed <- .qdesn_vb_design_hash(X)
    expected <- as.character(warm_start$design$design_hash %||% "")[1L]
    if (!identical(observed, expected)) .normal_desn_stop("Normal warm start design hash mismatch.")
  }
  if (!is.null(meta) && isTRUE(validate_feature_settings_hash)) {
    observed <- .qdesn_vb_feature_settings_hash(meta)
    expected <- as.character(warm_start$qdesn$feature_settings_hash %||% NA_character_)[1L]
    if (!is.na(expected) && !is.na(observed) && !identical(observed, expected)) {
      .normal_desn_stop("Normal warm start feature settings hash mismatch.")
    }
  }
  if (isTRUE(validate_package_sha)) {
    observed <- .qdesn_vb_package_sha()
    expected <- as.character(warm_start$package$sha %||% "")[1L]
    if (!nzchar(expected) || !identical(observed, expected)) {
      .normal_desn_stop("Normal warm start package SHA mismatch.")
    }
  }
  invisible(TRUE)
}

#' Convert a Normal DESN warm start to an AL/exAL VB initializer
#'
#' @inheritParams qdesn_normal_validate_warm_start
#' @param likelihood_family Target family, `"al"` or `"exal"`.
#' @param beta_prior_type Target beta prior family.
#' @param p0 Quantile level recorded in metadata.
#' @param eps Positive covariance jitter.
#' @return A list suitable as `vb_args$init` for `qdesn_fit_vb()`.
#' @export
qdesn_normal_warm_start_to_vb_init <- function(warm_start,
                                               likelihood_family = c("al", "exal"),
                                               beta_prior_type = c("ridge", "rhs", "rhs_ns"),
                                               p0 = 0.5,
                                               eps = 1e-8) {
  qdesn_normal_validate_warm_start(warm_start, strict = TRUE)
  readout <- .qdesn_normal_state_as_readout(warm_start)
  init <- qdesn_normal_to_vb_init(
    readout,
    likelihood_family = likelihood_family,
    beta_prior_type = beta_prior_type,
    p0 = p0,
    eps = eps
  )
  init$source$source_type <- "qdesn_normal_warm_start"
  init$source$normal_exact_status <- warm_start$target$exact_status
  init$source$design_hash <- warm_start$design$design_hash
  init$source$feature_settings_hash <- warm_start$qdesn$feature_settings_hash
  init$source$package_sha <- warm_start$package$sha
  init
}

#' Convert a Normal DESN warm start to an AL/exAL MCMC initializer
#'
#' @inheritParams qdesn_normal_warm_start_to_vb_init
#' @param gamma Initial gamma for exAL.
#' @param al_fixed_gamma Fixed AL gamma.
#' @return A list suitable as `mcmc_args$init` for `qdesn_fit_mcmc()`.
#' @export
qdesn_normal_warm_start_to_mcmc_init <- function(warm_start,
                                                 likelihood_family = c("al", "exal"),
                                                 beta_prior_type = c("ridge", "rhs", "rhs_ns"),
                                                 p0 = 0.5,
                                                 gamma = 0,
                                                 al_fixed_gamma = 0) {
  qdesn_normal_validate_warm_start(warm_start, strict = TRUE)
  readout <- .qdesn_normal_state_as_readout(warm_start)
  init <- qdesn_normal_to_mcmc_init(
    readout,
    likelihood_family = likelihood_family,
    beta_prior_type = beta_prior_type,
    p0 = p0,
    gamma = gamma,
    al_fixed_gamma = al_fixed_gamma
  )
  init$source$source_type <- "qdesn_normal_warm_start"
  init$source$normal_exact_status <- warm_start$target$exact_status
  init$source$design_hash <- warm_start$design$design_hash
  init$source$feature_settings_hash <- warm_start$qdesn$feature_settings_hash
  init$source$package_sha <- warm_start$package$sha
  init
}
