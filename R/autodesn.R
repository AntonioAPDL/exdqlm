#' Construct a small Q-DESN specification grid
#'
#' Each grid row is an explicit fixed reservoir specification, including its
#' seed. Width is constant across layers and bridges use half that width.
#' Supply a list of ordinary `qdesn_fit_vb()` argument lists directly to
#' [autodesn_build_bank()] for unequal layer widths or other custom grids.
#'
#' @param D Candidate depths.
#' @param n Candidate widths per layer.
#' @param m Candidate lag counts.
#' @param alpha Candidate leaks.
#' @param rho Candidate spectral radii.
#' @param seed Candidate reservoir seeds.
#' @param ... Shared arguments for [qdesn_fit_vb()], for example `washout`.
#' @return A named list of Q-DESN argument lists.
#' @export
autodesn_candidates <- function(D = c(1L, 2L), n = 12L, m = c(1L, 4L),
                                alpha = c(0.3, 0.8), rho = c(0.4, 0.8),
                                seed = c(11L, 29L), ...) {
  grid <- expand.grid(D = D, n = n, m = m, alpha = alpha, rho = rho,
                      seed = seed, KEEP.OUT.ATTRS = FALSE)
  if (!nrow(grid)) stop("The candidate grid must be nonempty.", call. = FALSE)
  shared <- list(...)
  if (length(shared) && (is.null(names(shared)) || any(!nzchar(names(shared))) ||
                        anyDuplicated(names(shared)))) {
    stop("Shared candidate arguments must have unique names.", call. = FALSE)
  }
  if (any(names(shared) %in% c(names(grid), "n_tilde"))) {
    stop("Grid arguments and n_tilde cannot be overridden through ... .", call. = FALSE)
  }
  out <- lapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]
    .autodesn_integer(g$D, "D")
    .autodesn_integer(g$n, "n")
    c(list(D = as.integer(g$D), n = rep(as.integer(g$n), g$D),
           n_tilde = rep(max(1L, as.integer(g$n) %/% 2L), g$D - 1L),
           m = g$m, alpha = g$alpha, rho = rep(g$rho, g$D), seed = g$seed), shared)
  })
  names(out) <- sprintf("desn_%03d", seq_along(out))
  out
}

.autodesn_spec <- function(x) {
  if (!is.list(x) || is.null(names(x)) || any(!nzchar(names(x))) ||
      anyDuplicated(names(x))) {
    stop("Each candidate must be an argument list with unique names.", call. = FALSE)
  }
  allowed <- names(formals(qdesn_fit_vb))
  unknown <- setdiff(names(x), allowed)
  if (length(unknown)) stop("Unknown candidate arguments: ", paste(unknown, collapse = ", "), call. = FALSE)
  forbidden <- intersect(names(x), c("y", "p0", "fit_readout", "vb_args", "weights",
                                    "segments", "decomposition", "decomposition_xreg",
                                    "lag_center_override", "lag_scale_override"))
  if (length(forbidden)) stop("Unsupported AutoDESN candidate arguments: ", paste(forbidden, collapse = ", "), call. = FALSE)
  x <- utils::modifyList(list(D = 1L, n = 12L, n_tilde = integer(0), m = 4L,
                             alpha = 0.5, rho = 0.8, washout = 20L,
                             pi_w = 0.2, pi_in = 0.5), x)
  .autodesn_integer(x$D, "D")
  .autodesn_integer(x$m, "m", 0L)
  .autodesn_integer(x$washout, "washout", 0L)
  if (is.null(x$seed)) stop("Every candidate needs an explicit reservoir seed.", call. = FALSE)
  .autodesn_integer(x$seed, "candidate seed", 0L)
  if (length(x$n) != x$D || any(!is.finite(x$n)) || any(x$n < 1 | x$n != floor(x$n))) {
    stop("Candidate n must contain one positive integer per layer.", call. = FALSE)
  }
  if (x$D == 1L) x$n_tilde <- integer(0)
  if (length(x$n_tilde) != x$D - 1L || any(!is.finite(x$n_tilde)) ||
      any(x$n_tilde < 1 | x$n_tilde != floor(x$n_tilde))) {
    stop("Candidate n_tilde must contain D-1 positive integers.", call. = FALSE)
  }
  if (!is.null(x$input_mode) && !identical(x$input_mode, "raw_y_lags")) {
    stop("AutoDESN currently supports raw_y_lags input only.", call. = FALSE)
  }
  if (!is.null(x$state_noise_sd) && !identical(as.numeric(x$state_noise_sd), 0)) {
    stop("AutoDESN requires deterministic features: state_noise_sd = 0.", call. = FALSE)
  }
  if (!is.null(x$add_bias) && !isTRUE(x$add_bias)) {
    stop("AutoDESN requires add_bias = TRUE for its proper intercept.", call. = FALSE)
  }
  x$add_bias <- TRUE
  x$input_mode <- "raw_y_lags"
  # The response is already standardized by the conditioning prefix. Prevent
  # the shared builder from estimating lag scaling from the response window.
  if (isTRUE(x$standardize_inputs)) {
    x$lag_center_override <- 0
    x$lag_scale_override <- 1
  }
  x
}

