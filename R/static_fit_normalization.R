# Internal static fit normalization helpers used by static parity pipelines.

.static_vb_to_mcmc_init <- function(vb_fit, dqlm.ind = isTRUE(vb_fit$dqlm.ind)) {
  if (!is.list(vb_fit)) stop("vb_fit must be a list")

  if (isTRUE(dqlm.ind)) {
    if (is.null(vb_fit$qbeta$m) || is.null(vb_fit$qsig$E_sigma) || is.null(vb_fit$qv$E_v)) {
      stop("DQLM VB fit missing required fields qbeta$m, qsig$E_sigma, or qv$E_v")
    }
    return(list(
      beta = as.numeric(vb_fit$qbeta$m),
      sigma = as.numeric(vb_fit$qsig$E_sigma)[1],
      v = as.numeric(vb_fit$qv$E_v)
    ))
  }

  if (is.null(vb_fit$qbeta$m) || is.null(vb_fit$qsiggam$sigma_mean) ||
      is.null(vb_fit$qsiggam$gamma_mean) || is.null(vb_fit$qv$E_v) || is.null(vb_fit$qs$E_s)) {
    stop("exAL VB fit missing required fields for MCMC initialization")
  }

  list(
    beta = as.numeric(vb_fit$qbeta$m),
    sigma = as.numeric(vb_fit$qsiggam$sigma_mean)[1],
    gamma = as.numeric(vb_fit$qsiggam$gamma_mean)[1],
    v = as.numeric(vb_fit$qv$E_v),
    s = as.numeric(vb_fit$qs$E_s)
  )
}

.static_normalize_vb_fit <- function(fit, model_name = c("al", "exal"), tau = NA_real_, run_settings = list()) {
  model_name <- match.arg(model_name)
  dqlm.ind <- isTRUE(if (!is.null(fit$dqlm.ind)) fit$dqlm.ind else identical(model_name, "al"))

  conv <- if (!is.null(fit$diagnostics$convergence)) fit$diagnostics$convergence else list()
  converged <- isTRUE(conv$converged)
  stop_reason <- if (!is.null(conv$stop_reason)) as.character(conv$stop_reason)[1] else NA_character_

  sigma_est <- if (isTRUE(dqlm.ind)) {
    if (!is.null(fit$qsig$E_sigma)) as.numeric(fit$qsig$E_sigma)[1] else NA_real_
  } else {
    if (!is.null(fit$qsiggam$sigma_mean)) as.numeric(fit$qsiggam$sigma_mean)[1] else NA_real_
  }

  gamma_est <- if (isTRUE(dqlm.ind)) {
    NA_real_
  } else {
    if (!is.null(fit$qsiggam$gamma_mean)) as.numeric(fit$qsiggam$gamma_mean)[1] else NA_real_
  }

  elbo_trace <- if (!is.null(fit$diagnostics$elbo)) {
    as.numeric(fit$diagnostics$elbo)
  } else if (!is.null(fit$misc$elbo)) {
    as.numeric(fit$misc$elbo)
  } else {
    numeric(0)
  }

  list(
    model_family = "static",
    algorithm = "vb",
    model = model_name,
    tau = as.numeric(tau)[1],
    dqlm.ind = dqlm.ind,
    status = if (converged) "converged" else "stopped",
    runtime_sec = if (!is.null(fit$run.time)) as.numeric(fit$run.time)[1] else NA_real_,
    iter = if (!is.null(fit$iter)) as.integer(fit$iter)[1] else NA_integer_,
    stop_reason = stop_reason,
    converged = converged,
    state_dim = if (!is.null(fit$qbeta$m)) length(fit$qbeta$m) else NA_integer_,
    sigma_est = sigma_est,
    gamma_est = gamma_est,
    diagnostics = list(
      convergence = conv,
      elbo = list(
        trace = elbo_trace,
        final = if (length(elbo_trace)) utils::tail(elbo_trace, 1L) else NA_real_
      ),
      ess = list(sigma = NA_real_, gamma = if (isTRUE(dqlm.ind)) NA_real_ else NA_real_),
      acceptance = list(total = NA_real_, burn = NA_real_, keep = NA_real_)
    ),
    metadata = list(settings = run_settings)
  )
}

