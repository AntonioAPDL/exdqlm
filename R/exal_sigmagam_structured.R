# Shared exAL scale-skewness helpers used by dynamic and static inference.

.exal_gamma_from_eta <- function(eta, L, U, eps = 1e-12) {
  s <- stats::plogis(as.numeric(eta))
  s <- pmin(pmax(s, eps), 1 - eps)
  L + (U - L) * s
}

.exal_eta_from_gamma <- function(gamma, L, U, eps = 1e-12) {
  u <- (as.numeric(gamma) - L) / (U - L)
  stats::qlogis(pmin(pmax(u, eps), 1 - eps))
}

.exal_log_gamma_jacobian_eta <- function(eta, L, U, eps = 1e-12) {
  s <- stats::plogis(as.numeric(eta))
  s <- pmin(pmax(s, eps), 1 - eps)
  log(pmax(U - L, eps)) + log(s) + log1p(-s)
}

.exal_sigmagam_stats <- function(sum_einv_quad, sum_t, sum_v, sum_s_einv_t,
                                 sum_s, sum_s2_einv, n, a_sigma, b_sigma) {
  out <- list(
    sum_einv_quad = as.numeric(sum_einv_quad)[1L],
    sum_t = as.numeric(sum_t)[1L],
    sum_v = as.numeric(sum_v)[1L],
    sum_s_einv_t = as.numeric(sum_s_einv_t)[1L],
    sum_s = as.numeric(sum_s)[1L],
    sum_s2_einv = as.numeric(sum_s2_einv)[1L],
    n = as.numeric(n)[1L],
    a_sigma = as.numeric(a_sigma)[1L],
    b_sigma = as.numeric(b_sigma)[1L]
  )
  bad <- !vapply(out, function(z) length(z) == 1L && is.finite(z), logical(1))
  if (any(bad)) {
    stop("Invalid exAL scale-skewness sufficient statistics.", call. = FALSE)
  }
  out
}

.exal_sigmagam_stats_from_vectors <- function(t_i, inv_v, v, s, s2 = s^2,
                                              theta_var = 0, a_sigma,
                                              b_sigma) {
  t_i <- as.numeric(t_i)
  inv_v <- as.numeric(inv_v)
  v <- as.numeric(v)
  s <- as.numeric(s)
  s2 <- as.numeric(s2)
  theta_var <- rep_len(as.numeric(theta_var), length(t_i))
  if (!all(is.finite(c(t_i, inv_v, v, s, s2, theta_var))) ||
      any(inv_v <= 0) || any(v <= 0) || length(t_i) < 1L) {
    stop("Invalid vectors for exAL scale-skewness sufficient statistics.", call. = FALSE)
  }
  .exal_sigmagam_stats(
    sum_einv_quad = sum(inv_v * (t_i^2 + pmax(theta_var, 0))),
    sum_t = sum(t_i),
    sum_v = sum(v),
    sum_s_einv_t = sum(s * inv_v * t_i),
    sum_s = sum(s),
    sum_s2_einv = sum(s2 * inv_v),
    n = length(t_i),
    a_sigma = a_sigma,
    b_sigma = b_sigma
  )
}

.exal_sigmagam_terms <- function(gamma, stats, p0) {
  gamma <- as.numeric(gamma)[1L]
  A <- A.fn(p0, gamma)
  B <- B.fn(p0, gamma)
  lambda <- C.fn(p0, gamma) * abs(gamma)
  if (!all(is.finite(c(A, B, lambda))) || B <= 0) {
    return(NULL)
  }
  quad <- stats$sum_einv_quad - 2 * A * stats$sum_t + (A * A) * stats$sum_v
  chi <- quad / B + 2 * (stats$sum_v + stats$b_sigma)
  psi <- (lambda * lambda / B) * stats$sum_s2_einv
  k <- -(stats$a_sigma + 1.5 * stats$n)
  cross <- (lambda / B) * (stats$sum_s_einv_t - A * stats$sum_s)
  if (!all(is.finite(c(chi, psi, k, cross))) || chi <= 0 || psi < 0) {
    return(NULL)
  }
  list(A = A, B = B, lambda = lambda, chi = chi, psi = psi, k = k, cross = cross)
}