#' Build a causal AutoDESN bank using the shared Q-DESN feature builder
#'
#' The first `conditioning` observations fix response centering and scaling
#' and are not scored. All models then share a further warmup of
#' `max(m, washout)` over the entire bank. Prior mass defaults to uniform over
#' depths, then uniform over specifications within depth. Reservoir seeds are
#' discrete candidate variables, not optimized recurrent weights.
#'
#' @param y Finite univariate observed series through the forecast origin.
#' @param candidates Named or unnamed list of Q-DESN specifications.
#' @param conditioning Number of initial observations reserved for scaling.
#' @param model_prior Optional positive masses, one per candidate.
#' @param normalize_features Divide slope features by sqrt(number of slopes).
#' @return An `autodesn_bank` retaining designs, reservoir weights, states,
#'   observed history, common row indices, and frozen preprocessing.
#' @export
autodesn_build_bank <- function(y, candidates = autodesn_candidates(),
                                conditioning = 30L, model_prior = NULL,
                                normalize_features = TRUE) {
  y <- .normal_desn_assert_response(y)
  .autodesn_integer(conditioning, "conditioning", 2L)
  if (!is.list(candidates) || !length(candidates)) stop("candidates must be a nonempty list.", call. = FALSE)
  specs <- lapply(candidates, .autodesn_spec)
  common_warmup <- max(vapply(specs, function(x) max(x$m, x$washout), numeric(1)))
  drop <- conditioning + common_warmup
  if (length(y) < drop + 2L) stop("Need at least two scored observations after conditioning and common warmup.", call. = FALSE)
  center <- mean(y[seq_len(conditioning)])
  scale <- stats::sd(y[seq_len(conditioning)])
  if (!is.finite(scale) || scale < 1e-12) scale <- 1
  z <- (y - center) / scale
  templates <- lapply(specs, function(x) {
    x$washout <- drop
    .autodesn_seed(x$seed, function() {
      do.call(qdesn_fit_vb, c(list(y = z, p0 = 0.5, fit_readout = FALSE), x))
    })
  })
  keep_idx <- seq.int(drop + 1L, length(y))
  if (!all(vapply(templates, function(x) identical(as.integer(x$meta$keep_idx), as.integer(keep_idx)), logical(1)))) {
    stop("Internal error: AutoDESN candidates have unequal response rows.", call. = FALSE)
  }
  labels <- names(candidates)
  if (is.null(labels)) labels <- sprintf("desn_%03d", seq_along(specs))
  if (any(!nzchar(labels)) || anyDuplicated(labels)) stop("Candidate names must be nonempty and unique.", call. = FALSE)
  info <- data.frame(model = seq_along(specs), candidate = labels,
                     D = vapply(specs, function(x) as.integer(x$D), integer(1)),
                     m = vapply(specs, function(x) as.integer(x$m), integer(1)),
                     seed = vapply(specs, function(x) as.integer(x$seed), integer(1)))
  if (is.null(model_prior)) {
    counts <- table(info$D)
    model_prior <- 1 / (length(counts) * as.numeric(counts[as.character(info$D)]))
  }
  bank <- autodesn_prepare_bank(z[keep_idx], lapply(templates, function(x) x$X[, -1L, drop = FALSE]),
                                 model_info = info, model_prior = model_prior,
                                 normalize_features = normalize_features)
  bank$templates <- templates
  bank$specifications <- specs
  bank$keep_idx <- keep_idx
  bank$history <- y
  bank$history_scaled <- z
  bank$preprocessing <- list(center = center, scale = scale, conditioning = conditioning,
                             common_warmup = common_warmup, drop = drop)
  bank$meta <- list(likelihood_family = "normal", beta_prior_type = "independent_ridge",
                    input_mode = "raw_y_lags", selection = "finite_bank",
                    package_version = .qdesn_vb_package_version(),
                    package_sha = suppressWarnings(.qdesn_vb_package_sha()))
  bank
}

