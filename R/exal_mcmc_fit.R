#' Fit exAL readout with MCMC and pluggable beta prior
#'
#' This is the MCMC counterpart to [exal_ldvb_fit()]. The initial implementation
#' supports the ridge beta prior and uses slice sampling for the nonconjugate
#' `gamma` block on a transformed coordinate. Closed-form Gibbs updates are used
#' for `beta`, `v`, `s`, and `sigma`.
#'
#' @export
exal_mcmc_fit <- function(y, X, p0, gamma_bounds,
                          mcmc_control = NULL,
                          n_burn = NULL, n_mcmc = NULL, thin = NULL,
                          verbose = NULL,
                          init = list(),
                          prior_gamma = NULL,
                          prior_gamma_mu0 = NULL,
                          prior_gamma_s20 = NULL,
                          log_prior_gamma = NULL,
                          prior_sigma = NULL,
                          a_sigma = NULL,
                          b_sigma = NULL,
                          beta_prior_obj = NULL,
                          ...) {

  `%||%` <- function(a, b) if (is.null(a)) b else a

  assert_matrix(X, "X")
  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")

  if (!is.numeric(gamma_bounds) || length(gamma_bounds) != 2L) {
    .stopf("gamma_bounds must be a numeric vector of length 2.")
  }
  gamma_bounds <- as.numeric(gamma_bounds)
  if (!all(is.finite(gamma_bounds)) || gamma_bounds[1] >= gamma_bounds[2]) {
    .stopf("gamma_bounds must be finite with lower < upper.")
  }
  if (!is.list(init)) .stopf("init must be a list.")

  if (is.null(mcmc_control)) mcmc_control <- list()
  if (!is.list(mcmc_control)) .stopf("mcmc_control must be a list.")
  if (!is.null(n_burn))  mcmc_control$n_burn  <- as.integer(n_burn)[1L]
  if (!is.null(n_mcmc))  mcmc_control$n_mcmc  <- as.integer(n_mcmc)[1L]
  if (!is.null(thin))    mcmc_control$thin    <- as.integer(thin)[1L]
  if (!is.null(verbose)) mcmc_control$verbose <- isTRUE(verbose)

  n_burn <- max(0L, as.integer(mcmc_control$n_burn %||% 2000L))
  n_keep <- max(1L, as.integer(mcmc_control$n_mcmc %||% 1500L))
  thin <- max(1L, as.integer(mcmc_control$thin %||% 1L))
  verbose <- isTRUE(mcmc_control$verbose %||% FALSE)
  init_from_vb <- isTRUE(mcmc_control$init_from_vb %||% FALSE)
  store_latent_draws <- isTRUE(mcmc_control$store_latent_draws %||% FALSE)

  slice_cfg <- mcmc_control$slice %||% list()
  gamma_slice_width <- as.numeric(slice_cfg$width_gamma %||% 1.0)
  gamma_slice_max_steps_out <- as.integer(slice_cfg$max_steps_out %||% 100L)
  gamma_slice_max_shrink <- as.integer(slice_cfg$max_shrink %||% 1000L)

  if (!is.finite(gamma_slice_width) || gamma_slice_width <= 0) {
    .stopf("mcmc_control$slice$width_gamma must be positive.")
  }

  if (is.null(prior_gamma)) prior_gamma <- list(mu0 = 0, s20 = 10)
  if (!is.list(prior_gamma)) .stopf("prior_gamma must be a list.")
  if (!is.null(prior_gamma_mu0)) prior_gamma$mu0 <- as.numeric(prior_gamma_mu0)[1L]
  if (!is.null(prior_gamma_s20)) prior_gamma$s20 <- as.numeric(prior_gamma_s20)[1L]
  if (is.null(prior_sigma)) prior_sigma <- list(a = 1, b = 1)
  if (!is.list(prior_sigma)) .stopf("prior_sigma must be a list.")
  if (!is.null(a_sigma)) prior_sigma$a <- as.numeric(a_sigma)[1L]
  if (!is.null(b_sigma)) prior_sigma$b <- as.numeric(b_sigma)[1L]

  if (is.null(log_prior_gamma)) {
    mu0 <- as.numeric(prior_gamma$mu0 %||% 0)
    s20 <- as.numeric(prior_gamma$s20 %||% 10)
    if (!is.finite(mu0) || !is.finite(s20) || s20 <= 0) {
      .stopf("prior_gamma must define finite mu0 and positive s20.")
    }
    log_prior_gamma <- function(g) {
      stats::dnorm(g, mean = mu0, sd = sqrt(s20), log = TRUE)
    }
  }

  if (is.null(beta_prior_obj)) {
    beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = 1e4))
  }
  if (!identical(beta_prior_obj$type, "ridge")) {
    .stopf("exal_mcmc_fit currently supports only ridge beta priors. Got '%s'.",
           as.character(beta_prior_obj$type))
  }
  tau2 <- as.numeric(beta_prior_obj$hypers$tau2 %||% NA_real_)
  if (!is.finite(tau2) || tau2 <= 0) .stopf("ridge tau2 must be positive.")

  y <- as.numeric(y)
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  n <- nrow(X)
  p <- ncol(X)

  L <- gamma_bounds[1L]
  U <- gamma_bounds[2L]

  g_from_eta <- function(eta) {
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    L + (U - L) * s
  }
  eta_from_g <- function(g) {
    z <- (g - L) / (U - L)
    z <- pmin(pmax(z, 1e-12), 1 - 1e-12)
    stats::qlogis(z)
  }
  log_jac_gamma <- function(eta) {
    s <- stats::plogis(eta)
    s <- pmin(pmax(s, 1e-12), 1 - 1e-12)
    log(U - L) + log(s) + log1p(-s)
  }

  .sample_mvnorm_prec <- function(rhs, Prec) {
    Uc <- tryCatch(chol(Prec), error = function(e) NULL)
    if (is.null(Uc)) Uc <- chol(Prec + 1e-10 * diag(nrow(Prec)))
    mu <- backsolve(Uc, forwardsolve(t(Uc), rhs))
    as.numeric(mu + backsolve(Uc, stats::rnorm(length(mu))))
  }

  .slice_sample_1d <- function(x0, logf, width = 1.0, max_steps_out = 100L,
                               max_shrink = 1000L, lower = -Inf, upper = Inf) {
    logx0 <- logf(x0)
    if (!is.finite(logx0)) .stopf("slice sampler received a non-finite initial log density.")
    logy <- logx0 - stats::rexp(1L, rate = 1)

    u <- stats::runif(1L, 0, width)
    left <- x0 - u
    right <- x0 + (width - u)
    if (is.finite(lower)) left <- max(left, lower)
    if (is.finite(upper)) right <- min(right, upper)

    j <- as.integer(floor(stats::runif(1L, 0, max_steps_out + 1L)))
    k <- max_steps_out - j
    n_steps_out <- 0L

    while (j > 0L && left > lower) {
      val <- logf(left)
      if (!is.finite(val) || val <= logy) break
      left <- max(left - width, lower)
      j <- j - 1L
      n_steps_out <- n_steps_out + 1L
    }
    while (k > 0L && right < upper) {
      val <- logf(right)
      if (!is.finite(val) || val <= logy) break
      right <- min(right + width, upper)
      k <- k - 1L
      n_steps_out <- n_steps_out + 1L
    }

    n_shrink <- 0L
    repeat {
      x1 <- stats::runif(1L, left, right)
      logx1 <- logf(x1)
      if (is.finite(logx1) && logx1 >= logy) {
        return(list(x = x1, logf = logx1, n_steps_out = n_steps_out, n_shrink = n_shrink))
      }
      if (x1 < x0) {
        left <- x1
      } else {
        right <- x1
      }
      n_shrink <- n_shrink + 1L
      if (n_shrink >= max_shrink) {
        .stopf("slice sampler exceeded max_shrink=%d without finding an acceptable point.", max_shrink)
      }
    }
  }

  A_of <- function(g) A.fn(p0, g)
  B_of <- function(g) B.fn(p0, g)
  Cabs_of <- function(g) C.fn(p0, g) * abs(g)

  logpost_eta_gamma <- function(eta, beta, sigma, v, s_vec) {
    if (!is.finite(eta) || sigma <= 0 || any(!is.finite(beta)) || any(v <= 0) ||
        any(!is.finite(v)) || any(s_vec < 0) || any(!is.finite(s_vec))) {
      return(-Inf)
    }
    g <- g_from_eta(eta)
    A <- as.numeric(A_of(g))[1L]
    B <- as.numeric(B_of(g))[1L]
    Cabs <- as.numeric(Cabs_of(g))[1L]
    if (!is.finite(A) || !is.finite(B) || !is.finite(Cabs) || B <= 0) return(-Inf)

    mu <- drop(X %*% beta) + Cabs * sigma * s_vec + A * v
    res <- y - mu
    quad <- sum((res * res) / (B * sigma * v))
    if (!is.finite(quad)) return(-Inf)

    -(n / 2) * log(B) - 0.5 * quad + log_prior_gamma(g) + log_jac_gamma(eta)
  }

  vb_warm <- NULL
  if (init_from_vb) {
    vb_warm <- exal_ldvb_fit(
      y = y,
      X = X,
      p0 = p0,
      gamma_bounds = gamma_bounds,
      vb_control = modifyList(list(
        max_iter = 50L,
        min_iter_elbo = 10L,
        tol = 1e-3,
        tol_par = 1e-3,
        n_samp_xi = 200L,
        verbose = FALSE
      ), mcmc_control$vb_warm_start_control %||% list()),
      init = init,
      prior_gamma = prior_gamma,
      prior_sigma = prior_sigma,
      log_prior_gamma = log_prior_gamma,
      beta_prior_obj = beta_prior_obj
    )
  }

  beta <- as.numeric(init$beta %||% if (!is.null(vb_warm)) vb_warm$qbeta$m else rep(0, p))
  sigma <- as.numeric(init$sigma %||% if (!is.null(vb_warm)) vb_warm$qsiggam$sigma_mean else 1)[1L]
  gamma <- as.numeric(init$gamma %||% if (!is.null(vb_warm)) vb_warm$qsiggam$gamma_mean else 0)[1L]
  gamma <- min(max(gamma, L + 1e-6), U - 1e-6)
  eta_gamma <- eta_from_g(gamma)

  v <- as.numeric(init$v %||% if (!is.null(vb_warm)) vb_warm$qv$E_v else rep(1, n))
  if (length(v) != n) v <- rep(v[1L], n)
  v <- pmax(v, 1e-12)

  s <- as.numeric(init$s %||% if (!is.null(vb_warm)) vb_warm$qs$E_s else abs(stats::rnorm(n)))
  if (length(s) != n) s <- rep(s[1L], n)
  s <- pmax(s, 0)

  n_total <- n_burn + n_keep * thin
  beta_draws <- matrix(NA_real_, nrow = n_keep, ncol = p)
  sigma_draws <- numeric(n_keep)
  gamma_draws <- numeric(n_keep)
  if (store_latent_draws) {
    v_draws <- matrix(NA_real_, nrow = n_keep, ncol = n)
    s_draws <- matrix(NA_real_, nrow = n_keep, ncol = n)
  } else {
    v_draws <- NULL
    s_draws <- NULL
  }
  gamma_steps_out <- integer(n_total)
  gamma_shrink <- integer(n_total)

  t0 <- proc.time()[3L]
  save_idx <- 0L
  for (iter in seq_len(n_total)) {
    A <- as.numeric(A_of(gamma))[1L]
    B <- as.numeric(B_of(gamma))[1L]
    Cabs <- as.numeric(Cabs_of(gamma))[1L]

    z_v <- y - drop(X %*% beta) - Cabs * sigma * s
    chi_v <- (z_v * z_v) / (B * sigma)
    psi_v <- (A * A) / (B * sigma) + (2 / sigma)
    v <- as.numeric(sample_gig_devroye_vector(
      1L, p = 0.5, a = psi_v, b_vec = chi_v
    )[1L, ])
    v <- pmax(v, 1e-12)

    r_s <- y - drop(X %*% beta) - A * v
    tau2_s <- 1 / (1 + (Cabs * Cabs) * sigma / (B * v))
    tau2_s <- pmax(tau2_s, 1e-12)
    mu_s <- tau2_s * (Cabs * r_s) / (B * v)
    s <- as.numeric(sample_truncnorm(1L, n, sts_mu = mu_s, sts_sig2 = tau2_s)[1L, ])
    s <- pmax(s, 0)

    W_diag <- 1 / (B * sigma * v)
    Prec_beta <- crossprod(X * sqrt(W_diag)) + diag(1 / tau2, p)
    y_star <- y - Cabs * sigma * s - A * v
    rhs_beta <- crossprod(X, W_diag * y_star)
    beta <- .sample_mvnorm_prec(rhs_beta, Prec_beta)

    r_sigma <- y - drop(X %*% beta) - A * v
    chi_sigma <- sum((r_sigma * r_sigma) / (B * v)) + 2 * sum(v) + 2 * as.numeric(prior_sigma$b)
    psi_sigma <- (Cabs * Cabs / B) * sum((s * s) / v)
    k_sigma <- -(as.numeric(prior_sigma$a) + 1.5 * n)
    sigma_new <- as.numeric(sample_gig_devroye_vector(
      1L, p = k_sigma, a = psi_sigma, b_vec = chi_sigma
    )[1L, 1L])
    if (is.finite(sigma_new) && sigma_new > 0) sigma <- sigma_new

    slice_gamma <- .slice_sample_1d(
      x0 = eta_gamma,
      logf = function(eta) logpost_eta_gamma(eta, beta = beta, sigma = sigma, v = v, s_vec = s),
      width = gamma_slice_width,
      max_steps_out = gamma_slice_max_steps_out,
      max_shrink = gamma_slice_max_shrink
    )
    eta_gamma <- slice_gamma$x
    gamma <- g_from_eta(eta_gamma)
    gamma_steps_out[iter] <- slice_gamma$n_steps_out
    gamma_shrink[iter] <- slice_gamma$n_shrink

    if (iter > n_burn && ((iter - n_burn) %% thin == 0L)) {
      save_idx <- save_idx + 1L
      beta_draws[save_idx, ] <- beta
      sigma_draws[save_idx] <- sigma
      gamma_draws[save_idx] <- gamma
      if (store_latent_draws) {
        v_draws[save_idx, ] <- v
        s_draws[save_idx, ] <- s
      }
    }

    if (verbose && (iter %% 500L == 0L)) {
      cat(sprintf("%s iteration %d | sigma=%.3f | gamma=%.3f\n",
                  ifelse(iter <= n_burn, "burn-in", "MCMC"), iter, sigma, gamma))
    }
  }
  runtime <- as.numeric(proc.time()[3L] - t0)

  beta_mean <- colMeans(beta_draws)
  beta_median <- apply(beta_draws, 2L, stats::median)
  sigma_mean <- mean(sigma_draws)
  gamma_mean <- mean(gamma_draws)

  structure(list(
    method = "mcmc",
    control = list(
      n_burn = n_burn,
      n_mcmc = n_keep,
      thin = thin,
      verbose = verbose,
      init_from_vb = init_from_vb,
      store_latent_draws = store_latent_draws,
      slice = list(
        width_gamma = gamma_slice_width,
        max_steps_out = gamma_slice_max_steps_out,
        max_shrink = gamma_slice_max_shrink
      )
    ),
    run.time = runtime,
    X = X,
    bounds = c(L = L, U = U),
    p0 = p0,
    samp.beta = coda::as.mcmc(beta_draws),
    samp.sigma = coda::as.mcmc(sigma_draws),
    samp.gamma = coda::as.mcmc(gamma_draws),
    samp.v = if (!is.null(v_draws)) coda::as.mcmc(v_draws) else NULL,
    samp.s = if (!is.null(s_draws)) coda::as.mcmc(s_draws) else NULL,
    beta_prior = list(type = beta_prior_obj$type, hypers = beta_prior_obj$hypers),
    summary = list(
      beta_mean = beta_mean,
      beta_median = beta_median,
      sigma_mean = sigma_mean,
      gamma_mean = gamma_mean
    ),
    diagnostics = list(
      gamma_slice_steps_out_mean = mean(gamma_steps_out),
      gamma_slice_steps_out_max = max(gamma_steps_out),
      gamma_slice_shrink_mean = mean(gamma_shrink),
      gamma_slice_shrink_max = max(gamma_shrink)
    ),
    misc = list(
      p0 = p0,
      bounds = c(L = L, U = U),
      n = n,
      p = p,
      method = "mcmc",
      gamma_slice_steps_out = gamma_steps_out,
      gamma_slice_shrink = gamma_shrink
    ),
    last = list(
      beta = beta,
      sigma = sigma,
      gamma = gamma,
      v = v,
      s = s
    )
  ), class = c("exal_mcmc", "exal_static_mcmc"))
}