.exal_gig_log_integral <- function(k, chi, psi, eps = 1e-12) {
  k <- as.numeric(k)[1L]
  chi <- as.numeric(chi)[1L]
  psi <- as.numeric(psi)[1L]
  if (!is.finite(k) || !is.finite(chi) || chi <= 0 || !is.finite(psi) || psi < 0) {
    return(-Inf)
  }
  if (psi <= eps) {
    if (k >= 0) return(-Inf)
    return(k * log(chi / 2) + lgamma(-k))
  }
  z <- sqrt(chi * psi)
  logK <- log(pmax(besselK(z, nu = k, expon.scaled = TRUE), 1e-300)) - z
  log(2) + 0.5 * k * (log(chi) - log(psi)) + logK
}

.exal_gig_moment <- function(k, chi, psi, r, eps = 1e-12) {
  k <- as.numeric(k)[1L]
  chi <- as.numeric(chi)[1L]
  psi <- as.numeric(psi)[1L]
  r <- as.numeric(r)[1L]
  if (!is.finite(k) || !is.finite(chi) || chi <= 0 ||
      !is.finite(psi) || psi < 0 || !is.finite(r)) {
    return(NA_real_)
  }
  if (psi <= eps) {
    alpha <- -k
    if (alpha <= r) return(NA_real_)
    return(exp(r * log(chi / 2) + lgamma(alpha - r) - lgamma(alpha)))
  }
  z <- sqrt(chi * psi)
  log_num <- log(pmax(besselK(z, nu = k + r, expon.scaled = TRUE), 1e-300))
  log_den <- log(pmax(besselK(z, nu = k, expon.scaled = TRUE), 1e-300))
  exp(0.5 * r * (log(chi) - log(psi)) + log_num - log_den)
}

.exal_gig_elog <- function(k, chi, psi, eps = 1e-12) {
  k <- as.numeric(k)[1L]
  chi <- as.numeric(chi)[1L]
  psi <- as.numeric(psi)[1L]
  if (!is.finite(k) || !is.finite(chi) || chi <= 0 || !is.finite(psi) || psi < 0) {
    return(NA_real_)
  }
  if (psi <= eps) {
    alpha <- -k
    if (alpha <= 0) return(NA_real_)
    return(log(chi / 2) - digamma(alpha))
  }
  z <- sqrt(chi * psi)
  h <- 1e-5
  logK <- function(nu) {
    log(pmax(besselK(z, nu = nu, expon.scaled = TRUE), 1e-300)) - z
  }
  0.5 * (log(chi) - log(psi)) + (logK(k + h) - logK(k - h)) / (2 * h)
}

.exal_gig_varlog <- function(k, chi, psi, eps = 1e-12) {
  k <- as.numeric(k)[1L]
  chi <- as.numeric(chi)[1L]
  psi <- as.numeric(psi)[1L]
  if (!is.finite(k) || !is.finite(chi) || chi <= 0 || !is.finite(psi) || psi < 0) {
    return(NA_real_)
  }
  if (psi <= eps) {
    alpha <- -k
    if (alpha <= 0) return(NA_real_)
    return(psigamma(alpha, deriv = 1L))
  }
  z <- sqrt(chi * psi)
  h <- 1e-4
  logK <- function(nu) {
    log(pmax(besselK(z, nu = nu, expon.scaled = TRUE), 1e-300)) - z
  }
  out <- (logK(k + h) - 2 * logK(k) + logK(k - h)) / (h^2)
  if (is.finite(out) && out >= 0) out else NA_real_
}

.exal_gig_entropy_one <- function(k, chi, psi, E_inv, E_x, E_log, eps = 1e-12) {
  logZ <- .exal_gig_log_integral(k, chi, psi, eps = eps)
  if (!all(is.finite(c(logZ, E_inv, E_x, E_log)))) return(NA_real_)
  logZ - (k - 1) * E_log + 0.5 * (chi * E_inv + psi * E_x)
}

