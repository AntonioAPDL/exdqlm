.autodesn_split_rhat <- function(z) {
  if (length(z) < 2L) return(NA_real_)
  half <- min(lengths(z)) %/% 2L
  if (half < 10L) return(NA_real_)
  x <- do.call(cbind, lapply(z, function(v) cbind(v[seq_len(half)], utils::tail(v, half))))
  rhat <- function(v) {
    dim(v) <- dim(x)
    W <- mean(apply(v, 2L, stats::var))
    if (!is.finite(W) || W == 0) return(NA_real_)
    B <- nrow(v) * stats::var(colMeans(v))
    sqrt((nrow(v) - 1) / nrow(v) + B / (nrow(v) * W))
  }
  rank_normal <- function(v) stats::qnorm((rank(v, ties.method = "average") - 3 / 8) / (length(v) + 1 / 4))
  a <- rhat(rank_normal(x))
  b <- rhat(rank_normal(abs(x - stats::median(x))))
  if (all(is.na(c(a, b)))) NA_real_ else max(c(a, b), na.rm = TRUE)
}

.autodesn_ess <- function(z) {
  vapply(z, function(x) {
    if (length(x) < 20L || stats::var(x) == 0) return(NA_real_)
    out <- tryCatch(as.numeric(coda::effectiveSize(coda::mcmc(x))), error = function(e) NA_real_)
    min(length(x), out)
  }, numeric(1))
}

.autodesn_batch_mcse <- function(z) {
  se <- vapply(z, function(x) {
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
#' unlisted architecture or guarantee mixing. Fixed precision has undefined
#' R-hat and ESS and is reported as NA.
#'
#' @param fits Nonempty list of independently initialized `autodesn_fit` objects
#'   for the same bank, prior and target distribution.
#' @return List with `parameters`, `models`, and a diagnostic qualification.
#' @export
autodesn_diagnostics <- function(fits) {
  if (!is.list(fits) || !length(fits) || !all(vapply(fits, inherits, logical(1), "autodesn_fit"))) {
    stop("fits must be a nonempty list of autodesn_fit objects.", call. = FALSE)
  }
  ref <- fits[[1L]]
  target_controls <- c("intercept_variance", "a_sigma", "b_sigma", "a_lambda", "b_lambda", "learn_ridge")
  for (fit in fits[-1L]) {
    if (!identical(fit$bank$y, ref$bank$y) || !identical(fit$bank$prior, ref$bank$prior) ||
        !identical(lapply(fit$bank$models, `[[`, "X"), lapply(ref$bank$models, `[[`, "X")) ||
        !identical(fit$controls[target_controls], ref$controls[target_controls]) ||
        (!isTRUE(ref$controls$learn_ridge) && !identical(unique(fit$draws$ridge_precision), unique(ref$draws$ridge_precision)))) {
      stop("Diagnostic chains must have the same bank, prior and target.", call. = FALSE)
    }
  }
  summarize <- function(z) {
    ess <- .autodesn_ess(z)
    c(rhat = .autodesn_split_rhat(z), ess_spectral = if (anyNA(ess)) NA_real_ else sum(ess),
      mcse_batch = .autodesn_batch_mcse(z))
  }
  pars <- list(log_variance = lapply(fits, function(f) log(f$draws$variance)),
               log_ridge_precision = lapply(fits, function(f) log(f$draws$ridge_precision)))
  parameters <- data.frame(parameter = names(pars), do.call(rbind, lapply(pars, summarize)), row.names = NULL)
  models <- ref$model_summary
  probabilities <- vapply(fits, function(f) f$model_summary$posterior_probability, numeric(nrow(models)))
  dim(probabilities) <- c(nrow(models), length(fits))
  models$posterior_probability <- rowMeans(probabilities)
  models$chain_range <- apply(probabilities, 1L, function(p) diff(range(p)))
  models$mcse_batch <- vapply(seq_len(nrow(models)), function(j) {
    .autodesn_batch_mcse(lapply(fits, function(f) f$conditional_probabilities[, j]))
  }, numeric(1))
  occupancy <- vapply(fits, function(f) f$model_summary$occupancy, numeric(nrow(models)))
  dim(occupancy) <- c(nrow(models), length(fits))
  models$occupancy <- rowMeans(occupancy)
  list(parameters = parameters, models = models, chains = length(fits),
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
