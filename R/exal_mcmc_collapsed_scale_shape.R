#' Collapsed exAL scale-shape helpers for MCMC
#'
#' Internal implementation of the exact posterior-preserving M0 update used by
#' the independent Q-DESN validation campaign. The update integrates sigma out
#' of the gamma target, samples gamma on its native-support logit coordinate,
#' and redraws sigma from its exact GIG conditional.
#'
#' @keywords internal
.exal_mcmc_gig_log_mode_one <- function(lambda, chi, psi) {
  root <- sqrt(lambda * lambda + chi * psi)
  mode <- if (lambda >= 0) {
    log((lambda + root) / psi)
  } else {
    log(chi / (root - lambda))
  }
  if (!is.finite(mode)) mode <- 0.5 * (log(chi) - log(psi))
  if (!is.finite(mode)) .stopf("Could not compute the GIG log-kernel mode.")
  mode
}

#' @keywords internal
.exal_mcmc_gig_log_kernel_u <- function(u, lambda, chi, psi) {
  log_max <- log(.Machine$double.xmax)
  log_min <- log(.Machine$double.xmin)
  log_chi <- log(chi) - u
  log_psi <- log(psi) + u
  chi_term <- ifelse(log_chi > log_max, Inf, ifelse(log_chi < log_min, 0, exp(log_chi)))
  psi_term <- ifelse(log_psi > log_max, Inf, ifelse(log_psi < log_min, 0, exp(log_psi)))
  out <- lambda * u - 0.5 * (chi_term + psi_term)
  out[!is.finite(chi_term) | !is.finite(psi_term)] <- -Inf
  out
}

#' @keywords internal
.exal_mcmc_gig_log_integral_numeric_one <- function(lambda, chi, psi) {
  mode <- .exal_mcmc_gig_log_mode_one(lambda, chi, psi)
  f_mode <- .exal_mcmc_gig_log_kernel_u(mode, lambda, chi, psi)
  if (!is.finite(f_mode)) return(NA_real_)
  curvature <- 0.5 * (
    exp(pmin(log(chi) - mode, log(.Machine$double.xmax))) +
      exp(pmin(log(psi) + mode, log(.Machine$double.xmax)))
  )
  scale <- 1 / sqrt(pmax(curvature, .Machine$double.eps))
  scale <- pmin(pmax(scale, 1e-8), 50)
  integrand <- function(t) {
    u <- mode + scale * t
    log_val <- .exal_mcmc_gig_log_kernel_u(u, lambda, chi, psi) - f_mode
    out <- scale * exp(pmin(log_val, 0))
    out[!is.finite(out)] <- 0
    out
  }
  val <- stats::integrate(
    integrand,
    lower = -80,
    upper = 80,
    subdivisions = 500L,
    rel.tol = 1e-10,
    stop.on.error = FALSE
  )
  if (!is.finite(val$value) || val$value <= 0) return(NA_real_)
  f_mode + log(val$value)
}

#' @keywords internal
.exal_mcmc_log_bessel_k <- function(nu, z) {
  n <- max(length(nu), length(z))
  order <- rep(abs(as.numeric(nu)), length.out = n)
  z <- rep(as.numeric(z), length.out = n)
  if (any(!is.finite(order)) || any(!is.finite(z) | z <= 0)) {
    .stopf("Stable log-Bessel inputs must be finite with z > 0.")
  }
  scaled <- suppressWarnings(besselK(z, nu = order, expon.scaled = TRUE))
  out <- log(scaled) - z
  bad <- !is.finite(out)
  if (any(bad)) {
    a <- order[bad]
    x <- z[bad] / a
    root <- sqrt(1 + x * x)
    eta <- root + log(x) - log1p(root)
    t <- 1 / root
    u1 <- (3 * t - 5 * t^3) / 24
    u2 <- (81 * t^2 - 462 * t^4 + 385 * t^6) / 1152
    u3 <- (
      30375 * t^3 - 369603 * t^5 + 765765 * t^7 - 425425 * t^9
    ) / 414720
    series <- 1 - u1 / a + u2 / a^2 - u3 / a^3
    expansion_ok <- is.finite(a) & a > 0 & is.finite(series) & series > 0
    if (any(expansion_ok)) {
      idx <- which(bad)[expansion_ok]
      aa <- a[expansion_ok]
      xx <- x[expansion_ok]
      out[idx] <- 0.5 * (log(pi) - log(2 * aa)) -
        0.25 * log1p(xx * xx) - aa * eta[expansion_ok] +
        log(series[expansion_ok])
    }
  }
  out
}