.exal_sigmagam_collapsed_log_gamma <- function(gamma, stats, p0, bounds,
                                               log_prior_gamma) {
  gamma <- as.numeric(gamma)[1L]
  L <- as.numeric(bounds[1L])
  U <- as.numeric(bounds[2L])
  if (!is.finite(gamma) || gamma <= L || gamma >= U) return(-Inf)
  terms <- .exal_sigmagam_terms(gamma, stats, p0)
  if (is.null(terms)) return(-Inf)
  lp <- log_prior_gamma(gamma)
  logZ <- .exal_gig_log_integral(terms$k, terms$chi, terms$psi)
  if (!is.finite(lp) || !is.finite(logZ)) return(-Inf)
  lp - 0.5 * stats$n * log(terms$B) + terms$cross + logZ
}

.exal_sigmagam_collapsed_log_eta <- function(eta, stats, p0, bounds,
                                             log_prior_gamma, eps = 1e-12) {
  L <- as.numeric(bounds[1L])
  U <- as.numeric(bounds[2L])
  gamma <- .exal_gamma_from_eta(eta, L, U, eps = eps)
  .exal_sigmagam_collapsed_log_gamma(gamma, stats, p0, bounds, log_prior_gamma) +
    .exal_log_gamma_jacobian_eta(eta, L, U, eps = eps)
}

.exal_sigmagam_sample_sigma_collapsed <- function(gamma, stats, p0,
                                                  fallback = NA_real_,
                                                  context = "exal_sigmagam_sigma") {
  terms <- .exal_sigmagam_terms(gamma, stats, p0)
  if (is.null(terms)) return(fallback)
  if (terms$psi <= 1e-12) {
    if (terms$k >= 0) return(fallback)
    draw <- 1 / stats::rgamma(1L, shape = -terms$k, rate = terms$chi / 2)
  } else {
    draw <- .sample_gig_devroye_required(
      1L, p = terms$k, a = terms$psi, b_vec = terms$chi, context = context
    )[1L, 1L]
  }
  if (is.finite(draw) && draw > 0) as.numeric(draw)[1L] else fallback
}