#' Fit Gaussian AutoDESN from an observed series
#'
#' Convenience facade over [autodesn_build_bank()] and [autodesn_fit_bank()].
#' See the AutoDESN guide for prior conventions, diagnostics, and restrictions.
#'
#' @inheritParams autodesn_build_bank
#' @param mcmc_args Named controls forwarded to [autodesn_fit_bank()].
#' @return An `autodesn_fit` supporting the existing Q-DESN prediction methods.
#' @export
autodesn_fit <- function(y, candidates = autodesn_candidates(), conditioning = 30L,
                         model_prior = NULL, normalize_features = TRUE,
                         mcmc_args = list()) {
  if (!is.list(mcmc_args) || (length(mcmc_args) &&
      (is.null(names(mcmc_args)) || any(!nzchar(names(mcmc_args))) || anyDuplicated(names(mcmc_args))))) {
    stop("mcmc_args must be a uniquely named list.", call. = FALSE)
  }
  if ("bank" %in% names(mcmc_args)) stop("mcmc_args cannot override bank.", call. = FALSE)
  bank <- autodesn_build_bank(y, candidates, conditioning, model_prior, normalize_features)
  do.call(autodesn_fit_bank, c(list(bank = bank), mcmc_args))
}

.autodesn_unscale <- function(bank, x) {
  if (is.null(bank$preprocessing)) return(x)
  bank$preprocessing$center + bank$preprocessing$scale * x
}

#' Fitted posterior means from Gaussian AutoDESN
#' @param object An `autodesn_fit`.
#' @return Numeric posterior means on the original response scale.
#' @export
predict_mu.autodesn_fit <- function(object) {
  mu <- numeric(object$bank$n)
  for (j in unique(object$draws$model)) {
    ids <- which(object$draws$model == j)
    beta_sum <- colSums(do.call(rbind, object$beta[ids]))
    mu <- mu + as.numeric(object$bank$models[[j]]$X %*% beta_sum)
  }
  .autodesn_unscale(object$bank, mu / nrow(object$draws))
}

#' Fixed-design posterior predictive draws from Gaussian AutoDESN
#'
#' Future autoregressive features must not be constructed with future observed
#' targets. Use [forecast_paths.autodesn_fit()] for recursive forecasting.
#'
#' @param object An `autodesn_fit`.
#' @param nd Number of predictive paths.
#' @param X_new Optional list of slope matrices, in bank order and before the
#'   bank's feature normalization. Defaults to the scored training designs.
#' @param seed Optional seed preserving the caller's RNG state.
#' @return List with `yrep`, `mu_draws`, and selected posterior draw indices.
#' @export
posterior_predict.autodesn_fit <- function(object, nd = 1000L, X_new = NULL, seed = NULL) {
  .autodesn_integer(nd, "nd")
  bank <- object$bank
  if (is.null(X_new)) {
    designs <- lapply(bank$models, function(x) x$X)
  } else {
    if (!is.list(X_new) || length(X_new) != length(bank$models)) stop("X_new must have one slope matrix per bank candidate.", call. = FALSE)
    designs <- lapply(seq_along(X_new), function(j) {
      x <- as.matrix(X_new[[j]])
      if (!is.numeric(x) || any(!is.finite(x)) || nrow(x) < 1L || ncol(x) != bank$models[[j]]$d) {
        stop("X_new matrices must be finite with the fitted slope dimensions.", call. = FALSE)
      }
      cbind(1, x / bank$models[[j]]$divisor)
    })
    if (length(unique(vapply(designs, nrow, integer(1)))) != 1L) stop("X_new matrices must share response rows.", call. = FALSE)
  }
  .autodesn_seed(seed, function() {
    ids <- sample.int(nrow(object$draws), nd, replace = TRUE)
    mu <- vapply(ids, function(k) as.numeric(designs[[object$draws$model[k]]] %*% object$beta[[k]]), numeric(nrow(designs[[1L]])))
    dim(mu) <- c(nrow(designs[[1L]]), nd)
    eps <- matrix(stats::rnorm(length(mu)), nrow(mu), nd)
    yrep <- mu + sweep(eps, 2L, sqrt(object$draws$variance[ids]), `*`)
    list(yrep = .autodesn_unscale(bank, yrep), mu_draws = .autodesn_unscale(bank, mu),
         draw_index = ids, model = object$draws$model[ids], nd = nd)
  })
}

