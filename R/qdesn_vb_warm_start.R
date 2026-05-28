if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.qdesn_vb_hash_object <- function(x) {
  digest::digest(x, algo = "sha256")
}

.qdesn_vb_design_hash <- function(X) {
  X <- as.matrix(X)
  .qdesn_vb_hash_object(list(
    dim = dim(X),
    colnames = colnames(X),
    X = unclass(X)
  ))
}

.qdesn_vb_feature_settings_hash <- function(meta) {
  if (is.null(meta) || !is.list(meta)) return(NA_character_)
  keep <- intersect(
    names(meta),
    c(
      "D", "n", "n_tilde", "m", "m_input", "input_lag_warmup",
      "alpha", "rho", "add_bias", "input_mode", "input_mode_effective",
      "standardize_inputs", "input_bound", "win_scale_global",
      "win_scale_bias", "win_scale_lags", "lag_center", "lag_scale",
      "p_res"
    )
  )
  if (!length(keep)) return(NA_character_)
  .qdesn_vb_hash_object(meta[keep])
}

.qdesn_vb_package_sha <- function(path = getwd()) {
  out <- tryCatch(
    system2("git", c("-C", path, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_
  )
  out <- as.character(out)[1L]
  if (!length(out) || is.na(out) || !nzchar(out)) NA_character_ else out
}

.qdesn_vb_package_version <- function() {
  tryCatch(as.character(utils::packageVersion("exdqlm")), error = function(e) NA_character_)
}

.qdesn_vb_extract_readout_fit <- function(object) {
  if (inherits(object, "qdesn_fit")) {
    fit <- object$fit
  } else {
    fit <- object
  }
  if (is.null(fit) || !inherits(fit, "exal_vb")) {
    stop("qdesn_vb_make_warm_start() requires a qdesn_fit with an exal_vb readout or an exal_vb object.", call. = FALSE)
  }
  fit
}

#' Create a Q-DESN VB warm-start state
#'
#' @param object A \code{qdesn_fit} returned by \code{qdesn_fit_vb()}, or an
#'   \code{exal_vb} readout fit when \code{X} is supplied.
#' @param X Optional design matrix. Required when \code{object} is an
#'   \code{exal_vb} fit rather than a full \code{qdesn_fit}.
#' @param package_sha Optional package commit SHA to record.
#' @return A \code{qdesn_vb_warm_start} list.
#' @export
qdesn_vb_make_warm_start <- function(object, X = NULL, package_sha = NULL) {
  fit <- .qdesn_vb_extract_readout_fit(object)
  if (inherits(object, "qdesn_fit")) {
    X <- X %||% object$X
    meta <- object$meta %||% list()
  } else {
    meta <- list()
  }
  if (is.null(X)) {
    stop("qdesn_vb_make_warm_start(): X is required when object is not a qdesn_fit.", call. = FALSE)
  }
  X <- as.matrix(X)
  if (nrow(X) <= 0L || ncol(X) <= 0L) {
    stop("qdesn_vb_make_warm_start(): X must have positive dimensions.", call. = FALSE)
  }

  likelihood_family <- tolower(as.character(
    fit$misc$likelihood_family %||% fit$likelihood_family %||% "exal"
  )[1L])
  prior_type <- tolower(as.character(fit$beta_prior$type %||% "ridge")[1L])
  qsig <- fit$qsiggam %||% list()
  prior_state <- fit$beta_prior$state %||% NULL

  state <- list(
    type = "qdesn_vb_warm_start",
    version = "0.1",
    qbeta = list(
      mean = as.numeric(fit$qbeta$m),
      cov = as.matrix(fit$qbeta$V)
    ),
    qv = list(
      mean = as.numeric(fit$qv$m %||% fit$qv$E_v),
      mean_inv = as.numeric(fit$qv$m_inv %||% fit$qv$E_inv_v)
    ),
    qs = list(
      mean = as.numeric(fit$qs$m %||% fit$qs$E_s),
      mean2 = as.numeric(fit$qs$m2 %||% fit$qs$E_s2)
    ),
    qsiggam = list(
      eta_hat = as.numeric(qsig$eta_hat),
      ell_hat = as.numeric(qsig$ell_hat),
      Sigma = as.matrix(qsig$Sigma),
      gamma_mean = as.numeric(qsig$gamma_mean),
      sigma_mean = as.numeric(qsig$sigma_mean)
    ),
    xis = qsig$xi %||% NULL,
    beta_prior_state = prior_state,
    rhs = if (prior_type %in% c("rhs", "rhs_ns")) prior_state else NULL,
    likelihood = list(
      family = likelihood_family,
      p0 = as.numeric(fit$misc$p0 %||% NA_real_),
      al_fixed_gamma = as.numeric(fit$misc$al_fixed_gamma %||% NA_real_)
    ),
    prior = list(
      family = prior_type,
      hypers = fit$beta_prior$hypers %||% list(),
      shrink_intercept = isTRUE((fit$beta_prior$state %||% list())$shrink_intercept)
    ),
    design = list(
      n_rows = nrow(X),
      n_features = ncol(X),
      design_hash = .qdesn_vb_design_hash(X)
    ),
    qdesn = list(
      feature_settings_hash = .qdesn_vb_feature_settings_hash(meta),
      reservoir_metadata = meta[intersect(names(meta), c("D", "n", "n_tilde", "m", "m_input", "add_bias", "p_res"))]
    ),
    package = list(
      sha = package_sha %||% .qdesn_vb_package_sha(),
      version = .qdesn_vb_package_version()
    ),
    control = list(source = "vb", mode = "full_or_exact")
  )
  class(state) <- c("qdesn_vb_warm_start", "list")
  state
}

.qdesn_vb_normalize_warm_start_control <- function(warm_start) {
  if (is.null(warm_start)) {
    return(list(enabled = FALSE, state = NULL, strict = TRUE,
                validate_design_hash = TRUE, validate_package_sha = FALSE))
  }
  if (inherits(warm_start, "qdesn_vb_warm_start") ||
      identical(warm_start$type %||% NULL, "qdesn_vb_warm_start")) {
    return(list(enabled = TRUE, state = warm_start, strict = TRUE,
                validate_design_hash = TRUE, validate_package_sha = FALSE))
  }
  if (!is.list(warm_start)) {
    stop("warm_start must be a qdesn_vb_warm_start object or a list.", call. = FALSE)
  }
  enabled <- if (is.null(warm_start$enabled)) TRUE else isTRUE(warm_start$enabled)
  if (!enabled) {
    return(list(enabled = FALSE, state = NULL, strict = TRUE,
                validate_design_hash = TRUE, validate_package_sha = FALSE))
  }
  state <- warm_start$state %||% NULL
  if (is.null(state) && identical(warm_start$type %||% NULL, "qdesn_vb_warm_start")) {
    state <- warm_start
  }
  if (is.null(state)) {
    stop("warm_start$state is required when warm_start is enabled.", call. = FALSE)
  }
  list(
    enabled = TRUE,
    state = state,
    strict = isTRUE(warm_start$strict %||% TRUE),
    validate_design_hash = isTRUE(warm_start$validate_design_hash %||% TRUE),
    validate_package_sha = isTRUE(warm_start$validate_package_sha %||% FALSE)
  )
}

.qdesn_vb_assert_vector <- function(x, n, name, positive = FALSE) {
  x <- as.numeric(x)
  if (length(x) != n) stop(sprintf("%s must have length %d.", name, n), call. = FALSE)
  if (any(!is.finite(x)) || (positive && any(x <= 0))) {
    stop(sprintf("%s must be finite%s.", name, if (positive) " and > 0" else ""), call. = FALSE)
  }
  x
}

.qdesn_vb_validate_warm_start <- function(warm_start, X, p0, likelihood_family,
                                          beta_prior_obj,
                                          al_fixed_gamma = NULL,
                                          validate_design_hash = TRUE,
                                          validate_package_sha = FALSE,
                                          strict = TRUE) {
  if (!is.list(warm_start) ||
      !identical(as.character(warm_start$type %||% "")[1L], "qdesn_vb_warm_start")) {
    stop("warm start state must have type 'qdesn_vb_warm_start'.", call. = FALSE)
  }
  X <- as.matrix(X)
  n <- nrow(X)
  p <- ncol(X)
  likelihood_family <- tolower(as.character(likelihood_family)[1L])
  prior_type <- tolower(as.character(beta_prior_obj$type %||% "")[1L])

  state_family <- tolower(as.character(warm_start$likelihood$family %||% "")[1L])
  if (!identical(state_family, likelihood_family)) {
    stop(sprintf(
      "warm start likelihood family mismatch: state has '%s', requested '%s'.",
      state_family, likelihood_family
    ), call. = FALSE)
  }
  state_p0 <- as.numeric(warm_start$likelihood$p0 %||% NA_real_)[1L]
  if (!is.finite(state_p0) || abs(state_p0 - p0) > 1e-12) {
    stop("warm start p0 does not match the requested fit.", call. = FALSE)
  }
  state_prior <- tolower(as.character(warm_start$prior$family %||% "")[1L])
  if (!identical(state_prior, prior_type)) {
    stop(sprintf(
      "warm start beta prior mismatch: state has '%s', requested '%s'.",
      state_prior, prior_type
    ), call. = FALSE)
  }

  design <- warm_start$design %||% list()
  if (!identical(as.integer(design$n_rows %||% NA_integer_), as.integer(n)) ||
      !identical(as.integer(design$n_features %||% NA_integer_), as.integer(p))) {
    stop("warm start design dimensions do not match the requested fit.", call. = FALSE)
  }
  if (isTRUE(validate_design_hash)) {
    expected_hash <- .qdesn_vb_design_hash(X)
    state_hash <- as.character(design$design_hash %||% "")[1L]
    if (!nzchar(state_hash) || !identical(state_hash, expected_hash)) {
      stop("warm start design hash does not match the requested fit.", call. = FALSE)
    }
  }
  if (isTRUE(validate_package_sha)) {
    state_sha <- as.character((warm_start$package %||% list())$sha %||% "")[1L]
    current_sha <- .qdesn_vb_package_sha()
    if (nzchar(state_sha) && nzchar(current_sha) && !identical(state_sha, current_sha)) {
      stop("warm start package SHA does not match the current package checkout.", call. = FALSE)
    }
  }

  beta_m <- .qdesn_vb_assert_vector(warm_start$qbeta$mean, p, "warm_start$qbeta$mean")
  beta_V <- as.matrix(warm_start$qbeta$cov)
  if (!all(dim(beta_V) == c(p, p)) || any(!is.finite(beta_V))) {
    stop("warm_start$qbeta$cov must be a finite p x p matrix.", call. = FALSE)
  }
  chol_ok <- tryCatch({ chol(0.5 * (beta_V + t(beta_V))); TRUE }, error = function(e) FALSE)
  if (!isTRUE(chol_ok)) stop("warm_start$qbeta$cov must be positive definite.", call. = FALSE)

  v_m <- .qdesn_vb_assert_vector(warm_start$qv$mean, n, "warm_start$qv$mean", positive = TRUE)
  v_inv <- .qdesn_vb_assert_vector(warm_start$qv$mean_inv, n, "warm_start$qv$mean_inv", positive = TRUE)
  s_m <- .qdesn_vb_assert_vector(warm_start$qs$mean, n, "warm_start$qs$mean", positive = TRUE)
  s_m2 <- .qdesn_vb_assert_vector(warm_start$qs$mean2, n, "warm_start$qs$mean2", positive = TRUE)

  qsig <- warm_start$qsiggam %||% list()
  gamma <- as.numeric(qsig$gamma_mean %||% NA_real_)[1L]
  sigma <- as.numeric(qsig$sigma_mean %||% NA_real_)[1L]
  siggam_Sigma <- as.matrix(qsig$Sigma)
  if (!is.finite(gamma)) stop("warm_start$qsiggam$gamma_mean must be finite.", call. = FALSE)
  if (!is.finite(sigma) || sigma <= 0) stop("warm_start$qsiggam$sigma_mean must be finite and > 0.", call. = FALSE)
  if (!all(dim(siggam_Sigma) == c(2L, 2L)) || any(!is.finite(siggam_Sigma))) {
    stop("warm_start$qsiggam$Sigma must be a finite 2 x 2 matrix.", call. = FALSE)
  }

  if (identical(likelihood_family, "al") && !is.null(al_fixed_gamma)) {
    state_gamma <- as.numeric(warm_start$likelihood$al_fixed_gamma %||% NA_real_)[1L]
    requested_gamma <- as.numeric(al_fixed_gamma)[1L]
    if (is.finite(state_gamma) && is.finite(requested_gamma) &&
        abs(state_gamma - requested_gamma) > 1e-10) {
      stop("warm start AL fixed-gamma value does not match the requested fit.", call. = FALSE)
    }
  }

  beta_state <- warm_start$beta_prior_state %||% warm_start$rhs %||% NULL
  if (prior_type %in% c("rhs", "rhs_ns")) {
    if (is.null(beta_state) || !is.list(beta_state)) {
      stop("warm start RHS/RHS_NS beta prior state is required.", call. = FALSE)
    }
    prec <- beta_prior_obj$expected_prec(beta_state, p)
    if (length(prec) != p || any(!is.finite(prec)) || any(prec <= 0)) {
      stop("warm start RHS/RHS_NS expected precision is invalid.", call. = FALSE)
    }
  } else if (!is.null(beta_state) && isTRUE(strict)) {
    prec <- beta_prior_obj$expected_prec(beta_state, p)
    if (length(prec) != p || any(!is.finite(prec)) || any(prec <= 0)) {
      stop("warm start beta prior state is invalid.", call. = FALSE)
    }
  }

  invisible(TRUE)
}

.qdesn_vb_warm_start_to_init <- function(warm_start, X, p0, likelihood_family,
                                         beta_prior_obj,
                                         al_fixed_gamma = NULL,
                                         validate_design_hash = TRUE,
                                         validate_package_sha = FALSE,
                                         strict = TRUE) {
  .qdesn_vb_validate_warm_start(
    warm_start = warm_start,
    X = X,
    p0 = p0,
    likelihood_family = likelihood_family,
    beta_prior_obj = beta_prior_obj,
    al_fixed_gamma = al_fixed_gamma,
    validate_design_hash = validate_design_hash,
    validate_package_sha = validate_package_sha,
    strict = strict
  )
  qsig <- warm_start$qsiggam %||% list()
  list(
    beta_m = as.numeric(warm_start$qbeta$mean),
    beta_V = as.matrix(warm_start$qbeta$cov),
    v_m = as.numeric(warm_start$qv$mean),
    v_inv = as.numeric(warm_start$qv$mean_inv),
    s_m = as.numeric(warm_start$qs$mean),
    s_m2 = as.numeric(warm_start$qs$mean2),
    gamma = as.numeric(qsig$gamma_mean)[1L],
    sigma = as.numeric(qsig$sigma_mean)[1L],
    siggam_Sigma = as.matrix(qsig$Sigma),
    beta_state = warm_start$beta_prior_state %||% warm_start$rhs %||% NULL,
    warm_start_meta = list(
      enabled = TRUE,
      version = as.character(warm_start$version %||% NA_character_),
      design_hash = as.character((warm_start$design %||% list())$design_hash %||% NA_character_),
      likelihood_family = as.character((warm_start$likelihood %||% list())$family %||% NA_character_),
      prior_family = as.character((warm_start$prior %||% list())$family %||% NA_character_)
    )
  )
}
