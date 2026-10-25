.autodesn_split_rhat <- function(z) {
  if (length(z) < 2L) return(NA_real_)
  if (any(vapply(z, function(x) any(!is.finite(x)), logical(1)))) return(NA_real_)
  half <- min(lengths(z)) %/% 2L
  if (half < 10L) return(NA_real_)
  x <- do.call(cbind, lapply(z, function(v) cbind(v[seq_len(half)], utils::tail(v, half))))
  rhat <- function(v) {
    dim(v) <- dim(x)
    W <- mean(apply(v, 2L, stats::var))
    B <- nrow(v) * stats::var(colMeans(v))
    if (!is.finite(W) || !is.finite(B)) return(NA_real_)
    if (W == 0) return(if (B > 0) Inf else NA_real_)
    sqrt((nrow(v) - 1) / nrow(v) + B / (nrow(v) * W))
  }
  rank_normal <- function(v) stats::qnorm((rank(v, ties.method = "average") - 3 / 8) / (length(v) + 1 / 4))
  a <- rhat(rank_normal(x))
  b <- rhat(rank_normal(abs(x - stats::median(x))))
  if (all(is.na(c(a, b)))) NA_real_ else max(c(a, b), na.rm = TRUE)
}

.autodesn_ess <- function(z) {
  vapply(z, function(x) {
    if (length(x) < 20L || any(!is.finite(x)) || stats::var(x) == 0) return(NA_real_)
    out <- tryCatch(as.numeric(coda::effectiveSize(coda::mcmc(x))), error = function(e) NA_real_)
    min(length(x), out)
  }, numeric(1))
}

.autodesn_batch_mcse <- function(z) {
  se <- vapply(z, function(x) {
    if (!length(x) || any(!is.finite(x))) return(NA_real_)
    b <- max(5L, floor(sqrt(length(x))))
    nb <- length(x) %/% b
    if (nb < 3L) return(NA_real_)
    stats::sd(colMeans(matrix(x[seq_len(nb * b)], b, nb))) / sqrt(nb)
  }, numeric(1))
  sqrt(sum(se^2)) / length(se)
}

