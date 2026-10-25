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
#' @param standardize_features Z-score readout columns using only scored training rows.
#'   This is separate from reservoir input scaling and sqrt-d normalization.
#' @param feature_sd_tol Positive SD threshold for excluding constant readout columns.
#' @param washout Optional total number of initial unscored observations,
#'   including the conditioning prefix. Must cover conditioning and every
#'   candidate's lag/washout requirement. NULL preserves the default additive
#'   conditioning-plus-warmup convention.
#' @return An `autodesn_bank` retaining designs, reservoir weights, states,
#'   observed history, common row indices, and frozen preprocessing.
#' @export
autodesn_build_bank <- function(y, candidates = autodesn_candidates(),
                                conditioning = 30L, model_prior = NULL,
                                normalize_features = TRUE, washout = NULL,
                                standardize_features = FALSE, feature_sd_tol = 1e-8) {
  y <- .normal_desn_assert_response(y)
  .autodesn_integer(conditioning, "conditioning", 2L)
  if (!is.list(candidates) || !length(candidates)) stop("candidates must be a nonempty list.", call. = FALSE)
  specs <- lapply(candidates, .autodesn_spec)
  common_warmup <- max(vapply(specs, function(x) max(x$m, x$washout), numeric(1)))
  drop <- conditioning + common_warmup
  if (!is.null(washout)) {
    .autodesn_integer(washout, "washout", 2L)
    if (washout < max(conditioning, common_warmup)) {
      stop("Total washout must cover conditioning and every candidate's lag/washout requirement.", call. = FALSE)
    }
    drop <- washout
  }
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
                                 normalize_features = normalize_features,
                                 standardize_features = standardize_features, feature_sd_tol = feature_sd_tol)
  bank$templates <- templates
  bank$specifications <- specs
  bank$keep_idx <- keep_idx
  bank$history <- y
  bank$history_scaled <- z
  bank$preprocessing <- list(center = center, scale = scale, conditioning = conditioning,
                             common_warmup = common_warmup, drop = drop)
  if (!is.null(washout)) bank$preprocessing$washout_mode <- "total_prefix"
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
#' @param beta_prior Readout prior, `"ridge"` or normalized `"rhs"`.
#' @param rhs_control RHS controls from [autodesn_rhs_control()] or a named list.
#' @param model_control RHS architecture sampler controls; see [autodesn_fit_bank()].
#' @param backend RHS algebra backend, `"auto"`, `"R"`, or `"cpp"`.
#' @param readout_control Optional augmented lag/group controls.
#' @param seasonal_control Optional proper seasonal-period controls.
#' @param variance_control Optional latent-volatility controls.
#' @return An `autodesn_fit` supporting the existing Q-DESN prediction methods.
#' @export
autodesn_fit <- function(y, candidates = autodesn_candidates(), conditioning = 30L,
                         model_prior = NULL, normalize_features = TRUE,
                         mcmc_args = list(), washout = NULL,
                         beta_prior = c("ridge", "rhs"), rhs_control = list(),
                         model_control = list(), backend = c("auto", "R", "cpp"),
                         standardize_features = FALSE, feature_sd_tol = 1e-8,
                         readout_control = NULL, seasonal_control = NULL, variance_control = NULL) {
  beta_prior <- match.arg(beta_prior)
  if (identical(backend, "r")) backend <- "R"
  backend <- match.arg(backend)
  if (!is.list(mcmc_args) || (length(mcmc_args) &&
      (is.null(names(mcmc_args)) || any(!nzchar(names(mcmc_args))) || anyDuplicated(names(mcmc_args))))) {
    stop("mcmc_args must be a uniquely named list.", call. = FALSE)
  }
  if ("bank" %in% names(mcmc_args)) stop("mcmc_args cannot override bank.", call. = FALSE)
  if (any(c("beta_prior", "rhs_control", "model_control", "backend") %in% names(mcmc_args))) {
    stop("Set beta_prior, rhs_control, model_control and backend as top-level arguments, not inside mcmc_args.", call. = FALSE)
  }
  bank <- autodesn_build_bank(y, candidates, conditioning, model_prior,
                               normalize_features, washout = washout,
                               standardize_features = standardize_features, feature_sd_tol = feature_sd_tol)
  if (!is.null(readout_control) || !is.null(seasonal_control) || !is.null(variance_control))
    bank <- autodesn_extend_bank(bank, readout_control, seasonal_control)
  do.call(autodesn_fit_bank, c(list(bank = bank, beta_prior = beta_prior,
    rhs_control = rhs_control, model_control = model_control, backend = backend,
    variance_control = variance_control), mcmc_args))
}