.exal_sigmagam_structured_update <- function(stats, p0, bounds, PriorSigma,
                                             log_prior_gamma, eta_start = 0,
                                             eta_lo = -12, eta_hi = 12,
                                             logit_eps = 1e-8,
                                             grid_size = 61L,
                                             span_sd = 6,
                                             min_sd = 0.05,
                                             max_sd = 3) {
  L <- as.numeric(bounds[1L])
  U <- as.numeric(bounds[2L])
  grid_size <- suppressWarnings(as.integer(grid_size)[1L])
  if (!is.finite(grid_size) || grid_size < 21L) grid_size <- 61L
  if (grid_size %% 2L == 0L) grid_size <- grid_size + 1L
  span_sd <- as.numeric(span_sd)[1L]
  if (!is.finite(span_sd) || span_sd <= 0) span_sd <- 6
  min_sd <- as.numeric(min_sd)[1L]
  if (!is.finite(min_sd) || min_sd <= 0) min_sd <- 0.05
  max_sd <- as.numeric(max_sd)[1L]
  if (!is.finite(max_sd) || max_sd < min_sd) max_sd <- max(3, min_sd)

  log_eta <- function(e) .exal_sigmagam_collapsed_log_eta(
    e, stats = stats, p0 = p0, bounds = c(L, U),
    log_prior_gamma = log_prior_gamma, eps = logit_eps
  )

  coarse <- seq(eta_lo, eta_hi, length.out = 81L)
  coarse_vals <- vapply(coarse, log_eta, numeric(1L))
  finite_idx <- which(is.finite(coarse_vals))
  start <- if (length(finite_idx)) coarse[finite_idx[which.max(coarse_vals[finite_idx])]] else eta_start
  start <- min(max(as.numeric(start)[1L], eta_lo), eta_hi)

  opt <- try(
    stats::optim(
      par = start,
      fn = function(e) {
        val <- log_eta(e)
        if (is.finite(val)) -val else 1e50
      },
      method = "L-BFGS-B",
      lower = eta_lo,
      upper = eta_hi,
      control = list(maxit = 500L)
    ),
    silent = TRUE
  )
  if (inherits(opt, "try-error") || !is.finite(opt$value)) {
    eta_mode <- start
    opt_conv <- 1L
    opt_fallback <- TRUE
  } else {
    eta_mode <- as.numeric(opt$par)[1L]
    opt_conv <- as.integer(opt$convergence)[1L]
    opt_fallback <- !identical(opt_conv, 0L)
  }

  h <- max(1e-4 * (1 + abs(eta_mode)), 1e-5)
  l0 <- log_eta(eta_mode)
  lp <- log_eta(min(eta_mode + h, eta_hi))
  lm <- log_eta(max(eta_mode - h, eta_lo))
  curv <- -(lp - 2 * l0 + lm) / (h^2)
  sd_eta <- if (is.finite(curv) && curv > 1e-8) sqrt(1 / curv) else 1
  sd_eta <- min(max(sd_eta, min_sd), max_sd)
  lo <- max(eta_lo, eta_mode - span_sd * sd_eta)
  hi <- min(eta_hi, eta_mode + span_sd * sd_eta)
  eta_grid <- seq(lo, hi, length.out = grid_size)
  logw <- vapply(eta_grid, log_eta, numeric(1L))
  if (!any(is.finite(logw))) {
    eta_grid <- coarse
    logw <- coarse_vals
  }
  finite <- is.finite(logw)
  eta_grid <- eta_grid[finite]
  logw <- logw[finite]
  if (!length(logw)) stop("Structured exAL scale-skewness update has no finite gamma grid.", call. = FALSE)

  normalize_eta_grid <- function(logw_vals, eta_vals) {
    if (!length(logw_vals) || !length(eta_vals)) {
      stop("Structured exAL scale-skewness update has an empty gamma grid.", call. = FALSE)
    }
    step <- if (length(eta_vals) > 1L) mean(diff(eta_vals)) else 1
    logw_cont <- logw_vals + log(abs(step))
    max_logw <- max(logw_cont)
    w_raw <- exp(logw_cont - max_logw)
    w_sum <- sum(w_raw)
    if (!is.finite(w_sum) || w_sum <= 0) {
      stop("Structured exAL scale-skewness update has invalid gamma weights.", call. = FALSE)
    }
    list(
      weights = w_raw / w_sum,
      logZ_eta = max_logw + log(w_sum)
    )
  }

  norm <- normalize_eta_grid(logw, eta_grid)
  weights <- norm$weights
  logZ_eta <- norm$logZ_eta

  gamma_grid <- .exal_gamma_from_eta(eta_grid, L, U, eps = logit_eps)
  term_list <- lapply(gamma_grid, .exal_sigmagam_terms, stats = stats, p0 = p0)
  keep <- vapply(term_list, Negate(is.null), logical(1L))
  eta_grid <- eta_grid[keep]
  logw <- logw[keep]
  gamma_grid <- gamma_grid[keep]
  term_list <- term_list[keep]
  if (!length(term_list)) {
    stop("Structured exAL scale-skewness update has no valid conditional scale kernels.", call. = FALSE)
  }
  norm <- normalize_eta_grid(logw, eta_grid)
  weights <- norm$weights
  logZ_eta <- norm$logZ_eta

  A <- vapply(term_list, `[[`, numeric(1L), "A")
  B <- vapply(term_list, `[[`, numeric(1L), "B")
  lambda <- vapply(term_list, `[[`, numeric(1L), "lambda")
  chi <- vapply(term_list, `[[`, numeric(1L), "chi")
  psi <- vapply(term_list, `[[`, numeric(1L), "psi")
  k <- vapply(term_list, `[[`, numeric(1L), "k")

  Esigma <- mapply(.exal_gig_moment, k, chi, psi, MoreArgs = list(r = 1))
  Einvsigma <- mapply(.exal_gig_moment, k, chi, psi, MoreArgs = list(r = -1))
  Esigma2 <- mapply(.exal_gig_moment, k, chi, psi, MoreArgs = list(r = 2))
  Elogsigma <- mapply(.exal_gig_elog, k, chi, psi)
  Vlogsigma <- mapply(.exal_gig_varlog, k, chi, psi)
  Hsigma <- mapply(.exal_gig_entropy_one, k, chi, psi, Einvsigma, Esigma, Elogsigma)
  valid_mom <- is.finite(Esigma) & Esigma > 0 & is.finite(Einvsigma) & Einvsigma > 0 &
    is.finite(Elogsigma)
  if (!all(valid_mom)) {
    eta_grid <- eta_grid[valid_mom]
    logw <- logw[valid_mom]
    gamma_grid <- gamma_grid[valid_mom]
    A <- A[valid_mom]
    B <- B[valid_mom]
    lambda <- lambda[valid_mom]
    chi <- chi[valid_mom]
    psi <- psi[valid_mom]
    k <- k[valid_mom]
    Esigma <- Esigma[valid_mom]
    Einvsigma <- Einvsigma[valid_mom]
    Esigma2 <- Esigma2[valid_mom]
    Elogsigma <- Elogsigma[valid_mom]
    Vlogsigma <- Vlogsigma[valid_mom]
    Hsigma <- Hsigma[valid_mom]
    norm <- normalize_eta_grid(logw, eta_grid)
    weights <- norm$weights
    logZ_eta <- norm$logZ_eta
  }
  if (!length(weights)) stop("Structured exAL scale-skewness update has no finite moments.", call. = FALSE)

  wsum <- function(x) sum(weights * as.numeric(x))
  E_eta <- wsum(eta_grid)
  E_gamma <- wsum(gamma_grid)
  E_sigma <- wsum(Esigma)
  E_inv_sigma <- wsum(Einvsigma)
  E_log_sigma <- wsum(Elogsigma)
  V_gamma <- wsum((gamma_grid - E_gamma)^2)
  V_sigma <- wsum(pmax(Esigma2, 0)) - E_sigma^2
  E_log_j_gamma <- wsum(.exal_log_gamma_jacobian_eta(eta_grid, L, U, eps = logit_eps))
  H_eta <- logZ_eta - wsum(logw)
  H_qsg <- H_eta + E_log_j_gamma + wsum(Hsigma)
  V_log_sigma <- wsum(pmax(Vlogsigma, 0) + (Elogsigma - E_log_sigma)^2)
  Cov_eta_log_sigma <- wsum((eta_grid - E_eta) * (Elogsigma - E_log_sigma))
  Sigma_eta_ell <- matrix(
    c(
      max(wsum((eta_grid - E_eta)^2), 1e-10),
      Cov_eta_log_sigma,
      Cov_eta_log_sigma,
      max(V_log_sigma, 1e-10)
    ),
    nrow = 2L
  )
  Sigma_eta_ell <- .exal_static_ld_regularize_cov(Sigma_eta_ell, eig_floor = 1e-10, eig_cap = 1e4)$Sigma

  E_prior_sig <- PriorSigma$a_sig * log(PriorSigma$b_sig) - lgamma(PriorSigma$a_sig) -
    (PriorSigma$a_sig + 1) * E_log_sigma - PriorSigma$b_sig * E_inv_sigma
  E_prior_gam <- wsum(vapply(gamma_grid, log_prior_gamma, numeric(1L)))
  E_log_B <- wsum(log(B))

  grid <- data.frame(
    eta = eta_grid,
    gamma = gamma_grid,
    weight = weights,
    A = A,
    B = B,
    lambda = lambda,
    chi = chi,
    psi = psi,
    k = k,
    E_sigma = Esigma,
    E_inv_sigma = Einvsigma,
    E_log_sigma = Elogsigma
  )

  list(
    E.sigma = as.numeric(E_sigma),
    E.inv.sigma = as.numeric(E_inv_sigma),
    E.gam = as.numeric(E_gamma),
    E.c2.invb.absgam2.sigma = as.numeric(wsum((lambda * lambda / B) * Esigma)),
    E.c.invb.absgam = as.numeric(wsum(lambda / B)),
    E.c.a.invb.absgam = as.numeric(wsum(lambda * A / B)),
    E.a2.invb.inv.sigma = as.numeric(wsum((A * A / B) * Einvsigma)),
    E.invb.inv.sigma = as.numeric(wsum((1 / B) * Einvsigma)),
    E.a.invb.inv.sigma = as.numeric(wsum((A / B) * Einvsigma)),
    Hess.LD = Sigma_eta_ell,
    E.log.sig.b = as.numeric(wsum(Elogsigma + log(B))),
    E.log.sig = as.numeric(E_log_sigma),
    E.prior.sig.gam = as.numeric(E_prior_sig + E_prior_gam),
    E.log.prior.sigma = as.numeric(E_prior_sig),
    E.log.prior.gamma = as.numeric(E_prior_gam),
    E.log.B = as.numeric(E_log_B),
    E.theta = c(eta = as.numeric(E_eta), ell = as.numeric(E_log_sigma)),
    entrop = as.numeric(H_qsg),
    V.gam = as.numeric(max(V_gamma, 0)),
    V.sigma = as.numeric(max(V_sigma, 0)),
    E.log.inv.sigma = -as.numeric(E_log_sigma),
    elbo_logZ = as.numeric(logZ_eta),
    factorization = "structured_qgamma_qsigma_given_gamma",
    xi = list(
      xi1 = as.numeric(wsum((1 / B) * Einvsigma)),
      xi_lambda = as.numeric(wsum(lambda / B)),
      xi_lambda2 = as.numeric(wsum((lambda * lambda / B) * Esigma)),
      xi_A = as.numeric(wsum((A / B) * Einvsigma)),
      xi_A2 = as.numeric(wsum((A * A / B) * Einvsigma)),
      zeta_lam = as.numeric(wsum(lambda * A / B)),
      zeta_logB = as.numeric(E_log_B),
      zeta_logpi = as.numeric(E_prior_gam),
      xi_siginv = as.numeric(E_inv_sigma),
      zeta_logsigma = as.numeric(E_log_sigma),
      zeta_logJ = as.numeric(E_log_j_gamma + E_log_sigma)
    ),
    structured = list(
      eta_mode = as.numeric(eta_mode),
      eta_mean = as.numeric(E_eta),
      eta_sd = sqrt(max(Sigma_eta_ell[1, 1], 0)),
      logZ_eta = as.numeric(logZ_eta),
      grid = grid,
      grid_size = nrow(grid),
      optimizer_convergence = opt_conv,
      used_fallback = isTRUE(opt_fallback),
      sigma_conditional = "GIG",
      gamma_transform = "bounded_logit"
    )
  )
}