#' Compare independent Gaussian AutoDESN chains
#'
#' Reports rank-normalized folded split R-hat, summed per-chain spectral ESS
#' estimates, batch-means Monte Carlo errors, and model probability agreement.
#' Spectral ESS is capped at the retained draw count per chain; it is not
#' the bulk/tail ESS used by Stan.
#' These are convergence screens; they do not establish exploration of an
#' unlisted architecture or guarantee mixing. Deliberately fixed parameters
#' have undefined R-hat and ESS, reported as NA with `sampled = FALSE`.
#' Model-indicator diagnostics describe architecture exploration separately
#' from continuous parameters. An unvisited model has undefined indicator ESS;
#' this does not establish that its posterior probability is zero.
#'
#' RHS chains must share the complete normalized prior, including fixed scale
#' values and the per-model global scales. Different initialization, proposal,
#' backend, and run-length settings are allowed because they do not change the
#' target. Full categorical scans use their conditional probabilities for
#' model-probability Monte Carlo errors. Collapsed MH uses sampled indicators;
#' its occupancy estimates are never presented as Rao--Blackwell estimates.
#'
#' @param fits Nonempty list of independently initialized `autodesn_fit` objects
#'   for the same bank, prior and target distribution.
#' @return List with `parameters`, `models`, `chains`, `beta_prior_type`, and a
#'   diagnostic qualification. `parameters$sampled` marks quantities whose
#'   convergence can be screened. Model-indicator R-hat and spectral ESS are
#'   additional columns in `models`.
#' @export
autodesn_diagnostics <- function(fits) {
  if (is.list(fits) && length(fits) && inherits(fits[[1L]], "autodesn_extended_fit"))
    return(.ext_diagnostics(fits))
  if (!is.list(fits) || !length(fits) || !all(vapply(fits, inherits, logical(1), "autodesn_fit"))) {
    stop("fits must be a nonempty list of autodesn_fit objects.", call. = FALSE)
  }
  ref <- fits[[1L]]
  prior_type <- function(f) {
    if (is.null(f$meta$beta_prior_type)) "independent_ridge" else f$meta$beta_prior_type
  }
  rhs <- identical(prior_type(ref), "independent_rhs")
  target_controls <- c("intercept_variance", "a_sigma", "b_sigma", "a_lambda", "b_lambda", "learn_ridge")
  same_target <- function(fit) {
    if (!identical(prior_type(fit), prior_type(ref))) return(FALSE)
    if (rhs) {
      return(!is.null(ref$controls$target) &&
               identical(fit$controls$target, ref$controls$target))
    }
    identical(fit$controls[target_controls], ref$controls[target_controls]) &&
      (isTRUE(ref$controls$learn_ridge) ||
         identical(unique(fit$draws$ridge_precision), unique(ref$draws$ridge_precision)))
  }
  for (fit in fits[-1L]) {
    if (!identical(fit$bank$y, ref$bank$y) || !identical(fit$bank$prior, ref$bank$prior) ||
        !identical(lapply(fit$bank$models, `[[`, "X"), lapply(ref$bank$models, `[[`, "X")) ||
        !same_target(fit)) {
      stop("Diagnostic chains must have the same bank, prior and target.", call. = FALSE)
    }
  }
  summarize <- function(z) {
    ess <- .autodesn_ess(z)
    c(rhat = .autodesn_split_rhat(z), ess_spectral = if (anyNA(ess)) NA_real_ else sum(ess),
      mcse_batch = .autodesn_batch_mcse(z))
  }
  pars <- list(log_variance = lapply(fits, function(f) log(f$draws$variance)))
  sampled <- TRUE
  if (rhs) {
    fields <- c("log_global", "log_slab", "mean_log_local", "intercept",
                "fitted_rms", "effective_slopes_diagonal")
    pars <- c(pars, stats::setNames(lapply(fields, function(nm) {
      lapply(fits, function(f) f$draws[[nm]])
    }), fields))
    ctl <- ref$controls$rhs_control
    if (is.null(ctl)) stop("RHS fit is missing its normalized rhs_control.", call. = FALSE)
    has_slopes <- any(vapply(ref$bank$models, function(m) m$d > 0L, logical(1)))
    sampled <- c(TRUE, isTRUE(ctl$learn_global), isTRUE(ctl$learn_slab),
                 has_slopes && is.null(ctl$fixed_local_scales), TRUE, TRUE,
                 has_slopes)
  } else {
    pars$log_ridge_precision <- lapply(fits, function(f) log(f$draws$ridge_precision))
    sampled <- c(TRUE, isTRUE(ref$controls$learn_ridge))
  }
  parameters <- data.frame(parameter = names(pars), do.call(rbind, lapply(pars, summarize)), row.names = NULL)
  parameters$sampled <- sampled
  parameters[!sampled, c("rhat", "ess_spectral")] <- NA_real_
  models <- ref$model_summary
  probabilities <- vapply(fits, function(f) f$model_summary$posterior_probability, numeric(nrow(models)))
  dim(probabilities) <- c(nrow(models), length(fits))
  models$posterior_probability <- rowMeans(probabilities)
  models$chain_range <- apply(probabilities, 1L, function(p) diff(range(p)))
  has_conditional <- vapply(fits, function(f) {
    is.matrix(f$conditional_probabilities) &&
      identical(dim(f$conditional_probabilities), c(nrow(f$draws), nrow(models)))
  }, logical(1))
  models$probability_estimator <- if (all(has_conditional)) {
    "mean_conditional_probability"
  } else if (!any(has_conditional)) "occupancy" else "mixed_valid_estimators"
  models$mcse_batch <- vapply(seq_len(nrow(models)), function(j) {
    .autodesn_batch_mcse(lapply(seq_along(fits), function(k) {
      if (has_conditional[k]) fits[[k]]$conditional_probabilities[, j]
      else as.numeric(fits[[k]]$draws$model == j)
    }))
  }, numeric(1))
  indicators <- lapply(seq_len(nrow(models)), function(j) {
    lapply(fits, function(f) as.numeric(f$draws$model == j))
  })
  models$rhat_indicator <- vapply(indicators, .autodesn_split_rhat, numeric(1))
  models$ess_indicator_spectral <- vapply(indicators, function(z) {
    ess <- .autodesn_ess(z)
    if (anyNA(ess)) NA_real_ else sum(ess)
  }, numeric(1))
  occupancy <- vapply(fits, function(f) f$model_summary$occupancy, numeric(nrow(models)))
  dim(occupancy) <- c(nrow(models), length(fits))
  models$occupancy <- rowMeans(occupancy)
  list(parameters = parameters, models = models, chains = length(fits),
       beta_prior_type = prior_type(ref),
       qualification = "Rank-normalized folded split R-hat; coda spectral ESS; batch-means MCSE. Screens only.")
}

#' Gaussian AutoDESN diagnostics
#' @param object An `autodesn_fit`.
#' @param ... Additional independent `autodesn_fit` objects for the same target.
#' @return The result of [autodesn_diagnostics()].
#' @method diagnostics autodesn_fit
#' @export
diagnostics.autodesn_fit <- function(object, ...) {
  autodesn_diagnostics(c(list(object), list(...)))
}
