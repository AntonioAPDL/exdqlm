#' RQR oracle roots for centered innovation laws
#'
#' The RQR interval roots `(a_c, b_c)` are defined by the coverage and
#' first-moment balance equations
#' `F(b_c) - F(a_c) = c` and
#' `M(b_c) - M(a_c) = c * E(E)`, where
#' `M(z) = E[E 1(E <= z)]`.  The helper is intended for simulation design and
#' endpoint-recovery audits; it is not used as a fitted model.
#'
#' @param family Innovation family. Supported values are `"gaussian"`,
#'   `"laplace"`, `"student_t"`, `"centered_gamma"`,
#'   `"asymmetric_laplace"`, and `"gaussian_mixture"`.
#' @param coverage_level Target interval coverage in `(0, 1)`.
#' @param params Optional family parameters.
#' @param tol Numerical tolerance for the scalar root search.
#' @return A list with roots, coverage/moment residuals, and family metadata.
#' @export
rqr_oracle_roots <- function(family, coverage_level, params = list(), tol = 1e-8) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  family <- tolower(gsub("-", "_", as.character(family)[1L]))
  c0 <- as.numeric(coverage_level)[1L]
  if (!is.finite(c0) || c0 <= 0 || c0 >= 1) {
    stop("coverage_level must be a finite scalar in (0, 1).", call. = FALSE)
  }
  spec <- .rqr_oracle_family_spec(family, params %||% list())
  eps <- max(1e-7, tol)
  p_grid <- seq(eps, 1 - c0 - eps, length.out = 401L)
  balance_at <- function(pa) {
    a <- spec$q(pa)
    b <- spec$q(pa + c0)
    spec$M(b) - spec$M(a) - c0 * spec$mean
  }
  vals <- vapply(p_grid, balance_at, numeric(1))
  finite <- is.finite(vals)
  if (!any(finite)) {
    stop(sprintf("RQR oracle balance could not be evaluated for family '%s'.", family), call. = FALSE)
  }
  p_grid <- p_grid[finite]
  vals <- vals[finite]
  sign_change <- which(vals[-length(vals)] * vals[-1L] <= 0)
  if (length(sign_change)) {
    ii <- sign_change[[1L]]
    pa <- stats::uniroot(balance_at, c(p_grid[ii], p_grid[ii + 1L]), tol = tol)$root
    method <- "root"
  } else {
    opt <- stats::optimize(function(pa) abs(balance_at(pa)), c(eps, 1 - c0 - eps))
    pa <- opt$minimum
    method <- "minimum_abs_balance"
  }
  a <- spec$q(pa)
  b <- spec$q(pa + c0)
  cov_resid <- spec$F(b) - spec$F(a) - c0
  mom_resid <- spec$M(b) - spec$M(a) - c0 * spec$mean
  list(
    family = family,
    coverage_level = c0,
    lower_root = as.numeric(a),
    upper_root = as.numeric(b),
    lower_probability = as.numeric(pa),
    upper_probability = as.numeric(pa + c0),
    mean = as.numeric(spec$mean),
    coverage_residual = as.numeric(cov_resid),
    moment_residual = as.numeric(mom_resid),
    method = method,
    params = spec$params
  )
}

#' Location-scale RQR oracle endpoints
#'
#' @param mu,sigma Location and positive scale vectors.
#' @inheritParams rqr_oracle_roots
#' @return A data frame with lower, upper, midpoint, and width.
#' @export
rqr_oracle_endpoints <- function(mu, sigma = 1, family, coverage_level, params = list(), tol = 1e-8) {
  roots <- rqr_oracle_roots(family, coverage_level, params = params, tol = tol)
  mu <- as.numeric(mu)
  sigma <- as.numeric(sigma)
  if (length(sigma) == 1L) sigma <- rep(sigma, length(mu))
  if (length(mu) != length(sigma)) stop("mu and sigma must have compatible lengths.", call. = FALSE)
  if (any(!is.finite(mu)) || any(!is.finite(sigma)) || any(sigma <= 0)) {
    stop("mu must be finite and sigma must be finite and positive.", call. = FALSE)
  }
  lower <- mu + sigma * roots$lower_root
  upper <- mu + sigma * roots$upper_root
  data.frame(
    lower = lower,
    upper = upper,
    midpoint = 0.5 * (lower + upper),
    width = upper - lower,
    lower_root = roots$lower_root,
    upper_root = roots$upper_root
  )
}