.exal_sigmagam_structured_sample <- function(qsiggam, n_samp,
                                             context = "structured_sigmagam") {
  ns <- suppressWarnings(as.integer(n_samp)[1L])
  if (!is.finite(ns) || ns < 1L) return(NULL)
  grid <- qsiggam$structured$grid
  if (is.null(grid) || !nrow(grid)) {
    stop(sprintf("%s cannot sample without a structured gamma grid.", context), call. = FALSE)
  }
  weights <- as.numeric(grid$weight)
  weights[!is.finite(weights) | weights < 0] <- 0
  if (!sum(weights)) stop(sprintf("%s has invalid structured weights.", context), call. = FALSE)
  weights <- weights / sum(weights)
  idx <- sample.int(nrow(grid), size = ns, replace = TRUE, prob = weights)
  sigma <- numeric(ns)
  for (i in seq_len(ns)) {
    row <- grid[idx[i], , drop = FALSE]
    if (row$psi <= 1e-12) {
      sigma[i] <- 1 / stats::rgamma(1L, shape = -row$k, rate = row$chi / 2)
    } else {
      sigma[i] <- .sample_gig_devroye_required(
        1L, p = row$k, a = row$psi, b_vec = row$chi, context = context
      )[1L, 1L]
    }
  }
  list(
    sigma = sigma,
    gamma = as.numeric(grid$gamma[idx])
  )
}