#' Draw posterior samples from an exAL fit
#'
#' Dispatches across the currently supported exAL inference backends.
#'
#' @export
exal_posterior_draws <- function(fit_exal, nd = 1000L, seed = NULL) {
  if (inherits(fit_exal, "exal_vb")) {
    return(exal_vb_posterior_draws(fit_exal, nd = nd))
  }
  if (inherits(fit_exal, "exal_mcmc")) {
    return(exal_mcmc_posterior_draws(fit_exal, nd = nd, seed = seed))
  }
  .stopf("Unsupported fit class for exal_posterior_draws().")
}

#' Posterior predictive samples from an exAL fit
#'
#' Dispatches across the currently supported exAL inference backends.
#'
#' @export
exal_posterior_predict <- function(fit_exal, X_new, nd = 1000L, chunk = 200L, draws = NULL, seed = NULL) {
  if (inherits(fit_exal, "exal_vb")) {
    return(exal_vb_posterior_predict(fit_exal, X_new = X_new, nd = nd, chunk = chunk, draws = draws))
  }
  if (inherits(fit_exal, "exal_mcmc")) {
    return(exal_mcmc_posterior_predict(fit_exal, X_new = X_new, nd = nd, chunk = chunk, draws = draws, seed = seed))
  }
  .stopf("Unsupported fit class for exal_posterior_predict().")
}