#' @keywords internal
.exal_mcmc_gig_log_integral <- function(lambda, chi, psi) {
  n <- max(length(lambda), length(chi), length(psi))
  lambda <- rep(as.numeric(lambda), length.out = n)
  chi <- pmin(pmax(rep(as.numeric(chi), length.out = n), .Machine$double.eps), 1e100)
  psi <- pmin(pmax(rep(as.numeric(psi), length.out = n), .Machine$double.eps), 1e100)
  if (any(!is.finite(lambda)) || any(!is.finite(chi)) || any(!is.finite(psi))) {
    .stopf("GIG log-integral parameters must be finite.")
  }
  z <- sqrt(chi * psi)
  out <- log(2) + .exal_mcmc_log_bessel_k(lambda, z) +
    0.5 * lambda * (log(chi) - log(psi))
  bad <- which(!is.finite(out))
  if (length(bad)) {
    for (ii in bad) {
      out[[ii]] <- .exal_mcmc_gig_log_integral_numeric_one(
        lambda[[ii]], chi[[ii]], psi[[ii]]
      )
    }
  }
  if (any(!is.finite(out))) .stopf("Could not compute the GIG log normalizing integral.")
  out
}

#' @keywords internal
.exal_mcmc_collapsed_sufficient_stats <- function(y, fitted, s, v) {
  r <- as.numeric(y) - as.numeric(fitted)
  s <- as.numeric(s)
  v <- as.numeric(v)
  if (!(length(r) == length(s) && length(r) == length(v)) ||
      any(!is.finite(r)) || any(!is.finite(s)) ||
      any(!is.finite(v)) || any(v <= 0)) {
    .stopf("Collapsed gamma-scale statistics require conformable finite inputs and positive v.")
  }
  list(
    n = length(r),
    sum_v = sum(v),
    sum_log_v = sum(log(v)),
    sum_r = sum(r),
    sum_r2_over_v = sum(r * r / v),
    sum_s = sum(s),
    sum_s2_over_v = sum(s * s / v),
    sum_sr_over_v = sum(s * r / v)
  )
}

#' @keywords internal
.exal_mcmc_collapsed_gig_terms <- function(gamma, stats, A, B, Cabs,
                                            a_sigma = 1, b_sigma = 1) {
  if (!is.finite(gamma) || !is.finite(A) || !is.finite(B) || B <= 0 ||
      !is.finite(Cabs) || !is.finite(a_sigma) || a_sigma <= 0 ||
      !is.finite(b_sigma) || b_sigma <= 0) {
    return(NULL)
  }
  weighted_residual_ss <- stats$sum_r2_over_v -
    2 * A * stats$sum_r + A * A * stats$sum_v
  out <- list(
    lambda = -a_sigma - 1.5 * stats$n,
    chi = 2 * b_sigma + 2 * stats$sum_v + weighted_residual_ss / B,
    psi = Cabs * Cabs * stats$sum_s2_over_v / B,
    log_Bv_sum = stats$n * log(B) + stats$sum_log_v,
    cross_term = Cabs / B * (stats$sum_sr_over_v - A * stats$sum_s)
  )
  if (!is.finite(out$lambda) || !is.finite(out$chi) || out$chi <= 0 ||
      !is.finite(out$psi) || out$psi < 0 || !is.finite(out$cross_term)) {
    return(NULL)
  }
  out$psi <- max(out$psi, .Machine$double.eps)
  out
}

#' @keywords internal
.exal_mcmc_gamma_collapsed_log_kernel <- function(
    gamma, stats, A, B, Cabs, a_sigma = 1, b_sigma = 1,
    log_prior_gamma = function(g) 0) {
  terms <- .exal_mcmc_collapsed_gig_terms(
    gamma = gamma,
    stats = stats,
    A = A,
    B = B,
    Cabs = Cabs,
    a_sigma = a_sigma,
    b_sigma = b_sigma
  )
  if (is.null(terms)) return(-Inf)
  prior <- as.numeric(log_prior_gamma(gamma))[1L]
  if (!is.finite(prior)) return(-Inf)
  out <- -0.5 * terms$log_Bv_sum + terms$cross_term + prior +
    .exal_mcmc_gig_log_integral(terms$lambda, terms$chi, terms$psi)
  if (is.finite(out)) as.numeric(out)[1L] else -Inf
}

