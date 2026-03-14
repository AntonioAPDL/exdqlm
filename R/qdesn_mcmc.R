#' Fit Q-DESN with configurable readout inference
#'
#' This is a light dispatcher that keeps the existing `qdesn_fit_vb()` path
#' intact while adding an MCMC readout alternative that reuses the same
#' reservoir and design construction.
#'
#' @param method One of `"vb"` or `"mcmc"`.
#' @param vb_args,mcmc_args Named lists of inference-specific settings.
#' @param ... Additional arguments forwarded to the underlying Q-DESN fitter.
#' @export
qdesn_fit <- function(..., method = c("vb", "mcmc"), vb_args = list(), mcmc_args = list()) {
  method <- match.arg(method)
  if (identical(method, "vb")) {
    return(do.call(qdesn_fit_vb, c(list(vb_args = vb_args), list(...))))
  }
  do.call(qdesn_fit_mcmc, c(list(mcmc_args = mcmc_args), list(...)))
}

#' Fit Q-DESN with an exAL MCMC readout
#'
#' The reservoir and readout design are built by reusing the existing
#' `qdesn_fit_vb(..., fit_readout = FALSE)` path. The readout is then fit with
#' [exal_mcmc_fit()] so the returned object remains compatible with the current
#' `qdesn_fit` forecasting code.
#'
#' @param mcmc_args Named list forwarded to [exal_mcmc_fit()].
#' @param fit_readout Logical; if `FALSE`, return the shared design-only object.
#' @param ... Additional arguments forwarded to the Q-DESN design builder.
#' @export
qdesn_fit_mcmc <- function(..., mcmc_args = list(), fit_readout = TRUE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a

  design_fit <- do.call(qdesn_fit_vb, c(list(fit_readout = FALSE, vb_args = list()), list(...)))
  if (!isTRUE(fit_readout)) {
    return(design_fit)
  }

  p0 <- as.numeric(design_fit$meta$p0 %||% NA_real_)
  if (!is.finite(p0) || length(p0) != 1L) {
    stop("qdesn_fit_mcmc: design object is missing a valid p0.", call. = FALSE)
  }

  beta_prior_obj <- mcmc_args$beta_prior_obj
  if (is.null(beta_prior_obj)) {
    beta_type <- tolower(as.character(mcmc_args$beta_prior_type %||% "ridge"))
    if (identical(beta_type, "rhs")) {
      rhs_list <- mcmc_args$beta_rhs %||% list()
      beta_prior_obj <- beta_prior("rhs", rhs = rhs_list)
    } else {
      tau2 <- as.numeric(mcmc_args$beta_ridge_tau2 %||% mcmc_args$tau2 %||% 1e4)
      beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = tau2))
    }
  }

  mcmc_control <- modifyList(list(
    n_burn = mcmc_args$n_burn %||% 2000L,
    n_mcmc = mcmc_args$n_mcmc %||% 1500L,
    thin = mcmc_args$thin %||% 1L,
    verbose = isTRUE(mcmc_args$verbose %||% FALSE),
    init_from_vb = isTRUE(mcmc_args$init_from_vb %||% FALSE),
    store_latent_draws = isTRUE(mcmc_args$store_latent_draws %||% FALSE),
    slice = mcmc_args$slice %||% list()
  ), mcmc_args$mcmc_control %||% list())

  fit <- exal_mcmc_fit(
    y = design_fit$y_fit,
    X = design_fit$X,
    p0 = p0,
    gamma_bounds = mcmc_args$gamma_bounds %||% c(L.fn(p0), U.fn(p0)),
    mcmc_control = mcmc_control,
    init = mcmc_args$init %||% list(),
    prior_gamma = mcmc_args$prior_gamma %||% list(
      mu0 = mcmc_args$prior_gamma_mu0 %||% 0,
      s20 = mcmc_args$prior_gamma_s20 %||% 10
    ),
    prior_sigma = mcmc_args$prior_sigma %||% list(
      a = mcmc_args$a_sigma %||% 1,
      b = mcmc_args$b_sigma %||% 1
    ),
    log_prior_gamma = mcmc_args$log_prior_gamma,
    beta_prior_obj = beta_prior_obj
  )

  design_fit$fit <- fit
  design_fit$mu_hat <- as.numeric(design_fit$X %*% fit$summary$beta_mean)
  design_fit$meta$inference_method <- "mcmc"
  design_fit
}