.static_normalize_mcmc_fit <- function(fit, model_name = c("al", "exal"), tau = NA_real_, run_settings = list()) {
  model_name <- match.arg(model_name)
  dqlm.ind <- isTRUE(if (!is.null(fit$dqlm.ind)) fit$dqlm.ind else identical(model_name, "al"))

  sigma_draws <- if (!is.null(fit$samp.sigma)) as.numeric(fit$samp.sigma) else numeric(0)
  gamma_draws <- if (!isTRUE(dqlm.ind) && !is.null(fit$samp.gamma)) as.numeric(fit$samp.gamma) else numeric(0)

  ess_sigma <- if (length(sigma_draws) >= 5L) {
    tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(sigma_draws))), error = function(e) NA_real_)
  } else {
    NA_real_
  }
  ess_gamma <- if (length(gamma_draws) >= 5L) {
    tryCatch(as.numeric(coda::effectiveSize(coda::as.mcmc(gamma_draws))), error = function(e) NA_real_)
  } else {
    NA_real_
  }

  accept_total <- if (!is.null(fit$accept.rate)) as.numeric(fit$accept.rate)[1] else NA_real_
  accept_burn <- if (!is.null(fit$accept.rate.burn)) as.numeric(fit$accept.rate.burn)[1] else NA_real_
  accept_keep <- if (!is.null(fit$accept.rate.keep)) as.numeric(fit$accept.rate.keep)[1] else NA_real_

  list(
    model_family = "static",
    algorithm = "mcmc",
    model = model_name,
    tau = as.numeric(tau)[1],
    dqlm.ind = dqlm.ind,
    status = "completed",
    runtime_sec = if (!is.null(fit$run.time)) as.numeric(fit$run.time)[1] else NA_real_,
    n_burn = if (!is.null(fit$n.burn)) as.integer(fit$n.burn)[1] else NA_integer_,
    n_mcmc = if (!is.null(fit$n.mcmc)) as.integer(fit$n.mcmc)[1] else length(sigma_draws),
    state_dim = if (!is.null(fit$samp.beta)) ncol(as.matrix(fit$samp.beta)) else NA_integer_,
    sigma_est = if (length(sigma_draws)) mean(sigma_draws) else NA_real_,
    gamma_est = if (length(gamma_draws)) mean(gamma_draws) else NA_real_,
    diagnostics = list(
      ess = list(sigma = ess_sigma, gamma = if (isTRUE(dqlm.ind)) NA_real_ else ess_gamma),
      acceptance = list(total = accept_total, burn = accept_burn, keep = accept_keep),
      rhat_ready = list(sigma = sigma_draws, gamma = gamma_draws)
    ),
    metadata = list(settings = run_settings)
  )
}

.static_quantile_path_from_fit <- function(fit, X, algorithm = c("vb", "mcmc")) {
  algorithm <- match.arg(algorithm)
  X <- as.matrix(X)

  if (algorithm == "vb") {
    if (is.null(fit$qbeta$m)) stop("VB fit missing qbeta$m")
    beta_mean <- as.numeric(fit$qbeta$m)
    mean_path <- as.numeric(drop(X %*% beta_mean))
    sd_path <- NA_real_ * mean_path
    if (!is.null(fit$qbeta$V)) {
      Vb <- as.matrix(fit$qbeta$V)
      if (ncol(Vb) == ncol(X)) {
        sd_path <- sqrt(pmax(rowSums((X %*% Vb) * X), 0))
      }
    }
    return(list(
      mean = mean_path,
      lo = mean_path - 1.96 * sd_path,
      hi = mean_path + 1.96 * sd_path,
      sd = sd_path
    ))
  }

  if (is.null(fit$samp.beta)) stop("MCMC fit missing samp.beta")
  beta_draws <- as.matrix(fit$samp.beta)
  q_draws <- beta_draws %*% t(X)
  list(
    mean = as.numeric(colMeans(q_draws)),
    lo = as.numeric(apply(q_draws, 2, stats::quantile, probs = 0.05, na.rm = TRUE)),
    hi = as.numeric(apply(q_draws, 2, stats::quantile, probs = 0.95, na.rm = TRUE)),
    sd = as.numeric(apply(q_draws, 2, stats::sd, na.rm = TRUE))
  )
}