#' Fit exAL readout with either VB or MCMC
#'
#' @export
exal_fit <- function(..., method = c("vb", "mcmc")) {
  method <- match.arg(method)
  if (identical(method, "vb")) {
    return(exal_ldvb_fit(...))
  }
  exal_mcmc_fit(...)
}

#' Draw posterior samples of (beta, sigma, gamma) from an exAL MCMC fit
#'
#' @export
exal_mcmc_posterior_draws <- function(fit_exal, nd = NULL, seed = NULL) {
  stopifnot(inherits(fit_exal, "exal_mcmc"))
  if (!is.null(seed)) set.seed(seed)

  beta <- as.matrix(fit_exal$samp.beta)
  sigma <- as.numeric(fit_exal$samp.sigma)
  gamma <- as.numeric(fit_exal$samp.gamma)
  n_save <- nrow(beta)
  if (length(sigma) != n_save || length(gamma) != n_save) {
    .stopf("MCMC draw lengths do not match beta chain rows.")
  }

  if (is.null(nd) || is.na(nd)) {
    idx <- seq_len(n_save)
  } else {
    nd <- as.integer(nd)[1L]
    if (nd < 1L) .stopf("nd must be >= 1.")
    idx <- sample.int(n_save, size = nd, replace = (nd > n_save))
  }

  list(
    beta = beta[idx, , drop = FALSE],
    sigma = sigma[idx],
    gamma = gamma[idx],
    nd = length(idx)
  )
}

