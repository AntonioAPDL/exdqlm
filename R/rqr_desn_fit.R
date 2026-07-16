#' Fit an RQR-DESN interval readout
#'
#' The DESN reservoir/design is built once through the existing
#' `qdesn_fit_vb(..., fit_readout = FALSE)` shell. The RQR readout is then fit
#' on the shared fixed design. The result is a generalized-Bayes interval model,
#' not a response predictive likelihood.
#'
#' @param y Response vector.
#' @param coverage_level Interval coverage level in `(0, 1)`.
#' @param ... Arguments forwarded to `qdesn_fit_vb()` for design construction.
#' @param inference One of `"mcmc"` or `"vb"`.
#' @param learning_rate Positive generalized-Bayes learning rate.
#' @param mcmc_args Named list for [rqr_mcmc_fit()].
#' @param vb_args Named list for [rqr_vb_fit()].
#' @param fit_readout If `FALSE`, return the design shell before fitting RQR.
#' @return An `rqr_desn_fit` object.
#' @export
rqr_desn_fit <- function(y, coverage_level, ...,
                         inference = c("mcmc", "vb"),
                         learning_rate = 1,
                         mcmc_args = list(),
                         vb_args = list(),
                         fit_readout = TRUE) {
  inference <- match.arg(inference)
  args <- list(...)
  if (!is.null(args$weights)) {
    stop(
      "rqr_desn_fit rejects observation weights in version 1 because Q-DESN's sqrt-weight premultiplication is invalid for the RQR product loss.",
      call. = FALSE
    )
  }
  if (!is.list(mcmc_args)) stop("mcmc_args must be a list.", call. = FALSE)
  if (!is.list(vb_args)) stop("vb_args must be a list.", call. = FALSE)

  design_fit <- do.call(
    qdesn_fit_vb,
    c(
      list(y = y, p0 = 0.5, fit_readout = FALSE, vb_args = list()),
      args
    )
  )
  if (!isTRUE(fit_readout)) {
    design_fit$meta$rqr_design_only <- TRUE
    design_fit$meta$rqr_coverage_level <- rqr_constants(coverage_level, learning_rate)$alpha
    return(design_fit)
  }

  if (identical(inference, "mcmc")) {
    beta_prior_obj <- mcmc_args$beta_prior_obj %||% NULL
    if (is.null(beta_prior_obj)) {
      beta_type <- tolower(as.character(mcmc_args$beta_prior_type %||% "ridge")[1L])
      if (identical(beta_type, "rhs_ns")) {
        beta_prior_obj <- beta_prior("rhs_ns", rhs = mcmc_args$beta_rhs %||% list())
      } else if (identical(beta_type, "ridge")) {
        beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = mcmc_args$beta_ridge_tau2 %||% mcmc_args$tau2 %||% 1e4))
      } else {
        stop("rqr_desn_fit MCMC supports beta_prior_type in {'ridge','rhs_ns'}.", call. = FALSE)
      }
    }
    fit <- rqr_mcmc_fit(
      y = design_fit$y_fit,
      X = design_fit$X,
      coverage_level = coverage_level,
      learning_rate = learning_rate,
      beta_prior_obj = beta_prior_obj,
      mcmc_control = mcmc_args$mcmc_control %||% mcmc_args,
      init = mcmc_args$init %||% list()
    )
  } else {
    fit <- rqr_vb_fit(
      y = design_fit$y_fit,
      X = design_fit$X,
      coverage_level = coverage_level,
      learning_rate = learning_rate,
      vb_control = vb_args$vb_control %||% vb_args,
      init = vb_args$init %||% list()
    )
  }

  out <- list(
    fit = fit,
    X = design_fit$X,
    y_fit = design_fit$y_fit,
    reservoir = design_fit$reservoir,
    states = design_fit$states,
    meta = utils::modifyList(
      design_fit$meta %||% list(),
      list(
        inference_method = paste0("rqr_", inference),
        rqr_coverage_level = rqr_constants(coverage_level, learning_rate)$alpha,
        rqr_learning_rate = rqr_constants(coverage_level, learning_rate)$omega,
        inherited_design_p0 = design_fit$meta$p0 %||% NA_real_,
        response_likelihood = FALSE,
        generalized_bayes = TRUE
      )
    ),
    model_spec = fit$model_spec,
    summary = fit$summary,
    note = "RQR-DESN is a generalized-Bayes interval readout; it does not define response predictive samples."
  )
  class(out) <- c("rqr_desn_fit", "rqr_fit")
  out
}

#' @export
rqr_posterior_draws.rqr_desn_fit <- function(object, nd = NULL, seed = NULL, ...) {
  rqr_posterior_draws(object$fit, nd = nd, seed = seed, ...)
}

#' @export
predict_interval.rqr_desn_fit <- function(object, X_new = NULL, nd = NULL,
                                          draws = NULL, seed = NULL, ...) {
  if (is.null(X_new)) {
    stop(
      "predict_interval.rqr_desn_fit requires X_new. Recursive DESN feature construction is handled by forecast_paths.rqr_desn_fit with an explicit driver contract.",
      call. = FALSE
    )
  }
  predict_interval(object$fit, X_new = X_new, nd = nd, draws = draws, seed = seed, ...)
}

#' @export
print.rqr_desn_fit <- function(x, ...) {
  cat("RQR-DESN fit\n")
  cat(sprintf("  inference:      %s\n", x$fit$method %||% x$meta$inference_method %||% "unknown"))
  cat(sprintf("  coverage_level: %.4f\n", x$model_spec$coverage_level))
  cat(sprintf("  learning_rate:  %.4f\n", x$model_spec$learning_rate))
  cat(sprintf("  design rows:    %d\n", nrow(x$X)))
  cat(sprintf("  design cols:    %d\n", ncol(x$X)))
  cat("  interpretation: generalized-Bayes interval readout, not response likelihood\n")
  invisible(x)
}