#' Recursive Gaussian AutoDESN forecast paths
#'
#' One joint model, coefficient, and variance draw is held fixed throughout
#' each path. Paths feed their own simulated observations into the existing
#' Normal Q-DESN transition. Forecasts start at the bank's terminal observation.
#'
#' @param object An `autodesn_fit` built from [autodesn_build_bank()].
#' @param H Positive forecast horizon.
#' @param nd Number of posterior predictive paths.
#' @param seed Optional seed preserving the caller's RNG state.
#' @param ... Reserved. Unrecognized controls fail explicitly.
#' @return List with `yrep`, `mu_draws`, model and draw indices, `H`, and `nd`.
#' @export
forecast_paths.autodesn_fit <- function(object, H, nd = 1000L, seed = NULL, ...) {
  .autodesn_integer(H, "H")
  .autodesn_integer(nd, "nd")
  if (length(list(...))) stop("AutoDESN forecast paths do not accept additional controls.", call. = FALSE)
  bank <- object$bank
  if (is.null(bank$templates)) stop("Recursive forecasts require autodesn_build_bank().", call. = FALSE)
  .autodesn_seed(seed, function() {
    ids <- sample.int(nrow(object$draws), nd, replace = TRUE)
    model_ids <- object$draws$model[ids]
    yrep <- mu <- matrix(NA_real_, H, nd)
    for (j in unique(model_ids)) {
      cols <- which(model_ids == j)
      beta <- do.call(rbind, object$beta[ids[cols]])
      beta[, -1L] <- beta[, -1L, drop = FALSE] / bank$models[[j]]$divisor
      # The Normal forecast API accepts external joint posterior draws. This
      # adapter labels their source and does not fit a scaled-ridge posterior.
      template <- bank$templates[[j]]
      template$fit <- list(target_label = "normal_independent_ridge_autodesn",
                           posterior_source = "finite_bank_blocked_gibbs")
      class(template) <- c("qdesn_normal_fit", "list")
      fc <- forecast_paths.qdesn_normal_fit(template, H = H, nd = length(cols),
              y_hist = bank$history_scaled, draws = list(beta = beta,
              omega2 = object$draws$variance[ids[cols]]))
      yrep[, cols] <- fc$yrep
      mu[, cols] <- fc$mu_draws
    }
    list(yrep = .autodesn_unscale(bank, yrep), mu_draws = .autodesn_unscale(bank, mu),
         draw_index = ids, model = model_ids, H = H, nd = nd,
         forecast_family = "normal_recursive_autodesn",
         origin = length(bank$history), target = "conditional_mean")
  })
}

#' @export
print.autodesn_fit <- function(x, ...) {
  cat("Gaussian AutoDESN: finite-bank blocked Gibbs\n")
  cat(length(x$bank$models), "candidates;", nrow(x$draws), "retained draws\n")
  print(utils::head(x$model_summary[order(-x$model_summary$posterior_probability), ], 8L), row.names = FALSE)
  invisible(x)
}