.autodesn_unscale <- function(bank, x) {
  if (is.null(bank$preprocessing)) return(x)
  bank$preprocessing$center + bank$preprocessing$scale * x
}

#' Fitted posterior means from Gaussian AutoDESN
#' @param object An `autodesn_fit`.
#' @param ... Reserved for generic compatibility; additional arguments are rejected.
#' @return Numeric posterior means on the original response scale.
#' @export
predict_mu.autodesn_fit <- function(object, ...) {
  if (length(substitute(list(...))) > 1L) stop("unused arguments in ...", call. = FALSE)
  if (inherits(object,"autodesn_extended_fit")) return(predict_mu.autodesn_extended_fit(object))
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
#' @param ... Reserved for generic compatibility; additional arguments are rejected.
#' @return List with `yrep`, `mu_draws`, and selected posterior draw indices.
#' @export
posterior_predict.autodesn_fit <- function(object, nd = 1000L, X_new = NULL, seed = NULL, ...) {
  if (length(substitute(list(...))) > 1L) stop("unused arguments in ...", call. = FALSE)
  if (inherits(object,"autodesn_extended_fit")) {
    if (!is.null(X_new)) stop("Use augmented forecast_paths for future designs.",call.=FALSE)
    return(posterior_predict.autodesn_extended_fit(object,nd,seed))
  }
  .autodesn_integer(nd, "nd")
  bank <- object$bank
  if (is.null(X_new)) {
    designs <- lapply(bank$models, function(x) x$X)
  } else {
    if (!is.list(X_new) || length(X_new) != length(bank$models)) stop("X_new must have one slope matrix per bank candidate.", call. = FALSE)
    designs <- lapply(seq_along(X_new), function(j) {
      x <- as.matrix(X_new[[j]])
      raw_d <- if (is.null(bank$models[[j]]$raw_d)) bank$models[[j]]$d else bank$models[[j]]$raw_d
      if (!is.numeric(x) || any(!is.finite(x)) || nrow(x) < 1L || ncol(x) != raw_d) {
        stop("X_new matrices must be finite with the fitted slope dimensions.", call. = FALSE)
      }
      cbind(1, .autodesn_feature_apply(bank$models[[j]], x))
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
#' @param draw_index Optional indices of retained joint posterior draws. When
#'   supplied, their length determines the number of outer draws instead of nd.
#' @param inner_paths Independent innovation paths per outer draw.
#' @param innovations Optional H by (outer draws times inner_paths) matrix of
#'   standard-normal innovations, allowing paired comparisons and nested subsets.
#' @param recursion_mode Posterior predictive feedback or a separately labeled
#'   zero-innovation conditional-mean plug-in diagnostic.
#' @param backend Shared Normal forecast engine: serial (default) or batched.
#' @param ... Reserved. Unrecognized controls fail explicitly.
#' @return List with `yrep`, `mu_draws`, model and draw indices, `H`, `nd`,
#'   outer/inner path indices, and `mean_conditional_location` averaged over
#'   inner paths for each outer draw. Predictive quantiles must pool `yrep`.
#' @export
forecast_paths.autodesn_fit <- function(object, H, nd = 1000L, seed = NULL,
                                        draw_index = NULL, inner_paths = 1L,
                                        innovations = NULL,
                                        recursion_mode = c("posterior_predictive", "conditional_mean_plugin"),
                                        backend = c("serial", "batched"), ...) {
  if (inherits(object,"autodesn_extended_fit")) {
    if (match.arg(recursion_mode)!="posterior_predictive") stop("Augmented forecasts require posterior predictive recursion.",call.=FALSE)
    return(forecast_paths.autodesn_extended_fit(object,H,nd,seed,draw_index,inner_paths,innovations,...))
  }
  .autodesn_integer(H, "H")
  .autodesn_integer(nd, "nd")
  .autodesn_integer(inner_paths, "inner_paths")
  recursion_mode <- match.arg(recursion_mode)
  backend <- match.arg(backend)
  if (length(list(...))) stop("AutoDESN forecast paths do not accept additional controls.", call. = FALSE)
  bank <- object$bank
  if (is.null(bank$templates)) stop("Recursive forecasts require autodesn_build_bank().", call. = FALSE)
  if (!is.null(draw_index) && (!is.numeric(draw_index) || !length(draw_index) ||
      any(!is.finite(draw_index)) || any(draw_index != floor(draw_index)) ||
      any(draw_index < 1L | draw_index > nrow(object$draws)))) {
    stop("draw_index must contain valid retained joint-draw indices.", call. = FALSE)
  }
  .autodesn_seed(seed, function() {
    outer_ids <- if (is.null(draw_index)) sample.int(nrow(object$draws), nd, replace = TRUE) else as.integer(draw_index)
    n_outer <- length(outer_ids)
    ids <- rep(outer_ids, each = inner_paths)
    nd <- length(ids)
    if (!is.null(innovations) && (!is.matrix(innovations) || !is.numeric(innovations) ||
        !identical(dim(innovations), c(as.integer(H), as.integer(nd))) || any(!is.finite(innovations)))) {
      stop("innovations must be a finite H by total-path-count numeric matrix.", call. = FALSE)
    }
    # Keep the original serial, one-path-per-draw RNG order unchanged. Nested
    # paths use one global noise bank, independent of model grouping.
    if (is.null(innovations) && inner_paths > 1L && recursion_mode == "posterior_predictive") {
      innovations <- matrix(stats::rnorm(H * nd), H, nd)
    }
    model_ids <- object$draws$model[ids]
    yrep <- mu <- matrix(NA_real_, H, nd)
    for (j in unique(model_ids)) {
      cols <- which(model_ids == j)
      beta <- do.call(rbind, object$beta[ids[cols]])
      beta <- .autodesn_raw_beta(bank$models[[j]], beta)
      # The Normal forecast API accepts external joint posterior draws. This
      # adapter labels their source and does not fit a scaled-ridge posterior.
      template <- bank$templates[[j]]
      prior_label <- object$meta$beta_prior_type
      if (is.null(prior_label)) prior_label <- "independent_ridge"
      source_label <- object$meta$inference_method
      if (is.null(source_label)) source_label <- "blocked_gibbs"
      template$fit <- list(target_label = paste0("normal_", prior_label, "_autodesn"),
                           posterior_source = paste0("finite_bank_", source_label))
      class(template) <- c("qdesn_normal_fit", "list")
      fc <- forecast_paths.qdesn_normal_fit(template, H = H, nd = length(cols),
              y_hist = bank$history_scaled, draws = list(beta = beta,
              omega2 = object$draws$variance[ids[cols]]),
              innovations = if (is.null(innovations)) NULL else innovations[, cols, drop = FALSE],
              recursion_mode = recursion_mode, backend = backend)
      yrep[, cols] <- fc$yrep
      mu[, cols] <- fc$mu_draws
    }
    mean_location <- vapply(seq_len(n_outer), function(k)
      rowMeans(mu[, (k - 1L) * inner_paths + seq_len(inner_paths), drop = FALSE]), numeric(H))
    dim(mean_location) <- c(H, n_outer)
    list(yrep = .autodesn_unscale(bank, yrep), mu_draws = .autodesn_unscale(bank, mu),
         draw_index = ids, model = model_ids, H = H, nd = nd,
         outer_draw_index = rep(seq_len(n_outer), each = inner_paths),
         inner_path_index = rep(seq_len(inner_paths), times = n_outer),
         n_outer = n_outer, inner_paths = inner_paths,
         mean_conditional_location = .autodesn_unscale(bank, mean_location),
         recursion_mode = recursion_mode, backend = backend,
         forecast_family = "normal_recursive_autodesn",
         beta_prior_type = object$meta$beta_prior_type,
         origin = length(bank$history), target = "conditional_mean")
  })
}

#' @export
print.autodesn_fit <- function(x, ...) {
  prior <- x$meta$beta_prior_type
  if (is.null(prior)) prior <- "independent_ridge"
  inference <- x$meta$inference_method
  if (is.null(inference)) inference <- "blocked_gibbs"
  cat("Gaussian AutoDESN:", prior, "readout;", inference, "\n")
  cat(length(x$bank$models), "candidates;", nrow(x$draws), "retained draws\n")
  print(utils::head(x$model_summary[order(-x$model_summary$posterior_probability), ], 8L), row.names = FALSE)
  invisible(x)
}