.exal_posterior_predict_from_draws <- function(fit_exal, X_new, draws, chunk = 200L) {
  X_new <- as.matrix(X_new)
  n <- nrow(X_new)

  Bdraw <- draws$beta
  sdraw <- draws$sigma
  gdraw <- draws$gamma
  if (is.null(Bdraw) || !is.matrix(Bdraw)) .stopf("posterior_predict: missing beta draws.")
  if (length(sdraw) != nrow(Bdraw) || length(gdraw) != nrow(Bdraw)) {
    .stopf("posterior_predict: draw lengths do not match beta draws.")
  }
  nd_eff <- nrow(Bdraw)

  p0 <- fit_exal$misc$p0
  A_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$A, numeric(1))
  B_d <- vapply(gdraw, function(g) exal_get_ABC(p0 = p0, gamma = g)$B, numeric(1))
  lam_d <- vapply(gdraw, function(g) {
    abc <- exal_get_ABC(p0 = p0, gamma = g)
    abc$C * abs(g)
  }, numeric(1))

  yrep <- matrix(NA_real_, n, nd_eff)
  mu_draws <- matrix(NA_real_, n, nd_eff)
  ids_list <- split(seq_len(nd_eff), ceiling(seq_len(nd_eff) / as.integer(chunk)))
  for (ids in ids_list) {
    mm <- length(ids)
    Bc <- t(Bdraw[ids, , drop = FALSE])
    mu <- X_new %*% Bc
    mu_draws[, ids] <- mu

    s_mat <- matrix(abs(stats::rnorm(n * mm)), n, mm)
    v_mat <- matrix(stats::rexp(n * mm, rate = rep(1 / sdraw[ids], each = n)), n, mm)
    z_mat <- matrix(stats::rnorm(n * mm), n, mm)

    term_s <- sweep(s_mat, 2L, lam_d[ids] * sdraw[ids], `*`)
    term_v <- sweep(v_mat, 2L, A_d[ids], `*`)
    sd_mat <- sqrt(sweep(v_mat, 2L, B_d[ids] * sdraw[ids], `*`))

    yrep[, ids] <- mu + term_s + term_v + sd_mat * z_mat
  }

  list(yrep = yrep, mu_draws = mu_draws,
       beta = Bdraw, sigma = sdraw, gamma = gdraw)
}

#' Posterior predictive samples for an exAL MCMC fit
#'
#' @export
exal_mcmc_posterior_predict <- function(fit_exal, X_new, nd = 1000L, chunk = 200L, draws = NULL, seed = NULL) {
  stopifnot(inherits(fit_exal, "exal_mcmc"))
  if (!is.null(seed)) set.seed(seed)
  if (is.null(draws)) draws <- exal_mcmc_posterior_draws(fit_exal, nd = nd)
  .exal_posterior_predict_from_draws(fit_exal, X_new = X_new, draws = draws, chunk = chunk)
}