#' @keywords internal
.exal_mcmc_sigma_gamma_log_kernel <- function(
    sigma, gamma, stats, A, B, Cabs, a_sigma = 1, b_sigma = 1,
    log_prior_gamma = function(g) 0) {
  if (!is.finite(sigma) || sigma <= 0) return(-Inf)
  terms <- .exal_mcmc_collapsed_gig_terms(
    gamma = gamma,
    stats = stats,
    A = A,
    B = B,
    Cabs = Cabs,
    a_sigma = a_sigma,
    b_sigma = b_sigma
  )
  if (is.null(terms)) return(-Inf)
  prior <- as.numeric(log_prior_gamma(gamma))[1L]
  if (!is.finite(prior)) return(-Inf)
  -0.5 * terms$log_Bv_sum + terms$cross_term + prior +
    (terms$lambda - 1) * log(sigma) -
    0.5 * (terms$chi / sigma + terms$psi * sigma)
}

#' @keywords internal
.exal_mcmc_collapsed_scale_shape_draw <- function(
    sigma, eta_gamma, y, fitted, s, v, lower, upper,
    A_of, B_of, Cabs_of, log_prior_gamma,
    a_sigma = 1, b_sigma = 1,
    width = 1, max_steps_out = 100L, max_shrink = 1000L) {
  if (!is.finite(lower) || !is.finite(upper) || lower >= upper) {
    .stopf("M0 requires finite ordered gamma support bounds.")
  }
  stats <- .exal_mcmc_collapsed_sufficient_stats(y, fitted, s, v)
  g_from_eta <- function(eta) {
    p <- pmin(pmax(stats::plogis(eta), 1e-12), 1 - 1e-12)
    lower + (upper - lower) * p
  }
  eta_from_g <- function(gamma) {
    p <- pmin(pmax((gamma - lower) / (upper - lower), 1e-12), 1 - 1e-12)
    stats::qlogis(p)
  }
  log_jacobian <- function(eta) {
    p <- pmin(pmax(stats::plogis(eta), 1e-12), 1 - 1e-12)
    log(upper - lower) + log(p) + log1p(-p)
  }
  margin <- max(1e-8, 1e-8 * (upper - lower))
  eta_lower <- eta_from_g(lower + margin)
  eta_upper <- eta_from_g(upper - margin)
  density_evaluations <- 0L
  eta_log_density <- function(eta) {
    density_evaluations <<- density_evaluations + 1L
    gamma <- g_from_eta(eta)
    A <- as.numeric(A_of(gamma))[1L]
    B <- as.numeric(B_of(gamma))[1L]
    Cabs <- as.numeric(Cabs_of(gamma))[1L]
    .exal_mcmc_gamma_collapsed_log_kernel(
      gamma = gamma,
      stats = stats,
      A = A,
      B = B,
      Cabs = Cabs,
      a_sigma = a_sigma,
      b_sigma = b_sigma,
      log_prior_gamma = log_prior_gamma
    ) + log_jacobian(eta)
  }
  slice <- .exal_mcmc_slice_sample_1d(
    x0 = eta_gamma,
    logf = eta_log_density,
    width = width,
    max_steps_out = max_steps_out,
    max_shrink = max_shrink,
    lower = eta_lower,
    upper = eta_upper
  )
  gamma <- g_from_eta(slice$x)
  A <- as.numeric(A_of(gamma))[1L]
  B <- as.numeric(B_of(gamma))[1L]
  Cabs <- as.numeric(Cabs_of(gamma))[1L]
  terms <- .exal_mcmc_collapsed_gig_terms(
    gamma = gamma,
    stats = stats,
    A = A,
    B = B,
    Cabs = Cabs,
    a_sigma = a_sigma,
    b_sigma = b_sigma
  )
  if (is.null(terms)) .stopf("M0 produced invalid GIG terms after the gamma draw.")
  sigma <- as.numeric(.sample_gig_devroye_required(
    1L,
    p = terms$lambda,
    a = terms$psi,
    b_vec = terms$chi,
    context = "exal_mcmc_fit::m0_collapsed_scale_shape"
  )[1L, 1L])
  if (!is.finite(sigma) || sigma <= 0) .stopf("M0 produced an invalid sigma draw.")
  list(
    sigma = sigma,
    eta_sigma = log(sigma),
    gamma = gamma,
    eta_gamma = slice$x,
    gamma_steps_out = as.integer(slice$n_steps_out),
    gamma_shrink = as.integer(slice$n_shrink),
    gamma_density_evaluations = as.integer(density_evaluations),
    gig_lambda = terms$lambda,
    gig_chi = terms$chi,
    gig_psi = terms$psi
  )
}