.rqr_oracle_family_spec <- function(family, params) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  numeric_M <- function(d, lower, upper) {
    force(d)
    force(lower)
    function(z) {
      z <- as.numeric(z)
      vapply(z, function(zz) {
        if (!is.finite(zz) && zz < 0) return(0)
        if (zz <= lower) return(0)
        hi <- min(zz, upper)
        stats::integrate(
          function(x) x * d(x),
          lower = lower,
          upper = hi,
          rel.tol = 1e-9,
          subdivisions = 300L
        )$value
      }, numeric(1))
    }
  }
  if (family %in% c("gaussian", "normal")) {
    mu <- as.numeric(params$mean %||% 0)[1L]
    sd <- as.numeric(params$sd %||% 1)[1L]
    if (!is.finite(sd) || sd <= 0) stop("gaussian sd must be positive.", call. = FALSE)
    return(list(
      F = function(z) stats::pnorm(z, mean = mu, sd = sd),
      q = function(p) stats::qnorm(p, mean = mu, sd = sd),
      M = function(z) mu * stats::pnorm(z, mu, sd) - sd * stats::dnorm(z, mu, sd),
      mean = mu,
      params = list(mean = mu, sd = sd)
    ))
  }
  if (family == "student_t") {
    df <- as.numeric(params$df %||% 5)[1L]
    scale <- as.numeric(params$scale %||% 1)[1L]
    if (!is.finite(df) || df <= 1) stop("student_t df must exceed 1.", call. = FALSE)
    if (!is.finite(scale) || scale <= 0) stop("student_t scale must be positive.", call. = FALSE)
    d <- function(x) stats::dt(x / scale, df = df) / scale
    return(list(
      F = function(z) stats::pt(z / scale, df = df),
      q = function(p) scale * stats::qt(p, df = df),
      M = numeric_M(d, -Inf, Inf),
      mean = 0,
      params = list(df = df, scale = scale)
    ))
  }
  if (family == "laplace") {
    loc <- as.numeric(params$location %||% 0)[1L]
    scale <- as.numeric(params$scale %||% 1)[1L]
    if (!is.finite(scale) || scale <= 0) stop("laplace scale must be positive.", call. = FALSE)
    F <- function(z) ifelse(z < loc, 0.5 * exp((z - loc) / scale), 1 - 0.5 * exp(-(z - loc) / scale))
    q <- function(p) ifelse(p < 0.5, loc + scale * log(2 * p), loc - scale * log(2 * (1 - p)))
    d <- function(x) 0.5 / scale * exp(-abs(x - loc) / scale)
    return(list(F = F, q = q, M = numeric_M(d, -Inf, Inf), mean = loc, params = list(location = loc, scale = scale)))
  }
  if (family %in% c("centered_gamma", "centered_exponential")) {
    shape <- as.numeric(params$shape %||% if (family == "centered_exponential") 1 else 2)[1L]
    scale <- as.numeric(params$scale %||% 1)[1L]
    center <- shape * scale
    if (!is.finite(shape) || shape <= 0 || !is.finite(scale) || scale <= 0) {
      stop("centered_gamma shape and scale must be positive.", call. = FALSE)
    }
    F <- function(z) stats::pgamma(z + center, shape = shape, scale = scale)
    q <- function(p) stats::qgamma(p, shape = shape, scale = scale) - center
    d <- function(x) stats::dgamma(x + center, shape = shape, scale = scale)
    return(list(F = F, q = q, M = numeric_M(d, -center, Inf), mean = 0, params = list(shape = shape, scale = scale, center = center)))
  }
  if (family == "asymmetric_laplace") {
    tau <- as.numeric(params$tau %||% params$p %||% 0.25)[1L]
    scale <- as.numeric(params$scale %||% 1)[1L]
    if (!is.finite(tau) || tau <= 0 || tau >= 1 || !is.finite(scale) || scale <= 0) {
      stop("asymmetric_laplace tau must be in (0,1) and scale must be positive.", call. = FALSE)
    }
    raw_mean <- scale * (1 - 2 * tau) / (tau * (1 - tau))
    rho <- function(z) z * (tau - as.numeric(z < 0))
    d_raw <- function(z) tau * (1 - tau) / scale * exp(-rho(z / scale))
    F_raw <- function(z) ifelse(z < 0, tau * exp((1 - tau) * z / scale), 1 - (1 - tau) * exp(-tau * z / scale))
    q_raw <- function(p) ifelse(p < tau, scale * log(p / tau) / (1 - tau), -scale * log((1 - p) / (1 - tau)) / tau)
    d <- function(x) d_raw(x + raw_mean)
    return(list(
      F = function(z) F_raw(z + raw_mean),
      q = function(p) q_raw(p) - raw_mean,
      M = numeric_M(d, -Inf, Inf),
      mean = 0,
      params = list(tau = tau, scale = scale, center = raw_mean)
    ))
  }
  if (family == "gaussian_mixture") {
    weights <- as.numeric(params$weights %||% c(0.1, 0.9))
    means <- as.numeric(params$means %||% c(0, 1))
    sds <- as.numeric(params$sds %||% c(0.5, 1.5))
    if (length(weights) != length(means) || length(weights) != length(sds)) {
      stop("gaussian_mixture weights, means, and sds must have equal lengths.", call. = FALSE)
    }
    weights <- weights / sum(weights)
    if (any(!is.finite(weights)) || any(weights < 0) || any(!is.finite(sds)) || any(sds <= 0)) {
      stop("gaussian_mixture has invalid weights or standard deviations.", call. = FALSE)
    }
    raw_mean <- sum(weights * means)
    center <- if (isTRUE(params$center %||% TRUE)) raw_mean else 0
    F <- function(z) {
      z <- as.numeric(z)
      mat <- sapply(seq_along(weights), function(ii) weights[ii] * stats::pnorm(z + center, means[ii], sds[ii]))
      if (is.null(dim(mat))) mat <- matrix(mat, nrow = length(z))
      rowSums(mat)
    }
    d <- function(x) {
      x <- as.numeric(x)
      mat <- sapply(seq_along(weights), function(ii) weights[ii] * stats::dnorm(x + center, means[ii], sds[ii]))
      if (is.null(dim(mat))) mat <- matrix(mat, nrow = length(x))
      rowSums(mat)
    }
    q <- function(p) vapply(p, function(pp) {
      stats::uniroot(function(z) F(z) - pp, c(min(means - center - 12 * sds), max(means - center + 12 * sds)))$root
    }, numeric(1))
    return(list(
      F = F,
      q = q,
      M = numeric_M(d, -Inf, Inf),
      mean = raw_mean - center,
      params = list(weights = weights, means = means, sds = sds, center = center)
    ))
  }
  stop(sprintf("Unsupported RQR oracle family: %s", family), call. = FALSE)
}
